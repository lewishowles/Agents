#!/usr/bin/env bash
# Records Claude tool failures in the central friction log for recurring analysis.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat) || exit 0
tool_name=$(printf '%s' "$input" | jq -er '.tool_name | select(type == "string" and length > 0)' 2>/dev/null) || exit 0
discriminator=$(printf '%s' "$input" | jq -r '
	.tool_input as $input |
	if ($input | type) == "object" then
		[
			$input.command?,
			$input.file_path?,
			$input.path?,
			$input.pattern?,
			$input.query?,
			$input.url?,
			$input.notebook_path?,
			$input.description?,
			$input.prompt?,
			$input.old_string?,
			($input | to_entries[]? | select(.value | type == "string" and length > 0) | .value)
		]
		| map(select(type == "string" and length > 0))
		| .[0] // ""
	elif ($input | type) == "string" then
		$input
	else
		""
	end
' 2>/dev/null) || exit 0
error=$(printf '%s' "$input" | jq -r 'if (.error | type) == "string" then .error else "" end' 2>/dev/null) || exit 0

# Replaces log delimiters and keeps repeated failures byte-identical.
#
# @param  {string}  value
#     The field to sanitise and truncate.
truncate_field() {
	local value="$1"

	value="${value//$'\t'/ }"
	value="${value//$'\r'/ }"
	value="${value//$'\n'/ }"

	printf '%s' "$value" | cut -c1-300
}

tool_name=$(truncate_field "$tool_name")
discriminator=$(truncate_field "$discriminator")
error=$(truncate_field "$error")

if [[ -z "$discriminator" ]]; then
	discriminator="unknown input"
fi

if [[ -z "$error" ]]; then
	error="unknown error"
fi

detail="$tool_name: $discriminator — $error"
timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ') || exit 0
log_file="$HOME/.claude/logs/friction.log"
fallback_log_file="$PWD/.agent/logs/friction.log"

if mkdir -p "$(dirname "$log_file")" 2>/dev/null && printf '%s\t%s\t%s\t%s\n' "$timestamp" "tool-error" "$PWD" "$detail" >> "$log_file" 2>/dev/null; then
	exit 0
fi

if mkdir -p "$(dirname "$fallback_log_file")" 2>/dev/null && printf '%s\t%s\t%s\t%s\n' "$timestamp" "tool-error" "$PWD" "$detail" >> "$fallback_log_file" 2>/dev/null; then
	exit 0
fi

exit 1
