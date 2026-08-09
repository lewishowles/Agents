#!/usr/bin/env python3
"""Validate a Codex insights narrative and render a self-contained HTML report."""

from __future__ import annotations

import argparse
import copy
import datetime
import html
import json
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[4]
AUDIT_DIRECTORY = REPO_ROOT / ".agent/audits/codex-insights"
DEFAULT_INPUT_PATH = AUDIT_DIRECTORY / "latest-narrative.json"
UTC = datetime.timezone.utc

SECTION_DEFINITIONS = (
	("at-a-glance", "At a glance"),
	("what-you-work-on", "What you work on"),
	("how-you-use-codex", "How you use Codex"),
	("what-is-working", "What is working"),
	("where-things-go-wrong", "Where things go wrong"),
	("codex-capabilities-to-try", "Codex capabilities to try"),
	("new-ways-to-use-codex", "New ways to use Codex"),
	("on-the-horizon", "On the horizon"),
)
CAPABILITY_SECTION_INDEX = 5
CAPABILITY_KINDS = frozenset({"capability", "agents-md-addition"})
VERIFICATION_BASES = frozenset({"official-documentation", "observed-local-capability"})
TOP_LEVEL_KEYS = frozenset({"schema_version", "generated_at", "source", "sections"})
SOURCE_KEYS = frozenset({"extraction_path", "window", "session_count"})
WINDOW_KEYS = frozenset({"since", "until"})
SECTION_KEYS = frozenset({"key", "title", "summary", "findings"})
FINDING_KEYS = frozenset({"title", "text", "evidence"})
CAPABILITY_FINDING_KEYS = FINDING_KEYS | frozenset({"kind", "verification"})
EVIDENCE_KEYS = frozenset({"session_id", "timestamp", "source", "detail"})
VERIFICATION_KEYS = frozenset({"basis", "source", "verified_on"})

REPORT_STYLE = """
:root {
  color-scheme: light;
  --background: #f8fafc;
  --surface: #ffffff;
  --text: #1f2937;
  --heading: #111827;
  --muted: #4b5563;
  --border: #6b7280;
  --accent: #005a9c;
  --focus: #005fcc;
  --highlight: #eff6ff;
}

* {
  box-sizing: border-box;
}

html {
  background: var(--background);
}

body {
  margin: 0;
  color: var(--text);
  background: var(--background);
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  font-size: 1rem;
  line-height: 1.5;
}

a {
  color: var(--accent);
}

a:focus-visible,
main:focus-visible {
  outline: 3px solid var(--focus);
  outline-offset: 3px;
}

.skip-link {
  position: absolute;
  top: 0.75rem;
  left: 0.75rem;
  z-index: 1;
  padding: 0.65rem 0.9rem;
  color: var(--heading);
  background: var(--surface);
  border: 2px solid var(--focus);
  transform: translateY(-200%);
}

.skip-link:focus {
  transform: translateY(0);
}

.page-width {
  width: min(100%, 72rem);
  margin: 0 auto;
  padding: 0 clamp(1rem, 4vw, 3rem);
}

.report-header {
  padding: clamp(2rem, 6vw, 4rem) 0 2rem;
  background: var(--surface);
  border-bottom: 1px solid var(--border);
}

h1,
h2,
h3,
h4 {
  color: var(--heading);
  line-height: 1.2;
  overflow-wrap: anywhere;
}

h1 {
  max-width: 18ch;
  margin: 0;
  font-size: clamp(2rem, 5vw, 3rem);
}

h2 {
  margin: 0;
  font-size: clamp(1.5rem, 3vw, 2rem);
}

h3 {
  margin: 0;
  font-size: 1.2rem;
}

h4 {
  margin: 1.25rem 0 0.35rem;
  font-size: 1rem;
}

p {
  max-width: 65ch;
  overflow-wrap: anywhere;
}

.metadata {
  margin: 1rem 0 0;
  color: var(--muted);
}

.section-nav {
  padding: 1.5rem 0;
  background: var(--highlight);
  border-bottom: 1px solid var(--border);
}

.section-nav ol {
  display: grid;
  gap: 0.5rem 1.5rem;
  margin: 0;
  padding-left: 1.5rem;
}

.report-main {
  padding-top: 2rem;
  padding-bottom: 3rem;
}

.report-section {
  min-width: 0;
  margin: 0 0 2rem;
  padding: clamp(1rem, 3vw, 2rem);
  background: var(--surface);
  border: 1px solid var(--border);
}

.report-section:last-child {
  margin-bottom: 0;
}

.section-summary {
  margin: 0.75rem 0 1.5rem;
}

.findings,
.evidence-list {
  margin: 0;
  padding-left: 1.5rem;
}

.finding {
  min-width: 0;
  margin-top: 1.5rem;
}

.finding:first-child {
  margin-top: 0;
}

.finding-text {
  margin-bottom: 0;
}

.evidence,
.verification {
  min-width: 0;
  margin-top: 1rem;
  padding: 0.9rem 1rem;
  background: var(--highlight);
  border-left: 0.3rem solid var(--accent);
}

.evidence h4,
.verification h4 {
  margin-top: 0;
}

.evidence-list li {
  margin-top: 0.55rem;
  overflow-wrap: anywhere;
}

.evidence-list li:first-child {
  margin-top: 0;
}

code {
  overflow-wrap: anywhere;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.95em;
}

.evidence-detail {
  display: block;
}

.empty {
  margin-bottom: 0;
  color: var(--muted);
  font-style: italic;
}

.report-footer {
  padding: 1.5rem 0 3rem;
  color: var(--muted);
}

@media (min-width: 50rem) {
  .section-nav ol {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (prefers-reduced-motion: reduce) {
  html {
    scroll-behavior: auto;
  }
}
""".strip()


