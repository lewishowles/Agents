#!/usr/bin/env bash
# Tests the shared project diagnostics command against small mock projects.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)

source "$SCRIPT_DIR/lib/test-helpers.sh"

trap cleanup EXIT

test_local_validate_script() {
	local target_dir="$TEST_ROOT/with-validate"
	local list_output="$TEST_ROOT/with-validate-list.md"
	local output="$TEST_ROOT/with-validate.md"
	mkdir -p "$target_dir/scripts"

	printf '#!/usr/bin/env bash\nprintf "validation ok\\n"\n' > "$target_dir/scripts/validate.sh"
	chmod +x "$target_dir/scripts/validate.sh"

	"$REPO_DIR/scripts/project-diagnostics.py" --project "$target_dir" > "$list_output"

	assert_contains "$list_output" "Mode: list only. No checks were run."
	assert_contains "$list_output" "| validate | \`bash scripts/validate.sh\` |"
	assert_not_exists "$target_dir/.agent/diagnostics"

	"$REPO_DIR/scripts/project-diagnostics.py" --project "$target_dir" --check validate > "$output"

	assert_contains "$output" "Project diagnostics"
	assert_contains "$output" "| validate | passed |"
	assert_contains "$output" "validation ok"
	assert_dir "$target_dir/.agent/diagnostics"
}

test_json_skipped_when_no_safe_checks() {
	local target_dir="$TEST_ROOT/no-checks"
	local output="$TEST_ROOT/no-checks.json"
	mkdir -p "$target_dir"

	"$REPO_DIR/scripts/project-diagnostics.py" --project "$target_dir" --json --list > "$output"

	assert_contains "$output" '"mode": "list"'
	assert_contains "$output" '"checks": []'
	assert_contains "$output" "no conservative diagnostics command found"
}

test_scoped_unit_test_files_and_globs() {
	local target_dir="$TEST_ROOT/scoped-unit"
	local output="$TEST_ROOT/scoped-unit.md"
	mkdir -p "$target_dir/src/components"

	printf '{"scripts":{"test:unit":"node test-runner.js"}}\n' > "$target_dir/package.json"
	printf 'const files = process.argv.slice(2); console.log(files.join("\\n"));\n' > "$target_dir/test-runner.js"
	printf 'test\n' > "$target_dir/src/example.test.js"
	printf 'test\n' > "$target_dir/src/components/button.test.js"

	"$REPO_DIR/scripts/project-diagnostics.py" \
		--project "$target_dir" \
		--check test:unit \
		--test-file src/example.test.js \
		--test-glob 'src/components/*.test.js' > "$output"

	assert_contains "$output" "| test:unit | passed |"
	assert_contains "$output" "src/example.test.js"
	assert_contains "$output" "src/components/button.test.js"
}

test_scoped_xcode_unit_test_files_and_globs() {
	local target_dir="$TEST_ROOT/scoped-xcode-unit"
	local output="$TEST_ROOT/scoped-xcode-unit.md"
	mkdir -p "$target_dir/bin" "$target_dir/Boilersuit.xcodeproj" "$target_dir/BoilersuitTests/Rendering"

	printf '#!/usr/bin/env bash\nprintf "xcodebuild mock\\n"\n' > "$target_dir/bin/xcodebuild"
	chmod +x "$target_dir/bin/xcodebuild"
	printf 'test\n' > "$target_dir/BoilersuitTests/TemplateEngineTests.swift"
	printf 'test\n' > "$target_dir/BoilersuitTests/Rendering/PreviewTests.swift"

	PATH="$target_dir/bin:$PATH" "$REPO_DIR/scripts/project-diagnostics.py" \
		--project "$target_dir" \
		--check test:unit \
		--test-file BoilersuitTests/TemplateEngineTests.swift \
		--test-glob 'BoilersuitTests/Rendering/*.swift' > "$output"

	assert_contains "$output" "| test:unit | passed |"
	assert_contains "$output" "-only-testing:BoilersuitTests/PreviewTests"
	assert_contains "$output" "-only-testing:BoilersuitTests/TemplateEngineTests"
	assert_not_contains "$output" "-- BoilersuitTests/"

	printf 'test\n' > "$target_dir/BoilersuitTests/README.md"
	if PATH="$target_dir/bin:$PATH" "$REPO_DIR/scripts/project-diagnostics.py" \
		--project "$target_dir" \
		--check test:unit \
		--test-file BoilersuitTests/README.md > "$output" 2>&1; then
		fail "Expected a non-Swift Xcode test file to be rejected"
	fi
	assert_contains "$output" "Xcode test file must be a Swift source file"

	mkdir -p "$target_dir/Support"
	printf 'test\n' > "$target_dir/Support/TestHelpers.swift"
	if PATH="$target_dir/bin:$PATH" "$REPO_DIR/scripts/project-diagnostics.py" \
		--project "$target_dir" \
		--check test:unit \
		--test-file Support/TestHelpers.swift > "$output" 2>&1; then
		fail "Expected an Xcode test file outside a test target directory to be rejected"
	fi
	assert_contains "$output" "Xcode test file must be inside a directory ending in Tests"
}

test_scoped_unit_tests_reject_unsafe_targets() {
	local target_dir="$TEST_ROOT/rejected-targets"
	local output="$TEST_ROOT/rejected-targets.txt"
	mkdir -p "$target_dir"

	printf '{"scripts":{"test:unit":"node test-runner.js","lint":"node test-runner.js"}}\n' > "$target_dir/package.json"
	printf 'console.log("ran");\n' > "$target_dir/test-runner.js"

	if "$REPO_DIR/scripts/project-diagnostics.py" \
		--project "$target_dir" \
		--check test:unit \
		--test-file ../outside.test.js > "$output" 2>&1; then
		fail "Expected an outside-project test file to be rejected"
	fi
	assert_contains "$output" "test file must stay inside the project"

	if "$REPO_DIR/scripts/project-diagnostics.py" \
		--project "$target_dir" \
		--check test:unit \
		--test-glob 'src/**/*.test.js' > "$output" 2>&1; then
		fail "Expected an unmatched test glob to be rejected"
	fi
	assert_contains "$output" "test glob matched no files"

	if "$REPO_DIR/scripts/project-diagnostics.py" \
		--project "$target_dir" \
		--check lint \
		--test-file test-runner.js > "$output" 2>&1; then
		fail "Expected test targeting on a non-test check to be rejected"
	fi
	assert_contains "$output" "check does not support test targets: lint"
}

test_local_validate_script
test_json_skipped_when_no_safe_checks
test_scoped_unit_test_files_and_globs
test_scoped_xcode_unit_test_files_and_globs
test_scoped_unit_tests_reject_unsafe_targets

printf '✓ project-diagnostics tests passed\n'
