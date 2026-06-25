#!/usr/bin/env python3
"""Shared Local Repo Gateway tool logic."""

import json
import subprocess
from pathlib import Path

VERSION = "0.1.0"

# Output bounds keep responses usable without flooding context.
MAX_FILE_BYTES = 50_000
MAX_TREE_ENTRIES = 200
MAX_SEARCH_MATCHES = 100
MAX_GIT_LINES = 200

IGNORED_NAMES = {
	".git", "node_modules", "dist", "build", "__pycache__", ".venv", "venv",
	"coverage", ".cache", ".mypy_cache", ".pytest_cache", ".ruff_cache",
	".tox", ".eggs", "*.egg-info",
}

IGNORED_SUFFIXES = {".pem", ".key", ".p12", ".pfx", ".crt", ".cer"}

SECRET_NAMES = {"credentials", "secrets", ".env", ".envrc"}


def _load_config() -> dict:
	config_path = Path(__file__).parent / "repos.json"
	if not config_path.exists():
		example = Path(__file__).parent / "repos.example.json"
		raise FileNotFoundError(
			f"repos.json not found. Copy {example} to repos.json and edit it."
		)
	return json.loads(config_path.read_text())


def _get_repo(repo_id: str, repos: list[dict]) -> dict:
	for repo in repos:
		if repo["id"] == repo_id:
			return repo

	ids = [repo["id"] for repo in repos]
	raise ValueError(f"Unknown repo_id {repo_id!r}. Configured: {ids}")


def _safe_path(repo_root: Path, relative: str) -> Path:
	"""Resolve relative path and reject traversal attempts."""
	resolved = (repo_root / relative).resolve()
	if not str(resolved).startswith(str(repo_root.resolve())):
		raise ValueError(f"Path {relative!r} escapes repo root.")
	return resolved


def _is_ignored(path: Path) -> bool:
	for part in path.parts:
		if part in IGNORED_NAMES or part.lower() in SECRET_NAMES:
			return True
	if path.suffix in IGNORED_SUFFIXES:
		return True
	return False


def _tree_entries(root: Path, prefix: str = "", entries: list | None = None) -> list[str]:
	if entries is None:
		entries = []

	try:
		children = sorted(root.iterdir(), key=lambda path: (path.is_file(), path.name))
	except PermissionError:
		return entries

	for child in children:
		if len(entries) >= MAX_TREE_ENTRIES:
			entries.append(f"... (truncated at {MAX_TREE_ENTRIES} entries)")
			return entries
		if _is_ignored(child):
			continue

		label = child.name + ("/" if child.is_dir() else "")
		entries.append(f"{prefix}{label}")
		if child.is_dir():
			_tree_entries(child, prefix + "  ", entries)

	return entries


def tool_health(repos: list[dict], arguments: dict) -> str:
	return json.dumps({
		"version": VERSION,
		"mode": "read-only",
		"repo_count": len(repos),
		"operations": ["read", "git_status", "git_diff"],
	}, indent=2)


def tool_list(repos: list[dict], arguments: dict) -> str:
	summary = [
		{"id": repo["id"], "name": repo["name"], "description": repo.get("description", "")}
		for repo in repos
	]
	return json.dumps(summary, indent=2)


def tool_get_instructions(repo: dict, arguments: dict) -> str:
	root = Path(repo["path"]).resolve()
	parts = []

	for filename in ("AGENTS.md", "AGENT_CAPABILITIES.md", "PROGRESS.md"):
		path = root / filename
		if not path.exists():
			continue

		content = path.read_text(encoding="utf-8", errors="replace")
		if filename == "PROGRESS.md":
			# Return only the handoff section to keep tokens manageable.
			handoff_marker = "## Session handoff"
			stop_marker = "## Upcoming work"
			start = content.find(handoff_marker)
			stop = content.find(stop_marker)
			if start != -1:
				content = content[start:stop if stop != -1 else start + 3000]

		parts.append(f"### {filename}\n\n{content.strip()}")

	return "\n\n---\n\n".join(parts) if parts else "No instruction files found."


