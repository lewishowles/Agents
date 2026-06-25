#!/usr/bin/env python3
# Generate ChatGPT target files from skill manifests.
#
# Reads authored manifests and generated runtime skills, and writes:
#   dist/chatgpt/SKILLS.md       — index of all included skills with trigger descriptions
#   dist/chatgpt/<name>.md       — verbatim copy of each included SKILL.md
#   dist/chatgpt/INSTRUCTIONS.md — copied from dist/chatgpt/source/system.md
#
# Skills with a 'targets' field that does not include 'chatgpt' are excluded.
# The output directory is cleared before each run so renamed or excluded skills
# do not leave stale files behind.

import json
import shutil
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent.parent
SKILLS_DIR = REPO_DIR / "skills"
DIST_SKILLS_DIR = REPO_DIR / "dist" / "skills"
TARGET_DIR = REPO_DIR / "dist" / "chatgpt"
SOURCE_DIR = TARGET_DIR / "source"


# Read skill.json and return the fields needed for index generation.
#
# @param  {Path}  skill_dir
#     The skill directory containing skill.json.
def load_manifest(skill_dir: Path) -> dict:
	manifest_file = skill_dir / "skill.json"
	if not manifest_file.exists():
		return {}
	data = json.loads(manifest_file.read_text())
	return {
		"name": data.get("name", skill_dir.name),
		"description": data.get("description", ""),
		"do-not-use-when": data.get("do-not-use-when", []),
		"related-skills": data.get("dependencies", []),
		"targets": data.get("targets"),
	}


# Build a single skill section for SKILLS.md from a manifest dict.
#
# @param  {dict}  manifest    Manifest returned by load_manifest.
# @param  {str}   skill_name
#     The skill name used as the section heading.
def build_skill_entry(manifest: dict, skill_name: str) -> str:
	lines = [f"### {skill_name}"]

	description = manifest.get("description", "")
	if description:
		lines.append(f"**When to use:** {description}")

	avoid = manifest.get("do-not-use-when", [])
	if avoid:
		lines.append(f"**Avoid:** {'; '.join(avoid)}")

	related = manifest.get("related-skills", [])
	if related:
		lines.append(f"**Combine with:** {', '.join(related)}")

	return "\n".join(lines)


def main() -> None:
	TARGET_DIR.mkdir(parents=True, exist_ok=True)

	# Clear previously generated files so renamed or excluded skills don't accumulate.
	for f in TARGET_DIR.iterdir():
		if f.is_file():
			f.unlink()

	shutil.copy2(SOURCE_DIR / "system.md", TARGET_DIR / "INSTRUCTIONS.md")

	instructions = (SOURCE_DIR / "instructions.md").read_text()
	skill_entries = []

	for manifest_file in sorted(SKILLS_DIR.rglob("skill.json")):
		skill_dir = manifest_file.parent
		manifest = load_manifest(skill_dir)
		name = manifest.get("name") or skill_dir.name
		skill_file = DIST_SKILLS_DIR / name / "SKILL.md"
		if not skill_file.exists():
			continue

		targets = manifest.get("targets")
		if targets is not None and "chatgpt" not in targets:
			continue

		shutil.copy2(skill_file, TARGET_DIR / f"{name}.md")
		skill_entries.append(build_skill_entry(manifest, name))

	skills_md = instructions.rstrip() + "\n\n" + "\n\n".join(skill_entries) + "\n"
	(TARGET_DIR / "SKILLS.md").write_text(skills_md)


if __name__ == "__main__":
	main()
