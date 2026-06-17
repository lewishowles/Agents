#!/usr/bin/env bash
#
# progress-resume — UserPromptSubmit hook
#
# Detects continue-intent phrases and injects root PROGRESS.md content
# into context so Claude can resume without the user pasting the file manually.

if ! command -v jq &>/dev/null; then
	exit 0
fi

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null)

[ -z "$prompt" ] && exit 0

if ! printf '%s' "$prompt" | grep -qiE '\b(continue|carry on|pick up|resume|where were we|next step|where did we|what.s next)\b'; then
	exit 0
fi

progress_file="$PWD/PROGRESS.md"
[ -f "$progress_file" ] || exit 0

content=$(cat "$progress_file")
ctx="PROGRESS.md found:"$'\n\n'"$content"

jq -n --arg ctx "$ctx" \
	'{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
