#!/usr/bin/env python3
"""Classify bounded Codex evidence into facets and actionable findings."""

from __future__ import annotations

import argparse
import datetime
import json
import shlex
import tempfile
from pathlib import Path
from typing import Iterable

from codex_insights_facets_common import (
	CANDIDATE_FIELDS,
	CONFIGURATION_BASENAME_PATTERN,
	CONFIGURATION_TOKEN_PATTERN,
	DEFAULT_EXTRACTION_PATH,
	DEFAULT_FACETS_PATH,
	DEFAULT_NARRATIVE_PATH,
	EXTRACTION_SCHEMA_VERSION,
	FACETS_SCHEMA_VERSION,
	MAX_CONFIGURATION_BYTES,
	MAX_EVENTS_PER_CONVERSATION,
	MAX_EVIDENCE_REFERENCES_PER_CITATION,
	MAX_FINDINGS,
	MAX_LIMITATIONS_PER_CONVERSATION,
	MAX_PATTERN_CITATIONS,
	MAX_PATTERN_OBSERVATIONS,
	MAX_TURNS_PER_ROLLOUT,
	NARRATIVE_SCHEMA_VERSION,
	UTC,
	ProvenanceError,
	available_conversation_id,
	bounded_text,
	conversation_key,
	earliest_timestamp,
	event_classification,
	format_timestamp,
	hash_bytes,
	load_json,
	normalise_pattern_key,
	parse_timestamp,
	references_for_entries,
	require_count,
	require_mapping,
	require_string,
	serialise,
	validate_extraction,
	validate_references,
)

# Common-module names re-exported here so codex_insights_render.py can import them from this module.
__all__ = (
	"ProvenanceError",
	"hash_bytes",
	"load_json",
	"require_mapping",
	"require_string",
	"validate_extraction",
)


def derive_turns(
	rollout: dict[str, object], evidence_index: dict[str, dict[str, object]]
) -> list[dict[str, object]]:
	"""Derive bounded authored-user turns from ordered retained evidence."""
	evidence = rollout.get("evidence", [])
	if not isinstance(evidence, list):
		return []

	authored_indexes = [
		index for index, entry in enumerate(evidence) if entry.get("kind") == "authored_user_message"
	]
	turns = []
	for turn_index, start_index in enumerate(authored_indexes[:MAX_TURNS_PER_ROLLOUT], start=1):
		end_index = authored_indexes[turn_index] if turn_index < len(authored_indexes) else len(evidence)
		entries = evidence[start_index:end_index]
		references = [entry["reference"] for entry in entries if entry.get("reference") in evidence_index]
		if not references:
			continue

		turns.append(
			{
				"turn_index": turn_index,
				"evidence_references": references[:MAX_EVIDENCE_REFERENCES_PER_CITATION * 4],
				"start_timestamp": format_timestamp(evidence_index[references[0]].get("timestamp")),
				"classification": {
					"label": "authored_turn",
					"method": "ordered_retained_evidence",
					"confidence": "high",
				},
			}
		)

	return turns


def candidate_event(
	rollout: dict[str, object],
	candidate_value: dict[str, object],
	kind: str,
	evidence_index: dict[str, dict[str, object]],
) -> dict[str, object]:
	"""Convert one extractor candidate into a traceable facet observation."""
	references = list(candidate_value["evidence_references"])
	status = candidate_value.get("status")
	target = bounded_text(candidate_value.get("target"), 280)
	return {
		"kind": kind,
		"source": bounded_text(candidate_value.get("source"), 80),
		"target": target,
		"status": status,
		"evidence_references": references,
		"timestamp": earliest_timestamp([candidate_value], evidence_index),
		"conversation_id": available_conversation_id(rollout),
		"rollout_id": rollout.get("rollout_id"),
		"classification": event_classification(kind, status),
	}


def ledger_event(
	rollout: dict[str, object],
	ledger_entry: dict[str, object],
	kind: str,
	evidence_index: dict[str, dict[str, object]],
) -> dict[str, object]:
	"""Convert one bounded tool ledger entry into a facet observation."""
	references = [
		reference
		for reference in (ledger_entry.get("call_reference"), ledger_entry.get("result_reference"))
		if isinstance(reference, str)
	]
	return {
		"kind": kind,
		"source": ledger_entry.get("status_source"),
		"target": bounded_text(ledger_entry.get("target"), 280),
		"status": ledger_entry.get("status"),
		"expected_probe": ledger_entry.get("expected_probe"),
		"evidence_references": references,
		"timestamp": earliest_timestamp([{"evidence_references": references}], evidence_index),
		"conversation_id": available_conversation_id(rollout),
		"rollout_id": rollout.get("rollout_id"),
		"classification": event_classification(kind, ledger_entry.get("status")),
	}


