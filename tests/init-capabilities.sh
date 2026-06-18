#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)

source "$SCRIPT_DIR/lib/test-helpers.sh"

trap cleanup EXIT

run_init() {
	local target_dir="$1"
	shift

	"$REPO_DIR/scripts/init-capabilities.py" --project-dir "$target_dir" "$@"
}

create_node_project() {
	local target_dir="$1"

	mkdir -p "$target_dir/src" "$target_dir/tests" "$target_dir/docs" "$target_dir/dist"
	printf '{"scripts":{"test":"vitest","test:unit":"vitest","test:unit:run":"vitest run","lint":"eslint . --fix","lint:check":"eslint .","typecheck":"vue-tsc --noEmit","build":"vite build","test:e2e":"playwright test","test:component":"playwright test -c test/playwright-ct.config.js"},"peerDependencies":{"vue":"latest"},"packageManager":"bun@1.2.0"}\n' > "$target_dir/package.json"
	printf 'lock\n' > "$target_dir/bun.lock"
	printf 'export default {}\n' > "$target_dir/vitest.config.js"
	mkdir -p "$target_dir/test"
	printf 'export default {}\n' > "$target_dir/test/playwright-ct.config.js"
	printf '# App\n' > "$target_dir/README.md"
	printf '# Rules\n' > "$target_dir/AGENTS.md"
}

test_preview_does_not_write() {
	local target_dir="$TEST_ROOT/preview"
	local output="$TEST_ROOT/preview.md"
	create_node_project "$target_dir"

	run_init "$target_dir" > "$output"

	assert_not_file "$target_dir/AGENT_CAPABILITIES.md"
	assert_contains "$output" "Primary stack: Vue"
	assert_contains "$output" "Package manager: Bun (detected from \`bun.lock\`)"
	assert_contains "$output" "Runtime requirements: bun@1.2.0"
	assert_contains "$output" '- None detected.'
	assert_contains "$output" 'vitest.config.js'
	assert_contains "$output" 'test/playwright-ct.config.js'
	assert_contains "$output" '| Lint | `bun run lint:check` |'
	assert_contains "$output" '| Unit tests | `bun run test:unit` |'
	assert_contains "$output" '| Component tests | `bun run test:component` |'
	assert_contains "$output" '| End-to-end tests | `bun run test:e2e` |'
	assert_contains "$output" '| Build | `bun run build` |'
	assert_contains "$output" '| None detected |  |  |'
}

test_write_creates_missing_manifest() {
	local target_dir="$TEST_ROOT/write"
	create_node_project "$target_dir"

	run_init "$target_dir" --write >/dev/null

	assert_file "$target_dir/AGENT_CAPABILITIES.md"
	assert_contains "$target_dir/AGENT_CAPABILITIES.md" "## Common checks"
}

test_existing_manifest_requires_force() {
	local target_dir="$TEST_ROOT/existing"
	create_node_project "$target_dir"
	printf 'custom\n' > "$target_dir/AGENT_CAPABILITIES.md"

	if run_init "$target_dir" --write >/dev/null 2>&1; then
		fail "Expected existing manifest write to fail without --force"
	fi

	assert_contains "$target_dir/AGENT_CAPABILITIES.md" "custom"
	run_init "$target_dir" --write --force >/dev/null
	assert_contains "$target_dir/AGENT_CAPABILITIES.md" "Project capabilities"
}

test_force_preserves_known_existing_values() {
	local target_dir="$TEST_ROOT/preserve"
	create_node_project "$target_dir"
	cat > "$target_dir/AGENT_CAPABILITIES.md" <<'EOF'
# Project capabilities

## Repo context

- Package manager: pnpm (manual)

## Diagnostics and checks

| Purpose | Command | Notes |
| --- | --- | --- |
| Unit test for one file | `pnpm vitest src/example.test.ts` | Manual command. |
EOF

	run_init "$target_dir" --write --force >/dev/null

	assert_contains "$target_dir/AGENT_CAPABILITIES.md" "pnpm (manual)"
	assert_contains "$target_dir/AGENT_CAPABILITIES.md" 'pnpm vitest src/example.test.ts'
	assert_contains "$target_dir/AGENT_CAPABILITIES.md" "Preserved from existing"
}

test_placeholders_do_not_override_detected_values() {
	local target_dir="$TEST_ROOT/placeholders"
	local output="$TEST_ROOT/placeholders.md"
	create_node_project "$target_dir"
	cat > "$target_dir/AGENT_CAPABILITIES.md" <<'EOF'
# Project capabilities

## Diagnostics and checks

| Purpose | Command | Notes |
| --- | --- | --- |
| Unit test for one file | `[command]` | Placeholder. |
| Lint changed files | `[unknown]` | Placeholder. |
EOF

	run_init "$target_dir" > "$output"

	assert_contains "$output" '| Unit tests | `bun run test:unit` |'
	assert_contains "$output" '| Lint | `bun run lint:check` |'
}

test_missing_package_scripts_leave_unknowns() {
	local target_dir="$TEST_ROOT/no-package"
	local output="$TEST_ROOT/no-package.md"
	mkdir -p "$target_dir"

	run_init "$target_dir" > "$output"

	assert_contains "$output" "Not detected"
	assert_contains "$output" "| Unit tests | Not detected |"
	assert_contains "$output" "| Build | Not detected |"
}

test_repo_preview_uses_progress_file() {
	local output="$TEST_ROOT/repo.md"

	run_init "$REPO_DIR" > "$output"

	assert_contains "$output" '`PROGRESS.md`'
	assert_not_file "$REPO_DIR/AGENT_CAPABILITIES.md"
}

test_preview_does_not_write
test_write_creates_missing_manifest
test_existing_manifest_requires_force
test_force_preserves_known_existing_values
test_placeholders_do_not_override_detected_values
test_missing_package_scripts_leave_unknowns
test_repo_preview_uses_progress_file

printf '✓ init-capabilities tests passed\n'
