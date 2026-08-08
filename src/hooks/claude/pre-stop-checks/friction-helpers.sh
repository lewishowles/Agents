#!/usr/bin/env bash
# Shared check-running and friction-log-writing helpers. Copied to
# dist/claude/hooks/ as a sibling of pre-stop-checks.sh (and, in future, a
# Codex Stop hook) so both entry points can source the same logic.

# Returns 0 if the named npm script exists in package.json, 1 otherwise.
# Uses jq for exact key lookup when available; falls back to grep.
#
# @param  {string}  name
#     The npm script name to look up.
has_script() {
	local name="$1"

	if command -v jq &>/dev/null; then
		jq -e ".scripts | has(\"$name\")" package.json 2>/dev/null && return 0 || return 1
	else
		grep -q "\"$name\"" package.json 2>/dev/null && return 0 || return 1
	fi
}

# Adds a check name to the comma-separated failed_checks string.
#
# @param  {string}  check
#     The check name to append (e.g. "lint" or "test:unit:run").
append_failed_check() {
	local check="$1"

	if [ -n "$failed_checks" ]; then
		failed_checks="$failed_checks,$check"
	else
		failed_checks="$check"
	fi
}

# Picks the most useful single line out of captured check output.
#
# npm prints a blank line and one or more "> script" banner lines before the
# command's own output, so the first line is almost never the failure. Prefer
# the first line that reads as an error; fall back to the first line that isn't
# part of npm's banner.
#
# @param  {string}  output
#     Combined stdout and stderr from the failed check.
extract_error_summary() {
	local body
	local line

	body=$(printf '%s\n' "$1" | grep -vE '^[[:space:]]*$|^[[:space:]]*>')

	line=$(printf '%s\n' "$body" | grep -m1 -E 'error|Error|ERROR|FAIL|failed|✖|✗|×') || true

	if [ -z "$line" ]; then
		line=$(printf '%s\n' "$body" | head -1)
	fi

	printf '%s' "$line" | tr '\t' ' ' | cut -c1-300
}

# Returns 0 if an identical entry was written to the log within the last two
# minutes. Repeated stop attempts against an unchanged failure would otherwise
# write one row per attempt, which buries the manually logged entries.
#
# @param  {string}  log_file
#     Path to the log being appended to.
# @param  {string}  category
#     Friction category for the pending entry.
# @param  {string}  detail
#     Detail string for the pending entry.
is_duplicate_entry() {
	local log_file="$1"
	local category="$2"
	local detail="$3"
	local last_line
	local now_seconds
	local then_seconds

	if [[ ! -f "$log_file" ]]; then
		return 1
	fi

	last_line=$(tail -1 "$log_file" 2>/dev/null) || return 1

	[ "$(printf '%s' "$last_line" | cut -f2)" = "$category" ] || return 1
	[ "$(printf '%s' "$last_line" | cut -f3)" = "$PWD" ] || return 1
	[ "$(printf '%s' "$last_line" | cut -f4)" = "$detail" ] || return 1

	now_seconds=$(date -u '+%s')
	then_seconds=$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$(printf '%s' "$last_line" | cut -f1)" '+%s' 2>/dev/null) || return 1

	[ "$((now_seconds - then_seconds))" -lt 120 ]
}

# Appends a tab-separated entry to the friction log so patterns can be
# analysed later with src/skills/friction-review/scripts/analyse-friction.sh.
#
# @param  {string}  category
#     Friction category — check-fail for automated check failures.
# @param  {string}  detail
#     Freeform detail, e.g. "<failed_checks>: <first error line>".
write_friction_log() {
	local category="$1"
	local detail="$2"
	local log_file="$HOME/.claude/logs/friction.log"
	local fallback_log_file="$PWD/.agent/logs/friction.log"
	local timestamp

	if is_duplicate_entry "$log_file" "$category" "$detail"; then
		return 0
	fi

	timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

	if mkdir -p "$(dirname "$log_file")" 2>/dev/null && printf '%s\t%s\t%s\t%s\n' "$timestamp" "$category" "$PWD" "$detail" >> "$log_file" 2>/dev/null; then
		return 0
	fi

	mkdir -p "$(dirname "$fallback_log_file")" 2>/dev/null || return 0
	printf '%s\t%s\t%s\t%s\n' "$timestamp" "$category" "$PWD" "$detail" >> "$fallback_log_file" 2>/dev/null || return 0
}
