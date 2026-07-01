#!/usr/bin/env bash
# Summarises friction log entries by aggregating counts per unique
# (category, cwd, detail) combination, sorted most frequent first.
# Entries are written by pre-stop-checks.sh, the Codex Stop hook, and
# scripts/log-friction.sh as tab-separated lines.

set -euo pipefail

log_file="${1:-$HOME/.claude/logs/friction.log}"  # Default path matches pre-stop-checks.sh.

if [ ! -f "$log_file" ]; then
	printf 'No friction log found at %s\n' "$log_file"
	exit 0
fi

# Current schema: timestamp, category, cwd, detail (field 2 = category).
# Pre-category lines used: timestamp, cwd, failed_checks, summary — field 2
# there is a path, not a known category, so those rows are treated as
# check-fail and still aggregate without a log reset.
# A RESOLVED marker (field 1 literal "RESOLVED ⇥ category ⇥ pattern ⇥ ref")
# excludes matching (category, detail) occurrences at or before its line —
# a later occurrence of the same pattern still counts, signalling the fix
# didn't hold. The file is read twice (NR == FNR) to know the marker's line
# position before filtering the second pass.
awk -F '\t' '
	BEGIN {
		split("rule-ignored wrong-approach token-waste tool-misuse check-fail missing-guidance", cats, " ")
		for (i in cats) known[cats[i]] = 1
	}

	NR == FNR {
		if ($1 == "RESOLVED" && NF >= 3) {
			resolved_at[$2 FS $3] = FNR
		}
		next
	}

	$1 == "RESOLVED" { next }

	NF >= 4 {
		if ($2 in known) {
			category = $2
			cwd = $3
			detail = $4
		} else {
			category = "check-fail"
			cwd = $2
			detail = $3 FS $4
		}

		pattern_key = category FS detail
		if ((pattern_key in resolved_at) && FNR <= resolved_at[pattern_key]) {
			next
		}

		key = category FS cwd FS detail
		counts[key]++
	}

	END {
		for (key in counts) {
			print counts[key] FS key
		}
	}
' "$log_file" "$log_file" | sort -rn
