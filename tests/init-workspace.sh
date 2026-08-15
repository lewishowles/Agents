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

	"$REPO_DIR/scripts/init-workspace.py" --project-dir "$target_dir" "$@" </dev/null
}

create_node_project() {
	local target_dir="$1"

	mkdir -p "$target_dir/src" "$target_dir/tests" "$target_dir/docs" "$target_dir/dist" "$target_dir/.github/workflows"
	printf '{"name":"example-app","version":"1.2.3","private":true,"type":"module","scripts":{"test":"vitest","test:unit":"vitest","test:unit:run":"vitest run","lint":"eslint . --fix","lint:check":"eslint .","typecheck":"vue-tsc --noEmit","build":"vite build","test:e2e":"playwright test","test:component":"playwright test -c test/playwright-ct.config.js"},"peerDependencies":{"vue":"latest"},"packageManager":"bun@1.2.0","exports":{".":"./src/index.js"},"bin":{"example":"./bin/example.js"}}\n' > "$target_dir/package.json"
	printf 'lock\n' > "$target_dir/bun.lock"
	printf 'export default {}\n' > "$target_dir/vitest.config.js"
	mkdir -p "$target_dir/test"
	printf 'export default {}\n' > "$target_dir/test/playwright-ct.config.js"
	printf '# App\n' > "$target_dir/README.md"
	printf '# Rules\n' > "$target_dir/AGENTS.md"
	printf 'name: CI\n' > "$target_dir/.github/workflows/ci.yml"
}

create_javascript_library_project() {
	local target_dir="$1"

	mkdir -p "$target_dir/lib"
	printf '{"type":"module","files":["dist","types"],"exports":{"./array":{"import":"./dist/array.js"}},"devDependencies":{"vue":"latest"},"packageManager":"bun@1.2.0"}\n' > "$target_dir/package.json"
	printf 'lock\n' > "$target_dir/bun.lock"
}

create_xcode_project() {
	local target_dir="$1"

	mkdir -p "$target_dir/App/App.xcodeproj" "$target_dir/App/App" "$target_dir/App/AppTests" "$target_dir/App/AppUITests"
	printf 'import SwiftUI\n' > "$target_dir/App/App/App.swift"
	printf 'import XCTest\n' > "$target_dir/App/AppTests/AppTests.swift"
	printf 'import XCTest\n' > "$target_dir/App/AppUITests/AppUITests.swift"
	printf '{}\n' > "$target_dir/App/App.xctestplan"
	printf '# App\n' > "$target_dir/README.md"
	printf '# Architecture\n' > "$target_dir/ARCHITECTURE.md"
	printf '# Design\n' > "$target_dir/DESIGN.md"
}

create_nested_test_project() {
	local target_dir="$1"

	mkdir -p "$target_dir/src/analyser" "$target_dir/src/render"
	printf '{"scripts":{"test":"node --test"},"packageManager":"bun@1.2.0"}\n' > "$target_dir/package.json"
	printf 'lock\n' > "$target_dir/bun.lock"
	printf 'test("ok", () => {})\n' > "$target_dir/src/analyser/index.test.js"
	printf 'test("ok", () => {})\n' > "$target_dir/src/render/template.spec.js"
}

create_project_with_diagnostics() {
	local target_dir="$1"

	create_nested_test_project "$target_dir"
	mkdir -p "$target_dir/.agent/scripts"
	printf '#!/usr/bin/env python3\n' > "$target_dir/.agent/scripts/project-diagnostics.py"
	printf '#!/usr/bin/env python3\n' > "$target_dir/.agent/scripts/repo-context.py"
	printf '#!/usr/bin/env python3\n' > "$target_dir/.agent/scripts/change-impact.py"
	printf '#!/usr/bin/env python3\n' > "$target_dir/.agent/scripts/generated-file-guard.py"
	printf '#!/usr/bin/env python3\n' > "$target_dir/.agent/scripts/markdown-claims.py"
}

test_preview_does_not_write() {
	local target_dir="$TEST_ROOT/preview"
	local output="$TEST_ROOT/preview.md"
	create_node_project "$target_dir"

	run_init "$target_dir" > "$output"

	assert_not_file "$target_dir/WORKSPACE.md"
	assert_contains "$output" "Primary stack: Vue"
	assert_contains "$output" "Package manager: Bun (detected from \`bun.lock\`)"
	assert_contains "$output" "Runtime requirements: bun@1.2.0"
	assert_contains "$output" '- None detected.'
	assert_contains "$output" 'vitest.config.js'
	assert_contains "$output" 'test/playwright-ct.config.js'
	assert_contains "$output" '| Lint | `bun run lint:check` |'
	assert_contains "$output" '| Unit tests | `bun run test:unit:run` |'
	assert_contains "$output" '| Component tests | `bun run test:component` |'
	assert_contains "$output" '| End-to-end tests | `bun run test:e2e` |'
	assert_contains "$output" '| Build | `bun run build` |'
	assert_contains "$output" '| None detected |  |  |'
	assert_contains "$output" 'Project checks shims: Not detected.'
	assert_contains "$output" "## Package metadata"
	assert_contains "$output" '| Name | `example-app` |'
	assert_contains "$output" '| Private | `true` |'
	assert_contains "$output" "## Declared entry points"
	assert_contains "$output" '| `exports:.` | `./src/index.js` |'
	assert_contains "$output" '| `bin:example` | `./bin/example.js` |'
	assert_contains "$output" "## Continuous integration"
	assert_contains "$output" '`.github/workflows/ci.yml`'
	assert_not_contains "$output" "## File tree"
}