class NarrativeValidationError(ValueError):
	"""Describe one narrative input that does not meet the report schema."""


def require_exact_mapping(
	value: object,
	expected_keys: frozenset[str],
	location: str,
) -> dict[str, object]:
	"""Return a mapping when it has exactly the keys required at a schema location."""
	if not isinstance(value, dict):
		raise NarrativeValidationError(f"{location} must be an object")

	actual_keys = set(value)
	if actual_keys != expected_keys:
		missing = sorted(expected_keys - actual_keys)
		extra = sorted(actual_keys - expected_keys)
		details = []
		if missing:
			details.append(f"missing {', '.join(missing)}")
		if extra:
			details.append(f"unexpected {', '.join(extra)}")
		raise NarrativeValidationError(f"{location} has invalid keys: {'; '.join(details)}")

	return value


def require_string(value: object, location: str) -> str:
	"""Return a non-empty string value or reject the schema location."""
	if not isinstance(value, str) or not value.strip():
		raise NarrativeValidationError(f"{location} must be a non-empty string")

	return value


def require_non_negative_integer(value: object, location: str) -> int:
	"""Return a non-negative integer while rejecting booleans and other values."""
	if isinstance(value, bool) or not isinstance(value, int) or value < 0:
		raise NarrativeValidationError(f"{location} must be a non-negative integer")

	return value


def parse_utc_timestamp(value: object, location: str) -> tuple[str, datetime.datetime]:
	"""Return the original UTC timestamp and its parsed value."""
	text = require_string(value, location)
	normalised = f"{text[:-1]}+00:00" if text.endswith("Z") else text
	try:
		parsed = datetime.datetime.fromisoformat(normalised)
	except ValueError as error:
		raise NarrativeValidationError(f"{location} must be an ISO-8601 timestamp") from error

	if parsed.tzinfo is None or parsed.utcoffset() != datetime.timedelta(0):
		raise NarrativeValidationError(f"{location} must include an explicit UTC offset")

	return text, parsed


def require_optional_utc_timestamp(
	value: object,
	location: str,
) -> str | None:
	"""Return an optional UTC timestamp, preserving null as unavailable."""
	if value is None:
		return None

	text, _ = parse_utc_timestamp(value, location)
	return text


def require_date(value: object, location: str) -> str:
	"""Return a calendar date in the verification schema's YYYY-MM-DD form."""
	text = require_string(value, location)
	try:
		datetime.date.fromisoformat(text)
	except ValueError as error:
		raise NarrativeValidationError(f"{location} must be a YYYY-MM-DD date") from error

	if len(text) != 10:
		raise NarrativeValidationError(f"{location} must be a YYYY-MM-DD date")

	return text


