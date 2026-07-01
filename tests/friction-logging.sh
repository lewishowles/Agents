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

	assert_contains "$output_file" "2	check-fail	/legacy-project	lint	lint exploded"
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

test_failed_checks_are_logged
test_successful_checks_are_not_logged
test_analyser_groups_log_entries
test_analyser_tolerates_legacy_lines
test_manual_writer_logs_entry

printf '✓ friction logging tests passed\n'
