#!/usr/bin/env bash
# Wrapper for serena-hooks remind — nudges the agent to prefer Serena's
# symbolic tools over consecutive grep/read_file calls.
set -euo pipefail

set +e
output="$(serena-hooks remind --client=claude-code)"
status="$?"
set -e

if [[ "$status" -ne 0 && "$output" == *"Too many consecutive"* ]]; then
	printf 'Too many consecutive source-inspection calls without symbolic tools. Stop reading/searching. Next action must be a Serena symbolic lookup, diagnostics, or a single targeted read with a stated reason.\n'
	exit "$status"
fi

if [[ -n "$output" ]]; then
	printf '%s\n' "$output"
fi

exit "$status"
