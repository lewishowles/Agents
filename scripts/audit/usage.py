#!/usr/bin/env python3
"""Write a bounded Claude and Codex token-usage report.

Codex ``event_msg`` records store token counts under ``payload.info``. An
empirical check of a real session with ten consecutive records confirmed that
``total_token_usage`` is cumulative per session, while ``last_token_usage`` is
the per-event delta. This script sums the latter and derives a delta from the
former only when the per-event value is absent.

All values produced by this script are tokens, not cost. The script reads
transcripts and the optional hcom database, then overwrites two fixed report
paths under the repository's ``.agent/audits/usage`` directory.
"""

from __future__ import annotations

import argparse
import collections
import contextlib
import datetime
import json
import math
import os
import re
import sqlite3
import sys
from pathlib import Path
from typing import Callable, Optional, TypedDict


REPO_ROOT = Path(__file__).resolve().parents[2]
AUDIT_DIRECTORY = Path(__file__).resolve().parent
if str(AUDIT_DIRECTORY) not in sys.path:
	sys.path.insert(0, str(AUDIT_DIRECTORY))

from metrics import (  # noqa: E402
	COMMAND_TEXT_LIMIT,
	RESULT_TEXT_LIMIT,
	blocks,
	classify_bash_command,
)
from redundancy import repeated_call_indexes  # noqa: E402


CLAUDE_ROOT = Path(os.environ.get("CLAUDE_CONFIG_DIR", "~/.claude")).expanduser() / "projects"
_CODEX_HOME = Path(os.environ.get("CODEX_HOME", "~/.codex")).expanduser()
CODEX_ROOTS = (
	_CODEX_HOME / "sessions",
	_CODEX_HOME / "archived_sessions",
)
HCOM_DATABASE = Path("~/.hcom/hcom.db").expanduser()
REPORT_DIRECTORY = REPO_ROOT / ".agent/audits/usage"
TOOLS = ("Claude", "Codex")
CLAUDE_RECORD_TYPES = (
	"assistant",
	"attachment",
	"user",
	"last-prompt",
	"mode",
	"permission-mode",
	"file-history-snapshot",
	"ai-title",
	"system",
	"queue-operation",
)
CODEX_RECORD_TYPES = (
	"event_msg",
	"response_item",
	"session_meta",
	"turn_context",
	"compacted",
)
DRIVER_METHOD = "chars/4"


class RecordStats(TypedDict):
	"""Track skipped records while reading one transcript."""

	skipped_record_count: int


class TokenTotals(TypedDict, total=False):
	"""Store the normalised token fields for one runtime."""

	input_tokens: int
	cache_creation_input_tokens: int
	cache_read_input_tokens: int
	cached_input_tokens: int
	reasoning_output_tokens: int
	output_tokens: int
	total_tokens: int
	total_input_tokens: int


class TokenSchema(TypedDict):
	"""Define source and derived token fields for one runtime."""

	fields: tuple[str, ...]
	total_input_fields: tuple[str, ...]


TOKEN_SCHEMAS: dict[str, TokenSchema] = {
	"Claude": {
		"fields": (
			"input_tokens",
			"cache_creation_input_tokens",
			"cache_read_input_tokens",
			"output_tokens",
		),
		"total_input_fields": (
			"input_tokens",
			"cache_creation_input_tokens",
			"cache_read_input_tokens",
		),
	},
	"Codex": {
		"fields": (
			"input_tokens",
			"cached_input_tokens",
			"reasoning_output_tokens",
			"output_tokens",
			"total_tokens",
		),
		"total_input_fields": (),
	},
}

# Keep the Codex field order available to the existing audit helper that consumes it.
CODEX_FIELDS = TOKEN_SCHEMAS["Codex"]["fields"]


class DriverClassification(TypedDict):
	"""Describe the safe grouping and repeat identity for one tool call."""

	category: str
	key: str
	target: str
	repeat_name: str
	repeat_input: dict[str, object]


# Define the target-extraction callable used by each classification rule.
# Assigned at module load (not deferred by `from __future__ import annotations`,
# which only covers annotations), so it needs `Optional[str]`: Python 3.9 doesn't
# support `str | None` as a runtime expression.
DriverTargetExtractor = Callable[[str, dict[str, object]], Optional[str]]


class DriverRule(TypedDict):
	"""Define how one known tool name supplies its classification target."""

	category: str
	target_extractor: DriverTargetExtractor


class DriverCall(TypedDict):
	"""Store bounded tool-call data while a session is being parsed."""

	name: object
	input: dict[str, object]
	classification: DriverClassification | None
	result: str
	failed: bool


class DriverLedgerRow(TypedDict):
	"""Store one ranked driver-ledger aggregate."""

	category: str
	key: str
	count: int
	payload_estimate_tokens: int
	method: str
	failure_count: int
	retry_count: int
	repeated: bool


class Unattributed(TypedDict):
	"""Store tool calls that cannot be assigned to a driver row."""

	count: int
	payload_estimate_tokens: int
	method: str


class HcomLabel(TypedDict):
	"""Store the safe hcom label joined to a transcript session."""

	agent_name: str
	role: str
	tool: str


class Session(TypedDict):
	"""Store the internal report model for one parsed transcript."""

	tool: str
	session_id: str
	transcript_path: str
	project_directory: str
	tokens: TokenTotals
	models: dict[str, TokenTotals]
	days: dict[str, TokenTotals]
	hcom: HcomLabel
	_driver_calls: list[DriverCall]
	tool_call_count: int
	skipped_record_count: int
	driver_ledger: list[DriverLedgerRow]
	unattributed_count: int
	unattributed: Unattributed
	driver_reconciles: bool


class RatioData(TypedDict):
	"""Store ratio inputs and the calculated ratio for report consumers."""

	numerator_tokens: int
	denominator_tokens: int
	ratio: float | None


class AggregateRow(TypedDict, total=False):
	"""Store one grouped report aggregate, including empty-tool metadata."""

	session_count: int
	tokens: TokenTotals
	empty: bool
	cache_read_ratio: RatioData
	reasoning_output_ratio: RatioData
	message: str


Group = dict[str, dict[str, AggregateRow]]
Window = tuple[datetime.datetime, datetime.datetime, str, str]
Sections = tuple[dict[str, AggregateRow], dict[str, Group], Group, Group, Group]


class WindowReport(TypedDict):
	"""Store the selected window in the serialised report."""

	since: str
	until: str
	start_utc: str
	end_utc_exclusive: str


class PartialData(TypedDict):
	"""Store skipped-record totals in the serialised report."""

	partial: bool
	skipped_record_count: int
	skipped_record_counts: dict[str, int]


