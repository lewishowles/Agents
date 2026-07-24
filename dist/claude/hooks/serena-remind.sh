#!/usr/bin/env bash
# Wrapper for serena-hooks remind — nudges the agent to prefer Serena's
# symbolic tools over consecutive grep/read_file calls.
set -euo pipefail

# This repo's hook/skill directories are pairs of small config/shell files
# (hook.json + .sh, skill.json + SKILL.body.md) with little symbolic content;
# Serena's symbolic tools add no value there, so the reminder doesn't apply.
if [[ "$PWD" == "$HOME/Dev/Configuration/Agents"* ]]; then
	exit 0
fi

set +e
output="$(serena-hooks remind --client=claude-code)"
status="$?"
set -e

if [[ "$output" == *"Too many consecutive"* ]]; then
	printf 'Serena reminder: too many consecutive source-inspection calls without symbolic tools. Next action should be a Serena symbolic lookup, diagnostics, or a single targeted read with a stated reason.\n' >&2
	exit 0
fi

if [[ -n "$output" ]]; then
	printf '%s\n' "$output"
fi

exit "$status"
