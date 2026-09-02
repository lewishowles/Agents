#!/usr/bin/env bash
# Blocks `git <subcommand> ... --no-pager`, which Git rejects with
# "error: invalid option: --no-pager". `--no-pager` is a Git global option and
# must sit before the subcommand: `git --no-pager log`, `git -C path --no-pager diff`.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"  # Raw PreToolUse payload on stdin.
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)" || exit 0
[[ "$tool_name" == "Bash" ]] || exit 0

command_str="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)" || exit 0
[[ -n "$command_str" ]] || exit 0

normalised="${command_str//$'\n'/ }"  # Newlines flattened so the patterns see one line.

git_pattern='(^|[;&|`(]|[[:space:]])git[[:space:]]'  # A git invocation anywhere in the command.
no_pager_pattern='(^|[[:space:]])--no-pager([[:space:]]|$)'  # The flag as its own token, not a substring.
# `--no-pager` in its valid slot: straight after `git` and any pre-subcommand global options.
valid_pattern='git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--git-dir=[^[:space:]]+|--work-tree=[^[:space:]]+|--paginate|-P))*[[:space:]]+--no-pager([[:space:]]|$)'

if [[ "$normalised" =~ $git_pattern ]] \
	&& [[ "$normalised" =~ $no_pager_pattern ]] \
	&& [[ ! "$normalised" =~ $valid_pattern ]]; then
	printf 'guard-no-pager: blocked: `--no-pager` is a Git global option and goes before the subcommand. Use `git --no-pager <subcommand>` or `git -C <path> --no-pager <subcommand>`.\n' >&2
	exit 2
fi

exit 0
