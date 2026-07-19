#!/usr/bin/env bash
# Runs all repository validation checks in a stable order.

set -euo pipefail

# macOS ships bash 3.2; several validators need bash 4+ (declare -A, mapfile).
# Re-exec under homebrew bash if the current interpreter is too old.
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
	export PATH="/opt/homebrew/bin:$PATH"
	if [ -x /opt/homebrew/bin/bash ]; then
		exec /opt/homebrew/bin/bash "$0" "$@"
	else
		exec "$(command -v bash)" "$0" "$@"
	fi
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$REPO_DIR/scripts/lib/colours.sh"
source "$REPO_DIR/scripts/lib/cli-style-output.sh"

FAILED_CHECKS=0

cli_section "Validation" "Run repository checks"

# Runs a command as a named validation check.
# Prints a section header before running and ✓/✗ after.
#
# @param  {string}  label
#     Human-readable name displayed before and after the check runs.
# @param  {string}  ...
#     Command and arguments to execute.
run_check() {
	local label="$1"
	local output
	shift
	cli_status info "Checking" "$label"
	if output=$("$@" 2>&1); then
		if { [ "$label" = "staleness" ] || [ "$label" = "instruction budgets" ]; } && [ -n "$output" ]; then
			printf '%s\n' "$output"
		fi
		cli_status success "$label"
	else
		if [ -n "$output" ]; then
			printf '%s\n' "$output" >&2
		fi
		cli_status error "$label" "failed"
		FAILED_CHECKS=$((FAILED_CHECKS + 1))
	fi
}

run_check "skill manifests"       bash "$REPO_DIR/scripts/validate/check-skill-manifests.sh"
run_check "instruction budgets"   bash "$REPO_DIR/scripts/validate/check-instruction-budgets.sh"
run_check "trigger overlap"       python3 "$REPO_DIR/scripts/validate/check-trigger-overlap.py"
run_check "trigger fixture names" bash "$REPO_DIR/scripts/validate/check-trigger-fixture-names.sh"
run_check "hook manifests"        bash "$REPO_DIR/scripts/validate/check-hook-manifests.sh"
run_check "generated files"       bash "$REPO_DIR/scripts/validate/check-generated-files.sh"
run_check "hook sync"             bash "$REPO_DIR/scripts/validate/check-hook-sync.sh"
run_check "dist sync"             bash "$REPO_DIR/scripts/validate/check-dist-sync.sh"
run_check "docs tables"           python3 "$REPO_DIR/scripts/build/build-docs.py" --check
run_check "cli-style installer"   bash "$REPO_DIR/tests/install-cli-style.sh"
run_check "skill triggers"        bash "$REPO_DIR/tests/skill-triggers.sh"
run_check "project diagnostics"   bash "$REPO_DIR/tests/project-diagnostics.sh"
run_check "workspace generator"   bash "$REPO_DIR/tests/init-workspace.sh"
run_check "project setup"         bash "$REPO_DIR/tests/setup-project.sh"
run_check "repo context"          bash "$REPO_DIR/tests/repo-context.sh"
run_check "generated-file guard"  bash "$REPO_DIR/tests/generated-file-guard.sh"
run_check "change impact"         bash "$REPO_DIR/tests/change-impact.sh"
run_check "friction logging"      bash "$REPO_DIR/tests/friction-logging.sh"
run_check "dead path refs"        python3 "$REPO_DIR/scripts/validate/markdown-claims.py" --mode paths
run_check "script command refs"   python3 "$REPO_DIR/scripts/validate/markdown-claims.py" --mode commands
run_check "setup drift"           python3 "$REPO_DIR/scripts/validate/check-setup-drift.py"
run_check "staleness"             python3 "$REPO_DIR/scripts/validate/check-staleness.py"

printf '\n'
if [ "$FAILED_CHECKS" -gt 0 ]; then
	cli_status error "$FAILED_CHECKS validation check(s) failed"
	exit 1
fi

cli_status success "All checks passed"
