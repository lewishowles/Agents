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

assert_not_file() {
	local path="$1"

	[ ! -f "$path" ] || fail "Expected no file: $path"
}

assert_contains() {
	local path="$1"
	local pattern="$2"

	grep -q "$pattern" "$path" || fail "Expected $path to contain: $pattern"
}

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
	printf '2026-05-15T19:00:00Z\t/project-a\tlint\tlint exploded\n' > "$log_file"
	printf '2026-05-15T19:01:00Z\t/project-a\tlint\tlint exploded\n' >> "$log_file"
	printf '2026-05-15T19:02:00Z\t/project-b\ttest:unit:run\tunit tests exploded\n' >> "$log_file"

	HOME="$home_dir" "$REPO_DIR/scripts/analyse-friction.sh" > "$output_file"

	assert_contains "$output_file" "2	/project-a	lint	lint exploded"
	assert_contains "$output_file" "1	/project-b	test:unit:run	unit tests exploded"
}

test_failed_checks_are_logged
test_successful_checks_are_not_logged
test_analyser_groups_log_entries

printf '✓ friction logging tests passed\n'
