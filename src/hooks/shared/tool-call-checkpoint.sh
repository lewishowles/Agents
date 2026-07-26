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
readonly TOOL_CALL_CONTEXT='TOOL-CALL CHECKPOINT (20/20): HCOM Scout, Implementer, and Reviewer: send this checkpoint only to your direct sender, the Orchestrator: "I hit a tool-call checkpoint. Please ask the human to reset me, then tell me to continue the current scoped task." Do not continue, create a successor, or ask another team member for a packet. Then wait. HCOM Orchestrator receiving that report: tell the human that the worker hit a tool-call checkpoint, ask them to reset that worker and let you know, then send the reset worker: "Continue <current task or next scoped action>." HCOM Orchestrator awaiting a Scout, Implementer, or Reviewer report: keep your exact identity and wait. Do not create a checkpoint, reset yourself, or start a successor. HCOM Orchestrator with no outstanding team-member report: stop expanding this work cycle. Ask the human to reset this Orchestrator, then provide one paste-ready replacement-Orchestrator packet containing the current objective, team status, checkpointed worker and scope, verification, blockers, and next decision. The replacement Orchestrator must inspect team status first, then send the checkpointed worker: "Continue <current task or next scoped action>." Outside HCOM, tell the user exactly: "To continue, send: Continue <current task or next scoped action>."'

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