class SessionReport(TypedDict):
	"""Store one serialised session row in the report."""

	rank: int
	tool: str
	session_id: str
	transcript_path: str
	project_directory: str
	hcom: HcomLabel
	models: list[str]
	tokens: TokenTotals
	tool_call_count: int
	skipped_record_count: int
	unattributed_count: int
	unattributed: Unattributed
	driver_reconciles: bool
	driver_ledger: list[DriverLedgerRow]


class DriverReconciliation(TypedDict):
	"""Store aggregate driver rows and their reconciliation counts."""

	driver_ledger: list[DriverLedgerRow]
	tool_call_count: int
	attributed_count: int
	unattributed_count: int
	unattributed: Unattributed
	reconciles: bool


class Report(TypedDict):
	"""Store the complete serialised usage report."""

	units: str
	window: WindowReport
	empty_window: bool
	partial_data: PartialData
	session_count: int
	totals_by_tool: dict[str, AggregateRow]
	totals_by_model: dict[str, Group]
	totals_by_day: Group
	totals_by_project: Group
	totals_by_role: Group
	driver_ledger: list[DriverLedgerRow]
	driver_reconciliation: DriverReconciliation
	sessions: list[SessionReport]
	top_sessions: list[SessionReport]


UNATTRIBUTED: HcomLabel = {
	"agent_name": "unattributed",
	"role": "unattributed",
	"tool": "unknown",
}


def parse_date(value):
	"""Parse a command-line date as a UTC calendar date.

	@param  {str}  value
		The YYYY-MM-DD value supplied by the caller.
	@return  {datetime.date}
		The parsed calendar date.
	"""
	try:
		return datetime.date.fromisoformat(value)
	except ValueError as error:
		raise argparse.ArgumentTypeError("expected YYYY-MM-DD") from error


def parse_timestamp(value):
	"""Parse a transcript timestamp, treating naive values as UTC.

	@param  {object}  value
		The timestamp value read from a JSONL record.
	@return  {datetime.datetime|None}
		An aware UTC timestamp, or None for an unsupported value.
	"""
	if not isinstance(value, str) or not value:
		return None

	try:
		timestamp = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
	except ValueError:
		return None

	if timestamp.tzinfo is None:
		timestamp = timestamp.replace(tzinfo=datetime.timezone.utc)

	return timestamp.astimezone(datetime.timezone.utc)


def build_window(arguments) -> Window:
	"""Build the half-open UTC window selected by the command line."""
	if arguments.days is not None and (arguments.since or arguments.until):
		arguments.parser.error("use --days or --since/--until, not both")

	if bool(arguments.since) != bool(arguments.until):
		arguments.parser.error("--since and --until must be provided together")

	if arguments.since and arguments.until:
		if arguments.until < arguments.since:
			arguments.parser.error("--until must not be before --since")

		start = datetime.datetime.combine(
			arguments.since,
			datetime.time.min,
			datetime.timezone.utc,
		)
		end = datetime.datetime.combine(
			arguments.until + datetime.timedelta(days=1),
			datetime.time.min,
			datetime.timezone.utc,
		)
		return start, end, arguments.since.isoformat(), arguments.until.isoformat()

	days = 7 if arguments.days is None else arguments.days
	if days < 0:
		arguments.parser.error("--days must not be negative")

	end = datetime.datetime.now(datetime.timezone.utc)
	start = end - datetime.timedelta(days=days)
	return start, end, start.isoformat(timespec="seconds"), end.isoformat(timespec="seconds")


def records(path, supported_types, record_stats: RecordStats):
	"""Yield supported JSON objects and count skipped transcript records."""
	with path.open(encoding="utf-8", errors="replace") as handle:
		for line in handle:
			try:
				record = json.loads(line)
			except (TypeError, ValueError):
				record_stats["skipped_record_count"] += 1
				continue

			if not isinstance(record, dict) or record.get("type") not in supported_types:
				record_stats["skipped_record_count"] += 1
				continue

			yield record


def number(value):
	"""Return a non-negative integer token value for a parsed field.

	Non-finite floats are invalid and become zero. Finite floats are truncated
	toward zero by ``int()`` before negative values are clamped to zero.
	"""
	if isinstance(value, bool) or not isinstance(value, (int, float)):
		return 0

	if isinstance(value, float) and not math.isfinite(value):
		return 0

	return max(0, int(value))


def safe_text(value):
	"""Return a single-line string suitable for safe length measurement."""
	if not isinstance(value, str):
		return ""

	return value.replace("\x00", "").replace("\r", " ").replace("\n", " ").strip()


def object_input(value):
	"""Decode a tool input object when a transcript stores it as JSON text."""
	if isinstance(value, dict):
		return value

	if not isinstance(value, str):
		return {}

	try:
		decoded = json.loads(value)
	except (TypeError, ValueError):
		return {}

	return decoded if isinstance(decoded, dict) else {}


def decode_js_string(value):
	"""Decode one quoted JavaScript string literal without parsing the source."""
	if not isinstance(value, str) or len(value) < 2:
		return ""

	if value.startswith('"') and value.endswith('"'):
		try:
			return safe_text(json.loads(value))
		except (TypeError, ValueError):
			return ""

	if value.startswith("'") and value.endswith("'"):
		try:
			return safe_text(bytes(value[1:-1], "utf-8").decode("unicode_escape"))
		except (UnicodeDecodeError, ValueError):
			return ""

	return ""


def embedded_js_argument(source, key):
	"""Extract one quoted argument from a nested JavaScript tool call."""
	if not isinstance(source, str):
		return ""

	pattern = rf"(?:['\"]{re.escape(key)}['\"]|{re.escape(key)})\s*:\s*(\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*')"
	match = re.search(pattern, source)
	return decode_js_string(match.group(1)) if match else ""


def embedded_patch_path(source):
	"""Extract the first safe target path from an apply_patch source string."""
	if not isinstance(source, str):
		return ""

	match = re.search(r"\*\*\* (?:Update|Add|Delete) File:\s*([^\s\\]+)", source)
	return safe_text(match.group(1)) if match else ""


def embedded_tool_call(value):
	"""Extract the real tool call nested inside a Codex ``exec`` source string."""
	if not isinstance(value, str):
		return None

	match = re.search(r"\btools\.([A-Za-z_][A-Za-z0-9_]*)\s*\(", value)
	if not match:
		return None

	name = match.group(1)
	tool_input = {
		key: argument
		for key in (
			"agent",
			"command",
			"cmd",
			"file_path",
			"name",
			"path",
			"skill",
			"subagent_type",
		)
		if (argument := embedded_js_argument(value, key))
	}

	if name == "apply_patch":
		file_path = embedded_patch_path(value)
		if file_path:
			tool_input["file_path"] = file_path

	if name == "exec_command" or name == "write_stdin":
		return "Bash", tool_input

	if name == "apply_patch":
		return "Edit", tool_input

	return name, tool_input


