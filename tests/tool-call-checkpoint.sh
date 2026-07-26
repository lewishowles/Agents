#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)
HOOK="$REPO_DIR/dist/claude/hooks/tool-call-checkpoint.sh"

source "$SCRIPT_DIR/lib/test-helpers.sh"

trap cleanup EXIT

run_hook() {
	local runtime="$1"
	local session_id="$2"
	local event_name="$3"
	local source="${4:-}"

	printf '{"session_id":"%s","hook_event_name":"%s","source":"%s"}' "$session_id" "$event_name" "$source" | \
		TMPDIR="$TEST_ROOT/state" bash "$HOOK" "$runtime"
}

assert_checkpoint() {
	local output="$1"

	printf '%s' "$output" | jq -e '
		.hookSpecificOutput.hookEventName == "PreToolUse"
		and (.hookSpecificOutput.additionalContext | contains("TOOL-CALL CHECKPOINT (20/20)"))
		and (.hookSpecificOutput.additionalContext | contains("HCOM Scout, Implementer, and Reviewer: send this checkpoint only to your direct sender (the peer whose request you are currently working on — the Orchestrator, or the Reviewer if it assigned you):"))
		and (.hookSpecificOutput.additionalContext | contains("Please ask the human to reset me, then tell me to continue the current scoped task"))
		and (.hookSpecificOutput.additionalContext | contains("Do not continue, create a successor, or ask another team member for a packet"))
		and (.hookSpecificOutput.additionalContext | contains("HCOM Orchestrator receiving that report: tell the human that the worker hit a tool-call checkpoint"))
		and (.hookSpecificOutput.additionalContext | contains("ask them to reset that worker and let you know"))
		and (.hookSpecificOutput.additionalContext | contains("HCOM Orchestrator awaiting a Scout, Implementer, or Reviewer report"))
		and (.hookSpecificOutput.additionalContext | contains("report: keep your exact identity and wait"))
		and (.hookSpecificOutput.additionalContext | contains("HCOM Orchestrator with no outstanding team-member report"))
		and (.hookSpecificOutput.additionalContext | contains("Ask the human to reset this Orchestrator"))
		and (.hookSpecificOutput.additionalContext | contains("paste-ready replacement-Orchestrator packet"))
		and (.hookSpecificOutput.additionalContext | contains("The replacement Orchestrator must inspect team status first"))
		and (.hookSpecificOutput.additionalContext | contains("HCOM Reviewer receiving a Scout checkpoint report: tell the human that Scout hit a tool-call checkpoint"))
		and (.hookSpecificOutput.additionalContext | contains("Do not escalate this to the Orchestrator or treat it as your own checkpoint"))
		and (.hookSpecificOutput.additionalContext | contains("HCOM Reviewer awaiting a delegated Scout report: keep your exact identity and wait"))
		and (.hookSpecificOutput.additionalContext | contains("To continue, send: Continue <current task or next scoped action>."))
	' >/dev/null || fail "Expected the 20-call advisory checkpoint"
}

# Assert a runtime-specific advisory before context compaction.
#
# @param  {string}  runtime
#     The runtime that produced the hook output.
# @param  {string}  output
#     The JSON output returned by the hook.
assert_compaction_checkpoint() {
	local runtime="$1"
	local output="$2"

	if [[ "$runtime" == "claude" ]]; then
		printf '%s' "$output" | jq -e '
			.hookSpecificOutput.hookEventName == "PreCompact"
			and (.hookSpecificOutput.additionalContext | contains("CONTEXT CHECKPOINT"))
			and (.hookSpecificOutput.additionalContext | contains("Do not expand scope"))
		' >/dev/null || fail "Expected the Claude pre-compaction checkpoint"
		return
	fi

	printf '%s' "$output" | jq -e '
		.systemMessage | contains("CONTEXT CHECKPOINT")
		and contains("Do not expand scope")
	' >/dev/null || fail "Expected the Codex pre-compaction checkpoint"
}

test_warns_once_at_twenty_calls() {
	local output=""

	for _ in {1..19}; do
		output="$(run_hook claude claude-session PreToolUse)"
		assert_empty "$output"
	done

	output="$(run_hook claude claude-session PreToolUse)"
	assert_checkpoint "$output"

	output="$(run_hook claude claude-session PreToolUse)"
	assert_empty "$output"
}

test_separates_runtime_and_session_state() {
	local output=""

	for _ in {1..19}; do
		run_hook codex shared-session PreToolUse >/dev/null
	done

	output="$(run_hook claude shared-session PreToolUse)"
	assert_empty "$output"

	output="$(run_hook codex shared-session PreToolUse)"
	assert_checkpoint "$output"
}

test_clear_resets_the_counter() {
	local output=""

	for _ in {1..20}; do
		run_hook codex clear-session PreToolUse >/dev/null
	done

	output="$(run_hook codex clear-session SessionStart clear)"
	assert_empty "$output"

	for _ in {1..19}; do
		output="$(run_hook codex clear-session PreToolUse)"
		assert_empty "$output"
	done

	output="$(run_hook codex clear-session PreToolUse)"
	assert_checkpoint "$output"
}

test_warns_before_compaction_without_changing_the_counter() {
	local output=""

	output="$(run_hook claude compaction-session PreCompact)"
	assert_compaction_checkpoint claude "$output"

	output="$(run_hook codex compaction-session PreCompact)"
	assert_compaction_checkpoint codex "$output"

	for _ in {1..19}; do
		output="$(run_hook claude compaction-session PreToolUse)"
		assert_empty "$output"
	done

	output="$(run_hook claude compaction-session PreToolUse)"
	assert_checkpoint "$output"
}

test_ignores_unsafe_session_identifiers() {
	local output

	output="$(run_hook claude '../unsafe' PreToolUse)"
	assert_empty "$output"
}

test_warns_once_at_twenty_calls
test_separates_runtime_and_session_state
test_clear_resets_the_counter
test_warns_before_compaction_without_changing_the_counter
test_ignores_unsafe_session_identifiers

printf '✓ tool-call checkpoint tests passed\n'
