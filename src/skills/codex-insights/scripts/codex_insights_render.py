#!/usr/bin/env python3
"""Validate the bound Codex insights provenance chain and render the actionable HTML report."""

from __future__ import annotations

import argparse
import copy
import datetime
import html
import os
import sys
import tempfile
from pathlib import Path

import codex_insights_facets as facets

CODEX_HOME = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex").expanduser()
USAGE_DATA_DIRECTORY = CODEX_HOME / "usage-data"
DEFAULT_EXTRACTION_PATH = USAGE_DATA_DIRECTORY / "latest.json"
DEFAULT_FACETS_PATH = USAGE_DATA_DIRECTORY / "latest-facets.json"
DEFAULT_NARRATIVE_PATH = USAGE_DATA_DIRECTORY / "latest-narrative.json"
UTC = datetime.timezone.utc

KIND_LABELS = {
	"tool_failure": "Tool failure",
	"verification_gap": "Verification gap",
	"correction": "User correction",
	"configuration_touch": "Configuration touch",
	"successful_behaviour": "Successful behaviour",
	"approach_change": "Approach change",
	"retry": "Retry",
	"interruption": "Interruption",
	"rollback": "Rollback",
}
KIND_GROUPS = (
	("failures", "Repeated failures", frozenset({"tool_failure", "verification_gap"})),
	("corrections", "Repeated user corrections", frozenset({"correction"})),
	("configuration", "Configuration opportunities", frozenset({"configuration_touch"})),
	("successes", "Successful behaviours worth standardising", frozenset({"successful_behaviour"})),
	("workflow", "Workflow patterns", frozenset({"approach_change", "retry", "interruption", "rollback"})),
)
CONFIGURATION_STATUS_LABELS = {
	"missing": "Missing — no matching guidance found",
	"already_remediated": "Already remediated — guidance already covers this",
	"present_but_ignored": "Present but ignored — guidance exists but was not followed",
	"ambiguous": "Ambiguous — could not resolve to one configuration surface",
	"unavailable": "Unavailable — the surface could not be read",
	"not_applicable": "Not tied to a named configuration surface",
}

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
  --high-confidence: #0f5132;
  --low-confidence: #664d03;
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
  max-width: 24ch;
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
.lead-list,
.evidence-list,
.limitations-list {
  margin: 0;
  padding-left: 1.5rem;
}

.finding {
  min-width: 0;
  margin-top: 1.75rem;
  padding-top: 1.75rem;
  border-top: 1px solid var(--border);
}

.finding:first-child {
  margin-top: 0;
  padding-top: 0;
  border-top: none;
}

.finding-meta {
  margin: 0.5rem 0;
}

.badge {
  display: inline-block;
  margin: 0.15rem 0.35rem 0.15rem 0;
  padding: 0.15rem 0.55rem;
  color: var(--heading);
  font-size: 0.85rem;
  background: var(--highlight);
  border: 1px solid var(--border);
  border-radius: 999px;
}

.badge-confidence-high {
  color: var(--high-confidence);
  border-color: var(--high-confidence);
}

.badge-confidence-low {
  color: var(--low-confidence);
  border-color: var(--low-confidence);
}

.proposed-change,
.current-state,
.evidence,
.limitations {
  min-width: 0;
  margin-top: 1rem;
  padding: 0.9rem 1rem;
  background: var(--highlight);
  border-left: 0.3rem solid var(--accent);
}

.proposed-change h4,
.current-state h4,
.evidence h4,
.limitations h4 {
  margin-top: 0;
}

.evidence-list li,
.limitations-list li {
  margin-top: 0.55rem;
  overflow-wrap: anywhere;
}

