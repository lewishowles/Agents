#!/usr/bin/env python3
# Generate SKILL.md for each skill and the global-skills index for Claude.
#
# Sources per skill:
#   skill.json    — metadata (name, description, dependencies, capabilities)
#   SKILL.body.md — instructional content (the part Claude actually reads)
#
# Output per skill:
#   SKILL.md      — generated frontmatter from skill.json + body from SKILL.body.md
#
# Bootstrap: if SKILL.body.md is missing, the body is extracted from the existing
# SKILL.md (stripping its frontmatter) to create it, then SKILL.md is regenerated.
#
# Skill discovery supports two layouts:
#   skills/<name>/           — flat skill
#   skills/<group>/<name>/   — grouped skill (e.g. skills/vue/vue-pinia/)

import json
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_DIR / "skills"
GLOBAL_SKILLS_OUT = REPO_DIR / "dist" / "claude" / "source" / "global-skills.md"

PM_GROUP = "project-management"  # Listed first in the global index so it appears near slash-command docs.

GENERATED_HEADER = "# Generated — edit skill.json and SKILL.body.md instead."

GLOBAL_SKILLS_HEADER = """\
## Global skills

Apply across all projects. See individual skills for detailed rules. Per-project `.claude/settings.json` can disable skills via `skillOverrides` — useful if a skill's tech (Vue, Swift) isn't used in that project.
"""


# Return all skill directories, sorted alphabetically at each level.
# Handles both flat (skills/<name>/) and grouped (skills/<group>/<name>/) layouts.
def discover_skill_dirs() -> list[Path]:
	dirs = []
	for d in sorted(SKILLS_DIR.iterdir()):
		if not d.is_dir():
			continue
		if (d / "skill.json").exists():
			dirs.append(d)
		else:
			for sub in sorted(d.iterdir()):
				if sub.is_dir() and (sub / "skill.json").exists():
					dirs.append(sub)
	return dirs


# Return the content of a SKILL.md after stripping its YAML frontmatter.
# @param  Path  skill_file  Path to the SKILL.md to extract body from.
def extract_body(skill_file: Path) -> str:
	lines = skill_file.read_text().splitlines()
	dash_indices = [i for i, line in enumerate(lines) if line.strip() == "---"]
	if len(dash_indices) < 2:
		return skill_file.read_text()
	body_start = dash_indices[1] + 1
	while body_start < len(lines) and not lines[body_start].strip():
		body_start += 1
	return "\n".join(lines[body_start:]) + "\n"


# Write SKILL.md by combining skill.json metadata with SKILL.body.md.
# If SKILL.body.md does not exist, the body is bootstrapped from the existing
# SKILL.md so the first sync run on an existing skill is non-destructive.
# @param  Path  skill_dir  The skill directory to generate SKILL.md for.
def generate_skill_md(skill_dir: Path) -> None:
	manifest_file = skill_dir / "skill.json"
	body_file = skill_dir / "SKILL.body.md"
	output_file = skill_dir / "SKILL.md"

	manifest = json.loads(manifest_file.read_text())

	if not body_file.exists():
		body_file.write_text(extract_body(output_file) if output_file.exists() else "")

	body = body_file.read_text()

	parts = [
		"---",
		GENERATED_HEADER,
		f"name: {manifest['name']}",
	]

	display_name = manifest.get("title")
	if display_name:
		parts.append(f"displayName: {display_name}")

	parts.extend([
		"description: >",
		f"  {manifest.get('description', '')}",
	])

	do_not_use = manifest.get("do-not-use-when", [])
	if do_not_use:
		parts.append("do-not-use-when:")
		parts.extend(f"  - {item}" for item in do_not_use)

	deps = manifest.get("dependencies", [])
	if deps:
		parts.append("related-skills:")
		parts.extend(f"  - {dep}" for dep in deps)

	parts.append("---")
	parts.append("")

	output_file.write_text("\n".join(parts) + body)


# Write the global-skills index consumed by Claude's CLAUDE.md.
# Project-management skills are listed before all others so they appear
# near the slash-command section of the generated CLAUDE.md.
# Skills without a 'when' field are omitted — they have no trigger description.
def generate_global_skills_md() -> None:
	pm_skills = []
	other_skills = []

	for skill_dir in discover_skill_dirs():
		manifest = json.loads((skill_dir / "skill.json").read_text())
		name = manifest.get("name", skill_dir.name)
		when = manifest.get("when", "")
		if not when:
			continue
		if skill_dir.parent.name == PM_GROUP:
			pm_skills.append((name, when))
		else:
			other_skills.append((name, when))

	pm_skills.sort(key=lambda x: x[0])
	other_skills.sort(key=lambda x: x[0])

	lines = [GLOBAL_SKILLS_HEADER, "\n"]
	for name, when in pm_skills + other_skills:
		lines.append(f"- `/{name}` — {when}\n")

	GLOBAL_SKILLS_OUT.parent.mkdir(parents=True, exist_ok=True)
	GLOBAL_SKILLS_OUT.write_text("".join(lines))


def main() -> None:
	skill_dirs = discover_skill_dirs()
	for skill_dir in skill_dirs:
		generate_skill_md(skill_dir)
	print(f"Generated {len(skill_dirs)} SKILL.md files.")

	generate_global_skills_md()
	print("Generated dist/claude/source/global-skills.md.")


if __name__ == "__main__":
	main()
