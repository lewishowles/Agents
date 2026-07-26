#!/usr/bin/env python3
# Generates the inline Codex hook TOML fragment from the canonical JSON source.

from __future__ import annotations

import json
import sys
from pathlib import Path


# Format a scalar as a TOML-compatible basic value.
#
# @param  {object}  value
#     The scalar value to format.
def format_value(value: object) -> str:
	return json.dumps(value, ensure_ascii=False)


# Write the TOML array tables for one Codex hook matcher group.
#
# @param  {TextIO}  output
#     The generated TOML file.
# @param  {str}  event
#     The Codex hook event name.
# @param  {dict}  hook_group
#     One matcher group from the canonical hook configuration.
def write_hook_group(output, event: str, hook_group: dict) -> None:
	print(f"[[hooks.{event}]]", file=output)

	for key, value in hook_group.items():
		if key != "hooks":
			print(f"{key} = {format_value(value)}", file=output)

	for hook in hook_group["hooks"]:
		print(f"\n[[hooks.{event}.hooks]]", file=output)
		for key, value in hook.items():
			print(f"{key} = {format_value(value)}", file=output)

	print(file=output)


# Generate the inline TOML fragment used by global Codex setup.
#
# @param  {Path}  source_path
#     Canonical JSON hook configuration.
# @param  {Path}  output_path
#     Generated inline TOML fragment.
def build_hooks(source_path: Path, output_path: Path) -> None:
	source = json.loads(source_path.read_text())

	with output_path.open("w") as output:
		for event, hook_groups in source["hooks"].items():
			for hook_group in hook_groups:
				write_hook_group(output, event, hook_group)


def main() -> None:
	if len(sys.argv) != 3:
		raise SystemExit("usage: build-codex-hooks.py <source.json> <output.toml>")

	build_hooks(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
	main()
