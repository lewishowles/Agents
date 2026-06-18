#!/usr/bin/env bash
# Checks generated docs tables are in sync with source manifests.

set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib/validate.sh"

validate_section 'Checking generated docs tables...'

if python3 "$REPO_DIR/scripts/build-docs.py" --check; then
	printf '%s✓%s Generated docs tables in sync\n' "$GREEN" "$RESET_COLOUR"
else
	validate_fail "Generated docs tables out of sync (run scripts/sync.sh)"
fi

validate_finish
