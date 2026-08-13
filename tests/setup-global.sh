#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TEST_ROOT=$(mktemp -d)

source "$SCRIPT_DIR/lib/test-helpers.sh"

trap cleanup EXIT

# Creates command stubs so setup-global can run against an isolated home
# without installing dependencies, synchronising output, or changing Git.
#
# @param  {string}  bin_dir
#     Directory that receives the test commands.
create_command_stubs() {
	local bin_dir="$1"

	mkdir -p "$bin_dir"

	cat > "$bin_dir/bash" <<'EOF'
#!/bin/sh
case "$1" in
	"$SETUP_GLOBAL_INSTALLER"|"$SETUP_GLOBAL_SYNC") exit 0 ;;
esac
exec /bin/bash "$@"
EOF

	cat > "$bin_dir/cli-style" <<'EOF'
#!/bin/sh
if [ "$1" = "adapter-path" ]; then
	printf '%s\n' "$SETUP_GLOBAL_TEST_ADAPTER"
	fi
EOF

	cat > "$bin_dir/cp" <<'EOF'
#!/bin/sh
if [ "$1" = "-R" ]; then
	mkdir -p "$3"
	exit 0
fi
exec /bin/cp "$@"
EOF

	cat > "$bin_dir/mv" <<'EOF'
#!/bin/sh
if [ "${SETUP_GLOBAL_TEST_FAIL_BACKUP_MOVE:-0}" = "1" ]; then
	printf 'backup move failed\n' >&2
	exit 1
fi
exec /bin/mv "$@"
EOF

	cat > "$bin_dir/git" <<'EOF'
#!/bin/sh
exit 0
EOF

	cat > "$bin_dir/cli-style-adapter.sh" <<'EOF'
#!/bin/bash
cli_style_render() {
	cat >/dev/null
}
EOF

	chmod +x "$bin_dir/bash" "$bin_dir/cli-style" "$bin_dir/cp" "$bin_dir/mv" "$bin_dir/git" "$bin_dir/cli-style-adapter.sh"
}

# Creates a Codex configuration that setup-global must replace.
#
# @param  {string}  home_dir
#     Isolated home directory for one setup run.
create_existing_config() {
	local home_dir="$1"

	mkdir -p "$home_dir/.codex"
	printf 'custom_setting = "keep"\n' > "$home_dir/.codex/config.toml"
}

# Runs the global setup in a temporary home with test-only command stubs.
#
# @param  {string}  home_dir
#     Isolated home directory for the setup run.
# @param  {string}  ...
#     Additional setup-global arguments.
run_setup() {
	local home_dir="$1"
	local bin_dir="$TEST_ROOT/bin"
	local fail_backup_move="${SETUP_GLOBAL_TEST_FAIL_BACKUP_MOVE:-0}"
	shift

	HOME="$home_dir" \
	PATH="$bin_dir:$PATH" \
	CLI_STYLE_BIN="$bin_dir/cli-style" \
	SETUP_GLOBAL_INSTALLER="$REPO_DIR/scripts/install-cli-style.sh" \
	SETUP_GLOBAL_SYNC="$REPO_DIR/scripts/sync.sh" \
	SETUP_GLOBAL_TEST_ADAPTER="$bin_dir/cli-style-adapter.sh" \
	SETUP_GLOBAL_TEST_FAIL_BACKUP_MOVE="$fail_backup_move" \
	bash "$REPO_DIR/scripts/setup-global.sh" --codex --skip-external "$@"
}

# Asserts that setup-global preserved the old configuration in a timestamped backup.
#
# @param  {string}  home_dir
#     Isolated home directory inspected after setup.
assert_timestamped_backup() {
	local home_dir="$1"
	local backups=("$home_dir/.codex/config.toml.bak."*)

	assert_file "${backups[0]}"
	assert_equals "$(cat "${backups[0]}")" 'custom_setting = "keep"'
}

test_help_hides_backup_bypass() {
	local output="$TEST_ROOT/help.txt"

	/bin/bash "$REPO_DIR/scripts/setup-global.sh" --help > "$output"

	assert_not_contains "$output" "--no-backup"
}

test_public_backup_bypass_is_rejected() {
	local home_dir="$TEST_ROOT/no-backup"
	local output="$TEST_ROOT/no-backup.txt"

	create_existing_config "$home_dir"
	if run_setup "$home_dir" --no-backup > "$output" 2>&1; then
		fail "Expected --no-backup to be rejected"
	fi

	assert_contains "$output" "Usage:"
	assert_equals "$(cat "$home_dir/.codex/config.toml")" 'custom_setting = "keep"'
}

