#!/usr/bin/env bash
# Shared helpers for project setup commands.

# Copies a template to target only if target does not already exist.
#
# @param  {string}  source
#     Template file path.
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

# Copies a template to target, or prompts before overwriting a changed file.
#
# @param  {string}  source
#     Template file path.
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
# @param  {string}  path
#     Directory to create.
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

# Copies Claude support files into the target project.
copy_claude_support_files() {
	ensure_dir "$PROJECT_DIR/.claude" ".claude/"

	sync_file "$REPO_DIR/templates/claude/.claudeignore" "$PROJECT_DIR/.claude/.claudeignore" ".claude/.claudeignore"
}

# Writes an inferred capability manifest when one does not already exist.
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
