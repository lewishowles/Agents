#!/usr/bin/env bash
#
# skill-autotrigger — UserPromptSubmit hook
#
# Data-driven: reads skill.json triggers (plain strings, case-insensitive
# substring match) to determine which skills apply to the user's prompt.
# Only skills with capabilities.promptTriggering = true are considered.
#
# Continuation prompts ("yes", "continue", etc.) inject all promptTriggering
# skills as a safety net, since Claude independently decides what to write.
#
# Requires: jq (brew install jq) — hard fails and blocks the prompt if missing.

if ! command -v jq &>/dev/null; then
	printf '{"decision":"block","reason":"skill-autotrigger hook requires jq, which is not installed. Fix: brew install jq"}'
	exit 1
fi

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null)

[ -z "$prompt" ] && exit 0

mapfile -t manifests < <(find -L "$HOME/.claude/skills" -name "skill.json" -maxdepth 2 2>/dev/null)
[ ${#manifests[@]} -eq 0 ] && exit 0

skills=()

is_continuation=false
if printf '%s' "$prompt" | grep -qiE '^\s*(yes|yep|yeah|ok|okay|sure|go ahead|sounds good|perfect|great|looks good|done|next|correct|exactly)\s*[.!]?\s*$' || \
   printf '%s' "$prompt" | grep -qiE '\b(continue|carry on|move on|next step|proceed|let'\''s go|what'\''s next|keep going|move forward|let'\''s continue|crack on)\b'; then
	is_continuation=true
fi

if [ "$is_continuation" = "true" ]; then
	while IFS= read -r skill_name; do
		skills+=("$skill_name")
	done < <(jq -rn '
		inputs |
		select(.capabilities.promptTriggering == true) |
		.name
	' "${manifests[@]}" 2>/dev/null)
else
	prompt_lower=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')
	sep=$'\x1f'

	while IFS="$sep" read -r skill_name triggers_str; do
		IFS=',' read -ra triggers <<< "$triggers_str"
		for trigger in "${triggers[@]}"; do
			[ -z "$trigger" ] && continue
			trigger_lower=$(printf '%s' "$trigger" | tr '[:upper:]' '[:lower:]')
			if [[ "$prompt_lower" == *"$trigger_lower"* ]]; then
				skills+=("$skill_name")
				break
			fi
		done
	done < <(jq -rn '
		inputs |
		select(.capabilities.promptTriggering == true) |
		[.name, (.triggers // [] | join(","))] |
		join("\u001f")
	' "${manifests[@]}" 2>/dev/null)
fi

[ ${#skills[@]} -eq 0 ] && exit 0

readarray -t unique < <(printf '%s\n' "${skills[@]}" | sort -u)
list="${unique[*]}"

jq -n \
	--arg ctx "SKILL AUTO-TRIGGER: Before writing any code or content, you MUST invoke these skills using the Skill tool: ${list}. Call each one now, before any other response." \
	'{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
