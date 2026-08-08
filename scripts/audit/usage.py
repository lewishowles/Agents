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
import os
import sqlite3
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
AUDIT_DIRECTORY = Path(__file__).resolve().parent

# Both direct script execution and ``from scripts.audit import usage`` are
# supported; each invocation style needs the sibling audit modules on sys.path.
if str(AUDIT_DIRECTORY) not in sys.path:
	sys.path.insert(0, str(AUDIT_DIRECTORY))

from usage_driver import DRIVER_METHOD  # noqa: E402
from usage_parsing import (  # noqa: E402
	CLAUDE_RECORD_TYPES,
	add_totals,
	empty_totals,
	number,
	parse_claude_session,
	parse_codex_session,
	records,
	usage_totals,
)
from usage_types import (  # noqa: E402
	AggregateRow,
	DriverLedgerRow,
	DriverReconciliation,
	Group,
	HcomLabel,
	PartialData,
	RatioData,
	Report,
	Sections,
	Session,
	SessionReport,
	TokenTotals,
	Unattributed,
	Window,
	WindowReport,
)

CLAUDE_ROOT = (
	Path(os.environ.get("CLAUDE_CONFIG_DIR", "~/.claude")).expanduser() / "projects"
)
_CODEX_HOME = Path(os.environ.get("CODEX_HOME", "~/.codex")).expanduser()
CODEX_ROOTS = (
	_CODEX_HOME / "sessions",
	_CODEX_HOME / "archived_sessions",
)
HCOM_DATABASE = Path("~/.hcom/hcom.db").expanduser()
REPORT_DIRECTORY = REPO_ROOT / ".agent/audits/usage"
TOOLS = ("Claude", "Codex")


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
	return (
		start,
		end,
		start.isoformat(timespec="seconds"),
		end.isoformat(timespec="seconds"),
	)


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
			by_tool[tool]["message"] = (
				f"No {tool} token usage records in the selected window."
			)

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
			lines.append(f"| {tool} | {partial_data['skipped_record_counts'][tool]} |")

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
			lines.extend(
				markdown_driver_table(session["driver_ledger"], session["unattributed"])
			)
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
			"partial": any(session["skipped_record_count"] > 0 for session in sessions),
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
	parser.add_argument(
		"--since", type=parse_date, help="inclusive UTC date, YYYY-MM-DD"
	)
	parser.add_argument(
		"--until", type=parse_date, help="inclusive UTC date, YYYY-MM-DD"
	)
	parser.add_argument(
		"--days", type=int, help="window ending now in UTC (default: 7)"
	)
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