def result_text(value):
	"""Extract result text for bounded length measurement without reporting it."""
	if isinstance(value, str):
		return value

	if isinstance(value, list):
		return " ".join(result_text(item) for item in value)

	if isinstance(value, dict):
		for key in ("content", "output", "result", "text"):
			if key in value:
				return result_text(value[key])

	return ""


def tool_result_failed(value):
	"""Return whether a tool result explicitly reports a failure."""
	return isinstance(value, dict) and bool(value.get("is_error") or value.get("isError"))


def command_input(tool_input):
	"""Return a command from Claude or Codex tool input."""
	for key in ("command", "cmd"):
		command = safe_text(tool_input.get(key))
		if command:
			return command

	return ""


def extract_command_target(name: str, tool_input: dict[str, object]) -> str:
	"""Return a command target, including an empty target when absent."""
	return command_input(tool_input)


def extract_file_target(name: str, tool_input: dict[str, object]) -> str | None:
	"""Return a non-empty file target from tool input."""
	target = safe_text(tool_input.get("file_path") or tool_input.get("path"))
	return target or None


def extract_skill_target(name: str, tool_input: dict[str, object]) -> str | None:
	"""Return a non-empty skill target from tool input."""
	target = safe_text(tool_input.get("skill") or tool_input.get("name"))
	return target or None


# Define the fixed-name rules before adding the dynamic hook and MCP rules.
DRIVER_RULES: dict[str, DriverRule] = {
	"Bash": {
		"category": "bash",
		"target_extractor": extract_command_target,
	},
	"Edit": {
		"category": "edit",
		"target_extractor": extract_file_target,
	},
	"Read": {
		"category": "read",
		"target_extractor": extract_file_target,
	},
	"Skill": {
		"category": "skill",
		"target_extractor": extract_skill_target,
	},
	"Write": {
		"category": "write",
		"target_extractor": extract_file_target,
	},
	"exec_command": {
		"category": "bash",
		"target_extractor": extract_command_target,
	},
}


def extract_hook_target(name: str, tool_input: dict[str, object]) -> str:
	"""Return a hook name from tool input, falling back to the tool name."""
	return safe_text(tool_input.get("name") or name)


def extract_name_target(name: str, tool_input: dict[str, object]) -> str:
	"""Return the tool name when it is also the classification target."""
	return name


def driver_rule(name: str) -> DriverRule | None:
	"""Return the table or dynamic rule for a tool name."""
	rule = DRIVER_RULES.get(name)
	if rule is not None:
		return rule

	if name == "Hook" or name.lower().startswith("hook"):
		return {"category": "hook", "target_extractor": extract_hook_target}

	if name.startswith(("mcp__", "mcp_")):
		return {"category": "mcp", "target_extractor": extract_name_target}

	return None


def driver_repeat_identity(
	name: str,
	category: str,
	target: str,
) -> tuple[str, dict[str, object]]:
	"""Return the tool identity and bounded input used for repeat detection."""
	if category == "bash":
		return "Bash", {"command": target}

	if category in ("read", "write", "edit"):
		return name, {"file_path": target}

	return name, {}


def build_driver_classification(
	name: str,
	category: str,
	target: str,
	classification_key: str | None = None,
) -> DriverClassification:
	"""Build a classification from its category, target, and repeat identity."""
	repeat_name, repeat_input = driver_repeat_identity(name, category, target)
	key = classification_key or target
	if classification_key is None and category == "bash":
		key = classify_bash_command(target) or "other"

	return {
		"category": category,
		"key": key,
		"target": target,
		"repeat_name": repeat_name,
		"repeat_input": repeat_input,
	}


def fallback_driver_classification(
	name: str,
	tool_input: dict[str, object],
) -> DriverClassification:
	"""Classify an unknown tool using its safest available target."""
	target = safe_text(
		tool_input.get("file_path")
		or tool_input.get("path")
		or tool_input.get("subagent_type")
		or name
	)
	return build_driver_classification(name, "tool", target, name)


def driver_classification(name, tool_input: dict[str, object]) -> DriverClassification | None:
	"""Classify one tool call and return its safe key and estimate target."""
	if not isinstance(name, str) or not name:
		return None

	rule = driver_rule(name)
	if rule is None:
		return fallback_driver_classification(name, tool_input)

	target = rule["target_extractor"](name, tool_input)
	if target is None:
		return None

	return build_driver_classification(name, rule["category"], target)


def new_driver_call(name, tool_input: dict[str, object]) -> DriverCall:
	"""Create an internal tool-call record without retaining raw result content."""
	classification = driver_classification(name, tool_input)
	return {
		"name": name,
		"input": tool_input,
		"classification": classification,
		"result": "",
		"failed": False,
	}


def new_session_parse_state() -> tuple[dict[str, DriverCall], RecordStats]:
	"""Create driver correlation and record-skipping state for one session."""
	return {}, {"skipped_record_count": 0}


def append_driver_call(
	session: Session,
	calls_by_id: dict[str, DriverCall],
	call: DriverCall,
	call_id: object = None,
):
	"""Append one in-window driver call and register its response identifier."""
	session["_driver_calls"].append(call)
	session["tool_call_count"] += 1

	if isinstance(call_id, str) and call_id:
		calls_by_id[call_id] = call


def update_driver_call_result(
	calls_by_id: dict[str, DriverCall],
	call_id: object,
	result: object,
	failed: bool,
):
	"""Attach one correlated result to a previously recorded driver call."""
	call = calls_by_id.get(call_id)
	if call is not None:
		call["result"] = result_text(result)
		call["failed"] = failed


def estimated_payload_tokens(call):
	"""Estimate one driver payload from bounded command, target, and result text."""
	classification = call["classification"]
	if classification is None:
		target = safe_text(call.get("name"))
	else:
		target = classification["target"]

	parts = [target[:COMMAND_TEXT_LIMIT], safe_text(call["result"])[:RESULT_TEXT_LIMIT]]
	character_count = sum(len(part) for part in parts)
	return math.ceil(character_count / 4) if character_count else 0


