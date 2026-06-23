#!/usr/bin/env bash
# Install Local Repo Gateway LaunchAgents (HTTP server + Cloudflare tunnel).
# Run once; re-run to update after changing GATEWAY_TOKEN or paths.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

source "$REPO_DIR/scripts/lib/colours.sh"

ok()   { printf '%s✓%s %s\n' "$GREEN"  "$RESET_COLOUR" "$1"; }
fail() { printf '%s✗%s %s\n' "$RED"    "$RESET_COLOUR" "$1"; FAILED=1; }

FAILED=0

# Require token before writing plists.
if [ -z "${GATEWAY_TOKEN:-}" ]; then
	fail "GATEWAY_TOKEN not set — source ~/.zshrc first, or run: export GATEWAY_TOKEN=<token>"
	exit 1
fi

HTTP_PLIST="$LAUNCH_AGENTS/com.lewis.local-repo-gateway-http.plist"
TUNNEL_PLIST="$LAUNCH_AGENTS/com.lewis.local-repo-gateway-tunnel.plist"

# Write HTTP server plist.
cat > "$HTTP_PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lewis.local-repo-gateway-http</string>
    <key>ProgramArguments</key>
    <array>
        <string>$REPO_DIR/servers/local-repo-gateway/.venv/bin/python</string>
        <string>$REPO_DIR/servers/local-repo-gateway/http_server.py</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>GATEWAY_TOKEN</key>
        <string>$GATEWAY_TOKEN</string>
        <key>GATEWAY_PORT</key>
        <string>8754</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/local-repo-gateway-http.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/local-repo-gateway-http.log</string>
</dict>
</plist>
PLIST
ok "wrote $HTTP_PLIST"

# Write tunnel plist.
cat > "$TUNNEL_PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lewis.local-repo-gateway-tunnel</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/cloudflared</string>
        <string>tunnel</string>
        <string>--config</string>
        <string>$REPO_DIR/servers/local-repo-gateway/cloudflared/config.yml</string>
        <string>run</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/local-repo-gateway-tunnel.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/local-repo-gateway-tunnel.log</string>
</dict>
</plist>
PLIST
ok "wrote $TUNNEL_PLIST"

# Unload existing agents if running, then load fresh.
for label in com.lewis.local-repo-gateway-http com.lewis.local-repo-gateway-tunnel; do
    launchctl unload "$LAUNCH_AGENTS/$label.plist" 2>/dev/null || true
    launchctl load "$LAUNCH_AGENTS/$label.plist"
    ok "loaded $label"
done

printf '\n'
printf 'Gateway running at https://local-repo-gateway.howles.dev\n'
printf 'Logs: tail -f /tmp/local-repo-gateway-http.log\n'
printf '      tail -f /tmp/local-repo-gateway-tunnel.log\n'
