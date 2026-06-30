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
		cli_group_status muted "$label" "already exists"
		return
	fi

	cp "$source" "$target"
	cli_group_status success "created" "$label"
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
		cli_group_status success "created" "$label"
		return
	fi

	if cmp -s "$source" "$target"; then
		cli_group_status muted "$label" "already up to date"
		return
	fi

	printf '\n'
	cli_group_status warning "$label" "exists locally but differs from the default"
	printf '  This usually means either:\n'
	printf '    • You have customised it for this project\n'
	printf '    • The default template has been updated\n\n'
	printf '  Overwrite with the default? (y/n): '
	read -r response
	if [[ $response == y ]]; then
		cp "$source" "$target"
		cli_group_status success "updated" "$label"
		printf '\n'
	else
		cli_group_status muted "skipped" "$label"
		printf '\n'
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
			cli_group_status muted "$label" "already linked"
			return
		fi

		ln -sf "$source" "$target"
		cli_group_status success "relinked" "$label"
		return
	fi

	if [ -e "$target" ] && ! cmp -s "$source" "$target"; then
		printf '\n'
		cli_group_status warning "$label" "exists as a local copy that differs from the default"
		printf '  Replace it with a symlink to the shared script? (y/n): '
		read -r response
		if [[ $response != y ]]; then
			cli_group_status muted "kept local copy of" "$label"
			printf '\n'
			return
		fi
	fi

	ln -sf "$source" "$target"
	cli_group_status success "linked" "$label"
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
		cli_group_status muted "$label" "already exists"
		return
	fi

	mkdir -p "$path"
	cli_group_status success "created" "$label"
}

# Copies Claude support files into the target project.
copy_claude_support_files() {
	cli_group_begin "Claude support files"
	ensure_dir "$PROJECT_DIR/.claude" ".claude/"

	sync_file "$REPO_DIR/templates/claude/.claudeignore" "$PROJECT_DIR/.claude/.claudeignore" ".claude/.claudeignore"
	cli_group_end
}

# Links shared project-local agent tooling into the target project. Symlinks keep every
# project tracking the central source, so improvements and fixes propagate without re-copying.
copy_shared_agent_tools() {
	cli_group_begin "Shared agent tools"
	ensure_dir "$PROJECT_DIR/.agent/scripts" ".agent/scripts/"

	link_file "$REPO_DIR/scripts/project-diagnostics.py" "$PROJECT_DIR/.agent/scripts/project-diagnostics.py" ".agent/scripts/project-diagnostics.py"
	link_file "$REPO_DIR/scripts/validate/generated-file-guard.py" "$PROJECT_DIR/.agent/scripts/generated-file-guard.py" ".agent/scripts/generated-file-guard.py"
	link_file "$REPO_DIR/scripts/repo-context.py" "$PROJECT_DIR/.agent/scripts/repo-context.py" ".agent/scripts/repo-context.py"
	link_file "$REPO_DIR/scripts/validate/change-impact.py" "$PROJECT_DIR/.agent/scripts/change-impact.py" ".agent/scripts/change-impact.py"
	cli_group_end
}

# Prints the review warning for generated workspace files.
print_workspace_review_note() {
	cli_group_status warning "Review generated command safety, generated paths, and forbidden operations before relying on it."
}

# Writes inferred workspace context when it does not already exist.
write_workspace_file() {
	local target="$PROJECT_DIR/WORKSPACE.md"
	local legacy="$PROJECT_DIR/AGENT_CAPABILITIES.md"

	if [ -e "$target" ] || [ -L "$target" ]; then
		cli_group_status muted "WORKSPACE.md" "already exists"
		return
	fi

	"$REPO_DIR/scripts/init-workspace.py" --project-dir "$PROJECT_DIR" --write >/dev/null
	if [ -e "$legacy" ] || [ -L "$legacy" ]; then
		cli_group_status success "created WORKSPACE.md" "legacy AGENT_CAPABILITIES.md remains for review"
	else
		cli_group_status success "created" "WORKSPACE.md"
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
