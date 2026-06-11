#!/usr/bin/env python3
# Generate manifest-backed tables in docs so skill and hook lists do not drift.

import json
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_DIR / "skills"
HOOKS_DIR = REPO_DIR / "hooks" / "claude"


# Return all skill manifests in display order.
def skill_manifests() -> list[dict]:
	manifests = []
	for skill_dir in sorted(SKILLS_DIR.iterdir()):
		if not skill_dir.is_dir():
			continue
		if (skill_dir / "skill.json").exists():
			manifests.append(json.loads((skill_dir / "skill.json").read_text()))
		else:
			for sub in sorted(skill_dir.iterdir()):
				if sub.is_dir() and (sub / "skill.json").exists():
					manifests.append(json.loads((sub / "skill.json").read_text()))
	return sorted(manifests, key=lambda item: item["name"])


# Return all Claude hook manifests in display order.
def hook_manifests() -> list[dict]:
	manifests = []
	for hook_file in sorted(HOOKS_DIR.glob("*/hook.json")):
		manifests.append(json.loads(hook_file.read_text()))
	return sorted(manifests, key=lambda item: item["name"])


# Replace generated block content between named markers.
# @param  Path  path   Markdown file path.
# @param  str   name   Marker name, e.g. user-skills.
# @param  str   body   New block content without surrounding markers.
def replace_block(path: Path, name: str, body: str) -> None:
	start = f"<!-- BEGIN GENERATED: {name} -->"
	end = f"<!-- END GENERATED: {name} -->"
	text = path.read_text()
	before, marker, rest = text.partition(start)
	if not marker:
		raise ValueError(f"Missing start marker {start} in {path}")
	_, marker, after = rest.partition(end)
	if not marker:
		raise ValueError(f"Missing end marker {end} in {path}")
	path.write_text(f"{before}{start}\n{body.rstrip()}\n{end}{after}")


# Keep table cells on one line.
# @param  str  value  Cell text.
def cell(value: str) -> str:
	return value.replace("\n", " ").replace("|", "\\|")


# Render a comma-separated list as inline code values.
# @param  list  values  Values to render.
def code_list(values: list[str]) -> str:
	if not values:
		return ""
	return ", ".join(f"`{value}`" for value in values)


def build_user_skills_table() -> str:
	lines = [
		"| Skill | When to use | Auto-trigger keywords |",
		"| ----- | ----------- | --------------------- |",
	]
	for manifest in skill_manifests():
		name = manifest["name"]
		when = manifest.get("when") or manifest.get("description", "")
		triggers = manifest.get("triggers", [])
		if manifest.get("capabilities", {}).get("promptTriggering") is False:
			trigger_text = "(manual only)"
		else:
			trigger_text = code_list(triggers)
		lines.append(f"| `{name}` | {cell(when)} | {cell(trigger_text)} |")
	return "\n".join(lines)


def build_skill_commands_table() -> str:
	lines = [
		"| Command | Skill | When to use it manually |",
		"| ------- | ----- | ----------------------- |",
	]
	for manifest in skill_manifests():
		name = manifest["name"]
		when = manifest.get("when") or manifest.get("description", "")
		lines.append(f"| `/{name}` | `{name}` | {cell(when)} |")
	return "\n".join(lines)


def build_registered_hooks_table() -> str:
	lines = [
		"| Hook | Event | Behaviour on failure |",
		"| ---- | ----- | -------------------- |",
	]
	for manifest in hook_manifests():
		name = manifest["name"]
		events = []
		for event in manifest.get("events", []):
			label = event["event"]
			if event.get("matcher"):
				label += f" (`{event['matcher']}`)"
			events.append(label)
		failure = manifest.get("failureMode", "")
		dependencies = manifest.get("dependencies", [])
		dependency_text = f"; requires {', '.join(dependencies)}" if dependencies else ""
		lines.append(f"| `{name}` | {cell(', '.join(events))} | `{failure}`{dependency_text} |")
	return "\n".join(lines)


def build_file_trigger_table() -> str:
	lines = [
		"| Pattern | Skills injected |",
		"| ------- | --------------- |",
	]
	for manifest in skill_manifests():
		if not manifest.get("capabilities", {}).get("fileTriggering"):
			continue
		patterns = manifest.get("filePatterns", []) + manifest.get("pathPatterns", [])
		if not patterns:
			continue
		name = manifest["name"]
		skills = [name] + manifest.get("dependencies", [])
		lines.append(f"| {cell(code_list(patterns))} | {cell(code_list(skills))} |")
	return "\n".join(lines)


def main() -> None:
	replace_block(REPO_DIR / "docs" / "skills.md", "user-skills", build_user_skills_table())
	replace_block(REPO_DIR / "docs" / "commands.md", "skill-commands", build_skill_commands_table())
	replace_block(REPO_DIR / "docs" / "hooks.md", "registered-hooks", build_registered_hooks_table())
	replace_block(REPO_DIR / "docs" / "hooks.md", "file-trigger-mapping", build_file_trigger_table())
	print("Generated manifest-backed docs tables.")


if __name__ == "__main__":
	main()
