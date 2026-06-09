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

assert_contains() {
	local path="$1"
	local pattern="$2"

	grep -q "$pattern" "$path" || fail "Expected $path to contain: $pattern"
}

assert_empty() {
	local path="$1"

	[ ! -s "$path" ] || fail "Expected $path to be empty"
}

write_vitest_package() {
	local path="$1"

	cat > "$path/package.json" <<'JSON'
{
	"scripts": {
		"test:unit:run": "vitest run"
	},
	"devDependencies": {
		"vitest": "latest"
	}
}
JSON
}

run_hook() {
	local project_dir="$1"
	local file_path="$2"
	local output_file="$3"

	printf '{"tool_input":{"file_path":"%s"}}' "$file_path" | (
		cd "$project_dir"
		bash "$REPO_DIR/dist/claude/hooks/test-skeleton-reminder.sh"
	) > "$output_file"
}

test_implementation_file_without_test_emits_reminder() {
	local project_dir="$TEST_ROOT/missing-test"
	local output_file="$TEST_ROOT/missing-test.out"

	mkdir -p "$project_dir/src"
	write_vitest_package "$project_dir"

	run_hook "$project_dir" "$project_dir/src/example.ts" "$output_file"

	assert_contains "$output_file" "TEST REMINDER"
	assert_contains "$output_file" "src/example.test.ts"
}

test_existing_sibling_test_is_silent() {
	local project_dir="$TEST_ROOT/with-test"
	local output_file="$TEST_ROOT/with-test.out"

	mkdir -p "$project_dir/src"
	write_vitest_package "$project_dir"
	touch "$project_dir/src/example.test.ts"

	run_hook "$project_dir" "$project_dir/src/example.ts" "$output_file"

	assert_empty "$output_file"
}

test_test_file_is_silent() {
	local project_dir="$TEST_ROOT/test-file"
	local output_file="$TEST_ROOT/test-file.out"

	mkdir -p "$project_dir/src"
	write_vitest_package "$project_dir"

	run_hook "$project_dir" "$project_dir/src/example.test.ts" "$output_file"

	assert_empty "$output_file"
}

test_project_without_test_stack_is_silent() {
	local project_dir="$TEST_ROOT/no-tests"
	local output_file="$TEST_ROOT/no-tests.out"

	mkdir -p "$project_dir/src"
	printf '{"scripts":{"build":"vite build"}}\n' > "$project_dir/package.json"

	run_hook "$project_dir" "$project_dir/src/example.ts" "$output_file"

	assert_empty "$output_file"
}

test_implementation_file_without_test_emits_reminder
test_existing_sibling_test_is_silent
test_test_file_is_silent
test_project_without_test_stack_is_silent

printf '✓ test-skeleton reminder tests passed\n'
