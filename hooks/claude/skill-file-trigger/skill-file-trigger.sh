#!/usr/bin/env bash
#
# skill-file-trigger — PreToolUse hook (Write|Edit)
#
# Data-driven: reads skill.json manifests from the repo to determine which
# skills apply to a file being written or edited. Skills declare:
#   filePatterns  — bash globs matched against the filename (basename)
#   pathPatterns  — substrings matched against the full file path
#
# Only skills with capabilities.fileTriggering = true are considered.
#
# Requires: jq — silently skips (exit 0) if missing, so writes are never blocked.

command -v jq &>/dev/null || exit 0

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

[ -z "$file_path" ] && exit 0

filename=$(basename "$file_path")

mapfile -t manifests < <(find -L "$HOME/.claude/skills" -name "skill.json" -maxdepth 2 2>/dev/null)
[ ${#manifests[@]} -eq 0 ] && exit 0

skills=()

# Use \x1f (ASCII unit separator) as field delimiter — it is not IFS whitespace
# so consecutive occurrences are not collapsed, preserving empty fields.
sep=$'\x1f'

while IFS="$sep" read -r skill_name file_patterns path_patterns; do
	matched=false

	IFS=',' read -ra fps <<< "$file_patterns"
	for pattern in "${fps[@]}"; do
		[ -z "$pattern" ] && continue
		# shellcheck disable=SC2254
		case "$filename" in
		$pattern) matched=true; break ;;
		esac
	done

	if [ "$matched" = "false" ]; then
		IFS=',' read -ra pps <<< "$path_patterns"
		for pattern in "${pps[@]}"; do
			[ -z "$pattern" ] && continue
			[[ "$file_path" == *"$pattern"* ]] && matched=true && break
		done
	fi

	[ "$matched" = "true" ] && skills+=("$skill_name")

done < <(jq -rn '
	inputs |
	select(.capabilities.fileTriggering == true) |
	[.name, (.filePatterns // [] | join(",")), (.pathPatterns // [] | join(","))] |
	join("")
' "${manifests[@]}" 2>/dev/null)

[ ${#skills[@]} -eq 0 ] && exit 0

readarray -t unique < <(printf '%s\n' "${skills[@]}" | sort -u)

jq -n \
	--arg ctx "SKILL REMINDER (${filename}): Consider these skills for the current file: ${unique[*]}." \
	'{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
