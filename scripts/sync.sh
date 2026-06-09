#!/usr/bin/env bash

set -euo pipefail

# Resolve the script's directory, then the repo root, so relative paths work
# even when this script is run from another directory.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$REPO_DIR/scripts/lib/colours.sh"

CLAUDE_TARGET="$REPO_DIR/targets/claude/CLAUDE.md"
CODEX_TARGET="$REPO_DIR/targets/codex/AGENTS.md"

mkdir -p "$REPO_DIR/targets/claude" "$REPO_DIR/targets/codex"

# Target files are composed from editable fragments, not embedded prose.
CLAUDE_PARTS=(
	"$REPO_DIR/targets/claude/source/header.md"
	"$REPO_DIR/shared/global-rules.md"
	"$REPO_DIR/shared/identity.md"
	"$REPO_DIR/shared/skills-policy.md"
	"$REPO_DIR/shared/file-discovery.md"
	"$REPO_DIR/targets/claude/source/global-skills.md"
	"$REPO_DIR/targets/claude/source/codebase-memory.md"
)

CODEX_PARTS=(
	"$REPO_DIR/targets/codex/source/header.md"
	"$REPO_DIR/shared/global-rules.md"
	"$REPO_DIR/shared/identity.md"
	"$REPO_DIR/shared/skills-policy.md"
	"$REPO_DIR/shared/file-discovery.md"
	"$REPO_DIR/targets/codex/source/codebase-memory.md"
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

write_target "$CLAUDE_TARGET" "${CLAUDE_PARTS[@]}"
write_target "$CODEX_TARGET" "${CODEX_PARTS[@]}"

python3 "$REPO_DIR/scripts/build-chatgpt-target.py"

printf '%s✓%s synced %stargets/claude/CLAUDE.md%s\n' "$GREEN" "$RESET_COLOUR" "$PURPLE" "$RESET_COLOUR"
printf '%s✓%s synced %stargets/codex/AGENTS.md%s\n' "$GREEN" "$RESET_COLOUR" "$PURPLE" "$RESET_COLOUR"
printf '%s✓%s synced %stargets/chatgpt/%s\n' "$GREEN" "$RESET_COLOUR" "$PURPLE" "$RESET_COLOUR"