test_unit_script_falls_back_when_run_script_is_missing() {
	local target_dir="$TEST_ROOT/unit-fallback"
	local output="$TEST_ROOT/unit-fallback.md"
	mkdir -p "$target_dir"
	printf '{"scripts":{"test:unit":"vitest"},"packageManager":"bun@1.2.0"}\n' > "$target_dir/package.json"
	printf 'lock\n' > "$target_dir/bun.lock"

	run_init "$target_dir" > "$output"

	assert_contains "$output" '| Unit tests | `bun run test:unit` |'
	assert_not_contains "$output" '| Unit tests | `bun run test:unit:run` |'
}

test_write_creates_missing_manifest() {
	local target_dir="$TEST_ROOT/write"
	create_node_project "$target_dir"

	run_init "$target_dir" --write >/dev/null

	assert_file "$target_dir/WORKSPACE.md"
	assert_contains "$target_dir/WORKSPACE.md" "## Common checks"
}

test_existing_manifest_requires_force() {
	local target_dir="$TEST_ROOT/existing"
	create_node_project "$target_dir"
	printf 'custom\n' > "$target_dir/WORKSPACE.md"

	if run_init "$target_dir" --write >/dev/null 2>&1; then
		fail "Expected existing manifest write to fail without --force"
	fi

	assert_contains "$target_dir/WORKSPACE.md" "custom"
	run_init "$target_dir" --write --force >/dev/null
	assert_contains "$target_dir/WORKSPACE.md" "Workspace"
}

test_force_preserves_known_existing_values() {
	local target_dir="$TEST_ROOT/preserve"
	create_node_project "$target_dir"
	cat > "$target_dir/WORKSPACE.md" <<'EOF'
# Workspace

## Repo context

- Package manager: pnpm (manual)

## Diagnostics and checks

| Purpose | Command | Notes |
| --- | --- | --- |
| Unit test for one file | `pnpm vitest src/example.test.ts` | Manual command. |
EOF

	run_init "$target_dir" --write --force >/dev/null

	assert_contains "$target_dir/WORKSPACE.md" "pnpm (manual)"
	assert_contains "$target_dir/WORKSPACE.md" 'pnpm vitest src/example.test.ts'
	assert_contains "$target_dir/WORKSPACE.md" "Preserved from existing"
}

test_placeholders_do_not_override_detected_values() {
	local target_dir="$TEST_ROOT/placeholders"
	local output="$TEST_ROOT/placeholders.md"
	create_node_project "$target_dir"
	cat > "$target_dir/WORKSPACE.md" <<'EOF'
# Workspace

## Diagnostics and checks

| Purpose | Command | Notes |
| --- | --- | --- |
| Unit test for one file | `[command]` | Placeholder. |
| Lint changed files | `[unknown]` | Placeholder. |
EOF

	run_init "$target_dir" > "$output"

	assert_contains "$output" '| Unit tests | `bun run test:unit:run` |'
	assert_contains "$output" '| Lint | `bun run lint:check` |'
}

test_legacy_manifest_values_are_preserved() {
	local target_dir="$TEST_ROOT/legacy"
	create_node_project "$target_dir"
	cat > "$target_dir/AGENT_CAPABILITIES.md" <<'EOF'
# Project capabilities

## Repo context

- Package manager: pnpm (manual)
EOF

	run_init "$target_dir" --write >/dev/null

	assert_file "$target_dir/WORKSPACE.md"
	assert_contains "$target_dir/WORKSPACE.md" "pnpm (manual)"
	assert_contains "$target_dir/WORKSPACE.md" "Preserved from existing"
	assert_file "$target_dir/AGENT_CAPABILITIES.md"
}

test_library_with_dev_framework_dependency_keeps_library_stack() {
	local target_dir="$TEST_ROOT/javascript-library"
	local output="$TEST_ROOT/javascript-library.md"
	create_javascript_library_project "$target_dir"

	run_init "$target_dir" > "$output"

	assert_contains "$output" "Primary stack: JavaScript library"
}

test_xcode_project_detects_swift_paths() {
	local target_dir="$TEST_ROOT/xcode"
	local output="$TEST_ROOT/xcode.md"
	create_xcode_project "$target_dir"

	run_init "$target_dir" > "$output"

	assert_contains "$output" "Primary stack: Swift / Xcode app"
	assert_contains "$output" "Runtime requirements: Xcode; Swift"
	assert_contains "$output" 'Main source directories: `App/App`'
	assert_contains "$output" 'Configuration paths: `App/App.xcodeproj`, `App/App.xctestplan`'
	assert_contains "$output" 'Test paths: `App/AppTests`, `App/AppUITests`'
	assert_contains "$output" 'Documentation paths: `ARCHITECTURE.md`, `DESIGN.md`, `README.md`'
	assert_contains "$output" 'No `.boilersuit` generators detected.'
	assert_contains "$output" '1. nearby README/docs files'
}

