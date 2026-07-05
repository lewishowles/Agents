#!/usr/bin/env bash
# Summarises friction log entries by aggregating counts per unique
# (category, cwd, detail) combination, sorted most frequent first. By default,
# it merges the central log with project-local fallback logs under $HOME/Dev
# and excludes automated check-fail rows. Set FRICTION_INCLUDE_CHECK_FAILS=1
# to include them when reviewing verification debt.
# Entries are written by pre-stop-checks.sh, the Codex Stop hook, and
# scripts/log-friction.sh as tab-separated lines.

set -euo pipefail

canonical_log_file="$HOME/.claude/logs/friction.log"
dev_root="${FRICTION_DEV_ROOT:-$HOME/Dev}"
include_check_fails="${FRICTION_INCLUDE_CHECK_FAILS:-0}"
log_files=()

if [ "$#" -gt 0 ]; then
	for log_file in "$@"; do
		if [[ "$(basename "$log_file")" != "friction.log" ]]; then
			printf 'Refusing non-friction-log path: %s\n' "$log_file" >&2
			exit 1
		fi
	done
	log_files=("$@")
else
	if [[ -d "$dev_root" ]]; then
		while IFS= read -r fallback_log_file; do
			if [[ "$fallback_log_file" != "$canonical_log_file" ]]; then
				log_files+=("$fallback_log_file")
			fi
		done < <(find "$dev_root" -path '*/.agent/logs/friction.log' -type f 2>/dev/null | sort)
	fi

	log_files+=("$canonical_log_file")
fi

existing_log_files=()
for log_file in "${log_files[@]}"; do
	if [[ -f "$log_file" ]]; then
		existing_log_files+=("$log_file")
	fi
done

if [ "${#existing_log_files[@]}" -eq 0 ]; then
	printf 'No friction log found'
	for log_file in "${log_files[@]}"; do
		printf ' %s' "$log_file"
	done
	printf '\n'
	exit 0
fi

merged_log_file=$(mktemp)
trap 'rm -f "$merged_log_file"' EXIT
cat "${existing_log_files[@]}" > "$merged_log_file"

# Current schema: timestamp, category, cwd, detail (field 2 = category).
# Pre-category lines used: timestamp, cwd, failed_checks, summary — field 2
# there is a path, not a known category, so those rows are treated as
# check-fail and still aggregate without a log reset.
# A RESOLVED marker (field 1 literal "RESOLVED ⇥ category ⇥ pattern ⇥ ref")
# excludes matching (category, detail) occurrences at or before its line —
# a later occurrence of the same pattern still counts, signalling the fix
# didn't hold. The file is read twice (NR == FNR) to know the marker's line
# position before filtering the second pass.
awk -F '\t' -v include_check_fails="$include_check_fails" '
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
			detail = $3
			if (NF >= 4 && $4 != "") {
				detail = detail FS $4
			}
		}

		if (category == "check-fail" && include_check_fails != "1") {
			next
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
' "$merged_log_file" "$merged_log_file" | sort -rn
