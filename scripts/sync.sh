#!/usr/bin/env bash
# Generates all dist/ output from source files.
#
# Build order:
#   1. dist/skills/ runtime skills + global-skills.md (build-skill-mds.py)
#   2. Docs tables generated from skill/hook manifests (build-docs.py)
#   3. dist/claude/hooks/ (copied from hooks/claude/ source)
#   4. dist/claude/CLAUDE.md and dist/codex/AGENTS.md (assembled from rules/)
#   5. dist/chatgpt/ (build-chatgpt-target.py)
#   6. dist/claude/settings.json (build-settings.py)
#   7. Validation (validate.sh)

set -euo pipefail

# macOS ships bash 3.2; several validators need bash 4+ (declare -A, mapfile).
# Re-exec under homebrew bash if the current interpreter is too old.
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
	export PATH="/opt/homebrew/bin:$PATH"
	if [ -x /opt/homebrew/bin/bash ]; then
		exec /opt/homebrew/bin/bash "$0" "$@"
	else
		exec "$(command -v bash)" "$0" "$@"
	fi
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

source "$REPO_DIR/scripts/lib/colours.sh"
source "$REPO_DIR/scripts/lib/cli-style-output.sh"
source "$REPO_DIR/scripts/lib/dist-targets.sh"

# Clears dist/claude/hooks/ and repopulates it from the hook source dirs.
# Clearing first prevents stale files from accumulating when hooks are renamed.
copy_hooks() {
	mkdir -p "$REPO_DIR/dist/claude/hooks"
	find "$REPO_DIR/dist/claude/hooks" -maxdepth 1 -type f -delete

	local hook_dir script
	for hook_dir in "$REPO_DIR/hooks/claude/"/*/; do
		[ -d "$hook_dir" ] || continue
		for script in "$hook_dir"*; do
			[ -f "$script" ] || continue
			[[ "$(basename "$script")" == "hook.json" ]] && continue
			cp "$script" "$REPO_DIR/dist/claude/hooks/$(basename "$script")"
		done
	done
}

mkdir -p "$REPO_DIR/dist/claude" "$REPO_DIR/dist/codex"

cli_section "Generated outputs" "Build dist files and manifests"

python3 "$REPO_DIR/scripts/build/build-skill-mds.py" >/dev/null
python3 "$REPO_DIR/scripts/build/build-docs.py" >/dev/null
copy_hooks
write_target "$CLAUDE_TARGET" "${CLAUDE_PARTS[@]}"
write_target "$CODEX_TARGET" "${CODEX_PARTS[@]}"
python3 "$REPO_DIR/scripts/build/build-chatgpt-target.py" >/dev/null
python3 "$REPO_DIR/scripts/build/build-settings.py" >/dev/null

# Copy static config files from adapters to dist.
cp "$REPO_DIR/adapters/claude/mcp.json" "$REPO_DIR/dist/claude/.mcp.json"
cp "$REPO_DIR/adapters/codex/hooks.json" "$REPO_DIR/dist/codex/hooks.json"

cli_status success "synced" "dist/claude/CLAUDE.md"
cli_status success "synced" "dist/codex/AGENTS.md"
cli_status success "synced" "dist/chatgpt/"
cli_status success "synced" "manifest-backed docs tables"
cli_status success "synced" "dist/claude/settings.json"
cli_status success "synced" "dist/codex/hooks.json"

bash "$REPO_DIR/scripts/validate.sh"
