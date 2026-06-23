#!/usr/bin/env bash
# Interactive first-time setup for Local Repo Gateway.
# Creates the Cloudflare tunnel, generates an auth token, writes all config,
# installs LaunchAgents, and prints the ChatGPT Custom GPT instructions.
#
# Re-running is safe: existing tunnels and tokens are detected and preserved.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SERVER_DIR="$REPO_DIR/servers/local-repo-gateway"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

source "$REPO_DIR/scripts/lib/colours.sh"

ok()      { printf '%s✓%s %s\n' "$GREEN"  "$RESET_COLOUR" "$1"; }
info()    { printf '%s→%s %s\n' "$PURPLE" "$RESET_COLOUR" "$1"; }
warn()    { printf '%s!%s %s\n' "$YELLOW" "$RESET_COLOUR" "$1"; }
fail()    { printf '%s✗%s %s\n' "$RED"    "$RESET_COLOUR" "$1"; exit 1; }
ask()     { printf '%s?%s %s: '  "$PURPLE" "$RESET_COLOUR" "$1"; }
divider() { printf '\n%s\n\n' "────────────────────────────────────────"; }

# ── Prerequisites ──────────────────────────────────────────────────────────────

divider
info "Checking prerequisites..."

command -v cloudflared >/dev/null 2>&1 || fail "cloudflared not found. Install with: brew install cloudflare/cloudflare/cloudflared"
ok "cloudflared found"

command -v uv >/dev/null 2>&1 || fail "uv not found. Install with: brew install uv"
ok "uv found"

command -v rg >/dev/null 2>&1 || warn "ripgrep (rg) not found — local_repo_search will not work"

# ── repos.json ─────────────────────────────────────────────────────────────────

if [ ! -f "$SERVER_DIR/repos.json" ]; then
	warn "repos.json not found."
	ask "Copy from example and continue? [y/N]"
	read -r REPLY
	[[ "$REPLY" =~ ^[Yy]$ ]] || fail "Create repos.json before running setup."
	cp "$SERVER_DIR/repos.example.json" "$SERVER_DIR/repos.json"
	ok "copied repos.example.json → repos.json (edit it to add your repos)"
fi
ok "repos.json found"

# ── Cloudflare tunnel ──────────────────────────────────────────────────────────

divider
info "Cloudflare tunnel setup..."

# Check if already authenticated.
if ! cloudflared tunnel list >/dev/null 2>&1; then
	info "Authenticating with Cloudflare (opens browser)..."
	cloudflared login
fi

ask "Your Cloudflare-managed domain (e.g. example.com)"
read -r CF_DOMAIN
CF_DOMAIN="${CF_DOMAIN// /}"
[ -n "$CF_DOMAIN" ] || fail "Domain cannot be empty."

ask "Hostname prefix [local-repo-gateway]"
read -r CF_PREFIX
CF_PREFIX="${CF_PREFIX:-local-repo-gateway}"
CF_HOSTNAME="${CF_PREFIX}.${CF_DOMAIN}"

# Create tunnel if it doesn't already exist.
if cloudflared tunnel list 2>/dev/null | grep -q "$CF_PREFIX"; then
	TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | grep "$CF_PREFIX" | awk '{print $1}')
	ok "tunnel '$CF_PREFIX' already exists (id: $TUNNEL_ID)"
else
	info "Creating tunnel '$CF_PREFIX'..."
	TUNNEL_OUTPUT=$(cloudflared tunnel create "$CF_PREFIX" 2>&1)
	TUNNEL_ID=$(echo "$TUNNEL_OUTPUT" | grep -o 'id [a-f0-9-]*' | awk '{print $2}')
	ok "created tunnel (id: $TUNNEL_ID)"

	info "Routing DNS: $CF_HOSTNAME → tunnel..."
	cloudflared tunnel route dns --overwrite-dns "$TUNNEL_ID" "$CF_HOSTNAME"
	ok "DNS route created"
fi

CREDENTIALS_FILE="$HOME/.cloudflared/${TUNNEL_ID}.json"

# Write cloudflared config.
mkdir -p "$SERVER_DIR/cloudflared"
cat > "$SERVER_DIR/cloudflared/config.yml" << YAML
tunnel: $TUNNEL_ID
credentials-file: $CREDENTIALS_FILE

ingress:
  - hostname: $CF_HOSTNAME
    service: http://127.0.0.1:8754
  - service: http_status:404
YAML
ok "wrote cloudflared/config.yml"

