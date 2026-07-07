#!/usr/bin/env bash
# Shared helpers for repository shell tests.

# Removes the temporary test root created by the calling test script.
cleanup() {
	rm -rf "$TEST_ROOT"
}

# Prints a failing assertion message and exits.
#
# @param  {string}  message
#     Failure message to display.
fail() {
	printf '✗ %s\n' "$1" >&2
	exit 1
}

# Asserts that a file exists.
#
# @param  {string}  path
#     File path to check.
assert_file() {
	local path="$1"

	[ -f "$path" ] || fail "Expected file: $path"
}

# Asserts that a path is a symlink resolving to an existing file.
#
# @param  {string}  path
#     Path to check.
assert_link() {
	local path="$1"

	[ -L "$path" ] || fail "Expected symlink: $path"
	[ -f "$path" ] || fail "Symlink does not resolve to a file: $path"
}

# Asserts that a path is a symlink resolving to an existing directory.
#
# @param  {string}  path
#     Path to check.
assert_dir_link() {
	local path="$1"

	[ -L "$path" ] || fail "Expected symlink: $path"
	[ -d "$path" ] || fail "Symlink does not resolve to a directory: $path"
}

# Asserts that a directory exists.
#
# @param  {string}  path
#     Directory path to check.
assert_dir() {
	local path="$1"

	[ -d "$path" ] || fail "Expected directory: $path"
}

# Asserts that a path does not exist.
#
# @param  {string}  path
#     Path to check.
assert_not_exists() {
	local path="$1"

	[ ! -e "$path" ] || fail "Expected no path: $path"
}

# Asserts that a path does not point to a file.
#
# @param  {string}  path
#     Path to check.
assert_not_file() {
	local path="$1"

	[ ! -f "$path" ] || fail "Expected no file: $path"
}

# Asserts that a file contains a fixed string.
#
# @param  {string}  path
#     File path to inspect.
# @param  {string}  pattern
#     Fixed string to find.
assert_contains() {
	local path="$1"
	local pattern="$2"

	grep -Fq -- "$pattern" "$path" || fail "Expected $path to contain: $pattern"
}

# Asserts that a file does not contain a fixed string.
#
# @param  {string}  path
#     File path to inspect.
# @param  {string}  pattern
#     Fixed string that must be absent.
assert_not_contains() {
	local path="$1"
	local pattern="$2"

	! grep -Fq -- "$pattern" "$path" || fail "Expected $path not to contain: $pattern"
}

# Asserts that two strings are equal.
#
# @param  {string}  actual
#     Actual value.
# @param  {string}  expected
#     Expected value.
assert_equals() {
	local actual="$1"
	local expected="$2"

	[ "$actual" = "$expected" ] || fail "Expected '$expected', got '$actual'"
}

# Asserts that a file is empty or missing.
#
# @param  {string}  path
#     File path to inspect.
assert_empty() {
	local path="$1"

	[ ! -s "$path" ] || fail "Expected $path to be empty"
}
