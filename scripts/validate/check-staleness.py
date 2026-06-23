#!/usr/bin/env python3
# Flag skills and rules files unchanged for too long.
# Warns when a file has not been committed in N days or N repo commits.
# Always exits 0 — staleness is a warning signal, not a hard failure.

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent

DEFAULT_DAYS = 90
DEFAULT_COMMITS = 100

SCAN_GLOBS = [
	("rules", "*.md"),
	("skills", "**/SKILL.body.md"),
]


def collect_files() -> list[Path]:
	files = []
	for directory, pattern in SCAN_GLOBS:
		d = REPO_ROOT / directory
		if d.exists():
			files.extend(sorted(d.glob(pattern)))
	return files


# Returns (last_commit_hash, commit_timestamp) for a file, or None if untracked.
#
# @param  {Path}  path
#     Absolute path of the file to query.
def last_commit(path: Path) -> tuple[str, int] | None:
	result = subprocess.run(
		["git", "log", "-1", "--format=%H %ct", "--", str(path)],
		capture_output=True,
		text=True,
		cwd=REPO_ROOT,
	)
	line = result.stdout.strip()
	if not line:
		return None
	parts = line.split()
	return parts[0], int(parts[1])


# Returns the number of repo commits made after the given commit hash.
#
# @param  {str}  commit_hash
#     The commit to measure from.
def commits_since(commit_hash: str) -> int:
	result = subprocess.run(
		["git", "rev-list", "--count", f"{commit_hash}..HEAD"],
		capture_output=True,
		text=True,
		cwd=REPO_ROOT,
	)
	try:
		return int(result.stdout.strip())
	except ValueError:
		return 0


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--days", type=int, default=DEFAULT_DAYS)
	parser.add_argument("--commits", type=int, default=DEFAULT_COMMITS)
	args = parser.parse_args()

	now = int(time.time())
	files = collect_files()
	warnings = 0

	for path in files:
		info = last_commit(path)
		if info is None:
			continue

		commit_hash, timestamp = info
		age_days = (now - timestamp) // 86400
		age_commits = commits_since(commit_hash)
		rel = path.relative_to(REPO_ROOT)

		if age_days >= args.days:
			print(f"  {rel}: unchanged for {age_days} days (last commit {age_commits} commits ago)")
			warnings += 1
		elif age_commits >= args.commits:
			print(f"  {rel}: unchanged for {age_commits} commits ({age_days} days)")
			warnings += 1

	if warnings:
		print(f"\n  {warnings} stale file(s) — review for drift against current runtime behaviour")


if __name__ == "__main__":
	main()
