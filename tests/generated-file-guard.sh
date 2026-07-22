#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)

source "$SCRIPT_DIR/lib/test-helpers.sh"

trap cleanup EXIT

run_guard() {
	local target_dir="$1"
	shift

	"$REPO_DIR/scripts/validate/generated-file-guard.py" --project-dir "$target_dir" "$@"
}

init_repo() {
	local target_dir="$1"

	git -C "$target_dir" init --initial-branch=main >/dev/null
	git -C "$target_dir" config user.email "test@example.com"
	git -C "$target_dir" config user.name "Test User"
	git -C "$target_dir" add -f . >/dev/null
	git -C "$target_dir" commit -m "Initial" >/dev/null
}

create_config_repo() {
	local target_dir="$1"

	mkdir -p "$target_dir/dist/claude" "$target_dir/src/rules" "$target_dir/scripts"
	printf '#!/usr/bin/env bash\n' > "$target_dir/scripts/sync.sh"
	printf 'source\n' > "$target_dir/src/rules/global-rules.md"
	printf 'generated\n' > "$target_dir/dist/claude/CLAUDE.md"
	init_repo "$target_dir"
}

create_skill_repo() {
	local target_dir="$1"

	mkdir -p "$target_dir/dist/claude" "$target_dir/dist/skills/example" "$target_dir/dist/skills/excluded" "$target_dir/docs" "$target_dir/src/rules" "$target_dir/scripts" "$target_dir/src/skills/example/example" "$target_dir/src/skills/example/excluded"
	printf '#!/usr/bin/env bash\n' > "$target_dir/scripts/sync.sh"
	printf '{"name":"example"}\n' > "$target_dir/src/skills/example/example/skill.json"
	printf 'body\n' > "$target_dir/src/skills/example/example/SKILL.body.md"
	printf 'generated skill\n' > "$target_dir/dist/skills/example/SKILL.md"
	printf '{"name":"excluded","targets":["claude","codex"]}\n' > "$target_dir/src/skills/example/excluded/skill.json"
	printf 'excluded body\n' > "$target_dir/src/skills/example/excluded/SKILL.body.md"
	printf 'excluded generated skill\n' > "$target_dir/dist/skills/excluded/SKILL.md"
	printf 'docs\n' > "$target_dir/docs/skills.md"
	init_repo "$target_dir"
}

test_generated_only_change_fails() {
	local target_dir="$TEST_ROOT/generated-only"
	local output="$TEST_ROOT/generated-only.md"
	create_config_repo "$target_dir"
	printf 'changed\n' >> "$target_dir/dist/claude/CLAUDE.md"

	if run_guard "$target_dir" > "$output"; then
		fail "Expected generated-only change to fail"
	fi

	assert_contains "$output" "generated output changed without its source"
	assert_contains "$output" "rules/"
}

test_source_without_generated_fails() {
	local target_dir="$TEST_ROOT/stale"
	local output="$TEST_ROOT/stale.md"
	create_config_repo "$target_dir"
	printf 'changed\n' >> "$target_dir/src/rules/global-rules.md"

	if run_guard "$target_dir" > "$output"; then
		fail "Expected source-only change to fail"
	fi

	assert_contains "$output" "source changed but generated output is not changed"
	assert_contains "$output" "Run \`scripts/sync.sh\`"
}

test_source_and_generated_passes() {
	local target_dir="$TEST_ROOT/synced"
	local output="$TEST_ROOT/synced.md"
	create_config_repo "$target_dir"
	printf 'changed\n' >> "$target_dir/src/rules/global-rules.md"
	printf 'changed\n' >> "$target_dir/dist/claude/CLAUDE.md"

	run_guard "$target_dir" > "$output"

	assert_contains "$output" "No generated-file issues detected."
}

test_generic_generated_only_change_fails() {
	local target_dir="$TEST_ROOT/generic"
	local output="$TEST_ROOT/generic.md"
	mkdir -p "$target_dir/dist"
	printf 'generated\n' > "$target_dir/dist/app.js"
	init_repo "$target_dir"
	printf 'changed\n' >> "$target_dir/dist/app.js"

	if run_guard "$target_dir" > "$output"; then
		fail "Expected generic generated-only change to fail"
	fi

	assert_contains "$output" "Generated output changed without any source change"
}

test_skill_source_with_generated_outputs_does_not_require_claude_index() {
	local target_dir="$TEST_ROOT/skill"
	local output="$TEST_ROOT/skill.md"
	create_skill_repo "$target_dir"
	printf '{"name":"example","description":"changed"}\n' > "$target_dir/src/skills/example/example/skill.json"
	printf 'changed\n' >> "$target_dir/dist/skills/example/SKILL.md"
	printf 'changed\n' >> "$target_dir/docs/skills.md"

	run_guard "$target_dir" > "$output"

	assert_contains "$output" "No generated-file issues detected."
}

test_skill_body_with_generated_skill_output_does_not_require_indexes() {
	local target_dir="$TEST_ROOT/skill-body"
	local output="$TEST_ROOT/skill-body.md"
	create_skill_repo "$target_dir"
	printf 'changed\n' >> "$target_dir/src/skills/example/example/SKILL.body.md"
	printf 'changed\n' >> "$target_dir/dist/skills/example/SKILL.md"

	run_guard "$target_dir" > "$output"

	assert_contains "$output" "No generated-file issues detected."
}

test_excluded_skill_body_change_is_in_sync() {
	local target_dir="$TEST_ROOT/excluded-skill-body"
	local output="$TEST_ROOT/excluded-skill-body.md"
	create_skill_repo "$target_dir"
	printf 'changed\n' >> "$target_dir/src/skills/example/excluded/SKILL.body.md"
	printf 'changed\n' >> "$target_dir/dist/skills/excluded/SKILL.md"

	run_guard "$target_dir" > "$output"

	assert_contains "$output" "No generated-file issues detected."
}

test_skill_metadata_without_indexes_fails() {
	local target_dir="$TEST_ROOT/skill-metadata"
	local output="$TEST_ROOT/skill-metadata.md"
	create_skill_repo "$target_dir"
	printf '{"name":"example","description":"changed"}\n' > "$target_dir/src/skills/example/example/skill.json"
	printf 'changed\n' >> "$target_dir/dist/skills/example/SKILL.md"

	if run_guard "$target_dir" > "$output"; then
		fail "Expected skill metadata change without docs or index updates to fail"
	fi

	assert_contains "$output" "generated docs tables source changed but generated output is not changed"
}

test_json_output_is_machine_readable() {
	local target_dir="$TEST_ROOT/json"
	local output="$TEST_ROOT/guard.json"
	create_config_repo "$target_dir"
	printf 'changed\n' >> "$target_dir/src/rules/global-rules.md"

	if run_guard "$target_dir" --json > "$output"; then
		fail "Expected stale generated output to fail"
	fi

	python3 - "$output" <<'PY'
import json
import sys

data = json.loads(open(sys.argv[1]).read())
assert data["ok"] is False
assert data["findings"][0]["code"] == "generated-stale"
PY
}

test_generated_only_change_fails
test_source_without_generated_fails
test_source_and_generated_passes
test_generic_generated_only_change_fails
test_skill_source_with_generated_outputs_does_not_require_claude_index
test_skill_body_with_generated_skill_output_does_not_require_indexes
test_excluded_skill_body_change_is_in_sync
test_skill_metadata_without_indexes_fails
test_json_output_is_machine_readable

printf '✓ generated-file-guard tests passed\n'
