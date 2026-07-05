#!/usr/bin/env python3
# Flags trigger phrases shared between two skills, so overlapping triggers are
# a deliberate, reviewed choice (cross-referenced in do-not-use-when, or
# allowlisted below) rather than silent wrong-skill-loading risk.

from __future__ import annotations

import json
import re
import sys
from itertools import combinations
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SKILLS_DIR = REPO_ROOT / "skills"

# Pairs already known to overlap and not yet resolved with mutual
# do-not-use-when cross-references. Remove an entry once the two skills name
# each other in do-not-use-when.
#
# TODO(section 7): remove the six code-review / project-review-* entries once
# those skills cross-reference each other in do-not-use-when.
ALLOWLIST = {
	frozenset({"accessibility", "accessibility-audit"}),  # TODO(section 7): building vs auditing accessibility, same domain
	frozenset({"bash", "typescript"}),  # TODO(section 7): "type alias" is generic to both
	frozenset({"boilersuit-generator-authoring", "vue"}),  # TODO(section 7): "template" is generic
	frozenset({"code-review", "friction-review"}),  # TODO(section 7): review family
	frozenset({"code-review", "project-learn-from-source"}),  # TODO(section 7): review family
	frozenset({"code-review", "project-review-commits"}),  # TODO(section 7): review family
	frozenset({"code-review", "project-review-progress"}),  # TODO(section 7): review family
	frozenset({"code-review", "project-review-worktree"}),  # TODO(section 7): review family
	frozenset({"code-review", "project-synthesise-feedback"}),  # TODO(section 7): review family
	frozenset({"codebase-memory", "fallow"}),  # TODO(section 7): both flag "dead code"
	frozenset({"component-api-design", "frontend-design"}),  # TODO(section 7): "design" is generic
	frozenset({"component-api-design", "vue"}),  # TODO(section 7): shared Vue API vocabulary
	frozenset({"component-api-design", "vue-project-stack"}),  # TODO(section 7): shared Vue API vocabulary
	frozenset({"fallow", "frontend-security"}),  # TODO(section 7): "security" is generic
	frozenset({"frontend-design", "skill-craft"}),  # TODO(section 7): "design" is generic
	frozenset({"frontend-design", "swift-ui"}),  # TODO(section 7): "composition" is generic
	frozenset({"frontend-design", "vue"}),  # TODO(section 7): "composition" is generic
	frozenset({"global-rules", "project-compact-progress"}),  # TODO(section 7): both reference progress.md
	frozenset({"global-rules", "project-review-progress"}),  # TODO(section 7): both reference progress.md
	frozenset({"library-release", "vue-project-stack"}),  # TODO(section 7): "@lewishowles" prefix overlap
	frozenset({"library-release", "writing"}),  # TODO(section 7): "changelog" is generic
	frozenset({"source-extraction", "writing"}),  # TODO(section 7): "article" is generic
	frozenset({"swift", "swift-ui"}),  # TODO(section 7): sibling skills, shared SwiftUI vocabulary
	frozenset({"swift", "test-unit"}),  # TODO(section 7): both reference XCTest
	frozenset({"test-unit", "vue-router"}),  # TODO(section 7): both reference beforeEach
	frozenset({"vue", "vue-project-stack"}),  # TODO(section 7): sibling skills, shared Vue vocabulary
	frozenset({"vue-pinia", "vue-pinia-colada"}),  # TODO(section 7): sibling skills, shared Pinia vocabulary
	frozenset({"vue-project-stack", "vue-router"}),  # TODO(section 7): sibling skills, shared Vue Router vocabulary
	frozenset({"vue-vite", "web-performance"}),  # TODO(section 7): both reference bundle size
	frozenset({"web-performance", "web-performance-audit"}),  # TODO(section 7): building vs auditing performance, same domain
	frozenset({"writing", "writing-readme"}),  # TODO(section 7): sibling skills, shared README vocabulary
}


# A trigger is too generic to compare on its own (a single short word like
# "vue" or "test" is a topic label, not a wrong-skill-loading risk); only
# multi-word phrases or words of at least 5 characters are compared.
def is_eligible(trigger: str) -> bool:
	return " " in trigger or len(trigger) >= 5


def word_contains(needle: str, haystack: str) -> bool:
	if not needle:
		return False
	return re.search(r"(?<!\w)" + re.escape(needle) + r"(?!\w)", haystack) is not None


def load_skills() -> dict[str, dict]:
	skills = {}
	for manifest in sorted(SKILLS_DIR.glob("**/skill.json")):
		data = json.loads(manifest.read_text())
		name = data.get("name")
		if not name:
			continue
		triggers = [t.lower() for t in data.get("triggers", []) if is_eligible(t)]
		dnuw = " ".join(data.get("do-not-use-when", [])).lower()
		skills[name] = {"triggers": triggers, "dnuw": dnuw}
	return skills


def overlapping_triggers(a: dict, b: dict) -> list[tuple[str, str]]:
	hits = []
	for ta in a["triggers"]:
		for tb in b["triggers"]:
			if ta == tb or word_contains(ta, tb) or word_contains(tb, ta):
				hits.append((ta, tb))
	return hits


def main() -> None:
	skills = load_skills()
	failures = []

	for name_a, name_b in combinations(sorted(skills), 2):
		hits = overlapping_triggers(skills[name_a], skills[name_b])
		if not hits:
			continue

		mutual_cross_ref = name_a in skills[name_b]["dnuw"] and name_b in skills[name_a]["dnuw"]
		if mutual_cross_ref:
			continue

		if frozenset({name_a, name_b}) in ALLOWLIST:
			continue

		example = ", ".join(f"{ta!r}/{tb!r}" for ta, tb in hits[:3])
		failures.append(f"  {name_a} <-> {name_b}: overlapping triggers ({example})")

	if failures:
		print("\n".join(failures))
		print(f"\n  {len(failures)} unresolved trigger overlap(s) — add mutual do-not-use-when cross-references or allowlist with a reason")
		sys.exit(1)


if __name__ == "__main__":
	main()