.evidence-list li:first-child,
.limitations-list li:first-child {
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

.appendix-table {
  width: 100%;
  border-collapse: collapse;
}

.appendix-table th,
.appendix-table td {
  padding: 0.4rem 0.6rem;
  text-align: left;
  border-bottom: 1px solid var(--border);
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


def load_and_validate(
	extraction_path: Path, facets_path: Path, narrative_path: Path
) -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
	"""Validate the extraction, facets, and narrative provenance chain before rendering."""
	extraction_info = facets.validate_extraction(extraction_path)
	facets_document = facets.load_json(facets_path)
	facets.validate_facets(facets_document, extraction_info)
	facets_sha256 = facets.hash_bytes(facets_path.read_bytes())
	narrative_document = facets.load_json(narrative_path)
	facets.validate_narrative(narrative_document, extraction_info, facets_document, facets_sha256)
	return extraction_info, facets_document, narrative_document


def escaped(value: object) -> str:
	"""Escape a validated dynamic value for HTML text or an attribute."""
	return html.escape(str(value), quote=True)


def display_optional(value: object) -> str:
	"""Render an unavailable optional value without inventing evidence."""
	return "Not available" if value in (None, "") else escaped(value)


def finding_sort_key(finding: dict[str, object]) -> tuple[int, int, int]:
	"""Rank findings by confidence, then occurrence, then conversation spread."""
	frequency = finding["frequency"]
	return (
		0 if finding["confidence"] == "high" else 1,
		-int(frequency["occurrences"]),
		-int(frequency["unique_conversations"]),
	)


def render_lead_list(findings: list[dict[str, object]]) -> list[str]:
	"""Render the ranked proposed-change digest that leads the report."""
	if not findings:
		return ['<p class="empty">No repeated pattern reached the two-conversation recurrence bar in this window.</p>']

	lines = ['<ol class="lead-list">']
	for finding in sorted(findings, key=finding_sort_key):
		kind_label = KIND_LABELS.get(finding["kind"], finding["kind"])
		lines.append(
			"<li>"
			f'<a href="#finding-{escaped(finding["finding_id"])}">'
			f"{escaped(kind_label)}: {escaped(finding['proposed_target'])}"
			"</a> — "
			f"{escaped(finding['exact_change_or_next_investigation'])}"
			"</li>"
		)
	lines.append("</ol>")
	return lines


def render_current_state(current_configuration_status: dict[str, object]) -> list[str]:
	"""Render the current configuration state read before proposing a change."""
	status = current_configuration_status.get("status")
	lines = [
		'<div class="current-state">',
		"<h4>Current configuration state</h4>",
		f"<p>{escaped(CONFIGURATION_STATUS_LABELS.get(status, status))}</p>",
	]
	surfaces = current_configuration_status.get("surfaces") or []
	if surfaces:
		lines.append('<ul class="evidence-list">')
		for surface in surfaces:
			path = display_optional(surface.get("path") or surface.get("surface"))
			surface_status = escaped(CONFIGURATION_STATUS_LABELS.get(surface.get("status"), surface.get("status")))
			lines.append(f"<li><code>{path}</code>: {surface_status}</li>")
		lines.append("</ul>")
	lines.append("</div>")
	return lines


def render_evidence(citations: list[dict[str, object]]) -> list[str]:
	"""Render bounded supporting evidence citations in source order."""
	lines = [
		'<div class="evidence">',
		"<h4>Supporting evidence</h4>",
		'<ul class="evidence-list">',
	]
	for citation in citations:
		conversation_id = display_optional(citation.get("conversation_id"))
		timestamp = citation.get("timestamp")
		time_html = (
			f'<time datetime="{escaped(timestamp)}">{escaped(timestamp)}</time>'
			if timestamp
			else "<span>time unavailable</span>"
		)
		lines.append(
			"<li>"
			f"<code>{conversation_id}</code> {time_html}"
			'<span class="evidence-detail">'
			f"{escaped(citation.get('detail') or 'No excerpt retained')}"
			"</span>"
			"</li>"
		)
	lines.extend(["</ul>", "</div>"])
	return lines


def render_limitations(limitations: list[str]) -> list[str]:
	"""Render counterevidence and limitations attached to one finding."""
	lines = ['<div class="limitations">', "<h4>Limitations</h4>", '<ul class="limitations-list">']
	for limitation in limitations:
		lines.append(f"<li>{escaped(limitation)}</li>")
	lines.extend(["</ul>", "</div>"])
	return lines


def render_finding(finding: dict[str, object]) -> list[str]:
	"""Render one finding with its evidence strength, current state, and proposed change."""
	kind_label = KIND_LABELS.get(finding["kind"], finding["kind"])
	frequency = finding["frequency"]
	time_span = finding["time_span"]
	confidence = finding["confidence"]
	lines = [
		f'<li class="finding" id="finding-{escaped(finding["finding_id"])}">',
		f"<h3>{escaped(kind_label)}: {escaped(finding['observed_pattern'])}</h3>",
		'<p class="finding-meta">',
		f'<span class="badge badge-confidence-{escaped(confidence)}">Confidence: {escaped(confidence)}</span>',
		f'<span class="badge">{escaped(frequency["occurrences"])} occurrences '
		f'across {escaped(frequency["unique_conversations"])} conversations</span>',
		f'<span class="badge">{display_optional(time_span.get("since"))} '
		f'to {display_optional(time_span.get("until"))}</span>',
		"</p>",
		f"<p><strong>Consequence:</strong> {escaped(finding['consequence'])}</p>",
		'<div class="proposed-change">',
		"<h4>Proposed change</h4>",
		f"<p><strong>Owner:</strong> {escaped(finding['owner'])}. "
		f"<strong>Layer:</strong> {escaped(finding['proposed_layer'])}. "
		f"<strong>Target:</strong> {escaped(finding['proposed_target'])}.</p>",
		f"<p>{escaped(finding['exact_change_or_next_investigation'])}</p>",
		"</div>",
	]
	lines.extend(render_current_state(finding["current_configuration_status"]))
	lines.extend(render_evidence(finding["supporting_evidence"]))
	lines.extend(render_limitations(finding["counterevidence_or_limitations"]))
	lines.append("</li>")
	return lines


def render_category_section(
	section_id: str, title: str, findings: list[dict[str, object]]
) -> list[str]:
	"""Render one categorised section of findings, or its explicit empty state."""
	lines = [
		f'<section id="{section_id}" class="report-section" aria-labelledby="{section_id}-title">',
		f'<h2 id="{section_id}-title">{escaped(title)}</h2>',
	]
	if findings:
		lines.append('<ul class="findings">')
		for finding in sorted(findings, key=finding_sort_key):
			lines.extend(render_finding(finding))
		lines.append("</ul>")
	else:
		lines.append(f'<p class="empty">No evidenced {escaped(title.lower())} were found in this window.</p>')
	lines.append("</section>")
	return lines


def render_evidence_limits_section(
	section_id: str, facets_document: dict[str, object], narrative_document: dict[str, object]
) -> list[str]:
	"""Render the deduplicated evidence limits carried from facets and narrative."""
	limitations = list(dict.fromkeys(facets_document.get("limitations", []) + narrative_document.get("limitations", [])))
	counts = facets_document.get("counts", {})
	illustrated_only = counts.get("pattern_count", 0) - counts.get("repeated_pattern_count", 0)
	if illustrated_only:
		limitations.append(
			f"{illustrated_only} pattern(s) were observed once and are not shown; "
			"a repeated pattern needs at least two unique conversations."
		)
	lines = [
		f'<section id="{section_id}" class="report-section" aria-labelledby="{section_id}-title">',
		f'<h2 id="{section_id}-title">Evidence limits</h2>',
	]
	if limitations:
		lines.append('<ul class="limitations-list">')
		for limitation in limitations:
			lines.append(f"<li>{escaped(limitation)}</li>")
		lines.append("</ul>")
	else:
		lines.append('<p class="empty">No evidence limits were recorded for this window.</p>')
	lines.append("</section>")
	return lines


def render_appendix_section(
	section_id: str, extraction_info: dict[str, object], facets_document: dict[str, object]
) -> list[str]:
	"""Render repository, rollout, conversation, and pattern totals as a supporting appendix."""
	extraction_counts = extraction_info["document"].get("counts", {})
	facets_counts = facets_document.get("counts", {})
	project_paths = {
		rollout.get("project_path")
		for rollout in extraction_info["rollout_index"].values()
		if rollout.get("project_path")
	}
	binding = extraction_info["binding"]
	rows = [
		("Repository directories touched", str(len(project_paths))),
		("Rollouts extracted", str(extraction_counts.get("rollout_count", 0))),
		("Conversations", str(extraction_counts.get("conversation_count", 0))),
		("Subagent rollouts", str(extraction_counts.get("subagent_rollout_count", 0))),
		("Conversation facets classified", str(facets_counts.get("conversation_facet_count", 0))),
		("Patterns observed", str(facets_counts.get("pattern_count", 0))),
		("Repeated patterns promoted to findings", str(facets_counts.get("repeated_pattern_count", 0))),
		("Extraction schema", str(binding.get("extraction_schema_version"))),
		("Extraction SHA-256", str(binding.get("extraction_sha256"))),
	]
	lines = [
		f'<section id="{section_id}" class="report-section" aria-labelledby="{section_id}-title">',
		f'<h2 id="{section_id}-title">Appendix: totals and provenance</h2>',
		'<table class="appendix-table">',
		"<tbody>",
	]
	for label, value in rows:
		lines.append(f"<tr><th scope=\"row\">{escaped(label)}</th><td>{escaped(value)}</td></tr>")
	lines.extend(["</tbody>", "</table>", "</section>"])
	return lines


def render_report(
	narrative_document: dict[str, object],
	facets_document: dict[str, object],
	extraction_info: dict[str, object],
) -> str:
	"""Return a self-contained accessible HTML report for one validated provenance chain."""
	findings = narrative_document.get("findings", [])
	window = narrative_document["provenance"]["window"]

	sections: list[tuple[str, str, list[str]]] = []
	for group_id, title, kinds in KIND_GROUPS:
		group_findings = [finding for finding in findings if finding["kind"] in kinds]
		sections.append((group_id, title, render_category_section(group_id, title, group_findings)))
	sections.append(
		("evidence-limits", "Evidence limits", render_evidence_limits_section("evidence-limits", facets_document, narrative_document))
	)
	sections.append(
		("appendix", "Appendix: totals and provenance", render_appendix_section("appendix", extraction_info, facets_document))
	)

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
		f"Generated {escaped(narrative_document['generated_at'])}. "
		f"Window: {display_optional(window.get('since'))} to {display_optional(window.get('until'))}.",
		"</p>",
		"</div>",
		"</header>",
		'<nav class="section-nav" aria-label="Report sections">',
		'<div class="page-width">',
		"<ol>",
		'<li><a href="#proposed-changes">Proposed changes</a></li>',
	]
	for section_id, title, _ in sections:
		lines.append(f'<li><a href="#{section_id}">{escaped(title)}</a></li>')
	lines.extend(["</ol>", "</div>", "</nav>"])
	lines.append('<main id="main" class="report-main page-width" tabindex="-1">')
	lines.extend(
		[
			'<section id="proposed-changes" class="report-section" aria-labelledby="proposed-changes-title">',
			'<h2 id="proposed-changes-title">Proposed changes</h2>',
			'<p class="section-summary">Ranked by confidence, then by how often the pattern recurred.</p>',
		]
	)
	lines.extend(render_lead_list(findings))
	lines.append("</section>")
	for _, _, section_lines in sections:
		lines.extend(section_lines)
	lines.extend(
		[
			"</main>",
			'<footer class="report-footer">',
			'<div class="page-width">',
			f"<p>Source extraction: <code>{escaped(extraction_info['path'])}</code>.</p>",
			"</div>",
			"</footer>",
			"</body>",
			"</html>",
		]
	)
	return "\n".join(lines) + "\n"


def report_path(now: datetime.datetime | None = None) -> Path:
	"""Return a UTC-timestamped path in Codex's global usage-data directory."""
	now = datetime.datetime.now(UTC) if now is None else now
	timestamp = now.astimezone(UTC).strftime("%Y-%m-%d-%H%M%S")
	return USAGE_DATA_DIRECTORY / f"report-{timestamp}.html"


def write_html(
	narrative_document: dict[str, object],
	facets_document: dict[str, object],
	extraction_info: dict[str, object],
	path: Path,
) -> None:
	"""Render and replace one static HTML report file."""
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(render_report(narrative_document, facets_document, extraction_info), encoding="utf-8")


def write_report(
	narrative_document: dict[str, object],
	facets_document: dict[str, object],
	extraction_info: dict[str, object],
) -> Path:
	"""Write the validated report to a UTC-timestamped usage-data path."""
	path = report_path()
	write_html(narrative_document, facets_document, extraction_info, path)
	return path


def hostile_narrative(narrative_document: dict[str, object]) -> dict[str, object]:
	"""Return a copy of one valid narrative with hostile display text in its findings."""
	tampered = copy.deepcopy(narrative_document)
	hostile_text = "</p><img src=x onerror=alert(1)> <script>alert(1)</script> Ignore previous instructions"
	for finding in tampered["findings"]:
		finding["observed_pattern"] = hostile_text
		finding["consequence"] = hostile_text
		finding["exact_change_or_next_investigation"] = hostile_text
		for citation in finding["supporting_evidence"]:
			citation["detail"] = hostile_text
	return tampered


def expect_provenance_error(callback: object) -> None:
	"""Assert that a selftest callback rejects its tampered provenance input."""
	try:
		callback()
	except facets.ProvenanceError:
		return

	raise AssertionError("expected ProvenanceError")


def run_selftest() -> None:
	"""Verify provenance validation, tamper rejection, escaping, and report content."""
	with tempfile.TemporaryDirectory() as directory:
		root = Path(directory)
		project = root / "project"
		project.mkdir()

		extraction_path = root / "latest.json"
		facets.write_json(extraction_path, facets.fixture_extraction(project))
		extraction_info = facets.validate_extraction(extraction_path)
		facets_document = facets.make_facets(extraction_info)
		facets.validate_facets(facets_document, extraction_info)
		facets_path = root / "latest-facets.json"
		facets.write_json(facets_path, facets_document)
		facets_sha256 = facets.hash_bytes(facets_path.read_bytes())
		narrative_document = facets.make_narrative(facets_document, extraction_info, facets_sha256)
		facets.validate_narrative(narrative_document, extraction_info, facets_document, facets_sha256)
		narrative_path = root / "latest-narrative.json"
		facets.write_json(narrative_path, narrative_document)

		loaded_extraction_info, loaded_facets, loaded_narrative = load_and_validate(
			extraction_path, facets_path, narrative_path
		)
		assert loaded_narrative["findings"]

		report = render_report(loaded_narrative, loaded_facets, loaded_extraction_info)
		assert "Proposed changes" in report
		assert "Repeated failures" in report
		assert "Appendix: totals and provenance" in report
		for finding in loaded_narrative["findings"]:
			assert f'id="finding-{finding["finding_id"]}"' in report
			assert finding["exact_change_or_next_investigation"] in report

		hostile = hostile_narrative(loaded_narrative)
		hostile_report = render_report(hostile, loaded_facets, loaded_extraction_info)
		assert "<script" not in hostile_report.casefold()
		assert "<img" not in hostile_report.casefold()
		assert "&lt;script&gt;" in hostile_report
		assert "&lt;/p&gt;&lt;img" in hostile_report

		empty_findings_narrative = copy.deepcopy(loaded_narrative)
		empty_findings_narrative["findings"] = []
		empty_report = render_report(empty_findings_narrative, loaded_facets, loaded_extraction_info)
		assert "No repeated pattern reached the two-conversation recurrence bar" in empty_report

		tampered_extraction = facets.load_json(extraction_path)
		tampered_extraction["counts"]["rollout_count"] = 1
		tampered_extraction_path = root / "tampered-extraction.json"
		facets.write_json(tampered_extraction_path, tampered_extraction)
		expect_provenance_error(
			lambda: load_and_validate(tampered_extraction_path, facets_path, narrative_path)
		)

		tampered_facets = facets.load_json(facets_path)
		tampered_facets["provenance"]["input_sha256"] = "c" * 64
		tampered_facets_path = root / "tampered-facets.json"
		facets.write_json(tampered_facets_path, tampered_facets)
		expect_provenance_error(
			lambda: load_and_validate(extraction_path, tampered_facets_path, narrative_path)
		)

		tampered_narrative = facets.load_json(narrative_path)
		tampered_narrative["provenance"]["extraction_sha256"] = "d" * 64
		tampered_narrative_path = root / "tampered-narrative.json"
		facets.write_json(tampered_narrative_path, tampered_narrative)
		expect_provenance_error(
			lambda: load_and_validate(extraction_path, facets_path, tampered_narrative_path)
		)

		fixed_now = datetime.datetime(2026, 8, 9, 14, 30, 52, tzinfo=UTC)
		expected_directory = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex").expanduser() / "usage-data"
		assert report_path(fixed_now) == expected_directory / "report-2026-08-09-143052.html"

		output_path = root / "report-2026-08-09-143052.html"
		write_html(loaded_narrative, loaded_facets, loaded_extraction_info, output_path)
		first_size = output_path.stat().st_size
		write_html(hostile, loaded_facets, loaded_extraction_info, output_path)
		assert output_path.stat().st_size != first_size
		assert output_path.read_text(encoding="utf-8") == hostile_report

	print("codex_insights_render selftest passed")


def parse_arguments() -> argparse.Namespace:
	"""Parse the extraction, facets, and narrative input paths or the isolated self-test flag."""
	parser = argparse.ArgumentParser(
		description=__doc__,
		epilog=(
			"Example: python3 src/skills/codex-insights/scripts/"
			"codex_insights_render.py --narrative "
			"~/.codex/usage-data/latest-narrative.json"
		),
	)
	parser.add_argument(
		"--extraction",
		type=Path,
		default=DEFAULT_EXTRACTION_PATH,
		metavar="PATH",
		help="extraction JSON path (default: $CODEX_HOME/usage-data/latest.json)",
	)
	parser.add_argument(
		"--facets",
		type=Path,
		default=DEFAULT_FACETS_PATH,
		metavar="PATH",
		help="facets JSON path (default: $CODEX_HOME/usage-data/latest-facets.json)",
	)
	parser.add_argument(
		"--narrative",
		type=Path,
		default=DEFAULT_NARRATIVE_PATH,
		metavar="PATH",
		help="narrative JSON path (default: $CODEX_HOME/usage-data/latest-narrative.json)",
	)
	parser.add_argument(
		"--selftest",
		action="store_true",
		help="run provenance, tamper-rejection, and escaping fixtures without writing a report",
	)
	arguments = parser.parse_args()
	custom_paths = (
		(arguments.extraction, DEFAULT_EXTRACTION_PATH),
		(arguments.facets, DEFAULT_FACETS_PATH),
		(arguments.narrative, DEFAULT_NARRATIVE_PATH),
	)
	if arguments.selftest and any(path != default for path, default in custom_paths):
		parser.error("--selftest cannot be combined with custom paths")
	return arguments


def main() -> None:
	"""Run the selftest or validate and render one bound provenance chain."""
	arguments = parse_arguments()
	if arguments.selftest:
		run_selftest()
		return

	try:
		extraction_info, facets_document, narrative_document = load_and_validate(
			arguments.extraction, arguments.facets, arguments.narrative
		)
		output_path = write_report(narrative_document, facets_document, extraction_info)
	except facets.ProvenanceError as error:
		print(f"codex_insights_render: {error}", file=sys.stderr)
		raise SystemExit(2) from error

	print(f"Wrote {output_path}")


if __name__ == "__main__":
	main()
