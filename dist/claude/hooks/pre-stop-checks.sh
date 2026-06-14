#!/usr/bin/env bash
# Runs lint and unit tests before Claude stops, then pauses if either fails.
# This enforces the evidence-before-claims rule — Claude cannot mark work done
# until the project's own checks pass. Only runs in projects with package.json.

set -euo pipefail

if [ ! -f "package.json" ]; then
	exit 0
fi

failed=false
errors=""
failed_checks=""

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
write_friction_log() {
	local log_file="$HOME/.claude/logs/friction.log"
	local timestamp
	local summary

	timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
	summary=$(printf '%s\n' "$errors" | sed -n '1p' | tr '\t' ' ')

	mkdir -p "$(dirname "$log_file")"
	printf '%s\t%s\t%s\t%s\n' "$timestamp" "$PWD" "$failed_checks" "$summary" >> "$log_file"
}

if has_script "lint"; then
	printf 'Running lint...\n' >&2
	if ! lint_out=$(npm run lint 2>&1); then
		failed=true
		append_failed_check "lint"
		errors="$lint_out"
	fi
fi

if has_script "test:unit:run"; then
	printf 'Running unit tests...\n' >&2
	if ! test_out=$(npm run test:unit:run 2>&1); then
		failed=true
		append_failed_check "test:unit:run"
		if [ -n "$errors" ]; then
			errors="$errors"$'\n\n'"$test_out"
		else
			errors="$test_out"
		fi
	fi
fi

if [ "$failed" = true ]; then
	write_friction_log

	jq -n --arg errors "$errors" '{
		systemMessage: ("Lint or test checks failed:\n\n" + $errors),
		continue: false,
		stopReason: "Fix errors and try stopping again"
	}'
fi

exit 0
