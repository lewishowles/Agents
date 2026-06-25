#!/usr/bin/env bash
# Shared symlink and backup helpers for setup scripts.

# Produces a timestamp string used to make backup filenames unique.
timestamp() {
	date '+%Y%m%d-%H%M%S'
}

# Moves a file to its backup location and prints the backup path.
# Backup paths are routed by prefix so each agent's backups stay separate.
# If a backup already exists, a timestamp suffix is added to avoid collision.
#
# @param  {string}  path
#     The file or symlink to back up.
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
#
# @param  {string}  path
#     The absolute path to display.
display_path() {
	local path="$1"

	case "$path" in
		"$HOME"/*) printf '~/%s' "${path#"$HOME"/}" ;;
		*) printf '%s' "$path" ;;
	esac
}

# Ensures a directory exists as a real directory, not a symlink.
# Per-item symlinks inside the directory need the parent to be a real dir.
#
# @param  {string}  path
#     The directory path to ensure.
# @param  {string}  label
#     Human-readable name for output messages.
ensure_container_dir() {
	local path="$1"
	local label="$2"

	if [ -L "$path" ] || { [ -e "$path" ] && [ ! -d "$path" ]; }; then
		if [ "${SKIP_BACKUP:-0}" = "1" ]; then
			rm -rf "$path"
			mkdir -p "$path"
			printf '  %s⟳%s replaced %s\n' "$YELLOW" "$RESET_COLOUR" "$label"
		else
			local backup
			backup=$(backup_path "$path")
			mkdir -p "$path"
			printf '  %s⟳%s replaced %s (backup at %s)\n' "$YELLOW" "$RESET_COLOUR" "$label" "$(display_path "$backup")"
		fi
	else
		mkdir -p "$path"
	fi
}

# Removes broken symlinks in a directory that point into this repo.
# Symlinks pointing elsewhere are left alone.
#
# @param  {string}  dir
#     Directory to scan.
# @param  {string}  repo_prefix
#     Only prune links whose target starts with this path.
# @param  {string}  label
#     Human-readable name used in output messages.
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

# Creates a symlink from source to target, backing up any conflicting path.
#
# @param  {string}  source
#     The file or directory to link to.
# @param  {string}  target
#     The symlink path to create.
# @param  {string}  label
#     Human-readable name for output messages.
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

		if [ "${SKIP_BACKUP:-0}" = "1" ]; then
			rm "$target"
			ln -s "$source" "$target"
			printf '  %s⟳%s relinked %s\n' "$YELLOW" "$RESET_COLOUR" "$label"
		else
			local backup
			backup=$(backup_path "$target")
			ln -s "$source" "$target"
			printf '  %s⟳%s relinked %s (backup at %s)\n' "$YELLOW" "$RESET_COLOUR" "$label" "$(display_path "$backup")"
		fi
	elif [ -e "$target" ]; then
		if [ "${SKIP_BACKUP:-0}" = "1" ]; then
			rm -rf "$target"
			ln -s "$source" "$target"
			printf '  %s⟳%s replaced %s\n' "$YELLOW" "$RESET_COLOUR" "$label"
		else
			local backup
			backup=$(backup_path "$target")
			ln -s "$source" "$target"
			printf '  %s⟳%s replaced %s (backup at %s)\n' "$YELLOW" "$RESET_COLOUR" "$label" "$(display_path "$backup")"
		fi
	else
		ln -s "$source" "$target"
		printf '  %s✓%s linked %s\n' "$GREEN" "$RESET_COLOUR" "$label"
	fi
}

# Links all skills from this repo into the given target directory.
# Handles both flat skills and grouped skills.
#
# @param  {string}  target_dir
#     The directory to install skill symlinks into.
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

# Copies all skills from this repo into the given target directory.
# Handles both flat skills and grouped skills.
#
# @param  {string}  target_dir
#     The directory to copy skills into.
copy_skills() {
	local target_dir="$1"
	local skill sub

	for skill in "$REPO_DIR"/skills/*; do
		[ -d "$skill" ] || continue
		if [ -f "$skill/SKILL.md" ]; then
			cp -R "$skill" "$target_dir/$(basename "$skill")"
			printf '  %s✓%s copied skills/%s\n' "$GREEN" "$RESET_COLOUR" "$(basename "$skill")"
		else
			for sub in "$skill"/*/; do
				[ -d "$sub" ] || continue
				cp -R "$sub" "$target_dir/$(basename "$sub")"
				printf '  %s✓%s copied skills/%s/%s\n' "$GREEN" "$RESET_COLOUR" "$(basename "$skill")" "$(basename "$sub")"
			done
		fi
	done
}
