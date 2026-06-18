#!/usr/bin/env bash
# Installs global agent configuration by symlinking dist/ output and skills
# into ~/.claude/ and/or ~/.agents/. Safe to re-run — existing links are
# backed up rather than overwritten, and stale links are pruned automatically.

set -euo pipefail

# Resolved at startup so aliases can call this script from any directory.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$REPO_DIR/scripts/lib/colours.sh"
source "$REPO_DIR/scripts/lib/setup-links.sh"

usage() {
	printf 'Usage: %s [--claude|--codex|--both] [--skip-external]\n' "$(basename "$0")"
}

setup_claude() {
	printf '\n→ Setting up Claude (global)\n\n'

	ensure_container_dir "$HOME/.claude" "~/.claude"
	ensure_container_dir "$HOME/.claude/skills" "skills"
	ensure_container_dir "$HOME/.claude/hooks" "hooks"
	ensure_container_dir "$HOME/.claude/commands" "commands"

	link_path "$REPO_DIR/dist/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md" "CLAUDE.md"
	link_path "$REPO_DIR/dist/claude/settings.json" "$HOME/.claude/settings.json" "settings.json"
	link_path "$REPO_DIR/dist/claude/.mcp.json" "$HOME/.claude/.mcp.json" ".mcp.json"

	prune_stale_repo_links "$HOME/.claude/skills" "$REPO_DIR/skills" "skills"
	link_skills "$HOME/.claude/skills"

	prune_stale_repo_links "$HOME/.claude/hooks" "$REPO_DIR/dist/claude/hooks" "hooks"
	local hook
	for hook in "$REPO_DIR"/dist/claude/hooks/*; do
		[ -f "$hook" ] || continue
		link_path "$hook" "$HOME/.claude/hooks/$(basename "$hook")" "hooks/$(basename "$hook")"
	done

	local command
	for command in "$REPO_DIR"/dist/claude/commands/*; do
		[ -f "$command" ] || continue
		link_path "$command" "$HOME/.claude/commands/$(basename "$command")" "commands/$(basename "$command")"
	done
}

setup_codex() {
	printf '\n→ Setting up Codex (global)\n\n'

	ensure_container_dir "$HOME/.agents" "~/.agents"
	ensure_container_dir "$HOME/.agents/skills" "~/.agents/skills"
	ensure_container_dir "$HOME/.codex" "~/.codex"
	ensure_container_dir "$HOME/.codex/skills" "~/.codex/skills"

	link_path "$REPO_DIR/dist/codex/AGENTS.md" "$HOME/.agents/AGENTS.md" "AGENTS.md"
	link_path "$REPO_DIR/dist/codex/AGENTS.md" "$HOME/.codex/AGENTS.md" "Codex AGENTS.md"
	ensure_codex_config

	prune_stale_repo_links "$HOME/.agents/skills" "$REPO_DIR/skills" "skills"
	prune_stale_repo_links "$HOME/.codex/skills" "$REPO_DIR/skills" "Codex skills"
	link_skills "$HOME/.agents/skills"
	link_skills "$HOME/.codex/skills"
}

# Ensures ~/.codex/config.toml contains the codebase-memory-mcp server entry.
# Any existing entry for that server is replaced rather than duplicated, so
# this function is safe to run on every setup.
ensure_codex_config() {
	local config="$HOME/.codex/config.toml"
	local temp

	temp=$(mktemp)
	touch "$config"

	# Strip any existing codebase-memory-mcp section before re-appending it,
	# so re-running setup never creates duplicate entries.
	awk '
		/^\[mcp_servers\.codebase-memory-mcp(\.|\])/{ skip = 1; next }
		/^\[/{ skip = 0 }
		!skip { print }
	' "$config" > "$temp"

	printf '\n[mcp_servers.codebase-memory-mcp]\ncommand = "codebase-memory-mcp"\n' >> "$temp"

	if cmp -s "$config" "$temp"; then
		rm "$temp"
		printf '  %s↪%s Codex config already configured\n' "$PURPLE" "$RESET_COLOUR"
		return
	fi

	local backup="$config.bak.$(timestamp)"
	cp "$config" "$backup"
	mv "$temp" "$config"
	printf '  %s✓%s configured Codex MCP server (backup at %s)\n' "$GREEN" "$RESET_COLOUR" "$(display_path "$backup")"
}

# Configures git to use hooks/git/ as the hook directory for this repo.
# This installs the pre-push hook without touching ~/.git/hooks directly.
configure_git_hooks() {
	printf '\n→ Configuring git hooks\n\n'

	if ! git -C "$REPO_DIR" config core.hooksPath hooks/git &>/dev/null; then
		printf '  %s!%s Could not set core.hooksPath — not a git repo?\n' "$YELLOW" "$RESET_COLOUR"
		return
	fi

	printf '  %s✓%s git hooks path set to hooks/git/\n' "$GREEN" "$RESET_COLOUR"
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

target=""
sync_external=true

while [ $# -gt 0 ]; do
	case "$1" in
		--claude)        target="claude" ;;
		--codex)         target="codex" ;;
		--both)          target="both" ;;
		--skip-external) sync_external=false ;;
		--help)          usage; exit 0 ;;
		*)               usage >&2; exit 1 ;;
	esac
	shift
done

if [ -z "$target" ]; then
	target=$(prompt_target)
fi

if [ "$sync_external" = true ]; then
	if ! bash "$REPO_DIR/scripts/sync-external-skills.sh"; then
		printf '%s!%s external skill sync failed; continuing with existing local skills\n' "$YELLOW" "$RESET_COLOUR" >&2
	fi
fi

bash "$REPO_DIR/scripts/sync.sh"

case "$target" in
	claude) setup_claude ;;
	codex)  setup_codex ;;
	both)   setup_claude; setup_codex ;;
esac

configure_git_hooks

printf '\nDone.\n'
