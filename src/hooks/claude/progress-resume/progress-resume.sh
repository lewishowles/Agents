#!/usr/bin/env bash
#
# progress-resume — UserPromptSubmit hook
#
# Detects continue-intent phrases and injects current progress context
# so Claude can resume without the user restating the project state.

if ! command -v jq &>/dev/null; then
	exit 0
fi

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null)

if [[ -z "$prompt" ]]; then
	exit 0
fi

if ! printf '%s' "$prompt" | grep -qiE '\b(continue|carry on|pick up|resume|where were we|next step|where did we|what.s next)\b'; then
	exit 0
fi

ctx=""
if command -v progress &>/dev/null; then
	progress_output=$(progress next --json 2>/dev/null) || progress_output=""
	if [[ -n "$progress_output" ]] && printf '%s' "$progress_output" | jq -e 'type == "object"' >/dev/null 2>&1; then
		ctx="Current project progress from progress next --json:"$'\n\n'"$progress_output"
	fi
fi

if [[ -z "$ctx" ]]; then
	if [[ -f "$PWD/WORKSPACE.md" ]]; then
		ctx="Project progress is unavailable. Inspect WORKSPACE.md first, then AGENTS.md and nearby project docs, before continuing."
	elif [[ -f "$PWD/AGENT_CAPABILITIES.md" ]]; then
		ctx="Project progress is unavailable and WORKSPACE.md is absent. Inspect AGENT_CAPABILITIES.md first, then AGENTS.md and nearby project docs, before continuing."
	else
		ctx="Project progress is unavailable and WORKSPACE.md is absent. Inspect AGENTS.md, package scripts, and nearby project docs before continuing."
	fi
fi

jq -n --arg ctx "$ctx" \
	'{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