def derive_observations(
	rollout: dict[str, object], evidence_index: dict[str, dict[str, object]]
) -> list[dict[str, object]]:
	"""Derive all bounded behavioural observations from one extractor rollout."""
	observations = []
	seen = set()

	def add_observation(observation: dict[str, object]) -> None:
		"""Keep one observation per kind and evidence set within the conversation bound."""
		references = tuple(observation["evidence_references"])
		identity = (observation["kind"], references)
		if not references or identity in seen or len(observations) >= MAX_EVENTS_PER_CONVERSATION:
			return

		seen.add(identity)
		observations.append(observation)

	for field_name, kind in CANDIDATE_FIELDS.items():
		for candidate_value in rollout.get("candidates", {}).get(field_name, []):
			add_observation(candidate_event(rollout, candidate_value, kind, evidence_index))

	for ledger_value in rollout.get("tool_ledger", []):
		ledger_entry = require_mapping(ledger_value, "rollout.tool_ledger[]")
		status = ledger_entry.get("status")
		expected_probe = ledger_entry.get("expected_probe")
		if status == "failure" and expected_probe != "explicit":
			add_observation(ledger_event(rollout, ledger_entry, "tool_failure", evidence_index))
		if status == "success":
			add_observation(ledger_event(rollout, ledger_entry, "successful_behaviour", evidence_index))
		if status == "unknown" and expected_probe != "explicit":
			add_observation(ledger_event(rollout, ledger_entry, "verification_gap", evidence_index))

	return observations


def event_summary(event: dict[str, object]) -> str:
	"""Describe one observation without exposing more transcript content than needed."""
	kind = event["kind"]
	target = event.get("target")
	if isinstance(target, str) and target:
		return f"{kind}: {target}"

	return str(kind)


def limitation(
	kind: str, summary: str, references: Iterable[str] = ()
) -> dict[str, object]:
	"""Build one explicit limitation or unavailable state."""
	return {
		"kind": kind,
		"summary": summary,
		"evidence_references": list(references),
		"confidence": "high" if kind == "unavailable" else "medium",
	}


def conversation_facet(
	conversation_id: str | None,
	rollouts: list[dict[str, object]],
	evidence_index: dict[str, dict[str, object]],
) -> tuple[dict[str, object], list[dict[str, object]]]:
	"""Build one bounded per-conversation facet and its pattern observations."""
	all_evidence = []
	all_observations = []
	for rollout in rollouts:
		all_evidence.extend(
			entry for entry in rollout.get("evidence", []) if isinstance(entry, dict)
		)
		all_observations.extend(derive_observations(rollout, evidence_index))
	authored_messages = [entry for entry in all_evidence if entry.get("kind") == "authored_user_message"]
	goal_entry = authored_messages[0] if authored_messages else None
	goal = (
		{
			"state": "observed",
			"text": bounded_text(goal_entry.get("excerpt")),
			"evidence_references": [goal_entry["reference"]],
			"classification": "task_goal",
			"confidence": "medium",
		}
		if goal_entry is not None
		else {
			"state": "unavailable",
			"text": None,
			"evidence_references": [],
			"classification": "task_goal",
			"confidence": "high",
		}
	)

	lifecycle_entries = [
		entry
		for entry in all_evidence
		if entry.get("kind") in {"lifecycle_event", "rollback_event"}
	]
	lifecycle_types = {entry.get("event_type") for entry in lifecycle_entries}
	if "task_complete" in lifecycle_types:
		outcome_state = "completed"
	elif "thread_rolled_back" in lifecycle_types:
		outcome_state = "rolled_back"
	elif "turn_aborted" in lifecycle_types:
		outcome_state = "interrupted"
	elif any(rollout.get("activity_state") == "live" for rollout in rollouts):
		outcome_state = "live"
	else:
		outcome_state = "unknown"
	outcome_references = [entry["reference"] for entry in lifecycle_entries]
	outcome = {
		"state": outcome_state,
		"evidence_references": outcome_references,
		"classification": outcome_state,
		"confidence": "high" if lifecycle_entries else "low",
	}

	friction_kinds = {
		"tool_failure",
		"correction",
		"retry",
		"verification_gap",
		"interruption",
		"rollback",
	}
	friction_events = [
		{
			"kind": event["kind"],
			"summary": event_summary(event),
			"evidence_references": event["evidence_references"],
			"classification": event["classification"],
		}
		for event in all_observations
		if event["kind"] in friction_kinds
	]
	successful_behaviours = [
		{
			"summary": event_summary(event),
			"evidence_references": event["evidence_references"],
			"classification": event["classification"],
		}
		for event in all_observations
		if event["kind"] == "successful_behaviour"
	]
	user_interventions = [
		{
			"kind": event["kind"],
			"summary": event_summary(event),
			"evidence_references": event["evidence_references"],
			"classification": event["classification"],
		}
		for event in all_observations
		if event["kind"] in {"correction", "approach_change"}
	]
	verification_gaps = [
		{
			"summary": event_summary(event),
			"evidence_references": event["evidence_references"],
			"classification": event["classification"],
		}
		for event in all_observations
		if event["kind"] == "verification_gap"
	]
	approach_changes = [
		{
			"summary": event_summary(event),
			"evidence_references": event["evidence_references"],
			"classification": event["classification"],
		}
		for event in all_observations
		if event["kind"] == "approach_change"
	]

	limitations = [
		limitation(
			"classifier",
			"Semantic labels are deterministic candidate classifications, not model judgements.",
		)
	]
	for rollout in rollouts:
		for unavailable in rollout.get("unavailable", []):
			limitations.append(
				limitation("unavailable", str(unavailable), rollout.get("uncertain_user_message_references", []))
			)
		truncation = rollout.get("truncation", {})
		if isinstance(truncation, dict) and any(value for value in truncation.values()):
			limitations.append(
				limitation(
					"truncated",
					"The extractor bound omitted some records or candidates.",
					[],
				)
			)
	if len(limitations) > MAX_LIMITATIONS_PER_CONVERSATION:
		limitations = limitations[:MAX_LIMITATIONS_PER_CONVERSATION]

	turns = []
	for rollout in rollouts:
		turns.extend(derive_turns(rollout, evidence_index))
	all_references = references_for_entries(
		[
			{"evidence_references": [entry["reference"] for entry in all_evidence]},
			*all_observations,
		]
	)
	start_timestamps = [parse_timestamp(rollout.get("start_timestamp")) for rollout in rollouts]
	end_timestamps = [parse_timestamp(rollout.get("end_timestamp")) for rollout in rollouts]
	start_timestamps = [timestamp for timestamp in start_timestamps if timestamp is not None]
	end_timestamps = [timestamp for timestamp in end_timestamps if timestamp is not None]
	facet = {
		"conversation_id": conversation_id,
		"conversation_id_state": "available" if conversation_id is not None else "unavailable",
		"rollout_ids": [rollout.get("rollout_id") for rollout in rollouts],
		"time_span": {
			"since": format_timestamp(min(start_timestamps)) if start_timestamps else None,
			"until": format_timestamp(max(end_timestamps)) if end_timestamps else None,
			"state": "observed" if start_timestamps else "unavailable",
		},
		"task_goal": goal,
		"outcome": outcome,
		"turns": turns[:MAX_TURNS_PER_ROLLOUT],
		"friction_events": friction_events,
		"successful_behaviours": successful_behaviours,
		"user_interventions": user_interventions,
		"verification_gaps": verification_gaps,
		"approach_changes": approach_changes,
		"current_limitations": limitations,
		"evidence_references": all_references,
		"confidence": "medium" if conversation_id is not None else "low",
	}
	return facet, all_observations


