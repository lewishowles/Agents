#!/usr/bin/env bash
# Start the Local Repo Gateway HTTP server (foreground).
# Requires GATEWAY_TOKEN to be set in the environment.
# Stop with Ctrl+C.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SERVER_DIR="$REPO_DIR/servers/local-repo-gateway"
VENV="$SERVER_DIR/.venv"

# Require repos.json before starting.
if [ ! -f "$SERVER_DIR/repos.json" ]; then
	printf 'repos.json not found. Copy and edit the example:\n'
	printf '  cp %s/repos.example.json %s/repos.json\n' "$SERVER_DIR" "$SERVER_DIR"
	exit 1
fi

# Require auth token — used by ChatGPT to authenticate each request.
if [ -z "${GATEWAY_TOKEN:-}" ]; then
	printf 'GATEWAY_TOKEN env var not set.\n'
	printf 'Generate one with: openssl rand -hex 32\n'
	exit 1
fi

# Create venv and sync deps if needed.
if [ ! -d "$VENV" ]; then
	printf 'Creating virtual environment...\n'
	uv venv "$VENV" --python 3.12 --quiet
fi
uv pip install --quiet -r "$SERVER_DIR/requirements.txt" --python "$VENV/bin/python"

PORT="${GATEWAY_PORT:-8754}"
printf 'Starting HTTP server on port %s...\n' "$PORT"

exec "$VENV/bin/python" "$SERVER_DIR/http_server.py"
