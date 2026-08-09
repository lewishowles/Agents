#!/usr/bin/env python3
"""Extract deterministic, evidence-only insights from Codex rollout files."""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parents[4]
if str(REPO_ROOT) not in sys.path:
	 sys.path.insert(0, str(REPO_ROOT))

from scripts.audit.corrections import matches_correction  # noqa: E402
from scripts.audit.token_usage_report import (  # noqa: E402
	CODEX_RECORD_TYPES,
	aggregate_codex_usage,
	codex_usage_event,
	new_session,
	parse_timestamp,
	process_codex_response_item,
	records,
	transcript_paths,
	update_codex_metadata,
)

CODEX_HOME = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex").expanduser()
OUTPUT_PATH = CODEX_HOME / "usage-data/latest.json"
UTC = datetime.timezone.utc
FAILURE_CATEGORIES = (
	"permission",
	"timeout",
	"not-found",
	"validation",
	"network",
	"process-exit",
	"other",
)
TERMINAL_EVENT_TYPES = {"task_complete", "turn_aborted"}
PROCESS_EXIT_PATTERN = re.compile(
	r"\b(?:exit(?:ed)?|exit_code|return(?:ed)?|status(?:_code)?)\b[^\d\n]*[1-9]\d*\b",
	re.IGNORECASE,
)
FAILURE_MARKERS = (
	"error",
	"failed",
	"failure",
	"exception",
	"traceback",
	"fatal",
	"permission denied",
	"timed out",
	"timeout",
	"not found",
	"invalid",
	"validation",
	"network",
	"connection refused",
	"connection reset",
	"process exited",
	"exit code",
)
FAILURE_CATEGORY_MARKERS = {
	"permission": ("permission denied", "access denied", "not permitted"),
	"timeout": ("timed out", "timeout", "time out"),
	"not-found": (
		"command not found",
		"file not found",
		"no such file",
		"not found",
	),
	"validation": (
		"validation",
		"invalid",
		"schema error",
		"argument error",
	),
	"network": (
		"network",
		"connection refused",
		"connection reset",
		"could not resolve",
		"dns",
		"unreachable",
	),
	"process-exit": (
		"process exited",
		"non-zero exit",
		"exit code",
		"exit status",
	),
}


def parse_bound(value: str) -> datetime.datetime:
	"""Parse a command-line value as an ISO-8601 UTC timestamp."""
	timestamp = parse_timestamp(value)
	if timestamp is None:
		raise argparse.ArgumentTypeError(
			"expected an ISO-8601 UTC timestamp, for example 2026-08-09T00:00:00Z"
		)

	return timestamp


def format_timestamp(timestamp: datetime.datetime | None) -> str | None:
	"""Return one timestamp in canonical UTC JSON form, or null when absent."""
	if timestamp is None:
		return None

	return timestamp.astimezone(UTC).isoformat().replace("+00:00", "Z")


def in_window(
	timestamp: datetime.datetime | None,
	start: datetime.datetime,
	end: datetime.datetime,
) -> bool:
	"""Return whether a timestamp belongs to the half-open UTC window."""
	return timestamp is not None and start <= timestamp < end


def payload_for(record: dict[str, object]) -> dict[str, object]:
	"""Return a response or event payload object when one is present."""
	payload = record.get("payload")
	return payload if isinstance(payload, dict) else {}


def record_type(record: dict[str, object]) -> str:
	"""Return the nested event type, or an empty string when unavailable."""
	payload = payload_for(record)
	value = payload.get("type")
	return value if isinstance(value, str) else ""


def evidence_text(value: object) -> str:
	"""Convert tool output into a comparable text form."""
	if isinstance(value, str):
		return value

	try:
		return json.dumps(value, ensure_ascii=False, sort_keys=True, default=str)
	except (TypeError, ValueError):
		return str(value)


def message_text(payload: dict[str, object]) -> str:
	"""Extract visible text from one canonical response-item message."""
	content = payload.get("content")
	if isinstance(content, str):
		return content.strip()

	if not isinstance(content, list):
		return ""

	parts = []
	for block in content:
		if isinstance(block, str):
			parts.append(block)
		elif isinstance(block, dict) and isinstance(block.get("text"), str):
			parts.append(block["text"])

	return " ".join(parts).strip()


def failure_category(output: object) -> str | None:
	"""Classify a failed tool output using ordered evidence markers."""
	text = evidence_text(output).casefold()
	if not text:
		return None

	if not any(marker in text for marker in FAILURE_MARKERS) and not PROCESS_EXIT_PATTERN.search(
		text
	):
		return None

	for category in FAILURE_CATEGORIES:
		if category == "other":
			continue
		markers = FAILURE_CATEGORY_MARKERS[category]
		if any(marker in text for marker in markers):
			return category

	if PROCESS_EXIT_PATTERN.search(text):
		return "process-exit"

	return "other"


