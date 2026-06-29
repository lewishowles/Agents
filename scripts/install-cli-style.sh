#!/usr/bin/env bash
# Installs cli-style into this repository's agent tools directory.

set -euo pipefail

VERSION="0.2.0"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
INSTALL_DIR="$REPO_DIR/.agent/tools/cli-style"

platform=$(uname -s | tr '[:upper:]' '[:lower:]')
architecture=$(uname -m)

case "$architecture" in
	arm64|aarch64) architecture="arm64" ;;
	x86_64|amd64) architecture="x64" ;;
esac

archive="cli-style-$platform-$architecture.tar.gz"
url="https://github.com/lewishowles/cli-style/releases/download/v$VERSION/$archive"

mkdir -p "$INSTALL_DIR"
curl -fsSL "$url" | tar -xz -C "$INSTALL_DIR"
printf '%s\n' "$VERSION" > "$INSTALL_DIR/VERSION"

"$INSTALL_DIR/bin/cli-style" render status --plain <<'JSON'
{"type":"success","label":"cli-style installed"}
JSON
