#!/usr/bin/env bash

set -euo pipefail

# Resolve the script's directory, then the repo root, so aliases can call this
# script from anywhere.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$REPO_DIR/scripts/lib/colours.sh"

usage() {
	printf 'Usage: %s [--claude|--codex|--both] [--skip-external]\n' "$(basename "$0")"
}

timestamp() {
	date '+%Y%m%d-%H%M%S'
}

backup_path() {
	local path="$1"
	local backup="${path}.bak"

	case "$path" in
		"$HOME/.claude/skills/"*) backup="$HOME/.claude/backups/skills/$(basename "$path").bak" ;;
		"$HOME/.claude/hooks/"*) backup="$HOME/.claude/backups/hooks/$(basename "$path").bak" ;;
		"$HOME/.claude/commands/"*) backup="$HOME/.claude/backups/commands/$(basename "$path").bak" ;;
		"$HOME/.agents/skills/"*) backup="$HOME/.agents/backups/skills/$(basename "$path").bak" ;;
	esac

	# Preserve existing backups by adding a timestamp only when needed.
	if [ -e "$backup" ] || [ -L "$backup" ]; then
		backup="${backup}.$(timestamp)"
	fi

	mkdir -p "$(dirname "$backup")"
	mv "$path" "$backup"
	printf '%s' "$backup"
}

display_path() {
	local path="$1"

	case "$path" in
		"$HOME"/*) printf '~/%s' "${path#"$HOME"/}" ;;
		*) printf '%s' "$path" ;;
	esac
}

ensure_container_dir() {
	local path="$1"
	local label="$2"

	# Container paths must be real directories so per-item symlinks can coexist.
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

link_path() {
	local source="$1"
	local target="$2"
	local label="$3"

	# Existing files are backed up, never overwritten in place.
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

setup_claude() {
	printf '\n→ Setting up Claude (global)\n\n'

	ensure_container_dir "$HOME/.claude" "~/.claude"
	ensure_container_dir "$HOME/.claude/skills" "skills"
	ensure_container_dir "$HOME/.claude/hooks" "hooks"
	ensure_container_dir "$HOME/.claude/commands" "commands"

	link_path "$REPO_DIR/dist/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md" "CLAUDE.md"
	link_path "$REPO_DIR/dist/claude/settings.json" "$HOME/.claude/settings.json" "settings.json"
	link_path "$REPO_DIR/dist/claude/.mcp.json" "$HOME/.claude/.mcp.json" ".mcp.json"

	# Link each skill and hook individually so plugin-installed items can coexist.
	local skill
	for skill in "$REPO_DIR"/skills/*; do
		[ -d "$skill" ] || continue
		link_path "$skill" "$HOME/.claude/skills/$(basename "$skill")" "skills/$(basename "$skill")"
	done

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

	link_path "$REPO_DIR/dist/codex/AGENTS.md" "$HOME/.agents/AGENTS.md" "AGENTS.md"
	link_path "$REPO_DIR/dist/codex/AGENTS.md" "$HOME/.codex/AGENTS.md" "Codex AGENTS.md"
	ensure_codex_config

	# Keep legacy ~/.agents wiring and current Codex ~/.codex instructions in sync.
	local skill
	for skill in "$REPO_DIR"/skills/*; do
		[ -d "$skill" ] || continue
		link_path "$skill" "$HOME/.agents/skills/$(basename "$skill")" "skills/$(basename "$skill")"
	done
}

ensure_codex_config() {
	local config="$HOME/.codex/config.toml"
	local temp

	temp=$(mktemp)
	touch "$config"

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
		--claude) target="claude" ;;
		--codex) target="codex" ;;
		--both) target="both" ;;
		--skip-external) sync_external=false ;;
		--help) usage; exit 0 ;;
		*) usage >&2; exit 1 ;;
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
	codex) setup_codex ;;
	both) setup_claude; setup_codex ;;
esac

printf '\nDone.\n'
