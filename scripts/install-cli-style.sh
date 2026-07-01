#!/usr/bin/env bash
# Installs cli-style into this repository's agent tools directory.

set -euo pipefail

VERSION="0.4.1"
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
temp_archive=$(mktemp)

trap 'rm -f "$temp_archive"' EXIT

mkdir -p "$INSTALL_DIR"
curl --connect-timeout 10 --max-time 600 --retry 2 -fsSL "$url" -o "$temp_archive"
tar -xzf "$temp_archive" -C "$INSTALL_DIR"
printf '%s\n' "$VERSION" > "$INSTALL_DIR/VERSION"

source "$REPO_DIR/scripts/lib/cli-style-output.sh"
cli_section "Installer" "Install local cli-style binary"
cli_status success "cli-style installed"
