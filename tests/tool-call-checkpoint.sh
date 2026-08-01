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
		and (.hookSpecificOutput.additionalContext | contains("send one --intent inform checkpoint only to your direct sender"))
		and (.hookSpecificOutput.additionalContext | contains("State: stopped; human decision required."))
		and (.hookSpecificOutput.additionalContext | contains("remaining work after reset; and the exact next action after reset"))
		and (.hookSpecificOutput.additionalContext | contains("Do not describe the checkpoint as \"not blocked\", \"just pausing\", waiting for the final result"))
		and (.hookSpecificOutput.additionalContext | contains("Do not send it to the human or another team member, continue, create a successor, or ask for another packet"))
		and (.hookSpecificOutput.additionalContext | contains("HCOM Orchestrator receiving that report: it is always a mandatory stop"))
		and (.hookSpecificOutput.additionalContext | contains("Remaining work is the continuation scope after reset, never permission to wait for a final result from the current worker"))
		and (.hookSpecificOutput.additionalContext | contains("Assess whether the worker is safe to reset"))
		and (.hookSpecificOutput.additionalContext | contains("Present the human the completed work, changed paths, discoveries, remaining work, and your safe-to-reset assessment"))
		and (.hookSpecificOutput.additionalContext | contains("do not reset it yourself or resume waiting on your own judgement"))
		and (.hookSpecificOutput.additionalContext | contains("Once the human resets the worker, either the human or the Orchestrator may tell it its next scoped action"))
		and (.hookSpecificOutput.additionalContext | contains("a direct human instruction to the worker is a valid resume trigger and does not need to be relayed through the Orchestrator first"))
		and (.hookSpecificOutput.additionalContext | contains("HCOM Orchestrator awaiting a Scout, Implementer, or Reviewer report"))
		and (.hookSpecificOutput.additionalContext | contains("report: keep your exact identity and wait"))
		and (.hookSpecificOutput.additionalContext | contains("HCOM Orchestrator with no outstanding team-member report"))
		and (.hookSpecificOutput.additionalContext | contains("Ask the human to reset this Orchestrator"))
		and (.hookSpecificOutput.additionalContext | contains("paste-ready replacement-Orchestrator packet"))
		and (.hookSpecificOutput.additionalContext | contains("The replacement Orchestrator must inspect team status first"))
		and (.hookSpecificOutput.additionalContext | contains("HCOM Reviewer receiving a Scout checkpoint report: it is always a mandatory stop"))
		and (.hookSpecificOutput.additionalContext | contains("Assess whether Scout is safe to reset"))
		and (.hookSpecificOutput.additionalContext | contains("Once the human resets Scout, either the human or the Reviewer may tell it its next scoped action"))
		and (.hookSpecificOutput.additionalContext | contains("a direct human instruction to Scout is a valid resume trigger and does not need to be relayed through the Reviewer first"))
		and (.hookSpecificOutput.additionalContext | contains("Do not escalate this to the Orchestrator or treat it as your own checkpoint"))
		and (.hookSpecificOutput.additionalContext | contains("HCOM Reviewer awaiting a delegated Scout report: keep your exact identity and wait"))
		and (.hookSpecificOutput.additionalContext | contains("Outside HCOM, give the user the same compact handoff"))
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

test_traces_event_structure_without_tool_arguments() {
	local output
	local trace_file="$TEST_ROOT/state/agent-tool-call-checkpoints/codex-trace-session.trace.jsonl"

	output="$(printf '%s' '{"session_id":"trace-session","hook_event_name":"PreToolUse","tool_name":"functions.exec","tool_input":{"cmd":"secret command"}}' | AGENT_TOOL_CALL_CHECKPOINT_TRACE=1 TMPDIR="$TEST_ROOT/state" bash "$HOOK" codex)"
	assert_empty "$output"

	jq -e '
		.eventName == "PreToolUse"
		and .toolName == "functions.exec"
		and .toolInputKeys == ["cmd"]
		and (has("toolInput") | not)
		and (has("session_id") | not)
	' "$trace_file" >/dev/null || fail "Expected a non-sensitive event trace"
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
test_traces_event_structure_without_tool_arguments
test_ignores_unsafe_session_identifiers

printf '✓ tool-call checkpoint tests passed\n'
