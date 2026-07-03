#!/usr/bin/env bash
# Checks dist/skills/*/SKILL.md, dist/claude/CLAUDE.md, and dist/codex/AGENTS.md
# against a fresh rebuild from source, so content drift (not just missing
# files) is caught the same way check-hook-sync.sh catches hook drift.

set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/lib/validate.sh"

REAL_REPO_DIR="$REPO_DIR"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Mirror only the inputs build-skill-mds.py and the CLAUDE/AGENTS assembly
# need, at the same relative paths, so REPO_DIR inside the copied script
# resolves to $TMP_DIR instead of the real repo.
mkdir -p "$TMP_DIR/skills" "$TMP_DIR/rules" "$TMP_DIR/scripts/build" "$TMP_DIR/scripts/lib" \
	"$TMP_DIR/dist/claude/source" "$TMP_DIR/dist/codex/source"

cp -r "$REAL_REPO_DIR/skills/." "$TMP_DIR/skills/"
cp "$REAL_REPO_DIR/rules/"*.md "$TMP_DIR/rules/"
cp "$REAL_REPO_DIR/dist/claude/source/header.md" "$TMP_DIR/dist/claude/source/"
cp "$REAL_REPO_DIR/dist/codex/source/header.md" "$REAL_REPO_DIR/dist/codex/source/codebase-memory.md" "$TMP_DIR/dist/codex/source/"
cp "$REAL_REPO_DIR/scripts/build/build-skill-mds.py" "$TMP_DIR/scripts/build/"
cp "$REAL_REPO_DIR/scripts/lib/dist-targets.sh" "$TMP_DIR/scripts/lib/"

python3 "$TMP_DIR/scripts/build/build-skill-mds.py" >/dev/null

# Reassigns REPO_DIR only for the duration of this subshell, so dist-targets.sh
# builds CLAUDE_PARTS/CODEX_PARTS against the temp tree without leaking the
# override into the rest of this script.
(
	REPO_DIR="$TMP_DIR"
	source "$TMP_DIR/scripts/lib/dist-targets.sh"
	write_target "$CLAUDE_TARGET" "${CLAUDE_PARTS[@]}"
	write_target "$CODEX_TARGET" "${CODEX_PARTS[@]}"
)

if ! diff -q "$TMP_DIR/dist/claude/CLAUDE.md" "$REAL_REPO_DIR/dist/claude/CLAUDE.md" >/dev/null 2>&1; then
	validate_fail "dist/claude/CLAUDE.md out of sync with source (run scripts/sync.sh)"
fi

if ! diff -q "$TMP_DIR/dist/codex/AGENTS.md" "$REAL_REPO_DIR/dist/codex/AGENTS.md" >/dev/null 2>&1; then
	validate_fail "dist/codex/AGENTS.md out of sync with source (run scripts/sync.sh)"
fi

if ! diff -rq "$TMP_DIR/dist/skills" "$REAL_REPO_DIR/dist/skills" >/dev/null 2>&1; then
	validate_fail "dist/skills/ out of sync with source (run scripts/sync.sh)"
fi

validate_finish
