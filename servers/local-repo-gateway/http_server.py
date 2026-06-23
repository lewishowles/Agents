#!/usr/bin/env python3
"""Local Repo Gateway — HTTP server for ChatGPT Custom GPT Actions.

Exposes the same 8 tools as the MCP server over a simple REST API.
Requires an auth token set via the GATEWAY_TOKEN env var.
"""

import os
import sys
from pathlib import Path

from fastapi import FastAPI, HTTPException, Security
from fastapi.security.api_key import APIKeyHeader

# Allow running from the repo root or directly.
sys.path.insert(0, str(Path(__file__).parent))

from tools import (
    VERSION,
    _get_repo,
    _load_config,
    tool_get_instructions,
    tool_git_diff,
    tool_git_status,
    tool_health,
    tool_list,
    tool_list_skills,
    tool_read_file,
    tool_read_skill,
    tool_search,
    tool_tree,
)

_config = _load_config()
_repos = _config["repos"]

TOKEN = os.environ.get("GATEWAY_TOKEN", "")
if not TOKEN:
    print("ERROR: GATEWAY_TOKEN env var not set. Refusing to start.", file=sys.stderr)
    sys.exit(1)

app = FastAPI(
    title="Local Repo Gateway",
    version=VERSION,
    description="Read-only access to allowlisted local repositories.",
    openapi_version="3.1.0",
)

_api_key_header = APIKeyHeader(name="X-Gateway-Token", auto_error=True)


async def _auth(key: str = Security(_api_key_header)) -> None:
    if key != TOKEN:
        raise HTTPException(status_code=403, detail="Invalid token.")


def _repo(repo_id: str) -> dict:
    try:
        return _get_repo(repo_id, _repos)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@app.get("/health", dependencies=[Security(_auth)], operation_id="health")
def health():
    return tool_health(_repos, {})


@app.get("/repos", dependencies=[Security(_auth)], operation_id="list_repos")
def list_repos():
    return tool_list(_repos, {})


@app.get("/repos/{repo_id}/instructions", dependencies=[Security(_auth)], operation_id="get_instructions")
def get_instructions(repo_id: str):
    return tool_get_instructions(_repo(repo_id), {})


@app.get("/repos/{repo_id}/tree", dependencies=[Security(_auth)], operation_id="tree")
def tree(repo_id: str, path: str = ""):
    return tool_tree(_repo(repo_id), {"path": path})


@app.get("/repos/{repo_id}/search", dependencies=[Security(_auth)], operation_id="search")
def search(repo_id: str, pattern: str, path: str = ""):
    return tool_search(_repo(repo_id), {"pattern": pattern, "path": path})


@app.get("/repos/{repo_id}/file", dependencies=[Security(_auth)], operation_id="read_file")
def read_file(repo_id: str, path: str):
    return tool_read_file(_repo(repo_id), {"path": path})


@app.get("/repos/{repo_id}/git/status", dependencies=[Security(_auth)], operation_id="git_status")
def git_status(repo_id: str):
    return tool_git_status(_repo(repo_id), {})


@app.get("/repos/{repo_id}/git/diff", dependencies=[Security(_auth)], operation_id="git_diff")
def git_diff(repo_id: str, path: str = ""):
    return tool_git_diff(_repo(repo_id), {"path": path})


@app.get("/skills", dependencies=[Security(_auth)], operation_id="list_skills")
def list_skills():
    return tool_list_skills({})


@app.get("/skills/{slug}", dependencies=[Security(_auth)], operation_id="read_skill")
def read_skill(slug: str):
    return tool_read_skill({"slug": slug})


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("GATEWAY_PORT", "8754"))
    uvicorn.run(app, host="127.0.0.1", port=port)
