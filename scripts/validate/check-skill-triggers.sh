#!/usr/bin/env bash
# Runs skill trigger fixture tests with compact output.

set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib/validate.sh"

validate_section 'Checking skill trigger fixtures...'

if bash "$REPO_DIR/tests/skill-triggers.sh" 2>&1 | tail -20; then
	printf '%s✓%s Skill trigger fixtures passed\n' "$GREEN" "$RESET_COLOUR"
else
	validate_fail "Skill trigger fixtures failed"
fi

validate_finish
