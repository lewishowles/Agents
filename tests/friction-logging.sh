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

test_analyser_groups_log_entries() {
	local home_dir="$TEST_ROOT/analyse-home"
	local log_file="$home_dir/.claude/logs/friction.log"
	local output_file="$TEST_ROOT/analyse.out"

	mkdir -p "$(dirname "$log_file")"
	printf '2026-05-15T19:00:00Z\trule-ignored\t/project-a\tskipped review gate\n' > "$log_file"
	printf '2026-05-15T19:01:00Z\trule-ignored\t/project-a\tskipped review gate\n' >> "$log_file"
	printf '2026-05-15T19:02:00Z\tcheck-fail\t/project-b\ttest:unit:run: unit tests exploded\n' >> "$log_file"

	HOME="$home_dir" "$REPO_DIR/src/skills/friction-review/scripts/analyse-friction.sh" > "$output_file"

	assert_contains "$output_file" "2	rule-ignored	/project-a	skipped review gate"
	assert_not_contains "$output_file" "check-fail"

	HOME="$home_dir" FRICTION_INCLUDE_CHECK_FAILS=1 "$REPO_DIR/src/skills/friction-review/scripts/analyse-friction.sh" > "$output_file"

	assert_contains "$output_file" "1	check-fail	/project-b	test:unit:run: unit tests exploded"
}

test_analyser_excludes_tool_error_entries_by_default() {
	local home_dir="$TEST_ROOT/tool-error-analyse-home"
	local log_file="$home_dir/.claude/logs/friction.log"
	local output_file="$TEST_ROOT/tool-error-analyse.out"

	mkdir -p "$(dirname "$log_file")"
	printf '2026-05-15T19:00:00Z\ttool-error\t/project-a\tBash: cat missing.txt — cat: missing.txt: No such file or directory\n' > "$log_file"
	printf '2026-05-15T19:01:00Z\ttool-error\t/project-a\tBash: cat missing.txt — cat: missing.txt: No such file or directory\n' >> "$log_file"

	HOME="$home_dir" "$REPO_DIR/src/skills/friction-review/scripts/analyse-friction.sh" > "$output_file"

	assert_not_contains "$output_file" "tool-error"

	HOME="$home_dir" FRICTION_INCLUDE_TOOL_ERRORS=1 "$REPO_DIR/src/skills/friction-review/scripts/analyse-friction.sh" > "$output_file"

	assert_contains "$output_file" "2	tool-error	/project-a	Bash: cat missing.txt — cat: missing.txt: No such file or directory"
}

test_analyser_tolerates_legacy_lines() {
	local home_dir="$TEST_ROOT/legacy-home"
	local log_file="$home_dir/.claude/logs/friction.log"
	local output_file="$TEST_ROOT/legacy.out"

	mkdir -p "$(dirname "$log_file")"
	printf '2026-05-01T10:00:00Z\t/legacy-project\tlint\tlint exploded\n' > "$log_file"
	printf '2026-05-01T10:01:00Z\t/legacy-project\tlint\tlint exploded\n' >> "$log_file"

	HOME="$home_dir" "$REPO_DIR/src/skills/friction-review/scripts/analyse-friction.sh" > "$output_file"

	assert_not_contains "$output_file" "check-fail"

	HOME="$home_dir" FRICTION_INCLUDE_CHECK_FAILS=1 "$REPO_DIR/src/skills/friction-review/scripts/analyse-friction.sh" > "$output_file"

	assert_contains "$output_file" "2	check-fail	/legacy-project	lint	lint exploded"
}

test_analyser_excludes_resolved_pattern() {
	local home_dir="$TEST_ROOT/resolved-home"
	local log_file="$home_dir/.claude/logs/friction.log"
	local output_file="$TEST_ROOT/resolved.out"

	mkdir -p "$(dirname "$log_file")"
	printf '2026-05-15T19:00:00Z\trule-ignored\t/project-a\tskipped review gate\n' > "$log_file"
	printf '2026-05-15T19:01:00Z\trule-ignored\t/project-a\tskipped review gate\n' >> "$log_file"
	printf 'RESOLVED\trule-ignored\tskipped review gate\tfeat(rules): add blocking review gate\n' >> "$log_file"

	HOME="$home_dir" "$REPO_DIR/src/skills/friction-review/scripts/analyse-friction.sh" > "$output_file"

	assert_not_contains "$output_file" "skipped review gate"
}

test_analyser_resurfaces_pattern_after_resolution() {
	local home_dir="$TEST_ROOT/resurface-home"
	local log_file="$home_dir/.claude/logs/friction.log"
	local output_file="$TEST_ROOT/resurface.out"

	mkdir -p "$(dirname "$log_file")"
	printf '2026-05-15T19:00:00Z\trule-ignored\t/project-a\tskipped review gate\n' > "$log_file"
	printf 'RESOLVED\trule-ignored\tskipped review gate\tfeat(rules): add blocking review gate\n' >> "$log_file"
	printf '2026-06-01T09:00:00Z\trule-ignored\t/project-a\tskipped review gate\n' >> "$log_file"

	HOME="$home_dir" "$REPO_DIR/src/skills/friction-review/scripts/analyse-friction.sh" > "$output_file"

	assert_contains "$output_file" "1	rule-ignored	/project-a	skipped review gate"
}

test_analyser_selftest_passes() {
	local output_file="$TEST_ROOT/analyser-selftest.out"

	"$REPO_DIR/src/skills/friction-review/scripts/analyse-friction.sh" --selftest > "$output_file"

	assert_contains "$output_file" "analyse-friction.sh --selftest passed"
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

test_analyser_discovers_project_fallback_logs() {
	local home_dir="$TEST_ROOT/discover-home"
	local dev_root="$TEST_ROOT/dev-root"
	local fallback_log="$dev_root/Configuration/Agents/.agent/logs/friction.log"
	local canonical_log="$home_dir/.claude/logs/friction.log"
	local output_file="$TEST_ROOT/discover.out"

	mkdir -p "$(dirname "$fallback_log")" "$(dirname "$canonical_log")"
	printf '2026-05-15T19:00:00Z\trule-ignored\t/project-a\tskipped review gate\n' > "$fallback_log"
	printf '2026-05-15T19:01:00Z\trule-ignored\t/project-a\tskipped review gate\n' >> "$fallback_log"
	printf '2026-05-15T19:02:00Z\tmissing-guidance\t/project-b\tcentral log was sandboxed\n' >> "$fallback_log"
	printf 'RESOLVED\trule-ignored\tskipped review gate\tfeat(rules): add blocking review gate\n' > "$canonical_log"

	HOME="$home_dir" FRICTION_DEV_ROOT="$dev_root" "$REPO_DIR/src/skills/friction-review/scripts/analyse-friction.sh" > "$output_file"

	assert_not_contains "$output_file" "skipped review gate"
	assert_contains "$output_file" "1	missing-guidance	/project-b	central log was sandboxed"
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
test_analyser_groups_log_entries
test_analyser_excludes_tool_error_entries_by_default
test_analyser_tolerates_legacy_lines
test_analyser_excludes_resolved_pattern
test_analyser_resurfaces_pattern_after_resolution
test_manual_writer_logs_entry
test_manual_writer_falls_back_to_project_log
test_tool_failure_hook_is_non_blocking
test_analyser_discovers_project_fallback_logs
test_analyser_selftest_passes
test_codex_hcom_hooks_bootstrap_homebrew_path

printf '✓ friction logging tests passed\n'
