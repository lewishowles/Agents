#!/usr/bin/env bash
# Summarises friction log entries by aggregating counts per unique
# (category, cwd, detail) combination, sorted most frequent first. By default,
# it merges the central log with project-local fallback logs under $HOME/Dev
# and excludes automated check-fail rows. Set FRICTION_INCLUDE_CHECK_FAILS=1
# to include them when reviewing verification debt.
# Entries are written by pre-stop-checks.sh, the Codex Stop hook, and
# scripts/agent-tools/log-friction.sh as tab-separated lines.

set -euo pipefail

# Temporary root used by --selftest and cleaned up on exit.
SELFTEST_ROOT=""

# Fails when analyser output omits an expected row.
#
# @param  {string}  output
#     Analyser output to inspect.
# @param  {string}  expected
#     Tab-separated row fragment expected in the output.
selftest_assert_contains() {
	local output="$1"
	local expected="$2"

	if [[ "$output" != *"$expected"* ]]; then
		printf 'Self-test expected output to contain: %s\nActual output:\n%s' "$expected" "$output" >&2
		return 1
	fi
}

# Fails when analyser output includes a row that should have been filtered.
#
# @param  {string}  output
#     Analyser output to inspect.
# @param  {string}  unexpected
#     Row fragment that must not appear in the output.
selftest_assert_not_contains() {
	local output="$1"
	local unexpected="$2"

	if [[ "$output" == *"$unexpected"* ]]; then
		printf 'Self-test expected output not to contain: %s\nActual output:\n%s' "$unexpected" "$output" >&2
		return 1
	fi
}

# Exercises the analyser's filtering and aggregation contract using temporary logs.
run_selftest() {
	local script_path
	local grouped_log
	local grouped_output
	local grouped_with_check_fails
	local home_dir
	local dev_root
	local fallback_log
	local canonical_log
	local discovered_output

	SELFTEST_ROOT=$(mktemp -d)
	trap 'rm -rf "$SELFTEST_ROOT"' EXIT
	script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

	grouped_log="$SELFTEST_ROOT/group/friction.log"
	mkdir -p "$(dirname "$grouped_log")"
	printf '2026-05-15T19:00:00Z\trule-ignored\t/project-a\tskipped review gate\n' > "$grouped_log"
	printf '2026-05-15T19:01:00Z\trule-ignored\t/project-a\tskipped review gate\n' >> "$grouped_log"
	printf '2026-05-15T19:02:00Z\tcheck-fail\t/project-b\ttest:unit:run: unit tests exploded\n' >> "$grouped_log"
	printf '2026-05-15T19:03:00Z\t/legacy-project\tlint\tlint exploded\n' >> "$grouped_log"
	printf '2026-05-15T19:04:00Z\t/legacy-project\tlint\tlint exploded\n' >> "$grouped_log"

	grouped_output=$(bash "$script_path" "$grouped_log")
	selftest_assert_contains "$grouped_output" $'2\trule-ignored\t/project-a\tskipped review gate'
	selftest_assert_not_contains "$grouped_output" $'check-fail'

	grouped_with_check_fails=$(FRICTION_INCLUDE_CHECK_FAILS=1 bash "$script_path" "$grouped_log")
	selftest_assert_contains "$grouped_with_check_fails" $'1\tcheck-fail\t/project-b\ttest:unit:run: unit tests exploded'
	selftest_assert_contains "$grouped_with_check_fails" $'2\tcheck-fail\t/legacy-project\tlint\tlint exploded'

	home_dir="$SELFTEST_ROOT/home"
	dev_root="$SELFTEST_ROOT/dev"
	fallback_log="$dev_root/project/.agent/logs/friction.log"
	canonical_log="$home_dir/.claude/logs/friction.log"
	mkdir -p "$(dirname "$fallback_log")" "$(dirname "$canonical_log")"
	printf '2026-05-15T19:00:00Z\trule-ignored\t/project-a\tskipped review gate\n' > "$fallback_log"
	printf '2026-05-15T19:01:00Z\trule-ignored\t/project-a\tskipped review gate\n' >> "$fallback_log"
	printf '2026-05-15T19:02:00Z\tmissing-guidance\t/project-b\tcentral log was sandboxed\n' >> "$fallback_log"
	printf 'RESOLVED\trule-ignored\tskipped review gate\tself-test resolution\n' > "$canonical_log"
	printf '2026-06-01T09:00:00Z\trule-ignored\t/project-a\tskipped review gate\n' >> "$canonical_log"

	discovered_output=$(HOME="$home_dir" FRICTION_DEV_ROOT="$dev_root" bash "$script_path")
	selftest_assert_not_contains "$discovered_output" $'2\trule-ignored\t/project-a\tskipped review gate'
	selftest_assert_contains "$discovered_output" $'1\trule-ignored\t/project-a\tskipped review gate'
	selftest_assert_contains "$discovered_output" $'1\tmissing-guidance\t/project-b\tcentral log was sandboxed'

	printf 'analyse-friction.sh --selftest passed\n'
}

if [[ "${1:-}" == "--selftest" ]]; then
	run_selftest
	exit 0
fi

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
