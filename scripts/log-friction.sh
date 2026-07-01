#!/usr/bin/env bash
# Manually appends a friction log entry, so behavioural failures (not just
# automated check failures) can be recorded during a session.
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
timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

mkdir -p "$(dirname "$log_file")"
printf '%s\t%s\t%s\t%s\n' "$timestamp" "$category" "$PWD" "$detail" >> "$log_file"

printf 'Logged: %s — %s\n' "$category" "$detail"
