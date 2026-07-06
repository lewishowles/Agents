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

# Reports project setup state without modifying any files. Detects the
# configured mode from AGENTS.md content, then checks AGENTS.md template
# match, WORKSPACE.md presence, .agent/scripts symlink targets, Claude
# support files (claude/both only), and unexpected runtime directories.
check_status() {
	local agents_md="$PROJECT_DIR/AGENTS.md"
	local workspace_md="$PROJECT_DIR/WORKSPACE.md"
	local detected_mode=""

	# Detect mode from AGENTS.md body text.
	if [ -f "$agents_md" ]; then
		if grep -Fq "Claude Code and Codex" "$agents_md"; then
			detected_mode="both"
		elif grep -Fq "Claude Code" "$agents_md"; then
			detected_mode="claude"
		elif grep -Fq "Codex" "$agents_md"; then
			detected_mode="codex"
		fi
	fi

	cli_section "Project setup status" "$PROJECT_DIR"

	if [ -z "$detected_mode" ]; then
		cli_status failed "No setup detected" "AGENTS.md missing or mode unrecognised"
		printf '\n  Run: setup-project.sh --claude|--codex|--both\n\n'
		return 0
	fi

	cli_status success "Detected mode" "$detected_mode"

	# AGENTS.md template match.
	cli_group_begin "Project rules"
	local template=""
	case "$detected_mode" in
		claude) template="$REPO_DIR/templates/claude/AGENTS.md.template" ;;
		codex)  template="$REPO_DIR/templates/codex/AGENTS.md.template" ;;
		both)   template="$REPO_DIR/templates/shared/AGENTS.md.template" ;;
	esac
	if cmp -s "$template" "$agents_md"; then
		cli_group_status muted "AGENTS.md" "matches template"
	else
		cli_group_status warning "AGENTS.md" "differs from template (may be customised)"
	fi
	cli_group_end

	# WORKSPACE.md presence.
	cli_group_begin "Workspace"
	if [ -e "$workspace_md" ] || [ -L "$workspace_md" ]; then
		cli_group_status muted "WORKSPACE.md" "exists"
	else
		cli_group_status warning "WORKSPACE.md" "missing"
	fi
	cli_group_end

	# Shared agent tools — each should be a symlink to the central source.
	cli_group_begin "Shared agent tools"
	local scripts_dir="$PROJECT_DIR/.agent/scripts"
	local expected_tools=(
		"project-diagnostics.py|$REPO_DIR/scripts/project-diagnostics.py"
		"generated-file-guard.py|$REPO_DIR/scripts/validate/generated-file-guard.py"
		"repo-context.py|$REPO_DIR/scripts/repo-context.py"
		"change-impact.py|$REPO_DIR/scripts/validate/change-impact.py"
	)
	if [ ! -d "$scripts_dir" ]; then
		cli_group_status warning ".agent/scripts/" "missing"
	else
		for entry in "${expected_tools[@]}"; do
			local name="${entry%%|*}"
			local source="${entry##*|}"
			local target="$scripts_dir/$name"

			if [ ! -e "$target" ] && [ ! -L "$target" ]; then
				cli_group_status failed "$name" "missing"
			elif [ -L "$target" ]; then
				if [ "$(readlink "$target")" = "$source" ]; then
					cli_group_status muted "$name" "linked correctly"
				else
					cli_group_status warning "$name" "symlink points elsewhere"
				fi
			else
				cli_group_status warning "$name" "local copy, not symlinked"
			fi
		done
	fi
	cli_group_end

	# Claude support files (claude/both only).
	if [ "$detected_mode" = "claude" ] || [ "$detected_mode" = "both" ]; then
		cli_group_begin "Claude support files"
		local claudeignore="$PROJECT_DIR/.claude/.claudeignore"

		if [ ! -d "$PROJECT_DIR/.claude" ]; then
			cli_group_status warning ".claude/" "missing"
		elif [ ! -e "$claudeignore" ] && [ ! -L "$claudeignore" ]; then
			cli_group_status warning ".claude/.claudeignore" "missing"
		elif cmp -s "$REPO_DIR/templates/claude/.claudeignore" "$claudeignore"; then
			cli_group_status muted ".claude/.claudeignore" "matches template"
		else
			cli_group_status warning ".claude/.claudeignore" "differs from template (may be customised)"
		fi
		cli_group_end
	fi

	# Unexpected runtime directories.
	cli_group_begin "Runtime directories"
	if [ "$detected_mode" = "codex" ]; then
		if [ -e "$PROJECT_DIR/.claude" ]; then
			cli_group_status warning ".claude/" "unexpected for Codex-only mode"
		else
			cli_group_status muted ".claude/" "absent (correct for Codex-only)"
		fi
	fi
	if [ -e "$PROJECT_DIR/.agents" ]; then
		cli_group_status warning ".agents/" "present (local skills — intentional?)"
	fi
	cli_group_end

	# Repair guidance — no files are modified.
	printf '\n  Repair:\n'
	printf '    setup-project.sh --%s  — set up missing files\n' "$detected_mode"
	printf '    setup-project.sh --write-workspace  — create WORKSPACE.md\n'
	printf '    setup-project.sh --force-workspace  — refresh WORKSPACE.md\n\n'
}