def finalise_driver_ledger(session: Session):
	"""Build ranked driver rows and explicit unattributed counts for a session."""
	calls = session["_driver_calls"]
	repetition_calls = [
		(
			call["classification"]["repeat_name"] if call["classification"] else call["name"],
			call["classification"]["repeat_input"] if call["classification"] else {},
			index,
		)
		for index, call in enumerate(calls)
	]
	repeated_indexes = repeated_call_indexes(repetition_calls)
	rows: dict[tuple[str, str], DriverLedgerRow] = {}
	unattributed_count = 0
	unattributed_payload = 0
	failed_before: dict[tuple[str, str], bool] = {}

	for index, call in enumerate(calls):
		classification = call["classification"]
		payload_estimate = estimated_payload_tokens(call)
		if classification is None:
			unattributed_count += 1
			unattributed_payload += payload_estimate
			continue

		category = classification["category"]
		key = classification["key"]
		identity = (category, key)
		retry_count = 1 if failed_before.get(identity) else 0
		if call["failed"]:
			failed_before[identity] = True

		row = rows.setdefault(
			identity,
			{
				"category": category,
				"key": key,
				"count": 0,
				"payload_estimate_tokens": 0,
				"method": DRIVER_METHOD,
				"failure_count": 0,
				"retry_count": 0,
				"repeated": False,
			},
		)
		row["count"] += 1
		row["payload_estimate_tokens"] += payload_estimate
		row["failure_count"] += int(call["failed"])
		row["retry_count"] += retry_count
		row["repeated"] = row["repeated"] or index in repeated_indexes

	ordered_rows = sorted(
		rows.values(),
		key=lambda row: (-row["payload_estimate_tokens"], row["category"], row["key"]),
	)
	session["driver_ledger"] = ordered_rows
	session["unattributed_count"] = unattributed_count
	session["unattributed"] = {
		"count": unattributed_count,
		"payload_estimate_tokens": unattributed_payload,
		"method": DRIVER_METHOD,
	}
	session["driver_reconciles"] = session["tool_call_count"] == (
		sum(row["count"] for row in ordered_rows) + unattributed_count
	)


def token_schema(tool: str) -> TokenSchema:
	"""Return the token field schema for one runtime."""
	return TOKEN_SCHEMAS.get(tool, TOKEN_SCHEMAS["Codex"])


def empty_totals(tool: str) -> TokenTotals:
	"""Create the token fields used by one tool's aggregate."""
	schema = token_schema(tool)
	totals = {field: 0 for field in schema["fields"]}
	totals["total_tokens"] = 0

	for field in schema["total_input_fields"]:
		totals[field] = 0

	return totals


def usage_totals(usage: dict[str, object], tool: str) -> TokenTotals:
	"""Normalise one Claude or Codex usage object into token fields."""
	schema = token_schema(tool)
	values = {field: number(usage.get(field)) for field in schema["fields"]}
	total_input_fields = schema["total_input_fields"]

	if total_input_fields:
		values["total_input_tokens"] = sum(
			values[field] for field in total_input_fields
		)
		values["total_tokens"] = values["total_input_tokens"] + values["output_tokens"]
	elif not values["total_tokens"]:
		values["total_tokens"] = values["input_tokens"] + values["output_tokens"]

	return values


def add_totals(target: TokenTotals, source: TokenTotals, tool: str):
	"""Add one normalised usage object to an aggregate."""
	schema = token_schema(tool)
	for field, value in source.items():
		if field != "total_input_tokens" or schema["total_input_fields"]:
			target[field] = target.get(field, 0) + value

	if schema["total_input_fields"]:
		target["total_input_tokens"] = sum(
			target[field] for field in schema["total_input_fields"]
		)
		target["total_tokens"] = target["total_input_tokens"] + target["output_tokens"]


def add_session_usage(
	session: Session,
	usage: dict[str, object],
	model: str,
	day: str,
	tool: str,
):
	"""Add one in-window event to session, model, and day totals."""
	normalised = usage_totals(usage, tool)
	if not normalised["total_tokens"]:
		return

	add_totals(session["tokens"], normalised, tool)
	add_totals(session["models"].setdefault(model, empty_totals(tool)), normalised, tool)
	add_totals(session["days"].setdefault(day, empty_totals(tool)), normalised, tool)


def new_session(tool: str, session_id: str, path: Path, project_directory: str) -> Session:
	"""Create the internal representation for one transcript session."""
	return {
		"tool": tool,
		"session_id": session_id,
		"transcript_path": str(path),
		"project_directory": project_directory or "unknown",
		"tokens": empty_totals(tool),
		"models": {},
		"days": {},
		"hcom": dict(UNATTRIBUTED),
		"_driver_calls": [],
		"tool_call_count": 0,
		"skipped_record_count": 0,
		"driver_ledger": [],
		"unattributed_count": 0,
		"unattributed": {
			"count": 0,
			"payload_estimate_tokens": 0,
			"method": DRIVER_METHOD,
		},
		"driver_reconciles": True,
	}


def finalise_session(session: Session, record_stats: RecordStats) -> Session | None:
	"""Attach parser bookkeeping and omit sessions with no usage or skipped records."""
	session["skipped_record_count"] = record_stats["skipped_record_count"]
	finalise_driver_ledger(session)

	if session["tokens"]["total_tokens"] or session["skipped_record_count"]:
		return session

	return None


def in_window(timestamp, start, end):
	"""Return whether a timestamp belongs to the selected half-open window."""
	return timestamp is not None and start <= timestamp < end


def update_claude_metadata(session: Session, record: dict[str, object]):
	"""Update the project directory from one Claude record."""
	cwd = record.get("cwd")
	if isinstance(cwd, str) and cwd:
		session["project_directory"] = cwd


def append_claude_hook_call(
	session: Session,
	calls_by_id: dict[str, DriverCall],
	record: dict[str, object],
	timestamp,
	start: datetime.datetime,
	end: datetime.datetime,
):
	"""Record one in-window Claude hook attachment as a driver call."""
	attachment = record.get("attachment")
	if not (
		isinstance(attachment, dict)
		and attachment.get("type") == "hook_success"
		and in_window(timestamp, start, end)
	):
		return

	hook_name = safe_text(attachment.get("hookName"))
	if not hook_name:
		return

	call = new_driver_call("Hook", {"name": hook_name})
	call["result"] = result_text(attachment.get("stdout"))
	call["failed"] = attachment.get("exitCode") not in (None, 0, "0")
	append_driver_call(session, calls_by_id, call)


def process_claude_tool_blocks(
	session: Session,
	calls_by_id: dict[str, DriverCall],
	record: dict[str, object],
	timestamp,
	start: datetime.datetime,
	end: datetime.datetime,
):
	"""Correlate Claude tool calls and their results for one record."""
	for block in blocks(record):
		if block.get("type") == "tool_use" and in_window(timestamp, start, end):
			call = new_driver_call(block.get("name"), object_input(block.get("input") or {}))
			append_driver_call(session, calls_by_id, call, block.get("id"))
		elif block.get("type") == "tool_result":
			update_driver_call_result(
				calls_by_id,
				block.get("tool_use_id"),
				block.get("content"),
				tool_result_failed(block),
			)


