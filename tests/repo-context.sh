#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)

source "$SCRIPT_DIR/lib/test-helpers.sh"

trap cleanup EXIT

run_context() {
	local target_dir="$1"
	shift

	"$REPO_DIR/scripts/repo-context.py" --project-dir "$target_dir" "$@"
}

create_project() {
	local target_dir="$1"

	mkdir -p "$target_dir/.agent/scripts" "$target_dir/src" "$target_dir/dist" "$target_dir/.boilersuit"
	printf '# Rules\n' > "$target_dir/AGENTS.md"
	printf '# Progress\n' > "$target_dir/PROGRESS.md"
	printf '#!/usr/bin/env python3\n' > "$target_dir/.agent/scripts/project-diagnostics.py"
	chmod +x "$target_dir/.agent/scripts/project-diagnostics.py"

	cat > "$target_dir/WORKSPACE.md" <<'EOF'
# Workspace

## Repo summary

- Primary stack: JavaScript library
- Package manager: Bun (detected from `bun.lockb`)
- Script runner: `bun run <script>`
- Runtime requirements: Node >=20; Bun
- Progress files: `PROGRESS.md`
- Agent rules: `AGENTS.md`

## Generated or build output

- `dist`

## Important paths

- Main source directories: `src`

## Generators

| Name | Command | Notes |
| --- | --- | --- |
| Boilersuit | `.boilersuit` | Local generators. |
EOF
}

test_markdown_uses_workspace_and_git_counts() {
	local target_dir="$TEST_ROOT/markdown"
	local output="$TEST_ROOT/markdown.md"
	create_project "$target_dir"

	git -C "$target_dir" init --initial-branch=main >/dev/null
	git -C "$target_dir" config user.email "test@example.com"
	git -C "$target_dir" config user.name "Test User"
	git -C "$target_dir" add AGENTS.md >/dev/null
	git -C "$target_dir" commit -m "Initial" >/dev/null
	printf 'changed\n' >> "$target_dir/AGENTS.md"
	printf 'new\n' > "$target_dir/new.txt"

	run_context "$target_dir" > "$output"

	assert_contains "$output" "Source: WORKSPACE.md"
	assert_contains "$output" 'Workspace: `WORKSPACE.md`'
	assert_contains "$output" "Primary stack: JavaScript library"
	assert_contains "$output" 'Source dirs: `src`'
	assert_contains "$output" 'Diagnostics: `.agent/scripts/project-diagnostics.py --list`'
	assert_contains "$output" "Git: main; ahead 0, behind 0; 1 modified"
	assert_contains "$output" "untracked"
	assert_contains "$output" '`dist`'
	assert_contains "$output" 'Boilersuit: `.boilersuit`'
}

test_json_output_is_machine_readable() {
	local target_dir="$TEST_ROOT/json"
	local output="$TEST_ROOT/context.json"
	create_project "$target_dir"

	run_context "$target_dir" --json > "$output"

	python3 - "$output" <<'PY'
import json
import sys

data = json.loads(open(sys.argv[1]).read())
assert data["summary"]["primary_stack"] == "JavaScript library"
assert data["summary"]["source_dirs"] == "`src`"
assert data["diagnostics"] == ".agent/scripts/project-diagnostics.py --list"
assert data["generated_paths"] == ["dist"]
PY
}

test_missing_workspace_labels_inferred_source() {
	local target_dir="$TEST_ROOT/inferred"
	local output="$TEST_ROOT/inferred.md"
	mkdir -p "$target_dir/dist"
	printf '# Rules\n' > "$target_dir/AGENTS.md"

	run_context "$target_dir" > "$output"

	assert_contains "$output" "Source: inferred"
	assert_contains "$output" "Agent rules: \`AGENTS.md\`"
	assert_contains "$output" '`dist`'
}

test_legacy_manifest_is_used_as_fallback() {
	local target_dir="$TEST_ROOT/legacy"
	local output="$TEST_ROOT/legacy.md"
	create_project "$target_dir"
	mv "$target_dir/WORKSPACE.md" "$target_dir/AGENT_CAPABILITIES.md"

	run_context "$target_dir" > "$output"

	assert_contains "$output" "Source: AGENT_CAPABILITIES.md"
	assert_contains "$output" 'Workspace: `AGENT_CAPABILITIES.md`'
}

test_markdown_uses_workspace_and_git_counts
test_json_output_is_machine_readable
test_missing_workspace_labels_inferred_source
test_legacy_manifest_is_used_as_fallback

printf '✓ repo-context tests passed\n'
