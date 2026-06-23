#!/usr/bin/env bash
# Start the Local Repo Gateway MCP server (stdio, foreground).
# Stop with Ctrl+C.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SERVER_DIR="$REPO_DIR/servers/local-repo-gateway"
CONFIG="$SERVER_DIR/repos.json"

# Require repos.json — copy from repos.example.json and add your repo paths.
if [ ! -f "$CONFIG" ]; then
	printf 'repos.json not found. Copy and edit the example:\n'
	printf '  cp %s/repos.example.json %s/repos.json\n' "$SERVER_DIR" "$SERVER_DIR"
	exit 1
fi

VENV="$SERVER_DIR/.venv"

# Create the virtual environment on first run. Uses Python 3.12 via uv.
if [ ! -d "$VENV" ]; then
	printf 'Creating virtual environment...\n'
	uv venv "$VENV" --python 3.12 --quiet
fi

# Sync dependencies into the venv. No-op when already up to date.
uv pip install --quiet -r "$SERVER_DIR/requirements.txt" --python "$VENV/bin/python"

# Hand off to the server process. stdio transport stays attached to this terminal.
exec "$VENV/bin/python" "$SERVER_DIR/server.py"
