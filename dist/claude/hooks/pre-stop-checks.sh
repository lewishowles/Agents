#!/usr/bin/env bash
# Runs lint and unit tests before Claude stops, then pauses if either fails.
# This enforces the evidence-before-claims rule — Claude cannot mark work done
# until the project's own checks pass. Only runs in projects with package.json.

set -euo pipefail

if [ ! -f "package.json" ]; then
	exit 0
fi

source "$(dirname "$0")/friction-helpers.sh"

failed=false
errors=""
failed_checks=""

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
	summary=$(printf '%s\n' "$errors" | sed -n '1p' | tr '\t' ' ')
	write_friction_log "check-fail" "$failed_checks: $summary"

	jq -n --arg errors "$errors" '{
		systemMessage: ("Lint or test checks failed:\n\n" + $errors),
		continue: false,
		stopReason: "Fix errors and try stopping again"
	}'
fi

exit 0
