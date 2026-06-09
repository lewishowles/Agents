#!/usr/bin/env python3
"""Generate ChatGPT target files from skill frontmatter.

Reads skills/*/SKILL.md, extracts frontmatter, and writes:
  dist/chatgpt/SKILLS.md       — index assembled from source/instructions.md + skill entries
  dist/chatgpt/<name>.md       — verbatim copy of each SKILL.md
"""

import json
import shutil
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_DIR / "skills"
TARGET_DIR = REPO_DIR / "dist" / "chatgpt"
SOURCE_DIR = TARGET_DIR / "source"


def load_manifest(skill_dir: Path) -> dict:
	"""Read skill.json and normalise to the shape build_skill_entry expects."""
	manifest_file = skill_dir / "skill.json"
	if not manifest_file.exists():
		return {}
	data = json.loads(manifest_file.read_text())
	return {
		"name": data.get("name", skill_dir.name),
		"description": data.get("description", ""),
		"do-not-use-when": data.get("do-not-use-when", []),
		"related-skills": data.get("dependencies", []),
	}


def build_skill_entry(fm: dict, skill_name: str) -> str:
	"""Build a SKILLS.md section for a single skill."""
	lines = [f"### {skill_name}"]

	description = fm.get("description", "")
	if description:
		lines.append(f"**When to use:** {description}")

	avoid = fm.get("do-not-use-when", [])
	if avoid:
		lines.append(f"**Avoid:** {'; '.join(avoid)}")

	related = fm.get("related-skills", [])
	if related:
		lines.append(f"**Combine with:** {', '.join(related)}")

	return "\n".join(lines)


def main():
	TARGET_DIR.mkdir(parents=True, exist_ok=True)

	shutil.copy2(SOURCE_DIR / "system.md", TARGET_DIR / "INSTRUCTIONS.md")

	instructions = (SOURCE_DIR / "instructions.md").read_text()
	skill_entries = []

	# Discover flat skills (skills/<name>/SKILL.md) and grouped skills
	# (skills/<group>/<name>/SKILL.md) at one level of nesting.
	skill_dirs = []
	for d in sorted(SKILLS_DIR.iterdir()):
		if not d.is_dir():
			continue
		if (d / "SKILL.md").exists():
			skill_dirs.append(d)
		else:
			for sub in sorted(d.iterdir()):
				if sub.is_dir() and (sub / "SKILL.md").exists():
					skill_dirs.append(sub)

	for skill_dir in skill_dirs:
		skill_file = skill_dir / "SKILL.md"
		if not skill_file.exists():
			continue

		fm = load_manifest(skill_dir)
		name = fm.get("name") or skill_dir.name

		shutil.copy2(skill_file, TARGET_DIR / f"{name}.md")
		skill_entries.append(build_skill_entry(fm, name))

	skills_md = instructions.rstrip() + "\n\n" + "\n\n".join(skill_entries) + "\n"
	(TARGET_DIR / "SKILLS.md").write_text(skills_md)


if __name__ == "__main__":
	main()