# Update openapi.json server URL.
"$SERVER_DIR/.venv/bin/python" - << PYEOF
import json
from pathlib import Path

schema_path = Path("$SERVER_DIR/openapi.json")
if schema_path.exists():
    schema = json.loads(schema_path.read_text())
    schema["servers"] = [{"url": "https://$CF_HOSTNAME"}]
    schema_path.write_text(json.dumps(schema, indent=2))
PYEOF
ok "updated openapi.json server URL → https://$CF_HOSTNAME"

# ── Auth token ─────────────────────────────────────────────────────────────────

divider
info "Auth token..."

if [ -n "${GATEWAY_TOKEN:-}" ]; then
	ok "GATEWAY_TOKEN already set in environment — keeping it"
	TOKEN="$GATEWAY_TOKEN"
else
	TOKEN=$(openssl rand -hex 32)
	printf '\n'
	printf 'Add this to your shell profile (~/.zshrc or ~/.zprofile):\n\n'
	printf '  %sexport GATEWAY_TOKEN="%s"%s\n\n' "$GREEN" "$TOKEN" "$RESET_COLOUR"
	printf 'Then press Enter to continue (the install will read it from your profile).'
	read -r _
	export GATEWAY_TOKEN="$TOKEN"
fi

# ── venv + dependencies ────────────────────────────────────────────────────────

divider
info "Setting up Python environment..."

VENV="$SERVER_DIR/.venv"
if [ ! -d "$VENV" ]; then
	uv venv "$VENV" --python 3.12 --quiet
fi
uv pip install --quiet -r "$SERVER_DIR/requirements.txt" --python "$VENV/bin/python"
ok "venv ready"

# ── LaunchAgents ───────────────────────────────────────────────────────────────

divider
info "Installing LaunchAgents..."

HTTP_PLIST="$LAUNCH_AGENTS/com.lewis.local-repo-gateway-http.plist"
TUNNEL_PLIST="$LAUNCH_AGENTS/com.lewis.local-repo-gateway-tunnel.plist"

cat > "$HTTP_PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lewis.local-repo-gateway-http</string>
    <key>ProgramArguments</key>
    <array>
        <string>$VENV/bin/python</string>
        <string>$SERVER_DIR/http_server.py</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>GATEWAY_TOKEN</key>
        <string>$TOKEN</string>
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
        <string>$SERVER_DIR/cloudflared/config.yml</string>
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

for label in com.lewis.local-repo-gateway-http com.lewis.local-repo-gateway-tunnel; do
	launchctl unload "$LAUNCH_AGENTS/$label.plist" 2>/dev/null || true
	launchctl load "$LAUNCH_AGENTS/$label.plist"
	ok "loaded $label"
done

# ── Done ───────────────────────────────────────────────────────────────────────

divider
printf '%sSetup complete.%s\n\n' "$GREEN" "$RESET_COLOUR"
printf 'Gateway URL:  https://%s\n' "$CF_HOSTNAME"
printf 'Health check: curl -s -H "X-Gateway-Token: %s" https://%s/health\n\n' "$TOKEN" "$CF_HOSTNAME"
printf '%sChatGPT Custom GPT setup:%s\n' "$PURPLE" "$RESET_COLOUR"
printf '  1. ChatGPT → Explore GPTs → Create → Configure → Actions → Create new action\n'
printf '  2. Paste the contents of servers/local-repo-gateway/openapi.json into the schema editor\n'
printf '  3. Authentication: API Key → header name X-Gateway-Token → token: %s\n' "$TOKEN"
printf '  4. Paste the following into the Instructions field:\n\n'
cat << 'INSTRUCTIONS'
You are Local Repo Gateway, a read-only assistant for inspecting local software repositories.

When asked to look at a repo, plan work, or review changes:
1. Call local_repo_list to show available repositories and let the user choose one.
2. Call local_repo_get_instructions to read the project's AGENTS.md, capabilities, and current PROGRESS.md handoff.
3. Use local_repo_tree, local_repo_search, and local_repo_read_file only for targeted lookups — do not read files speculatively.
4. For review tasks, call local_repo_git_status and local_repo_git_diff to see uncommitted changes.

Always work from the project's own AGENTS.md and PROGRESS.md before offering opinions or plans. Respect the project's conventions, commit style, and scope rules as described in those files.

You are read-only. You cannot write files, create commits, or push changes. When suggesting changes, describe them clearly so the user can implement them in their editor or via Claude Code or Codex.
INSTRUCTIONS
printf '\n  5. Save and test: "List my local repos"\n'