def empty_failed_tool_counts() -> dict[str, int]:
	"""Return all failed-tool categories with explicit zero counts."""
	return {category: 0 for category in FAILURE_CATEGORIES}


def string_value(value: object) -> str | None:
	"""Return a non-empty string value, preserving unavailable values as null."""
	return value if isinstance(value, str) and value else None


def read_session_index() -> dict[str, str]:
	"""Read the optional id-to-thread-name Codex index join."""
	index_path = Path(os.environ.get("CODEX_HOME", "~/.codex")).expanduser() / "session_index.jsonl"
	thread_names = {}
	if not index_path.is_file():
		return thread_names

	with index_path.open(encoding="utf-8", errors="replace") as handle:
		for line in handle:
			try:
				record = json.loads(line)
			except (TypeError, ValueError):
				continue
			if not isinstance(record, dict):
				continue
			session_id = string_value(record.get("id"))
			thread_name = string_value(record.get("thread_name"))
			if session_id is not None and thread_name is not None:
				thread_names[session_id] = thread_name

	return thread_names


def read_rollout_records(path: Path) -> list[dict[str, object]]:
	"""Read supported records through the shared JSONL parser."""
	record_stats = {"skipped_record_count": 0}
	return list(records(path, CODEX_RECORD_TYPES, record_stats))


def is_terminal_record(record: dict[str, object]) -> bool:
	"""Return whether one record marks a completed or aborted turn."""
	return record.get("type") in TERMINAL_EVENT_TYPES or record_type(record) in TERMINAL_EVENT_TYPES


def extract_session(
	path: Path,
	start: datetime.datetime,
	end: datetime.datetime,
	thread_names: dict[str, str],
) -> dict[str, object] | None:
	"""Return one session's window-scoped counts, or null when no record falls in the window.

	Session/git metadata is gathered from the whole rollout file, not just the window,
	since a session_meta record can fall outside the requested bounds.
	"""
	rollout_id = path.stem.removeprefix("rollout-")
	rollout_records = read_rollout_records(path)
	if not rollout_records:
		return None

	session_id = rollout_id
	project_path = None
	git = {"branch": None, "commit_hash": None, "repository_url": None}
	all_timestamps = []
	window_records = []
	last_valid_was_terminal = False

	for record in rollout_records:
		timestamp = parse_timestamp(record.get("timestamp"))
		if timestamp is None:
			continue
		all_timestamps.append(timestamp)
		last_valid_was_terminal = is_terminal_record(record)
		if in_window(timestamp, start, end):
			window_records.append((record, timestamp))

		if record.get("type") in ("session_meta", "turn_context"):
			source = payload_for(record)
			candidate_id = string_value(source.get("session_id")) or string_value(source.get("id"))
			if candidate_id is not None:
				session_id = candidate_id
			candidate_path = string_value(source.get("cwd"))
			if candidate_path is not None:
				project_path = candidate_path
			if record.get("type") == "session_meta":
				candidate_git = source.get("git")
				if isinstance(candidate_git, dict):
					for key in git:
						value = string_value(candidate_git.get(key))
						if value is not None:
							git[key] = value

	if not window_records:
		return None

	counts = {"user": 0, "assistant": 0}
	tool_call_count = 0
	first_user_prompt = None
	failed_tool_counts = empty_failed_tool_counts()
	correction_markers = []

	for record, timestamp in window_records:
		payload = payload_for(record)
		if record.get("type") != "response_item":
			continue

		response_type = payload.get("type")
		if response_type == "message":
			role = payload.get("role")
			if role in counts:
				counts[role] += 1
			if role == "user":
				text = message_text(payload)
				if first_user_prompt is None and text:
					first_user_prompt = text[:1200]
				if text and matches_correction(text):
					correction_markers.append(
						{
							"session_id": session_id,
							"timestamp": format_timestamp(timestamp),
							"text": text[:1200],
						}
					)
		elif response_type in ("custom_tool_call", "function_call"):
			tool_call_count += 1
		elif response_type in ("custom_tool_call_output", "function_call_output"):
			category = failure_category(payload.get("output"))
			if category is not None:
				failed_tool_counts[category] += 1

	shared_session = new_session(
		"Codex",
		session_id,
		path,
		project_path or "unknown",
	)
	model = "unknown"
	previous_total = None
	calls_by_id = {}
	token_event_seen = False
	for record in rollout_records:
		model = update_codex_metadata(shared_session, record, model)
		timestamp = parse_timestamp(record.get("timestamp"))
		process_codex_response_item(
			shared_session,
			calls_by_id,
			record,
			timestamp,
			start,
			end,
		)
		delta, previous_total = codex_usage_event(record, previous_total)
		if delta is not None:
			token_event_seen = True
		aggregate_codex_usage(
			shared_session,
			delta,
			model,
			timestamp,
			start,
			end,
		)

	all_timestamps.sort()
	start_timestamp = all_timestamps[0] if all_timestamps else None
	observed_end = all_timestamps[-1] if all_timestamps else None
	is_archived = "archived_sessions" in path.parts
	is_active = not is_archived and not last_valid_was_terminal
	end_timestamp = None if is_active else observed_end
	correction_markers.sort(key=lambda marker: (marker["timestamp"], marker["text"]))

	return {
		"session_id": session_id,
		"thread_name": thread_names.get(session_id),
		"project_path": project_path,
		"start_timestamp": format_timestamp(start_timestamp),
		"end_timestamp": format_timestamp(end_timestamp),
		"user_message_count": counts["user"],
		"assistant_message_count": counts["assistant"],
		"tool_call_count": tool_call_count,
		"git": git,
		"token_totals": dict(shared_session["tokens"]) if token_event_seen else None,
		"first_user_prompt": first_user_prompt,
		"failed_tool_counts": failed_tool_counts,
		"correction_markers": correction_markers,
	}


