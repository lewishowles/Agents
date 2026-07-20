#!/usr/bin/env bash
# Exercises instruction byte-budget pass, warning, and malformed-baseline cases.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
VALIDATOR="$SCRIPT_DIR/check-instruction-budgets.sh"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE_REPO="$TMP_DIR/repo"
BASELINE_FILE="$TMP_DIR/instruction-budgets.json"

mkdir -p "$FIXTURE_REPO/dist/claude" "$FIXTURE_REPO/dist/codex" \
	"$FIXTURE_REPO/dist/skills/demo" "$FIXTURE_REPO/skills/demo"
printf 'claude\n' > "$FIXTURE_REPO/dist/claude/CLAUDE.md"
printf 'codex\n' > "$FIXTURE_REPO/dist/codex/AGENTS.md"
printf 'skill\n' > "$FIXTURE_REPO/dist/skills/demo/SKILL.md"
printf '{"name":"demo"}\n' > "$FIXTURE_REPO/skills/demo/skill.json"
printf '# Demo\n' > "$FIXTURE_REPO/skills/demo/SKILL.body.md"

# Returns the UTF-8 byte count for a fixture file.
#
# @param  {string}  file
#     Fixture file to measure.
byte_count() {
	local file="$1"

	wc -c < "$file" | tr -d '[:space:]'
}

# Writes a minimal baseline containing one artefact in each class.
#
# @param  {string}  always_loaded_bytes
#     Baseline for the generated Codex instruction file.
# @param  {string}  skill_body_bytes
#     Baseline for the generated demo skill body.
# @param  {string}  eager_metadata_bytes
#     Baseline for the demo skill manifest.
write_baseline() {
	local always_loaded_bytes="$1"
	local skill_body_bytes="$2"
	local eager_metadata_bytes="$3"

	printf '{\n  "always_loaded": {"dist/codex/AGENTS.md": %s},\n  "skill_bodies": {"dist/skills/demo/SKILL.md": %s},\n  "eager_metadata": {"skills/demo/skill.json": %s}\n}\n' \
		"$always_loaded_bytes" "$skill_body_bytes" "$eager_metadata_bytes" > "$BASELINE_FILE"
}

# Runs the validator against the temporary fixture repository.
run_validator() {
	set +e
	TEST_OUTPUT=$(INSTRUCTION_BUDGET_REPO_DIR="$FIXTURE_REPO" INSTRUCTION_BUDGET_BASELINE="$BASELINE_FILE" bash "$VALIDATOR" 2>&1)
	TEST_STATUS=$?
	set -e
}

# Fails the self-test when two values differ.
#
# @param  {string}  expected
#     Expected value.
# @param  {string}  actual
#     Actual value.
# @param  {string}  message
#     Failure message.
assert_equal() {
	local expected="$1"
	local actual="$2"
	local message="$3"

	if [ "$expected" != "$actual" ]; then
		printf 'FAIL %s: expected %s, got %s\n' "$message" "$expected" "$actual" >&2
		exit 1
	fi
}

# Fails the self-test when output does not contain a required fragment.
#
# @param  {string}  fragment
#     Expected output fragment.
# @param  {string}  message
#     Failure message.
assert_contains() {
	local fragment="$1"
	local message="$2"

	case "$TEST_OUTPUT" in
		*"$fragment"*) ;;
		*)
			printf 'FAIL %s: missing %s\n%s\n' "$message" "$fragment" "$TEST_OUTPUT" >&2
			exit 1
			;;
	esac
}

claude_bytes=$(byte_count "$FIXTURE_REPO/dist/claude/CLAUDE.md")
codex_bytes=$(byte_count "$FIXTURE_REPO/dist/codex/AGENTS.md")
skill_bytes=$(byte_count "$FIXTURE_REPO/dist/skills/demo/SKILL.md")
metadata_bytes=$(byte_count "$FIXTURE_REPO/skills/demo/skill.json")

write_baseline "$codex_bytes" "$skill_bytes" "$metadata_bytes"
run_validator
assert_equal 0 "$TEST_STATUS" "pass case status"
assert_equal '' "$TEST_OUTPUT" "pass case output"
printf 'PASS pass case\n'

write_baseline 0 0 0
NO_COLOR= run_validator
assert_equal 0 "$TEST_STATUS" "warning case status"
assert_contains 'dist/codex/AGENTS.md:' 'always-loaded warning'
assert_contains '⚠' 'warning status icon'
assert_contains $'\n↳ edit:' 'muted source hint'
assert_contains 'dist/codex/source or rules/ inputs' 'always-loaded source hint'
assert_contains 'skills/demo/SKILL.body.md' 'skill-body source hint'
assert_contains 'skills/demo/skill.json' 'eager-metadata source hint'
assert_contains 'bytes' 'warning byte details'
assert_contains 'baseline' 'warning baseline details'
printf 'PASS warning case\n'

NO_COLOR=1 run_validator
assert_equal 0 "$TEST_STATUS" "no-colour warning case status"
case "$TEST_OUTPUT" in
	*$'\033'*)
		printf 'FAIL no-colour warning case contains ANSI escape codes\n%s\n' "$TEST_OUTPUT" >&2
		exit 1
		;;
esac
assert_contains $'\n↳ edit:  dist/codex/source or rules/ inputs' 'no-colour source hint'
printf 'PASS no-colour warning case\n'

printf '{\n' > "$BASELINE_FILE"
run_validator
if [ "$TEST_STATUS" -eq 0 ]; then
	printf 'FAIL invalid JSON case did not fail\n' >&2
	exit 1
fi
assert_contains 'invalid JSON' 'invalid JSON failure'
printf 'PASS invalid JSON case\n'

printf '{"always_loaded": {}, "eager_metadata": {}}\n' > "$BASELINE_FILE"
run_validator
if [ "$TEST_STATUS" -eq 0 ]; then
	printf 'FAIL missing class case did not fail\n' >&2
	exit 1
fi
assert_contains "missing top-level class 'skill_bodies'" 'missing class failure'
printf 'PASS missing class case\n'
