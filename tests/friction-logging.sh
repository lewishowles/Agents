#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)

source "$SCRIPT_DIR/lib/test-helpers.sh"

trap cleanup EXIT

write_package() {
	local path="$1"

	cat > "$path/package.json" <<'JSON'
{
	"scripts": {
		"lint": "lint",
		"test:unit:run": "test"
	}
}
JSON
}

write_npm_stub() {
	local bin_dir="$1"
	local lint_status="$2"
	local test_status="$3"

	mkdir -p "$bin_dir"

	cat > "$bin_dir/npm" <<STUB
#!/usr/bin/env bash

if [ "\$1" != "run" ]; then
	exit 1
fi

case "\$2" in
	lint)
		printf 'lint exploded\nsecond lint line\n'
		exit $lint_status
		;;
	test:unit:run)
		printf 'unit tests exploded\nsecond test line\n'
		exit $test_status
		;;
	*)
		exit 1
		;;
esac
STUB

	chmod +x "$bin_dir/npm"
}

run_hook() {
	local project_dir="$1"
	local home_dir="$2"
	local bin_dir="$3"

	(
		cd "$project_dir"
		HOME="$home_dir" PATH="$bin_dir:$PATH" bash "$REPO_DIR/dist/claude/hooks/pre-stop-checks.sh" >/dev/null 2>/dev/null
	)
}

test_failed_checks_are_logged() {
	local project_dir="$TEST_ROOT/failing-project"
	local home_dir="$TEST_ROOT/home"
	local bin_dir="$TEST_ROOT/bin-fail"
	local log_file="$home_dir/.claude/logs/friction.log"

	mkdir -p "$project_dir" "$home_dir"
	write_package "$project_dir"
	write_npm_stub "$bin_dir" 1 1

	run_hook "$project_dir" "$home_dir" "$bin_dir"

	assert_file "$log_file"
	assert_contains "$log_file" "check-fail"
	assert_contains "$log_file" "$project_dir"
	assert_contains "$log_file" "lint,test:unit:run"
	assert_contains "$log_file" "lint exploded"
}

test_successful_checks_are_not_logged() {
	local project_dir="$TEST_ROOT/passing-project"
	local home_dir="$TEST_ROOT/pass-home"
	local bin_dir="$TEST_ROOT/bin-pass"
	local log_file="$home_dir/.claude/logs/friction.log"

	mkdir -p "$project_dir" "$home_dir"
	write_package "$project_dir"
	write_npm_stub "$bin_dir" 0 0

	run_hook "$project_dir" "$home_dir" "$bin_dir"

	assert_not_file "$log_file"
}

test_analyser_groups_log_entries() {
	local home_dir="$TEST_ROOT/analyse-home"
	local log_file="$home_dir/.claude/logs/friction.log"
	local output_file="$TEST_ROOT/analyse.out"

	mkdir -p "$(dirname "$log_file")"
	printf '2026-05-15T19:00:00Z\trule-ignored\t/project-a\tskipped review gate\n' > "$log_file"
	printf '2026-05-15T19:01:00Z\trule-ignored\t/project-a\tskipped review gate\n' >> "$log_file"
	printf '2026-05-15T19:02:00Z\tcheck-fail\t/project-b\ttest:unit:run: unit tests exploded\n' >> "$log_file"

	HOME="$home_dir" "$REPO_DIR/scripts/analyse-friction.sh" > "$output_file"

	assert_contains "$output_file" "2	rule-ignored	/project-a	skipped review gate"
	assert_not_contains "$output_file" "check-fail"

	HOME="$home_dir" FRICTION_INCLUDE_CHECK_FAILS=1 "$REPO_DIR/scripts/analyse-friction.sh" > "$output_file"

	assert_contains "$output_file" "1	check-fail	/project-b	test:unit:run: unit tests exploded"
}

test_analyser_tolerates_legacy_lines() {
	local home_dir="$TEST_ROOT/legacy-home"
	local log_file="$home_dir/.claude/logs/friction.log"
	local output_file="$TEST_ROOT/legacy.out"

	mkdir -p "$(dirname "$log_file")"
	printf '2026-05-01T10:00:00Z\t/legacy-project\tlint\tlint exploded\n' > "$log_file"
	printf '2026-05-01T10:01:00Z\t/legacy-project\tlint\tlint exploded\n' >> "$log_file"

	HOME="$home_dir" "$REPO_DIR/scripts/analyse-friction.sh" > "$output_file"

	assert_not_contains "$output_file" "check-fail"

	HOME="$home_dir" FRICTION_INCLUDE_CHECK_FAILS=1 "$REPO_DIR/scripts/analyse-friction.sh" > "$output_file"

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

	HOME="$home_dir" "$REPO_DIR/scripts/analyse-friction.sh" > "$output_file"

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

	HOME="$home_dir" "$REPO_DIR/scripts/analyse-friction.sh" > "$output_file"

	assert_contains "$output_file" "1	rule-ignored	/project-a	skipped review gate"
}

