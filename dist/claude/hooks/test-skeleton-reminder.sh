#!/usr/bin/env bash

set -euo pipefail

command -v jq &>/dev/null || exit 0

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

[ -z "$file_path" ] && exit 0

filename=$(basename "$file_path")
extension="${filename##*.}"

is_test_file() {
	local path="$1"
	local name="$2"

	[[ "$name" =~ \.(test|spec)\.(js|ts|tsx|vue)$ ]] && return 0
	[[ "$name" =~ \.e2e\.(js|ts|tsx)$ ]] && return 0
	[[ "$name" =~ Tests?\.(swift|js|ts)$ ]] && return 0
	[[ "$path" =~ /(__tests__|test|tests|e2e)/ ]] && return 0

	return 1
}

is_implementation_file() {
	case "$extension" in
		js|ts|tsx|vue|swift) return 0 ;;
		*) return 1 ;;
	esac
}

has_test_stack() {
	if [ "$extension" = "swift" ]; then
		[ -d "Tests" ] || [ -f "Package.swift" ]
		return
	fi

	[ -f "package.json" ] || return 1

	if command -v jq &>/dev/null; then
		jq -e '
			[
				.scripts,
				.dependencies,
				.devDependencies
			]
			| map(select(. != null))
			| add
			| tostring
			| test("vitest|jest|playwright|cypress"; "i")
		' package.json >/dev/null 2>&1
	else
		grep -qiE 'vitest|jest|playwright|cypress' package.json
	fi
}

test_candidates() {
	local path="$1"
	local dir
	local base

	dir=$(dirname "$path")
	base=$(basename "$path")
	base="${base%.*}"

	case "$extension" in
		js|ts|tsx|vue)
			printf '%s/%s.test.%s\n' "$dir" "$base" "$extension"
			printf '%s/%s.spec.%s\n' "$dir" "$base" "$extension"
			printf '%s/__tests__/%s.test.%s\n' "$dir" "$base" "$extension"
			;;
		swift)
			printf 'Tests/%sTests.swift\n' "$base"
			printf '%s/%sTests.swift\n' "$dir" "$base"
			;;
	esac
}

matching_test_exists() {
	local candidate

	while IFS= read -r candidate; do
		[ -f "$candidate" ] && return 0
	done < <(test_candidates "$file_path")

	return 1
}

if ! is_implementation_file || is_test_file "$file_path" "$filename" || ! has_test_stack || matching_test_exists; then
	exit 0
fi

first_candidate=$(test_candidates "$file_path" | sed -n '1p')
display_candidate="${first_candidate#$PWD/}"

jq -n \
	--arg ctx "TEST REMINDER (${filename}): This project has a test setup, but I couldn't find a matching test file. Add or update one alongside this implementation, for example ${display_candidate}." \
	'{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
