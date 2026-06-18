#!/usr/bin/env bash
# Tests the shared project diagnostics command against small mock projects.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)

source "$SCRIPT_DIR/lib/test-helpers.sh"

trap cleanup EXIT

test_local_validate_script() {
	local target_dir="$TEST_ROOT/with-validate"
	local list_output="$TEST_ROOT/with-validate-list.md"
	local output="$TEST_ROOT/with-validate.md"
	mkdir -p "$target_dir/scripts"

	printf '#!/usr/bin/env bash\nprintf "validation ok\\n"\n' > "$target_dir/scripts/validate.sh"
	chmod +x "$target_dir/scripts/validate.sh"

	"$REPO_DIR/scripts/project-diagnostics.py" --project "$target_dir" > "$list_output"

	assert_contains "$list_output" "Mode: list only. No checks were run."
	assert_contains "$list_output" "| validate | \`bash scripts/validate.sh\` |"
	assert_not_exists "$target_dir/.agent/diagnostics"

	"$REPO_DIR/scripts/project-diagnostics.py" --project "$target_dir" --check validate > "$output"

	assert_contains "$output" "Project diagnostics"
	assert_contains "$output" "| validate | passed |"
	assert_contains "$output" "validation ok"
	assert_dir "$target_dir/.agent/diagnostics"
}

test_json_skipped_when_no_safe_checks() {
	local target_dir="$TEST_ROOT/no-checks"
	local output="$TEST_ROOT/no-checks.json"
	mkdir -p "$target_dir"

	"$REPO_DIR/scripts/project-diagnostics.py" --project "$target_dir" --json --list > "$output"

	assert_contains "$output" '"mode": "list"'
	assert_contains "$output" '"checks": []'
	assert_contains "$output" "no conservative diagnostics command found"
}

test_local_validate_script
test_json_skipped_when_no_safe_checks

printf '✓ project-diagnostics tests passed\n'
