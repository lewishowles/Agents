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
readonly TOOL_CALL_CONTEXT='TOOL-CALL CHECKPOINT (20/20): HCOM Scout, Implementer, and Reviewer: send one --intent inform checkpoint only to your direct sender, the peer whose request you are working on (the Orchestrator, or the Reviewer that assigned you). Begin with "State: stopped; human decision required." State that you reached a tool-call checkpoint, then hand off: completed work and changed paths; discoveries worth retaining; verification completed or pending; remaining work; and the exact next action if continued. Report the true state of the work. Do not send it to the human or another team member, continue on your own initiative, create a successor, or ask for another packet. Then wait for a direct human continuation or reset decision. HCOM Orchestrator receiving that report: it is always a mandatory stop, never a routine progress update. Confirm every discovery is captured in the report text and list changed paths. Present the human the completed work, changed paths, discoveries, remaining work, verification, and safe-to-reset assessment. Recommend a reset by default: a fresh worker seeded with the checkpoint report and required skills reconstructs the same state at a known cost. Recommend continuing the same worker only when its own in-context state holds something the report and a fresh session could not reconstruct, and the report does not say the session is unsafe to continue; treat a worker claim of being safe to continue as one input to that judgement, not the deciding one. Do not reset it yourself or resume it on your own judgement. If the human continues the current worker, give its exact next action directly. If the human resets it, give the replacement packet the checkpoint evidence, exact next action, and required skills. HCOM Orchestrator awaiting a Scout, Implementer, or Reviewer report: keep your exact identity and wait. Do not create a checkpoint, reset yourself, or start a successor. HCOM Orchestrator with no outstanding team-member report: stop expanding this work cycle, provide the human a compact handoff, and wait for a direct continuation or reset decision. HCOM Reviewer receiving a Scout checkpoint report: it is always a mandatory stop, never a routine progress update. Confirm every discovery is captured in the report text and list changed paths. Present the human the completed work, changed paths, discoveries, remaining work, verification, and safe-to-reset assessment. Recommend a reset by default: a fresh Scout seeded with the checkpoint report and required skills reconstructs the same state at a known cost. Recommend continuing the same Scout only when its own in-context state holds something the report and a fresh session could not reconstruct, and the report does not say the session is unsafe to continue; treat a Scout claim of being safe to continue as one input to that judgement, not the deciding one. Do not escalate this to the Orchestrator or treat it as your own checkpoint. Do not reset or resume Scout on your own judgement. If the human continues Scout, give its exact next action directly. If the human resets Scout, give the replacement packet the checkpoint evidence, exact next action, and required skills. HCOM Reviewer awaiting a delegated Scout report: keep your exact identity and wait. Do not create a checkpoint, reset yourself, or start a successor. Outside HCOM, give the user the same compact handoff and wait for a continuation message.'

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
