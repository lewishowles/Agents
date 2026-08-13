#!/usr/bin/env bash
# Blocks acknowledgement-only HCOM messages from agent tool calls.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)" || exit 0
[[ "$tool_name" == "Bash" ]] || exit 0

command_str="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)" || exit 0
[[ -n "$command_str" ]] || exit 0

normalised_command="${command_str//$'\n'/;}"
hcom_send_pattern='(^|[;&|][[:space:]]*)(command[[:space:]]+)?hcom[[:space:]]+send([[:space:]]|$)'
ack_intent_pattern='(^|[[:space:]])--intent(=|[[:space:]]+)ack([[:space:]]|$)'

if [[ "$normalised_command" =~ $hcom_send_pattern ]] && [[ "$normalised_command" =~ $ack_intent_pattern ]]; then
	printf 'guard-hcom-ack: blocked: HCOM team roles do not send acknowledgement messages. Wait silently for actionable work or send a terminal result, blocker, decision, or correction.\n' >&2
	exit 2
fi

exit 0
