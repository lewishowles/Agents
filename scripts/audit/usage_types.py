"""Define the typed boundaries for the usage report and session model."""

from __future__ import annotations

import datetime
from typing import Callable, Optional, TypedDict


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
TOOLS = ("Claude", "Codex")


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