test_nested_test_files_are_summarised() {
	local target_dir="$TEST_ROOT/nested-tests"
	local output="$TEST_ROOT/nested-tests.md"
	create_nested_test_project "$target_dir"

	run_init "$target_dir" > "$output"

	assert_contains "$output" 'Test paths: `src/**/*.spec.*`, `src/**/*.test.*`'
	assert_contains "$output" '1. `package.json`'
	assert_contains "$output" '2. nearby README/docs files'
}

test_config_overrides_detected_values() {
	local target_dir="$TEST_ROOT/config-overrides"
	local output="$TEST_ROOT/config-overrides.md"
	create_nested_test_project "$target_dir"
	cat > "$target_dir/.agent-workspace.json" <<'EOF'
{
	"primaryStack": "Sketch plugin",
	"runtimeRequirements": "Bun; Sketch",
	"sourceDirs": ["src"],
	"testPaths": ["src/**/*.test.js"],
	"configPaths": ["package.json"],
	"docPaths": ["README.md"],
	"architectureNotes": ["Requests enter through src/index.js."],
	"lookup": {
		"Add analyser": "`src/analyser`"
	},
	"keyFiles": {
		"`package.json`": "Package scripts and published metadata."
	},
	"commonChecks": {
		"Single test file": "bun run test src/analyser/index.test.js",
		"Unit tests": "bun run test:unit:run"
	}
}
EOF
	printf '# App\n' > "$target_dir/README.md"

	run_init "$target_dir" > "$output"

	assert_contains "$output" "Primary stack: Sketch plugin"
	assert_contains "$output" "Runtime requirements: Bun; Sketch"
	assert_contains "$output" 'Main source directories: `src`'
	assert_contains "$output" 'Documentation paths: `README.md`'
	assert_contains "$output" '| Single test file | `bun run test src/analyser/index.test.js` |'
	assert_contains "$output" '| Unit tests | `bun run test:unit:run` |'
	assert_contains "$output" "## Architecture notes"
	assert_contains "$output" "Requests enter through src/index.js."
	assert_contains "$output" "## Lookup"
	assert_contains "$output" '| Add analyser | `src/analyser` |'
	assert_contains "$output" "## Key files"
	assert_contains "$output" '| `package.json` | Package scripts and published metadata. |'
}

test_file_tree_is_opt_in() {
	local target_dir="$TEST_ROOT/tree"
	local output="$TEST_ROOT/tree.md"
	create_node_project "$target_dir"

	run_init "$target_dir" --tree-depth 1 > "$output"

	assert_contains "$output" "## File tree"
	assert_contains "$output" "Generated with depth 1."
}

test_diagnostics_guidance_discourages_direct_commands() {
	local target_dir="$TEST_ROOT/diagnostics"
	local output="$TEST_ROOT/diagnostics.md"
	create_project_with_diagnostics "$target_dir"

	run_init "$target_dir" > "$output"

	assert_contains "$output" '.agent/scripts/project-diagnostics.py --list'
	assert_contains "$output" 'project-checks --list'
	assert_contains "$output" '.agent/scripts/project-diagnostics.py --check <name>'
	assert_contains "$output" '.agent/scripts/project-diagnostics.py --check test:component --test-file <path>'
	assert_contains "$output" '.agent/scripts/repo-context.py  # invokes project-checks-repo-context'
	assert_contains "$output" '.agent/scripts/change-impact.py  # invokes project-checks-change-impact'
	assert_contains "$output" '.agent/scripts/generated-file-guard.py  # invokes project-checks-generated-file-guard'
	assert_contains "$output" '.agent/scripts/markdown-claims.py  # invokes project-checks-markdown-claims'
	assert_contains "$output" 'Run checks through these shims rather than direct package commands.'
	assert_contains "$output" 'Playwright-backed component checks require `--test-file <path>` or `--test-glob'
	assert_contains "$output" 'extract details from the returned log path'
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
	assert_not_file "$REPO_DIR/WORKSPACE.md"
}

test_preview_does_not_write
test_unit_script_falls_back_when_run_script_is_missing
test_write_creates_missing_manifest
test_existing_manifest_requires_force
test_force_preserves_known_existing_values
test_placeholders_do_not_override_detected_values
test_legacy_manifest_values_are_preserved
test_library_with_dev_framework_dependency_keeps_library_stack
test_xcode_project_detects_swift_paths
test_nested_test_files_are_summarised
test_config_overrides_detected_values
test_file_tree_is_opt_in
test_diagnostics_guidance_discourages_direct_commands
test_missing_package_scripts_leave_unknowns
test_repo_preview_uses_progress_file

printf '✓ init-workspace tests passed\n'
