#!/usr/bin/env bash
# Shared cli-style rendering helpers for repository scripts.

CLI_STYLE_BIN="${CLI_STYLE_BIN:-$REPO_DIR/.agent/tools/cli-style/bin/cli-style}"
export CLI_STYLE_BIN

CLI_STYLE_GROUP_LABEL=""
CLI_STYLE_GROUP_SUCCESS=0
CLI_STYLE_GROUP_SKIPPED=0
CLI_STYLE_GROUP_SKIPPED_REASON=""
CLI_STYLE_GROUP_UNCHANGED=0
CLI_STYLE_GROUP_WARNING=0
CLI_STYLE_GROUP_FAILED=0

if [ ! -x "$CLI_STYLE_BIN" ]; then
	printf 'cli-style is not installed. Run: scripts/install-cli-style.sh\n' >&2
	exit 1
fi

source "$("$CLI_STYLE_BIN" adapter-path bash)"

# Renders a status row through the installed cli-style binary.
#
# @param  {string}  type
#     Status result type.
# @param  {string}  label
#     Main status label.
# @param  {string}  detail
#     Additional status text.
cli_status() {
	local type="$1"
	local label="$2"
	local detail="${3:-}"

	case "$type" in
		error) type="failed" ;;
		muted) type="unchanged" ;;
	esac

	python3 - "$type" "$label" "$detail" <<'PY' | cli_style_render status
import json
import sys

print(json.dumps({
	"type": sys.argv[1],
	"label": sys.argv[2],
	"detail": sys.argv[3],
}))
PY
}

# Renders a reporter-style group summary row.
#
# @param  {string}  type
#     Group result type.
# @param  {string}  label
#     Group label.
# @param  {string}  summary
#     Group summary text.
cli_group() {
	local type="$1"
	local label="$2"
	local summary="${3:-}"

	cli_status "$type" "$label" "$summary"
}

# Renders a compact section divider for major script phases.
#
# @param  {string}  title
#     Section title.
# @param  {string}  detail
#     Optional supporting text.
cli_section() {
	local title="$1"
	local detail="${2:-}"

	printf '\n'
	python3 - "$title" "$detail" <<'PY' | cli_style_render divider
import json
import sys

label = sys.argv[1] if sys.argv[2] == "" else f"{sys.argv[1]} · {sys.argv[2]}"
print(json.dumps({
	"dividerWidth": 64,
	"label": label,
	"labelColour": "info",
}))
PY
}

# Starts collecting status rows for one grouped summary.
#
# @param  {string}  label
#     Group label.
cli_group_begin() {
	local label="$1"

	CLI_STYLE_GROUP_LABEL="$label"
	CLI_STYLE_GROUP_SUCCESS=0
	CLI_STYLE_GROUP_SKIPPED=0
	CLI_STYLE_GROUP_SKIPPED_REASON=""
	CLI_STYLE_GROUP_UNCHANGED=0
	CLI_STYLE_GROUP_WARNING=0
	CLI_STYLE_GROUP_FAILED=0
}

# Records and optionally renders a status row inside the active group.
#
# @param  {string}  type
#     Status result type.
# @param  {string}  label
#     Main status label.
# @param  {string}  detail
#     Additional status text.
cli_group_status() {
	local type="$1"
	local label="$2"
	local detail="${3:-}"
	local normalised_type

	normalised_type=$(cli_normalise_status_type "$type")

	if [[ "$CLI_STYLE_GROUP_LABEL" == "" ]]; then
		cli_status "$normalised_type" "$label" "$detail"
		return
	fi

	cli_group_record "$normalised_type" "$label"

	if [[ "${CLI_STYLE_VERBOSE:-0}" != "1" ]] && [[ "$normalised_type" =~ ^(success|skipped|unchanged)$ ]]; then
		return
	fi

	cli_status "$normalised_type" "$label" "$detail"
}

# Renders the active group summary and clears the group state.
cli_group_end() {
	local result summary

	if [[ "$CLI_STYLE_GROUP_LABEL" == "" ]]; then
		return
	fi

	result=$(cli_group_result)
	summary=$(cli_group_summary)
	if [[ "$summary" == "" ]]; then
		CLI_STYLE_GROUP_LABEL=""
		return
	fi

	cli_group "$result" "$CLI_STYLE_GROUP_LABEL" "$summary"
	CLI_STYLE_GROUP_LABEL=""
}

