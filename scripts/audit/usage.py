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

import argparse
import collections
import datetime
import json
import math
import os
import re
import sqlite3
import sys
from pathlib import Path


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
CLAUDE_FIELDS = (
	"input_tokens",
	"cache_creation_input_tokens",
	"cache_read_input_tokens",
	"output_tokens",
)
CODEX_FIELDS = (
	"input_tokens",
	"cached_input_tokens",
	"reasoning_output_tokens",
	"output_tokens",
	"total_tokens",
)
TOOLS = ("Claude", "Codex")
DRIVER_METHOD = "chars/4"
UNATTRIBUTED = {
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


def build_window(arguments):
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


def records(path):
	"""Yield JSON objects from a JSONL file, ignoring malformed lines."""
	try:
		with path.open(encoding="utf-8", errors="replace") as handle:
			for line in handle:
				try:
					record = json.loads(line)
				except (TypeError, ValueError):
					continue

				if isinstance(record, dict):
					yield record
	except OSError:
		return


def number(value):
	"""Return a non-negative integer token value for a parsed field."""
	if isinstance(value, bool) or not isinstance(value, (int, float)):
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


def driver_classification(name, tool_input):
	"""Classify one tool call and return its safe key and estimate target."""
	if not isinstance(name, str) or not name:
		return None

	if name in ("Bash", "exec_command"):
		command = command_input(tool_input)
		return {
			"category": "bash",
			"key": classify_bash_command(command) or "other",
			"target": command,
			"repeat_name": "Bash",
			"repeat_input": {"command": command},
		}

	if name in ("Read", "Write", "Edit"):
		file_path = safe_text(tool_input.get("file_path") or tool_input.get("path"))
		if not file_path:
			return None

		return {
			"category": name.lower(),
			"key": file_path,
			"target": file_path,
			"repeat_name": name,
			"repeat_input": {"file_path": file_path},
		}

	if name == "Skill":
		skill_name = safe_text(tool_input.get("skill") or tool_input.get("name"))
		if not skill_name:
			return None

		return {
			"category": "skill",
			"key": skill_name,
			"target": skill_name,
			"repeat_name": name,
			"repeat_input": {},
		}

	if name == "Hook" or name.lower().startswith("hook"):
		hook_name = safe_text(tool_input.get("name") or name)
		return {
			"category": "hook",
			"key": hook_name,
			"target": hook_name,
			"repeat_name": name,
			"repeat_input": {},
		}

	if name.startswith("mcp__") or name.startswith("mcp_"):
		return {
			"category": "mcp",
			"key": name,
			"target": name,
			"repeat_name": name,
			"repeat_input": {},
		}

	return {
		"category": "tool",
		"key": name,
		"target": safe_text(
			tool_input.get("file_path")
			or tool_input.get("path")
			or tool_input.get("subagent_type")
			or name
		),
		"repeat_name": name,
		"repeat_input": {},
	}


def new_driver_call(name, tool_input):
	"""Create an internal tool-call record without retaining raw result content."""
	classification = driver_classification(name, tool_input)
	return {
		"name": name,
		"input": tool_input,
		"classification": classification,
		"result": "",
		"failed": False,
	}


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


def finalise_driver_ledger(session):
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
	rows = {}
	unattributed_count = 0
	unattributed_payload = 0
	failed_before = {}

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


def empty_totals(tool):
	"""Create the token fields used by one tool's aggregate."""
	fields = CLAUDE_FIELDS if tool == "Claude" else CODEX_FIELDS
	totals = {field: 0 for field in fields}
	totals["total_tokens"] = 0

	if tool == "Claude":
		totals["total_input_tokens"] = 0

	return totals


def usage_totals(usage, tool):
	"""Normalise one Claude or Codex usage object into token fields."""
	fields = CLAUDE_FIELDS if tool == "Claude" else CODEX_FIELDS
	values = {field: number(usage.get(field)) for field in fields}

	if tool == "Claude":
		values["total_input_tokens"] = sum(
			values[field]
			for field in (
				"input_tokens",
				"cache_creation_input_tokens",
				"cache_read_input_tokens",
			)
		)
		values["total_tokens"] = values["total_input_tokens"] + values["output_tokens"]
	elif not values["total_tokens"]:
		values["total_tokens"] = values["input_tokens"] + values["output_tokens"]

	return values


def add_totals(target, source, tool):
	"""Add one normalised usage object to an aggregate."""
	for field, value in source.items():
		if field != "total_input_tokens" or tool == "Claude":
			target[field] = target.get(field, 0) + value

	if tool == "Claude":
		target["total_input_tokens"] = sum(
			target[field]
			for field in (
				"input_tokens",
				"cache_creation_input_tokens",
				"cache_read_input_tokens",
			)
		)
		target["total_tokens"] = target["total_input_tokens"] + target["output_tokens"]


def add_session_usage(session, usage, model, day, tool):
	"""Add one in-window event to session, model, and day totals."""
	normalised = usage_totals(usage, tool)
	if not normalised["total_tokens"]:
		return

	add_totals(session["tokens"], normalised, tool)
	add_totals(session["models"].setdefault(model, empty_totals(tool)), normalised, tool)
	add_totals(session["days"].setdefault(day, empty_totals(tool)), normalised, tool)


def new_session(tool, session_id, path, project_directory):
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
		"driver_ledger": [],
		"unattributed_count": 0,
		"unattributed": {
			"count": 0,
			"payload_estimate_tokens": 0,
			"method": DRIVER_METHOD,
		},
		"driver_reconciles": True,
	}


