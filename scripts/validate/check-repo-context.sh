#!/usr/bin/env bash
# Runs repo context tests with compact output.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

source "$REPO_DIR/scripts/lib/validate.sh"

validate_section 'Checking repo context...'

if bash "$REPO_DIR/tests/repo-context.sh" 2>&1 | tail -20; then
	printf '%s✓%s Repo context passed\n' "$GREEN" "$RESET_COLOUR"
else
	validate_fail "Repo context failed"
fi
