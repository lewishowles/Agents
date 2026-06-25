#!/usr/bin/env python3
"""Local Repo Gateway MCP server — read-only access to allowlisted local repositories."""

import asyncio

from mcp.server import Server
from mcp.server.stdio import stdio_server
import mcp.types as types

from tools import (
    MAX_FILE_BYTES,
    MAX_GIT_LINES,
    MAX_SEARCH_MATCHES,
    MAX_TREE_ENTRIES,
    _get_repo,
    _load_config,
    tool_get_instructions,
    tool_git_diff,
    tool_git_status,
    tool_health,
    tool_list,
    tool_read_file,
    tool_search,
    tool_tree,
)


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
            description="Return AGENTS.md, WORKSPACE.md (or legacy AGENT_CAPABILITIES.md), and the PROGRESS.md handoff for a repo.",
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
        return text(tool_health(_repos, arguments))

    if name == "local_repo_list":
        return text(tool_list(_repos, arguments))

    repo = _get_repo(arguments["repo_id"], _repos)

    if name == "local_repo_get_instructions":
        return text(tool_get_instructions(repo, arguments))

    if name == "local_repo_tree":
        return text(tool_tree(repo, arguments))

    if name == "local_repo_search":
        return text(tool_search(repo, arguments))

    if name == "local_repo_read_file":
        return text(tool_read_file(repo, arguments))

    if name == "local_repo_git_status":
        return text(tool_git_status(repo, arguments))

    if name == "local_repo_git_diff":
        return text(tool_git_diff(repo, arguments))

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