def in_window(timestamp, start, end):
	"""Return whether a timestamp belongs to the selected half-open window."""
	return timestamp is not None and start <= timestamp < end


def parse_claude_session(path, start, end):
	"""Parse in-window Claude usage records from one transcript."""
	session_id = path.stem
	project_directory = path.parent.name
	session = new_session("Claude", session_id, path, project_directory)
	calls_by_id = {}

	for record in records(path):
		cwd = record.get("cwd")
		if isinstance(cwd, str) and cwd:
			session["project_directory"] = cwd

		message = record.get("message") or {}
		timestamp = parse_timestamp(record.get("timestamp"))
		attachment = record.get("attachment")
		if (
			isinstance(attachment, dict)
			and attachment.get("type") == "hook_success"
			and in_window(timestamp, start, end)
		):
			hook_name = safe_text(attachment.get("hookName"))
			if hook_name:
				call = new_driver_call("Hook", {"name": hook_name})
				call["result"] = result_text(attachment.get("stdout"))
				call["failed"] = attachment.get("exitCode") not in (None, 0, "0")
				session["_driver_calls"].append(call)
				session["tool_call_count"] += 1

		for block in blocks(record):
			if block.get("type") == "tool_use" and in_window(timestamp, start, end):
				call = new_driver_call(block.get("name"), object_input(block.get("input") or {}))
				session["_driver_calls"].append(call)
				session["tool_call_count"] += 1
				call_id = block.get("id")
				if isinstance(call_id, str) and call_id:
					calls_by_id[call_id] = call
			elif block.get("type") == "tool_result":
				call_id = block.get("tool_use_id")
				call = calls_by_id.get(call_id)
				if call is not None:
					call["result"] = result_text(block.get("content"))
					call["failed"] = tool_result_failed(block)

		if record.get("type") != "assistant":
			continue

		# Sidechain (subagent) usage lives only inside its own record here, never
		# duplicated in the parent's usage, so it is counted rather than filtered.
		usage = message.get("usage")
		if not isinstance(usage, dict):
			continue

		if not in_window(timestamp, start, end):
			continue

		model = message.get("model")
		model = model if isinstance(model, str) and model else "unknown"
		add_session_usage(session, usage, model, timestamp.date().isoformat(), "Claude")

	finalise_driver_ledger(session)
	return session if session["tokens"]["total_tokens"] else None


def codex_delta(last_usage, total_usage, previous_total):
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