def pattern_id(kind: str, key: str) -> str:
	"""Return a stable identifier for one normalised pattern."""
	return f"{kind}-{hash_bytes(f'{kind}|{key}'.encode('utf-8'))[:12]}"


def pattern_key(observation: dict[str, object]) -> str:
	"""Return the grouping key that keeps unrelated observations separate."""
	kind = observation["kind"]
	if kind in {"tool_failure", "successful_behaviour", "retry", "configuration_touch", "verification_gap"}:
		return normalise_pattern_key(observation.get("target"))
	if kind == "correction":
		return "user-authored-correction"
	if kind == "approach_change":
		return "user-authored-approach-change"
	return normalise_pattern_key(observation.get("source") or kind)


def pattern_configuration_target(observation: dict[str, object]) -> bool:
	"""Return whether one observation names a configuration surface to inspect."""
	if observation["kind"] == "configuration_touch":
		return True

	target = observation.get("target")
	return isinstance(target, str) and bool(CONFIGURATION_TOKEN_PATTERN.search(target))


def configuration_tokens(target: str) -> list[str]:
	"""Return named configuration paths from one bounded tool target."""
	try:
		tokens = shlex.split(target)
	except ValueError:
		tokens = target.split()

	candidates = []
	for token in tokens:
		cleaned = token.strip("()[]{}<>,;:\"'")
		if CONFIGURATION_TOKEN_PATTERN.search(cleaned) or CONFIGURATION_BASENAME_PATTERN.match(cleaned):
			candidates.append(cleaned)

	return list(dict.fromkeys(candidates))


def configuration_markers_for_pattern(kind: str, observed_pattern: str) -> tuple[str, ...]:
	"""Return the observed pattern detail used to check one configuration surface."""
	prefix = f"{kind}:"
	marker = observed_pattern.strip()
	if marker.casefold().startswith(prefix.casefold()):
		marker = marker[len(prefix) :].strip()

	return (marker,) if marker else ()


def configuration_status(
	target: object,
	project_path: object,
	required_markers: Iterable[str] = (),
) -> dict[str, object]:
	"""Read one named current configuration surface before recommending a change."""
	if not isinstance(target, str) or not target:
		return {"status": "ambiguous", "surface": None, "path": None, "read": False}
	tokens = configuration_tokens(target)
	if len(tokens) != 1:
		return {
			"status": "ambiguous",
			"surface": tokens or None,
			"path": None,
			"read": False,
		}

	surface = tokens[0]
	surface_path = Path(surface).expanduser()
	if not surface_path.is_absolute():
		base = Path(project_path).expanduser() if project_path else Path.cwd()
		surface_path = base / surface_path
	try:
		surface_path = surface_path.resolve()
	except OSError:
		return {"status": "unavailable", "surface": surface, "path": None, "read": False}

	if not surface_path.exists():
		return {"status": "missing", "surface": surface, "path": surface_path.as_posix(), "read": False}
	if not surface_path.is_file():
		return {"status": "ambiguous", "surface": surface, "path": surface_path.as_posix(), "read": False}

	try:
		contents = surface_path.read_bytes()
	except OSError:
		return {"status": "unavailable", "surface": surface, "path": surface_path.as_posix(), "read": False}
	if len(contents) > MAX_CONFIGURATION_BYTES:
		return {
			"status": "unavailable",
			"surface": surface,
			"path": surface_path.as_posix(),
			"read": False,
			"reason": "configuration_surface_exceeds_bound",
		}

	try:
		text = contents.decode("utf-8")
	except UnicodeDecodeError:
		return {
			"status": "unavailable",
			"surface": surface,
			"path": surface_path.as_posix(),
			"read": False,
			"reason": "configuration_surface_is_not_utf8",
		}

	marker_values = [marker.casefold() for marker in required_markers]
	if marker_values and all(marker in text.casefold() for marker in marker_values):
		status = "already_remediated"
	else:
		status = "present_but_ignored"
	return {
		"status": status,
		"surface": surface,
		"path": surface_path.as_posix(),
		"read": True,
		"sha256": hash_bytes(contents),
		"byte_count": len(contents),
	}


