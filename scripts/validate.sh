#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$REPO_DIR/scripts/lib/colours.sh"

if ! command -v jq &>/dev/null; then
	printf 'This script requires jq. Install it with: brew install jq\n' >&2
	exit 1
fi

ERRORS=0

fail() {
	printf '%s✗%s %s\n' "$RED" "$RESET_COLOUR" "$1" >&2
	ERRORS=$((ERRORS + 1))
}

section() {
	printf '\n%s\n' "$1"
}

# ---------------------------------------------------------------------------
# Collect all skill names for dependency resolution.
# ---------------------------------------------------------------------------

declare -A SKILL_NAMES
while IFS= read -r -d '' manifest; do
	name=$(jq -r '.name // empty' "$manifest")
	[ -n "$name" ] && SKILL_NAMES["$name"]=1
done < <(find "$REPO_DIR/skills" -name "skill.json" -print0 | sort -z)

# ---------------------------------------------------------------------------
# Skill manifests
# ---------------------------------------------------------------------------

section 'Checking skill manifests...'

SKILL_COUNT=0
VALID_CAPS=("fileTriggering" "promptTriggering")
VALID_TARGETS=("claude" "codex" "chatgpt")

while IFS= read -r -d '' manifest; do
	dir=$(dirname "$manifest")
	dir_name=$(basename "$dir")

	if ! jq empty "$manifest" 2>/dev/null; then
		fail "Invalid JSON: $manifest"
		continue
	fi

	name=$(jq -r '.name // empty' "$manifest")
	[ -z "$name" ] && fail "Missing 'name': $manifest" && continue

	[ -z "$(jq -r '.description // empty' "$manifest")" ] && \
		fail "Missing 'description' in $name ($(basename "$dir"))"

	[ "$name" != "$dir_name" ] && \
		fail "name '$name' does not match directory '$dir_name'"

	while IFS= read -r cap; do
		valid=false
		for vc in "${VALID_CAPS[@]}"; do [ "$cap" = "$vc" ] && valid=true && break; done
		[ "$valid" = false ] && fail "Unknown capability '$cap' in $name"
	done < <(jq -r '.capabilities // {} | keys[]' "$manifest")

	while IFS= read -r tgt; do
		valid=false
		for vt in "${VALID_TARGETS[@]}"; do [ "$tgt" = "$vt" ] && valid=true && break; done
		[ "$valid" = false ] && fail "Unknown target '$tgt' in $name"
	done < <(jq -r '.targets // [] | .[]' "$manifest")

	while IFS= read -r dep; do
		[ -z "${SKILL_NAMES[$dep]+_}" ] && \
			fail "Unresolved dependency '$dep' in $name"
	done < <(jq -r '.dependencies // [] | .[]' "$manifest")

	[ ! -f "$dir/SKILL.body.md" ] && fail "Missing SKILL.body.md for $name"
	[ ! -f "$dir/SKILL.md" ]      && fail "Missing SKILL.md for $name (run scripts/sync.sh)"

	SKILL_COUNT=$((SKILL_COUNT + 1))
done < <(find "$REPO_DIR/skills" -name "skill.json" -print0 | sort -z)

printf '%s✓%s %d skill manifests valid\n' "$GREEN" "$RESET_COLOUR" "$SKILL_COUNT"

# ---------------------------------------------------------------------------
# Hook manifests
# ---------------------------------------------------------------------------

section 'Checking hook manifests...'

HOOK_COUNT=0
VALID_FAILURE_MODES=("block" "ignore" "silent")

while IFS= read -r -d '' manifest; do
	dir=$(dirname "$manifest")
	dir_name=$(basename "$dir")

	if ! jq empty "$manifest" 2>/dev/null; then
		fail "Invalid JSON: $manifest"
		continue
	fi

	name=$(jq -r '.name // empty' "$manifest")
	[ -z "$name" ] && fail "Missing 'name': $manifest" && continue

	[ "$name" != "$dir_name" ] && \
		fail "name '$name' does not match directory '$dir_name'"

	[ -z "$(jq -r '.runtime // empty' "$manifest")" ] && \
		fail "Missing 'runtime' in $name"

	failure_mode=$(jq -r '.failureMode // empty' "$manifest")
	if [ -z "$failure_mode" ]; then
		fail "Missing 'failureMode' in $name"
	else
		valid=false
		for fm in "${VALID_FAILURE_MODES[@]}"; do [ "$failure_mode" = "$fm" ] && valid=true && break; done
		[ "$valid" = false ] && fail "Unknown failureMode '$failure_mode' in $name"
	fi

	# Find the hook script — may be <name>.sh or extensionless <name>.
	hook_script=""
	[ -f "$dir/${name}.sh" ] && hook_script="$dir/${name}.sh"
	[ -f "$dir/${name}" ]    && hook_script="$dir/${name}"

	if [ -z "$hook_script" ]; then
		fail "No hook script found for $name (expected ${name}.sh or $name)"
	elif [ ! -x "$hook_script" ]; then
		fail "Hook script not executable: $hook_script"
	fi

	HOOK_COUNT=$((HOOK_COUNT + 1))
done < <(find "$REPO_DIR/hooks/claude" -name "hook.json" -print0 | sort -z)

printf '%s✓%s %d hook manifests valid\n' "$GREEN" "$RESET_COLOUR" "$HOOK_COUNT"

# ---------------------------------------------------------------------------
# Generated files exist
# ---------------------------------------------------------------------------

section 'Checking generated files...'

GENERATED_FILES=(
	"dist/claude/CLAUDE.md"
	"dist/claude/settings.json"
	"dist/claude/source/global-skills.md"
)

for f in "${GENERATED_FILES[@]}"; do
	[ ! -f "$REPO_DIR/$f" ] && fail "Missing generated file: $f (run scripts/sync.sh)"
done

printf '%s✓%s Generated files present\n' "$GREEN" "$RESET_COLOUR"

# ---------------------------------------------------------------------------
# dist/claude/hooks/ in sync with source
# ---------------------------------------------------------------------------

section 'Checking dist/claude/hooks/ in sync...'

STALE=0

while IFS= read -r -d '' manifest; do
	dir=$(dirname "$manifest")
	name=$(jq -r '.name' "$manifest")

	for src in "$dir/${name}.sh" "$dir/${name}"; do
		[ -f "$src" ] || continue
		basename=$(basename "$src")
		dst="$REPO_DIR/dist/claude/hooks/$basename"
		if [ ! -f "$dst" ]; then
			fail "dist/claude/hooks/$basename missing (run scripts/sync.sh)"
			STALE=$((STALE + 1))
		elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
			fail "dist/claude/hooks/$basename out of sync with source (run scripts/sync.sh)"
			STALE=$((STALE + 1))
		fi
	done
done < <(find "$REPO_DIR/hooks/claude" -name "hook.json" -print0 | sort -z)

[ "$STALE" -eq 0 ] && printf '%s✓%s dist/claude/hooks/ in sync\n' "$GREEN" "$RESET_COLOUR"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf '\n'
if [ "$ERRORS" -gt 0 ]; then
	printf '%s%d error(s) found%s\n' "$RED" "$ERRORS" "$RESET_COLOUR"
	exit 1
fi

printf '%s✓ All checks passed%s\n' "$GREEN" "$RESET_COLOUR"
