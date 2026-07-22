#!/usr/bin/env python3
# Generate the ChatGPT target instructions file.
#
# Writes dist/chatgpt/INSTRUCTIONS.md, copied from src/fragments/chatgpt/system.md.
#
# Skill content is no longer duplicated into dist/chatgpt/ — the local-repo-gateway
# server exposes skills live (list_skills, read_skill), so the custom GPT's
# instructions tell it to call those instead of reading uploaded knowledge files.

import shutil
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent.parent
TARGET_DIR = REPO_DIR / "dist" / "chatgpt"
SOURCE_DIR = REPO_DIR / "src" / "fragments" / "chatgpt"


def main() -> None:
	TARGET_DIR.mkdir(parents=True, exist_ok=True)

	# Clear previously generated files so a prior run's SKILLS.md and
	# per-skill copies don't linger after this rework.
	for f in TARGET_DIR.iterdir():
		if f.is_file():
			f.unlink()

	shutil.copy2(SOURCE_DIR / "system.md", TARGET_DIR / "INSTRUCTIONS.md")


if __name__ == "__main__":
	main()
