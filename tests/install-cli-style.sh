#!/usr/bin/env bash
# Checks the cli-style installer contract.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$SCRIPT_DIR/lib/test-helpers.sh"

bash -n "$REPO_DIR/scripts/install-cli-style.sh"
assert_contains "$REPO_DIR/scripts/install-cli-style.sh" 'VERSION="0.4.0"'
assert_contains "$REPO_DIR/scripts/install-cli-style.sh" "https://github.com/lewishowles/cli-style/releases/download"
assert_contains "$REPO_DIR/scripts/install-cli-style.sh" 'curl --connect-timeout 10 --max-time 600 --retry 2 -fsSL "$url" -o "$temp_archive"'
assert_contains "$REPO_DIR/scripts/install-cli-style.sh" 'tar -xzf "$temp_archive" -C "$INSTALL_DIR"'

printf '✓ install-cli-style contract passed\n'
