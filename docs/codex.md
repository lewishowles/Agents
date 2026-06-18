# Codex

This repo targets Codex through global `AGENTS.md`, user skills, and project templates. Codex hooks exist, but this repo does not install Codex hook parity yet.

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

User-level Codex app config lives at `~/.codex/config.toml`. Legacy/user skill wiring also uses `~/.agents` on this machine. Project-level config can live at `.agents/config.toml`, and Codex loads it only for trusted projects.

Useful keys for this repo:

```toml
project_doc_fallback_filenames = ["TEAM_GUIDE.md"]
project_doc_max_bytes = 65536
```

The official reference also documents `skills.config` for per-skill path and enablement overrides.

Global setup preserves the existing `~/.codex/config.toml` and ensures this MCP server is present:

```toml
[mcp_servers.codebase-memory-mcp]
command = "codebase-memory-mcp"
```

Indexing is explicit by default. `codebase-memory-mcp config list` currently reports `auto_index = false`, so run `index_repository` for a project before expecting graph queries to work. The CLI form is:

```bash
codebase-memory-mcp cli index_repository '{"repo_path":"'$PWD'"}'
```

## Skills

This repo uses `~/.codex/skills/<name>` for user-global skill symlinks in current Codex builds. `scripts/setup-global.sh --codex` links every repo skill there, and also keeps `~/.agents/skills/<name>` linked for compatibility with older local setups.

Project setup does not create `.agents/skills/` by default. Add that directory only when a project has local Codex skills.

Skill matching is description-driven. Keep frontmatter descriptions specific, action-led, and prefixed with `Use this skill when...` so Codex has enough signal before loading the full skill body.

## Hooks

Codex hooks are configured through `hooks.json` next to active config layers or inline `[hooks]` tables in `config.toml`. The official Codex hook events include `SessionStart`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `UserPromptSubmit`, and `Stop`.

Codex hook parity is intentionally out of scope for the current repo phase. The Claude hooks remain in `dist/claude/hooks/`; Codex relies on skill descriptions and `AGENTS.md` guidance until dedicated Codex hooks are added.
