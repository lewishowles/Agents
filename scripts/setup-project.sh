#!/usr/bin/env bash

set -euo pipefail

# Resolve the script's directory, then the repo root, so aliases can call this
# script from any project directory.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
PROJECT_DIR=$(pwd)

source "$REPO_DIR/scripts/lib/colours.sh"

usage() {
	printf 'Usage: %s [--claude|--codex|--both]\n' "$(basename "$0")"
}

copy_file() {
	local source="$1"
	local target="$2"
	local label="$3"

	if [ -e "$target" ] || [ -L "$target" ]; then
		printf '  %s↪%s %s already exists\n' "$PURPLE" "$RESET_COLOUR" "$label"
		return
	fi

	cp "$source" "$target"
	printf '  %s✓%s created %s\n' "$GREEN" "$RESET_COLOUR" "$label"
}

ensure_dir() {
	local path="$1"
	local label="$2"

	if [ -d "$path" ]; then
		printf '  %s↪%s %s already exists\n' "$PURPLE" "$RESET_COLOUR" "$label"
		return
	fi

	mkdir -p "$path"
	printf '  %s✓%s created %s\n' "$GREEN" "$RESET_COLOUR" "$label"
}

copy_claude_support_files() {
	ensure_dir "$PROJECT_DIR/.claude" ".claude/"
	ensure_dir "$PROJECT_DIR/.claude/templates" ".claude/templates/"

	copy_file "$REPO_DIR/templates/claude/settings.json" "$PROJECT_DIR/.claude/settings.json" ".claude/settings.json"
	copy_file "$REPO_DIR/templates/claude/.claudeignore" "$PROJECT_DIR/.claude/.claudeignore" ".claude/.claudeignore"
	copy_file "$REPO_DIR/templates/PLAN.md.template" "$PROJECT_DIR/.claude/templates/PLAN.md.template" ".claude/templates/PLAN.md.template"
}

setup_claude() {
	printf '\n→ Setting up Claude (project)\n\n'

	copy_file "$REPO_DIR/templates/claude/AGENTS.md.template" "$PROJECT_DIR/AGENTS.md" "AGENTS.md"
	copy_claude_support_files
}

setup_codex() {
	printf '\n→ Setting up Codex (project)\n\n'

	copy_file "$REPO_DIR/templates/codex/AGENTS.md.template" "$PROJECT_DIR/AGENTS.md" "AGENTS.md"
	ensure_dir "$PROJECT_DIR/.agents" ".agents/"
	ensure_dir "$PROJECT_DIR/.agents/skills" ".agents/skills/"
}

setup_both() {
	printf '\n→ Setting up Claude + Codex (project)\n\n'

	copy_file "$REPO_DIR/templates/shared/AGENTS.md.template" "$PROJECT_DIR/AGENTS.md" "AGENTS.md"
	copy_claude_support_files
	ensure_dir "$PROJECT_DIR/.agents" ".agents/"
	ensure_dir "$PROJECT_DIR/.agents/skills" ".agents/skills/"
}

prompt_target() {
	printf 'Which agent(s)? [1] Claude  [2] Codex  [3] Both: '
	read -r choice

	case "$choice" in
		1) printf 'claude' ;;
		2) printf 'codex' ;;
		3) printf 'both' ;;
		*) printf '%sInvalid choice.%s\n' "$RED" "$RESET_COLOUR" >&2; exit 1 ;;
	esac
}

target="${1:-}"

case "$target" in
	--claude) target="claude" ;;
	--codex) target="codex" ;;
	--both) target="both" ;;
	"") target=$(prompt_target) ;;
	*) usage >&2; exit 1 ;;
esac

case "$target" in
	claude) setup_claude ;;
	codex) setup_codex ;;
	both) setup_both ;;
esac

printf '\nDone.\n'
