#!/usr/bin/env bash
# Runs lint and unit tests before Claude stops, then pauses if either fails.
# This enforces the evidence-before-claims rule — Claude cannot mark work done
# until the project's own checks pass. Only runs in projects with package.json.
#
# Checks are skipped when the worktree fingerprint matches the last run that
# passed, so notification-only stops and status-only turns don't re-run the
# suite. A failing tree is never cached, so the gate still blocks every time.

set -euo pipefail

if [ ! -f "package.json" ]; then
	exit 0
fi

source "$(dirname "$0")/friction-helpers.sh"

# Prints a fingerprint of the current worktree, or nothing when the project is
# not a Git repository. Without Git there is no cheap way to tell whether
# anything changed, so those projects always run their checks.
worktree_fingerprint() {
	local head
	local status

	if ! git rev-parse --git-dir &>/dev/null; then
		return 0
	fi

	head=$(git rev-parse HEAD 2>/dev/null || printf 'no-head')
	status=$(git status --porcelain 2>/dev/null || printf '')

	printf '%s\n%s' "$head" "$status" | shasum | cut -d' ' -f1
}

# Prints the path of the file holding the last passing fingerprint for $PWD.
# Keyed by directory so each project caches independently.
cache_file_path() {
	local key

	key=$(printf '%s' "$PWD" | shasum | cut -d' ' -f1)

	printf '%s/.claude/cache/pre-stop-checks/%s' "$HOME" "$key"
}

# Records the fingerprint of a worktree whose checks passed. Failures are never
# recorded, so an unchanged failing tree is rechecked and blocks again.
#
# @param  {string}  fingerprint
#     The fingerprint to store, or empty to store nothing.
remember_passing_fingerprint() {
	local fingerprint="$1"
	local cache_file

	if [ -z "$fingerprint" ]; then
		return 0
	fi

	cache_file=$(cache_file_path)

	mkdir -p "$(dirname "$cache_file")" 2>/dev/null || return 0
	printf '%s' "$fingerprint" > "$cache_file" 2>/dev/null || return 0
}

# Returns 0 if this exact worktree already passed its checks.
#
# @param  {string}  fingerprint
#     The current worktree fingerprint, or empty when unavailable.
already_passed() {
	local fingerprint="$1"
	local cache_file

	if [ -z "$fingerprint" ]; then
		return 1
	fi

	cache_file=$(cache_file_path)

	if [[ ! -f "$cache_file" ]]; then
		return 1
	fi

	[ "$(cat "$cache_file" 2>/dev/null)" = "$fingerprint" ]
}

fingerprint=$(worktree_fingerprint)

if already_passed "$fingerprint"; then
	exit 0
fi

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
	summary=$(extract_error_summary "$errors")
	write_friction_log "check-fail" "$failed_checks: $summary"

	jq -n --arg errors "$errors" '{
		systemMessage: ("Lint or test checks failed:\n\n" + $errors),
		continue: false,
		stopReason: "Fix errors and try stopping again"
	}'
else
	remember_passing_fingerprint "$fingerprint"
fi

exit 0
