#!/usr/bin/env bash
# Shared cli-style rendering helpers for repository scripts.

CLI_STYLE_BIN="${CLI_STYLE_BIN:-$REPO_DIR/.agent/tools/cli-style/bin/cli-style}"
export CLI_STYLE_BIN

if [ ! -x "$CLI_STYLE_BIN" ]; then
	printf 'cli-style is not installed. Run: scripts/install-cli-style.sh\n' >&2
	exit 1
fi

source "$("$CLI_STYLE_BIN" adapter-path bash)"

# Renders a status row through the installed cli-style binary.
#
# @param  {string}  type
#     Status result type.
# @param  {string}  label
#     Main status label.
# @param  {string}  detail
#     Additional status text.
cli_status() {
	local type="$1"
	local label="$2"
	local detail="${3:-}"

	case "$type" in
		error) type="failed" ;;
		muted) type="unchanged" ;;
	esac

	python3 - "$type" "$label" "$detail" <<'PY' | cli_style_render status
import json
import sys

print(json.dumps({
	"type": sys.argv[1],
	"label": sys.argv[2],
	"detail": sys.argv[3],
}))
PY
}
