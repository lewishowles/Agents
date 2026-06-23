# Local Repo Gateway MCP

Local Repo Gateway is a local MCP server for read-only inspection of selected repositories. It lets ChatGPT list configured repos, read project instructions, inspect files, search, and review Git state without exposing the whole filesystem.

## What it does

- Uses `repos.json` as an explicit allowlist of repositories.
- Resolves every repo operation through a stable `repo_id`.
- Keeps file paths relative to the configured repo root.
- Rejects path traversal outside the configured repo root.
- Excludes `.git`, dependencies, generated output, caches, and secret-looking paths from tree and file reads.
- Bounds responses for file reads, tree listings, search results, and diffs.
- Runs in read-only mode.

## What it does not do

- It does not expose arbitrary local paths.
- It does not let the model choose filesystem roots.
- It does not write files.
- It does not stage, commit, tag, push, merge, or rebase.
- It does not apply patches.
- It does not deploy, publish, or mutate remote services.

## Setup

Create a local repository allowlist:

```sh
cp servers/local-repo-gateway/repos.example.json servers/local-repo-gateway/repos.json
```

Edit `servers/local-repo-gateway/repos.json` so each entry points at a local repository you want to expose:

```json
{
  "repos": [
    {
      "id": "agents-config",
      "name": "Agent configuration",
      "path": "/Users/lewis/Dev/Configuration/Agents",
      "description": "Shared Claude, Codex, and ChatGPT configuration source",
      "operations": ["read", "git_status", "git_diff"]
    }
  ]
}
```

Start the server in foreground stdio mode:

```sh
scripts/local-repo-gateway-mcp.sh
```

The script checks for `repos.json`, creates a Python 3.12 virtual environment at `servers/local-repo-gateway/.venv` if one does not exist, installs requirements via `uv`, then starts `servers/local-repo-gateway/server.py`. Stop it with `Ctrl+C`. Requires `uv` on `PATH`.

## ChatGPT connector workflow

Add a local MCP connector in ChatGPT that uses stdio transport and starts this server script:

```sh
/path/to/Agents/scripts/local-repo-gateway-mcp.sh
```

Use the repository path that matches this checkout on your machine. The connector should launch the command directly over stdio; no HTTP tunnel or arbitrary filesystem bridge is needed.

After connecting:

1. Ask ChatGPT to use Local Repo Gateway.
2. ChatGPT calls `local_repo_health` to confirm the server is reachable.
3. ChatGPT calls `local_repo_list` to show configured repositories.
4. Choose the `repo_id` ChatGPT should inspect.
5. ChatGPT uses the read-only tools for planning or review.

## Available tools

| Tool                          | Returns                                                                                                                                   |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `local_repo_health`           | JSON with server version, mode, configured repo count, and available operations.                                                          |
| `local_repo_list`             | JSON list of allowlisted repos with `id`, `name`, and `description`.                                                                      |
| `local_repo_get_instructions` | `AGENTS.md`, `AGENT_CAPABILITIES.md` when present, and the `PROGRESS.md` handoff section when present.                                    |
| `local_repo_tree`             | Bounded directory listing for a repo-relative path, excluding Git data, dependencies, generated output, caches, and secret-looking paths. |
| `local_repo_search`           | Bounded `rg` results for a pattern, with paths made relative to the repo root.                                                            |
| `local_repo_read_file`        | Bounded UTF-8 file contents for one repo-relative path, or a message when the file is missing, excluded, binary, or too large.            |
| `local_repo_git_status`       | Compact `git status --short --branch` output, or `Working tree clean.`                                                                    |
| `local_repo_git_diff`         | Bounded `git diff HEAD` output, optionally scoped to one repo-relative path.                                                              |

## Planning workflow

1. Ask ChatGPT to inspect local repos with Local Repo Gateway.
2. ChatGPT calls `local_repo_list`.
3. Choose a repo.
4. ChatGPT reads instructions and `PROGRESS.md` metadata with `local_repo_get_instructions`.
5. ChatGPT uses targeted `local_repo_tree`, `local_repo_search`, and `local_repo_read_file` calls as needed.
6. ChatGPT discusses the plan, risks, and suggested next changes.

## Review workflow

1. Ask ChatGPT to review uncommitted work against `PROGRESS.md`.
2. ChatGPT reads instructions and handoff context with `local_repo_get_instructions`.
3. ChatGPT calls `local_repo_git_status` and `local_repo_git_diff`.
4. ChatGPT reads targeted files only where needed.
5. ChatGPT returns review findings, missed tests, risks, and alternative approaches.

## Troubleshooting

If the server does not start:

- Check that `servers/local-repo-gateway/repos.json` exists.
- Check that `repos.json` is valid JSON.
- Check that each repo entry has an `id`, `name`, `path`, `description`, and `operations`.
- Check that every configured `path` exists on disk.
- Run `scripts/local-repo-gateway-mcp.sh` from a terminal and read the first error.
- Check that `uv` is on `PATH` (`which uv`).
- Check that `uv` can create a Python 3.12 environment: `uv python install 3.12`.

If the ChatGPT connector cannot reach it:

- Check that the connector uses stdio transport.
- Check that the command points at the absolute path to `scripts/local-repo-gateway-mcp.sh`.
- Check that the script is executable.
- Start the same command manually in a terminal to confirm it launches.
- Check that ChatGPT is not configured for an HTTP URL or tunnel for this connector.
- Check connector logs for `repos.json not found`, Python dependency errors, or JSON parse errors.

If a tool cannot read a path:

- Use `local_repo_list` to confirm the `repo_id`.
- Use repo-relative paths, not absolute paths.
- Check that the path does not escape the repo root.
- Check that the path is not excluded as Git data, dependency output, generated output, cache data, or secret-looking content.
