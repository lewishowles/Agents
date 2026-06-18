#!/usr/bin/env bash
# Validates skill manifests and generated skill files.

set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib/validate.sh"

validate_require_jq

VALID_CAPS=("fileTriggering" "promptTriggering")
VALID_TARGETS=("chatgpt" "claude" "codex")

declare -A SKILL_NAMES
while IFS= read -r -d '' manifest; do
	name=$(jq -r '.name // empty' "$manifest")
	if [ -n "$name" ]; then
		SKILL_NAMES["$name"]=1
	fi
done < <(find "$REPO_DIR/skills" -name "skill.json" -print0 | sort -z)

validate_section 'Checking skill manifests...'

SKILL_COUNT=0

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

	if [ -z "$(jq -r '.description // empty' "$manifest")" ]; then
		validate_fail "Missing 'description' in $name"
	fi

	title=$(jq -r '.title // empty' "$manifest")
	if [ -n "$title" ] && [ "$title" = "$name" ]; then
		validate_fail "title should be human-readable, not identical to name, in $name"
	fi

	if [ "$name" != "$dir_name" ]; then
		validate_fail "name '$name' does not match directory '$dir_name'"
	fi

	while IFS= read -r cap; do
		if ! validate_is_valid "$cap" "${VALID_CAPS[@]}"; then
			validate_fail "Unknown capability '$cap' in $name"
		fi
	done < <(jq -r '.capabilities // {} | keys[]' "$manifest")

	while IFS= read -r tgt; do
		if ! validate_is_valid "$tgt" "${VALID_TARGETS[@]}"; then
			validate_fail "Unknown target '$tgt' in $name"
		fi
	done < <(jq -r '.targets // [] | .[]' "$manifest")

	while IFS= read -r dep; do
		if [ -z "${SKILL_NAMES[$dep]+_}" ]; then
			validate_fail "Unresolved dependency '$dep' in $name"
		fi
	done < <(jq -r '.dependencies // [] | .[]' "$manifest")

	if [ ! -f "$dir/SKILL.body.md" ]; then
		validate_fail "Missing SKILL.body.md for $name"
	fi

	if [ ! -f "$dir/SKILL.md" ]; then
		validate_fail "Missing SKILL.md for $name (run scripts/sync.sh)"
	fi

	if [ -f "$dir/SKILL.md" ]; then
		line_count=$(wc -l < "$dir/SKILL.md")
		if [ "$line_count" -gt 500 ]; then
			validate_warn "SKILL.md for $name is ${line_count} lines (limit: 500) — consider splitting"
		fi
	fi

	SKILL_COUNT=$((SKILL_COUNT + 1))
done < <(find "$REPO_DIR/skills" -name "skill.json" -print0 | sort -z)

printf '%s✓%s %d skill manifests valid\n' "$GREEN" "$RESET_COLOUR" "$SKILL_COUNT"

validate_finish
