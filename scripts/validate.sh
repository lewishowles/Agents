#!/usr/bin/env bash
# Validates all skill.json and hook.json manifests, checks that generated files
# exist, and confirms dist/claude/hooks/ matches the hook sources.
# Run directly or via scripts/sync.sh after generation.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$REPO_DIR/scripts/lib/colours.sh"

if ! command -v jq &>/dev/null; then
	printf 'This script requires jq. Install it with: brew install jq\n' >&2
	exit 1
fi

ERRORS=0

# Prints an error message and increments the error counter.
#
# @param  {string}  message
#     Error message to display.
fail() {
	printf '%s✗%s %s\n' "$RED" "$RESET_COLOUR" "$1" >&2
	ERRORS=$((ERRORS + 1))
}

# Prints a warning message without incrementing the error counter.
#
# @param  {string}  message
#     Warning message to display.
warn() {
	printf '%s⚠%s %s\n' "$YELLOW" "$RESET_COLOUR" "$1" >&2
}

# @param  {string}  heading
#     Section heading to print.
section() {
	printf '\n%s\n' "$1"
}

# Returns 0 if the value is in the allowed list, 1 otherwise.
#
# @param  {string}  value
#     The value to check.
# @param  {string}  ...
#     Allowed values (remaining arguments).
is_valid() {
	local value="$1"
	shift
	local allowed
	for allowed in "$@"; do
		[ "$value" = "$allowed" ] && return 0
	done
	return 1
}

VALID_CAPS=("fileTriggering" "promptTriggering")
VALID_TARGETS=("chatgpt" "claude" "codex")
VALID_FAILURE_MODES=("block" "ignore" "silent")

# Collect all skill names up front so dependency references can be resolved
# without re-reading every manifest once per skill.
declare -A SKILL_NAMES
while IFS= read -r -d '' manifest; do
	name=$(jq -r '.name // empty' "$manifest")
	[ -n "$name" ] && SKILL_NAMES["$name"]=1
done < <(find "$REPO_DIR/skills" -name "skill.json" -print0 | sort -z)


section 'Checking skill manifests...'

SKILL_COUNT=0

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
		fail "Missing 'description' in $name"

	title=$(jq -r '.title // empty' "$manifest")
	[ -n "$title" ] && [ "$title" = "$name" ] && \
		fail "title should be human-readable, not identical to name, in $name"

	[ "$name" != "$dir_name" ] && \
		fail "name '$name' does not match directory '$dir_name'"

	while IFS= read -r cap; do
		is_valid "$cap" "${VALID_CAPS[@]}" || fail "Unknown capability '$cap' in $name"
	done < <(jq -r '.capabilities // {} | keys[]' "$manifest")

	while IFS= read -r tgt; do
		is_valid "$tgt" "${VALID_TARGETS[@]}" || fail "Unknown target '$tgt' in $name"
	done < <(jq -r '.targets // [] | .[]' "$manifest")

	while IFS= read -r dep; do
		[ -z "${SKILL_NAMES[$dep]+_}" ] && fail "Unresolved dependency '$dep' in $name"
	done < <(jq -r '.dependencies // [] | .[]' "$manifest")

	[ ! -f "$dir/SKILL.body.md" ] && fail "Missing SKILL.body.md for $name"
	[ ! -f "$dir/SKILL.md" ]      && fail "Missing SKILL.md for $name (run scripts/sync.sh)"

	if [ -f "$dir/SKILL.md" ]; then
		line_count=$(wc -l < "$dir/SKILL.md")
		[ "$line_count" -gt 500 ] && \
			warn "SKILL.md for $name is ${line_count} lines (limit: 500) — consider splitting"
	fi

	SKILL_COUNT=$((SKILL_COUNT + 1))
done < <(find "$REPO_DIR/skills" -name "skill.json" -print0 | sort -z)

printf '%s✓%s %d skill manifests valid\n' "$GREEN" "$RESET_COLOUR" "$SKILL_COUNT"


section 'Checking hook manifests...'

HOOK_COUNT=0

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

	[ -z "$(jq -r '.description // empty' "$manifest")" ] && \
		fail "Missing 'description' in $name"

	failure_mode=$(jq -r '.failureMode // empty' "$manifest")
	if [ -z "$failure_mode" ]; then
		fail "Missing 'failureMode' in $name"
	else
		is_valid "$failure_mode" "${VALID_FAILURE_MODES[@]}" || \
			fail "Unknown failureMode '$failure_mode' in $name"
	fi

	# Hooks are either a .sh script or an extensionless executable (for hooks
	# with a custom command path in hook.json, like cbm-code-discovery-gate).
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


section 'Checking dist/claude/hooks/ in sync...'

STALE=0

while IFS= read -r -d '' manifest; do
	dir=$(dirname "$manifest")
	name=$(jq -r '.name' "$manifest")

	for src in "$dir/${name}.sh" "$dir/${name}"; do
		[ -f "$src" ] || continue
		dst="$REPO_DIR/dist/claude/hooks/$(basename "$src")"

		if [ ! -f "$dst" ]; then
			fail "dist/claude/hooks/$(basename "$src") missing (run scripts/sync.sh)"
			STALE=$((STALE + 1))
		elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
			fail "dist/claude/hooks/$(basename "$src") out of sync with source (run scripts/sync.sh)"
			STALE=$((STALE + 1))
		fi
	done
done < <(find "$REPO_DIR/hooks/claude" -name "hook.json" -print0 | sort -z)

[ "$STALE" -eq 0 ] && printf '%s✓%s dist/claude/hooks/ in sync\n' "$GREEN" "$RESET_COLOUR"

section 'Checking generated docs tables...'

if python3 "$REPO_DIR/scripts/build-docs.py" --check; then
	printf '%s✓%s Generated docs tables in sync\n' "$GREEN" "$RESET_COLOUR"
else
	fail "Generated docs tables out of sync (run scripts/sync.sh)"
fi


printf '\n'
if [ "$ERRORS" -gt 0 ]; then
	printf '%s%d error(s) found%s\n' "$RED" "$ERRORS" "$RESET_COLOUR"
	exit 1
fi

printf '%s✓ All checks passed%s\n' "$GREEN" "$RESET_COLOUR"
