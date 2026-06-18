#!/usr/bin/env bash
# Runs change impact reporter tests with compact output.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

source "$REPO_DIR/scripts/lib/validate.sh"

validate_section 'Checking change impact reporter...'

if bash "$REPO_DIR/tests/change-impact.sh" 2>&1 | tail -20; then
	printf '%s✓%s Change impact reporter passed\n' "$GREEN" "$RESET_COLOUR"
else
	validate_fail "Change impact reporter failed"
fi