def build_report(
	paths: Iterable[Path],
	start: datetime.datetime,
	end: datetime.datetime,
	thread_names: dict[str, str] | None = None,
) -> dict[str, object]:
	"""Build the deterministic extraction document for a UTC window."""
	thread_names = {} if thread_names is None else thread_names
	sessions = []
	for path in paths:
		session = extract_session(path, start, end, thread_names)
		if session is not None:
			sessions.append(session)

	sessions.sort(key=lambda session: (session["start_timestamp"] or "", session["session_id"]))
	status = "live" if any(session["end_timestamp"] is None for session in sessions) else "elapsed"
	return {
		"schema_version": 1,
		"window": {
			"since": format_timestamp(start),
			"until": format_timestamp(end),
			"end_utc_exclusive": format_timestamp(end),
		},
		"status": status,
		"session_count": len(sessions),
		"sessions": sessions,
	}


def serialise_report(report: dict[str, object]) -> str:
	"""Serialise one report with stable indentation and key order."""
	return json.dumps(report, ensure_ascii=False, indent=2) + "\n"


def write_report(report: dict[str, object]) -> None:
	"""Write the extraction to Codex's global usage-data directory."""
	OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
	OUTPUT_PATH.write_text(serialise_report(report), encoding="utf-8")


def parse_arguments() -> argparse.Namespace:
	"""Parse the --since/--until window, or the --selftest flag that runs the fixture-based check instead."""
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--since", type=parse_bound)
	parser.add_argument("--until", type=parse_bound)
	parser.add_argument("--selftest", action="store_true")
	arguments = parser.parse_args()
	if arguments.selftest:
		if arguments.since is not None or arguments.until is not None:
			parser.error("--selftest cannot be combined with --since or --until")
		return arguments
	if arguments.since is None or arguments.until is None:
		parser.error("--since and --until must be provided together")
	if arguments.until < arguments.since:
		parser.error("--until must not be before --since")
	return arguments


def fixture_record(timestamp: str, record_kind: str, payload: dict[str, object]) -> dict[str, object]:
	"""Wrap a payload in the timestamp/type/payload envelope real rollout records use."""
	return {"timestamp": timestamp, "type": record_kind, "payload": payload}


