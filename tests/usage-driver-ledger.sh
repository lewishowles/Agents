#!/usr/bin/env bash
# Prove the driver ledger against synthetic Case 1 and Case 2 Claude and Codex sessions.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures/usage-case-1"

output=$(
	cd "$REPO_DIR"
	CLAUDE_CONFIG_DIR="$FIXTURE_DIR/claude" \
	CODEX_HOME="$FIXTURE_DIR/codex" \
	python3 scripts/audit/usage.py --since 2026-08-01 --until 2026-08-01 2>&1
)
printf '%s\n' "$output" | tail -20

cd "$REPO_DIR"
python3 - <<'PY'
import json
from pathlib import Path


report_directory = Path(".agent/audits/usage")
report = json.loads((report_directory / "latest.json").read_text(encoding="utf-8"))
markdown = (report_directory / "latest.md").read_text(encoding="utf-8")

assert report["session_count"] == 2
assert report["driver_reconciliation"]["reconciles"] is True
assert report["driver_reconciliation"]["tool_call_count"] == 16
assert report["driver_reconciliation"]["attributed_count"] == 16
assert report["driver_reconciliation"]["unattributed_count"] == 0

sessions = {session["tool"]: session for session in report["sessions"]}
claude = sessions["Claude"]
codex = sessions["Codex"]

assert claude["tokens"] == {
	"cache_creation_input_tokens": 30,
	"cache_read_input_tokens": 45,
	"input_tokens": 150,
	"output_tokens": 65,
	"total_input_tokens": 225,
	"total_tokens": 290,
}
assert codex["tokens"] == {
	"cached_input_tokens": 30,
	"input_tokens": 120,
	"output_tokens": 45,
	"reasoning_output_tokens": 15,
	"total_tokens": 210,
}

for session in (claude, codex):
	assert session["tool_call_count"] == sum(row["count"] for row in session["driver_ledger"])
	assert session["tool_call_count"] == (9 if session["tool"] == "Claude" else 7)
	assert session["driver_reconciles"] is True
	assert all(row["method"] == "chars/4" for row in session["driver_ledger"])
	assert session["driver_ledger"] == sorted(
		session["driver_ledger"],
		key=lambda row: (-row["payload_estimate_tokens"], row["category"], row["key"]),
	)

claude_rows = {(row["category"], row["key"]): row for row in claude["driver_ledger"]}
codex_rows = {(row["category"], row["key"]): row for row in codex["driver_ledger"]}
assert claude_rows[("bash", "rg")]["count"] == 1
assert claude_rows[("read", "/fixture/claude/project/src/app.py")]["repeated"] is True
assert claude_rows[("edit", "/fixture/claude/project/src/app.py")]["repeated"] is True
assert claude_rows[("write", "/fixture/claude/project/src/config.py")]["count"] == 1
assert claude_rows[("skill", "code-style")]["count"] == 1
assert claude_rows[("hook", "progress-resume")]["count"] == 1
assert claude_rows[("tool", "Task")]["count"] == 1
assert codex_rows[("bash", "git")]["count"] == 1
assert codex_rows[("bash", "cat")]["count"] == 2
assert codex_rows[("edit", "/fixture/codex/project/src/app.py")]["count"] == 1
assert codex_rows[("tool", "spawn_agent")]["count"] == 1

for forbidden in (
	"SYNTHETIC_CLAUDE_HOOK_STDOUT_8F3C",
	"SYNTHETIC_CLAUDE_READ_RESULT_1A7E",
	"SYNTHETIC_CLAUDE_DELEGATION_RESULT_4C2B",
	"SYNTHETIC_CODEX_COMMAND_RESULT_6D9A",
	"SYNTHETIC_CODEX_DELEGATION_RESULT_3B1F",
	"SYNTHETIC_CODEX_MCP_RESULT_5E8D",
):
	assert forbidden not in markdown
	assert forbidden not in json.dumps(report)