def validate_evidence(value: object, location: str) -> list[dict[str, object]]:
	"""Validate and normalise the evidence objects attached to one finding."""
	if not isinstance(value, list) or not value:
		raise NarrativeValidationError(f"{location} must be a non-empty array")

	validated = []
	for index, evidence in enumerate(value):
		item_location = f"{location}[{index}]"
		item = require_exact_mapping(evidence, EVIDENCE_KEYS, item_location)
		timestamp, _ = parse_utc_timestamp(item["timestamp"], f"{item_location}.timestamp")
		validated.append(
			{
				"session_id": require_string(item["session_id"], f"{item_location}.session_id"),
				"timestamp": timestamp,
				"source": require_string(item["source"], f"{item_location}.source"),
				"detail": require_string(item["detail"], f"{item_location}.detail"),
			}
		)

	return validated


def validate_verification(value: object, location: str) -> dict[str, str]:
	"""Validate capability evidence provenance and its verification date."""
	verification = require_exact_mapping(value, VERIFICATION_KEYS, location)
	basis = require_string(verification["basis"], f"{location}.basis")
	if basis not in VERIFICATION_BASES:
		raise NarrativeValidationError(
			f"{location}.basis must be one of: {', '.join(sorted(VERIFICATION_BASES))}"
		)

	source = require_string(verification["source"], f"{location}.source")
	if basis == "official-documentation" and not source.startswith("https://"):
		raise NarrativeValidationError(
			f"{location}.source must be an HTTPS documentation source for official verification"
		)
	if basis == "observed-local-capability" and not source.startswith("local:"):
		raise NarrativeValidationError(
			f"{location}.source must start with local: for local verification"
		)

	return {
		"basis": basis,
		"source": source,
		"verified_on": require_date(verification["verified_on"], f"{location}.verified_on"),
	}


def validate_finding(
	value: object,
	location: str,
	capability_section: bool,
) -> dict[str, object]:
	"""Validate one finding and require verification metadata in section six."""
	expected_keys = CAPABILITY_FINDING_KEYS if capability_section else FINDING_KEYS
	finding = require_exact_mapping(value, expected_keys, location)
	validated: dict[str, object] = {
		"title": require_string(finding["title"], f"{location}.title"),
		"text": require_string(finding["text"], f"{location}.text"),
		"evidence": validate_evidence(finding["evidence"], f"{location}.evidence"),
	}
	if capability_section:
		kind = require_string(finding["kind"], f"{location}.kind")
		if kind not in CAPABILITY_KINDS:
			raise NarrativeValidationError(
				f"{location}.kind must be one of: {', '.join(sorted(CAPABILITY_KINDS))}"
			)
		validated["kind"] = kind
		validated["verification"] = validate_verification(
			finding["verification"], f"{location}.verification"
		)

	return validated


