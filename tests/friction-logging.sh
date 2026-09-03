#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)

source "$SCRIPT_DIR/lib/test-helpers.sh"

trap cleanup EXIT

run_tool_failure_hook() {
	local project_dir="$1"
	local database_path="$2"
	local payload="$3"

	(
		cd "$project_dir"
		FRICTION_DATABASE="$database_path" bash "$REPO_DIR/dist/claude/hooks/tool-failure-log.sh" <<< "$payload"
	)
}

test_tool_failures_are_logged() {
	local project_dir="$TEST_ROOT/tool-failure-project"
	local database_path="$TEST_ROOT/tool-failure.db"
	local summary_file="$TEST_ROOT/tool-failure-summary.json"
	local payload='{"tool_name":"Bash","tool_input":{"command":"cat missing.txt"},"error":"cat: missing.txt: No such file or directory","is_interrupt":false,"duration_ms":12,"session_id":"test-session","cwd":"/ignored/by/log/schema"}'

	mkdir -p "$project_dir"
	run_tool_failure_hook "$project_dir" "$database_path" "$payload"
	FRICTION_DATABASE="$database_path" friction summary --include-tool-errors --json > "$summary_file"

	assert_contains "$summary_file" '"count": 1'
	assert_contains "$summary_file" '"category": "tool-error"'
	assert_contains "$summary_file" "$project_dir"
	assert_contains "$summary_file" "Bash: cat missing.txt"
	assert_contains "$summary_file" "cat: missing.txt: No such file or directory"
}

test_manual_writer_logs_entry() {
	local home_dir="$TEST_ROOT/manual-home"
	local log_file="$home_dir/.claude/logs/friction.log"

	(
		cd "$TEST_ROOT"
		HOME="$home_dir" bash "$REPO_DIR/scripts/agent-tools/log-friction.sh" "wrong-approach" "reimplemented clamp instead of using helper" >/dev/null
	)

	assert_file "$log_file"
	assert_contains "$log_file" "wrong-approach"
	assert_contains "$log_file" "reimplemented clamp instead of using helper"
}

test_manual_writer_falls_back_to_project_log() {
	local project_dir="$TEST_ROOT/manual-fallback-project"
	local blocked_home="$TEST_ROOT/blocked-home"
	local log_file="$project_dir/.agent/logs/friction.log"

	mkdir -p "$project_dir"
	printf 'not a directory\n' > "$blocked_home"

	(
		cd "$project_dir"
		HOME="$blocked_home" bash "$REPO_DIR/scripts/agent-tools/log-friction.sh" "missing-guidance" "central log was sandboxed" >/dev/null 2>/dev/null
	)

	assert_file "$log_file"
	assert_contains "$log_file" "missing-guidance"
	assert_contains "$log_file" "central log was sandboxed"
}

test_tool_failure_hook_is_non_blocking() {
	local project_dir="$TEST_ROOT/tool-failure-non-blocking-project"
	local database_path="$TEST_ROOT/tool-failure-non-blocking.db"
	local payload='{"tool_name":"Read","tool_input":{"file_path":"missing.md"},"error":"File does not exist","is_interrupt":false,"duration_ms":8,"session_id":"test-session","cwd":"/ignored/by/log/schema"}'

	mkdir -p "$project_dir"

	(
		cd "$project_dir"
		FRICTION_DATABASE="$database_path" bash "$REPO_DIR/dist/claude/hooks/tool-failure-log.sh" <<< "not JSON"
	) || fail "Tool-failure hook exited non-zero for malformed input"

	(
		cd "$project_dir"
		PATH="/usr/bin:/bin" /bin/bash "$REPO_DIR/dist/claude/hooks/tool-failure-log.sh" <<< "$payload"
	) || fail "Tool-failure hook exited non-zero without friction"
}

test_codex_hcom_hooks_bootstrap_homebrew_path() {
	local hcom_command_count
	local bootstrapped_command_count
	local hooks_file="$REPO_DIR/dist/codex/hooks.json"

	hcom_command_count=$(jq '[.. | objects | select(.command? and (.command | contains("; hcom ")))] | length' "$hooks_file")
	bootstrapped_command_count=$(jq '[.. | objects | select(.command? and (.command | startswith("export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\"; hcom ")))] | length' "$hooks_file")

	[ "$hcom_command_count" -eq 5 ] || fail "Expected five HCOM Codex hooks, found $hcom_command_count"
	[ "$bootstrapped_command_count" -eq "$hcom_command_count" ] || fail "HCOM Codex hooks do not all bootstrap Homebrew PATH"
}

test_tool_failures_are_logged
test_manual_writer_logs_entry
test_manual_writer_falls_back_to_project_log
test_tool_failure_hook_is_non_blocking
test_codex_hcom_hooks_bootstrap_homebrew_path

printf '✓ friction logging tests passed\n'
