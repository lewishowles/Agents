#!/usr/bin/env bash
# Installs global agent configuration into Claude and Codex via symlinks.

set -euo pipefail

# Resolved at startup so aliases can call this script from any directory.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$REPO_DIR/scripts/lib/setup-links.sh"

usage() {
	printf 'Usage: %s [--claude|--codex|--both] [--skip-external]\n' "$(basename "$0")"
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
	link_path "$REPO_DIR/dist/claude/statusline.sh" "$HOME/.claude/statusline.sh" "statusline.sh"
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
	ensure_container_dir "$HOME/.codex/hooks" "~/.codex/hooks"
	cli_group_end

	cli_group_begin "Codex files"
	link_path "$REPO_DIR/dist/codex/AGENTS.md" "$HOME/.agents/AGENTS.md" "AGENTS.md"
	link_path "$REPO_DIR/dist/codex/AGENTS.md" "$HOME/.codex/AGENTS.md" "Codex AGENTS.md"
	link_path "$REPO_DIR/dist/codex/hooks.json" "$HOME/.codex/hooks.json" "Codex hooks"
	link_path "$REPO_DIR/dist/codex/hooks/tool-call-checkpoint.sh" "$HOME/.codex/hooks/tool-call-checkpoint.sh" "Codex tool-call checkpoint"
	ensure_codex_config
	cli_group_end

	cli_group_begin "Codex skills"
	prune_stale_repo_links "$HOME/.agents/skills" "$REPO_DIR" "skills"
	prune_stale_repo_links "$HOME/.codex/skills" "$REPO_DIR" "legacy skills" "1"
	link_skills "$HOME/.agents/skills"
	cli_group_end
}

