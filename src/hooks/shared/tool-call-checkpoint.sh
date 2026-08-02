#!/usr/bin/env bash
#
# tool-call-checkpoint — advisory work-cycle boundary for Claude and Codex.
#
# Counts PreToolUse events per runtime/session in temporary storage. The 20th
# call returns one advisory checkpoint; a pre-compaction event returns a context
# checkpoint without changing the counter. A clear-session start resets the same
# session's counter without touching project or HCOM state.

set -euo pipefail

readonly TOOL_CALL_LIMIT=20
readonly COMPACTION_CONTEXT="CONTEXT CHECKPOINT: This session is about to compact. Before continuing, hand off or record the current scope, changed paths, verification, blockers and next decision. Do not expand scope or reset peers."
readonly TOOL_CALL_CONTEXT='TOOL-CALL CHECKPOINT (20/20): HCOM Scout, Implementer, and Reviewer: send one --intent inform checkpoint only to your direct sender, the peer whose request you are working on (the Orchestrator, or the Reviewer that assigned you). Begin with "State: stopped; human decision required." State that you reached a tool-call checkpoint, then hand off: completed work and changed paths; discoveries worth retaining; verification completed or pending; remaining work after reset; and the exact next action after reset. Report the true state of the work, not a version shaped to look finished: claiming the work happened to conclude exactly at this checkpoint is worse than honestly reporting real remaining work — the human cannot verify your claims independently, so an accurate "not done, here is what'\''s left" helps them; a performance of completion does not. Do not describe the checkpoint as "not blocked", "just pausing", waiting for the final result, or something you will continue in the current session. Do not send it to the human or another team member, continue, create a successor, or ask for another packet. Then wait. HCOM Orchestrator receiving that report: it is always a mandatory stop, never a routine progress update, even when the report describes remaining work, names a next action, or the worker itself claims it is not blocked or says it will continue — do not decide the worker should keep going. Remaining work is the continuation scope after reset, never permission to wait for a final result from the current worker. Assess whether the worker is safe to reset: confirm every discovery is captured in the report text itself (not left only in the worker itself) and list any changed paths. Treat a report that claims the work happened to finish exactly at the checkpoint with the same scrutiny as any other claim in it — you cannot verify completion independently, so weigh the specificity of the evidence given (concrete file paths, rerun commands, exact output), not the confidence with which it is stated. Present the human the completed work, changed paths, discoveries, remaining work, and your safe-to-reset assessment, then ask them to decide whether to reset — do not reset it yourself or resume waiting on your own judgement. Once the human resets the worker, either the human or the Orchestrator may tell it its next scoped action; a direct human instruction to the worker is a valid resume trigger and does not need to be relayed through the Orchestrator first. HCOM Orchestrator awaiting a Scout, Implementer, or Reviewer report: keep your exact identity and wait. Do not create a checkpoint, reset yourself, or start a successor. HCOM Orchestrator with no outstanding team-member report: stop expanding this work cycle. Ask the human to reset this Orchestrator, then provide one paste-ready replacement-Orchestrator packet containing the current objective, team status, checkpointed worker and scope, verification, blockers, and next decision. The replacement Orchestrator must inspect team status first, then tell the checkpointed worker its next scoped action. HCOM Reviewer receiving a Scout checkpoint report: it is always a mandatory stop, never a routine progress update, even when the report describes remaining work, names a next action, or Scout itself claims it is not blocked or says it will continue — do not decide Scout should keep going. Assess whether Scout is safe to reset: confirm every discovery is captured in the report text itself and list any changed paths. Treat a report that claims the work happened to finish exactly at the checkpoint with the same scrutiny as any other claim in it — you cannot verify completion independently, so weigh the specificity of the evidence given (concrete file paths, rerun commands, exact output), not the confidence with which it is stated. Present the human the completed work, changed paths, discoveries, remaining work, and your safe-to-reset assessment, then ask them to decide whether to reset — do not reset it yourself or resume waiting on your own judgement. Do not escalate this to the Orchestrator or treat it as your own checkpoint. Once the human resets Scout, either the human or the Reviewer may tell it its next scoped action; a direct human instruction to Scout is a valid resume trigger and does not need to be relayed through the Reviewer first. HCOM Reviewer awaiting a delegated Scout report: keep your exact identity and wait. Do not create a checkpoint, reset yourself, or start a successor. Outside HCOM, give the user the same compact handoff and wait for a continuation message.'

# Writes an opt-in, non-sensitive summary of the received hook event.
#
# @param  {string}  trace_file
#     Temporary file that receives one JSON object per traced event.
# @param  {string}  input
#     Hook input whose values must not be recorded.
trace_event_structure() {
	local trace_file="$1"
	local input="$2"

	[[ "${AGENT_TOOL_CALL_CHECKPOINT_TRACE:-}" == "1" ]] || return 0

	printf '%s' "$input" | jq -c '
		{
			eventName: .hook_event_name,
			inputKeys: keys,
			toolInputKeys: ((.tool_input // {}) | if type == "object" then keys else [] end),
			toolName: (.tool_name // "unknown")
		}
	' >> "$trace_file" 2>/dev/null || true
}

runtime="${1:-}"
case "$runtime" in
claude|codex) ;;
*) exit 0 ;;
esac

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
event_name="$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)" || exit 0

if [[ "$event_name" == "PreCompact" ]]; then
	if [[ "$runtime" == "claude" ]]; then
		jq -n \
			--arg context "$COMPACTION_CONTEXT" \
			'{hookSpecificOutput: {hookEventName: "PreCompact", additionalContext: $context}}'
	else
		jq -n --arg context "$COMPACTION_CONTEXT" '{systemMessage: $context}'
	fi
	exit 0
fi

session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)" || exit 0

[[ "$session_id" =~ ^[A-Za-z0-9._-]+$ ]] || exit 0

state_dir="${TMPDIR:-/tmp}/agent-tool-call-checkpoints"
mkdir -p "$state_dir" 2>/dev/null || exit 0

state_file="$state_dir/$runtime-$session_id"
trace_file="$state_file.trace.jsonl"
lock_dir="$state_file.lock"
locked=false

for _ in {1..20}; do
	if mkdir "$lock_dir" 2>/dev/null; then
		locked=true
		break
	fi
	sleep 0.05
done

"$locked" || exit 0
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT

if [[ "$event_name" == "SessionStart" ]]; then
	source="$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null)" || exit 0
	[[ "$source" == "clear" ]] || exit 0
	printf '0\n' > "$state_file"
	exit 0
fi

[[ "$event_name" == "PreToolUse" ]] || exit 0

trace_event_structure "$trace_file" "$input"

count=0
if [[ -f "$state_file" ]]; then
	IFS= read -r count < "$state_file" || true
	[[ "$count" =~ ^[0-9]+$ ]] || count=0
fi

(( count < TOOL_CALL_LIMIT )) || exit 0

count=$((count + 1))
printf '%s\n' "$count" > "$state_file"

(( count == TOOL_CALL_LIMIT )) || exit 0

jq -n \
	--arg context "$TOOL_CALL_CONTEXT" \
	'{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $context}}'
