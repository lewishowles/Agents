#!/usr/bin/env bash
# Tests the change impact reporter against small Git repositories.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)

source "$SCRIPT_DIR/lib/test-helpers.sh"

trap cleanup EXIT

run_impact() {
	local target_dir="$1"
	shift

	"$REPO_DIR/scripts/validate/change-impact.py" --project-dir "$target_dir" "$@"
}

init_repo() {
	local target_dir="$1"

	git -C "$target_dir" init --initial-branch=main >/dev/null
	git -C "$target_dir" config user.email "test@example.com"
	git -C "$target_dir" config user.name "Test User"
	git -C "$target_dir" add -f . >/dev/null
	git -C "$target_dir" commit -m "Initial" >/dev/null
}

create_project() {
	local target_dir="$1"

	mkdir -p "$target_dir/scripts" "$target_dir/src" "$target_dir/tests"
	printf '#!/usr/bin/env bash\nprintf "ok\\n"\n' > "$target_dir/scripts/validate.sh"
	printf 'print("hello")\n' > "$target_dir/src/app.py"
	printf 'test\n' > "$target_dir/tests/app.test.py"
	init_repo "$target_dir"
}

create_config_repo() {
	local target_dir="$1"

	mkdir -p "$target_dir/dist/claude" "$target_dir/src/rules" "$target_dir/scripts"
	printf '#!/usr/bin/env bash\n' > "$target_dir/scripts/sync.sh"
	printf 'source\n' > "$target_dir/src/rules/global-rules.md"
	printf 'generated\n' > "$target_dir/dist/claude/CLAUDE.md"
	init_repo "$target_dir"
}

test_markdown_groups_paths_and_suggests_checks() {
	local target_dir="$TEST_ROOT/markdown"
	local output="$TEST_ROOT/markdown.md"
	create_project "$target_dir"
	printf 'change\n' >> "$target_dir/src/app.py"
	printf 'change\n' >> "$target_dir/tests/app.test.py"

	run_impact "$target_dir" > "$output"

	assert_contains "$output" "# Change impact"
	assert_contains "$output" "| Source | 1 | \`src/app.py\` |"
	assert_contains "$output" "| Tests | 1 | \`tests/app.test.py\` |"
	assert_contains "$output" "\`bash scripts/validate.sh\`"
}

test_generated_guard_findings_are_reported() {
	local target_dir="$TEST_ROOT/stale"
	local output="$TEST_ROOT/stale.md"
	create_config_repo "$target_dir"
	printf 'change\n' >> "$target_dir/src/rules/global-rules.md"

	if run_impact "$target_dir" > "$output"; then
		fail "Expected generated/source mismatch to fail"
	fi

	assert_contains "$output" "source changed but generated output is not changed"
	assert_contains "$output" "Generated/source mismatch detected"
}

test_json_output_is_machine_readable() {
	local target_dir="$TEST_ROOT/json"
	local output="$TEST_ROOT/impact.json"
	create_project "$target_dir"
	printf 'change\n' >> "$target_dir/scripts/validate.sh"

	run_impact "$target_dir" --json > "$output"

	python3 - "$output" <<'PY'
import json
import sys

data = json.loads(open(sys.argv[1]).read())
assert data["changed_count"] == 1
assert data["changed"][0]["category"] == "scripts"
assert data["risks"][0]["code"] == "scripts-changed"
PY
}

test_markdown_groups_paths_and_suggests_checks
test_generated_guard_findings_are_reported
test_json_output_is_machine_readable

printf '✓ change-impact tests passed\n'
