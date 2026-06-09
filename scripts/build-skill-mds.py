#!/usr/bin/env python3
"""Generate SKILL.md for each skill from skill.json + SKILL.body.md.

Bootstrap: if SKILL.body.md is missing, extracts the body from the existing
SKILL.md (stripping frontmatter) to create it, then regenerates SKILL.md.

On every subsequent run: reads skill.json and SKILL.body.md, regenerates SKILL.md.

Discovers skills at two depths:
  skills/<name>/           — flat skills
  skills/<group>/<name>/   — grouped skills
"""

import json
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_DIR / "skills"

GENERATED_HEADER = "# Generated — edit skill.json and SKILL.body.md instead."


def discover_skill_dirs():
    for d in sorted(SKILLS_DIR.iterdir()):
        if not d.is_dir():
            continue
        if (d / "skill.json").exists():
            yield d
        else:
            for sub in sorted(d.iterdir()):
                if sub.is_dir() and (sub / "skill.json").exists():
                    yield sub


def extract_body(skill_file: Path) -> str:
    lines = skill_file.read_text().splitlines()
    dash_indices = [i for i, line in enumerate(lines) if line.strip() == "---"]
    if len(dash_indices) < 2:
        return skill_file.read_text()
    body_start = dash_indices[1] + 1
    while body_start < len(lines) and not lines[body_start].strip():
        body_start += 1
    return "\n".join(lines[body_start:]) + "\n"


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
        "description: >",
        f"  {manifest.get('description', '')}",
    ]

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


def main():
    count = 0
    for skill_dir in discover_skill_dirs():
        generate_skill_md(skill_dir)
        count += 1
    print(f"Generated {count} SKILL.md files.")


if __name__ == "__main__":
    main()
