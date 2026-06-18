#!/usr/bin/env bash
# Checks that required generated output files exist.

set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib/validate.sh"

validate_section 'Checking generated files...'

GENERATED_FILES=(
	"dist/claude/CLAUDE.md"
	"dist/claude/settings.json"
	"dist/claude/source/global-skills.md"
)

for file in "${GENERATED_FILES[@]}"; do
	if [ ! -f "$REPO_DIR/$file" ]; then
		validate_fail "Missing generated file: $file (run scripts/sync.sh)"
	fi
done

printf '%s✓%s Generated files present\n' "$GREEN" "$RESET_COLOUR"

validate_finish