def write_fixture(path: Path, records_to_write: list[dict[str, object]], malformed: bool = False) -> None:
	"""Write JSONL fixture records, optionally including an invalid line."""
	lines = [json.dumps(record, sort_keys=True) for record in records_to_write]
	if malformed:
		lines.insert(1, "not json")
	path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def run_selftest() -> None:
	"""Verify the extractor's behaviour against synthetic fixtures, without needing real Codex session data."""
	window_start = datetime.datetime(2026, 8, 8, 9, tzinfo=UTC)
	window_end = datetime.datetime(2026, 8, 8, 11, tzinfo=UTC)
	with tempfile.TemporaryDirectory() as directory:
		root = Path(directory)
		first = root / "rollout-a.jsonl"
		second = root / "rollout-b.jsonl"
		active = root / "rollout-c.jsonl"
		write_fixture(
			first,
			[
				fixture_record(
					"2026-08-08T10:00:00Z",
					"session_meta",
					{
						"id": "a",
						"cwd": "/tmp/project-a",
						"git": {
							"branch": "main",
							"commit_hash": "abc",
							"repository_url": "https://example.test/a",
						},
					},
				),
				fixture_record(
					"2026-08-08T10:01:00Z",
					"response_item",
					{
						"type": "message",
						"role": "user",
						"content": "Please stop editing files without asking.",
					},
				),
				fixture_record(
					"2026-08-08T10:01:30Z",
					"event_msg",
					{"type": "message", "role": "user", "content": "duplicate"},
				),
				fixture_record(
					"2026-08-08T10:02:00Z",
					"response_item",
					{"type": "message", "role": "assistant", "content": "Understood."},
				),
				fixture_record(
					"2026-08-08T10:02:30Z",
					"response_item",
					{
						"type": "custom_tool_call",
						"call_id": "call-1",
						"name": "exec",
						"input": "tools.exec_command({command: \"false\"})",
					},
				),
				fixture_record(
					"2026-08-08T10:02:40Z",
					"response_item",
					{
						"type": "custom_tool_call_output",
						"call_id": "call-1",
						"output": "Permission denied",
					},
				),
				fixture_record(
					"2026-08-08T10:02:50Z",
					"response_item",
					{
						"type": "function_call",
						"call_id": "call-2",
						"arguments": "{}",
					},
				),
				fixture_record(
					"2026-08-08T10:03:00Z",
					"response_item",
					{
						"type": "function_call_output",
						"call_id": "call-2",
						"output": "process exited with code 1",
					},
				),
				fixture_record(
					"2026-08-08T10:03:10Z",
					"event_msg",
					{
						"type": "token_count",
						"info": {
							"last_token_usage": {
								"input_tokens": 3,
								"cached_input_tokens": 4,
								"reasoning_output_tokens": 5,
								"output_tokens": 6,
								"total_tokens": 18,
							},
						},
					},
				),
				fixture_record("2026-08-08T10:04:00Z", "event_msg", {"type": "task_complete"}),
			],
			malformed=True,
		)
		write_fixture(
			second,
			[
				{
					"timestamp": "2026-08-08T09:00:00Z",
					"type": "session_meta",
					"payload": {"session_id": "b", "cwd": "/tmp/project-b"},
				},
				fixture_record(
					"2026-08-08T09:01:00Z",
					"response_item",
					{"type": "message", "role": "user", "content": "A normal prompt."},
				),
				fixture_record(
					"2026-08-08T09:02:00Z",
					"response_item",
					{"type": "message", "role": "assistant", "content": "Done."},
				),
				fixture_record("2026-08-08T09:03:00Z", "event_msg", {"type": "task_complete"}),
			],
		)
		write_fixture(
			active,
			[
				fixture_record("2026-08-08T10:30:00Z", "session_meta", {"session_id": "c", "cwd": "/tmp/project-c"}),
				fixture_record(
					"2026-08-08T10:31:00Z",
					"response_item",
					{"type": "message", "role": "user", "content": "Continue."},
				),
			],
		)

		first_report = build_report([first, second, active], window_start, window_end)
		second_report = build_report([active, second, first], window_start, window_end)
		assert serialise_report(first_report) == serialise_report(second_report)
		assert first_report["status"] == "live"
		assert [session["session_id"] for session in first_report["sessions"]] == ["b", "a", "c"]
		assert set(first_report["sessions"][1]) == {
			"session_id",
			"thread_name",
			"project_path",
			"start_timestamp",
			"end_timestamp",
			"user_message_count",
			"assistant_message_count",
			"tool_call_count",
			"git",
			"token_totals",
			"first_user_prompt",
			"failed_tool_counts",
			"correction_markers",
		}
		session_b, session_a, session_c = first_report["sessions"]
		assert session_a["project_path"] == "/tmp/project-a"
		assert session_a["git"] == {
			"branch": "main",
			"commit_hash": "abc",
			"repository_url": "https://example.test/a",
		}
		assert session_a["user_message_count"] == 1
		assert session_a["assistant_message_count"] == 1
		assert session_a["tool_call_count"] == 2
		assert session_a["failed_tool_counts"]["permission"] == 1
		assert session_a["failed_tool_counts"]["process-exit"] == 1
		assert session_a["token_totals"]["total_tokens"] == 18
		assert session_a["correction_markers"][0]["session_id"] == "a"
		assert session_a["correction_markers"][0]["timestamp"] == "2026-08-08T10:01:00Z"
		assert session_b["project_path"] == "/tmp/project-b"
		assert session_b["git"] == {"branch": None, "commit_hash": None, "repository_url": None}
		assert session_c["project_path"] == "/tmp/project-c"
		assert session_c["end_timestamp"] is None
		assert matches_correction("That was not what I asked.")
		assert not matches_correction("Please continue.")

	print("codex_insights_extract selftest passed")


def main() -> None:
	"""Run the selftest or write one bounded real-data extraction."""
	arguments = parse_arguments()
	if arguments.selftest:
		run_selftest()
		return

	paths = transcript_paths()[1]
	report = build_report(
		paths,
		arguments.since,
		arguments.until,
		read_session_index(),
	)
	write_report(report)
	print(
		f"Wrote {report['session_count']} sessions to {OUTPUT_PATH} "
		f"(status={report['status']})"
	)


if __name__ == "__main__":
	main()
