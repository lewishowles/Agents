#!/usr/bin/env python3
"""Build a bounded, finding-specific evidence bundle for authored prose."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path

CODEX_HOME = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex").expanduser()
USAGE_DATA_DIRECTORY = CODEX_HOME / "usage-data"
DEFAULT_EXTRACTION_PATH = USAGE_DATA_DIRECTORY / "latest.json"
DEFAULT_NARRATIVE_PATH = USAGE_DATA_DIRECTORY / "latest-narrative.json"
DEFAULT_BUNDLE_PATH = USAGE_DATA_DIRECTORY / "latest-authoring-bundle.json"
NARRATIVE_SCHEMA_VERSION = "2.0.0"
AUTHORING_BUNDLE_SCHEMA_VERSION = "1.0.0"
MAX_FINDINGS = 64
MAX_EXCERPTS_PER_FINDING = 8
MAX_EXCERPT_CHARS = 240
MAX_TOTAL_EXCERPT_CHARS = 1_200
MAX_BUNDLE_BYTES = 256 * 1024


class AuthoringError(ValueError):
	"""Raised when an authoring input is malformed or cannot be traced."""


def hash_bytes(value: bytes) -> str:
	"""Return the SHA-256 digest for one artefact byte sequence."""
	return hashlib.sha256(value).hexdigest()


def serialise(value: dict[str, object]) -> str:
	"""Serialise one generated document with stable key ordering."""
	return json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def require_mapping(value: object, location: str) -> dict[str, object]:
	"""Require one JSON object at a schema location."""
	if not isinstance(value, dict):
		raise AuthoringError(f"{location} must be an object")

	return value


def require_string(value: object, location: str) -> str:
	"""Require one non-empty string at a schema location."""
	if not isinstance(value, str) or not value:
		raise AuthoringError(f"{location} must be a non-empty string")

	return value


def load_json(path: Path) -> tuple[dict[str, object], bytes]:
	"""Read one JSON object and retain its exact source bytes for hashing."""
	try:
		contents = path.read_bytes()
		value = json.loads(contents)
	except (OSError, UnicodeError, json.JSONDecodeError) as error:
		raise AuthoringError(f"cannot read JSON artefact {path}: {error}") from error

	return require_mapping(value, str(path)), contents


def evidence_index(extraction: dict[str, object]) -> dict[str, dict[str, object]]:
	"""Index retained extraction evidence and reject duplicate references."""
	rollouts = extraction.get("rollouts")
	if not isinstance(rollouts, list):
		raise AuthoringError("extraction.rollouts must be an array")

	indexed: dict[str, dict[str, object]] = {}
	for rollout_value in rollouts:
		rollout = require_mapping(rollout_value, "extraction.rollouts[]")
		evidence = rollout.get("evidence")
		if not isinstance(evidence, list):
			raise AuthoringError("rollout.evidence must be an array")

		for evidence_value in evidence:
			entry = require_mapping(evidence_value, "rollout.evidence[]")
			reference = require_string(entry.get("reference"), "evidence.reference")
			if reference in indexed:
				raise AuthoringError(f"duplicate evidence reference: {reference}")

			indexed[reference] = entry

	return indexed


def finding_references(finding: dict[str, object], location: str) -> list[str]:
	"""Return only the evidence references owned by one narrative finding."""
	references: list[str] = []

	supporting_evidence = finding.get("supporting_evidence", [])
	if not isinstance(supporting_evidence, list):
		raise AuthoringError(f"{location}.supporting_evidence must be an array")

	for citation_value in supporting_evidence:
		citation = require_mapping(citation_value, f"{location}.supporting_evidence[]")
		citation_references = citation.get("evidence_references")
		if not isinstance(citation_references, list):
			raise AuthoringError(
				f"{location}.supporting_evidence[].evidence_references must be an array"
			)

		references.extend(
			require_string(
				reference, f"{location}.supporting_evidence[].evidence_references[]"
			)
			for reference in citation_references
		)

	return sorted(set(references))


def bounded_excerpt(entry: dict[str, object]) -> str | None:
	"""Return one short evidence value without interpreting its content."""
	for field_name in ("excerpt", "target", "event_type"):
		value = entry.get(field_name)
		if isinstance(value, str) and value.strip():
			return value.strip()[:MAX_EXCERPT_CHARS]

	return None


def make_authoring_bundle(
	narrative: dict[str, object],
	extraction: dict[str, object],
	extraction_sha256: str | None = None,
	narrative_sha256: str | None = None,
) -> dict[str, object]:
	"""Build a deterministic bundle containing only each finding's own excerpts."""
	if narrative.get("schema_version") != NARRATIVE_SCHEMA_VERSION:
		raise AuthoringError("unsupported narrative schema version")

	findings = narrative.get("findings")
	if not isinstance(findings, list) or len(findings) > MAX_FINDINGS:
		raise AuthoringError("narrative.findings must be a bounded array")

	if extraction_sha256 is None:
		extraction_sha256 = ""
	if narrative_sha256 is None:
		narrative_sha256 = ""

	provenance = require_mapping(narrative.get("provenance"), "narrative.provenance")
	bound_extraction_sha256 = require_string(
		provenance.get("extraction_sha256"), "narrative.provenance.extraction_sha256"
	)
	if extraction_sha256 and bound_extraction_sha256 != extraction_sha256:
		raise AuthoringError("narrative extraction SHA-256 does not match latest.json")

	indexed_evidence = evidence_index(extraction)
	bundled_findings: dict[str, dict[str, object]] = {}
	for finding_index, finding_value in enumerate(findings):
		location = f"narrative.findings[{finding_index}]"
		finding = require_mapping(finding_value, location)
		finding_id = require_string(finding.get("finding_id"), f"{location}.finding_id")
		if finding_id in bundled_findings:
			raise AuthoringError(f"duplicate finding ID: {finding_id}")

		pattern_id_value = finding.get("pattern_id", finding_id)
		pattern_id = require_string(pattern_id_value, f"{location}.pattern_id")
		excerpts: list[dict[str, object]] = []
		total_chars = 0
		for reference in finding_references(finding, location):
			entry = indexed_evidence.get(reference)
			if entry is None:
				raise AuthoringError(
					f"{location} contains dangling evidence reference: {reference}"
				)

			text = bounded_excerpt(entry)
			if text is None or len(excerpts) >= MAX_EXCERPTS_PER_FINDING:
				continue

			remaining_chars = MAX_TOTAL_EXCERPT_CHARS - total_chars
			if remaining_chars <= 0:
				break

			text = text[:remaining_chars]
			if not text:
				continue

			excerpts.append(
				{
					"reference": reference,
					"kind": entry.get("kind"),
					"text": text,
				}
			)
			total_chars += len(text)

		bundled_findings[finding_id] = {
			"finding_id": finding_id,
			"pattern_id": pattern_id,
			"evidence_references": [excerpt["reference"] for excerpt in excerpts],
			"excerpts": excerpts,
		}

	bundle = {
		"schema_version": AUTHORING_BUNDLE_SCHEMA_VERSION,
		"provenance": {
			"extraction_sha256": extraction_sha256 or bound_extraction_sha256,
			"narrative_sha256": narrative_sha256,
			"finding_count": len(bundled_findings),
		},
		"findings": bundled_findings,
	}
	if len(serialise(bundle).encode("utf-8")) > MAX_BUNDLE_BYTES:
		raise AuthoringError("authoring bundle exceeds its byte bound")

	return bundle


