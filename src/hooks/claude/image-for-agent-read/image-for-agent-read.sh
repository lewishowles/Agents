#!/usr/bin/env bash
# Reroutes local image Read calls through image-for-agent.
#
# This hook is an optimisation only. Any parsing, dependency, source, cache,
# or conversion error exits silently so the original Read can proceed.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0
command -v image-for-agent >/dev/null 2>&1 || exit 0
command -v shasum >/dev/null 2>&1 || exit 0
command -v stat >/dev/null 2>&1 || exit 0

input="$(cat)"
source_path="$(printf '%s' "$input" | jq -er '.tool_input.file_path | select(type == "string" and length > 0)' 2>/dev/null)" || exit 0

shopt -s nocasematch
case "$source_path" in
*.png|*.jpg|*.jpeg|*.webp) ;;
*) exit 0 ;;
esac
shopt -u nocasematch

[[ -f "$source_path" ]] || exit 0

mtime="$(stat -f '%m' "$source_path" 2>/dev/null)" || exit 0
[[ "$mtime" =~ ^[0-9]+$ ]] || exit 0

preset="ui"
cache_dir="$HOME/.claude/image-for-agent-cache"
cache_identity="${source_path}"$'\n'"${mtime}"$'\n'"${preset}"
cache_digest="$(printf '%s' "$cache_identity" | shasum -a 256 2>/dev/null)" || exit 0
cache_key="${cache_digest%% *}"
[[ "$cache_key" =~ ^[[:xdigit:]]{64}$ ]] || exit 0

cache_path="$cache_dir/${cache_key}.png"

if [[ ! -s "$cache_path" ]]; then
	mkdir -p "$cache_dir" || exit 0
	image-for-agent "$source_path" --preset "$preset" --output "$cache_path" >/dev/null 2>&1 || exit 0
	[[ -s "$cache_path" ]] || exit 0
fi

printf '%s' "$input" | jq -c --arg cache_path "$cache_path" \
	'{hookSpecificOutput: {hookEventName: "PreToolUse", updatedInput: (.tool_input | .file_path = $cache_path)}}'