def parse_codex_session(path, start, end):
	"""Parse in-window Codex token-count events from one rollout transcript."""
	session_id = path.stem
	if session_id.startswith("rollout-"):
		session_id = session_id.removeprefix("rollout-")

	session = new_session("Codex", session_id, path, "unknown")
	model = "unknown"
	previous_total = None
	calls_by_id = {}

	for record in records(path):
		payload = record.get("payload")
		if not isinstance(payload, dict):
			payload = {}
		record_type = record.get("type")
		timestamp = parse_timestamp(record.get("timestamp"))

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

		if record_type == "response_item":
			response_type = payload.get("type")
			if response_type in ("function_call", "custom_tool_call"):
				name = payload.get("name") or payload.get("tool_name")
				arguments = payload.get("arguments", payload.get("input", {}))
				tool_input = object_input(arguments)
				if response_type == "custom_tool_call":
					embedded = embedded_tool_call(arguments)
					if embedded is not None:
						name, tool_input = embedded

				if in_window(timestamp, start, end):
					call = new_driver_call(name, tool_input)
					session["_driver_calls"].append(call)
					session["tool_call_count"] += 1
					call_id = payload.get("call_id") or payload.get("id")
					if isinstance(call_id, str) and call_id:
						calls_by_id[call_id] = call
			elif response_type in ("function_call_output", "custom_tool_call_output"):
				call = calls_by_id.get(payload.get("call_id") or payload.get("id"))
				if call is not None:
					call["result"] = result_text(payload.get("output"))
					call["failed"] = tool_result_failed(payload)

		if record_type != "event_msg" or payload.get("type") != "token_count":
			continue

		info = payload.get("info")
		if not isinstance(info, dict):
			info = payload

		total_usage = info.get("total_token_usage")
		last_usage = info.get("last_token_usage")
		delta = codex_delta(last_usage, total_usage, previous_total)
		if isinstance(total_usage, dict):
			previous_total = total_usage

		if not in_window(timestamp, start, end) or not isinstance(delta, dict):
			continue

		add_session_usage(session, delta, model, timestamp.date().isoformat(), "Codex")

	finalise_driver_ledger(session)
	return session if session["tokens"]["total_tokens"] else None


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


def load_hcom_labels():
	"""Load best-effort transcript labels from hcom's read-only database."""
	by_session_id = {}
	by_path = {}

	if not HCOM_DATABASE.is_file():
		return by_session_id, by_path

	try:
		connection = sqlite3.connect(
			f"file:{HCOM_DATABASE}?mode=ro",
			uri=True,
			timeout=1,
		)
		connection.row_factory = sqlite3.Row
		rows = connection.execute(
			"SELECT name, session_id, transcript_path, tag, parent_name, tool "
			"FROM instances"
		).fetchall()
		connection.close()
	except sqlite3.Error:
		return by_session_id, by_path

	for row in rows:
		label = {
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


def apply_hcom_label(session, by_session_id, by_path):
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


def ratio_data(numerator, denominator):
	"""Return ratio inputs as well as the calculated ratio for JSON consumers."""
	return {
		"numerator_tokens": numerator,
		"denominator_tokens": denominator,
		"ratio": ratio(numerator, denominator),
	}


def add_group(group, key, tool, session_count, tokens):
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


def aggregate(sessions):
	"""Build all report breakdowns from parsed sessions."""
	by_tool = {
		tool: {
			"session_count": 0,
			"tokens": empty_totals(tool),
		}
		for tool in TOOLS
	}
	by_model = {tool: {} for tool in TOOLS}
	by_day = {}
	by_project = {}
	by_role = {}

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


def aggregate_driver_ledger(sessions):
	"""Combine session driver rows into one ranked ledger and reconciliation."""
	rows = {}
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


def markdown_table_for_group(group):
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


def markdown_driver_table(rows, unattributed):
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


def render_markdown(report):
	"""Render the machine-readable report as concise Markdown."""
	window = report["window"]
	by_tool = report["totals_by_tool"]
	lines = [
		"# Token usage report",
		"",
		"All figures below are tokens, not cost. The report contains no price or dollar estimate.",
		"",
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

	lines.extend(
		[
			"## Totals by tool (tokens, not cost)",
			"",
			"| Tool | Sessions | Total tokens | Input tokens | Output tokens |",
			"| --- | ---: | ---: | ---: | ---: |",
		]
	)

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

	lines.extend(["", "## Totals by model (tokens, not cost)", ""])
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

	lines.extend(
		[
			"",
			"## Top 10 sessions by total tokens (tokens, not cost)",
			"",
			"| Rank | Tool | Session id | Total tokens | Project directory | Transcript path | Hcom role |",
			"| ---: | --- | --- | ---: | --- | --- | --- |",
		]
	)

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

	lines.extend(
		[
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
	)
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

	lines.extend(["", "## Claude cache-read ratio (tokens, not cost)", ""])
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

	lines.extend(
		[
			"",
			"## Codex counting semantics (tokens, not cost)",
			"",
			"`total_token_usage` is cumulative per session. `last_token_usage` is the per-event delta, "
			"which is what this report sums.",
			"",
		]
	)

	return "\n".join(lines) + "\n"


def make_report(sessions, window, sections):
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

	def session_report(session, rank):
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
			"unattributed_count": session["unattributed_count"],
			"unattributed": session["unattributed"],
			"driver_reconciles": session["driver_reconciles"],
			"driver_ledger": session["driver_ledger"],
		}

	all_sessions = [
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


def write_report(report):
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
	sessions = []

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