def validate_narrative(value: object) -> dict[str, object]:
	"""Validate and normalise a complete eight-section narrative document."""
	narrative = require_exact_mapping(value, TOP_LEVEL_KEYS, "narrative")
	schema_version = narrative["schema_version"]
	if isinstance(schema_version, bool) or schema_version != 1:
		raise NarrativeValidationError("narrative.schema_version must be 1")

	generated_at, _ = parse_utc_timestamp(narrative["generated_at"], "narrative.generated_at")
	source = require_exact_mapping(narrative["source"], SOURCE_KEYS, "narrative.source")
	window = require_exact_mapping(source["window"], WINDOW_KEYS, "narrative.source.window")
	since = require_optional_utc_timestamp(window["since"], "narrative.source.window.since")
	until = require_optional_utc_timestamp(window["until"], "narrative.source.window.until")
	if since is not None and until is not None:
		_, since_value = parse_utc_timestamp(since, "narrative.source.window.since")
		_, until_value = parse_utc_timestamp(until, "narrative.source.window.until")
		if until_value < since_value:
			raise NarrativeValidationError("narrative.source.window.until must not precede since")

	sections = narrative["sections"]
	if not isinstance(sections, list) or len(sections) != len(SECTION_DEFINITIONS):
		raise NarrativeValidationError("narrative.sections must contain exactly eight sections")

	validated_sections = []
	for index, (expected_key, expected_title) in enumerate(SECTION_DEFINITIONS):
		location = f"narrative.sections[{index}]"
		section = require_exact_mapping(sections[index], SECTION_KEYS, location)
		if section["key"] != expected_key or section["title"] != expected_title:
			raise NarrativeValidationError(
				f"{location} must be {expected_key!r} / {expected_title!r} in canonical order"
			)
		findings = section["findings"]
		if not isinstance(findings, list):
			raise NarrativeValidationError(f"{location}.findings must be an array")
		validated_sections.append(
			{
				"key": expected_key,
				"title": expected_title,
				"summary": require_string(section["summary"], f"{location}.summary"),
				"findings": [
					validate_finding(
						finding,
						f"{location}.findings[{finding_index}]",
						index == CAPABILITY_SECTION_INDEX,
					)
					for finding_index, finding in enumerate(findings)
				],
			}
		)

	return {
		"schema_version": 1,
		"generated_at": generated_at,
		"source": {
			"extraction_path": require_string(
				source["extraction_path"], "narrative.source.extraction_path"
			),
			"window": {"since": since, "until": until},
			"session_count": require_non_negative_integer(
				source["session_count"], "narrative.source.session_count"
			),
		},
		"sections": validated_sections,
	}


def load_narrative(path: Path) -> dict[str, object]:
	"""Read and validate one narrative JSON file."""
	try:
		value = json.loads(path.read_text(encoding="utf-8"))
	except OSError as error:
		raise NarrativeValidationError(f"could not read {path}: {error}") from error
	except json.JSONDecodeError as error:
		raise NarrativeValidationError(f"{path} is not valid JSON: {error.msg}") from error

	return validate_narrative(value)


def escaped(value: object) -> str:
	"""Escape a validated dynamic value for HTML text or an attribute."""
	return html.escape(str(value), quote=True)


def display_optional(value: str | None) -> str:
	"""Render an unavailable optional value without inventing evidence."""
	return "Not available" if value is None else escaped(value)


def render_evidence(evidence: list[dict[str, object]]) -> list[str]:
	"""Render evidence in source order with all values escaped."""
	lines = [
		'<div class="evidence">',
		"<h4>Evidence</h4>",
		'<ul class="evidence-list">',
	]
	for item in evidence:
		lines.append(
				"<li>"
				f"<code>{escaped(item['session_id'])}</code> "
				f'<time datetime="{escaped(item["timestamp"])}">{escaped(item["timestamp"])}</time>'
				'<span class="evidence-detail">'
				f"<strong>{escaped(item['source'])}:</strong> {escaped(item['detail'])}"
				"</span>"
				"</li>"
		)
	lines.extend(["</ul>", "</div>"])
	return lines


def render_verification(verification: dict[str, str]) -> list[str]:
	"""Render the provenance required for a capability suggestion."""
	return [
		'<div class="verification">',
		"<h4>Verification</h4>",
		"<p>"
		f"<strong>Basis:</strong> {escaped(verification['basis'])}. "
		f"<strong>Source:</strong> <code>{escaped(verification['source'])}</code>. "
		f"<strong>Verified:</strong> <time datetime=\"{escaped(verification['verified_on'])}\">"
		f"{escaped(verification['verified_on'])}</time>."
		"</p>",
		"</div>",
	]


def render_finding(finding: dict[str, object]) -> list[str]:
	"""Render one finding, its evidence, and optional capability verification."""
	lines = [
		'<li class="finding">',
		f"<h3>{escaped(finding['title'])}</h3>",
		f'<p class="finding-text">{escaped(finding["text"])}</p>',
	]
	lines.extend(render_evidence(finding["evidence"]))
	if "verification" in finding:
		lines.extend(render_verification(finding["verification"]))
	lines.append("</li>")
	return lines


