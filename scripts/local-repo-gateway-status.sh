#!/usr/bin/env bash
# Report Local Repo Gateway status: config validity and dependency availability.
# Exits 1 if anything is missing; exits 0 when ready to start.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SERVER_DIR="$REPO_DIR/servers/local-repo-gateway"
CONFIG="$SERVER_DIR/repos.json"

source "$REPO_DIR/scripts/lib/colours.sh"

ok()   { printf '%s✓%s %s\n' "$GREEN"  "$RESET_COLOUR" "$1"; }
fail() { printf '%s✗%s %s\n' "$RED"    "$RESET_COLOUR" "$1"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET_COLOUR" "$1"; }

issues=0

# repos.json must exist and be parseable before the server can start.
if [ -f "$CONFIG" ]; then
	ok "repos.json found"
	repo_count=$(python3 -c "import json; d=json.load(open('$CONFIG')); print(len(d.get('repos', [])))" 2>/dev/null || echo "?")
	ok "$repo_count repo(s) configured"
else
	fail "repos.json missing — copy repos.example.json and edit it"
	issues=$((issues + 1))
fi

# The venv is created automatically by local-repo-gateway-mcp.sh on first run.
VENV="$SERVER_DIR/.venv"
if [ -d "$VENV" ] && "$VENV/bin/python" -c "import mcp" 2>/dev/null; then
	ok "venv and mcp package available"
else
	warn "venv or mcp missing — run: bash scripts/local-repo-gateway-mcp.sh (auto-installs)"
	issues=$((issues + 1))
fi

# rg is used by local_repo_search; the other tools do not need it.
if command -v rg >/dev/null 2>&1; then
	ok "ripgrep (rg) available"
else
	warn "ripgrep not found — local_repo_search will fail"
	issues=$((issues + 1))
fi

printf '\n'
if [ "$issues" -eq 0 ]; then
	printf 'Ready. Start with: bash scripts/local-repo-gateway-mcp.sh\n'
else
	printf '%d issue(s) to resolve before starting.\n' "$issues"
	exit 1
fi
