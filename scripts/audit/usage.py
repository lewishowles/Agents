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
from typing import Iterator


REPO_ROOT = Path(__file__).resolve().parents[2]
AUDIT_DIRECTORY = Path(__file__).resolve().parent

# Both direct script execution and ``from scripts.audit import usage`` are
# supported; each invocation style needs the sibling audit modules on sys.path.
if str(AUDIT_DIRECTORY) not in sys.path:
	sys.path.insert(0, str(AUDIT_DIRECTORY))

from metrics import (  # noqa: E402
	COMMAND_TEXT_LIMIT,
	RESULT_TEXT_LIMIT,
	blocks,
	classify_bash_command,
)
from redundancy import repeated_call_indexes  # noqa: E402
from usage_types import (  # noqa: E402
	AggregateRow,
	CODEX_FIELDS,
	DriverCall,
	DriverClassification,
	DriverLedgerRow,
	DriverReconciliation,
	DriverRule,
	DriverTargetExtractor,
	Group,
	HcomLabel,
	PartialData,
	RatioData,
	RecordStats,
	Report,
	Sections,
	Session,
	SessionReport,
	TOKEN_SCHEMAS,
	TokenSchema,
	TokenTotals,
	UNATTRIBUTED,
	Unattributed,
	Window,
	WindowReport,
)


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

# Match a quoted or bare JavaScript property and capture its quoted string value.
EMBEDDED_JS_ARGUMENT_PATTERN = (
	r"""(?:['"]{key}['"]|{key})\s*:\s*"""
	r"""("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')"""
)

# Match the first file path named by an apply_patch source string.
EMBEDDED_PATCH_PATH_PATTERN = re.compile(
	r"\*\*\* (?:Update|Add|Delete) File:\s*([^\s\\]+)"
)

# Match the tool name in a nested Codex exec source string.
EMBEDDED_TOOL_CALL_PATTERN = re.compile(
	r"\btools\.([A-Za-z_][A-Za-z0-9_]*)\s*\("
)


def parse_date(value: str) -> datetime.date:
	"""Parse a command-line date as a UTC calendar date.

	Args:
		value: The YYYY-MM-DD value supplied by the caller.

	Returns:
		The parsed calendar date.
	"""
	try:
		return datetime.date.fromisoformat(value)
	except ValueError as error:
		raise argparse.ArgumentTypeError("expected YYYY-MM-DD") from error