def configuration_status_for_pattern(
	observations: list[dict[str, object]],
	cache: dict[tuple[str, str, tuple[str, ...]], dict[str, object]],
	kind: str,
	observed_pattern: str,
) -> list[dict[str, object]]:
	"""Inspect each project surface represented by a pattern's observations."""
	required_markers = configuration_markers_for_pattern(kind, observed_pattern)
	statuses = []
	for observation in observations:
		if not pattern_configuration_target(observation):
			continue
		target = observation.get("target")
		project_path = observation.get("project_path")
		cache_key = (str(project_path or ""), str(target or ""), required_markers)
		if cache_key not in cache:
			cache[cache_key] = configuration_status(target, project_path, required_markers)
		status = cache[cache_key]
		if status not in statuses:
			statuses.append(status)

	return statuses


def build_patterns(
	observations: list[dict[str, object]],
	configuration_cache: dict[tuple[str, str], dict[str, object]],
) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
	"""Group observations by kind and normalised target across unique conversations."""
	groups: dict[tuple[str, str], list[dict[str, object]]] = {}
	for observation in observations[:MAX_PATTERN_OBSERVATIONS]:
		key = (observation["kind"], pattern_key(observation))
		groups.setdefault(key, []).append(observation)

	patterns = []
	for (kind, key), group in sorted(groups.items()):
		conversation_ids = sorted(
			{
				observation["conversation_id"]
				for observation in group
				if isinstance(observation.get("conversation_id"), str)
			}
		)
		citations = []
		for conversation_id in conversation_ids:
			conversation_group = [
				observation for observation in group if observation.get("conversation_id") == conversation_id
			]
			first = conversation_group[0]
			references = references_for_entries(conversation_group)
			citations.append(
				{
					"conversation_id": conversation_id,
					"rollout_id": first.get("rollout_id"),
					"timestamp": first.get("timestamp"),
					"evidence_references": references[:MAX_EVIDENCE_REFERENCES_PER_CITATION],
					"detail": event_summary(first),
				}
			)
		for observation in group:
			if observation.get("conversation_id") is None and len(citations) < MAX_PATTERN_CITATIONS:
				citations.append(
					{
						"conversation_id": None,
						"rollout_id": observation.get("rollout_id"),
						"timestamp": observation.get("timestamp"),
						"evidence_references": observation["evidence_references"][:MAX_EVIDENCE_REFERENCES_PER_CITATION],
						"detail": event_summary(observation),
					}
				)

		first_timestamps = [parse_timestamp(observation.get("timestamp")) for observation in group]
		first_timestamps = [timestamp for timestamp in first_timestamps if timestamp is not None]
		labels = {
			observation.get("classification", {}).get("label")
			for observation in group
			if isinstance(observation.get("classification"), dict)
		}
		labels.discard(None)
		classification_label = next(iter(labels)) if len(labels) == 1 else "mixed_causes"
		observed_pattern = event_summary(group[0])
		configuration_statuses = configuration_status_for_pattern(
			group, configuration_cache, kind, observed_pattern
		)
		patterns.append(
			{
				"pattern_id": pattern_id(kind, key),
				"kind": kind,
				"key": key,
				"observed_pattern": observed_pattern,
				"occurrence_count": len(group),
				"unique_conversation_count": len(conversation_ids),
				"conversation_ids": conversation_ids,
				"recurrence_state": "repeated"
				if len(conversation_ids) >= 2
				else "illustrated_once"
				if conversation_ids
				else "unavailable",
				"time_span": {
					"since": format_timestamp(min(first_timestamps)) if first_timestamps else None,
					"until": format_timestamp(max(first_timestamps)) if first_timestamps else None,
					"state": "observed" if first_timestamps else "unavailable",
				},
				"classification": {
					"label": classification_label,
					"method": "deterministic_candidate_grouping",
					"confidence": "high" if len(conversation_ids) >= 2 else "low",
				},
				"supporting_evidence": citations[:MAX_PATTERN_CITATIONS],
				"evidence_references": references_for_entries(group),
				"configuration_statuses": configuration_statuses,
				"counterevidence_or_limitations": [
					"Only retained bounded evidence is available to this pass.",
					"A single conversation illustrates a pattern but does not establish recurrence."
					if len(conversation_ids) < 2
					else "Recurrence is counted across unique conversation IDs, not rollout rows.",
				],
			}
		)

	repeated_patterns = [pattern for pattern in patterns if pattern["recurrence_state"] == "repeated"]
	return patterns, repeated_patterns


def layer_for_surface(surface: object) -> str:
	"""Choose the owning configuration layer for one named surface."""
	value = str(surface or "").casefold()
	if "agents.md" in value:
		return "rule"
	if "workspace.md" in value:
		return "workflow"
	if "skill" in value:
		return "skill"
	if "hook" in value:
		return "hook"
	if "script" in value:
		return "script"
	return "tooling"


def finding_owner(kind: str) -> str:
	"""Return a plain-language owner for one repeated observation."""
	if kind in {"correction", "tool_failure"}:
		return "agent"
	if kind == "configuration_touch":
		return "configuration"
	if kind == "successful_behaviour":
		return "workflow"
	return "workflow"