# Ensures the Codex TUI uses the managed status line while preserving all
# unrelated TUI preferences.
#
# @param  {string}  config
#     Codex config file to update.
ensure_codex_status_line() {
	local config="$1"
	local temp

	temp=$(mktemp)
	awk '
		BEGIN {
			in_tui = 0
			tui_found = 0
		}
		/^\[tui\]$/ {
			print
			print "status_line = [\"run-state\", \"project-name\", \"used-tokens\", \"context-used\", \"five-hour-limit\", \"weekly-limit\", \"model-with-reasoning\"]"
			print "status_line_use_colors = true"
			in_tui = 1
			tui_found = 1
			next
		}
		/^\[/ { in_tui = 0 }
		in_tui && /^status_line(_use_colors)?[[:space:]]*=/ { next }
		{ print }
		END {
			if (!tui_found) {
				print ""
				print "[tui]"
				print "status_line = [\"run-state\", \"project-name\", \"used-tokens\", \"context-used\", \"five-hour-limit\", \"weekly-limit\", \"model-with-reasoning\"]"
				print "status_line_use_colors = true"
			}
		}
	' "$config" > "$temp"
	mv "$temp" "$config"
}

# Sets the root-level Codex defaults while preserving unrelated configuration.
#
# @param  {string}  source
#     Existing Codex config file to read.
# @param  {string}  destination
#     Temporary file that receives the updated configuration.
ensure_codex_defaults() {
	local source="$1" destination="$2"

	awk '
		function print_defaults() {
			print "approval_policy = \"never\""
			print "sandbox_mode = \"workspace-write\""
		}
		BEGIN {
			in_root = 1
			defaults_written = 0
		}
		/^\[/ {
			if (in_root) {
				print_defaults()
				defaults_written = 1
				in_root = 0
			}
			print
			next
		}
		in_root && /^(approval_policy|sandbox_mode)[[:space:]]*=/ { next }
		{ print }
		END {
			if (!defaults_written) {
				print_defaults()
			}
		}
	' "$source" > "$destination"
}

# Ensures the workspace-write sandbox allows outbound network access while
# preserving its other settings.
#
# @param  {string}  config
#     Codex configuration file to update.
ensure_codex_workspace_network() {
	local config="$1"
	local temp

	temp=$(mktemp)
	awk '
		BEGIN {
			in_workspace_write = 0
			workspace_write_found = 0
		}
		/^\[sandbox_workspace_write\]$/ {
			print
			print "network_access = true"
			in_workspace_write = 1
			workspace_write_found = 1
			next
		}
		/^\[/ { in_workspace_write = 0 }
		in_workspace_write && /^network_access[[:space:]]*=/ { next }
		{ print }
		END {
			if (!workspace_write_found) {
				print ""
				print "[sandbox_workspace_write]"
				print "network_access = true"
			}
		}
	' "$config" > "$temp"
	mv "$temp" "$config"
}

# Removes inline Codex hook definitions while preserving user configuration
# and Codex-managed hook trust state. Hooks are defined in hooks.json.
#
# @param  {string}  source
#     Existing Codex config file to read.
# @param  {string}  destination
#     Temporary file that receives the configuration without inline hooks.
remove_inline_codex_hooks() {
	local source="$1" destination="$2"

	awk '
		/^\[\[hooks\./ { skip = 1; next }
		/^\[hooks\.state/ { skip = 0 }
		/^\[/ && skip { skip = 0 }
		!skip { print }
	' "$source" > "$destination"
}

# Ensures ~/.codex/config.toml contains the managed defaults, MCP server
# entries, hooks feature flag, and TUI status line. Legacy inline hooks are
# removed so Codex uses the managed hooks.json file.
ensure_codex_config() {
	local config="$HOME/.codex/config.toml"
	local defaults_temp temp

	defaults_temp=$(mktemp)
	temp=$(mktemp)
	touch "$config"
	ensure_codex_defaults "$config" "$defaults_temp"

	# Strip managed MCP server sections before re-appending them,
	# so re-running setup never creates duplicate entries.
	awk '
		/^\[mcp_servers\.codebase-memory-mcp(\.|\])/{ skip = 1; next }
		/^\[mcp_servers\.serena(\.|\])/{ skip = 1; next }
		/^\[mcp_servers\.mdn(\.|\])/{ skip = 1; next }
		/^\[/{ skip = 0 }
		!skip { print }
	' "$defaults_temp" > "$temp"
	rm "$defaults_temp"

	# Re-add managed MCP server entries with canonical config.
	printf '\n[mcp_servers.codebase-memory-mcp]\ncommand = "codebase-memory-mcp"\ndefault_tools_approval_mode = "approve"\n' >> "$temp"
	printf '\n[mcp_servers.serena]\nstartup_timeout_sec = 15\ncommand = "serena"\nargs = ["start-mcp-server", "--project-from-cwd", "--context=codex"]\ndefault_tools_approval_mode = "approve"\n' >> "$temp"

	# MDN docs/browser-compat server, shipped disabled: enable on request
	# when a browser-support or Baseline fact needs a live source.
	printf '\n[mcp_servers.mdn]\nurl = "https://mcp.mdn.mozilla.net/"\nenabled = false\n' >> "$temp"
	ensure_codex_workspace_network "$temp"
	ensure_codex_status_line "$temp"

	local hooks_temp
	hooks_temp=$(mktemp)
	remove_inline_codex_hooks "$temp" "$hooks_temp"
	mv "$hooks_temp" "$temp"

	# Migrate the deprecated codex_hooks key to hooks, and ensure the hooks
	# feature flag is present in [features].
	if grep -q '^codex_hooks' "$temp"; then
		local temp2
		temp2=$(mktemp)
		sed 's/^codex_hooks = /hooks = /' "$temp" > "$temp2"
		mv "$temp2" "$temp"
	elif ! grep -q '^\[features\]' "$temp"; then
		printf '\n[features]\nhooks = true\n' >> "$temp"
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

	local backup
	backup=$(backup_path "$config")
	mv "$temp" "$config"
	cli_group_status success "configured Codex MCP servers and hooks" "backup at $(display_path "$backup")"
}

# Configures git to use src/hooks/git/ as the hook directory for this repo.
# This installs the pre-push hook without touching ~/.git/hooks directly.
configure_git_hooks() {
	cli_section "Git hooks"

	if ! git -C "$REPO_DIR" config core.hooksPath src/hooks/git &>/dev/null; then
		cli_status warning "Could not set core.hooksPath" "not a git repo?"
		return
	fi

	cli_status success "git hooks path set" "src/hooks/git/"
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

configure_git_hooks

printf '\n'
cli_status success "Done."
