#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)

source "$SCRIPT_DIR/lib/test-helpers.sh"

trap cleanup EXIT

run_setup() {
	local target_dir="$1"
	shift
	(
		cd "$target_dir"
		"$REPO_DIR/scripts/setup-project.sh" "$@" >/dev/null </dev/null
	)
}

run_setup_output() {
	local target_dir="$1"
	shift
	(
		cd "$target_dir"
		"$REPO_DIR/scripts/setup-project.sh" "$@" </dev/null
	)
}

run_setup_input() {
	local target_dir="$1"
	local input="$2"
	shift 2
	(
		cd "$target_dir"
		printf '%b' "$input" | "$REPO_DIR/scripts/setup-project.sh" "$@" >/dev/null
	)
}

test_claude_setup() {
	local target_dir="$TEST_ROOT/claude"
	mkdir -p "$target_dir/src"

	run_setup "$target_dir" --claude

	assert_file "$target_dir/AGENTS.md"
	assert_file "$target_dir/WORKSPACE.md"
	assert_contains "$target_dir/WORKSPACE.md" "Main source directories: \`src\`"
	assert_link "$target_dir/.agent/scripts/project-diagnostics.py"
	assert_link "$target_dir/.agent/scripts/repo-context.py"
	assert_link "$target_dir/.agent/scripts/change-impact.py"
	assert_link "$target_dir/.agent/scripts/generated-file-guard.py"
	assert_link "$target_dir/.agent/scripts/markdown-claims.py"
	assert_link "$target_dir/.agent/scripts/log-friction.sh"
	assert_contains "$target_dir/WORKSPACE.md" ".agent/scripts/project-diagnostics.py"
	assert_contains "$target_dir/WORKSPACE.md" "project-checks --list"
	assert_dir "$target_dir/.claude"
	assert_file "$target_dir/.claude/.claudeignore"
	assert_not_exists "$target_dir/.claude/templates"
	assert_contains "$target_dir/AGENTS.md" "Claude Code"
}

test_codex_setup() {
	local target_dir="$TEST_ROOT/codex"
	mkdir -p "$target_dir/src"

	run_setup "$target_dir" --codex

	assert_file "$target_dir/AGENTS.md"
	assert_file "$target_dir/WORKSPACE.md"
	assert_contains "$target_dir/WORKSPACE.md" "Main source directories: \`src\`"
	assert_file "$target_dir/.agent/scripts/project-diagnostics.py"
	assert_file "$target_dir/.agent/scripts/repo-context.py"
	assert_file "$target_dir/.agent/scripts/change-impact.py"
	assert_file "$target_dir/.agent/scripts/generated-file-guard.py"
	assert_file "$target_dir/.agent/scripts/markdown-claims.py"
	assert_link "$target_dir/.agent/scripts/log-friction.sh"
	assert_contains "$target_dir/WORKSPACE.md" ".agent/scripts/project-diagnostics.py"
	assert_contains "$target_dir/WORKSPACE.md" "project-checks --list"
	assert_not_exists "$target_dir/.agents"
	assert_contains "$target_dir/AGENTS.md" "Codex"
}

test_both_setup() {
	local target_dir="$TEST_ROOT/both"
	mkdir -p "$target_dir/src"

	run_setup "$target_dir" --both

	assert_file "$target_dir/AGENTS.md"
	assert_file "$target_dir/WORKSPACE.md"
	assert_contains "$target_dir/WORKSPACE.md" "Main source directories: \`src\`"
	assert_file "$target_dir/.agent/scripts/project-diagnostics.py"
	assert_file "$target_dir/.agent/scripts/repo-context.py"
	assert_file "$target_dir/.agent/scripts/change-impact.py"
	assert_file "$target_dir/.agent/scripts/generated-file-guard.py"
	assert_file "$target_dir/.agent/scripts/markdown-claims.py"
	assert_link "$target_dir/.agent/scripts/log-friction.sh"
	assert_contains "$target_dir/WORKSPACE.md" ".agent/scripts/project-diagnostics.py"
	assert_contains "$target_dir/WORKSPACE.md" "project-checks --list"
	assert_file "$target_dir/.claude/.claudeignore"
	assert_not_exists "$target_dir/.claude/templates"
	assert_not_exists "$target_dir/.agents"
	assert_contains "$target_dir/AGENTS.md" "Claude Code and Codex"
}

