#!/usr/bin/env python3
"""Local Repo Gateway MCP server — read-only access to allowlisted local repositories."""

import asyncio
import json
import subprocess
from pathlib import Path

from mcp.server import Server
from mcp.server.stdio import stdio_server
import mcp.types as types

VERSION = "0.1.0"

# Output bounds — keep responses usable without flooding the context.
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
    for r in repos:
        if r["id"] == repo_id:
            return r
    ids = [r["id"] for r in repos]
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
        children = sorted(root.iterdir(), key=lambda p: (p.is_file(), p.name))
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


server = Server("local-repo-gateway")
_config = _load_config()
_repos = _config["repos"]


@server.list_tools()
async def list_tools() -> list[types.Tool]:
    return [
        types.Tool(
            name="local_repo_health",
            description="Server version, repo count, mode, and available operations.",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="local_repo_list",
            description="List allowlisted repositories available to read.",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="local_repo_get_instructions",
            description="Return AGENTS.md, AGENT_CAPABILITIES.md (if present), and PROGRESS.md summary (if present) for a repo.",
            inputSchema={
                "type": "object",
                "properties": {"repo_id": {"type": "string"}},
                "required": ["repo_id"],
            },
        ),
        types.Tool(
            name="local_repo_tree",
            description=f"Directory listing (max {MAX_TREE_ENTRIES} entries, ignores .git/deps/build/secrets).",
            inputSchema={
                "type": "object",
                "properties": {
                    "repo_id": {"type": "string"},
                    "path": {"type": "string", "description": "Relative path within repo. Defaults to root."},
                },
                "required": ["repo_id"],
            },
        ),
        types.Tool(
            name="local_repo_search",
            description=f"Search for a pattern in a repo using ripgrep (max {MAX_SEARCH_MATCHES} matches).",
            inputSchema={
                "type": "object",
                "properties": {
                    "repo_id": {"type": "string"},
                    "pattern": {"type": "string"},
                    "path": {"type": "string", "description": "Relative path to scope search. Defaults to root."},
                },
                "required": ["repo_id", "pattern"],
            },
        ),
        types.Tool(
            name="local_repo_read_file",
            description=f"Read a file (UTF-8 only, max {MAX_FILE_BYTES} bytes).",
            inputSchema={
                "type": "object",
                "properties": {
                    "repo_id": {"type": "string"},
                    "path": {"type": "string", "description": "Relative path within repo."},
                },
                "required": ["repo_id", "path"],
            },
        ),
        types.Tool(
            name="local_repo_git_status",
            description="Compact uncommitted state for a repo.",
            inputSchema={
                "type": "object",
                "properties": {"repo_id": {"type": "string"}},
                "required": ["repo_id"],
            },
        ),
        types.Tool(
            name="local_repo_git_diff",
            description=f"Diff output for uncommitted changes (max {MAX_GIT_LINES} lines).",
            inputSchema={
                "type": "object",
                "properties": {
                    "repo_id": {"type": "string"},
                    "path": {"type": "string", "description": "Relative path to scope diff. Optional."},
                },
                "required": ["repo_id"],
            },
        ),
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list[types.TextContent]:
    def text(content: str) -> list[types.TextContent]:
        return [types.TextContent(type="text", text=content)]

    if name == "local_repo_health":
        return text(json.dumps({
            "version": VERSION,
            "mode": "read-only",
            "repo_count": len(_repos),
            "operations": ["read", "git_status", "git_diff"],
        }, indent=2))

    if name == "local_repo_list":
        summary = [{"id": r["id"], "name": r["name"], "description": r.get("description", "")} for r in _repos]
        return text(json.dumps(summary, indent=2))

    repo = _get_repo(arguments["repo_id"], _repos)
    root = Path(repo["path"]).resolve()

    if name == "local_repo_get_instructions":
        parts = []
        for filename in ("AGENTS.md", "AGENT_CAPABILITIES.md", "PROGRESS.md"):
            p = root / filename
            if p.exists():
                content = p.read_text(encoding="utf-8", errors="replace")
                if filename == "PROGRESS.md":
                    # Return only the handoff section to keep tokens manageable.
                    handoff_marker = "## Session handoff"
                    stop_marker = "## Upcoming work"
                    start = content.find(handoff_marker)
                    stop = content.find(stop_marker)
                    if start != -1:
                        content = content[start:stop if stop != -1 else start + 3000]
                parts.append(f"### {filename}\n\n{content.strip()}")
        return text("\n\n---\n\n".join(parts) if parts else "No instruction files found.")

    if name == "local_repo_tree":
        rel = arguments.get("path", "")
        target = _safe_path(root, rel) if rel else root
        if not target.exists():
            return text(f"Path not found: {rel!r}")
        entries = _tree_entries(target)
        header = f"{rel or '.'} ({len(entries)} entries)"
        return text(header + "\n" + "\n".join(entries))

    if name == "local_repo_search":
        pattern = arguments["pattern"]
        rel = arguments.get("path", "")
        search_root = _safe_path(root, rel) if rel else root
        cmd = [
            "rg", "--max-count", "1", "--line-number", "--no-heading",
            "--max-filesize", "1M", "-m", str(MAX_SEARCH_MATCHES),
            pattern, str(search_root),
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=root)
        lines = result.stdout.splitlines()[:MAX_SEARCH_MATCHES]
        # Make paths relative to repo root.
        rel_lines = [l.replace(str(root) + "/", "") for l in lines]
        return text("\n".join(rel_lines) if rel_lines else "No matches found.")

    if name == "local_repo_read_file":
        rel = arguments["path"]
        target = _safe_path(root, rel)
        if not target.exists():
            return text(f"File not found: {rel!r}")
        if _is_ignored(target):
            return text(f"Path {rel!r} is excluded.")
        raw = target.read_bytes()
        try:
            content = raw[:MAX_FILE_BYTES].decode("utf-8")
        except UnicodeDecodeError:
            return text(f"File {rel!r} is not valid UTF-8 (binary file).")
        truncated = len(raw) > MAX_FILE_BYTES
        if truncated:
            content += f"\n\n... (truncated — file is {len(raw)} bytes, limit {MAX_FILE_BYTES})"
        return text(content)

    if name == "local_repo_git_status":
        result = subprocess.run(
            ["git", "status", "--short", "--branch"],
            capture_output=True, text=True, cwd=root,
        )
        return text(result.stdout.strip() or "Working tree clean.")

    if name == "local_repo_git_diff":
        rel = arguments.get("path")
        cmd = ["git", "diff", "HEAD"]
        if rel:
            _safe_path(root, rel)
            cmd.append("--")
            cmd.append(rel)
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=root)
        lines = result.stdout.splitlines()[:MAX_GIT_LINES]
        output = "\n".join(lines)
        if len(result.stdout.splitlines()) > MAX_GIT_LINES:
            output += f"\n... (truncated at {MAX_GIT_LINES} lines)"
        return text(output or "No uncommitted changes.")

    return [types.TextContent(type="text", text=f"Unknown tool: {name!r}")]


async def main() -> None:
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options(),
        )


if __name__ == "__main__":
    asyncio.run(main())
