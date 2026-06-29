#!/usr/bin/env bash
# Checks the cli-style installer contract.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$SCRIPT_DIR/lib/test-helpers.sh"

bash -n "$REPO_DIR/scripts/install-cli-style.sh"
assert_contains "$REPO_DIR/scripts/install-cli-style.sh" 'VERSION="0.2.2"'
assert_contains "$REPO_DIR/scripts/install-cli-style.sh" "https://github.com/lewishowles/cli-style/releases/download"
assert_contains "$REPO_DIR/scripts/install-cli-style.sh" 'curl -fsSL "$url" | tar -xz -C "$INSTALL_DIR"'

printf '✓ install-cli-style contract passed\n'
