#!/usr/bin/env bash
# Start the Cloudflare tunnel for Local Repo Gateway (foreground).
# Exposes http://127.0.0.1:8754 as https://local-repo-gateway.howles.dev.
# Stop with Ctrl+C.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
CONFIG="$REPO_DIR/servers/local-repo-gateway/cloudflared/config.yml"

if [ ! -f "$CONFIG" ]; then
	printf 'Tunnel config not found at %s\n' "$CONFIG"
	exit 1
fi

exec cloudflared tunnel --config "$CONFIG" run
