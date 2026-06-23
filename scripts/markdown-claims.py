#!/usr/bin/env python3
# Check that file paths claimed in agent-facing markdown actually exist on disk.
#
# Modes:
#   paths    — relative markdown links and inline code paths in agent instruction files
#   commands — inline `scripts/` references across all markdown, verifying executability

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Scan directories for each mode.
PATH_SCAN_DIRS = [
	"rules",
	"dist/claude/source",
	"dist/codex/source",
	"docs",
]

COMMAND_EXTRA_DIRS = [
	"skills",
]

# Inline code prefixes that are clearly repo-root-relative in this repo.
# Deliberately excludes bare "dist/" (too generic; vue-vite skill uses it for
# user project output).
REPO_PATH_PREFIXES = (
	"scripts/",
	"rules/",
	"dist/claude/",
	"dist/codex/",
	"dist/chatgpt/",
	"docs/",
	"templates/",
	"hooks/",
	"adapters/",
	"tests/",
)

RE_MD_LINK = re.compile(r'\[(?:[^\]]*)\]\(([^)#\s][^)]*)\)')
RE_INLINE_CODE = re.compile(r'(?<!`)`([^`\n]+)`(?!`)')
RE_CODE_FENCE = re.compile(r'```.*?```', re.DOTALL)


def collect_files(dirs: list[str]) -> list[Path]:
	files = []
	for d in dirs:
		path = REPO_ROOT / d
		if path.exists():
			files.extend(sorted(path.rglob("*.md")))
	return files


def strip_fences(text: str) -> str:
	return RE_CODE_FENCE.sub("", text)


# Returns (claim_text, resolved_path) pairs for relative markdown links.
#
# @param  {str}   text
#     Markdown source with fences already stripped.
# @param  {Path}  source_file
#     Absolute path of the file being scanned; used to resolve relative targets.
def extract_link_claims(text: str, source_file: Path) -> list[tuple[str, Path]]:
	claims = []
	for m in RE_MD_LINK.finditer(text):
		target = m.group(1).strip()
		if target.startswith(("http://", "https://", "#", "mailto:", "/")):
			continue
		resolved = (source_file.parent / target).resolve()
		claims.append((target, resolved))
	return claims


# Returns (claim_text, resolved_path) pairs for inline code matching prefixes.
# Paths are resolved from the repo root. Trailing arguments are stripped so
# `scripts/foo.sh --flag` resolves to scripts/foo.sh.
#
# @param  {str}            text
#     Markdown source with fences already stripped.
# @param  {tuple[str]}     prefixes
#     Only inline code starting with one of these prefixes is included.
def extract_code_claims(
	text: str,
	prefixes: tuple[str, ...],
) -> list[tuple[str, Path]]:
	claims = []
	for m in RE_INLINE_CODE.finditer(text):
		code = m.group(1).strip()
		if not code.startswith(prefixes):
			continue
		# Strip trailing arguments (e.g. `scripts/setup.sh --flag`)
		path_part = code.split()[0].rstrip("/")
		if "<" in path_part:
			continue
		resolved = REPO_ROOT / path_part
		claims.append((path_part, resolved))
	return claims


def check_paths() -> int:
	files = collect_files(PATH_SCAN_DIRS)
	failures = 0

	for md_file in files:
		text = strip_fences(md_file.read_text(encoding="utf-8"))
		rel = md_file.relative_to(REPO_ROOT)

		link_claims = extract_link_claims(text, md_file)
		code_claims = extract_code_claims(text, REPO_PATH_PREFIXES)

		for claim, resolved in link_claims + code_claims:
			if not resolved.exists():
				print(f"  {rel}: missing path '{claim}'")
				failures += 1

	return failures


def check_commands() -> int:
	dirs = PATH_SCAN_DIRS + COMMAND_EXTRA_DIRS
	files = collect_files(dirs)
	failures = 0

	for md_file in files:
		text = strip_fences(md_file.read_text(encoding="utf-8"))
		rel = md_file.relative_to(REPO_ROOT)

		for claim, resolved in extract_code_claims(text, ("scripts/",)):
			if not resolved.exists():
				print(f"  {rel}: missing script '{claim}'")
				failures += 1
			elif not resolved.stat().st_mode & 0o111:
				print(f"  {rel}: script not executable '{claim}'")
				failures += 1

	return failures


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument(
		"--mode",
		choices=["paths", "commands", "all"],
		default="all",
		help="Which claims to check (default: all)",
	)
	args = parser.parse_args()

	failures = 0

	if args.mode in ("paths", "all"):
		failures += check_paths()

	if args.mode in ("commands", "all"):
		failures += check_commands()

	if failures:
		print(f"\n  {failures} issue(s) found")
		sys.exit(1)


if __name__ == "__main__":
	main()