test_manual_writer_logs_entry() {
	local home_dir="$TEST_ROOT/manual-home"
	local log_file="$home_dir/.claude/logs/friction.log"

	(
		cd "$TEST_ROOT"
		HOME="$home_dir" bash "$REPO_DIR/scripts/log-friction.sh" "wrong-approach" "reimplemented clamp instead of using helper" >/dev/null
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
		HOME="$blocked_home" bash "$REPO_DIR/scripts/log-friction.sh" "missing-guidance" "central log was sandboxed" >/dev/null 2>/dev/null
	)

	assert_file "$log_file"
	assert_contains "$log_file" "missing-guidance"
	assert_contains "$log_file" "central log was sandboxed"
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

	HOME="$home_dir" FRICTION_DEV_ROOT="$dev_root" "$REPO_DIR/scripts/analyse-friction.sh" > "$output_file"

	assert_not_contains "$output_file" "skipped review gate"
	assert_contains "$output_file" "1	missing-guidance	/project-b	central log was sandboxed"
}

# Extracts the Codex Stop hook's check-run command from dist/codex/hooks.json.
codex_stop_command() {
	jq -r '.hooks.Stop[0].hooks[] | select(.command | startswith("if [ -f package.json")) | .command' "$REPO_DIR/dist/codex/hooks.json"
}

test_codex_hcom_hooks_bootstrap_homebrew_path() {
	local hcom_command_count
	local bootstrapped_command_count
	local hooks_file="$REPO_DIR/dist/codex/hooks.json"

	hcom_command_count=$(jq '[.hooks | to_entries[] | .value[] | .hooks[] | select(.command | contains("hcom "))] | length' "$hooks_file")
	bootstrapped_command_count=$(jq '[.hooks | to_entries[] | .value[] | .hooks[] | select(.command | contains("hcom ")) | select(.command | startswith("export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\"; hcom "))] | length' "$hooks_file")

	[ "$hcom_command_count" -eq 5 ] || fail "Expected five HCOM Codex hooks, found $hcom_command_count"
	[ "$bootstrapped_command_count" -eq "$hcom_command_count" ] || fail "HCOM Codex hooks do not all bootstrap Homebrew PATH"
}

test_codex_hook_logs_check_failure() {
	local project_dir="$TEST_ROOT/codex-failing-project"
	local home_dir="$TEST_ROOT/codex-home"
	local bin_dir="$TEST_ROOT/codex-bin-fail"
	local log_file="$home_dir/.claude/logs/friction.log"

	mkdir -p "$project_dir" "$home_dir"
	write_package "$project_dir"
	write_npm_stub "$bin_dir" 1 1

	(
		cd "$project_dir"
		HOME="$home_dir" PATH="$bin_dir:$PATH" sh -c "$(codex_stop_command)" >/dev/null 2>/dev/null
	)

	assert_file "$log_file"
	assert_contains "$log_file" "check-fail"
	assert_contains "$log_file" "$project_dir"
	assert_contains "$log_file" "lint,test:unit:run"
	assert_contains "$log_file" "lint exploded"
}

test_codex_hook_does_not_log_on_pass() {
	local project_dir="$TEST_ROOT/codex-passing-project"
	local home_dir="$TEST_ROOT/codex-pass-home"
	local bin_dir="$TEST_ROOT/codex-bin-pass"
	local log_file="$home_dir/.claude/logs/friction.log"

	mkdir -p "$project_dir" "$home_dir"
	write_package "$project_dir"
	write_npm_stub "$bin_dir" 0 0

	(
		cd "$project_dir"
		HOME="$home_dir" PATH="$bin_dir:$PATH" sh -c "$(codex_stop_command)" >/dev/null 2>/dev/null
	)

	assert_not_file "$log_file"
}

test_codex_hook_falls_back_to_project_log() {
	local project_dir="$TEST_ROOT/codex-fallback-project"
	local blocked_home="$TEST_ROOT/codex-blocked-home"
	local bin_dir="$TEST_ROOT/codex-bin-fallback"
	local log_file="$project_dir/.agent/logs/friction.log"

	mkdir -p "$project_dir"
	printf 'not a directory\n' > "$blocked_home"
	write_package "$project_dir"
	write_npm_stub "$bin_dir" 1 1

	(
		cd "$project_dir"
		HOME="$blocked_home" PATH="$bin_dir:$PATH" sh -c "$(codex_stop_command)" >/dev/null 2>/dev/null
	)

	assert_file "$log_file"
	assert_contains "$log_file" "check-fail"
	assert_contains "$log_file" "lint,test:unit:run"
}

test_failed_checks_are_logged
test_successful_checks_are_not_logged
test_analyser_groups_log_entries
test_analyser_tolerates_legacy_lines
test_analyser_excludes_resolved_pattern
test_analyser_resurfaces_pattern_after_resolution
test_manual_writer_logs_entry
test_manual_writer_falls_back_to_project_log
test_analyser_discovers_project_fallback_logs
test_codex_hcom_hooks_bootstrap_homebrew_path
test_codex_hook_logs_check_failure
test_codex_hook_does_not_log_on_pass
test_codex_hook_falls_back_to_project_log

printf '✓ friction logging tests passed\n'
