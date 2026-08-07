#!/usr/bin/env bash
# Checks dist hook copies against their hook source scripts.

set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib/validate.sh"

validate_require_jq

STALE=0

while IFS= read -r -d '' manifest; do
	dir=$(dirname "$manifest")
	name=$(jq -r '.name' "$manifest")

	for src in "$dir/${name}.sh" "$dir/${name}"; do
		if [ ! -f "$src" ]; then
			continue
		fi

		dst="$REPO_DIR/dist/claude/hooks/$(basename "$src")"

		if [ ! -f "$dst" ]; then
			validate_fail "dist/claude/hooks/$(basename "$src") missing (run scripts/sync.sh)"
			STALE=$((STALE + 1))
		elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
			validate_fail "dist/claude/hooks/$(basename "$src") out of sync with source (run scripts/sync.sh)"
			STALE=$((STALE + 1))
		fi
	done
done < <(find "$REPO_DIR/src/hooks/claude" -name "hook.json" -print0 | sort -z)

shared_hook="$REPO_DIR/src/hooks/shared/tool-call-checkpoint.sh"
if [ -f "$shared_hook" ]; then
	for destination in "$REPO_DIR/dist/claude/hooks/tool-call-checkpoint.sh" "$REPO_DIR/dist/codex/hooks/tool-call-checkpoint.sh"; do
		if [ ! -f "$destination" ]; then
			validate_fail "${destination#"$REPO_DIR/"} missing (run scripts/sync.sh)"
			STALE=$((STALE + 1))
		elif ! diff -q "$shared_hook" "$destination" >/dev/null 2>&1; then
			validate_fail "${destination#"$REPO_DIR/"} out of sync with source (run scripts/sync.sh)"
			STALE=$((STALE + 1))
		fi
	done
fi

shared_message="$REPO_DIR/src/hooks/shared/tool-call-checkpoint-message.md"
if [ -f "$shared_message" ]; then
	for destination in "$REPO_DIR/dist/claude/hooks/tool-call-checkpoint-message.md" "$REPO_DIR/dist/codex/hooks/tool-call-checkpoint-message.md"; do
		if [ ! -f "$destination" ]; then
			validate_fail "${destination#"$REPO_DIR/"} missing (run scripts/sync.sh)"
			STALE=$((STALE + 1))
		elif ! diff -q "$shared_message" "$destination" >/dev/null 2>&1; then
			validate_fail "${destination#"$REPO_DIR/"} out of sync with source (run scripts/sync.sh)"
			STALE=$((STALE + 1))
		fi
	done
fi

validate_finish
