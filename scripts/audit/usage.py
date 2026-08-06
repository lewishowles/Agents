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
import datetime
import json
import os
import sqlite3
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
CLAUDE_ROOT = Path("~/.claude/projects").expanduser()
CODEX_ROOTS = (
	Path("~/.codex/sessions").expanduser(),
	Path("~/.codex/archived_sessions").expanduser(),
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
	}


def in_window(timestamp, start, end):
	"""Return whether a timestamp belongs to the selected half-open window."""
	return timestamp is not None and start <= timestamp < end


def parse_claude_session(path, start, end):
	"""Parse in-window Claude usage records from one transcript."""
	session_id = path.stem
	project_directory = path.parent.name
	session = new_session("Claude", session_id, path, project_directory)

	for record in records(path):
		cwd = record.get("cwd")
		if isinstance(cwd, str) and cwd:
			session["project_directory"] = cwd

		if record.get("type") != "assistant":
			continue

		# Sidechain (subagent) usage lives only inside its own record here, never
		# duplicated in the parent's usage, so it is counted rather than filtered.
		message = record.get("message") or {}
		usage = message.get("usage")
		if not isinstance(usage, dict):
			continue

		timestamp = parse_timestamp(record.get("timestamp"))
		if not in_window(timestamp, start, end):
			continue

		model = message.get("model")
		model = model if isinstance(model, str) and model else "unknown"
		add_session_usage(session, usage, model, timestamp.date().isoformat(), "Claude")

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

	for record in records(path):
		payload = record.get("payload") or {}
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

		timestamp = parse_timestamp(record.get("timestamp"))
		if not in_window(timestamp, start, end) or not isinstance(delta, dict):
			continue

		add_session_usage(session, delta, model, timestamp.date().isoformat(), "Codex")

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
	ordered_sessions = sorted(
		sessions,
		key=lambda session: (
			-session["tokens"]["total_tokens"],
			session["tool"],
			session["session_id"],
		),
	)
	top_sessions = []

	for rank, session in enumerate(ordered_sessions[:10], start=1):
		top_sessions.append(
			{
				"rank": rank,
				"tool": session["tool"],
				"session_id": session["session_id"],
				"transcript_path": session["transcript_path"],
				"project_directory": session["project_directory"],
				"hcom": session["hcom"],
				"models": sorted(session["models"]),
				"tokens": session["tokens"],
			}
		)

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