def proposed_change(pattern: dict[str, object]) -> tuple[str, str, str]:
	"""Return a bounded layer, target, and exact change or next investigation."""
	kind = pattern["kind"]
	observed = pattern["observed_pattern"]
	statuses = pattern.get("configuration_statuses", [])
	if kind == "configuration_touch" and statuses:
		status = statuses[0]
		path = status.get("path") or status.get("surface") or "named configuration surface"
		layer = layer_for_surface(status.get("surface"))
		if status.get("status") == "missing":
			return layer, str(path), f"Add guidance for {observed} to {path} after confirming its owning project."
		if status.get("status") == "already_remediated":
			return layer, str(path), f"Do not add duplicate guidance; investigate why the observed behaviour bypassed {path}."
		if status.get("status") == "present_but_ignored":
			return layer, str(path), f"Do not duplicate prose; investigate deterministic enforcement for the observed use of {path}."
		return layer, str(path), f"Resolve access to {path} before choosing a configuration change."

	if kind == "successful_behaviour":
		return "workflow", "team workflow", f"Standardise the successful bounded behaviour shown by {observed} and measure repeat success."
	if kind == "correction":
		return "skill", "codex-insights workflow", f"Add a focused check for the corrected behaviour represented by {observed}."
	if kind in {"tool_failure", "verification_gap"}:
		return "workflow", "verification step", f"Add a bounded verification step for {observed}, then measure whether the failure recurs."
	if kind == "retry":
		return "workflow", "retry path", f"Document or instrument the bounded retry path represented by {observed}."
	if kind in {"interruption", "rollback"}:
		return "workflow", "interruption recovery", f"Add a bounded recovery check for {observed}."
	return "workflow", "approach-selection workflow", f"Investigate the approach change represented by {observed} before adding guidance."


def narrative_finding(pattern: dict[str, object]) -> dict[str, object]:
	"""Convert one repeated facet pattern into the actionable finding contract."""
	layer, target, change = proposed_change(pattern)
	status = pattern.get("configuration_statuses", [])
	if not status:
		current_configuration = {
			"status": "not_applicable",
			"surfaces": [],
		}
	elif len({entry.get("status") for entry in status}) == 1:
		current_configuration = {
			"status": status[0].get("status"),
			"surfaces": status,
		}
	else:
		current_configuration = {"status": "ambiguous", "surfaces": status}

	limitations = list(pattern.get("counterevidence_or_limitations", []))
	if pattern["kind"] == "successful_behaviour":
		limitations.append("Successful tool status does not alone prove that the user accepted the result.")
	else:
		limitations.append("The deterministic pass does not infer intent beyond the retained candidate evidence.")
	return {
		"finding_id": pattern["pattern_id"],
		"kind": pattern["kind"],
		"observed_pattern": pattern["observed_pattern"],
		"frequency": {
			"occurrences": pattern["occurrence_count"],
			"unique_conversations": pattern["unique_conversation_count"],
			"state": "repeated",
		},
		"time_span": pattern["time_span"],
		"diagnosis": pattern["classification"],
		"owner": finding_owner(pattern["kind"]),
		"consequence": f"The repeated pattern affects work represented by {pattern['observed_pattern']}.",
		"proposed_layer": layer,
		"proposed_target": target,
		"exact_change_or_next_investigation": change,
		"supporting_evidence": pattern["supporting_evidence"],
		"counterevidence_or_limitations": limitations,
		"current_configuration_status": current_configuration,
		"confidence": pattern["classification"]["confidence"],
	}


def make_facets(
	extraction_info: dict[str, object],
) -> dict[str, object]:
	"""Build the bounded facet document from one validated extraction."""
	extraction = extraction_info["document"]
	evidence_index = extraction_info["evidence_index"]
	rollouts = extraction_info["rollout_index"]
	by_conversation: dict[str, list[dict[str, object]]] = {}
	for rollout in rollouts.values():
		by_conversation.setdefault(conversation_key(rollout), []).append(rollout)

	conversation_facets = []
	all_observations = []
	for key, conversation_rollouts in sorted(by_conversation.items()):
		conversation_id = available_conversation_id(conversation_rollouts[0])
		facet, observations = conversation_facet(conversation_id, conversation_rollouts, evidence_index)
		conversation_facets.append(facet)
		for observation in observations:
			observation["project_path"] = conversation_rollouts[0].get("project_path")
		all_observations.extend(observations)

	configuration_cache: dict[tuple[str, str, tuple[str, ...]], dict[str, object]] = {}
	patterns, repeated_patterns = build_patterns(all_observations, configuration_cache)
	return {
		"schema_version": FACETS_SCHEMA_VERSION,
		"generated_at": format_timestamp(datetime.datetime.now(UTC)),
		"provenance": extraction_info["binding"],
		"counts": {
			"conversation_facet_count": len(conversation_facets),
			"pattern_count": len(patterns),
			"repeated_pattern_count": len(repeated_patterns),
		},
		"conversations": conversation_facets,
		"patterns": patterns,
		"repeated_patterns": repeated_patterns,
		"limitations": [
			"Patterns without two available conversation IDs remain illustrations, not recurrence findings.",
			"Current-configuration statuses are based on bounded reads of named surfaces only.",
		],
	}


def expected_binding(extraction_info: dict[str, object]) -> dict[str, object]:
	"""Return the binding expected in a facet or narrative document."""
	return extraction_info["binding"]


def validate_binding(
	value: object,
	extraction_info: dict[str, object],
	location: str,
) -> None:
	"""Reject stale or mismatched provenance before downstream synthesis."""
	document = require_mapping(value, location)
	binding = require_mapping(document.get("provenance"), f"{location}.provenance")
	expected = expected_binding(extraction_info)
	for field_name in expected:
		if binding.get(field_name) != expected[field_name]:
			raise ProvenanceError(
				f"{location}.provenance.{field_name} does not match the extraction"
			)


