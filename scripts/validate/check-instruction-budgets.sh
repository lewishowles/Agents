#!/usr/bin/env bash
# Warns when generated instruction artefacts grow beyond checked-in byte baselines.

set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib/validate.sh"

validate_require_jq

TARGET_REPO_DIR="${INSTRUCTION_BUDGET_REPO_DIR:-$REPO_DIR}"
BASELINE_FILE="${INSTRUCTION_BUDGET_BASELINE:-$REPO_DIR/scripts/validate/instruction-budgets.json}"
CLASSES=(always_loaded skill_bodies eager_metadata)

# Returns the source path associated with a measured artefact.
#
# @param  {string}  class
#     Baseline class containing the artefact.
# @param  {string}  relative_file
#     Artefact path relative to the repository root.
source_hint() {
	local class="$1"
	local relative_file="$2"
	local skill_name manifest manifest_name

	case "$class" in
		always_loaded)
			case "$relative_file" in
				dist/codex/AGENTS.md) printf '%s' 'dist/codex/source or rules/ inputs' ;;
				dist/claude/CLAUDE.md) printf '%s' 'dist/claude/source or rules/ inputs' ;;
				*) printf '%s' 'the generated instruction source inputs' ;;
			esac
			;;
		skill_bodies)
			skill_name="${relative_file#dist/skills/}"
			skill_name="${skill_name%%/*}"
			if [ "$skill_name" = "global-rules" ]; then
				printf '%s' 'rules/global-rules.md, rules/identity.md, rules/skills-policy.md, and rules/file-discovery.md'
				return
			fi

			while IFS= read -r -d '' manifest; do
				manifest_name=$(jq -r '.name // empty' "$manifest")
				if [ "$manifest_name" = "$skill_name" ]; then
					printf '%s/SKILL.body.md' "${manifest%/skill.json}"
					return
				fi
			done < <(find "$TARGET_REPO_DIR/skills" -name "skill.json" -type f -print0 | sort -z)

			printf 'skills/%s/SKILL.body.md' "$skill_name"
			;;
		eager_metadata)
			printf '%s' "$relative_file"
			;;
		*)
			printf '%s' 'the corresponding repository source file'
			;;
	esac
}

# Reports growth for one artefact without failing validation.
#
# @param  {string}  class
#     Baseline class containing the artefact.
# @param  {string}  relative_file
#     Artefact path relative to the repository root.
# @param  {string}  current_bytes
#     Current UTF-8 byte count.
# @param  {string}  baseline_bytes
#     Checked-in baseline byte count.
report_growth() {
	local class="$1"
	local relative_file="$2"
	local current_bytes="$3"
	local baseline_bytes="$4"

	cli_style_row \
		'⚠' \
		"$relative_file: current $current_bytes bytes exceeds baseline $baseline_bytes bytes" \
		--label-colour warning \
		--label-width 1 >&2
	cli_style_row \
		'↳ edit:' \
		"$(source_hint "$class" "$relative_file")" \
		--label-colour muted \
		--value-colour muted \
		--label-width 6 >&2
}

if [ ! -f "$BASELINE_FILE" ]; then
	validate_fail "Instruction budget baseline missing: $BASELINE_FILE"
	validate_finish
fi

if ! jq empty "$BASELINE_FILE" >/dev/null 2>&1; then
	validate_fail "Instruction budget baseline contains invalid JSON: $BASELINE_FILE"
	validate_finish
fi

for class in "${CLASSES[@]}"; do
	if ! jq -e --arg class "$class" '(.[$class] | type) == "object"' "$BASELINE_FILE" >/dev/null 2>&1; then
		validate_fail "Instruction budget baseline missing top-level class '$class': $BASELINE_FILE"
	fi
done

validate_finish

for class in "${CLASSES[@]}"; do
	while IFS= read -r relative_file; do
		baseline_bytes=$(jq -r --arg class "$class" --arg relative_file "$relative_file" '.[$class][$relative_file]' "$BASELINE_FILE")
		case "$baseline_bytes" in
			''|*[!0-9]*)
				validate_fail "Instruction budget baseline value for $class/$relative_file is not a non-negative integer"
				continue
				;;
		esac

		artefact="$TARGET_REPO_DIR/$relative_file"
		if [ ! -f "$artefact" ]; then
			validate_fail "Instruction budget artefact missing: $relative_file"
			continue
		fi

		current_bytes=$(wc -c < "$artefact" | tr -d '[:space:]')
		if [ "$current_bytes" -gt "$baseline_bytes" ]; then
			report_growth "$class" "$relative_file" "$current_bytes" "$baseline_bytes"
		fi
	done < <(jq -r --arg class "$class" '.[$class] | keys[]' "$BASELINE_FILE")
done

validate_finish
