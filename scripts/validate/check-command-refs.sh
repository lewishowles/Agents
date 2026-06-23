#!/usr/bin/env bash
# Checks that scripts and paths referenced in markdown exist and are executable.

set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib/validate.sh"

validate_section 'Checking script command references in markdown...'

if python3 "$REPO_DIR/scripts/markdown-claims.py" --mode commands; then
	printf '%s✓%s All script references are valid\n' "$GREEN" "$RESET_COLOUR"
else
	validate_fail "Invalid script references found (run scripts/markdown-claims.py --mode commands for details)"
fi

validate_finish