test_existing_files_are_skipped() {
	local target_dir="$TEST_ROOT/existing"
	local output="$TEST_ROOT/existing-second.out"
	mkdir -p "$target_dir"
	printf 'custom rules\n' > "$target_dir/AGENTS.md"

	run_setup "$target_dir" --both
	run_setup_output "$target_dir" --both > "$output"

	assert_equals "$(cat "$target_dir/AGENTS.md")" "custom rules"
	assert_file "$target_dir/.claude/.claudeignore"
	assert_contains "$output" "Shared agent tools"
	assert_contains "$output" "8 unchanged"
	assert_contains "$output" "Claude support files"
	assert_contains "$output" "2 unchanged"
}

test_init_workspace_previews_current_project() {
	local target_dir="$TEST_ROOT/init-preview"
	local output="$TEST_ROOT/init-preview.md"
	mkdir -p "$target_dir/src"

	run_setup_output "$target_dir" --init-workspace > "$output"

	assert_contains "$output" "Workspace"
	assert_contains "$output" "Main source directories"
	assert_not_contains "$output" "Done."
	[ ! -e "$target_dir/WORKSPACE.md" ] || fail "Preview should not write WORKSPACE.md"
}

test_write_workspace_writes_current_project() {
	local target_dir="$TEST_ROOT/init-write"
	local output="$TEST_ROOT/init-write.out"
	mkdir -p "$target_dir/src"

	run_setup_output "$target_dir" --write-workspace > "$output"

	assert_file "$target_dir/WORKSPACE.md"
	assert_contains "$target_dir/WORKSPACE.md" "Workspace"
	assert_contains "$output" "Review generated command safety, generated paths, and forbidden operations before relying on it."
}

test_write_workspace_protects_existing_manifest() {
	local target_dir="$TEST_ROOT/init-existing"
	mkdir -p "$target_dir"
	printf 'custom\n' > "$target_dir/WORKSPACE.md"

	if run_setup "$target_dir" --write-workspace; then
		fail "Expected existing manifest write to fail without force"
	fi

	assert_equals "$(cat "$target_dir/WORKSPACE.md")" "custom"
	run_setup "$target_dir" --force-workspace
	assert_contains "$target_dir/WORKSPACE.md" "Workspace"
}

test_legacy_capability_flag_writes_workspace() {
	local target_dir="$TEST_ROOT/legacy-flag"
	mkdir -p "$target_dir/src"

	run_setup "$target_dir" --write-capabilities

	assert_file "$target_dir/WORKSPACE.md"
}

test_help_lists_commands() {
	local output="$TEST_ROOT/help.txt"

	"$REPO_DIR/scripts/setup-project.sh" --help > "$output"

	assert_contains "$output" "Usage: setup-project.sh [command]"
	assert_contains "$output" "Project setup:"
	assert_contains "$output" "--both"
	assert_contains "$output" "Workspace:"
	assert_contains "$output" "--init-workspace"
	assert_contains "$output" "Project skill packs:"
	assert_contains "$output" "--with-skill-pack"
	assert_contains "$output" "--no-skill-packs"
	assert_contains "$output" "--list-skill-packs"
	assert_contains "$output" "Diagnostics:"
	assert_contains "$output" "--status"
	assert_contains "$output" "Examples:"
}

test_list_skill_packs_reports_macos() {
	local output="$TEST_ROOT/skill-packs.txt"

	"$REPO_DIR/scripts/setup-project.sh" --list-skill-packs > "$output"

	assert_contains "$output" "macos"
}