def claude_usage_event(
	record: dict[str, object],
	timestamp,
	start: datetime.datetime,
	end: datetime.datetime,
):
	"""Return one in-window Claude usage event with its model and day."""
	if record.get("type") != "assistant":
		return None

	message = record.get("message") or {}
	# Sidechain (subagent) usage lives only inside its own record here, never
	# duplicated in the parent's usage, so it is counted rather than filtered.
	usage = message.get("usage")
	if not isinstance(usage, dict) or not in_window(timestamp, start, end):
		return None

	model = message.get("model")
	model = model if isinstance(model, str) and model else "unknown"
	return usage, model, timestamp.date().isoformat()


def aggregate_claude_usage(session: Session, event):
	"""Add one parsed Claude usage event to the session totals."""
	if event is None:
		return

	usage, model, day = event
	add_session_usage(session, usage, model, day, "Claude")


def parse_claude_session(
	path: Path,
	start: datetime.datetime,
	end: datetime.datetime,
) -> Session | None:
	"""Parse in-window Claude usage records from one transcript."""
	session_id = path.stem
	project_directory = path.parent.name
	session = new_session("Claude", session_id, path, project_directory)
	calls_by_id, record_stats = new_session_parse_state()

	for record in records(path, CLAUDE_RECORD_TYPES, record_stats):
		update_claude_metadata(session, record)
		timestamp = parse_timestamp(record.get("timestamp"))
		append_claude_hook_call(session, calls_by_id, record, timestamp, start, end)
		process_claude_tool_blocks(session, calls_by_id, record, timestamp, start, end)
		aggregate_claude_usage(session, claude_usage_event(record, timestamp, start, end))

	return finalise_session(session, record_stats)


def codex_delta(last_usage, total_usage, previous_total) -> TokenTotals | None:
	"""Return one Codex event delta, preferring the recorded per-event value."""
	if isinstance(last_usage, dict):
		return last_usage

	if isinstance(total_usage, dict) and isinstance(previous_total, dict):
		return {
			field: number(total_usage.get(field)) - number(previous_total.get(field))
			for field in CODEX_FIELDS
		}

	if isinstance(total_usage, dict):
		return total_usage

	return None


def update_codex_metadata(
	session: Session,
	record: dict[str, object],
	model: str,
) -> str:
	"""Update Codex session metadata and return the current model."""
	payload = record.get("payload")
	if not isinstance(payload, dict):
		return model

	record_type = record.get("type")
	if record_type == "session_meta":
		metadata_session_id = payload.get("session_id") or payload.get("id")
		if isinstance(metadata_session_id, str) and metadata_session_id:
			session["session_id"] = metadata_session_id

		cwd = payload.get("cwd")
		if isinstance(cwd, str) and cwd:
			session["project_directory"] = cwd
	elif record_type == "turn_context":
		context_model = payload.get("model")
		if isinstance(context_model, str) and context_model:
			model = context_model

		cwd = payload.get("cwd")
		if isinstance(cwd, str) and cwd:
			session["project_directory"] = cwd

	return model


def decode_codex_tool_call(payload: dict[str, object]) -> tuple[object, dict[str, object]]:
	"""Decode a Codex response item, including embedded JavaScript calls."""
	name = payload.get("name") or payload.get("tool_name")
	arguments = payload.get("arguments", payload.get("input", {}))
	tool_input = object_input(arguments)
	if payload.get("type") == "custom_tool_call":
		embedded = embedded_tool_call(arguments)
		if embedded is not None:
			return embedded

	return name, tool_input


def process_codex_response_item(
	session: Session,
	calls_by_id: dict[str, DriverCall],
	record: dict[str, object],
	timestamp,
	start: datetime.datetime,
	end: datetime.datetime,
):
	"""Correlate Codex response-item tool calls and their results."""
	if record.get("type") != "response_item":
		return

	payload = record.get("payload")
	if not isinstance(payload, dict):
		return

	response_type = payload.get("type")
	if response_type in ("function_call", "custom_tool_call"):
		if not in_window(timestamp, start, end):
			return

		name, tool_input = decode_codex_tool_call(payload)
		call = new_driver_call(name, tool_input)
		call_id = payload.get("call_id") or payload.get("id")
		append_driver_call(session, calls_by_id, call, call_id)
	elif response_type in ("function_call_output", "custom_tool_call_output"):
		call_id = payload.get("call_id") or payload.get("id")
		update_driver_call_result(
			calls_by_id,
			call_id,
			payload.get("output"),
			tool_result_failed(payload),
		)


def codex_usage_event(
	record: dict[str, object],
	previous_total: dict[str, object] | None,
) -> tuple[TokenTotals | None, dict[str, object] | None]:
	"""Return a Codex token delta and the next cumulative total."""
	if record.get("type") != "event_msg":
		return None, previous_total

	payload = record.get("payload")
	if not isinstance(payload, dict) or payload.get("type") != "token_count":
		return None, previous_total

	info = payload.get("info")
	if not isinstance(info, dict):
		info = payload

	total_usage = info.get("total_token_usage")
	last_usage = info.get("last_token_usage")
	delta = codex_delta(last_usage, total_usage, previous_total)
	if isinstance(total_usage, dict):
		previous_total = total_usage

	return delta, previous_total


def aggregate_codex_usage(
	session: Session,
	delta: TokenTotals | None,
	model: str,
	timestamp,
	start: datetime.datetime,
	end: datetime.datetime,
):
	"""Add one in-window Codex token delta to the session totals."""
	if not in_window(timestamp, start, end) or not isinstance(delta, dict):
		return

	add_session_usage(session, delta, model, timestamp.date().isoformat(), "Codex")


def parse_codex_session(
	path: Path,
	start: datetime.datetime,
	end: datetime.datetime,
) -> Session | None:
	"""Parse in-window Codex token-count events from one rollout transcript."""
	session_id = path.stem
	if session_id.startswith("rollout-"):
		session_id = session_id.removeprefix("rollout-")

	session = new_session("Codex", session_id, path, "unknown")
	model = "unknown"
	previous_total = None
	calls_by_id, record_stats = new_session_parse_state()

	for record in records(path, CODEX_RECORD_TYPES, record_stats):
		model = update_codex_metadata(session, record, model)
		timestamp = parse_timestamp(record.get("timestamp"))
		process_codex_response_item(session, calls_by_id, record, timestamp, start, end)
		delta, previous_total = codex_usage_event(record, previous_total)
		aggregate_codex_usage(session, delta, model, timestamp, start, end)

	return finalise_session(session, record_stats)


def normalise_path(value):
	"""Return a comparable absolute path for an optional hcom value."""
	if not isinstance(value, str) or not value:
		return ""

	try:
		return str(Path(value).expanduser().resolve())
	except OSError:
		return os.path.abspath(os.path.expanduser(value))


