#!/usr/bin/env bash
# Blocks broad searches that bypass ignore rules or enter generated and cached directories.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

input="$(cat)"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)" || exit 0
[[ "$tool_name" == "Bash" ]] || exit 0

command_str="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)" || exit 0
[[ -n "$command_str" ]] || exit 0

# Returns the reason a search command must be blocked, or an empty string when it is safe.
#
# @param  {string}  command
#     Shell command from the Bash tool payload.
blocked_search_reason() {
	python3 - "$1" <<'PY'
import os
import re
import shlex
import sys
from typing import Optional

COMMAND_SEPARATORS = {"&", "&&", ";", ";;", "|", "||"}
PROTECTED_DIRECTORIES = {
	".cache",
	".caches",
	".git",
	".playwright",
	"build",
	"coverage",
	"dist",
	"ms-playwright",
	"node_modules",
	"playwright-report",
	"test-results",
}
ROOT_PATHS = {"$HOME", "$PWD", "${HOME}", "${PWD}", ".", "..", "../", "./", "/", "~"}
RG_OPTIONS_WITH_VALUE = {
	"--after-context",
	"--before-context",
	"--context",
	"--encoding",
	"--file",
	"--glob",
	"--iglob",
	"--ignore-file",
	"--max-columns",
	"--max-count",
	"--max-depth",
	"--max-filesize",
	"--path-separator",
	"--pre",
	"--pre-glob",
	"--regexp",
	"--replace",
	"--sort",
	"--sortr",
	"--type",
	"--type-add",
	"--type-clear",
	"-A",
	"-B",
	"-C",
	"-E",
	"-M",
	"-T",
	"-e",
	"-f",
	"-g",
	"-m",
	"-r",
	"-t",
}
GREP_OPTIONS_WITH_VALUE = {
	"--after-context",
	"--before-context",
	"--binary-files",
	"--context",
	"--directories",
	"--exclude",
	"--exclude-dir",
	"--exclude-from",
	"--file",
	"--include",
	"--label",
	"--max-count",
	"--regexp",
	"-A",
	"-B",
	"-C",
	"-D",
	"-d",
	"-e",
	"-f",
	"-m",
}
TREE_OPTIONS_WITH_VALUE = {"--filelimit", "-I", "-L", "-P", "-o"}


# Splits a shell command at control operators without executing it.
#
# @param  {str}  command
#     Shell command to split.
# @return  {list[list[str]]}
#     Token groups for the simple commands it contains.
def simple_commands(command: str) -> list[list[str]]:
	lexer = shlex.shlex(command.replace("\n", ";"), posix=True, punctuation_chars=";&|")
	lexer.commenters = ""
	lexer.whitespace_split = True
	commands: list[list[str]] = []
	current: list[str] = []

	try:
		tokens = list(lexer)
	except ValueError:
		return []

	for token in tokens:
		if token in COMMAND_SEPARATORS:
			if current:
				commands.append(current)
				current = []
			continue

		current.append(token)

	if current:
		commands.append(current)

	return commands


# Returns positional arguments while skipping options and their values.
#
# @param  {list[str]}  arguments
#     Arguments following a search executable.
# @param  {set[str]}  options_with_value
#     Options whose following token is not a search path.
# @return  {list[str]}
#     Positional pattern and path arguments.
def positional_arguments(arguments: list[str], options_with_value: set[str]) -> list[str]:
	positionals: list[str] = []
	expect_value = False
	options_enabled = True

	for argument in arguments:
		if expect_value:
			expect_value = False
			continue

		if options_enabled and argument == "--":
			options_enabled = False
			continue

		if options_enabled and argument in options_with_value:
			expect_value = True
			continue

		if options_enabled and argument.startswith("-") and argument != "-":
			continue

		positionals.append(argument)

	return positionals


# Returns whether a search pattern was supplied through an option.
#
# @param  {list[str]}  arguments
#     Search command arguments.
# @return  {bool}
#     True when positional arguments contain only paths.
def has_pattern_option(arguments: list[str]) -> bool:
	return any(
		argument in {"--regexp", "-e"}
		or argument.startswith("--regexp=")
		or (argument.startswith("-e") and len(argument) > 2)
		for argument in arguments
	)


# Returns whether a path names the repository root or a broader location.
#
# @param  {str}  path
#     Search path argument.
# @return  {bool}
#     True when the path is too broad for recursive discovery.
def is_root_path(path: str) -> bool:
	return path in ROOT_PATHS or os.path.abspath(path) == "/"


# Returns the protected directory named by a path, when present.
#
# @param  {str}  path
#     Search path argument.
# @return  {str | None}
#     Protected directory component or None.
def protected_directory(path: str) -> Optional[str]:
	path_parts = [part for part in path.replace("\\", "/").split("/") if part not in {"", "."}]

	for path_part in path_parts:
		if path_part in PROTECTED_DIRECTORIES:
			return path_part

	return None


# Returns a reason when any supplied search path is too broad or protected.
#
# @param  {list[str]}  paths
#     Paths searched recursively.
# @return  {str | None}
#     Block reason or None.
def unsafe_path_reason(paths: list[str]) -> Optional[str]:
	if not paths:
		return "the recursive search defaults to the repository root"

	for path in paths:
		if is_root_path(path):
			return f"the recursive search targets {path!r}"

		blocked_directory = protected_directory(path)

		if blocked_directory:
			return f"the search enters protected directory {blocked_directory!r}"

	return None


# Returns the unsafe search reason for one executable invocation.
#
# @param  {str}  executable
#     Search executable basename.
# @param  {list[str]}  arguments
#     Arguments passed to the executable.
# @param  {str | None}  working_directory
#     Explicit directory selected by an earlier cd command.
# @return  {str | None}
#     Block reason or None.
def search_reason(executable: str, arguments: list[str], working_directory: Optional[str]) -> Optional[str]:
	if working_directory:
		blocked_directory = protected_directory(working_directory)

		if blocked_directory:
			return f"the search runs inside protected directory {blocked_directory!r}"

	if executable == "rg":
		bypasses_ignores = any(
			argument in {"--no-ignore", "--no-ignore-global", "--no-ignore-parent", "--no-ignore-vcs", "--unrestricted"}
			or re.fullmatch(r"-u{1,3}[A-Za-z]*", argument)
			for argument in arguments
		)

		if not bypasses_ignores:
			return None

		positionals = positional_arguments(arguments, RG_OPTIONS_WITH_VALUE)
		files_only = "--files" in arguments
		paths = positionals if files_only or has_pattern_option(arguments) else positionals[1:]

		if not paths and working_directory and not is_root_path(working_directory):
			paths = [working_directory]

		return unsafe_path_reason(paths)

	if executable in {"grep", "egrep", "fgrep"}:
		recursive = any(
			argument in {"--recursive", "-R", "-r"}
			or (argument.startswith("-") and not argument.startswith("--") and ("R" in argument or "r" in argument))
			for argument in arguments
		)

		if not recursive:
			return None

		positionals = positional_arguments(arguments, GREP_OPTIONS_WITH_VALUE)
		paths = positionals if has_pattern_option(arguments) else positionals[1:]

		if not paths and working_directory and not is_root_path(working_directory):
			paths = [working_directory]

		return unsafe_path_reason(paths)

	if executable == "find":
		paths = []

		for argument in arguments:
			if argument.startswith("-") or argument in {"!", "("}:
				break

			paths.append(argument)

		if not paths and working_directory and not is_root_path(working_directory):
			paths = [working_directory]

		return unsafe_path_reason(paths)

	if executable == "tree":
		paths = positional_arguments(arguments, TREE_OPTIONS_WITH_VALUE)

		if not paths and working_directory and not is_root_path(working_directory):
			paths = [working_directory]

		return unsafe_path_reason(paths)

	return None


# Returns the first unsafe search in a complete shell command.
#
# @param  {str}  command
#     Shell command from the tool payload.
# @return  {str | None}
#     Block reason or None.
def command_reason(command: str) -> Optional[str]:
	working_directory: Optional[str] = None
	search_executables = {"egrep", "fgrep", "find", "grep", "rg", "tree"}

	for command_tokens in simple_commands(command):
		if not command_tokens:
			continue

		if os.path.basename(command_tokens[0]) == "cd" and len(command_tokens) > 1:
			working_directory = command_tokens[1]
			continue

		for index, token in enumerate(command_tokens):
			executable = os.path.basename(token)

			if executable not in search_executables:
				continue

			reason = search_reason(executable, command_tokens[index + 1 :], working_directory)

			if reason:
				return reason

	return None


reason = command_reason(sys.argv[1])

if reason:
	print(reason)
PY
}

# Denies the Bash tool call and tells the agent how to narrow it.
#
# @param  {string}  reason
#     Human-readable reason shown to the model.
block() {
	printf 'guard-search-boundaries: blocked: %s. Scope the search to a specific source or planning directory; use an exact file read for protected output.\n' "$1" >&2
	exit 2
}

reason="$(blocked_search_reason "$command_str")" || exit 0
[[ -n "$reason" ]] && block "$reason"

exit 0
