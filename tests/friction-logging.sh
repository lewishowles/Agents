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

# Writes an npm stub that mimics real npm output: a blank line and "> script"
# banner lines before the command's own output. Counts its own invocations so
# tests can assert how often the checks actually ran.
write_banner_npm_stub() {
	local bin_dir="$1"
	local count_file="$2"
	local lint_status="$3"

	mkdir -p "$bin_dir"

	cat > "$bin_dir/npm" <<STUB
#!/usr/bin/env bash

printf 'run\n' >> "$count_file"

if [ "\$1" = "run" ] && [ "\$2" = "lint" ]; then
	printf '\n> pkg@1.0.0 lint\n> eslint .\n\n/src/foo.js\n  12:5  error  Unexpected console statement\n'
	exit \${LINT_EXIT:-$lint_status}
fi

exit 1
STUB

	chmod +x "$bin_dir/npm"
}

write_lint_only_package() {
	printf '{"scripts":{"lint":"lint"}}\n' > "$1/package.json"
}

test_error_summary_skips_npm_banner() {
	local project_dir="$TEST_ROOT/banner-project"
	local home_dir="$TEST_ROOT/banner-home"
	local bin_dir="$TEST_ROOT/banner-bin"
	local log_file="$home_dir/.claude/logs/friction.log"

	mkdir -p "$project_dir" "$home_dir"
	write_lint_only_package "$project_dir"
	write_banner_npm_stub "$bin_dir" "$TEST_ROOT/banner-count" 1

	run_hook "$project_dir" "$home_dir" "$bin_dir"

	assert_file "$log_file"
	assert_contains "$log_file" "Unexpected console statement"
	assert_not_contains "$log_file" "pkg@1.0.0"
}

test_duplicate_entries_are_suppressed() {
	local project_dir="$TEST_ROOT/dupe-project"
	local home_dir="$TEST_ROOT/dupe-home"
	local bin_dir="$TEST_ROOT/dupe-bin"
	local log_file="$home_dir/.claude/logs/friction.log"
	local rows

	mkdir -p "$project_dir" "$home_dir"
	write_lint_only_package "$project_dir"
	write_banner_npm_stub "$bin_dir" "$TEST_ROOT/dupe-count" 1

	run_hook "$project_dir" "$home_dir" "$bin_dir"
	run_hook "$project_dir" "$home_dir" "$bin_dir"
	run_hook "$project_dir" "$home_dir" "$bin_dir"

	rows=$(wc -l < "$log_file" | tr -d ' ')

	[ "$rows" -eq 1 ] || fail "Expected one friction row for three identical failures, found $rows"
}

test_unchanged_passing_worktree_skips_checks() {
	local project_dir="$TEST_ROOT/fingerprint-project"
	local home_dir="$TEST_ROOT/fingerprint-home"
	local bin_dir="$TEST_ROOT/fingerprint-bin"
	local count_file="$TEST_ROOT/fingerprint-count"
	local runs
	local index

	mkdir -p "$project_dir" "$home_dir"
	write_lint_only_package "$project_dir"
	write_banner_npm_stub "$bin_dir" "$count_file" 0

	(
		cd "$project_dir"
		git init -q .
		git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
	)

	for index in $(seq 1 20); do
		run_hook "$project_dir" "$home_dir" "$bin_dir"
	done

	runs=$(wc -l < "$count_file" | tr -d ' ')

	[ "$runs" -eq 1 ] || fail "Expected one check run across 20 unchanged stops, found $runs"
}

test_changed_worktree_reruns_checks() {
	local project_dir="$TEST_ROOT/changed-project"
	local home_dir="$TEST_ROOT/changed-home"
	local bin_dir="$TEST_ROOT/changed-bin"
	local count_file="$TEST_ROOT/changed-count"
	local runs

	mkdir -p "$project_dir" "$home_dir"
	write_lint_only_package "$project_dir"
	write_banner_npm_stub "$bin_dir" "$count_file" 0

	(
		cd "$project_dir"
		git init -q .
		git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
	)

	run_hook "$project_dir" "$home_dir" "$bin_dir"
	printf 'const changed = true;\n' > "$project_dir/changed.js"
	run_hook "$project_dir" "$home_dir" "$bin_dir"

	runs=$(wc -l < "$count_file" | tr -d ' ')

	[ "$runs" -eq 2 ] || fail "Expected a rerun after the worktree changed, found $runs run(s)"
}

test_failing_worktree_is_never_cached() {
	local project_dir="$TEST_ROOT/failcache-project"
	local home_dir="$TEST_ROOT/failcache-home"
	local bin_dir="$TEST_ROOT/failcache-bin"
	local count_file="$TEST_ROOT/failcache-count"
	local runs

	mkdir -p "$project_dir" "$home_dir"
	write_lint_only_package "$project_dir"
	write_banner_npm_stub "$bin_dir" "$count_file" 1

	(
		cd "$project_dir"
		git init -q .
		git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
	)

	run_hook "$project_dir" "$home_dir" "$bin_dir"
	run_hook "$project_dir" "$home_dir" "$bin_dir"
	run_hook "$project_dir" "$home_dir" "$bin_dir"

	runs=$(wc -l < "$count_file" | tr -d ' ')

	[ "$runs" -eq 3 ] || fail "A failing tree must be rechecked every stop, found $runs run(s)"
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

# Extracts the Codex Stop hook's check-run command from dist/codex/hooks.toml.
codex_stop_command() {
	python3 - "$REPO_DIR/dist/codex/hooks.toml" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as hooks_file:
	for line in hooks_file:
		if line.startswith('command = "if [ -f package.json'):
			print(json.loads(line.removeprefix("command = ")))
PY
}

test_codex_hcom_hooks_bootstrap_homebrew_path() {
	local hcom_command_count
	local bootstrapped_command_count
	local hooks_file="$REPO_DIR/dist/codex/hooks.toml"

	hcom_command_count=$(rg -c 'hcom ' "$hooks_file")
	bootstrapped_command_count=$(rg -c '^command = "export PATH=\\"/opt/homebrew/bin:/usr/local/bin:\$PATH\\"; hcom ' "$hooks_file")

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
test_error_summary_skips_npm_banner
test_duplicate_entries_are_suppressed
test_unchanged_passing_worktree_skips_checks
test_changed_worktree_reruns_checks
test_failing_worktree_is_never_cached
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