def hcom_role(tag, parent_name):
	"""Extract the repository-scoped role suffix from an hcom label."""
	value = tag or parent_name or ""
	if not isinstance(value, str) or not value:
		return "unattributed"

	return value.rsplit("-", 1)[-1] or "unattributed"


def load_hcom_labels() -> tuple[dict[str, HcomLabel], dict[str, HcomLabel]]:
	"""Load best-effort transcript labels from hcom's read-only database."""
	by_session_id: dict[str, HcomLabel] = {}
	by_path: dict[str, HcomLabel] = {}

	if not HCOM_DATABASE.is_file():
		return by_session_id, by_path

	try:
		with contextlib.closing(
			sqlite3.connect(
				f"file:{HCOM_DATABASE}?mode=ro",
				uri=True,
				timeout=1,
			)
		) as connection:
			connection.row_factory = sqlite3.Row
			rows = connection.execute(
				"SELECT name, session_id, transcript_path, tag, parent_name, tool "
				"FROM instances"
			).fetchall()
	except sqlite3.Error:
		return by_session_id, by_path

	for row in rows:
		label: HcomLabel = {
			"agent_name": row["name"] or "unattributed",
			"role": hcom_role(row["tag"], row["parent_name"]),
			"tool": row["tool"] or "unknown",
		}
		session_id = row["session_id"]
		if isinstance(session_id, str) and session_id:
			by_session_id[session_id] = label

		path = normalise_path(row["transcript_path"])
		if path:
			by_path[path] = label

	return by_session_id, by_path


def apply_hcom_label(
	session: Session,
	by_session_id: dict[str, HcomLabel],
	by_path: dict[str, HcomLabel],
):
	"""Join one parsed session to hcom, retaining an explicit fallback label."""
	label = by_path.get(normalise_path(session["transcript_path"]))
	if label is None:
		label = by_session_id.get(session["session_id"])

	if label is not None:
		session["hcom"] = dict(label)


def ratio(numerator, denominator):
	"""Return a stable ratio, or None when the denominator is zero."""
	if not denominator:
		return None

	return round(numerator / denominator, 6)


def ratio_data(numerator: int, denominator: int) -> RatioData:
	"""Return ratio inputs as well as the calculated ratio for JSON consumers."""
	return {
		"numerator_tokens": numerator,
		"denominator_tokens": denominator,
		"ratio": ratio(numerator, denominator),
	}


def add_group(
	group: Group,
	key: str,
	tool: str,
	session_count: int,
	tokens: TokenTotals,
):
	"""Add a session or event aggregate to a grouped report section."""
	row = group.setdefault(key, {})
	tool_row = row.setdefault(
		tool,
		{
			"session_count": 0,
			"tokens": empty_totals(tool),
		},
	)
	tool_row["session_count"] += session_count
	add_totals(tool_row["tokens"], tokens, tool)


def aggregate(
	sessions: list[Session],
) -> Sections:
	"""Build all report breakdowns from parsed sessions."""
	by_tool: dict[str, AggregateRow] = {
		tool: {
			"session_count": 0,
			"tokens": empty_totals(tool),
		}
		for tool in TOOLS
	}
	by_model: dict[str, Group] = {tool: {} for tool in TOOLS}
	by_day: Group = {}
	by_project: Group = {}
	by_role: Group = {}

	for session in sessions:
		tool = session["tool"]
		by_tool[tool]["session_count"] += 1
		add_totals(by_tool[tool]["tokens"], session["tokens"], tool)

		for model, tokens in session["models"].items():
			add_group(by_model[tool], model, tool, 1, tokens)

		for day, tokens in session["days"].items():
			add_group(by_day, day, tool, 1, tokens)

		add_group(by_project, session["project_directory"], tool, 1, session["tokens"])
		add_group(by_role, session["hcom"]["role"], tool, 1, session["tokens"])

	for tool in TOOLS:
		tokens = by_tool[tool]["tokens"]
		by_tool[tool]["empty"] = by_tool[tool]["session_count"] == 0
		if tool == "Claude":
			by_tool[tool]["cache_read_ratio"] = ratio_data(
				tokens.get("cache_read_input_tokens", 0),
				tokens.get("total_input_tokens", 0),
			)
		else:
			by_tool[tool]["reasoning_output_ratio"] = ratio_data(
				tokens.get("reasoning_output_tokens", 0),
				tokens.get("output_tokens", 0),
			)

		if by_tool[tool]["empty"]:
			by_tool[tool]["message"] = f"No {tool} token usage records in the selected window."

	return by_tool, by_model, by_day, by_project, by_role


def aggregate_driver_ledger(sessions: list[Session]) -> DriverReconciliation:
	"""Combine session driver rows into one ranked ledger and reconciliation."""
	rows: dict[tuple[str, str], DriverLedgerRow] = {}
	tool_call_count = 0
	unattributed_count = 0
	unattributed_payload = 0

	for session in sessions:
		tool_call_count += session["tool_call_count"]
		unattributed_count += session["unattributed_count"]
		unattributed_payload += session["unattributed"]["payload_estimate_tokens"]

		for source in session["driver_ledger"]:
			identity = (source["category"], source["key"])
			if identity not in rows:
				rows[identity] = dict(source)
			else:
				row = rows[identity]
				row["count"] += source["count"]
				row["payload_estimate_tokens"] += source["payload_estimate_tokens"]
				row["failure_count"] += source["failure_count"]
				row["retry_count"] += source["retry_count"]
				row["repeated"] = row["repeated"] or source["repeated"]

	ordered_rows = sorted(
		rows.values(),
		key=lambda row: (-row["payload_estimate_tokens"], row["category"], row["key"]),
	)
	attributed_count = sum(row["count"] for row in ordered_rows)

	return {
		"driver_ledger": ordered_rows,
		"tool_call_count": tool_call_count,
		"attributed_count": attributed_count,
		"unattributed_count": unattributed_count,
		"unattributed": {
			"count": unattributed_count,
			"payload_estimate_tokens": unattributed_payload,
			"method": DRIVER_METHOD,
		},
		"reconciles": tool_call_count == attributed_count + unattributed_count,
	}


def display_token_count(tokens):
	"""Format a token count for the Markdown report."""
	return f"{tokens:,}"


def display_path(value):
	"""Keep grouped paths safe in a Markdown table."""
	return str(value).replace("|", "\\|").replace("\n", " ")


def format_ratio(data):
	"""Format a ratio row for Markdown."""
	if data["ratio"] is None:
		return "n/a"

	return f"{data['ratio'] * 100:.2f}%"


