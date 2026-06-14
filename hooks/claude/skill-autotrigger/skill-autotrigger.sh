#!/usr/bin/env bash
#
# skill-autotrigger — UserPromptSubmit hook
#
# Data-driven: reads skill.json triggers (case-insensitive) to determine which
# skills apply to the user's prompt. Only skills with capabilities.promptTriggering
# = true are considered.
#
# Matching strategy:
#   - Triggers starting with an alphanumeric char use word-boundary matching via
#     ERE so that e.g. "struct" does not fire on "instructions".
#   - Triggers starting with a non-word char (. @ # ! etc.) use substring match
#     since they are specific by nature (e.g. ".vue", "@state", "#!/").
#
# Continuation prompts ("yes", "continue", etc.) inject only the skills that
# were triggered earlier in the session (tracked in a temp file). If no session
# history exists, nothing is injected.
#
# Requires: jq (brew install jq) — hard fails and blocks the prompt if missing.

if ! command -v jq &>/dev/null; then
	printf '{"decision":"block","reason":"skill-autotrigger hook requires jq, which is not installed. Fix: brew install jq"}'
	exit 1
fi

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null)

[ -z "$prompt" ] && exit 0

session_file="/tmp/claude-autotrigger-$PPID"
find /tmp -name 'claude-autotrigger-*' -mtime +1 -delete 2>/dev/null || true

mapfile -t manifests < <(find -L "$HOME/.claude/skills" -name "skill.json" -maxdepth 2 2>/dev/null)
[ ${#manifests[@]} -eq 0 ] && exit 0

skills=()

is_continuation=false
if printf '%s' "$prompt" | grep -qiE '^\s*(yes|yep|yeah|ok|okay|sure|go ahead|sounds good|perfect|great|looks good|done|next|correct|exactly)\s*[.!]?\s*$' || \
   printf '%s' "$prompt" | grep -qiE '\b(continue|carry on|move on|next step|proceed|let'"'"'s go|what'"'"'s next|keep going|move forward|let'"'"'s continue|crack on)\b'; then
	is_continuation=true
fi

if [ "$is_continuation" = "true" ]; then
	if [[ -f "$session_file" ]]; then
		while IFS= read -r skill_name; do
			[ -n "$skill_name" ] && skills+=("$skill_name")
		done < "$session_file"
	fi
	[ ${#skills[@]} -eq 0 ] && exit 0
else
	prompt_lower=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')
	sep=$'\x1f'

	# Match trigger against prompt. Alphanumeric-starting triggers use word-boundary
	# ERE; symbol triggers use substring match.
	matches_trigger() {
		local trigger_lower="$1" prompt_lower="$2"
		if [[ ! "$trigger_lower" =~ ^[a-z0-9] ]]; then
			[[ "$prompt_lower" == *"$trigger_lower"* ]]
			return
		fi
		local escaped last_char
		escaped=$(printf '%s' "$trigger_lower" | sed 's/[]\[.^$*?+{}()|\\]/\\&/g')
		last_char="${trigger_lower: -1}"
		if [[ "$last_char" =~ [a-z0-9_] ]]; then
			printf '%s' "$prompt_lower" | grep -qE "(^|[^[:alnum:]_])${escaped}([^[:alnum:]_]|$)"
		else
			printf '%s' "$prompt_lower" | grep -qE "(^|[^[:alnum:]_])${escaped}"
		fi
	}

	while IFS="$sep" read -r skill_name triggers_str; do
		IFS=',' read -ra triggers <<< "$triggers_str"
		for trigger in "${triggers[@]}"; do
			[ -z "$trigger" ] && continue
			trigger_lower=$(printf '%s' "$trigger" | tr '[:upper:]' '[:lower:]')
			if matches_trigger "$trigger_lower" "$prompt_lower"; then
				skills+=("$skill_name")
				break
			fi
		done
	done < <(jq -rn '
		inputs |
		select(.capabilities.promptTriggering == true) |
		[.name, (.triggers // [] | join(","))] |
		join("")
	' "${manifests[@]}" 2>/dev/null)

	if [ ${#skills[@]} -gt 0 ]; then
		printf '%s\n' "${skills[@]}" | sort -u > "$session_file"
	fi
fi

[ ${#skills[@]} -eq 0 ] && exit 0

readarray -t unique < <(printf '%s\n' "${skills[@]}" | sort -u)
list="${unique[*]}"

if [ "$is_continuation" = "true" ]; then
	jq -n \
		--arg ctx "Active skills from this session (re-invoke if still relevant): ${list}." \
		'{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
else
	jq -n \
		--arg ctx "SKILL AUTO-TRIGGER: Before writing any code or content, you MUST invoke these skills using the Skill tool: ${list}. Call each one now, before any other response." \
		'{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
fi
