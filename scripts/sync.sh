#!/usr/bin/env bash

set -euo pipefail

# Resolve the script's directory, then the repo root, so relative paths work
# even when this script is run from another directory.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$REPO_DIR/scripts/lib/colours.sh"

CLAUDE_TARGET="$REPO_DIR/dist/claude/CLAUDE.md"
CODEX_TARGET="$REPO_DIR/dist/codex/AGENTS.md"

mkdir -p "$REPO_DIR/dist/claude" "$REPO_DIR/dist/codex"

# Target files are composed from editable fragments, not embedded prose.
CLAUDE_PARTS=(
	"$REPO_DIR/dist/claude/source/header.md"
	"$REPO_DIR/rules/global-rules.md"
	"$REPO_DIR/rules/identity.md"
	"$REPO_DIR/rules/skills-policy.md"
	"$REPO_DIR/rules/file-discovery.md"
	"$REPO_DIR/dist/claude/source/global-skills.md"
	"$REPO_DIR/dist/claude/source/codebase-memory.md"
)

CODEX_PARTS=(
	"$REPO_DIR/dist/codex/source/header.md"
	"$REPO_DIR/rules/global-rules.md"
	"$REPO_DIR/rules/identity.md"
	"$REPO_DIR/rules/skills-policy.md"
	"$REPO_DIR/rules/file-discovery.md"
	"$REPO_DIR/dist/codex/source/codebase-memory.md"
)

write_target() {
	local target="$1"
	shift

	: > "$target"

	local part
	local first=true

	for part in "$@"; do
		if [ "$first" = false ]; then
			printf '\n' >> "$target"
		fi

		cat "$part" >> "$target"
		first=false
	done
}

python3 "$REPO_DIR/scripts/build-skill-mds.py"

mkdir -p "$REPO_DIR/dist/claude/hooks"

for hook_dir in "$REPO_DIR/hooks/claude/"/*/; do
	[ -d "$hook_dir" ] || continue
	for script in "$hook_dir"*; do
		[ -f "$script" ] || continue
		[[ "$(basename "$script")" == "hook.json" ]] && continue
		cp "$script" "$REPO_DIR/dist/claude/hooks/$(basename "$script")"
	done
done

write_target "$CLAUDE_TARGET" "${CLAUDE_PARTS[@]}"
write_target "$CODEX_TARGET" "${CODEX_PARTS[@]}"

python3 "$REPO_DIR/scripts/build-chatgpt-target.py"

printf '%s✓%s synced %sdist/claude/CLAUDE.md%s\n' "$GREEN" "$RESET_COLOUR" "$PURPLE" "$RESET_COLOUR"
printf '%s✓%s synced %sdist/codex/AGENTS.md%s\n' "$GREEN" "$RESET_COLOUR" "$PURPLE" "$RESET_COLOUR"
printf '%s✓%s synced %sdist/chatgpt/%s\n' "$GREEN" "$RESET_COLOUR" "$PURPLE" "$RESET_COLOUR"
