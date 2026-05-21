#!/usr/bin/env bash
#
# skill-file-trigger — PreToolUse hook (Write|Edit)
#
# Fires whenever Claude is about to write or edit a file. Checks the file
# extension and injects a skill reminder into Claude's context.
#
# How it works:
#   Claude Code sends tool input JSON to stdin before each Write or Edit call.
#   This script extracts the file_path, determines the file type by extension,
#   and outputs hookSpecificOutput.additionalContext telling Claude which skills
#   apply. The reminder is injected before the write completes, so it can
#   influence subsequent edits within the same response turn.
#
# Complements skill-autotrigger.sh:
#   skill-autotrigger runs on the user's prompt text — it can't know what
#   files Claude will choose to write. skill-file-trigger catches the gap:
#   when Claude independently decides to write a .swift or .vue file (e.g.
#   after "let's continue"), the reminder fires at the point of the write.
#
# Limitations:
#   - By the time this hook fires, the file content is already formulated in
#     Claude's tool call. The reminder primarily affects subsequent edits in
#     the same turn, not the current write.
#   - Extension-based only — doesn't inspect file contents or project context.
#
# Requires: jq — silently skips (exit 0) if missing, so writes are never blocked.

command -v jq &>/dev/null || exit 0

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

[ -z "$file_path" ] && exit 0

filename=$(basename "$file_path")
ext="${filename##*.}"
skills=()

case "$ext" in
	swift)  skills+=("code-style" "swift") ;;
	vue)    skills+=("code-style" "vue" "vue-project-stack") ;;
	ts|tsx) skills+=("code-style" "typescript") ;;
	js)     skills+=("code-style") ;;
	sh)     skills+=("bash") ;;
	md)     skills+=("code-style" "writing") ;;
esac

shopt -s nocasematch

# README files: also pair with the readme skill
[[ "$filename" == "README.md" || "$filename" == "README" ]] && skills+=("readme")

# vite.config files: inject vite-patterns
[[ "$filename" == "vite.config.ts" || "$filename" == "vite.config.js" ]] && skills+=("vite-patterns")

# unit-testing: .test.js, .spec.js, .spec.ts, or XCTest files
[[ "$filename" =~ \.(test|spec)\.(js|ts)$ ]] || [[ "$filename" =~ Tests?\.(swift|js)$ ]] && skills+=("unit-testing")

# e2e-testing: .e2e.*, .cy.*, or files in e2e/ or tests/cypress/ directories
if [[ "$filename" =~ \.e2e\.(js|ts)$ ]] || [[ "$filename" =~ \.cy\.(js|ts)$ ]] || [[ "$file_path" =~ /e2e/ ]] || [[ "$file_path" =~ /tests/cypress/ ]]; then
	skills+=("e2e-testing")
fi

# architecture-decision-records: ADR files (0001-*.md pattern or adr/ directory)
[[ "$file_path" =~ /adr/ ]] || [[ "$filename" =~ ^[0-9]{4}- ]] && skills+=("architecture-decision-records")

# pinia-colada: files inside queries/ or mutations/ directories
if [[ "$file_path" =~ /queries/ ]] || [[ "$file_path" =~ /mutations/ ]]; then
	skills+=("code-style" "pinia-colada")
fi

shopt -u nocasematch

[ ${#skills[@]} -eq 0 ] && exit 0

unique=($(printf '%s\n' "${skills[@]}" | sort -u))

jq -n \
	--arg ctx "SKILL REMINDER (${filename}): If not already invoked this turn, use these skills now: ${unique[*]}." \
	'{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
