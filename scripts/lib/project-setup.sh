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

	if cmp -s "$source" "$target"; then
		printf '  %s↪%s %s already up to date\n' "$PURPLE" "$RESET_COLOUR" "$label"
		return
	fi

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
}

# Symlinks a shared tool into the target project so every project tracks the central
# source. Replaces an existing plain copy, prompting first if that copy has diverged.
#
# @param  {string}  source
#     Absolute path to the central script.
# @param  {string}  target
#     Destination path in the project.
# @param  {string}  label
#     Human-readable name for output messages.
link_file() {
	local source="$1"
	local target="$2"
	local label="$3"

	if [ -L "$target" ]; then
		if [ "$(readlink "$target")" = "$source" ]; then
			printf '  %s↪%s %s already linked\n' "$PURPLE" "$RESET_COLOUR" "$label"
			return
		fi

		ln -sf "$source" "$target"
		printf '  %s✓%s relinked %s\n' "$GREEN" "$RESET_COLOUR" "$label"
		return
	fi

	if [ -e "$target" ] && ! cmp -s "$source" "$target"; then
		printf '\n  %s⚠%s %s exists as a local copy that differs from the default\n' "$PURPLE" "$RESET_COLOUR" "$label"
		printf '  Replace it with a symlink to the shared script? (y/n): '
		read -r response
		if [[ $response != y ]]; then
			printf '  %s↪%s kept local copy of %s\n\n' "$PURPLE" "$RESET_COLOUR" "$label"
			return
		fi
	fi

	ln -sf "$source" "$target"
	printf '  %s✓%s linked %s\n' "$GREEN" "$RESET_COLOUR" "$label"
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

# Links shared project-local agent tooling into the target project. Symlinks keep every
# project tracking the central source, so improvements and fixes propagate without re-copying.
copy_shared_agent_tools() {
	ensure_dir "$PROJECT_DIR/.agent/scripts" ".agent/scripts/"

	link_file "$REPO_DIR/scripts/project-diagnostics.py" "$PROJECT_DIR/.agent/scripts/project-diagnostics.py" ".agent/scripts/project-diagnostics.py"
	link_file "$REPO_DIR/scripts/validate/generated-file-guard.py" "$PROJECT_DIR/.agent/scripts/generated-file-guard.py" ".agent/scripts/generated-file-guard.py"
	link_file "$REPO_DIR/scripts/repo-context.py" "$PROJECT_DIR/.agent/scripts/repo-context.py" ".agent/scripts/repo-context.py"
	link_file "$REPO_DIR/scripts/validate/change-impact.py" "$PROJECT_DIR/.agent/scripts/change-impact.py" ".agent/scripts/change-impact.py"
}

# Prints the review warning for generated workspace files.
print_workspace_review_note() {
	printf '  %s!%s Review generated command safety, generated paths, and forbidden operations before relying on it.\n' "$YELLOW" "$RESET_COLOUR"
}

# Writes inferred workspace context when it does not already exist.
write_workspace_file() {
	local target="$PROJECT_DIR/WORKSPACE.md"
	local legacy="$PROJECT_DIR/AGENT_CAPABILITIES.md"

	if [ -e "$target" ] || [ -L "$target" ]; then
		printf '  %s↪%s %s already exists\n' "$PURPLE" "$RESET_COLOUR" "WORKSPACE.md"
		return
	fi

	"$REPO_DIR/scripts/init-workspace.py" --project-dir "$PROJECT_DIR" --write >/dev/null
	if [ -e "$legacy" ] || [ -L "$legacy" ]; then
		printf '  %s✓%s created %s; legacy %s remains for review\n' "$GREEN" "$RESET_COLOUR" "WORKSPACE.md" "AGENT_CAPABILITIES.md"
	else
		printf '  %s✓%s created %s\n' "$GREEN" "$RESET_COLOUR" "WORKSPACE.md"
	fi
	print_workspace_review_note
}

# Previews or writes inferred workspace context for the current project.
#
# @param  {string}  mode
#     preview, write, or force.
init_workspace() {
	local mode="$1"
	local args=("--project-dir" "$PROJECT_DIR")

	case "$mode" in
		preview) ;;
		write) args+=("--write") ;;
		force) args+=("--write" "--force") ;;
	esac

	"$REPO_DIR/scripts/init-workspace.py" "${args[@]}"
	if [ "$mode" != "preview" ]; then
		print_workspace_review_note
	fi
}