def render_report(value: object) -> str:
	"""Return a self-contained accessible HTML report for a valid narrative."""
	narrative = validate_narrative(value)
	source = narrative["source"]
	window = source["window"]
	lines = [
		"<!doctype html>",
		'<html lang="en">',
		"<head>",
		'<meta charset="utf-8">',
		'<meta name="viewport" content="width=device-width, initial-scale=1">',
		"<title>Codex insights report</title>",
		"<style>",
		REPORT_STYLE,
		"</style>",
		"</head>",
		"<body>",
		'<a class="skip-link" href="#main">Skip to report</a>',
		'<header class="report-header">',
		'<div class="page-width">',
		"<h1>Codex insights report</h1>",
		'<p class="metadata">',
		f"Generated {escaped(narrative['generated_at'])}. "
		f"Analysed {escaped(source['session_count'])} sessions. "
		f"Window: {display_optional(window['since'])} to {display_optional(window['until'])}.",
		"</p>",
		"</div>",
		"</header>",
		'<nav class="section-nav" aria-label="Report sections">',
		'<div class="page-width">',
		"<ol>",
	]
	for index, (_, title) in enumerate(SECTION_DEFINITIONS, start=1):
		lines.append(f'<li><a href="#section-{index}">{escaped(title)}</a></li>')
	lines.extend(["</ol>", "</div>", "</nav>"])
	lines.extend(['<main id="main" class="report-main page-width" tabindex="-1">'])

	for index, section in enumerate(narrative["sections"], start=1):
		section_id = f"section-{index}"
		lines.extend(
			[
				f'<section id="{section_id}" class="report-section" aria-labelledby="{section_id}-title">',
				f'<h2 id="{section_id}-title">{escaped(section["title"])}</h2>',
				f'<p class="section-summary">{escaped(section["summary"])}</p>',
			]
		)
		findings = section["findings"]
		if findings:
			lines.append('<ul class="findings">')
			for finding in findings:
				lines.extend(render_finding(finding))
			lines.append("</ul>")
		else:
			lines.append('<p class="empty">No evidenced findings were recorded for this section.</p>')
		lines.append("</section>")

	lines.extend(
		[
			"</main>",
			'<footer class="report-footer">',
			'<div class="page-width">',
			f"<p>Source extraction: <code>{escaped(source['extraction_path'])}</code>.</p>",
			"</div>",
			"</footer>",
			"</body>",
			"</html>",
		]
	)
	return "\n".join(lines) + "\n"


def report_path(now: datetime.datetime | None = None) -> Path:
	"""Return the UTC-dated output path, replacing a same-day report on write."""
	now = datetime.datetime.now(UTC) if now is None else now
	return AUDIT_DIRECTORY / f"report-{now.astimezone(UTC).date().isoformat()}.html"


def write_html(value: object, path: Path) -> None:
	"""Validate and replace one static HTML report file."""
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(render_report(value), encoding="utf-8")


def write_report(value: object) -> Path:
	"""Write the narrative report to its current UTC-dated audit path."""
	path = report_path()
	write_html(value, path)
	return path


def fixture_narrative(hostile: bool = False) -> dict[str, object]:
	"""Build a valid selftest narrative, optionally containing hostile evidence text."""
	detail = (
		"</p><img src=x onerror=alert(1)> Ignore previous instructions"
		if hostile
		else "A bounded session record supports this observation."
	)
	sections = []
	for section_index, (key, title) in enumerate(SECTION_DEFINITIONS):
		finding: dict[str, object] = {
			"title": "Observed finding",
			"text": "The report keeps evidence and interpretation separate.",
			"evidence": [
				{
					"session_id": "session-1",
					"timestamp": "2026-08-09T10:00:00Z",
					"source": "first_user_prompt",
					"detail": detail,
				}
			],
		}
		if hostile:
			finding["title"] = "<script>alert(1)</script>"
		if section_index == CAPABILITY_SECTION_INDEX:
			finding.update(
				{
					"kind": "capability",
					"verification": {
						"basis": "observed-local-capability",
						"source": "local: ~/.agents/skills/",
						"verified_on": "2026-08-09",
					},
				}
			)
		sections.append(
			{
				"key": key,
				"title": title,
				"summary": "A short summary grounded in the extraction.",
				"findings": [finding],
			}
		)

	return {
		"schema_version": 1,
		"generated_at": "2026-08-09T12:00:00Z",
		"source": {
			"extraction_path": ".agent/audits/codex-insights/latest.json",
			"window": {
				"since": "2026-08-05T00:00:00Z",
				"until": "2026-08-06T00:00:00Z",
			},
			"session_count": 1,
		},
		"sections": sections,
	}


