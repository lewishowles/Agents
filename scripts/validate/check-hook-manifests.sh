#!/usr/bin/env bash
# Validates Claude hook manifests and executable hook scripts.

set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib/validate.sh"

validate_require_jq

VALID_FAILURE_MODES=("block" "ignore" "silent")

HOOK_COUNT=0

while IFS= read -r -d '' manifest; do
	dir=$(dirname "$manifest")
	dir_name=$(basename "$dir")

	if ! jq empty "$manifest" 2>/dev/null; then
		validate_fail "Invalid JSON: $manifest"
		continue
	fi

	name=$(jq -r '.name // empty' "$manifest")
	if [ -z "$name" ]; then
		validate_fail "Missing 'name': $manifest"
		continue
	fi

	if [ "$name" != "$dir_name" ]; then
		validate_fail "name '$name' does not match directory '$dir_name'"
	fi

	if [ -z "$(jq -r '.runtime // empty' "$manifest")" ]; then
		validate_fail "Missing 'runtime' in $name"
	fi

	if [ -z "$(jq -r '.description // empty' "$manifest")" ]; then
		validate_fail "Missing 'description' in $name"
	fi

	failure_mode=$(jq -r '.failureMode // empty' "$manifest")
	if [ -z "$failure_mode" ]; then
		validate_fail "Missing 'failureMode' in $name"
	elif ! validate_is_valid "$failure_mode" "${VALID_FAILURE_MODES[@]}"; then
		validate_fail "Unknown failureMode '$failure_mode' in $name"
	fi

	hook_script=""
	if [ -f "$dir/${name}.sh" ]; then
		hook_script="$dir/${name}.sh"
	fi
	if [ -f "$dir/${name}" ]; then
		hook_script="$dir/${name}"
	fi

	if [ -z "$hook_script" ]; then
		validate_fail "No hook script found for $name (expected ${name}.sh or $name)"
	elif [ ! -x "$hook_script" ]; then
		validate_fail "Hook script not executable: $hook_script"
	fi

	HOOK_COUNT=$((HOOK_COUNT + 1))
done < <(find "$REPO_DIR/hooks/claude" -name "hook.json" -print0 | sort -z)

validate_finish
