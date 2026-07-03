#!/usr/bin/env bash
# Manually appends a friction log entry, falling back to the current project's
# .agent/logs/friction.log when the central log is not writable.
#
# Usage: scripts/log-friction.sh "<category>" "<detail>"
# Categories: rule-ignored, wrong-approach, token-waste, tool-misuse,
# check-fail, missing-guidance.

set -euo pipefail

if [ "$#" -lt 2 ]; then
	printf 'Usage: %s "<category>" "<detail>"\n' "$0" >&2
	exit 1
fi

category="$1"
detail="$2"
log_file="$HOME/.claude/logs/friction.log"
fallback_log_file="$PWD/.agent/logs/friction.log"
timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Appends the entry to the given log path.
#
# @param  {string}  path
#     The friction log path to write.
write_entry() {
	local path="$1"

	mkdir -p "$(dirname "$path")"
	printf '%s\t%s\t%s\t%s\n' "$timestamp" "$category" "$PWD" "$detail" >> "$path"
}

if write_entry "$log_file" 2>/dev/null; then
	printf 'Logged: %s — %s\n' "$category" "$detail"
elif write_entry "$fallback_log_file"; then
	printf 'Friction log unavailable at %s; logged to %s\n' "$log_file" "$fallback_log_file" >&2
	printf 'Logged: %s — %s\n' "$category" "$detail"
else
	printf 'Could not write friction log entry to %s or %s\n' "$log_file" "$fallback_log_file" >&2
	exit 1
fi