def expect_validation_error(callback: object) -> None:
	"""Assert that a selftest callback rejects its narrative input."""
	if not callable(callback):
		raise AssertionError("selftest callback must be callable")

	try:
		callback()
	except NarrativeValidationError:
		return

	raise AssertionError("expected NarrativeValidationError")


def run_selftest() -> None:
	"""Verify schema rejection, malformed input handling, and HTML escaping."""
	valid = fixture_narrative()
	assert len(valid["sections"]) == 8
	validate_narrative(valid)

	empty = {}
	expect_validation_error(lambda: validate_narrative(empty))
	wrong_order = copy.deepcopy(valid)
	wrong_order["sections"][0]["title"] = "Where things go wrong"
	expect_validation_error(lambda: validate_narrative(wrong_order))
	missing_evidence = copy.deepcopy(valid)
	missing_evidence["sections"][0]["findings"][0]["evidence"] = []
	expect_validation_error(lambda: validate_narrative(missing_evidence))
	bad_verification = copy.deepcopy(valid)
	bad_verification["sections"][CAPABILITY_SECTION_INDEX]["findings"][0]["verification"][
		"source"
	] = "local: missing basis"
	bad_verification["sections"][CAPABILITY_SECTION_INDEX]["findings"][0]["verification"][
		"basis"
	] = "official-documentation"
	expect_validation_error(lambda: validate_narrative(bad_verification))

	with tempfile.TemporaryDirectory() as directory:
		root = Path(directory)
		empty_path = root / "empty.json"
		empty_path.write_text("", encoding="utf-8")
		malformed_path = root / "malformed.json"
		malformed_path.write_text("{not json", encoding="utf-8")
		expect_validation_error(lambda: load_narrative(empty_path))
		expect_validation_error(lambda: load_narrative(malformed_path))

	hostile_html = render_report(fixture_narrative(hostile=True))
	assert "<script" not in hostile_html.casefold()
	assert "<img" not in hostile_html.casefold()
	assert "&lt;script&gt;" in hostile_html
	assert "&lt;/p&gt;&lt;img" in hostile_html
	assert "<link" not in hostile_html.casefold()
	assert "<script" not in hostile_html.casefold()
	assert "@import" not in hostile_html.casefold()

	with tempfile.TemporaryDirectory() as directory:
		output_path = Path(directory) / "report-2026-08-09.html"
		write_html(valid, output_path)
		first_size = output_path.stat().st_size
		write_html(fixture_narrative(hostile=True), output_path)
		assert output_path.stat().st_size != first_size
		assert output_path.read_text(encoding="utf-8") == hostile_html

	print("codex_insights_render selftest passed")


def parse_arguments() -> argparse.Namespace:
	"""Parse the narrative input path or the fixture-based selftest flag."""
	parser = argparse.ArgumentParser(
		description=__doc__,
		epilog=(
			"Example: python3 src/skills/codex-insights/scripts/"
			"codex_insights_render.py --input "
			".agent/audits/codex-insights/latest-narrative.json"
		),
	)
	parser.add_argument(
		"--input",
		type=Path,
		default=DEFAULT_INPUT_PATH,
		metavar="PATH",
		help="narrative JSON path (default: .agent/audits/codex-insights/latest-narrative.json)",
	)
	parser.add_argument(
		"--selftest",
		action="store_true",
		help="run schema and escaping fixtures without writing a report",
	)
	arguments = parser.parse_args()
	if arguments.selftest and arguments.input != DEFAULT_INPUT_PATH:
		parser.error("--selftest cannot be combined with --input")
	return arguments


def main() -> None:
	"""Run the selftest or render one validated narrative JSON document."""
	arguments = parse_arguments()
	if arguments.selftest:
		run_selftest()
		return

	try:
		narrative = load_narrative(arguments.input)
		output_path = write_report(narrative)
	except NarrativeValidationError as error:
		print(f"codex_insights_render: {error}", file=sys.stderr)
		raise SystemExit(2) from error

	print(f"Wrote {output_path}")


if __name__ == "__main__":
	main()