def tool_tree(repo: dict, arguments: dict) -> str:
	root = Path(repo["path"]).resolve()
	relative = arguments.get("path", "")
	target = _safe_path(root, relative) if relative else root
	if not target.exists():
		return f"Path not found: {relative!r}"

	entries = _tree_entries(target)
	header = f"{relative or '.'} ({len(entries)} entries)"
	return header + "\n" + "\n".join(entries)


def tool_search(repo: dict, arguments: dict) -> str:
	root = Path(repo["path"]).resolve()
	pattern = arguments["pattern"]
	relative = arguments.get("path", "")
	search_root = _safe_path(root, relative) if relative else root
	command = [
		"rg", "--max-count", "1", "--line-number", "--no-heading",
		"--max-filesize", "1M", "-m", str(MAX_SEARCH_MATCHES),
		pattern, str(search_root),
	]
	result = subprocess.run(command, capture_output=True, text=True, cwd=root)
	lines = result.stdout.splitlines()[:MAX_SEARCH_MATCHES]
	rel_lines = [line.replace(str(root) + "/", "") for line in lines]
	return "\n".join(rel_lines) if rel_lines else "No matches found."


def tool_read_file(repo: dict, arguments: dict) -> str:
	root = Path(repo["path"]).resolve()
	relative = arguments["path"]
	target = _safe_path(root, relative)
	if not target.exists():
		return f"File not found: {relative!r}"
	if _is_ignored(target):
		return f"Path {relative!r} is excluded."

	raw = target.read_bytes()
	try:
		content = raw[:MAX_FILE_BYTES].decode("utf-8")
	except UnicodeDecodeError:
		return f"File {relative!r} is not valid UTF-8 (binary file)."

	truncated = len(raw) > MAX_FILE_BYTES
	if truncated:
		content += f"\n\n... (truncated — file is {len(raw)} bytes, limit {MAX_FILE_BYTES})"

	return content


def tool_git_status(repo: dict, arguments: dict) -> str:
	root = Path(repo["path"]).resolve()
	result = subprocess.run(
		["git", "status", "--short", "--branch"],
		capture_output=True, text=True, cwd=root,
	)
	return result.stdout.strip() or "Working tree clean."


SKILLS_DIR = Path(__file__).resolve().parent.parent.parent / "skills"
DIST_SKILLS_DIR = Path(__file__).resolve().parent.parent.parent / "dist" / "skills"


def tool_list_skills(arguments: dict) -> str:
	if not SKILLS_DIR.exists():
		return "No skills/ directory found."

	skills = []
	for skill_json in sorted(SKILLS_DIR.rglob("skill.json")):
		try:
			data = json.loads(skill_json.read_text(encoding="utf-8"))
		except Exception:
			continue
		slug = skill_json.parent.name
		skills.append({
			"slug": slug,
			"title": data.get("title") or data.get("name", slug),
			"description": data.get("description", ""),
			"triggers": data.get("triggers", []),
			"filePatterns": data.get("filePatterns", []),
		})

	if not skills:
		return "No skills found."

	return json.dumps(skills, indent=2)


def tool_read_skill(arguments: dict) -> str:
	slug = arguments.get("slug", "")
	if not slug:
		return "slug is required."

	skill_file = DIST_SKILLS_DIR / slug / "SKILL.md"
	if not skill_file.exists():
		return f"Skill {slug!r} not found."

	raw = skill_file.read_bytes()
	try:
		return raw[:MAX_FILE_BYTES].decode("utf-8")
	except UnicodeDecodeError:
		return f"Skill {slug!r} is not valid UTF-8."


def tool_git_diff(repo: dict, arguments: dict) -> str:
	root = Path(repo["path"]).resolve()
	relative = arguments.get("path")
	command = ["git", "diff", "HEAD"]
	if relative:
		_safe_path(root, relative)
		command.append("--")
		command.append(relative)

	result = subprocess.run(command, capture_output=True, text=True, cwd=root)
	lines = result.stdout.splitlines()[:MAX_GIT_LINES]
	output = "\n".join(lines)
	if len(result.stdout.splitlines()) > MAX_GIT_LINES:
		output += f"\n... (truncated at {MAX_GIT_LINES} lines)"

	return output or "No uncommitted changes."