def parse_timestamp(value: object) -> datetime.datetime | None:
	"""Parse a transcript timestamp, treating naive values as UTC.

	Args:
		value: The timestamp value read from a JSONL record.

	Returns:
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


def build_window(arguments: argparse.Namespace) -> Window:
	"""Build the half-open UTC window selected by the command line.

	Args:
		arguments: Parsed command-line options containing the date bounds.

	Returns:
		The UTC start, exclusive end, and display bounds for the report.
	"""
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


def records(
	path: Path,
	supported_types: tuple[str, ...],
	record_stats: RecordStats,
) -> Iterator[dict[str, object]]:
	"""Yield supported JSON objects and count skipped transcript records.

	Args:
		path: Transcript path to read as JSONL.
		supported_types: Record types accepted by the caller's parser.
		record_stats: Mutable counter updated for malformed or unsupported records.

	Returns:
		An iterator over supported JSON object records.
	"""
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


def number(value: object) -> int:
	"""Return a non-negative integer token value for a parsed field.

	Args:
		value: Parsed token field value.

	Returns:
		A finite value truncated toward zero and clamped to zero, or zero for an
		unsupported or non-finite value.
	"""
	if isinstance(value, bool) or not isinstance(value, (int, float)):
		return 0

	if isinstance(value, float) and not math.isfinite(value):
		return 0

	return max(0, int(value))


def safe_text(value: object) -> str:
	"""Return a single-line string suitable for safe length measurement.

	Args:
		value: Value to normalise when it is a string.

	Returns:
		A stripped, single-line string, or an empty string for other values.
	"""
	if not isinstance(value, str):
		return ""

	return value.replace("\x00", "").replace("\r", " ").replace("\n", " ").strip()


def object_input(value: object) -> dict[str, object]:
	"""Decode a tool input object when a transcript stores it as JSON text.

	Args:
		value: Tool input object or JSON text.

	Returns:
		The decoded object, or an empty object when decoding is unsupported.
	"""
	if isinstance(value, dict):
		return value

	if not isinstance(value, str):
		return {}

	try:
		decoded = json.loads(value)
	except (TypeError, ValueError):
		return {}

	return decoded if isinstance(decoded, dict) else {}


def decode_js_string(value: object) -> str:
	"""Decode one quoted JavaScript string literal without parsing the source.

	Args:
		value: Quoted JavaScript string literal.

	Returns:
		The decoded single-line string, or an empty string for invalid input.
	"""
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


def embedded_js_argument(source: object, key: str) -> str:
	"""Extract one quoted argument from a nested JavaScript tool call.

	Args:
		source: JavaScript source containing a nested tool call.
		key: Property name whose quoted value should be extracted.

	Returns:
		The decoded property value, or an empty string when it is absent.
	"""
	if not isinstance(source, str):
		return ""

	pattern = EMBEDDED_JS_ARGUMENT_PATTERN.format(key=re.escape(key))
	match = re.search(pattern, source)
	return decode_js_string(match.group(1)) if match else ""


def embedded_patch_path(source: object) -> str:
	"""Extract the first safe target path from an apply_patch source string.

	Args:
		source: apply_patch source containing a file header.

	Returns:
		The first safe target path, or an empty string when no header is present.
	"""
	if not isinstance(source, str):
		return ""

	match = EMBEDDED_PATCH_PATH_PATTERN.search(source)
	return safe_text(match.group(1)) if match else ""


def embedded_tool_call(value: object) -> tuple[str, dict[str, object]] | None:
	"""Extract the real tool call nested inside a Codex ``exec`` source string.

	Args:
		value: Codex exec source containing a nested tool call.

	Returns:
		The extracted tool name and input, or None when no call is present.
	"""
	if not isinstance(value, str):
		return None

	match = EMBEDDED_TOOL_CALL_PATTERN.search(value)
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


def result_text(value: object) -> str:
	"""Extract result text for bounded length measurement without reporting it.

	Args:
		value: Tool result value, possibly nested in content fields.

	Returns:
		The bounded-measurement source text, or an empty string when absent.
	"""
	if isinstance(value, str):
		return value

	if isinstance(value, list):
		return " ".join(result_text(item) for item in value)

	if isinstance(value, dict):
		for key in ("content", "output", "result", "text"):
			if key in value:
				return result_text(value[key])

	return ""


def tool_result_failed(value: object) -> bool:
	"""Return whether a tool result explicitly reports a failure.

	Args:
		value: Tool result value to inspect.

	Returns:
		True when the result contains an error flag, otherwise False.
	"""
	return isinstance(value, dict) and bool(value.get("is_error") or value.get("isError"))


def command_input(tool_input: dict[str, object]) -> str:
	"""Return a command from Claude or Codex tool input.

	Args:
		tool_input: Decoded tool input object.

	Returns:
		The first non-empty command value, or an empty string when absent.
	"""
	for key in ("command", "cmd"):
		command = safe_text(tool_input.get(key))
		if command:
			return command

	return ""


def extract_command_target(name: str, tool_input: dict[str, object]) -> str:
	"""Return a command target, including an empty target when absent.

	Args:
		name: Tool name supplied by the classification rule.
		tool_input: Decoded tool input object.

	Returns:
		The command target, or an empty string when absent.
	"""
	return command_input(tool_input)


def extract_file_target(name: str, tool_input: dict[str, object]) -> str | None:
	"""Return a non-empty file target from tool input.

	Args:
		name: Tool name supplied by the classification rule.
		tool_input: Decoded tool input object.

	Returns:
		The normalised file target, or None when absent.
	"""
	target = safe_text(tool_input.get("file_path") or tool_input.get("path"))
	return target or None


def extract_skill_target(name: str, tool_input: dict[str, object]) -> str | None:
	"""Return a non-empty skill target from tool input.

	Args:
		name: Tool name supplied by the classification rule.
		tool_input: Decoded tool input object.

	Returns:
		The normalised skill target, or None when absent.
	"""
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
	"""Return a hook name from tool input, falling back to the tool name.

	Args:
		name: Hook tool name used as the fallback.
		tool_input: Decoded tool input object.

	Returns:
		The hook target, or the tool name when absent.
	"""
	return safe_text(tool_input.get("name") or name)


def extract_name_target(name: str, tool_input: dict[str, object]) -> str:
	"""Return the tool name when it is also the classification target.

	Args:
		name: Tool name used as the target.
		tool_input: Decoded tool input object.

	Returns:
		The supplied tool name.
	"""
	return name


def driver_rule(name: str) -> DriverRule | None:
	"""Return the table or dynamic rule for a tool name.

	Args:
		name: Tool name to classify.

	Returns:
		The matching classification rule, or None for unsupported tools.
	"""
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
	"""Return the tool identity and bounded input used for repeat detection.

	Args:
		name: Tool name being classified.
		category: Classification category for the tool.
		target: Extracted target used by the classifier.

	Returns:
		The repeat-detection tool name and bounded input object.
	"""
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
	"""Build a classification from its category, target, and repeat identity.

	Args:
		name: Tool name being classified.
		category: Classification category for the tool.
		target: Extracted target used by the classifier.
		classification_key: Optional explicit grouping key.

	Returns:
		The completed driver classification.
	"""
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
	"""Classify an unknown tool using its safest available target.

	Args:
		name: Unknown tool name.
		tool_input: Decoded tool input object.

	Returns:
		A fallback classification using the safest available target.
	"""
	target = safe_text(
		tool_input.get("file_path")
		or tool_input.get("path")
		or tool_input.get("subagent_type")
		or name
	)
	return build_driver_classification(name, "tool", target, name)


def driver_classification(
	name: object,
	tool_input: dict[str, object],
) -> DriverClassification | None:
	"""Classify one tool call and return its safe key and estimate target.

	Args:
		name: Tool name read from a transcript record.
		tool_input: Decoded tool input object.

	Returns:
		The safe classification, or None when the tool cannot be classified.
	"""
	if not isinstance(name, str) or not name:
		return None

	rule = driver_rule(name)
	if rule is None:
		return fallback_driver_classification(name, tool_input)

	target = rule["target_extractor"](name, tool_input)
	if target is None:
		return None

	return build_driver_classification(name, rule["category"], target)


def new_driver_call(name: object, tool_input: dict[str, object]) -> DriverCall:
	"""Create an internal tool-call record without retaining raw result content.

	Args:
		name: Tool name read from a transcript record.
		tool_input: Decoded tool input object.

	Returns:
		The bounded internal tool-call record.
	"""
	classification = driver_classification(name, tool_input)
	return {
		"name": name,
		"input": tool_input,
		"classification": classification,
		"result": "",
		"failed": False,
	}


def new_session_parse_state() -> tuple[dict[str, DriverCall], RecordStats]:
	"""Create driver correlation and record-skipping state for one session.

	Returns:
		Empty response-correlation mapping and record-skipping counter.
	"""
	return {}, {"skipped_record_count": 0}


def append_driver_call(
	session: Session,
	calls_by_id: dict[str, DriverCall],
	call: DriverCall,
	call_id: object = None,
) -> None:
	"""Append one in-window driver call and register its response identifier.

	Args:
		session: Session receiving the driver call.
		calls_by_id: Response identifier mapping for correlated results.
		call: Bounded driver call to append.
		call_id: Optional response identifier for the call.

	Returns:
		None. The session and mapping are updated in place.
	"""
	session["_driver_calls"].append(call)
	session["tool_call_count"] += 1

	if isinstance(call_id, str) and call_id:
		calls_by_id[call_id] = call


def update_driver_call_result(
	calls_by_id: dict[str, DriverCall],
	call_id: object,
	result: object,
	failed: bool,
) -> None:
	"""Attach one correlated result to a previously recorded driver call.

	Args:
		calls_by_id: Response identifier mapping for recorded calls.
		call_id: Response identifier to resolve.
		result: Tool result value to measure.
		failed: Whether the result explicitly reports failure.

	Returns:
		None. The matching call is updated when the identifier is known.
	"""
	call = calls_by_id.get(call_id)
	if call is not None:
		call["result"] = result_text(result)
		call["failed"] = failed


def estimated_payload_tokens(call: DriverCall) -> int:
	"""Estimate one driver payload from bounded command, target, and result text.

	Args:
		call: Bounded driver call to measure.

	Returns:
		The estimated payload size in tokens.
	"""
	classification = call["classification"]
	if classification is None:
		target = safe_text(call.get("name"))
	else:
		target = classification["target"]

	parts = [target[:COMMAND_TEXT_LIMIT], safe_text(call["result"])[:RESULT_TEXT_LIMIT]]
	character_count = sum(len(part) for part in parts)
	return math.ceil(character_count / 4) if character_count else 0


def finalise_driver_ledger(session: Session) -> None:
	"""Build ranked driver rows and explicit unattributed counts for a session.

	Args:
		session: Session whose parsed driver calls should be aggregated.

	Returns:
		None. Driver ledger fields are updated in the session.
	"""
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
	"""Return the token field schema for one runtime.

	Args:
		tool: Runtime name whose token fields are needed.

	Returns:
		The matching token schema, defaulting to Codex fields.
	"""
	return TOKEN_SCHEMAS.get(tool, TOKEN_SCHEMAS["Codex"])


def empty_totals(tool: str) -> TokenTotals:
	"""Create the token fields used by one tool's aggregate.

	Args:
		tool: Runtime name whose token fields are needed.

	Returns:
		A zero-valued token aggregate for the runtime.
	"""
	schema = token_schema(tool)
	totals = {field: 0 for field in schema["fields"]}
	totals["total_tokens"] = 0

	for field in schema["total_input_fields"]:
		totals[field] = 0

	return totals


def usage_totals(usage: dict[str, object], tool: str) -> TokenTotals:
	"""Normalise one Claude or Codex usage object into token fields.

	Args:
		usage: Raw usage object from a transcript record.
		tool: Runtime name whose token fields are needed.

	Returns:
		The normalised non-negative token totals.
	"""
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


def add_totals(target: TokenTotals, source: TokenTotals, tool: str) -> None:
	"""Add one normalised usage object to an aggregate.

	Args:
		target: Aggregate updated in place.
		source: Normalised usage totals to add.
		tool: Runtime name whose total-input fields are needed.

	Returns:
		None. The target aggregate is updated in place.
	"""
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
) -> None:
	"""Add one in-window event to session, model, and day totals.

	Args:
		session: Session receiving the usage event.
		usage: Raw usage object from the transcript.
		model: Model name used by the event.
		day: UTC calendar day used by the event.
		tool: Runtime name whose totals are being updated.

	Returns:
		None. Session, model, and day aggregates are updated in place.
	"""
	normalised = usage_totals(usage, tool)
	if not normalised["total_tokens"]:
		return

	add_totals(session["tokens"], normalised, tool)
	add_totals(session["models"].setdefault(model, empty_totals(tool)), normalised, tool)
	add_totals(session["days"].setdefault(day, empty_totals(tool)), normalised, tool)


def new_session(tool: str, session_id: str, path: Path, project_directory: str) -> Session:
	"""Create the internal representation for one transcript session.

	Args:
		tool: Runtime that produced the transcript.
		session_id: Stable identifier for the transcript session.
		path: Transcript path used in the report.
		project_directory: Initial project directory from the transcript location.

	Returns:
		A zero-valued internal session model.
	"""
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
	"""Attach parser bookkeeping and omit sessions with no usage or skipped records.

	Args:
		session: Parsed session to finalise.
		record_stats: Record-skipping counter from transcript reading.

	Returns:
		The session when it has usage or skipped records, otherwise None.
	"""
	session["skipped_record_count"] = record_stats["skipped_record_count"]
	finalise_driver_ledger(session)

	if session["tokens"]["total_tokens"] or session["skipped_record_count"]:
		return session

	return None


def in_window(
	timestamp: datetime.datetime | None,
	start: datetime.datetime,
	end: datetime.datetime,
) -> bool:
	"""Return whether a timestamp belongs to the selected half-open window.

	Args:
		timestamp: Timestamp to test.
		start: Inclusive UTC window start.
		end: Exclusive UTC window end.

	Returns:
		True when the timestamp is inside the window, otherwise False.
	"""
	return timestamp is not None and start <= timestamp < end


def update_claude_metadata(session: Session, record: dict[str, object]) -> None:
	"""Update the project directory from one Claude record.

	Args:
		session: Session receiving metadata.
		record: Claude transcript record to inspect.

	Returns:
		None. The session project directory is updated in place when present.
	"""
	cwd = record.get("cwd")
	if isinstance(cwd, str) and cwd:
		session["project_directory"] = cwd


def append_claude_hook_call(
	session: Session,
	calls_by_id: dict[str, DriverCall],
	record: dict[str, object],
	timestamp: datetime.datetime | None,
	start: datetime.datetime,
	end: datetime.datetime,
) -> None:
	"""Record one in-window Claude hook attachment as a driver call.

	Args:
		session: Session receiving the hook call.
		calls_by_id: Response identifier mapping for correlated results.
		record: Claude transcript record to inspect.
		timestamp: Parsed UTC timestamp for the record.
		start: Inclusive UTC window start.
		end: Exclusive UTC window end.

	Returns:
		None. An in-window hook attachment is appended when valid.
	"""
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
	timestamp: datetime.datetime | None,
	start: datetime.datetime,
	end: datetime.datetime,
) -> None:
	"""Correlate Claude tool calls and their results for one record.

	Args:
		session: Session receiving in-window tool calls.
		calls_by_id: Response identifier mapping for correlated results.
		record: Claude transcript record to inspect.
		timestamp: Parsed UTC timestamp for the record.
		start: Inclusive UTC window start.
		end: Exclusive UTC window end.

	Returns:
		None. Tool calls and results are recorded in the session state.
	"""
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
	timestamp: datetime.datetime | None,
	start: datetime.datetime,
	end: datetime.datetime,
) -> tuple[dict[str, object], str, str] | None:
	"""Return one in-window Claude usage event with its model and day.

	Args:
		record: Claude transcript record to inspect.
		timestamp: Parsed UTC timestamp for the record.
		start: Inclusive UTC window start.
		end: Exclusive UTC window end.

	Returns:
		The usage object, model, and UTC day, or None when out of scope.
	"""
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


def aggregate_claude_usage(
	session: Session,
	event: tuple[dict[str, object], str, str] | None,
) -> None:
	"""Add one parsed Claude usage event to the session totals.

	Args:
		session: Session receiving the usage event.
		event: Parsed usage object, model, and UTC day, or None.

	Returns:
		None. Session aggregates are updated in place when an event is present.
	"""
	if event is None:
		return

	usage, model, day = event
	add_session_usage(session, usage, model, day, "Claude")


def parse_claude_session(
	path: Path,
	start: datetime.datetime,
	end: datetime.datetime,
) -> Session | None:
	"""Parse in-window Claude usage records from one transcript.

	Args:
		path: Claude transcript path to parse.
		start: Inclusive UTC window start.
		end: Exclusive UTC window end.

	Returns:
		The parsed session, or None when it has no usage or skipped records.
	"""
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


def codex_delta(
	last_usage: object,
	total_usage: object,
	previous_total: object,
) -> TokenTotals | None:
	"""Return one Codex event delta, preferring the recorded per-event value.

	Args:
		last_usage: Per-event token usage, when recorded.
		total_usage: Cumulative token usage, when recorded.
		previous_total: Previous cumulative token usage for this session.

	Returns:
		The event delta, or None when neither usage representation is available.
	"""
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
	"""Update Codex session metadata and return the current model.

	Args:
		session: Session receiving metadata.
		record: Codex transcript record to inspect.
		model: Current model name before this record.

	Returns:
		The current model name after applying the record.
	"""
	payload = record.get("payload")
	if not isinstance(payload, dict):
		return model

	record_type = record.get("type")
	if record_type == "session_meta":
		metadata_session_id = payload.get("session_id") or payload.get("id")
		if isinstance(metadata_session_id, str) and metadata_session_id:
			session["session_id"] = metadata_session_id

	elif record_type == "turn_context":
		context_model = payload.get("model")
		if isinstance(context_model, str) and context_model:
			model = context_model

	if record_type in ("session_meta", "turn_context"):
		cwd = payload.get("cwd")
		if isinstance(cwd, str) and cwd:
			session["project_directory"] = cwd

	return model


def decode_codex_tool_call(payload: dict[str, object]) -> tuple[object, dict[str, object]]:
	"""Decode a Codex response item, including embedded JavaScript calls.

	Args:
		payload: Codex response-item payload to decode.

	Returns:
		The decoded tool name and input object.
	"""
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
	timestamp: datetime.datetime | None,
	start: datetime.datetime,
	end: datetime.datetime,
) -> None:
	"""Correlate Codex response-item tool calls and their results.

	Args:
		session: Session receiving in-window tool calls.
		calls_by_id: Response identifier mapping for correlated results.
		record: Codex transcript record to inspect.
		timestamp: Parsed UTC timestamp for the record.
		start: Inclusive UTC window start.
		end: Exclusive UTC window end.

	Returns:
		None. Tool calls and results are recorded in the session state.
	"""
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
	"""Return a Codex token delta and the next cumulative total.

	Args:
		record: Codex transcript record to inspect.
		previous_total: Previous cumulative token usage for this session.

	Returns:
		The event delta and the cumulative total for the next record.
	"""
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
	timestamp: datetime.datetime | None,
	start: datetime.datetime,
	end: datetime.datetime,
) -> None:
	"""Add one in-window Codex token delta to the session totals.

	Args:
		session: Session receiving the usage event.
		delta: Parsed token delta, or None when unavailable.
		model: Model name used by the event.
		timestamp: Parsed UTC timestamp for the event.
		start: Inclusive UTC window start.
		end: Exclusive UTC window end.

	Returns:
		None. Session aggregates are updated in place when the event is in scope.
	"""
	if not in_window(timestamp, start, end) or not isinstance(delta, dict):
		return

	add_session_usage(session, delta, model, timestamp.date().isoformat(), "Codex")


def parse_codex_session(
	path: Path,
	start: datetime.datetime,
	end: datetime.datetime,
) -> Session | None:
	"""Parse in-window Codex token-count events from one rollout transcript.

	Args:
		path: Codex rollout transcript path to parse.
		start: Inclusive UTC window start.
		end: Exclusive UTC window end.

	Returns:
		The parsed session, or None when it has no usage or skipped records.
	"""
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


def normalise_path(value: object) -> str:
	"""Return a comparable absolute path for an optional hcom value.

	Args:
		value: Optional path value read from hcom.

	Returns:
		A comparable absolute path, or an empty string when absent.
	"""
	if not isinstance(value, str) or not value:
		return ""

	try:
		return str(Path(value).expanduser().resolve())
	except OSError:
		return os.path.abspath(os.path.expanduser(value))


def hcom_role(tag: object, parent_name: object) -> str:
	"""Extract the repository-scoped role suffix from an hcom label.

	Args:
		tag: Optional hcom tag.
		parent_name: Optional parent agent name used as fallback.

	Returns:
		The repository-scoped role suffix, or ``unattributed`` when absent.
	"""
	value = tag or parent_name or ""
	if not isinstance(value, str) or not value:
		return "unattributed"

	return value.rsplit("-", 1)[-1] or "unattributed"


def load_hcom_labels() -> tuple[dict[str, HcomLabel], dict[str, HcomLabel]]:
	"""Load best-effort transcript labels from hcom's read-only database.

	Returns:
		Mappings keyed by session id and normalised transcript path.
	"""
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
) -> None:
	"""Join one parsed session to hcom, retaining an explicit fallback label.

	Args:
		session: Parsed session receiving its hcom label.
		by_session_id: Labels indexed by transcript session id.
		by_path: Labels indexed by normalised transcript path.

	Returns:
		None. The session hcom label is updated in place when matched.
	"""
	label = by_path.get(normalise_path(session["transcript_path"]))
	if label is None:
		label = by_session_id.get(session["session_id"])

	if label is not None:
		session["hcom"] = dict(label)


def ratio(numerator: int, denominator: int) -> float | None:
	"""Return a stable ratio, or None when the denominator is zero.

	Args:
		numerator: Ratio numerator.
		denominator: Ratio denominator.

	Returns:
		The ratio rounded to six decimal places, or None for a zero denominator.
	"""
	if not denominator:
		return None

	return round(numerator / denominator, 6)


def ratio_data(numerator: int, denominator: int) -> RatioData:
	"""Return ratio inputs as well as the calculated ratio for JSON consumers.

	Args:
		numerator: Ratio numerator in tokens.
		denominator: Ratio denominator in tokens.

	Returns:
		A serialisable ratio object containing both inputs and the result.
	"""
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
) -> None:
	"""Add a session or event aggregate to a grouped report section.

	Args:
		group: Group receiving the aggregate.
		key: Grouping key for the aggregate.
		tool: Runtime name for the aggregate.
		session_count: Number of sessions represented by the aggregate.
		tokens: Normalised token totals to add.

	Returns:
		None. The grouped aggregate is updated in place.
	"""
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
	"""Build all report breakdowns from parsed sessions.

	Args:
		sessions: Parsed sessions to aggregate.

	Returns:
		Tool, model, day, project, and hcom-role report breakdowns.
	"""
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
	"""Combine session driver rows into one ranked ledger and reconciliation.

	Args:
		sessions: Parsed sessions whose driver ledgers should be combined.

	Returns:
		The ranked aggregate ledger and reconciliation counts.
	"""
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


def display_token_count(tokens: int) -> str:
	"""Format a token count for the Markdown report.

	Args:
		tokens: Token count to format.

	Returns:
		The count with thousands separators.
	"""
	return f"{tokens:,}"


def display_path(value: object) -> str:
	"""Keep grouped paths safe in a Markdown table.

	Args:
		value: Path or other value to display.

	Returns:
		A string with Markdown table separators escaped.
	"""
	return str(value).replace("|", "\\|").replace("\n", " ")


def format_ratio(data: RatioData) -> str:
	"""Format a ratio row for Markdown.

	Args:
		data: Ratio object containing the calculated value.

	Returns:
		A percentage string, or ``n/a`` when no ratio is available.
	"""
	if data["ratio"] is None:
		return "n/a"

	return f"{data['ratio'] * 100:.2f}%"


def markdown_table_for_group(group: Group) -> list[str]:
	"""Render grouped token totals as a deterministic Markdown table.

	Args:
		group: Grouped token totals to render.

	Returns:
		Markdown table lines, or a no-data line when the group is empty.
	"""
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
) -> list[str]:
	"""Render ranked driver rows without including raw transcript payloads.

	Args:
		rows: Ranked attributed driver rows to render.
		unattributed: Aggregate row for calls without a classification.

	Returns:
		Markdown table lines, or a no-data line when no calls exist.
	"""
	lines = [
		(
			"| Rank | Category | Key | Count | Payload estimate (tokens) | "
			"Method | Failures | Retries | Repeated |"
		),
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
	"""Render the report window, empty-window, and partial-data sections.

	Args:
		report: Serialised report containing window and partial-data details.

	Returns:
		Markdown lines for the report window sections.
	"""
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
	"""Render token totals grouped by runtime tool.

	Args:
		report: Serialised report containing tool totals.

	Returns:
		Markdown lines for the tool totals section.
	"""
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
	"""Render model, day, project, and hcom role totals.

	Args:
		report: Serialised report containing grouped totals.

	Returns:
		Markdown lines for the grouped totals sections.
	"""
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
	"""Render the top sessions ranked by total tokens.

	Args:
		report: Serialised report containing ranked sessions.

	Returns:
		Markdown lines for the top sessions section.
	"""
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
	"""Render aggregate and per-session driver ledger views.

	Args:
		report: Serialised report containing aggregate and session ledgers.

	Returns:
		Markdown lines for the driver ledger sections.
	"""
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
	"""Render Claude cache-read and Codex reasoning-output ratios.

	Args:
		report: Serialised report containing runtime ratio data.

	Returns:
		Markdown lines for the ratio sections.
	"""
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
	"""Render the report's token-counting semantics note.

	Returns:
		Markdown lines describing Codex token-counting semantics.
	"""
	return [
		"",
		"## Codex counting semantics (tokens, not cost)",
		"",
		"`total_token_usage` is cumulative per session. `last_token_usage` is the per-event delta, "
		"which is what this report sums.",
		"",
	]


def render_markdown(report: Report) -> str:
	"""Render the machine-readable report as concise Markdown.

	Args:
		report: Serialised report to render.

	Returns:
		The complete Markdown report with a trailing newline.
	"""
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
	"""Build the deterministic JSON report object.

	Args:
		sessions: Parsed sessions included in the selected window.
		window: UTC window and display bounds for the report.
		sections: Precomputed report breakdowns.

	Returns:
		The deterministic serialisable report object.
	"""
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
		"""Build one serialised session row.

		Args:
			session: Parsed session to serialise.
			rank: One-based ranking for the session.

		Returns:
			The serialised session row.
		"""
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

	totals_by_tool: dict[str, AggregateRow] = {
		tool: {
			field: value
			for field, value in row.items()
			if not (row["empty"] and field == "tokens")
		}
		for tool, row in by_tool.items()
	}

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
		"totals_by_tool": totals_by_tool,
		"totals_by_model": by_model,
		"totals_by_day": by_day,
		"totals_by_project": by_project,
		"totals_by_role": by_role,
		"driver_ledger": driver_data["driver_ledger"],
		"driver_reconciliation": driver_data,
		"sessions": all_sessions,
		"top_sessions": top_sessions,
	}


def parse_arguments() -> argparse.Namespace:
	"""Parse command-line bounds and retain the parser for validation errors.

	Returns:
		Parsed command-line options with the parser attached for validation errors.
	"""
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--since", type=parse_date, help="inclusive UTC date, YYYY-MM-DD")
	parser.add_argument("--until", type=parse_date, help="inclusive UTC date, YYYY-MM-DD")
	parser.add_argument("--days", type=int, help="window ending now in UTC (default: 7)")
	arguments = parser.parse_args()
	arguments.parser = parser
	return arguments


def transcript_paths() -> tuple[list[Path], list[Path]]:
	"""Return sorted Claude and Codex transcript paths that currently exist.

	Returns:
		Sorted Claude paths followed by sorted Codex rollout paths.
	"""
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


def write_report(report: Report) -> tuple[Path, Path]:
	"""Overwrite the fixed Markdown and JSON report paths.

	Args:
		report: Serialised report to write.

	Returns:
		Markdown path followed by JSON path.
	"""
	REPORT_DIRECTORY.mkdir(parents=True, exist_ok=True)
	json_path = REPORT_DIRECTORY / "latest.json"
	markdown_path = REPORT_DIRECTORY / "latest.md"

	json_path.write_text(
		json.dumps(report, indent=2, sort_keys=True) + "\n",
		encoding="utf-8",
	)
	markdown_path.write_text(render_markdown(report), encoding="utf-8")

	return markdown_path, json_path


def main() -> None:
	"""Read transcripts, write both reports, and print only a bounded summary.

	Returns:
		None. Reports are written and a bounded summary is printed.
	"""
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