test_config_replacement_creates_timestamped_backup() {
	local home_dir="$TEST_ROOT/backup"

	create_existing_config "$home_dir"
	run_setup "$home_dir" > /dev/null

	assert_timestamped_backup "$home_dir"
	assert_contains "$home_dir/.codex/config.toml" 'approval_policy = "never"'
	assert_contains "$home_dir/.codex/config.toml" '[mcp_servers.codebase-memory-mcp]'
	assert_contains "$home_dir/.codex/config.toml" '[mcp_servers.serena]'
	assert_equals "$(grep -c '^default_tools_approval_mode = \"approve\"$' "$home_dir/.codex/config.toml")" "2"
	assert_contains "$home_dir/.codex/config.toml" '[features]'
	assert_contains "$home_dir/.codex/config.toml" 'hooks = true'
	assert_contains "$home_dir/.codex/config.toml" 'writable_roots = ["'"$home_dir"'/Dev/Configuration/Agents", "'"$home_dir"'/.Trash"]'
	assert_not_contains "$home_dir/.codex/config.toml" '[[hooks.'
	assert_link "$home_dir/.codex/hooks.json"
	assert_link "$home_dir/.codex/hooks/tool-call-checkpoint.sh"
	assert_link "$home_dir/.codex/hooks/guard-hcom-ack.sh"
}

test_hook_file_is_replaced_with_managed_link() {
	local home_dir="$TEST_ROOT/legacy-hooks"
	local backups

	create_existing_config "$home_dir"
	printf '{"hooks": {}}\n' > "$home_dir/.codex/hooks.json"
	run_setup "$home_dir" > /dev/null

	backups=("$home_dir/.codex/hooks.json.bak."*)
	assert_file "${backups[0]}"
	assert_link "$home_dir/.codex/hooks.json"
	assert_equals "$(readlink "$home_dir/.codex/hooks.json")" "$REPO_DIR/dist/codex/hooks.json"
	assert_not_contains "$home_dir/.codex/config.toml" '[[hooks.'
}

test_workspace_network_access_is_enabled() {
	local home_dir="$TEST_ROOT/workspace-network"

	create_existing_config "$home_dir"
	printf '\n[sandbox_workspace_write]\nnetwork_access = false\nexclude_slash_tmp = true\nwritable_roots = ["/tmp/keep"]\n' >> "$home_dir/.codex/config.toml"
	run_setup "$home_dir" > /dev/null

	assert_contains "$home_dir/.codex/config.toml" '[sandbox_workspace_write]'
	assert_contains "$home_dir/.codex/config.toml" 'network_access = true'
	assert_not_contains "$home_dir/.codex/config.toml" 'network_access = false'
	assert_contains "$home_dir/.codex/config.toml" 'exclude_slash_tmp = true'
	assert_contains "$home_dir/.codex/config.toml" 'writable_roots = ["/tmp/keep", "'"$home_dir"'/Dev/Configuration/Agents", "'"$home_dir"'/.Trash"]'
}

test_skip_backup_environment_does_not_bypass_backup() {
	local home_dir="$TEST_ROOT/skip-backup-environment"

	create_existing_config "$home_dir"
	SKIP_BACKUP=1 run_setup "$home_dir" > /dev/null

	assert_timestamped_backup "$home_dir"
}

test_failed_backup_preserves_existing_config() {
	local home_dir="$TEST_ROOT/backup-failure"
	local output="$TEST_ROOT/backup-failure.txt"

	create_existing_config "$home_dir"
	if SETUP_GLOBAL_TEST_FAIL_BACKUP_MOVE=1 run_setup "$home_dir" > "$output" 2>&1; then
		fail "Expected a failed backup to abort setup"
	fi

	assert_contains "$output" "backup move failed"
	assert_equals "$(cat "$home_dir/.codex/config.toml")" 'custom_setting = "keep"'
}

create_command_stubs "$TEST_ROOT/bin"

test_help_hides_backup_bypass
test_public_backup_bypass_is_rejected
test_config_replacement_creates_timestamped_backup
test_hook_file_is_replaced_with_managed_link
test_workspace_network_access_is_enabled
test_skip_backup_environment_does_not_bypass_backup
test_failed_backup_preserves_existing_config

printf '✓ setup-global backup tests passed\n'
