#!/usr/bin/env python3
"""Generate ChatGPT target files from skill frontmatter.

Reads skills/*/SKILL.md, extracts frontmatter, and writes:
  targets/chatgpt/SKILLS.md       — index assembled from source/instructions.md + skill entries
  targets/chatgpt/<name>.md       — verbatim copy of each SKILL.md
"""

import re
import shutil
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_DIR / "skills"
TARGET_DIR = REPO_DIR / "targets" / "chatgpt"
SOURCE_DIR = TARGET_DIR / "source"


def parse_frontmatter(text):
	"""Extract name, description, related-skills, and do-not-use-when from SKILL.md frontmatter."""
	lines = text.split("\n")
	if not lines or lines[0].strip() != "---":
		return {}

	try:
		end = next(i for i, line in enumerate(lines[1:], 1) if line.strip() == "---")
	except StopIteration:
		return {}

	fm = "\n".join(lines[1:end])
	result = {}

	m = re.search(r"^name:\s*(.+)$", fm, re.MULTILINE)
	if m:
		result["name"] = m.group(1).strip()

	# Folded scalar (>) — join continuation lines with spaces
	m = re.search(r"^description:\s*>\s*\n((?:[ \t]+\S.*\n?)+)", fm, re.MULTILINE)
	if m:
		desc_lines = [line.strip() for line in m.group(1).splitlines() if line.strip()]
		result["description"] = " ".join(desc_lines)
	else:
		m = re.search(r"^description:\s*(.+)$", fm, re.MULTILINE)
		if m:
			result["description"] = m.group(1).strip()

	m = re.search(r"^related-skills:\s*\n((?:[ \t]+-[ \t]+\S.*\n?)+)", fm, re.MULTILINE)
	if m:
		result["related-skills"] = [
			re.sub(r"^[ \t]+-[ \t]+", "", line)
			for line in m.group(1).splitlines()
			if line.strip().startswith("-")
		]

	m = re.search(r"^do-not-use-when:\s*\n((?:[ \t]+-[ \t]+.*\n?)+)", fm, re.MULTILINE)
	if m:
		result["do-not-use-when"] = [
			re.sub(r"^[ \t]+-[ \t]+", "", line)
			for line in m.group(1).splitlines()
			if line.strip().startswith("-")
		]

	return result


def build_skill_entry(fm, skill_name):
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

	for skill_dir in sorted(d for d in SKILLS_DIR.iterdir() if d.is_dir()):
		skill_file = skill_dir / "SKILL.md"
		if not skill_file.exists():
			continue

		content = skill_file.read_text()
		fm = parse_frontmatter(content)
		name = fm.get("name") or skill_dir.name

		shutil.copy2(skill_file, TARGET_DIR / f"{name}.md")
		skill_entries.append(build_skill_entry(fm, name))

	skills_md = instructions.rstrip() + "\n\n" + "\n\n".join(skill_entries) + "\n"
	(TARGET_DIR / "SKILLS.md").write_text(skills_md)


if __name__ == "__main__":
	main()