def validate_facets(
	facets: dict[str, object], extraction_info: dict[str, object]
) -> None:
	"""Validate facet provenance, pattern recurrence, and all evidence references."""
	if facets.get("schema_version") != FACETS_SCHEMA_VERSION:
		raise ProvenanceError("unsupported facets schema version")
	validate_binding(facets, extraction_info, "facets")
	evidence_index = extraction_info["evidence_index"]
	conversations = facets.get("conversations")
	if not isinstance(conversations, list):
		raise ProvenanceError("facets.conversations must be an array")
	for facet in conversations:
		facet_value = require_mapping(facet, "facets.conversations[]")
		validate_references(facet_value.get("evidence_references", []), evidence_index, "facet")
		for field_name in (
			"turns",
			"friction_events",
			"successful_behaviours",
			"user_interventions",
			"verification_gaps",
			"approach_changes",
		):
			entries = facet_value.get(field_name, [])
			if not isinstance(entries, list):
				raise ProvenanceError(f"facet.{field_name} must be an array")
			for entry in entries:
				entry_value = require_mapping(entry, f"facet.{field_name}[]")
				validate_references(entry_value.get("evidence_references", []), evidence_index, field_name)

	for pattern in facets.get("patterns", []):
		pattern_value = require_mapping(pattern, "facets.patterns[]")
		validate_references(pattern_value.get("evidence_references", []), evidence_index, "pattern")
		if pattern_value.get("recurrence_state") == "repeated":
			if pattern_value.get("unique_conversation_count", 0) < 2:
				raise ProvenanceError("repeated pattern must cite at least two conversations")
			citations = pattern_value.get("supporting_evidence", [])
			citation_ids = {
				citation.get("conversation_id")
				for citation in citations
				if isinstance(citation, dict) and citation.get("conversation_id")
			}
			if len(citation_ids) < 2:
				raise ProvenanceError("repeated pattern is missing unique conversation citations")
			for citation in citations:
				citation_value = require_mapping(citation, "pattern.supporting_evidence[]")
				validate_references(citation_value.get("evidence_references", []), evidence_index, "citation")

	for pattern in facets.get("repeated_patterns", []):
		if pattern not in facets.get("patterns", []):
			raise ProvenanceError("facets.repeated_patterns contains an unknown pattern")


def validate_narrative(
	narrative: dict[str, object],
	extraction_info: dict[str, object],
	facets: dict[str, object],
	facets_sha256: str,
) -> None:
	"""Validate the actionable narrative contract and its two upstream bindings."""
	if narrative.get("schema_version") != NARRATIVE_SCHEMA_VERSION:
		raise ProvenanceError("unsupported narrative schema version")
	validate_binding(narrative, extraction_info, "narrative")
	provenance = require_mapping(narrative.get("provenance"), "narrative.provenance")
	if provenance.get("facets_schema_version") != FACETS_SCHEMA_VERSION:
		raise ProvenanceError("narrative facets schema version does not match")
	if provenance.get("facets_sha256") != facets_sha256:
		raise ProvenanceError("narrative facets SHA-256 does not match")
	if provenance.get("facets_pattern_count") != facets.get("counts", {}).get("pattern_count"):
		raise ProvenanceError("narrative facets pattern count does not match")

	evidence_index = extraction_info["evidence_index"]
	findings = narrative.get("findings")
	if not isinstance(findings, list) or len(findings) > MAX_FINDINGS:
		raise ProvenanceError("narrative.findings must be a bounded array")
	for finding in findings:
		finding_value = require_mapping(finding, "narrative.findings[]")
		frequency = require_mapping(finding_value.get("frequency"), "finding.frequency")
		if require_count(frequency.get("unique_conversations"), "finding.frequency.unique_conversations") < 2:
			raise ProvenanceError("narrative finding must cite at least two conversations")
		supporting_evidence = finding_value.get("supporting_evidence")
		if not isinstance(supporting_evidence, list):
			raise ProvenanceError("finding.supporting_evidence must be an array")
		conversation_ids = set()
		for citation in supporting_evidence:
			citation_value = require_mapping(citation, "finding.supporting_evidence[]")
			conversation_id = citation_value.get("conversation_id")
			if isinstance(conversation_id, str) and conversation_id:
				conversation_ids.add(conversation_id)
			validate_references(citation_value.get("evidence_references", []), evidence_index, "finding citation")
		if len(conversation_ids) < 2:
			raise ProvenanceError("finding must cite two unique conversation IDs")


def make_narrative(
	facets: dict[str, object], extraction_info: dict[str, object], facets_sha256: str
) -> dict[str, object]:
	"""Build the decision-oriented narrative document from validated repeated patterns."""
	repeated_patterns = facets.get("repeated_patterns", [])
	findings = [narrative_finding(pattern) for pattern in repeated_patterns[:MAX_FINDINGS]]
	return {
		"schema_version": NARRATIVE_SCHEMA_VERSION,
		"generated_at": format_timestamp(datetime.datetime.now(UTC)),
		"provenance": {
			**extraction_info["binding"],
			"facets_schema_version": FACETS_SCHEMA_VERSION,
			"facets_sha256": facets_sha256,
			"facets_pattern_count": facets.get("counts", {}).get("pattern_count"),
		},
		"findings": findings,
		"limitations": [
			"Only repeated patterns with at least two unique conversation citations become findings.",
			"The narrative does not replace direct review when bounded evidence is unavailable.",
		],
	}