def markdown_table_for_group(group: Group):
	"""Render grouped token totals as a deterministic Markdown table."""
	lines = [
		"| Group | Tool | Sessions | Total tokens |",
		"| --- | --- | ---: | ---: |",
	]

	for key in sorted(group):
		for tool in TOOLS:
			row = group[key].get(tool)
			if row is None:
				continue

			lines.append(
				f"| {display_path(key)} | {tool} | {row['session_count']} | "
				f"{display_token_count(row['tokens']['total_tokens'])} |"
			)

	return lines if len(lines) > 2 else ["No data in the selected window."]


def markdown_driver_table(
	rows: list[DriverLedgerRow],
	unattributed: Unattributed,
):
	"""Render ranked driver rows without including raw transcript payloads."""
	lines = [
		"| Rank | Category | Key | Count | Payload estimate (tokens) | Method | Failures | Retries | Repeated |",
		"| ---: | --- | --- | ---: | ---: | --- | ---: | ---: | --- |",
	]

	for rank, row in enumerate(rows, start=1):
		lines.append(
			f"| {rank} | {row['category']} | {display_path(row['key'])} | {row['count']} | "
			f"{row['payload_estimate_tokens']} | {row['method']} | {row['failure_count']} | "
			f"{row['retry_count']} | {'yes' if row['repeated'] else 'no'} |"
		)

	if unattributed["count"]:
		rank = len(rows) + 1
		lines.append(
			f"| {rank} | unattributed | — | {unattributed['count']} | "
			f"{unattributed['payload_estimate_tokens']} | {unattributed['method']} | — | — | — |"
		)

	return lines if len(lines) > 2 else ["No data in the selected window."]


def render_window_section(report: Report) -> list[str]:
	"""Render the report window, empty-window, and partial-data sections."""
	window = report["window"]
	lines = [
		"## Window (tokens, not cost)",
		"",
		f"- Since (UTC): `{window['since']}`",
		f"- Until (UTC): `{window['until']}`",
		f"- Sessions with usage: `{report['session_count']}`",
		"",
	]

	if report["empty_window"]:
		lines.extend(
			[
				"## Empty window (tokens, not cost)",
				"",
				"No Claude or Codex usage records were found in the selected window.",
				"",
			]
		)

	partial_data = report["partial_data"]
	if partial_data["partial"]:
		lines.extend(
			[
				"## Partial data",
				"",
				f"Skipped records: **{partial_data['skipped_record_count']}**",
				"",
				"| Runtime | Skipped records |",
				"| --- | ---: |",
			]
		)
		for tool in TOOLS:
			lines.append(
				f"| {tool} | {partial_data['skipped_record_counts'][tool]} |"
			)

	return lines


def render_tool_totals_section(report: Report) -> list[str]:
	"""Render token totals grouped by runtime tool."""
	by_tool = report["totals_by_tool"]
	lines = [
		"## Totals by tool (tokens, not cost)",
		"",
		"| Tool | Sessions | Total tokens | Input tokens | Output tokens |",
		"| --- | ---: | ---: | ---: | ---: |",
	]

	for tool in TOOLS:
		row = by_tool[tool]
		if row["empty"]:
			lines.append(f"| {tool} | 0 | no data | no data | no data |")
			continue

		tokens = row["tokens"]
		input_tokens = tokens.get("total_input_tokens", tokens.get("input_tokens", 0))
		lines.append(
			f"| {tool} | {row['session_count']} | "
			f"{display_token_count(tokens['total_tokens'])} | "
			f"{display_token_count(input_tokens)} | "
			f"{display_token_count(tokens['output_tokens'])} |"
		)

	return lines


def render_group_tables_section(report: Report) -> list[str]:
	"""Render model, day, project, and hcom role totals."""
	lines = ["", "## Totals by model (tokens, not cost)", ""]
	for line in markdown_table_for_group(report["totals_by_model"]["Claude"]):
		lines.append(line)
	for line in markdown_table_for_group(report["totals_by_model"]["Codex"]):
		lines.append(line)

	lines.extend(["", "## Totals by day (tokens, not cost)", ""])
	lines.extend(markdown_table_for_group(report["totals_by_day"]))
	lines.extend(["", "## Totals by project directory (tokens, not cost)", ""])
	lines.extend(markdown_table_for_group(report["totals_by_project"]))
	lines.extend(["", "## Totals by hcom role (tokens, not cost)", ""])
	lines.extend(markdown_table_for_group(report["totals_by_role"]))

	return lines


def render_top_sessions_section(report: Report) -> list[str]:
	"""Render the top sessions ranked by total tokens."""
	lines = [
		"",
		"## Top 10 sessions by total tokens (tokens, not cost)",
		"",
		"| Rank | Tool | Session id | Total tokens | Project directory | Transcript path | Hcom role |",
		"| ---: | --- | --- | ---: | --- | --- | --- |",
	]

	if report["top_sessions"]:
		for session in report["top_sessions"]:
			lines.append(
				f"| {session['rank']} | {session['tool']} | `{session['session_id']}` | "
				f"{display_token_count(session['tokens']['total_tokens'])} | "
				f"{display_path(session['project_directory'])} | "
				f"`{display_path(session['transcript_path'])}` | "
				f"{display_path(session['hcom']['role'])} |"
			)
	else:
		lines.append("| | | no data | | | | |")

	return lines


def render_driver_views_section(report: Report) -> list[str]:
	"""Render aggregate and per-session driver ledger views."""
	lines = [
		"",
		"## Driver ledger (ranked aggregate)",
		"",
		(
			f"Tool calls: **{report['driver_reconciliation']['tool_call_count']}** = "
			f"{report['driver_reconciliation']['attributed_count']} attributed + "
			f"{report['driver_reconciliation']['unattributed_count']} unattributed."
		),
		"",
	]
	lines.extend(
		markdown_driver_table(
			report["driver_ledger"],
			report["driver_reconciliation"]["unattributed"],
		)
	)

	lines.extend(["", "## Driver ledger by session", ""])
	if report["sessions"]:
		for session in report["sessions"]:
			lines.extend(
				[
					f"### {session['tool']} `{session['session_id']}`",
					"",
					(
						f"Tool calls: **{session['tool_call_count']}** = "
						f"{session['tool_call_count'] - session['unattributed_count']} attributed + "
						f"{session['unattributed_count']} unattributed."
					),
					"",
				]
			)
			lines.extend(markdown_driver_table(session["driver_ledger"], session["unattributed"]))
			lines.append("")
	else:
		lines.append("No data in the selected window.")

	return lines


