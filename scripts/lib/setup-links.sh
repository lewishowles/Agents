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
			cli_group_status warning "replaced" "$label"
		else
			local backup
			backup=$(backup_path "$path")
			mkdir -p "$path"
			cli_group_status warning "replaced $label" "backup at $(display_path "$backup")"
		fi
	else
		mkdir -p "$path"
	fi
}

# Removes stale or repo-owned symlinks in a directory.
# Symlinks pointing elsewhere are left alone.
#
# @param  {string}  dir
#     Directory to scan.
# @param  {string}  repo_prefix
#     Only prune links whose target starts with this path.
# @param  {string}  label
#     Human-readable name used in output messages.
# @param  {string}  remove_all
#     Set to 1 to remove all repo-owned links, including valid links.
prune_stale_repo_links() {
	local dir="$1"
	local repo_prefix="$2"
	local label="$3"
	local remove_all="${4:-0}"

	[ -d "$dir" ] || return 0

	local link target
	for link in "$dir"/*; do
		[ -L "$link" ] || continue
		target=$(readlink "$link")
		if [[ "$target" == "$repo_prefix"* ]] && {
			[ "$remove_all" = "1" ] || [ ! -e "$link" ]
		}; then
			trash "$link"
			if [ "$remove_all" = "1" ]; then
				cli_group_status warning "removed repo-owned" "$label/$(basename "$link")"
			else
				cli_group_status warning "removed stale" "$label/$(basename "$link")"
			fi
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
			cli_group_status muted "$label" "already linked"
			return
		fi

		if [ "${SKIP_BACKUP:-0}" = "1" ]; then
			rm "$target"
			ln -s "$source" "$target"
			cli_group_status warning "relinked" "$label"
		else
			local backup
			backup=$(backup_path "$target")
			ln -s "$source" "$target"
			cli_group_status warning "relinked $label" "backup at $(display_path "$backup")"
		fi
	elif [ -e "$target" ]; then
		if [ "${SKIP_BACKUP:-0}" = "1" ]; then
			rm -rf "$target"
			ln -s "$source" "$target"
			cli_group_status warning "replaced" "$label"
		else
			local backup
			backup=$(backup_path "$target")
			ln -s "$source" "$target"
			cli_group_status warning "replaced $label" "backup at $(display_path "$backup")"
		fi
	else
		ln -s "$source" "$target"
		cli_group_status success "linked" "$label"
	fi
}

# Links all generated runtime skills into the given target directory.
# Skills listed in STAGEWISE_ONLY_SKILLS are skipped — they are distributed
# to Stagewise only via copy_skills(), not symlinked into Claude or Codex.
#
# @param  {string}  target_dir
#     The directory to install skill symlinks into.
link_skills() {
	local target_dir="$1"
	local skill slug

	local STAGEWISE_ONLY_SKILLS=(global-rules)

	for skill in "$REPO_DIR"/dist/skills/*; do
		[ -d "$skill" ] || continue
		slug=$(basename "$skill")

		local skip=false
		local excluded
		for excluded in "${STAGEWISE_ONLY_SKILLS[@]}"; do
			if [ "$slug" = "$excluded" ]; then
				skip=true
				break
			fi
		done

		if [ "$skip" = true ]; then
			cli_group_status skipped "Stagewise-only skill" "$slug"
			continue
		fi

		link_path "$skill" "$target_dir/$slug" "skills/$slug"
	done
}

# Copies all generated runtime skills into the given target directory.
#
# @param  {string}  target_dir
#     The directory to copy skills into.
copy_skills() {
	local target_dir="$1"
	local skill

	for skill in "$REPO_DIR"/dist/skills/*; do
		[ -d "$skill" ] || continue
		cp -R "$skill" "$target_dir/$(basename "$skill")"
		cli_group_status success "copied" "skills/$(basename "$skill")"
	done
}
