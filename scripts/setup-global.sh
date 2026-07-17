#!/usr/bin/env bash
# Installs global agent configuration into Claude, Codex, and Stagewise.
# Claude and Codex use symlinks; Stagewise receives a fresh copy of skills.

set -euo pipefail

# Resolved at startup so aliases can call this script from any directory.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$REPO_DIR/scripts/lib/setup-links.sh"

usage() {
	printf 'Usage: %s [--claude|--codex|--both] [--skip-external] [--no-backup]\n' "$(basename "$0")"
}

setup_claude() {
	cli_section "Claude global setup"

	cli_group_begin "Claude directories"
	ensure_container_dir "$HOME/.claude" "~/.claude"
	ensure_container_dir "$HOME/.claude/skills" "skills"
	ensure_container_dir "$HOME/.claude/hooks" "hooks"
	ensure_container_dir "$HOME/.claude/commands" "commands"
	cli_group_end

	cli_group_begin "Claude files"
	link_path "$REPO_DIR/dist/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md" "CLAUDE.md"
	link_path "$REPO_DIR/dist/claude/settings.json" "$HOME/.claude/settings.json" "settings.json"
	link_path "$REPO_DIR/dist/claude/.mcp.json" "$HOME/.claude/.mcp.json" ".mcp.json"
	cli_group_end

	cli_group_begin "Claude skills"
	prune_stale_repo_links "$HOME/.claude/skills" "$REPO_DIR" "skills"
	link_skills "$HOME/.claude/skills"
	cli_group_end

	cli_group_begin "Claude hooks"
	prune_stale_repo_links "$HOME/.claude/hooks" "$REPO_DIR/dist/claude/hooks" "hooks"
	local hook
	for hook in "$REPO_DIR"/dist/claude/hooks/*; do
		[ -f "$hook" ] || continue
		link_path "$hook" "$HOME/.claude/hooks/$(basename "$hook")" "hooks/$(basename "$hook")"
	done
	cli_group_end

	cli_group_begin "Claude commands"
	local command
	for command in "$REPO_DIR"/dist/claude/commands/*; do
		[ -f "$command" ] || continue
		link_path "$command" "$HOME/.claude/commands/$(basename "$command")" "commands/$(basename "$command")"
	done
	cli_group_end
}

setup_codex() {
	cli_section "Codex global setup"

	cli_group_begin "Codex directories"
	ensure_container_dir "$HOME/.agents" "~/.agents"
	ensure_container_dir "$HOME/.agents/skills" "~/.agents/skills"
	ensure_container_dir "$HOME/.codex" "~/.codex"
	cli_group_end

	cli_group_begin "Codex files"
	link_path "$REPO_DIR/dist/codex/AGENTS.md" "$HOME/.agents/AGENTS.md" "AGENTS.md"
	link_path "$REPO_DIR/dist/codex/AGENTS.md" "$HOME/.codex/AGENTS.md" "Codex AGENTS.md"
	link_path "$REPO_DIR/dist/codex/hooks.json" "$HOME/.codex/hooks.json" "Codex hooks"
	ensure_codex_config
	cli_group_end

	cli_group_begin "Codex skills"
	prune_stale_repo_links "$HOME/.agents/skills" "$REPO_DIR" "skills"
	prune_stale_repo_links "$HOME/.codex/skills" "$REPO_DIR" "legacy skills"
	link_skills "$HOME/.agents/skills"
	cli_group_end
}

# Replaces Stagewise skills with a fresh copy from this repository.
# Global rules are delivered as a Stagewise-only skill (global-rules) rather
# than via ~/.stagewise/AGENTS.md, which Stagewise does not inject into agent
# context. Skills are the only user-provided knowledge Stagewise auto-mounts.
setup_stagewise() {
	local skills_dir="$HOME/.stagewise/skills"

	cli_section "Stagewise global setup"

	if [ -e "$skills_dir" ] || [ -L "$skills_dir" ]; then
		trash "$skills_dir"
	fi

	mkdir -p "$skills_dir"
	cli_group_begin "Stagewise skills"
	copy_skills "$skills_dir"
	cli_group_end
}

# Ensures ~/.codex/config.toml contains managed MCP server entries and the
# hooks feature flag. Existing entries for managed servers are replaced
# rather than duplicated, so this function is safe to run on every setup.
ensure_codex_config() {
	local config="$HOME/.codex/config.toml"
	local temp

	temp=$(mktemp)
	touch "$config"

	# Strip managed MCP server sections before re-appending them,
	# so re-running setup never creates duplicate entries.
	awk '
		/^\[mcp_servers\.codebase-memory-mcp(\.|\])/{ skip = 1; next }
		/^\[mcp_servers\.serena(\.|\])/{ skip = 1; next }
		/^\[mcp_servers\.mdn(\.|\])/{ skip = 1; next }
		/^\[/{ skip = 0 }
		!skip { print }
	' "$config" > "$temp"

	# Re-add managed MCP server entries with canonical config.
	printf '\n[mcp_servers.codebase-memory-mcp]\ncommand = "codebase-memory-mcp"\n' >> "$temp"
	printf '\n[mcp_servers.serena]\nstartup_timeout_sec = 15\ncommand = "serena"\nargs = ["start-mcp-server", "--project-from-cwd", "--context=codex"]\n' >> "$temp"

	# MDN docs/browser-compat server, shipped disabled: enable on request
	# when a browser-support or Baseline fact needs a live source.
	printf '\n[mcp_servers.mdn]\nurl = "https://mcp.mdn.mozilla.net/"\nenabled = false\n' >> "$temp"

	# Migrate the deprecated codex_hooks key to hooks, and ensure the hooks
	# feature flag is present in [features].
	if grep -q '^codex_hooks' "$temp"; then
		local temp2
		temp2=$(mktemp)
		sed 's/^codex_hooks = /hooks = /' "$temp" > "$temp2"
		mv "$temp2" "$temp"
	elif ! grep -q '^hooks' "$temp"; then
		local temp2
		temp2=$(mktemp)
		awk '/^\[features\]/{print; print "hooks = true"; next} 1' "$temp" > "$temp2"
		mv "$temp2" "$temp"
	fi

	if cmp -s "$config" "$temp"; then
		rm "$temp"
		cli_group_status muted "Codex config" "already configured"
		return
	fi

	if [ "${SKIP_BACKUP:-0}" = "1" ]; then
		mv "$temp" "$config"
		cli_group_status success "configured Codex MCP servers and hooks"
	else
		local backup="$config.bak.$(timestamp)"
		cp "$config" "$backup"
		mv "$temp" "$config"
		cli_group_status success "configured Codex MCP servers and hooks" "backup at $(display_path "$backup")"
	fi
}

# Configures git to use hooks/git/ as the hook directory for this repo.
# This installs the pre-push hook without touching ~/.git/hooks directly.
configure_git_hooks() {
	cli_section "Git hooks"

	if ! git -C "$REPO_DIR" config core.hooksPath hooks/git &>/dev/null; then
		cli_status warning "Could not set core.hooksPath" "not a git repo?"
		return
	fi

	cli_status success "git hooks path set" "hooks/git/"
}

prompt_target() {
	printf 'Which agent(s)? [1] Claude  [2] Codex  [3] Both: '
	read -r choice

	case "$choice" in
		1) printf 'claude' ;;
		2) printf 'codex' ;;
		3) printf 'both' ;;
		*) printf 'Invalid choice.\n' >&2; exit 1 ;;
	esac
}

target=""
sync_external=true
SKIP_BACKUP=0

while [ $# -gt 0 ]; do
	case "$1" in
		--claude)        target="claude" ;;
		--codex)         target="codex" ;;
		--both)          target="both" ;;
		--skip-external) sync_external=false ;;
		--no-backup)     SKIP_BACKUP=1 ;;
		--help)          usage; exit 0 ;;
		*)               usage >&2; exit 1 ;;
	esac
	shift
done

export SKIP_BACKUP

if [ -z "$target" ]; then
	target=$(prompt_target)
fi

bash "$REPO_DIR/scripts/install-cli-style.sh"
source "$REPO_DIR/scripts/lib/cli-style-output.sh"

if [ "$sync_external" = true ]; then
	if ! bash "$REPO_DIR/scripts/sync-external-skills.sh"; then
		cli_status warning "external skill sync failed" "continuing with existing local skills"
	fi
fi

bash "$REPO_DIR/scripts/sync.sh"

case "$target" in
	claude) setup_claude ;;
	codex)  setup_codex ;;
	both)   setup_claude; setup_codex ;;
esac

setup_stagewise
configure_git_hooks

printf '\n'
cli_status success "Done."