def render_ratios_section(report: Report) -> list[str]:
	"""Render Claude cache-read and Codex reasoning-output ratios."""
	by_tool = report["totals_by_tool"]
	lines = ["", "## Claude cache-read ratio (tokens, not cost)", ""]
	claude_ratio = by_tool["Claude"].get("cache_read_ratio")
	if by_tool["Claude"]["empty"]:
		lines.append("No Claude usage records in the selected window.")
	else:
		lines.append(
			f"Cache-read input tokens / total input tokens: **{format_ratio(claude_ratio)}** "
			f"({display_token_count(claude_ratio['numerator_tokens'])} / "
			f"{display_token_count(claude_ratio['denominator_tokens'])})."
		)

	lines.extend(["", "## Codex reasoning-output ratio (tokens, not cost)", ""])
	codex_ratio = by_tool["Codex"].get("reasoning_output_ratio")
	if by_tool["Codex"]["empty"]:
		lines.append("No Codex token_count records in the selected window.")
	else:
		lines.append(
			f"Reasoning output tokens / output tokens: **{format_ratio(codex_ratio)}** "
			f"({display_token_count(codex_ratio['numerator_tokens'])} / "
			f"{display_token_count(codex_ratio['denominator_tokens'])})."
		)

	return lines


def render_semantic_notes_section() -> list[str]:
	"""Render the report's token-counting semantics note."""
	return [
		"",
		"## Codex counting semantics (tokens, not cost)",
		"",
		"`total_token_usage` is cumulative per session. `last_token_usage` is the per-event delta, "
		"which is what this report sums.",
		"",
	]


def render_markdown(report: Report):
	"""Render the machine-readable report as concise Markdown."""
	lines = [
		"# Token usage report",
		"",
		"All figures below are tokens, not cost. The report contains no price or dollar estimate.",
		"",
	]
	lines.extend(render_window_section(report))
	lines.extend(render_tool_totals_section(report))
	lines.extend(render_group_tables_section(report))
	lines.extend(render_top_sessions_section(report))
	lines.extend(render_driver_views_section(report))
	lines.extend(render_ratios_section(report))
	lines.extend(render_semantic_notes_section())

	return "\n".join(lines) + "\n"


def make_report(sessions: list[Session], window: Window, sections: Sections) -> Report:
	"""Build the deterministic JSON report object."""
	start, end, display_since, display_until = window
	by_tool, by_model, by_day, by_project, by_role = sections
	driver_data = aggregate_driver_ledger(sessions)
	ordered_sessions = sorted(
		sessions,
		key=lambda session: (
			-session["tokens"]["total_tokens"],
			session["tool"],
			session["session_id"],
		),
	)

	def session_report(session: Session, rank: int) -> SessionReport:
		return {
			"rank": rank,
			"tool": session["tool"],
			"session_id": session["session_id"],
			"transcript_path": session["transcript_path"],
			"project_directory": session["project_directory"],
			"hcom": session["hcom"],
			"models": sorted(session["models"]),
			"tokens": session["tokens"],
			"tool_call_count": session["tool_call_count"],
			"skipped_record_count": session["skipped_record_count"],
			"unattributed_count": session["unattributed_count"],
			"unattributed": session["unattributed"],
			"driver_reconciles": session["driver_reconciles"],
			"driver_ledger": session["driver_ledger"],
		}

	all_sessions: list[SessionReport] = [
		session_report(session, rank)
		for rank, session in enumerate(ordered_sessions, start=1)
	]
	top_sessions = all_sessions[:10]

	for tool in TOOLS:
		if by_tool[tool]["empty"]:
			by_tool[tool].pop("tokens", None)

	return {
		"units": "tokens, not cost",
		"window": {
			"since": display_since,
			"until": display_until,
			"start_utc": start.isoformat(),
			"end_utc_exclusive": end.isoformat(),
		},
		"empty_window": not sessions,
		"partial_data": {
			"partial": any(
				session["skipped_record_count"] > 0 for session in sessions
			),
			"skipped_record_count": sum(
				session["skipped_record_count"] for session in sessions
			),
			"skipped_record_counts": {
				tool: sum(
					session["skipped_record_count"]
					for session in sessions
					if session["tool"] == tool
				)
				for tool in TOOLS
			},
		},
		"session_count": len(sessions),
		"totals_by_tool": by_tool,
		"totals_by_model": by_model,
		"totals_by_day": by_day,
		"totals_by_project": by_project,
		"totals_by_role": by_role,
		"driver_ledger": driver_data["driver_ledger"],
		"driver_reconciliation": driver_data,
		"sessions": all_sessions,
		"top_sessions": top_sessions,
	}


def parse_arguments():
	"""Parse command-line bounds and retain the parser for validation errors."""
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--since", type=parse_date, help="inclusive UTC date, YYYY-MM-DD")
	parser.add_argument("--until", type=parse_date, help="inclusive UTC date, YYYY-MM-DD")
	parser.add_argument("--days", type=int, help="window ending now in UTC (default: 7)")
	arguments = parser.parse_args()
	arguments.parser = parser
	return arguments


def transcript_paths():
	"""Return sorted Claude and Codex transcript paths that currently exist."""
	claude_paths = sorted(CLAUDE_ROOT.rglob("*.jsonl")) if CLAUDE_ROOT.is_dir() else []
	codex_paths = []
	seen = set()

	for root in CODEX_ROOTS:
		if not root.is_dir():
			continue

		for path in root.rglob("rollout-*.jsonl"):
			if path not in seen:
				seen.add(path)
				codex_paths.append(path)

	return claude_paths, sorted(codex_paths)


def write_report(report: Report):
	"""Overwrite the fixed Markdown and JSON report paths."""
	REPORT_DIRECTORY.mkdir(parents=True, exist_ok=True)
	json_path = REPORT_DIRECTORY / "latest.json"
	markdown_path = REPORT_DIRECTORY / "latest.md"

	json_path.write_text(
		json.dumps(report, indent=2, sort_keys=True) + "\n",
		encoding="utf-8",
	)
	markdown_path.write_text(render_markdown(report), encoding="utf-8")

	return markdown_path, json_path


def main():
	"""Read transcripts, write both reports, and print only a bounded summary."""
	arguments = parse_arguments()
	window = build_window(arguments)
	start, end, _, _ = window
	claude_paths, codex_paths = transcript_paths()
	sessions: list[Session] = []

	for path in claude_paths:
		session = parse_claude_session(path, start, end)
		if session is not None:
			sessions.append(session)

	for path in codex_paths:
		session = parse_codex_session(path, start, end)
		if session is not None:
			sessions.append(session)

	by_session_id, by_path = load_hcom_labels()
	for session in sessions:
		apply_hcom_label(session, by_session_id, by_path)

	report = make_report(sessions, window, aggregate(sessions))
	markdown_path, json_path = write_report(report)
	print(
		f"Wrote {report['session_count']} sessions, tokens not cost, "
		f"to {markdown_path} and {json_path}"
	)


if __name__ == "__main__":
	main()
