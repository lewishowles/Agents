#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
FIXTURE_DIR="$SCRIPT_DIR/fixtures"

pass=0
fail=0

command -v jq &>/dev/null || { printf 'skill-triggers tests require jq\n' >&2; exit 1; }

run_fixture() {
	local hook_script="$1"
	local fixture_dir="$2"
	local case_name="$3"

	local input="$fixture_dir/input.json"
	local expected_file="$fixture_dir/expected-skills.txt"
	local output

	output=$(bash "$hook_script" < "$input" 2>/dev/null || true)

	local expected_skills=()
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -n "${line// }" ]] && expected_skills+=("$line")
	done < "$expected_file"

	if [[ ${#expected_skills[@]} -eq 0 ]]; then
		if [[ -z "$output" ]]; then
			printf '  ✓ %s\n' "$case_name"
			pass=$((pass + 1))
		else
			printf '  ✗ %s: expected no output\n' "$case_name" >&2
			fail=$((fail + 1))
		fi
		return
	fi

	if [[ -z "$output" ]]; then
		printf '  ✗ %s: expected skills [%s] but got no output\n' \
			"$case_name" "${expected_skills[*]}" >&2
		fail=$((fail + 1))
		return
	fi

	local context
	context=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)

	local case_pass=true
	for skill in "${expected_skills[@]}"; do
		if ! printf '%s' "$context" | grep -qE "(^|[[:space:]])${skill}([[:space:]]|\.)"; then
			printf '  ✗ %s: skill "%s" not found in output\n' "$case_name" "$skill" >&2
			case_pass=false
		fi
	done

	if [[ "$case_pass" == true ]]; then
		printf '  ✓ %s\n' "$case_name"
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
	fi
}

run_suite() {
	local suite_name="$1"
	local hook_script="$2"
	local fixture_subdir="$3"

	printf '%s:\n' "$suite_name"

	for fixture_dir in "$FIXTURE_DIR/$fixture_subdir/"/*/; do
		[[ -d "$fixture_dir" ]] || continue
		run_fixture "$hook_script" "$fixture_dir" "$(basename "$fixture_dir")"
	done
}

run_suite "skill-file-trigger" \
	"$REPO_DIR/dist/claude/hooks/skill-file-trigger.sh" \
	"skill-file-trigger"

run_suite "skill-autotrigger" \
	"$REPO_DIR/dist/claude/hooks/skill-autotrigger.sh" \
	"skill-autotrigger"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
