#!/usr/bin/env bash
# Runs all repository validation checks in a stable order.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

CHECKS=(
	"scripts/validate/check-skill-manifests.sh"
	"scripts/validate/check-trigger-fixture-names.sh"
	"scripts/validate/check-hook-manifests.sh"
	"scripts/validate/check-generated-files.sh"
	"scripts/validate/check-hook-sync.sh"
	"scripts/validate/check-docs-tables.sh"
	"scripts/validate/check-skill-triggers.sh"
	"scripts/validate/check-project-diagnostics.sh"
)

FAILED_CHECKS=0

for check in "${CHECKS[@]}"; do
	if ! bash "$REPO_DIR/$check"; then
		FAILED_CHECKS=$((FAILED_CHECKS + 1))
	fi
done

printf '\n'
if [ "$FAILED_CHECKS" -gt 0 ]; then
	printf '%d validation check(s) failed\n' "$FAILED_CHECKS"
	exit 1
fi

source "$REPO_DIR/scripts/lib/colours.sh"
printf '%s✓ All checks passed%s\n' "$GREEN" "$RESET_COLOUR"