# Normalises shell-friendly aliases to result types accepted by cli-style.
#
# @param  {string}  type
#     Status result type or alias.
# @returns  {string}
#     Normalised status result type.
cli_normalise_status_type() {
	local type="$1"

	case "$type" in
		error) printf 'failed' ;;
		muted) printf 'unchanged' ;;
		*) printf '%s' "$type" ;;
	esac
}

# Counts one status row for the active group.
#
# @param  {string}  type
#     Normalised status result type.
# @param  {string}  label
#     Status label.
cli_group_record() {
	local type="$1"
	local label="$2"

	case "$type" in
		failed) CLI_STYLE_GROUP_FAILED=$((CLI_STYLE_GROUP_FAILED + 1)) ;;
		warning) CLI_STYLE_GROUP_WARNING=$((CLI_STYLE_GROUP_WARNING + 1)) ;;
		success) CLI_STYLE_GROUP_SUCCESS=$((CLI_STYLE_GROUP_SUCCESS + 1)) ;;
		skipped)
			CLI_STYLE_GROUP_SKIPPED=$((CLI_STYLE_GROUP_SKIPPED + 1))
			if [[ "$CLI_STYLE_GROUP_SKIPPED_REASON" == "" ]]; then
				CLI_STYLE_GROUP_SKIPPED_REASON="$label"
			fi
			;;
		unchanged) CLI_STYLE_GROUP_UNCHANGED=$((CLI_STYLE_GROUP_UNCHANGED + 1)) ;;
	esac
}

# Returns the highest-severity result for the active group.
#
# @returns  {string}
#     Group result type.
cli_group_result() {
	if [[ "$CLI_STYLE_GROUP_FAILED" -gt 0 ]]; then
		printf 'failed'
	elif [[ "$CLI_STYLE_GROUP_WARNING" -gt 0 ]]; then
		printf 'warning'
	elif [[ "$CLI_STYLE_GROUP_SUCCESS" -gt 0 ]]; then
		printf 'success'
	elif [[ "$CLI_STYLE_GROUP_SKIPPED" -gt 0 ]]; then
		printf 'skipped'
	else
		printf 'unchanged'
	fi
}

# Returns compact count text for the active group.
#
# @returns  {string}
#     Group summary text.
cli_group_summary() {
	local summary=""

	cli_group_append_summary summary "$CLI_STYLE_GROUP_FAILED" "failed"
	cli_group_append_summary summary "$CLI_STYLE_GROUP_WARNING" "warning"
	cli_group_append_summary summary "$CLI_STYLE_GROUP_SUCCESS" "success"
	cli_group_append_skipped_summary summary
	cli_group_append_summary summary "$CLI_STYLE_GROUP_UNCHANGED" "unchanged"

	printf '%s' "$summary"
}

# Appends skipped count and reason to a comma-separated group summary.
#
# @param  {string}  summary_name
#     Variable name for the summary being built.
cli_group_append_skipped_summary() {
	local summary_name="$1"
	local label="skipped"

	if [[ "$CLI_STYLE_GROUP_SKIPPED" -eq 0 ]]; then
		return
	fi

	if [[ "$CLI_STYLE_GROUP_SKIPPED_REASON" != "" ]]; then
		label="skipped (${CLI_STYLE_GROUP_SKIPPED_REASON})"
	fi

	cli_group_append_summary "$summary_name" "$CLI_STYLE_GROUP_SKIPPED" "$label"
}

# Appends one count to a comma-separated group summary.
#
# @param  {string}  summary_name
#     Variable name for the summary being built.
# @param  {number}  count
#     Count to append.
# @param  {string}  label
#     Count label.
cli_group_append_summary() {
	local summary_name="$1"
	local count="$2"
	local label="$3"
	local current

	if [[ "$count" -eq 0 ]]; then
		return
	fi

	current="${!summary_name}"
	if [[ "$current" == "" ]]; then
		printf -v "$summary_name" '%s %s' "$count" "$label"
	else
		printf -v "$summary_name" '%s, %s %s' "$current" "$count" "$label"
	fi
}
