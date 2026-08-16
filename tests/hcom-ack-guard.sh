#!/usr/bin/env bash
# Covers the shared guard that blocks acknowledgement-only HCOM messages.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)

source "$SCRIPT_DIR/lib/test-helpers.sh"

trap cleanup EXIT

TEST_STATUS=0

# Runs the HCOM acknowledgement guard with one Bash tool payload.
#
# @param  {string}  command
#     Shell command presented to the hook.
# @param  {string}  output_file
#     File that receives the hook's standard error.
run_guard() {
	local command="$1"
	local output_file="$2"

	set +e
	jq -n --arg command "$command" '{tool_name: "Bash", tool_input: {command: $command}}' \
		| bash "$REPO_DIR/src/hooks/shared/guard-hcom-ack.sh" 2> "$output_file"
	TEST_STATUS=$?
	set -e
}

# Asserts that an acknowledgement send is blocked.
#
# @param  {string}  command
#     Shell command expected to be denied.
assert_blocked() {
	local command="$1"
	local output_file="$TEST_ROOT/blocked.txt"

	run_guard "$command" "$output_file"

	assert_equals "$TEST_STATUS" "2"
	assert_contains "$output_file" "guard-hcom-ack: blocked"
	assert_contains "$output_file" "Wait silently"
}

# Asserts that a non-acknowledgement command passes without hook output.
#
# @param  {string}  command
#     Shell command expected to be allowed.
assert_allowed() {
	local command="$1"
	local output_file="$TEST_ROOT/allowed.txt"

	run_guard "$command" "$output_file"

	assert_equals "$TEST_STATUS" "0"
	assert_empty "$output_file"
}

assert_blocked "hcom send @peer --intent ack -- 'Acknowledged'"
assert_blocked "hcom send @peer --intent=ack -- 'Acknowledged'"
assert_blocked "command hcom send @peer --intent ack -- 'Acknowledged'"
assert_blocked "printf 'done'; hcom send @peer --intent ack -- 'Acknowledged'"
assert_blocked "hcom send @peer --intent inform -- 'Acknowledged. I will run the checks.'"
assert_blocked 'hcom send @peer --intent=inform -- "I will run the checks now."'
assert_blocked "hcom send @peer --intent inform -- 'Understood, starting now.'"

assert_allowed "hcom send @peer --intent request -- 'Run checks'"
assert_allowed "hcom send @peer --intent inform -- 'Checks passed'"
assert_allowed "hcom send @peer --intent inform -- 'Correction: formatter log is available'"
assert_allowed "rg -n -- '--intent ack' teams/hcom"
assert_allowed "printf '%s' 'hcom send @peer --intent ack'"

printf '✓ HCOM acknowledgement guard tests passed\n'
