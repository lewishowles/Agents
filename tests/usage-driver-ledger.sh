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
	python3 scripts/audit/token_usage_report.py --since 2026-08-01 --until 2026-08-01 2>&1
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
	python3 scripts/audit/token_usage_report.py --since 2026-08-01 --until 2026-08-01 2>&1
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

printf '%s\n' 'Running usage partial-data Case 3'
CASE3_FIXTURE_DIR="$SCRIPT_DIR/fixtures/usage-case-3"
output=$(
	cd "$REPO_DIR"
	CLAUDE_CONFIG_DIR="$CASE3_FIXTURE_DIR/claude" \
	CODEX_HOME="$CASE3_FIXTURE_DIR/codex" \
	python3 scripts/audit/token_usage_report.py --since 2026-08-01 --until 2026-08-01 2>&1
)
printf '%s\n' "$output" | tail -20

cd "$REPO_DIR"
python3 - <<'PY'
import json
from pathlib import Path


report_directory = Path(".agent/audits/usage")
report = json.loads((report_directory / "latest.json").read_text(encoding="utf-8"))
markdown = (report_directory / "latest.md").read_text(encoding="utf-8")

assert report["session_count"] == 4
assert report["partial_data"] == {
	"partial": True,
	"skipped_record_count": 8,
	"skipped_record_counts": {"Claude": 4, "Codex": 4},
}

sessions = {(session["tool"], session["session_id"]): session for session in report["sessions"]}
assert sessions[("Claude", "claude-case-3")]["tokens"]["total_tokens"] == 28
assert sessions[("Claude", "claude-case-3")]["skipped_record_count"] == 2
assert sessions[("Codex", "codex-case-3")]["tokens"]["total_tokens"] == 38
assert sessions[("Codex", "codex-case-3")]["skipped_record_count"] == 2
assert sessions[("Claude", "claude-case-3-skipped-only")]["tokens"]["total_tokens"] == 0
assert sessions[("Claude", "claude-case-3-skipped-only")]["skipped_record_count"] == 2
assert sessions[("Codex", "codex-case-3-skipped-only")]["tokens"]["total_tokens"] == 0
assert sessions[("Codex", "codex-case-3-skipped-only")]["skipped_record_count"] == 2
assert "## Partial data" in markdown
assert "Skipped records: **8**" in markdown
assert "| Claude | 4 |" in markdown
assert "| Codex | 4 |" in markdown
print("usage partial-data Case 3: PASS")
PY

printf '%s\n' 'Running usage correctness regressions'
cd "$REPO_DIR"
python3 - <<'PY'
import json
import tempfile
from pathlib import Path
from unittest.mock import patch

from scripts.audit import token_usage_report


with tempfile.TemporaryDirectory() as temporary_directory:
	missing_path = Path(temporary_directory) / "missing.jsonl"
	try:
		list(token_usage_report.records(missing_path, token_usage_report.CLAUDE_RECORD_TYPES, {"skipped_record_count": 0}))
	except FileNotFoundError:
		pass
	else:
		raise AssertionError("missing transcript reads must raise FileNotFoundError")


parsed_usage = json.loads(
	'{"input_tokens": 3.9, "cached_input_tokens": NaN, '
	'"reasoning_output_tokens": Infinity, "output_tokens": -Infinity, '
	'"total_tokens": Infinity}'
)
assert token_usage_report.usage_totals(parsed_usage, "Codex") == {
	"input_tokens": 3,
	"cached_input_tokens": 0,
	"reasoning_output_tokens": 0,
	"output_tokens": 0,
	"total_tokens": 3,
}
assert token_usage_report.number(float("nan")) == 0
assert token_usage_report.number(float("inf")) == 0
assert token_usage_report.number(float("-inf")) == 0


class FakeQuery:
	def fetchall(self):
		return []


class FakeConnection:
	def __init__(self, query_error=False):
		self.query_error = query_error
		self.closed = False

	def execute(self, query):
		if self.query_error:
			raise token_usage_report.sqlite3.OperationalError("synthetic query failure")

		return FakeQuery()

	def close(self):
		self.closed = True


with tempfile.TemporaryDirectory() as temporary_directory:
	database_path = Path(temporary_directory) / "hcom.db"
	database_path.touch()
	previous_database = token_usage_report.HCOM_DATABASE
	token_usage_report.HCOM_DATABASE = database_path
	try:
		success_connection = FakeConnection()
		with patch.object(token_usage_report.sqlite3, "connect", return_value=success_connection):
			assert token_usage_report.load_hcom_labels() == ({}, {})
		assert success_connection.closed

		error_connection = FakeConnection(query_error=True)
		with patch.object(token_usage_report.sqlite3, "connect", return_value=error_connection):
			assert token_usage_report.load_hcom_labels() == ({}, {})
		assert error_connection.closed
	finally:
		token_usage_report.HCOM_DATABASE = previous_database

print("usage correctness regressions: PASS")
PY
