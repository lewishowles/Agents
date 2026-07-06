# Local Repo Gateway MCP

Local Repo Gateway is a local MCP server for read-only inspection of selected repositories. It lets ChatGPT list configured repos, read project instructions, inspect files, search, and review Git state without exposing the whole filesystem.

## What it does

- Uses `repos.json` as an explicit allowlist of repositories.
- Resolves every repo operation through a stable `repo_id`.
- Keeps file paths relative to the configured repo root.
- Rejects path traversal outside the configured repo root.
- Excludes `.git`, dependencies, generated output, caches, and secret-looking paths from tree and file reads.
- Bounds responses for file reads, tree listings, search results, and diffs.
- Runs in read-only mode for direct filesystem mutation.
- Can propose a single-file text change as a unified diff, for repos that opt in — computed only, never written to disk.

## What it does not do

- It does not expose arbitrary local paths.
- It does not let the model choose filesystem roots.
- It does not write files.
- It does not stage, commit, tag, push, merge, or rebase.
- It does not apply patches — patch proposals are returned as text for you to apply and commit yourself.
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

## ChatGPT setup (Custom GPT with Actions)

ChatGPT connects via an HTTP server exposed through a Cloudflare tunnel. You need a Cloudflare account with a domain managed by Cloudflare DNS, and `cloudflared` installed (`brew install cloudflare/cloudflare/cloudflared`).

Run the setup script from the repo root:

```sh
bash scripts/local-repo-gateway-setup.sh
```

The script will:

1. Check prerequisites (`cloudflared`, `uv`, `rg`)
2. Ask for the Cloudflare domain and hostname prefix
3. Create the tunnel and DNS route
4. Generate an auth token and tell you where to store it
5. Write all config files
6. Install and start the LaunchAgents
7. Print the ChatGPT Custom GPT wiring instructions

Re-running the script is safe — existing tunnels and tokens are detected and preserved.

After the script finishes, follow the printed instructions to create a Custom GPT in ChatGPT with the generated schema and token. Paste the contents of `servers/local-repo-gateway/openapi.json` directly into the schema editor rather than importing by URL.

Logs:

```sh
tail -f /tmp/local-repo-gateway-http.log
tail -f /tmp/local-repo-gateway-tunnel.log
```

## Available tools

| Tool                          | Returns                                                                                                                                   |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `local_repo_health`           | JSON with server version, mode, configured repo count, and available operations.                                                          |
| `local_repo_list`             | JSON list of allowlisted repos with `id`, `name`, and `description`.                                                                      |
| `local_repo_get_instructions` | `AGENTS.md`, `WORKSPACE.md` or legacy `AGENT_CAPABILITIES.md`, and the `PROGRESS.md` handoff section when present.                       |
| `local_repo_tree`             | Bounded directory listing for a repo-relative path, excluding Git data, dependencies, generated output, caches, and secret-looking paths. |
| `local_repo_search`           | Bounded `rg` results for a pattern, with paths made relative to the repo root.                                                            |
| `local_repo_read_file`        | Bounded UTF-8 file contents for one repo-relative path, or a message when the file is missing, excluded, binary, or too large.            |
| `local_repo_git_status`       | Compact `git status --short --branch` output, or `Working tree clean.`                                                                    |
| `local_repo_git_diff`         | Bounded `git diff HEAD` output, optionally scoped to one repo-relative path.                                                              |
| `local_repo_propose_patch`    | Unified diff for a single-file text change (max 400 diff lines). Computed only — never written to disk. Requires `propose_patch` in the repo's `operations` allowlist. |

## Schema design

Tool `inputSchema`s stay flat: top-level string params only, no nested arrays of objects. Nested-object-array parameters are the highest-risk shape for malformed model tool calls (per Armin Ronacher's "Better Models: Worse Tools", 2026-07-04); flat schemas keep calls simple to validate and hard to get wrong. Every schema also sets `"additionalProperties": false` to reject invented keys. Revisit this if a future tool genuinely needs structured/array input.

## Patch-proposal workflow

Opt a repo in by adding `"propose_patch"` to its `operations` list in `repos.json`. It is omitted by default, so existing repos stay strictly read-only.

1. Ask ChatGPT to change a file in an opted-in repo.
2. ChatGPT calls `local_repo_propose_patch` with the target path and the full proposed file content.
3. The gateway computes a unified diff and returns it — the working tree is untouched.
4. You review the diff.
5. You apply it yourself (`git apply`, editor, etc.) and commit manually.

Proposals are capped at 400 diff lines and one file per call, to keep review chunks small. Larger changes come back as multiple smaller proposals instead of one large diff.

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

If the HTTP server does not start:

- Check `GATEWAY_TOKEN` is set: `echo $GATEWAY_TOKEN`
- Check `servers/local-repo-gateway/repos.json` exists and is valid JSON
- Check every configured `path` exists on disk
- Run `bash scripts/local-repo-gateway-http.sh` in a terminal and read the first error
- Check logs: `tail -20 /tmp/local-repo-gateway-http.log`
- Check `uv` is on `PATH` (`which uv`) and can create Python 3.12: `uv python install 3.12`

If the tunnel does not connect:

- Check logs: `tail -20 /tmp/local-repo-gateway-tunnel.log`
- Run `bash scripts/local-repo-gateway-tunnel.sh` in a terminal to see errors directly
- Check `cloudflared` is installed: `which cloudflared`
- Verify the tunnel still exists: `cloudflared tunnel list`
- Confirm DNS is routed correctly: `cloudflared tunnel info local-repo-gateway`

If ChatGPT cannot reach the gateway:

- Confirm the HTTP server is reachable through the tunnel: `curl -s -H "X-Gateway-Token: $GATEWAY_TOKEN" https://<your-tunnel-hostname>/health`
- Check the token in the Custom GPT Action matches `$GATEWAY_TOKEN` exactly
- Re-run `bash scripts/local-repo-gateway-install.sh` if you've changed the token

If a tool cannot read a path:

- Use `local_repo_list` to confirm the `repo_id`
- Use repo-relative paths, not absolute paths
- Check the path is not excluded as Git data, dependency output, generated output, cache, or secret-looking content
