#!/usr/bin/env bash
# Installs global agent configuration by symlinking dist/ output and skills
# into ~/.claude/ and/or ~/.agents/. Safe to re-run — existing links are
# backed up rather than overwritten, and stale links are pruned automatically.

set -euo pipefail

# Resolved at startup so aliases can call this script from any directory.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$REPO_DIR/scripts/lib/colours.sh"

usage() {
	printf 'Usage: %s [--claude|--codex|--both] [--skip-external]\n' "$(basename "$0")"
}

# Produces a timestamp string used to make backup filenames unique.
timestamp() {
	date '+%Y%m%d-%H%M%S'
}

# Moves a file to its backup location and prints the backup path.
# Backup paths are routed by prefix so each agent's backups stay separate.
# If a backup already exists, a timestamp suffix is added to avoid collision.
# @param  string  path  The file or symlink to back up.
backup_path() {
	local path="$1"
	local backup="${path}.bak"

	case "$path" in
		"$HOME/.claude/skills/"*)   backup="$HOME/.claude/backups/skills/$(basename "$path").bak" ;;
		"$HOME/.claude/hooks/"*)    backup="$HOME/.claude/backups/hooks/$(basename "$path").bak" ;;
		"$HOME/.claude/commands/"*) backup="$HOME/.claude/backups/commands/$(basename "$path").bak" ;;
		"$HOME/.agents/skills/"*)   backup="$HOME/.agents/backups/skills/$(basename "$path").bak" ;;
		"$HOME/.codex/skills/"*)    backup="$HOME/.codex/backups/skills/$(basename "$path").bak" ;;
	esac

	if [ -e "$backup" ] || [ -L "$backup" ]; then
		backup="${backup}.$(timestamp)"
	fi

	mkdir -p "$(dirname "$backup")"
	mv "$path" "$backup"
	printf '%s' "$backup"
}

# Prints a path with $HOME replaced by ~ for readable terminal output.
# @param  string  path  The absolute path to display.
display_path() {
	local path="$1"

	case "$path" in
		"$HOME"/*) printf '~/%s' "${path#"$HOME"/}" ;;
		*) printf '%s' "$path" ;;
	esac
}

# Ensures a directory exists as a real directory, not a symlink.
# Per-item symlinks inside the directory need the parent to be a real dir,
# otherwise the OS can't resolve sibling links independently.
# @param  string  path   The directory path to ensure.
# @param  string  label  Human-readable name for output messages.
ensure_container_dir() {
	local path="$1"
	local label="$2"

	if [ -L "$path" ]; then
		local backup
		backup=$(backup_path "$path")
		mkdir -p "$path"
		printf '  %s⟳%s replaced %s (backup at %s)\n' "$YELLOW" "$RESET_COLOUR" "$label" "$(display_path "$backup")"
	elif [ -e "$path" ] && [ ! -d "$path" ]; then
		local backup
		backup=$(backup_path "$path")
		mkdir -p "$path"
		printf '  %s⟳%s replaced %s (backup at %s)\n' "$YELLOW" "$RESET_COLOUR" "$label" "$(display_path "$backup")"
	else
		mkdir -p "$path"
	fi
}

# Removes broken symlinks in a directory that point into this repo.
# Symlinks pointing elsewhere (e.g. plugin-installed skills) are left alone.
# @param  string  dir          Directory to scan.
# @param  string  repo_prefix  Only prune links whose target starts with this path.
# @param  string  label        Human-readable name used in output messages.
prune_stale_repo_links() {
	local dir="$1"
	local repo_prefix="$2"
	local label="$3"

	[ -d "$dir" ] || return 0

	local link target
	for link in "$dir"/*; do
		[ -L "$link" ] || continue
		target=$(readlink "$link")
		if [[ "$target" == "$repo_prefix"* ]] && [ ! -e "$link" ]; then
			rm "$link"
			printf '  %s−%s removed stale %s\n' "$YELLOW" "$RESET_COLOUR" "$label/$(basename "$link")"
		fi
	done
}

# Creates a symlink from source to target. If a symlink already exists at
# target pointing to the same source, it is left unchanged. Any other existing
# file or symlink is backed up first.
# @param  string  source  The file or directory to link to.
# @param  string  target  The symlink path to create.
# @param  string  label   Human-readable name for output messages.
link_path() {
	local source="$1"
	local target="$2"
	local label="$3"

	if [ -L "$target" ]; then
		local current
		current=$(readlink "$target")

		if [ "$current" = "$source" ]; then
			printf '  %s↪%s %s already linked\n' "$PURPLE" "$RESET_COLOUR" "$label"
			return
		fi

		local backup
		backup=$(backup_path "$target")
		ln -s "$source" "$target"
		printf '  %s⟳%s relinked %s (backup at %s)\n' "$YELLOW" "$RESET_COLOUR" "$label" "$(display_path "$backup")"
	elif [ -e "$target" ]; then
		local backup
		backup=$(backup_path "$target")
		ln -s "$source" "$target"
		printf '  %s⟳%s replaced %s (backup at %s)\n' "$YELLOW" "$RESET_COLOUR" "$label" "$(display_path "$backup")"
	else
		ln -s "$source" "$target"
		printf '  %s✓%s linked %s\n' "$GREEN" "$RESET_COLOUR" "$label"
	fi
}

# Links all skills from this repo into the given target directory.
# Handles both flat skills (skills/<name>/) and grouped skills
# (skills/<group>/<name>/), installing each under its own name.
# @param  string  target_dir  The directory to install skill symlinks into.
link_skills() {
	local target_dir="$1"
	local skill sub

	for skill in "$REPO_DIR"/skills/*; do
		[ -d "$skill" ] || continue
		if [ -f "$skill/SKILL.md" ]; then
			link_path "$skill" "$target_dir/$(basename "$skill")" "skills/$(basename "$skill")"
		else
			for sub in "$skill"/*/; do
				[ -d "$sub" ] || continue
				link_path "$sub" "$target_dir/$(basename "$sub")" "skills/$(basename "$skill")/$(basename "$sub")"
			done
		fi
	done
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

printf '\nDone.\n'
