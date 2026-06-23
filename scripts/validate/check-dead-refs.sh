#!/usr/bin/env bash
# Checks that file paths referenced in agent-facing markdown actually exist on disk.

set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib/validate.sh"

validate_section 'Checking dead path references in agent markdown...'

if python3 "$REPO_DIR/scripts/markdown-claims.py" --mode paths; then
	printf '%s✓%s No dead path references found\n' "$GREEN" "$RESET_COLOUR"
else
	validate_fail "Dead path references found (run scripts/markdown-claims.py --mode paths for details)"
fi

validate_finish