assert "/fixture/claude/project/src/app.py" in markdown
assert "## Driver ledger (ranked aggregate)" in markdown
assert "## Driver ledger by session" in markdown
print("usage driver ledger Case 1: PASS")
PY

printf '%s\n' 'Running usage driver ledger Case 2'
CASE2_FIXTURE_DIR="$SCRIPT_DIR/fixtures/usage-case-2"
output=$(
	cd "$REPO_DIR"
	CLAUDE_CONFIG_DIR="$CASE2_FIXTURE_DIR/claude" \
	CODEX_HOME="$CASE2_FIXTURE_DIR/codex" \
	python3 scripts/audit/usage.py --since 2026-08-01 --until 2026-08-01 2>&1
)
printf '%s\n' "$output" | tail -20

cd "$REPO_DIR"
python3 - <<'PY'
import json
from pathlib import Path


report_directory = Path(".agent/audits/usage")
report = json.loads((report_directory / "latest.json").read_text(encoding="utf-8"))

assert report["session_count"] == 2
assert report["driver_reconciliation"]["tool_call_count"] == 5
assert report["driver_reconciliation"]["attributed_count"] == 5
assert report["driver_reconciliation"]["unattributed_count"] == 0
assert report["driver_reconciliation"]["reconciles"] is True

sessions = {session["tool"]: session for session in report["sessions"]}
claude = sessions["Claude"]
codex = sessions["Codex"]
claude_rows = {(row["category"], row["key"]): row for row in claude["driver_ledger"]}
codex_rows = {(row["category"], row["key"]): row for row in codex["driver_ledger"]}

assert claude["tool_call_count"] == 4
assert claude["driver_reconciles"] is True
assert claude["tokens"]["total_tokens"] == 42
assert "payload_estimate_tokens" not in claude["tokens"]
assert claude["driver_ledger"] == sorted(
	claude["driver_ledger"],
	key=lambda row: (-row["payload_estimate_tokens"], row["category"], row["key"]),
)
assert claude_rows[("bash", "rg")]["count"] == 2
assert claude_rows[("bash", "rg")]["failure_count"] == 1
assert claude_rows[("bash", "rg")]["retry_count"] == 1
assert claude_rows[("read", "/fixture/claude/project/src/app.py")]["count"] == 2
assert claude_rows[("read", "/fixture/claude/project/src/app.py")]["failure_count"] == 1
assert claude_rows[("read", "/fixture/claude/project/src/app.py")]["retry_count"] == 1

assert codex["tool_call_count"] == 1
assert codex["driver_reconciles"] is True
assert codex_rows[("bash", "rg")]["failure_count"] == 0
assert codex_rows[("bash", "rg")]["retry_count"] == 0

aggregate_rows = {(row["category"], row["key"]): row for row in report["driver_ledger"]}
assert aggregate_rows[("bash", "rg")]["count"] == 3
assert aggregate_rows[("bash", "rg")]["failure_count"] == 1
assert aggregate_rows[("bash", "rg")]["retry_count"] == 1
assert aggregate_rows[("read", "/fixture/claude/project/src/app.py")]["count"] == 2
assert aggregate_rows[("read", "/fixture/claude/project/src/app.py")]["failure_count"] == 1
assert aggregate_rows[("read", "/fixture/claude/project/src/app.py")]["retry_count"] == 1

for session in (claude, codex):
	assert session["tool_call_count"] == sum(row["count"] for row in session["driver_ledger"])
	assert all(row["method"] == "chars/4" for row in session["driver_ledger"])
	assert all(row["payload_estimate_tokens"] > 0 for row in session["driver_ledger"])

assert report["driver_ledger"] == sorted(
	report["driver_ledger"],
	key=lambda row: (-row["payload_estimate_tokens"], row["category"], row["key"]),
)
assert report["driver_ledger"]
assert all("payload_estimate_tokens" in row for row in report["driver_ledger"])
print("usage driver ledger Case 2: PASS")
PY
