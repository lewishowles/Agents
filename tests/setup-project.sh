#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)

source "$SCRIPT_DIR/lib/test-helpers.sh"

trap cleanup EXIT

run_setup() {
	local target_dir="$1"
	local flag="$2"

	(
		cd "$target_dir"
		"$REPO_DIR/scripts/setup-project.sh" "$flag" >/dev/null
	)
}

run_setup_output() {
	local target_dir="$1"
	local flag="$2"

	(
		cd "$target_dir"
		"$REPO_DIR/scripts/setup-project.sh" "$flag"
	)
}

test_claude_setup() {
	local target_dir="$TEST_ROOT/claude"
	mkdir -p "$target_dir/src"

	run_setup "$target_dir" --claude

	assert_file "$target_dir/AGENTS.md"
	assert_file "$target_dir/AGENT_CAPABILITIES.md"
	assert_contains "$target_dir/AGENT_CAPABILITIES.md" "Main source directories: \`src\`"
	assert_file "$target_dir/.agent/scripts/project-diagnostics.py"
	assert_file "$target_dir/.agent/scripts/repo-context.py"
	assert_contains "$target_dir/AGENT_CAPABILITIES.md" ".agent/scripts/project-diagnostics.py"
	assert_dir "$target_dir/.claude"
	assert_file "$target_dir/.claude/.claudeignore"
	assert_not_exists "$target_dir/.claude/settings.json"
	assert_not_exists "$target_dir/.claude/templates"
	assert_contains "$target_dir/AGENTS.md" "Claude Code"
}

test_codex_setup() {
	local target_dir="$TEST_ROOT/codex"
	mkdir -p "$target_dir/src"

	run_setup "$target_dir" --codex

	assert_file "$target_dir/AGENTS.md"
	assert_file "$target_dir/AGENT_CAPABILITIES.md"
	assert_contains "$target_dir/AGENT_CAPABILITIES.md" "Main source directories: \`src\`"
	assert_file "$target_dir/.agent/scripts/project-diagnostics.py"
	assert_file "$target_dir/.agent/scripts/repo-context.py"
	assert_contains "$target_dir/AGENT_CAPABILITIES.md" ".agent/scripts/project-diagnostics.py"
	assert_not_exists "$target_dir/.agents"
	[ ! -e "$target_dir/.claude" ] || fail "Codex-only setup should not create .claude"
	assert_contains "$target_dir/AGENTS.md" "Codex"
}

test_both_setup() {
	local target_dir="$TEST_ROOT/both"
	mkdir -p "$target_dir/src"

	run_setup "$target_dir" --both

	assert_file "$target_dir/AGENTS.md"
	assert_file "$target_dir/AGENT_CAPABILITIES.md"
	assert_contains "$target_dir/AGENT_CAPABILITIES.md" "Main source directories: \`src\`"
	assert_file "$target_dir/.agent/scripts/project-diagnostics.py"
	assert_file "$target_dir/.agent/scripts/repo-context.py"
	assert_contains "$target_dir/AGENT_CAPABILITIES.md" ".agent/scripts/project-diagnostics.py"
	assert_file "$target_dir/.claude/.claudeignore"
	assert_not_exists "$target_dir/.claude/settings.json"
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
	assert_contains "$output" ".agent/scripts/project-diagnostics.py already up to date"
	assert_contains "$output" ".agent/scripts/repo-context.py already up to date"
	assert_contains "$output" ".claude/.claudeignore already up to date"
}

test_init_capabilities_previews_current_project() {
	local target_dir="$TEST_ROOT/init-preview"
	local output="$TEST_ROOT/init-preview.md"
	mkdir -p "$target_dir/src"

	run_setup_output "$target_dir" --init-capabilities > "$output"

	assert_contains "$output" "Project capabilities"
	assert_contains "$output" "Main source directories"
	assert_not_contains "$output" "Done."
	[ ! -e "$target_dir/AGENT_CAPABILITIES.md" ] || fail "Preview should not write AGENT_CAPABILITIES.md"
}

test_write_capabilities_writes_current_project() {
	local target_dir="$TEST_ROOT/init-write"
	local output="$TEST_ROOT/init-write.out"
	mkdir -p "$target_dir/src"

	run_setup_output "$target_dir" --write-capabilities > "$output"

	assert_file "$target_dir/AGENT_CAPABILITIES.md"
	assert_contains "$target_dir/AGENT_CAPABILITIES.md" "Project capabilities"
	assert_contains "$output" "Review generated command safety, generated paths, and forbidden operations before relying on it."
}

test_write_capabilities_protects_existing_manifest() {
	local target_dir="$TEST_ROOT/init-existing"
	mkdir -p "$target_dir"
	printf 'custom\n' > "$target_dir/AGENT_CAPABILITIES.md"

	if run_setup "$target_dir" --write-capabilities; then
		fail "Expected existing manifest write to fail without force"
	fi

	assert_equals "$(cat "$target_dir/AGENT_CAPABILITIES.md")" "custom"
	run_setup "$target_dir" --force-capabilities
	assert_contains "$target_dir/AGENT_CAPABILITIES.md" "Project capabilities"
}

test_help_lists_commands() {
	local output="$TEST_ROOT/help.txt"

	"$REPO_DIR/scripts/setup-project.sh" --help > "$output"

	assert_contains "$output" "Usage: setup-project.sh [command]"
	assert_contains "$output" "Project setup:"
	assert_contains "$output" "--both"
	assert_contains "$output" "Capabilities:"
	assert_contains "$output" "--init-capabilities"
	assert_contains "$output" "Examples:"
}

test_claude_setup
test_codex_setup
test_both_setup
test_existing_files_are_skipped
test_init_capabilities_previews_current_project
test_write_capabilities_writes_current_project
test_write_capabilities_protects_existing_manifest
test_help_lists_commands

printf '✓ setup-project tests passed\n'
