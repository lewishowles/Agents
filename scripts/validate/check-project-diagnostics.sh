#!/usr/bin/env bash
# Runs project diagnostics tests with compact output.

set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib/validate.sh"

validate_section 'Checking project diagnostics...'

if bash "$REPO_DIR/tests/project-diagnostics.sh" 2>&1 | tail -20; then
	printf '%s✓%s Project diagnostics passed\n' "$GREEN" "$RESET_COLOUR"
else
	validate_fail "Project diagnostics failed"
fi

validate_finish
