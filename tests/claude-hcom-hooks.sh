#!/usr/bin/env bash
# Checks that generated Claude settings retain the supported HCOM event set.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$SCRIPT_DIR/lib/test-helpers.sh"

manifest="$REPO_DIR/src/hooks/claude/hcom/hook.json"
settings="$REPO_DIR/dist/claude/settings.json"
expected=$(jq -c . <<'JSON'
[
	{"event":"Notification","matcher":"","command":"cmd=${HCOM:-hcom}; command -v \"${cmd%% *}\" >/dev/null 2>&1 && exec $cmd notify || exit 0","timeout":null},
	{"event":"PermissionRequest","matcher":"","command":"cmd=${HCOM:-hcom}; command -v \"${cmd%% *}\" >/dev/null 2>&1 && exec $cmd permission-request || exit 0","timeout":null},
	{"event":"PostToolUse","matcher":"","command":"cmd=${HCOM:-hcom}; command -v \"${cmd%% *}\" >/dev/null 2>&1 && exec $cmd post || exit 0","timeout":86400},
	{"event":"PreToolUse","matcher":"Bash|Task|Write|Edit","command":"cmd=${HCOM:-hcom}; command -v \"${cmd%% *}\" >/dev/null 2>&1 && exec $cmd pre || exit 0","timeout":null},
	{"event":"SessionEnd","matcher":"","command":"cmd=${HCOM:-hcom}; command -v \"${cmd%% *}\" >/dev/null 2>&1 && exec $cmd sessionend || exit 0","timeout":null},
	{"event":"SessionStart","matcher":"","command":"cmd=${HCOM:-hcom}; command -v \"${cmd%% *}\" >/dev/null 2>&1 && exec $cmd sessionstart || exit 0","timeout":null},
	{"event":"Stop","matcher":"","command":"cmd=${HCOM:-hcom}; command -v \"${cmd%% *}\" >/dev/null 2>&1 && exec $cmd poll || exit 0","timeout":86400},
	{"event":"SubagentStart","matcher":"","command":"cmd=${HCOM:-hcom}; command -v \"${cmd%% *}\" >/dev/null 2>&1 && exec $cmd subagent-start || exit 0","timeout":null},
	{"event":"SubagentStop","matcher":"","command":"cmd=${HCOM:-hcom}; command -v \"${cmd%% *}\" >/dev/null 2>&1 && exec $cmd subagent-stop || exit 0","timeout":86400},
	{"event":"UserPromptSubmit","matcher":"","command":"cmd=${HCOM:-hcom}; command -v \"${cmd%% *}\" >/dev/null 2>&1 && exec $cmd userpromptsubmit || exit 0","timeout":null}
]
JSON
)

assert_file "$manifest"
assert_file "$settings"

source_events=$(jq -c '[.events[] | {event, matcher: (.matcher // ""), command, timeout: (.timeout // null)}] | sort_by(.event, .matcher)' "$manifest")
generated_events=$(jq -c '[.hooks | to_entries[] | .key as $event | .value[] | (.matcher // "") as $matcher | .hooks[] | select(.command | contains("HCOM:-hcom")) | {event: $event, matcher: $matcher, command, timeout: (.timeout // null)}] | sort_by(.event, .matcher)' "$settings")

assert_equals "$source_events" "$expected"
assert_equals "$generated_events" "$expected"

printf '✓ Claude HCOM hook tests passed\n'
