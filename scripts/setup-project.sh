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

usage() {
	local script_name
	script_name="$(basename "$0")"

	printf '\n%s\n\n' "Usage: $script_name [command]"
	printf 'Project setup:\n'
	printf '  %-22s %s\n' '--claude' 'Create Claude project files'
	printf '  %-22s %s\n' '--codex' 'Create Codex project files'
	printf '  %-22s %s\n\n' '--both' 'Create shared Claude + Codex project files'
	printf 'Capabilities:\n'
	printf '  %-22s %s\n' '--init-capabilities' 'Preview AGENT_CAPABILITIES.md for the current project'
	printf '  %-22s %s\n' '--write-capabilities' 'Write AGENT_CAPABILITIES.md when it is missing'
	printf '  %-22s %s\n\n' '--force-capabilities' 'Refresh AGENT_CAPABILITIES.md after review'
	printf 'Examples:\n'
	printf '  cd /path/to/project\n'
	printf '  %s --init-capabilities\n\n' "$script_name"
}

# Copies a template to target only if target does not already exist.
#
# @param  {string}  source  Template file path.
# @param  {string}  target
#     Destination path in the project.
# @param  {string}  label
#     Human-readable name for output messages.
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

# Copies a template to target, or prompts the user before overwriting a file
# that exists locally but differs from the template. This handles the case
# where a project has customised a file that the template has since updated.
#
# @param  {string}  source  Template file path.
# @param  {string}  target
#     Destination path in the project.
# @param  {string}  label
#     Human-readable name for output messages.
sync_file() {
	local source="$1"
	local target="$2"
	local label="$3"

	if ! [ -e "$target" ] && ! [ -L "$target" ]; then
		cp "$source" "$target"
		printf '  %s✓%s created %s\n' "$GREEN" "$RESET_COLOUR" "$label"
		return
	fi

	if ! cmp -s "$source" "$target"; then
		printf '\n  %s⚠%s %s exists locally but differs from the default\n' "$PURPLE" "$RESET_COLOUR" "$label"
		printf '  This usually means either:\n'
		printf '    • You have customised it for this project\n'
		printf '    • The default template has been updated\n\n'
		printf '  Overwrite with the default? (y/n): '
		read -r response
		if [[ $response == y ]]; then
			cp "$source" "$target"
			printf '  %s✓%s updated %s\n\n' "$GREEN" "$RESET_COLOUR" "$label"
		else
			printf '  %s↪%s skipped %s\n\n' "$PURPLE" "$RESET_COLOUR" "$label"
		fi
	fi
}

# Creates a directory at path if it doesn't already exist.
#
# @param  {string}  path  Directory to create.
# @param  {string}  label
#     Human-readable name for output messages.
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

	sync_file "$REPO_DIR/templates/claude/.claudeignore" "$PROJECT_DIR/.claude/.claudeignore" ".claude/.claudeignore"
}

# Writes an inferred capability manifest when one does not already exist.
#
write_capabilities_file() {
	local target="$PROJECT_DIR/AGENT_CAPABILITIES.md"

	if [ -e "$target" ] || [ -L "$target" ]; then
		printf '  %s↪%s %s already exists\n' "$PURPLE" "$RESET_COLOUR" "AGENT_CAPABILITIES.md"
		return
	fi

	"$REPO_DIR/scripts/init-capabilities.py" --project-dir "$PROJECT_DIR" --write >/dev/null
	printf '  %s✓%s created %s\n' "$GREEN" "$RESET_COLOUR" "AGENT_CAPABILITIES.md"
}

# Previews or writes an inferred capability manifest for the current project.
#
# @param  {string}  mode
#     preview, write, or force.
init_capabilities() {
	local mode="$1"
	local args=("--project-dir" "$PROJECT_DIR")

	case "$mode" in
		preview) ;;
		write) args+=("--write") ;;
		force) args+=("--write" "--force") ;;
	esac

	"$REPO_DIR/scripts/init-capabilities.py" "${args[@]}"
}

setup_claude() {
	printf '\n→ Setting up Claude (project)\n\n'
	copy_file "$REPO_DIR/templates/claude/AGENTS.md.template" "$PROJECT_DIR/AGENTS.md" "AGENTS.md"
	write_capabilities_file
	copy_claude_support_files
}

setup_codex() {
	printf '\n→ Setting up Codex (project)\n\n'
	copy_file "$REPO_DIR/templates/codex/AGENTS.md.template" "$PROJECT_DIR/AGENTS.md" "AGENTS.md"
	write_capabilities_file
}

setup_both() {
	printf '\n→ Setting up Claude + Codex (project)\n\n'
	copy_file "$REPO_DIR/templates/shared/AGENTS.md.template" "$PROJECT_DIR/AGENTS.md" "AGENTS.md"
	write_capabilities_file
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
	--init-capabilities)  target="init-capabilities" ;;
	--write-capabilities) target="write-capabilities" ;;
	--force-capabilities) target="force-capabilities" ;;
	--help|-h)            usage; exit 0 ;;
	"")                  target=$(prompt_target) ;;
	*)                   usage >&2; exit 1 ;;
esac

case "$target" in
	claude)             setup_claude ;;
	codex)              setup_codex ;;
	both)               setup_both ;;
	init-capabilities)  init_capabilities preview; exit ;;
	write-capabilities) init_capabilities write ;;
	force-capabilities) init_capabilities force ;;
esac

printf '\nDone.\n'
