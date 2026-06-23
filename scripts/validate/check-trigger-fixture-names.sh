#!/usr/bin/env bash
# Warns when trigger fixture skill-list files reference unknown skills.

set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib/validate.sh"

validate_require_jq

declare -A SKILL_NAMES
while IFS= read -r -d '' manifest; do
	name=$(jq -r '.name // empty' "$manifest")
	if [ -n "$name" ]; then
		SKILL_NAMES["$name"]=1
	fi
done < <(find "$REPO_DIR/skills" -name "skill.json" -print0 | sort -z)

# Returns 0 if the skill name is defined by a skill manifest.
#
# @param  {string}  skill
#     Skill name to check.
is_known_skill() {
	local skill="$1"

	[ -n "${SKILL_NAMES[$skill]+_}" ]
}

FIXTURE_SKILL_COUNT=0
UNRESOLVED_FIXTURE_SKILL_COUNT=0

while IFS= read -r -d '' fixture_file; do
	relative_file="${fixture_file#$REPO_DIR/}"

	while IFS= read -r skill || [ -n "$skill" ]; do
		if [ -z "${skill// }" ]; then
			continue
		fi

		FIXTURE_SKILL_COUNT=$((FIXTURE_SKILL_COUNT + 1))

		if ! is_known_skill "$skill"; then
			validate_warn "Unresolved fixture skill '$skill' in $relative_file"
			UNRESOLVED_FIXTURE_SKILL_COUNT=$((UNRESOLVED_FIXTURE_SKILL_COUNT + 1))
		fi
	done < "$fixture_file"
done < <(find "$REPO_DIR/tests/fixtures" \( -name "expected-skills.txt" -o -name "forbidden-skills.txt" \) -print0 | sort -z)

