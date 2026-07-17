#!/usr/bin/env bash
# Shared definition of how dist/claude/CLAUDE.md and dist/codex/AGENTS.md are
# assembled from rules/ fragments. Sourced by scripts/sync.sh (real build) and
# scripts/validate/check-dist-sync.sh (drift check against a temp rebuild).
# Requires REPO_DIR to already be set before sourcing.

CLAUDE_TARGET="$REPO_DIR/dist/claude/CLAUDE.md"
CODEX_TARGET="$REPO_DIR/dist/codex/AGENTS.md"

# Ordered fragment lists for each agent's composed output file.
# global-skills.md is omitted from Claude output because skill-file-trigger
# injects skill reminders on file writes.
CLAUDE_PARTS=(
	"$REPO_DIR/dist/claude/source/header.md"
	"$REPO_DIR/rules/global-rules.md"
	"$REPO_DIR/dist/claude/source/subagent-delegation.md"
	"$REPO_DIR/rules/identity.md"
	"$REPO_DIR/rules/skills-policy.md"
	"$REPO_DIR/rules/file-discovery.md"
)

CODEX_PARTS=(
	"$REPO_DIR/dist/codex/source/header.md"
	"$REPO_DIR/rules/global-rules.md"
	"$REPO_DIR/rules/identity.md"
	"$REPO_DIR/rules/skills-policy.md"
	"$REPO_DIR/rules/file-discovery.md"
)

# Concatenates ordered fragment files into a single target file, with a blank
# line separating each fragment so sections don't run together.
#
# @param  {string}  target
#     Output file path.
# @param  {string}  ...
#     Fragment file paths (remaining arguments), in order.
write_target() {
	local target="$1"
	shift

	: > "$target"

	local part
	local first=true

	for part in "$@"; do
		if [ "$first" = false ]; then
			printf '\n' >> "$target"
		fi

		cat "$part" >> "$target"
		first=false
	done
}
