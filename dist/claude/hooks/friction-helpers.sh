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

# Appends a tab-separated entry to the friction log so patterns can be
# analysed later with scripts/analyse-friction.sh.
#
# @param  {string}  category
#     Friction category — check-fail for automated check failures.
# @param  {string}  detail
#     Freeform detail, e.g. "<failed_checks>: <first error line>".
write_friction_log() {
	local category="$1"
	local detail="$2"
	local log_file="$HOME/.claude/logs/friction.log"
	local timestamp

	timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

	mkdir -p "$(dirname "$log_file")"
	printf '%s\t%s\t%s\t%s\n' "$timestamp" "$category" "$PWD" "$detail" >> "$log_file"
}
