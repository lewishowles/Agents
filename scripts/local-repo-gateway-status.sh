#!/usr/bin/env bash
# Report Local Repo Gateway status: config validity and dependency availability.
# Exits 1 if anything is missing; exits 0 when ready to start.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SERVER_DIR="$REPO_DIR/servers/local-repo-gateway"
CONFIG="$SERVER_DIR/repos.json"

source "$REPO_DIR/scripts/lib/cli-style-output.sh"

issues=0

# repos.json must exist and be parseable before the server can start.
if [[ -f "$CONFIG" ]]; then
	cli_status success "repos.json found"
	repo_count=$(python3 -c "import json; d=json.load(open('$CONFIG')); print(len(d.get('repos', [])))" 2>/dev/null || echo "?")
	cli_group success "Repository config" "$repo_count repo(s) configured"
else
	cli_group failed "Repository config" "repos.json missing — copy repos.example.json and edit it"
	issues=$((issues + 1))
fi

# The venv is created automatically by local-repo-gateway-mcp.sh on first run.
VENV="$SERVER_DIR/.venv"
if [[ -d "$VENV" ]] && "$VENV/bin/python" -c "import mcp" 2>/dev/null; then
	cli_group success "Python environment" "venv and mcp package available"
else
	cli_group warning "Python environment" "venv or mcp missing — run: bash scripts/local-repo-gateway-mcp.sh"
	issues=$((issues + 1))
fi

# rg is used by local_repo_search; the other tools do not need it.
if command -v rg >/dev/null 2>&1; then
	cli_group success "Search dependency" "ripgrep (rg) available"
else
	cli_group warning "Search dependency" "ripgrep not found — local_repo_search will fail"
	issues=$((issues + 1))
fi

printf '\n'
if [[ "$issues" -eq 0 ]]; then
	cli_status success "Ready" "Start with: bash scripts/local-repo-gateway-mcp.sh"
else
	cli_status failed "Not ready" "$issues issue(s) to resolve before starting"
	exit 1
fi
