#!/usr/bin/env bash
# Generates all dist/ output from source files.
#
# Build order:
#   1. SKILL.md files + global-skills.md (build-skill-mds.py)
#   2. dist/claude/hooks/ (copied from hooks/claude/ source)
#   3. dist/claude/CLAUDE.md and dist/codex/AGENTS.md (assembled from rules/)
#   4. dist/chatgpt/ (build-chatgpt-target.py)
#   5. dist/claude/settings.json (build-settings.py)
#   6. Validation (validate.sh)

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$REPO_DIR/scripts/lib/colours.sh"

CLAUDE_TARGET="$REPO_DIR/dist/claude/CLAUDE.md"
CODEX_TARGET="$REPO_DIR/dist/codex/AGENTS.md"

# Ordered fragment lists for each agent's composed output file.
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

# Concatenates ordered fragment files into a single target file, with a blank
# line separating each fragment so sections don't run together.
# @param  string  target  Output file path.
# @param  string  ...     Fragment file paths (remaining arguments), in order.
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

# Clears dist/claude/hooks/ and repopulates it from the hook source dirs.
# Clearing first prevents stale files from accumulating when hooks are renamed.
copy_hooks() {
	mkdir -p "$REPO_DIR/dist/claude/hooks"
	find "$REPO_DIR/dist/claude/hooks" -maxdepth 1 -type f -delete

	local hook_dir script
	for hook_dir in "$REPO_DIR/hooks/claude/"/*/; do
		[ -d "$hook_dir" ] || continue
		for script in "$hook_dir"*; do
			[ -f "$script" ] || continue
			[[ "$(basename "$script")" == "hook.json" ]] && continue
			cp "$script" "$REPO_DIR/dist/claude/hooks/$(basename "$script")"
		done
	done
}

mkdir -p "$REPO_DIR/dist/claude" "$REPO_DIR/dist/codex"

python3 "$REPO_DIR/scripts/build-skill-mds.py"
copy_hooks
write_target "$CLAUDE_TARGET" "${CLAUDE_PARTS[@]}"
write_target "$CODEX_TARGET" "${CODEX_PARTS[@]}"
python3 "$REPO_DIR/scripts/build-chatgpt-target.py"
python3 "$REPO_DIR/scripts/build-settings.py"

printf '%s✓%s synced %sdist/claude/CLAUDE.md%s\n' "$GREEN" "$RESET_COLOUR" "$PURPLE" "$RESET_COLOUR"
printf '%s✓%s synced %sdist/codex/AGENTS.md%s\n' "$GREEN" "$RESET_COLOUR" "$PURPLE" "$RESET_COLOUR"
printf '%s✓%s synced %sdist/chatgpt/%s\n' "$GREEN" "$RESET_COLOUR" "$PURPLE" "$RESET_COLOUR"
printf '%s✓%s synced %sdist/claude/settings.json%s\n' "$GREEN" "$RESET_COLOUR" "$PURPLE" "$RESET_COLOUR"

bash "$REPO_DIR/scripts/validate.sh"
