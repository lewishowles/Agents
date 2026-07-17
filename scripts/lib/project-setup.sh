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
	cli_style_hint "This usually means either you have customised it for this project or the default template has been updated."
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

# Returns 0 when Capn has already initialised the project.
capn_is_initialised() {
	[[ -f "$PROJECT_DIR/.capn/config.json" ]]
}

# Validates the prerequisites for Capn's Git-aware project initialisation.
check_capn_requirements() {
	local git_root

	if capn_is_initialised; then
		return
	fi

	if ! command -v capn &>/dev/null; then
		cli_status failed "Capn unavailable" "Install capn-hook globally before project setup"
		return 1
	fi

	if ! git_root="$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
		cli_status failed "Git repository required" "capn init --git needs an initialised Git repository"
		return 1
	fi

	if [ "$git_root" != "$PROJECT_DIR" ]; then
		cli_status failed "Git repository root required" "run project setup from $git_root"
		return 1
	fi
}

# Initialises disposable navigational memory and project hooks through Capn.
initialise_capn() {
	cli_group_begin "Navigational memory"
	if capn_is_initialised; then
		cli_group_status muted ".capn/config.json" "already configured"
		cli_group_end
		return
	fi

	if ! (
		cd "$PROJECT_DIR"
		capn init --git >/dev/null
	); then
		cli_group_status failed "capn init --git" "project initialisation failed"
		cli_group_end
		return 1
	fi
	cli_group_status success "initialised" "Capn hooks and post-commit pruning"
	cli_group_end
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
	link_file "$REPO_DIR/scripts/log-friction.sh" "$PROJECT_DIR/.agent/scripts/log-friction.sh" ".agent/scripts/log-friction.sh"
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

# Lists centrally managed project skill packs available for local project installs.
list_project_skill_packs() {
	local packs_dir="$REPO_DIR/project-skill-packs"
	local pack

	if [ ! -d "$packs_dir" ]; then
		return
	fi

	for pack in "$packs_dir"/*; do
		[ -d "$pack" ] || continue
		printf '%s\n' "$(basename "$pack")"
	done
}

# Returns 0 when the current project looks like a macOS or Swift project.
detect_macos_project() {
	local candidate

	for candidate in "$PROJECT_DIR"/*.xcodeproj "$PROJECT_DIR"/*.xcworkspace; do
		if [ -e "$candidate" ] || [ -L "$candidate" ]; then
			return 0
		fi
	done

	if [ -f "$PROJECT_DIR/Package.swift" ]; then
		shopt -s globstar nullglob
		for candidate in "$PROJECT_DIR"/Sources/**/*.swift "$PROJECT_DIR"/Tests/**/*.swift "$PROJECT_DIR"/*.swift; do
			if [ -f "$candidate" ]; then
				return 0
			fi
		done
	fi

	return 1
}

# Prompts for automatic macOS pack installation when the project shape matches.
should_install_detected_macos_pack() {
	if ! detect_macos_project; then
		return 1
	fi

	printf 'Detected a macOS/Swift project. Install local macOS skills? [Y/n] '
	local response
	if ! read -r response; then
		cli_group_status muted "macos" "detected; use --with-skill-pack macos to install non-interactively"
		return 1
	fi

	case "$response" in
		n|N|no|No|NO) return 1 ;;
		*) return 0 ;;
	esac
}

# Installs one project skill pack into both local agent skill directories.
#
# @param  {string}  pack_name
#     Name of the pack under project-skill-packs/.
install_project_skill_pack() {
	local pack_name="$1"
	local pack_dir="$REPO_DIR/project-skill-packs/$pack_name"
	local skill slug

	if [ ! -d "$pack_dir" ]; then
		cli_group_status failed "$pack_name" "project skill pack not found"
		return 1
	fi

	ensure_container_dir "$PROJECT_DIR/.agents/skills" ".agents/skills/"
	ensure_container_dir "$PROJECT_DIR/.claude/skills" ".claude/skills/"

	for skill in "$pack_dir"/*; do
		[ -d "$skill" ] || continue
		slug=$(basename "$skill")
		link_path "$skill" "$PROJECT_DIR/.agents/skills/$slug" ".agents/skills/$slug"
		link_path "$skill" "$PROJECT_DIR/.claude/skills/$slug" ".claude/skills/$slug"
	done
}

# Installs explicit project skill packs, or offers detected packs interactively.
install_project_skill_packs() {
	local packs=()
	local pack

	case "$SKILL_PACK_MODE" in
		none) return 0 ;;
		explicit) packs=("${REQUESTED_SKILL_PACKS[@]}") ;;
		auto)
			cli_group_begin "Project skill packs"
			if should_install_detected_macos_pack; then
				packs=(macos)
			fi
			cli_group_end
			;;
	esac

	if [ "${#packs[@]}" -eq 0 ]; then
		return 0
	fi

	cli_group_begin "Project skill packs"
	for pack in "${packs[@]}"; do
		install_project_skill_pack "$pack"
	done
	cli_group_end
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
		local _json
		_json='{"next":'"$(cli_style_json_string "Run setup to create project files")"',"reason":'"$(cli_style_json_string "")"',"commands":'"$(cli_style_json_string_array "setup-project.sh --claude" "setup-project.sh --codex" "setup-project.sh --both")"',"alternatives":'"$(cli_style_json_string_array)"'}'
		cli_style_render_json next-step-block "$_json"
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

	cli_group_begin "Navigational memory"
	if [ -f "$PROJECT_DIR/.capn/config.json" ]; then
		cli_group_status muted ".capn/config.json" "exists"
	else
		cli_group_status warning ".capn/config.json" "missing"
	fi
	if [ -f "$PROJECT_DIR/.claude/settings.json" ] && grep -Fq "/usr/bin/env capn context" "$PROJECT_DIR/.claude/settings.json"; then
		cli_group_status muted "Claude hook" "configured"
	else
		cli_group_status warning "Claude hook" "missing"
	fi
	if [ -f "$PROJECT_DIR/.codex/hooks.json" ] && grep -Fq "/usr/bin/env capn context" "$PROJECT_DIR/.codex/hooks.json"; then
		cli_group_status muted "Codex hook" "configured"
	else
		cli_group_status warning "Codex hook" "missing"
	fi
	if [ -f "$PROJECT_DIR/.git/hooks/post-commit" ] && grep -Fq "capn prune" "$PROJECT_DIR/.git/hooks/post-commit"; then
		cli_group_status muted "post-commit hook" "configured"
	else
		cli_group_status warning "post-commit hook" "missing"
	fi
	cli_group_end

	# Unexpected runtime directories.
	cli_group_begin "Runtime directories"
	if [ -e "$PROJECT_DIR/.agents" ]; then
		cli_group_status warning ".agents/" "present (local skills — intentional?)"
	fi
	cli_group_end

	# Repair guidance — no files are modified.
	local _json
	_json='{"next":'"$(cli_style_json_string "Repair setup drift")"',"reason":'"$(cli_style_json_string "")"',"commands":'"$(cli_style_json_string_array "setup-project.sh --$detected_mode" "setup-project.sh --write-workspace" "setup-project.sh --force-workspace")"',"alternatives":'"$(cli_style_json_string_array)"'}'
	cli_style_render_json next-step-block "$_json"
}
