# Codex

This repo targets Codex through global `AGENTS.md`, user skills, project templates, and Serena MCP hooks.

Official references:

- [Custom instructions with AGENTS.md](https://developers.openai.com/codex/guides/agents-md)
- [Configuration reference](https://developers.openai.com/codex/config-reference)
- [Hooks](https://developers.openai.com/codex/hooks)

## Instruction files

Codex reads `AGENTS.md` before work starts. The official discovery order is:

1. Global scope: `~/.agents/AGENTS.override.md` if present, otherwise `~/.agents/AGENTS.md`
2. Project scope: from project root down to the current directory, one guidance file per directory
3. Per-directory priority: `AGENTS.override.md`, then `AGENTS.md`, then names from `project_doc_fallback_filenames`

Later files appear later in the combined prompt, so deeper project guidance overrides broader guidance.

This repo links `~/.agents/AGENTS.md` and `~/.codex/AGENTS.md` to `dist/codex/AGENTS.md`.

Project setup creates a root `AGENTS.md` using one of:

- `templates/codex/AGENTS.md.template`
- `templates/shared/AGENTS.md.template`

## Config

User-level Codex app config lives at `~/.codex/config.toml`. User-global skills and global `AGENTS.md` live under `~/.agents` on this machine. Project-level config can live at `.agents/config.toml`, and Codex loads it only for trusted projects.

Useful keys for this repo:

```toml
project_doc_fallback_filenames = ["TEAM_GUIDE.md"]
project_doc_max_bytes = 65536
```

The official reference also documents `skills.config` for per-skill path and enablement overrides.

Global setup preserves unrelated settings in `~/.codex/config.toml` and sets these defaults alongside the managed MCP server:

```toml
approval_policy = "never"
sandbox_mode = "workspace-write"

[mcp_servers.codebase-memory-mcp]
command = "codebase-memory-mcp"
```

Setup also registers the MDN docs and browser-compat server, shipped disabled so it loads nothing until enabled. Ask the user to enable it when a browser-support or Baseline fact needs a live source:

```toml
[mcp_servers.mdn]
url = "https://mcp.mdn.mozilla.net/"
enabled = false
```

Indexing is explicit by default. `codebase-memory-mcp config list` currently reports `auto_index = false`, so run `index_repository` for a project before expecting graph queries to work. The CLI form is:

```bash
codebase-memory-mcp cli index_repository '{"repo_path":"'$PWD'"}'
```

## Skills

This repo uses `~/.agents/skills/<name>` for user-global skill symlinks. `scripts/setup-global.sh --codex` links every repo skill there.

Project setup does not create `.agents/skills/` by default. Add that directory only when a project has local Codex skills.

Skill matching is description-driven. Keep frontmatter descriptions specific, action-led, and prefixed with `Use this skill when...` so Codex has enough signal before loading the full skill body.

The `code-lookup` skill routes code discovery between Serena, codebase-memory, and targeted text search. Codebase-memory remains available for broad graph questions but is not a mandatory first step.

## Hooks

Codex hooks are configured through `~/.codex/hooks.json`, linked to the generated `dist/codex/hooks.json` file. The hook configuration has one JSON representation. The official Codex hook events include `SessionStart`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `UserPromptSubmit`, and `Stop`.

This repo installs Serena MCP hooks for Codex:

- **`serena-activate`** (`SessionStart`) — prompts the agent to activate the project with Serena on session start or resume.
- **`serena-remind`** (`PreToolUse`, `Bash` matcher) — nudges the agent to use Serena's symbolic tools instead of consecutive shell-based grep and code-file reads.
- **`serena-cleanup`** (`Stop`) — cleans up Serena hook session data when the session ends.

The managed Codex adapter also preserves HCOM's hook events. Each HCOM command
adds Homebrew's standard executable locations to `PATH` before invoking `hcom`,
because Codex hook processes may not inherit the interactive shell's `PATH`.
If `hcom hooks add codex` replaces `~/.codex/hooks.json`, rerun
`scripts/sync.sh` and `scripts/setup-global.sh --codex`. Setup moves the
replacement to a timestamped backup and restores the managed link.

The `PreToolUse` matcher is intentionally restricted to `Bash` because the Serena reminder hook for Codex tracks shell-based grep and code-file reads, so running it for every tool call is unnecessary.

`scripts/setup-global.sh --codex` links `dist/codex/hooks.json` into `~/.codex/`, preserves Codex's hook trust state, removes previously managed inline hooks, and ensures `hooks = true` is present in the `[features]` section.