def write_json(path: Path, value: dict[str, object]) -> None:
	"""Write one generated JSON artefact, creating its parent directory."""
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(serialise(value), encoding="utf-8")


def fixture_extraction(project_path: Path) -> dict[str, object]:
	"""Build a small Commit 1-shaped extraction with repeated and bounded evidence."""
	def rollout(rollout_id: str, conversation_id: str, offset: int) -> dict[str, object]:
		def reference(index: int) -> str:
			return f"{rollout_id}:r{index:06d}"

		evidence = [
			{
				"reference": reference(0),
				"timestamp": f"2026-08-08T10:{offset:02d}:00Z",
				"kind": "authored_user_message",
				"authorship": "authored",
				"excerpt": "Please fix the repeated configuration check and verify it.",
			},
			{
				"reference": reference(1),
				"timestamp": f"2026-08-08T10:{offset:02d}:01Z",
				"kind": "assistant_message",
				"excerpt": "I will inspect the configuration.",
			},
			{
				"reference": reference(2),
				"timestamp": f"2026-08-08T10:{offset:02d}:02Z",
				"kind": "tool_call",
				"target": "cat AGENTS.md",
			},
			{
				"reference": reference(3),
				"timestamp": f"2026-08-08T10:{offset:02d}:03Z",
				"kind": "tool_result",
				"excerpt": "Process exited with code 1",
			},
			{
				"reference": reference(4),
				"timestamp": f"2026-08-08T10:{offset:02d}:04Z",
				"kind": "tool_call",
				"target": "cat AGENTS.md",
			},
			{
				"reference": reference(5),
				"timestamp": f"2026-08-08T10:{offset:02d}:05Z",
				"kind": "tool_result",
				"excerpt": "Process exited with code 0",
			},
			{
				"reference": reference(6),
				"timestamp": f"2026-08-08T10:{offset:02d}:06Z",
				"kind": "lifecycle_event",
				"event_type": "task_complete",
			},
		]
		candidate_values = {
			"approach_changes": [
				{"kind": "approach_change", "source": "authored_user_message", "evidence_references": [reference(0)]}
			],
			"configuration_touches": [
				{"kind": "configuration_touch", "target": "cat AGENTS.md", "evidence_references": [reference(2)]}
			],
			"corrections": [
				{"kind": "correction", "source": "authored_user_message", "evidence_references": [reference(0)]}
			],
			"interruptions": [],
			"retries": [
				{
					"kind": "retry",
					"target": "cat AGENTS.md",
					"evidence_references": [reference(2), reference(3), reference(4)],
				}
			],
			"rollbacks": [],
			"verification": [
				{
					"kind": "verification",
					"source": "failed_tool_event",
					"status": "failure",
					"evidence_references": [reference(2), reference(3)],
				}
			],
		}
		ledger = [
			{
				"call_id": f"failure-{rollout_id}",
				"call_reference": reference(2),
				"result_reference": reference(3),
				"target": "cat AGENTS.md",
				"status": "failure",
				"status_source": "structured_exit_code",
				"exit_code": 1,
				"expected_probe": "not_expected",
			},
			{
				"call_id": f"success-{rollout_id}",
				"call_reference": reference(4),
				"result_reference": reference(5),
				"target": "cat AGENTS.md",
				"status": "success",
				"status_source": "structured_exit_code",
				"exit_code": 0,
				"expected_probe": "not_expected",
			},
		]
		return {
			"rollout_id": rollout_id,
			"conversation_id": conversation_id,
			"delegation_state": "parent",
			"subagent_role": None,
			"project_path": project_path.as_posix(),
			"start_timestamp": f"2026-08-08T10:{offset:02d}:00Z",
			"end_timestamp": f"2026-08-08T10:{offset:02d}:06Z",
			"activity_state": "elapsed",
			"uncertain_user_message_references": [],
			"tool_ledger": ledger,
			"evidence": evidence,
			"candidates": candidate_values,
			"truncation": {"candidate_count": 0, "evidence_count": 0, "tool_event_count": 0},
			"unavailable": [],
		}

	rollouts = [rollout("rollout-a", "conversation-a", 10), rollout("rollout-b", "conversation-b", 20)]
	return {
		"schema_version": EXTRACTION_SCHEMA_VERSION,
		"window": {
			"since": "2026-08-08T10:00:00Z",
			"until": "2026-08-08T11:00:00Z",
			"end_utc_exclusive": "2026-08-08T11:00:00Z",
		},
		"provenance": {
			"input_sha256": "a" * 64,
			"source_hashes": ["b" * 64],
		},
		"counts": {
			"rollout_count": 2,
			"conversation_count": 2,
			"subagent_rollout_count": 0,
			"conversation_id_unavailable_count": 0,
			"subagent_role_unavailable_count": 0,
		},
		"rollouts": rollouts,
	}