test_explicit_skill_pack_installs_local_links() {
	local target_dir="$TEST_ROOT/skill-pack-explicit"
	mkdir -p "$target_dir/src"

	run_setup "$target_dir" --both --with-skill-pack macos

	assert_dir_link "$target_dir/.agents/skills/swift"
	assert_dir_link "$target_dir/.agents/skills/macos"
	assert_dir_link "$target_dir/.claude/skills/swift"
	assert_dir_link "$target_dir/.claude/skills/macos"
	assert_equals "$(readlink "$target_dir/.agents/skills/swift")" "$REPO_DIR/project-skill-packs/macos/swift"
}

test_detected_skill_pack_installs_when_confirmed() {
	local target_dir="$TEST_ROOT/skill-pack-detected"
	mkdir -p "$target_dir/Sources/App"
	printf '// swift package\n' > "$target_dir/Package.swift"
	printf 'struct App {}\n' > "$target_dir/Sources/App/App.swift"

	run_setup_input "$target_dir" "y\n" --both

	assert_dir_link "$target_dir/.agents/skills/swift"
	assert_dir_link "$target_dir/.claude/skills/swift"
}

test_agent_docs_mentions_do_not_trigger_skill_pack_detection() {
	local target_dir="$TEST_ROOT/skill-pack-docs-mention"
	local output="$TEST_ROOT/skill-pack-docs-mention.out"
	mkdir -p "$target_dir/src"
	printf 'Use Swift skills when editing Swift files.\n' > "$target_dir/AGENTS.md"
	printf 'Swift diagnostics may exist in other projects.\n' > "$target_dir/WORKSPACE.md"

	run_setup_output "$target_dir" --both > "$output" 2>&1

	assert_not_contains "$output" "Detected a macOS/Swift project"
	assert_not_exists "$target_dir/.agents"
}

test_no_skill_packs_suppresses_detection() {
	local target_dir="$TEST_ROOT/skill-pack-suppressed"
	mkdir -p "$target_dir/Sources/App"
	printf '// swift package\n' > "$target_dir/Package.swift"
	printf 'struct App {}\n' > "$target_dir/Sources/App/App.swift"

	run_setup "$target_dir" --both --no-skill-packs

	assert_not_exists "$target_dir/.agents"
	assert_not_exists "$target_dir/.claude/skills"
}

test_status_reports_clean_project() {
	local target_dir="$TEST_ROOT/status-clean"
	local output="$TEST_ROOT/status-clean.out"
	mkdir -p "$target_dir/src"

	run_setup_output "$target_dir" --status > "$output" 2>&1

	assert_contains "$output" "No setup detected"
	assert_not_contains "$output" "Done."
}

test_status_reports_configured_project() {
	local target_dir="$TEST_ROOT/status-configured"
	local output="$TEST_ROOT/status-configured.out"
	mkdir -p "$target_dir/src"

	run_setup "$target_dir" --both
	run_setup_output "$target_dir" --status > "$output" 2>&1

	assert_contains "$output" "Detected mode"
	assert_contains "$output" "both"
	assert_contains "$output" "Project rules"
	assert_contains "$output" "Shared agent tools"
}

test_status_reports_drifted_project() {
	local target_dir="$TEST_ROOT/status-drifted"
	local output="$TEST_ROOT/status-drifted.out"
	mkdir -p "$target_dir/src"

	run_setup "$target_dir" --both
	rm "$target_dir/WORKSPACE.md"
	rm "$target_dir/.agent/scripts/repo-context.py"

	run_setup_output "$target_dir" --status > "$output" 2>&1

	assert_contains "$output" "WORKSPACE.md"
	assert_contains "$output" "repo-context.py"
}

test_claude_setup
test_codex_setup
test_both_setup
test_existing_files_are_skipped
test_init_workspace_previews_current_project
test_write_workspace_writes_current_project
test_write_workspace_protects_existing_manifest
test_legacy_capability_flag_writes_workspace
test_help_lists_commands
test_list_skill_packs_reports_macos
test_explicit_skill_pack_installs_local_links
test_detected_skill_pack_installs_when_confirmed
test_agent_docs_mentions_do_not_trigger_skill_pack_detection
test_no_skill_packs_suppresses_detection
test_status_reports_clean_project
test_status_reports_configured_project
test_status_reports_drifted_project

printf '✓ setup-project tests passed\n'
