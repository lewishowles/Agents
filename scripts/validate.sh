#!/usr/bin/env bash
# Runs all repository validation checks in a stable order.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$REPO_DIR/scripts/lib/colours.sh"

FAILED_CHECKS=0

# Runs a command as a named validation check.
# Prints a section header before running and ✓/✗ after.
#
# @param  {string}  label
#     Human-readable name displayed before and after the check runs.
# @param  {string}  ...
#     Command and arguments to execute.
run_check() {
	local label="$1"
	shift
	printf '\nChecking %s...\n' "$label"
	if "$@" 2>&1; then
		printf '%s✓%s %s\n' "$GREEN" "$RESET_COLOUR" "$label"
	else
		printf '%s✗%s %s failed\n' "$RED" "$RESET_COLOUR" "$label"
		FAILED_CHECKS=$((FAILED_CHECKS + 1))
	fi
}

run_check "skill manifests"       bash "$REPO_DIR/scripts/validate/check-skill-manifests.sh"
run_check "trigger fixture names" bash "$REPO_DIR/scripts/validate/check-trigger-fixture-names.sh"
run_check "hook manifests"        bash "$REPO_DIR/scripts/validate/check-hook-manifests.sh"
run_check "generated files"       bash "$REPO_DIR/scripts/validate/check-generated-files.sh"
run_check "hook sync"             bash "$REPO_DIR/scripts/validate/check-hook-sync.sh"
run_check "docs tables"           python3 "$REPO_DIR/scripts/build/build-docs.py" --check
run_check "skill triggers"        bash "$REPO_DIR/tests/skill-triggers.sh"
run_check "project diagnostics"   bash "$REPO_DIR/tests/project-diagnostics.sh"
run_check "repo context"          bash "$REPO_DIR/tests/repo-context.sh"
run_check "generated-file guard"  bash "$REPO_DIR/tests/generated-file-guard.sh"
run_check "change impact"         bash "$REPO_DIR/tests/change-impact.sh"
run_check "dead path refs"        python3 "$REPO_DIR/scripts/validate/markdown-claims.py" --mode paths
run_check "script command refs"   python3 "$REPO_DIR/scripts/validate/markdown-claims.py" --mode commands
run_check "setup drift"           python3 "$REPO_DIR/scripts/validate/check-setup-drift.py"
run_check "staleness"             python3 "$REPO_DIR/scripts/validate/check-staleness.py"

printf '\n'
if [ "$FAILED_CHECKS" -gt 0 ]; then
	printf '%s%d validation check(s) failed%s\n' "$RED" "$FAILED_CHECKS" "$RESET_COLOUR"
	exit 1
fi

printf '%s✓ All checks passed%s\n' "$GREEN" "$RESET_COLOUR"