def run_selftest() -> None:
	"""Verify schema binding, derived facets, recurrence, configuration status, and tamper rejection."""
	with tempfile.TemporaryDirectory() as directory:
		root = Path(directory)
		project = root / "project"
		project.mkdir()
		observed_pattern = "configuration_touch: cat AGENTS.md"
		marker = configuration_markers_for_pattern("configuration_touch", observed_pattern)[0]
		other_marker = configuration_markers_for_pattern(
			"configuration_touch", "configuration_touch: cat WORKSPACE.md"
		)[0]
		assert marker == "cat AGENTS.md"
		assert marker != other_marker
		(project / "AGENTS.md").write_text(
			f"Read this project guidance.\nThe {marker} is documented here.\n",
			encoding="utf-8",
		)
		extraction_path = root / "latest.json"
		write_json(extraction_path, fixture_extraction(project))
		extraction_info = validate_extraction(extraction_path)
		facets = make_facets(extraction_info)
		validate_facets(facets, extraction_info)
		facets_path = root / "latest-facets.json"
		write_json(facets_path, facets)
		facets_sha256 = hash_bytes(facets_path.read_bytes())
		facets_from_disk = load_json(facets_path)
		validate_facets(facets_from_disk, extraction_info)
		narrative = make_narrative(facets_from_disk, extraction_info, facets_sha256)
		validate_narrative(narrative, extraction_info, facets_from_disk, facets_sha256)

		assert len(facets["conversations"]) == 2
		assert all(facet["task_goal"]["evidence_references"] for facet in facets["conversations"])
		assert all(facet["turns"] for facet in facets["conversations"])
		assert facets["repeated_patterns"]
		assert all(pattern["unique_conversation_count"] >= 2 for pattern in facets["repeated_patterns"])
		agents_pattern = next(
			pattern for pattern in facets["repeated_patterns"] if pattern["kind"] == "configuration_touch"
		)
		assert len(agents_pattern["supporting_evidence"]) >= 2
		assert agents_pattern["configuration_statuses"][0]["status"] == "already_remediated"
		assert narrative["findings"]
		assert all(finding["frequency"]["unique_conversations"] >= 2 for finding in narrative["findings"])

		missing = configuration_status("cat WORKSPACE.md", project)
		assert missing["status"] == "missing"
		ambiguous = configuration_status("cat AGENTS.md WORKSPACE.md", project)
		assert ambiguous["status"] == "ambiguous"
		remediated = configuration_status(
			"cat AGENTS.md", project, required_markers=("read this project guidance",)
		)
		assert remediated["status"] == "already_remediated"
		ignored = configuration_status("cat AGENTS.md", project, required_markers=(other_marker,))
		assert ignored["status"] == "present_but_ignored"
		missing_pattern = {
			"kind": "configuration_touch",
			"observed_pattern": observed_pattern,
			"configuration_statuses": [
				{"status": "missing", "surface": "AGENTS.md", "path": "AGENTS.md"}
			],
		}
		_, _, missing_change = proposed_change(missing_pattern)
		assert observed_pattern in missing_change
		assert "required behaviour" not in missing_change

		tampered_extraction = json.loads(extraction_path.read_text(encoding="utf-8"))
		tampered_extraction["counts"]["rollout_count"] = 1
		tampered_extraction_path = root / "tampered-extraction.json"
		write_json(tampered_extraction_path, tampered_extraction)
		try:
			validate_binding(facets, validate_extraction(tampered_extraction_path), "facets")
		except ProvenanceError:
			pass
		else:
			raise AssertionError("tampered extraction provenance was accepted")

		tampered_facets = json.loads(facets_path.read_text(encoding="utf-8"))
		tampered_facets["provenance"]["input_sha256"] = "c" * 64
		try:
			validate_facets(tampered_facets, extraction_info)
		except ProvenanceError:
			pass
		else:
			raise AssertionError("tampered facets provenance was accepted")

		tampered_narrative = json.loads(json.dumps(narrative))
		tampered_narrative["provenance"]["extraction_sha256"] = "d" * 64
		try:
			validate_narrative(tampered_narrative, extraction_info, facets_from_disk, facets_sha256)
		except ProvenanceError:
			pass
		else:
			raise AssertionError("tampered narrative provenance was accepted")

	print("codex_insights_facets selftest passed")


def parse_arguments() -> argparse.Namespace:
	"""Parse bounded input/output paths or the isolated self-test request."""
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--input", type=Path, default=DEFAULT_EXTRACTION_PATH)
	parser.add_argument("--facets-output", type=Path, default=DEFAULT_FACETS_PATH)
	parser.add_argument("--narrative-output", type=Path, default=DEFAULT_NARRATIVE_PATH)
	parser.add_argument("--selftest", action="store_true")
	arguments = parser.parse_args()
	if arguments.selftest and any(
		path != default
		for path, default in (
			(arguments.input, DEFAULT_EXTRACTION_PATH),
			(arguments.facets_output, DEFAULT_FACETS_PATH),
			(arguments.narrative_output, DEFAULT_NARRATIVE_PATH),
		)
	):
		parser.error("--selftest cannot be combined with custom paths")
	return arguments


def main() -> None:
	"""Validate extraction, write facets, then write its bound actionable narrative."""
	arguments = parse_arguments()
	if arguments.selftest:
		run_selftest()
		return

	extraction_info = validate_extraction(arguments.input)
	facets = make_facets(extraction_info)
	validate_facets(facets, extraction_info)
	write_json(arguments.facets_output, facets)
	facets_sha256 = hash_bytes(arguments.facets_output.read_bytes())
	narrative = make_narrative(facets, extraction_info, facets_sha256)
	validate_narrative(narrative, extraction_info, facets, facets_sha256)
	write_json(arguments.narrative_output, narrative)
	print(
		f"Wrote {facets['counts']['conversation_facet_count']} conversation facets and "
		f"{len(narrative['findings'])} repeated findings"
	)


if __name__ == "__main__":
	main()
