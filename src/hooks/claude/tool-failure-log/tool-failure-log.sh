#!/usr/bin/env bash
# PostToolUseFailure hook: passes its stdin (the failure payload) to
# `friction hook claude-tool-failure`, which records the tool error for later
# friction review. Skips silently when friction is missing, and ignores a
# failed recording so a logging problem never blocks Claude.

set -euo pipefail

if ! command -v friction >/dev/null 2>&1; then
	exit 0
fi

friction hook claude-tool-failure >/dev/null 2>&1 || true
