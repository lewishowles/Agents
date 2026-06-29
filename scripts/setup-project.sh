#!/usr/bin/env bash
# Scaffolds agent configuration files into a project directory.
# Copies templates for the chosen agent runtime and prompts before
# overwriting any file that already exists but differs from the template.

set -euo pipefail

# Resolved at startup so aliases can call this script from any project directory.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
PROJECT_DIR=$(pwd)

source "$REPO_DIR/scripts/lib/colours.sh"
source "$REPO_DIR/scripts/lib/cli-style-output.sh"
source "$REPO_DIR/scripts/lib/project-setup.sh"

usage() {
	local script_name
	script_name="$(basename "$0")"

	printf '\n%s\n\n' "Usage: $script_name [command]"
	printf 'Project setup:\n'
	printf '  %-22s %s\n' '--claude' 'Create Claude project files'
	printf '  %-22s %s\n' '--codex' 'Create Codex project files'
	printf '  %-22s %s\n\n' '--both' 'Create shared Claude + Codex project files'
	printf 'Workspace:\n'
	printf '  %-22s %s\n' '--init-workspace' 'Preview WORKSPACE.md for the current project'
	printf '  %-22s %s\n' '--write-workspace' 'Write WORKSPACE.md when it is missing'
	printf '  %-22s %s\n\n' '--force-workspace' 'Refresh WORKSPACE.md after review'
	printf 'Examples:\n'
	printf '  cd /path/to/project\n'
	printf '  %s --init-workspace\n\n' "$script_name"
}

setup_claude() {
	printf '\n'
	cli_status info "Setting up Claude" "(project)"
	printf '\n'
	copy_file "$REPO_DIR/templates/claude/AGENTS.md.template" "$PROJECT_DIR/AGENTS.md" "AGENTS.md"
	copy_shared_agent_tools
	write_workspace_file
	copy_claude_support_files
}

setup_codex() {
	printf '\n'
	cli_status info "Setting up Codex" "(project)"
	printf '\n'
	copy_file "$REPO_DIR/templates/codex/AGENTS.md.template" "$PROJECT_DIR/AGENTS.md" "AGENTS.md"
	copy_shared_agent_tools
	write_workspace_file
}

setup_both() {
	printf '\n'
	cli_status info "Setting up Claude + Codex" "(project)"
	printf '\n'
	copy_file "$REPO_DIR/templates/shared/AGENTS.md.template" "$PROJECT_DIR/AGENTS.md" "AGENTS.md"
	copy_shared_agent_tools
	write_workspace_file
	copy_claude_support_files
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
	--claude)             target="claude" ;;
	--codex)              target="codex" ;;
	--both)               target="both" ;;
	--init-workspace)     target="init-workspace" ;;
	--write-workspace)    target="write-workspace" ;;
	--force-workspace)    target="force-workspace" ;;
	--init-capabilities)  target="init-workspace" ;;
	--write-capabilities) target="write-workspace" ;;
	--force-capabilities) target="force-workspace" ;;
	--help|-h)            usage; exit 0 ;;
	"")                  target=$(prompt_target) ;;
	*)                   usage >&2; exit 1 ;;
esac

case "$target" in
	claude)             setup_claude ;;
	codex)              setup_codex ;;
	both)               setup_both ;;
	init-workspace)  init_workspace preview; exit ;;
	write-workspace) init_workspace write ;;
	force-workspace) init_workspace force ;;
esac

printf '\n'
cli_status success "Done."
