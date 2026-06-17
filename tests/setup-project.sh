#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)

cleanup() {
	rm -rf "$TEST_ROOT"
}

trap cleanup EXIT

fail() {
	printf '✗ %s\n' "$1" >&2
	exit 1
}

assert_file() {
	local path="$1"

	[ -f "$path" ] || fail "Expected file: $path"
}

assert_dir() {
	local path="$1"

	[ -d "$path" ] || fail "Expected directory: $path"
}

assert_contains() {
	local path="$1"
	local pattern="$2"

	grep -q "$pattern" "$path" || fail "Expected $path to contain: $pattern"
}

assert_equals() {
	local actual="$1"
	local expected="$2"

	[ "$actual" = "$expected" ] || fail "Expected '$expected', got '$actual'"
}

run_setup() {
	local target_dir="$1"
	local flag="$2"

	(
		cd "$target_dir"
		"$REPO_DIR/scripts/setup-project.sh" "$flag" >/dev/null
	)
}

test_claude_setup() {
	local target_dir="$TEST_ROOT/claude"
	mkdir -p "$target_dir"

	run_setup "$target_dir" --claude

	assert_file "$target_dir/AGENTS.md"
	assert_file "$target_dir/AGENT_CAPABILITIES.md"
	assert_dir "$target_dir/.claude"
	assert_dir "$target_dir/.claude/templates"
	assert_file "$target_dir/.claude/settings.json"
	assert_file "$target_dir/.claude/.claudeignore"
	assert_file "$target_dir/.claude/templates/PLAN.md.template"
	assert_contains "$target_dir/AGENTS.md" "Claude Code"
}

test_codex_setup() {
	local target_dir="$TEST_ROOT/codex"
	mkdir -p "$target_dir"

	run_setup "$target_dir" --codex

	assert_file "$target_dir/AGENTS.md"
	assert_file "$target_dir/AGENT_CAPABILITIES.md"
	assert_dir "$target_dir/.agents"
	assert_dir "$target_dir/.agents/skills"
	[ ! -e "$target_dir/.claude" ] || fail "Codex-only setup should not create .claude"
	assert_contains "$target_dir/AGENTS.md" "Codex"
}

test_both_setup() {
	local target_dir="$TEST_ROOT/both"
	mkdir -p "$target_dir"

	run_setup "$target_dir" --both

	assert_file "$target_dir/AGENTS.md"
	assert_file "$target_dir/AGENT_CAPABILITIES.md"
	assert_file "$target_dir/.claude/settings.json"
	assert_file "$target_dir/.claude/.claudeignore"
	assert_file "$target_dir/.claude/templates/PLAN.md.template"
	assert_dir "$target_dir/.agents"
	assert_dir "$target_dir/.agents/skills"
	assert_contains "$target_dir/AGENTS.md" "Claude Code and Codex"
}

test_existing_files_are_skipped() {
	local target_dir="$TEST_ROOT/existing"
	mkdir -p "$target_dir"
	printf 'custom rules\n' > "$target_dir/AGENTS.md"

	run_setup "$target_dir" --both
	run_setup "$target_dir" --both

	assert_equals "$(cat "$target_dir/AGENTS.md")" "custom rules"
	assert_file "$target_dir/.claude/settings.json"
}

test_claude_setup
test_codex_setup
test_both_setup
test_existing_files_are_skipped

printf '✓ setup-project tests passed\n'