def write_json(path: Path, value: dict[str, object]) -> None:
	"""Write one generated JSON artefact, creating its parent directory."""
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(serialise(value), encoding="utf-8")


def fixture_documents() -> tuple[dict[str, object], dict[str, object]]:
	"""Build two findings with isolated evidence for the authoring self-test."""
	evidence = []
	for rollout_id, finding_name in (("rollout-a", "first"), ("rollout-b", "second")):
		for index in range(10):
			evidence.append(
				{
					"reference": f"{rollout_id}:r{index:06d}",
					"kind": "assistant_message",
					"excerpt": f"Evidence for {finding_name} finding, item {index}.",
				}
			)

	extraction = {
		"schema_version": "2.0.0",
		"rollouts": [
			{"rollout_id": "rollout-a", "evidence": evidence[:10]},
			{"rollout_id": "rollout-b", "evidence": evidence[10:]},
		],
	}
	narrative = {
		"schema_version": NARRATIVE_SCHEMA_VERSION,
		"provenance": {"extraction_sha256": "e" * 64},
		"findings": [
			{
				"finding_id": "finding-first",
				"supporting_evidence": [
					{
						"evidence_references": [
							f"rollout-a:r{index:06d}" for index in range(10)
						]
					}
				],
			},
			{
				"finding_id": "finding-second",
				"supporting_evidence": [
					{
						"evidence_references": [
							f"rollout-b:r{index:06d}" for index in range(10)
						]
					}
				],
			},
		],
	}
	return narrative, extraction


