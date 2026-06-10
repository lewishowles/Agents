#!/usr/bin/env bash
# Summarises friction log entries by aggregating counts per unique
# (hook, event, message) combination, sorted most frequent first.
# Friction entries are written by pre-stop-checks.sh as tab-separated lines.

set -euo pipefail

log_file="${1:-$HOME/.claude/logs/friction.log}"  # Default path matches pre-stop-checks.sh.

if [ ! -f "$log_file" ]; then
	printf 'No friction log found at %s\n' "$log_file"
	exit 0
fi

# Fields 2–4 (hook, event, message) form the deduplication key.
# Field 1 is a timestamp, which is intentionally excluded from grouping.
awk -F '\t' '
	NF >= 4 {
		key = $2 FS $3 FS $4
		counts[key]++
	}

	END {
		for (key in counts) {
			print counts[key] FS key
		}
	}
' "$log_file" | sort -rn
