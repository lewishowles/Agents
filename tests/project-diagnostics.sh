#!/usr/bin/env bash
# Tests the shared project diagnostics command against small mock projects.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)

source "$SCRIPT_DIR/lib/test-helpers.sh"

trap cleanup EXIT

# Writes a minimal Xcode project file for diagnostics discovery tests.
#
# @param  {string}  project_dir
#     Project root that should contain App.xcodeproj.
# @param  {string}  body
#     PBX objects body to write.
write_xcode_project() {
	local project_dir="$1"
	local body="$2"

	mkdir -p "$project_dir/App.xcodeproj"
	printf '// !$*UTF8*$!\n{\n\tobjects = {\n%b\n\t};\n}\n' "$body" > "$project_dir/App.xcodeproj/project.pbxproj"
}

# Writes a Bun project whose Playwright executable records the received arguments.
#
# @param  {string}  project_dir
#     Project root to populate.
write_fake_playwright_project() {
	local project_dir="$1"

	mkdir -p "$project_dir/node_modules/.bin" "$project_dir/src/components"
	printf '{"packageManager":"bun@1.2.0","scripts":{"test:component":"playwright test -c test/playwright-ct.config.js --project=chromium"}}\n' > "$project_dir/package.json"
	printf 'lock\n' > "$project_dir/bun.lock"
	printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" > component-test-args\n' > "$project_dir/node_modules/.bin/playwright"
	chmod +x "$project_dir/node_modules/.bin/playwright"
	printf 'test\n' > "$project_dir/src/components/ui-button.pw.js"
}

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

test_scoped_playwright_component_tests() {
	local targeted_dir="$TEST_ROOT/scoped-component"
	local unscoped_dir="$TEST_ROOT/unscoped-component"
	local all_dir="$TEST_ROOT/all-component"
	local output="$TEST_ROOT/scoped-component.md"
	local error_output="$TEST_ROOT/unscoped-component.txt"
	local all_output="$TEST_ROOT/all-component.md"
	local expected_arguments="$TEST_ROOT/scoped-component-arguments.txt"

	write_fake_playwright_project "$targeted_dir"
	write_fake_playwright_project "$unscoped_dir"
	write_fake_playwright_project "$all_dir"

	"$REPO_DIR/scripts/project-diagnostics.py" \
		--project "$targeted_dir" \
		--check test:component \
		--test-file src/components/ui-button.pw.js > "$output"

	printf 'test\n-c\ntest/playwright-ct.config.js\n--project=chromium\n--workers=1\nsrc/components/ui-button.pw.js\n' > "$expected_arguments"
	if ! diff -u "$expected_arguments" "$targeted_dir/component-test-args"; then
		fail "Expected targeted Playwright arguments"
	fi
	assert_contains "$output" "| test:component | passed |"

	if "$REPO_DIR/scripts/project-diagnostics.py" \
		--project "$unscoped_dir" \
		--check test:component > "$error_output" 2>&1; then
		fail "Expected unscoped Playwright component check to be rejected"
	fi
	assert_contains "$error_output" "test:component requires --test-file or --test-glob"
	assert_not_exists "$unscoped_dir/component-test-args"

	"$REPO_DIR/scripts/project-diagnostics.py" --project "$all_dir" --all > "$all_output"

	assert_contains "$all_output" "test:component: requires --test-file or --test-glob and is excluded from --all"
	assert_not_exists "$all_dir/component-test-args"
}

test_xcode_cli_targets_are_discovered() {
	local single_target_dir="$TEST_ROOT/xcode-cli-single"
	local multiple_target_dir="$TEST_ROOT/xcode-cli-multiple"
	local app_only_dir="$TEST_ROOT/xcode-cli-none"
	local single_output="$TEST_ROOT/xcode-cli-single.md"
	local multiple_output="$TEST_ROOT/xcode-cli-multiple.md"
	local app_only_output="$TEST_ROOT/xcode-cli-none.md"

	write_xcode_project "$single_target_dir" '
		ABC123 /* App */ = {
			isa = PBXNativeTarget;
			name = App;
			productType = "com.apple.product-type.application";
		};
		DEF456 /* boilersuit */ = {
			isa = PBXNativeTarget;
			name = boilersuit;
			productType = "com.apple.product-type.tool";
		};'

	"$REPO_DIR/scripts/project-diagnostics.py" --project "$single_target_dir" --list > "$single_output"

	assert_contains "$single_output" "| build:cli | \`xcodebuild build -project App.xcodeproj -target boilersuit -destination platform=macOS,arch=arm64\` |"
	assert_not_contains "$single_output" "build:cli:"

	write_xcode_project "$multiple_target_dir" '
		ABC123 /* boilersuit */ = {
			isa = PBXNativeTarget;
			name = boilersuit;
			productType = "com.apple.product-type.tool";
		};
		DEF456 /* Boiler Helper */ = {
			isa = PBXNativeTarget;
			name = "Boiler Helper";
			productType = "com.apple.product-type.tool";
		};'

	"$REPO_DIR/scripts/project-diagnostics.py" --project "$multiple_target_dir" --list > "$multiple_output"

	assert_not_contains "$multiple_output" "| build:cli |"
	assert_contains "$multiple_output" "| build:cli:boiler-helper |"
	assert_contains "$multiple_output" "| build:cli:boilersuit |"

	write_xcode_project "$app_only_dir" '
		ABC123 /* App */ = {
			isa = PBXNativeTarget;
			name = App;
			productType = "com.apple.product-type.application";
		};'

	"$REPO_DIR/scripts/project-diagnostics.py" --project "$app_only_dir" --list > "$app_only_output"

	assert_not_contains "$app_only_output" "build:cli"
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
test_scoped_playwright_component_tests
test_xcode_cli_targets_are_discovered
test_scoped_xcode_unit_test_files_and_globs
test_scoped_unit_tests_reject_unsafe_targets

printf '✓ project-diagnostics tests passed\n'
