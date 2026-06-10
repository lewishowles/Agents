#!/usr/bin/env python3
"""Generate dist/claude/settings.json from adapters/claude/settings.base.json + hook.json manifests.

The base file holds env, permissions, skillOverrides, and the inline .env read-guard
(a bare jq command that cannot be expressed as a named hook script). Everything else
in the hooks block is derived from hooks/claude/*/hook.json.

Hooks with no .sh extension (e.g. cbm-code-discovery-gate) use a top-level "command"
field in their hook.json to override the default bash-wrapper command.
"""

import json
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent
BASE_FILE = REPO_DIR / "adapters" / "claude" / "settings.base.json"
HOOKS_DIR = REPO_DIR / "hooks" / "claude"
OUT_FILE = REPO_DIR / "dist" / "claude" / "settings.json"


def hook_command(manifest: dict) -> str:
    if "command" in manifest:
        return manifest["command"]
    name = manifest["name"]
    return f'bash -c \'bash "$HOME/.claude/hooks/{name}.sh"\''


def build_hook_entry(hook_def: dict, command: str) -> dict:
    entry: dict = {"type": "command", "command": command}
    if "timeout" in hook_def:
        entry["timeout"] = hook_def["timeout"]
    if "statusMessage" in hook_def:
        entry["statusMessage"] = hook_def["statusMessage"]
    return entry


def main() -> None:
    base = json.loads(BASE_FILE.read_text())
    hooks_block: dict = base.setdefault("hooks", {})

    # Group by (event, matcher) → list of (name, command, hook_def) sorted by name.
    groups: dict[tuple, list] = {}

    for hook_dir in sorted(HOOKS_DIR.iterdir()):
        manifest_file = hook_dir / "hook.json"
        if not manifest_file.exists():
            continue
        manifest = json.loads(manifest_file.read_text())
        command = hook_command(manifest)

        for ev in manifest.get("events", []):
            key = (ev["event"], ev.get("matcher"))
            groups.setdefault(key, []).append((manifest["name"], command, ev))

    for entries in groups.values():
        entries.sort(key=lambda x: x[0])

    for (event, matcher), entries in sorted(groups.items(), key=lambda kv: (kv[0][0], kv[0][1] or "")):
        hook_entries = [build_hook_entry(ev, cmd) for _, cmd, ev in entries]
        event_list: list = hooks_block.setdefault(event, [])
        if matcher:
            event_list.append({"matcher": matcher, "hooks": hook_entries})
        else:
            event_list.append({"hooks": hook_entries})

    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text(json.dumps(base, indent=2) + "\n")
    print(f"Generated {OUT_FILE.relative_to(REPO_DIR)}")


if __name__ == "__main__":
    main()
