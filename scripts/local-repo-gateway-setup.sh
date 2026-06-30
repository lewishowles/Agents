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

source "$REPO_DIR/scripts/lib/cli-style-output.sh"

# Prints a prompt and leaves the cursor on the same line for user input.
#
# @param  {string}  prompt
#     Prompt text.
ask() {
	local prompt="$1"

	printf '? %s: ' "$prompt"
}

# Prints a failed status and exits.
#
# @param  {string}  label
#     Failure label.
# @param  {string}  detail
#     Supporting failure detail.
fail() {
	local label="$1"
	local detail="${2:-}"

	cli_status failed "$label" "$detail"
	exit 1
}

printf '\n'
cli_status info "Checking prerequisites"

command -v cloudflared >/dev/null 2>&1 || fail "cloudflared not found" "Install with: brew install cloudflare/cloudflare/cloudflared"
cli_group success "Cloudflare dependency" "cloudflared found"

command -v uv >/dev/null 2>&1 || fail "uv not found" "Install with: brew install uv"
cli_group success "Python dependency" "uv found"

if command -v rg >/dev/null 2>&1; then
	cli_group success "Search dependency" "ripgrep (rg) available"
else
	cli_group warning "Search dependency" "ripgrep (rg) not found — local_repo_search will not work"
fi

if [[ ! -f "$SERVER_DIR/repos.json" ]]; then
	cli_group warning "Repository config" "repos.json not found"
	ask "Copy from example and continue? [y/N]"
	read -r REPLY
	[[ "$REPLY" =~ ^[Yy]$ ]] || fail "Create repos.json before running setup"
	cp "$SERVER_DIR/repos.example.json" "$SERVER_DIR/repos.json"
	cli_group success "Repository config" "copied repos.example.json → repos.json"
else
	cli_group success "Repository config" "repos.json found"
fi

printf '\n'
cli_status info "Cloudflare tunnel setup"

# Check if already authenticated.
if ! cloudflared tunnel list >/dev/null 2>&1; then
	cli_status info "Authenticating with Cloudflare" "opens browser"
	cloudflared login
fi

ask "Your Cloudflare-managed domain (e.g. example.com)"
read -r CF_DOMAIN
CF_DOMAIN="${CF_DOMAIN// /}"
[[ -n "$CF_DOMAIN" ]] || fail "Domain cannot be empty"

ask "Hostname prefix [local-repo-gateway]"
read -r CF_PREFIX
CF_PREFIX="${CF_PREFIX:-local-repo-gateway}"
CF_HOSTNAME="${CF_PREFIX}.${CF_DOMAIN}"

# Create tunnel if it doesn't already exist.
if cloudflared tunnel list 2>/dev/null | grep -q "$CF_PREFIX"; then
	TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | grep "$CF_PREFIX" | awk '{print $1}')
	cli_group unchanged "Cloudflare tunnel" "'$CF_PREFIX' already exists (id: $TUNNEL_ID)"
else
	cli_status info "Creating tunnel" "$CF_PREFIX"
	TUNNEL_OUTPUT=$(cloudflared tunnel create "$CF_PREFIX" 2>&1)
	TUNNEL_ID=$(echo "$TUNNEL_OUTPUT" | grep -o 'id [a-f0-9-]*' | awk '{print $2}')
	cli_group success "Cloudflare tunnel" "created tunnel (id: $TUNNEL_ID)"

	cli_status info "Routing DNS" "$CF_HOSTNAME → tunnel"
	cloudflared tunnel route dns --overwrite-dns "$TUNNEL_ID" "$CF_HOSTNAME"
	cli_group success "Cloudflare DNS" "route created"
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
cli_group success "Cloudflare config" "wrote cloudflared/config.yml"

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
cli_group success "OpenAPI schema" "server URL → https://$CF_HOSTNAME"

printf '\n'
cli_status info "Auth token"

if [[ -n "${GATEWAY_TOKEN:-}" ]]; then
	cli_group unchanged "Gateway token" "GATEWAY_TOKEN already set in environment"
	TOKEN="$GATEWAY_TOKEN"
else
	TOKEN=$(openssl rand -hex 32)
	printf '\n'
	printf 'Add this to your shell profile (~/.zshrc or ~/.zprofile):\n\n'
	printf '  export GATEWAY_TOKEN="%s"\n\n' "$TOKEN"
	printf 'Then press Enter to continue (the install will read it from your profile).'
	read -r _
	export GATEWAY_TOKEN="$TOKEN"
fi

printf '\n'
cli_status info "Setting up Python environment"

VENV="$SERVER_DIR/.venv"
if [[ ! -d "$VENV" ]]; then
	uv venv "$VENV" --python 3.12 --quiet
fi
uv pip install --quiet -r "$SERVER_DIR/requirements.txt" --python "$VENV/bin/python"
cli_group success "Python environment" "venv ready"

printf '\n'
cli_status info "Installing LaunchAgents"

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
	cli_status success "loaded" "$label"
done

printf '\n'
cli_status success "Setup complete"
cli_group success "Gateway" "https://$CF_HOSTNAME"
cli_group info "Health check" "curl -s -H \"X-Gateway-Token: $TOKEN\" https://$CF_HOSTNAME/health"
printf '\n'
cli_status info "ChatGPT Custom GPT setup"
printf '  1. ChatGPT → Explore GPTs → Create → Configure → Actions → Create new action\n'
printf '  2. Paste the contents of servers/local-repo-gateway/openapi.json into the schema editor\n'
printf '  3. Authentication: API Key → header name X-Gateway-Token → token: %s\n' "$TOKEN"
printf '  4. Paste the following into the Instructions field:\n\n'
cat << 'INSTRUCTIONS'
You are Local Repo Gateway, a read-only assistant for inspecting local software repositories and applying the owner's coding skills and conventions.

## Skills

At the start of each conversation, call list_skills to load the full skill portfolio. Each skill has a description and a list of triggers. Use these to decide which skills apply to the current task — match against the task type, file types, and keywords mentioned. Do not guess at skill names or invent skills that are not in the list.

When a skill is relevant, fetch its full content with read_skill and apply its guidance before offering plans, suggestions, or writing anything.

## Working on a repo

1. Call list_repos to show available repositories and let the user choose one.
2. Call get_instructions to read the project's AGENTS.md, capabilities, and current PROGRESS.md handoff.
3. Apply any skills that match the current task based on the skill descriptions and triggers.
4. Use tree, search, and read_file only for targeted lookups — do not read files speculatively.
5. For review tasks, call git_status and git_diff to see uncommitted changes.

## Always

Work from the project's own AGENTS.md and PROGRESS.md before offering opinions or plans. Respect the project's conventions, commit style, and scope rules as described in those files.

You are read-only. You cannot write files, create commits, or push changes. When suggesting changes, describe them precisely so the user can apply them via their editor, Claude Code, or Codex.
INSTRUCTIONS
printf '\n  5. Save and test: "List my local repos"\n'