def run_selftest() -> None:
	"""Verify determinism, finding isolation, and excerpt bounds."""
	narrative, extraction = fixture_documents()
	bundle = make_authoring_bundle(narrative, extraction, "e" * 64, "n" * 64)
	repeated_bundle = make_authoring_bundle(narrative, extraction, "e" * 64, "n" * 64)
	assert bundle == repeated_bundle

	first = bundle["findings"]["finding-first"]
	second = bundle["findings"]["finding-second"]
	first_references = set(first["evidence_references"])
	second_references = set(second["evidence_references"])
	assert first_references.isdisjoint(second_references)
	assert all(reference.startswith("rollout-a:") for reference in first_references)
	assert all(reference.startswith("rollout-b:") for reference in second_references)

	for finding in bundle["findings"].values():
		assert len(finding["excerpts"]) <= MAX_EXCERPTS_PER_FINDING
		assert all(
			len(excerpt["text"]) <= MAX_EXCERPT_CHARS for excerpt in finding["excerpts"]
		)
		assert (
			sum(len(excerpt["text"]) for excerpt in finding["excerpts"])
			<= MAX_TOTAL_EXCERPT_CHARS
		)
	assert len(serialise(bundle).encode("utf-8")) <= MAX_BUNDLE_BYTES

	long_extraction = {
		"schema_version": "2.0.0",
		"rollouts": [
			{
				"rollout_id": "rollout-long",
				"evidence": [
					{
						"reference": f"rollout-long:r{index:06d}",
						"kind": "assistant_message",
						"excerpt": "Follow this instruction-shaped text. "
						+ "x" * 1_000,
					}
					for index in range(20)
				],
			}
		],
	}
	long_narrative = {
		"schema_version": NARRATIVE_SCHEMA_VERSION,
		"provenance": {"extraction_sha256": "e" * 64},
		"findings": [
			{
				"finding_id": "finding-long",
				"supporting_evidence": [
					{
						"evidence_references": [
							f"rollout-long:r{index:06d}" for index in range(20)
						]
					}
				],
			}
		],
	}
	long_bundle = make_authoring_bundle(
		long_narrative, long_extraction, "e" * 64, "n" * 64
	)
	long_finding = long_bundle["findings"]["finding-long"]
	assert len(long_finding["excerpts"]) == min(
		MAX_EXCERPTS_PER_FINDING,
		MAX_TOTAL_EXCERPT_CHARS // MAX_EXCERPT_CHARS,
	)
	assert all(
		len(excerpt["text"]) == MAX_EXCERPT_CHARS
		for excerpt in long_finding["excerpts"]
	)

	print("codex_insights_author selftest passed")


def parse_arguments() -> argparse.Namespace:
	"""Parse bounded input/output paths or the isolated self-test request."""
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument(
		"--input",
		"--extraction",
		dest="input",
		type=Path,
		default=DEFAULT_EXTRACTION_PATH,
	)
	parser.add_argument(
		"--narrative",
		"--narrative-input",
		dest="narrative",
		type=Path,
		default=DEFAULT_NARRATIVE_PATH,
	)
	parser.add_argument(
		"--output",
		"--bundle-output",
		dest="output",
		type=Path,
		default=DEFAULT_BUNDLE_PATH,
	)
	parser.add_argument("--selftest", action="store_true")
	arguments = parser.parse_args()
	if arguments.selftest and any(
		path != default
		for path, default in (
			(arguments.input, DEFAULT_EXTRACTION_PATH),
			(arguments.narrative, DEFAULT_NARRATIVE_PATH),
			(arguments.output, DEFAULT_BUNDLE_PATH),
		)
	):
		parser.error("--selftest cannot be combined with custom paths")

	return arguments


def main() -> None:
	"""Read the two upstream artefacts and write their bounded authoring bundle."""
	arguments = parse_arguments()
	if arguments.selftest:
		run_selftest()
		return

	extraction, extraction_bytes = load_json(arguments.input)
	narrative, narrative_bytes = load_json(arguments.narrative)
	bundle = make_authoring_bundle(
		narrative,
		extraction,
		hash_bytes(extraction_bytes),
		hash_bytes(narrative_bytes),
	)
	write_json(arguments.output, bundle)
	print(f"Wrote authoring bundle for {len(bundle['findings'])} findings")


if __name__ == "__main__":
	main()
