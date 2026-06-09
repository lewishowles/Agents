# Global agent configuration

Shared configuration for Claude Code, OpenAI Codex, and ChatGPT. The repo keeps common rules in one place, generates agent-specific target files, and provides setup scripts for global and per-project configuration.

## What's inside

- `shared/` - source fragments used by both Claude and Codex
- `targets/claude/` - generated `CLAUDE.md`, Claude settings, hooks, and Claude-only source fragments
- `targets/codex/` - generated `AGENTS.md` and Codex-only source fragments
- `targets/chatgpt/` - generated `SKILLS.md` index and per-skill files for upload to a ChatGPT Custom GPT knowledge base
- `skills/` - user skills, each as a folder containing `SKILL.md`
- `external-skills.json` - official upstream skills synced into `skills/`
- `scripts/` - sync and setup scripts
- `templates/` - project templates for Claude, Codex, or both
- `docs/` - deeper reference: [setup](docs/setup.md), [Codex](docs/codex.md), [hooks](docs/hooks.md), [skills](docs/skills.md), [commands](docs/commands.md), [agents](docs/agents.md), [plugins](docs/plugins.md)

## Initial setup

Replace `/path/to/repository` with the path to this repository.

```bash
cd /path/to/repository
scripts/setup-global.sh --both
```

Use `--claude` or `--codex` to configure one runtime only. With no flag, the script asks which agent(s) to configure.

The global setup script syncs official external skills, runs `scripts/sync.sh`, then links:

- `~/.claude/CLAUDE.md` to `targets/claude/CLAUDE.md`
- `~/.claude/settings.json` to `targets/claude/settings.json`
- `~/.claude/.mcp.json` to `targets/claude/.mcp.json`
- `~/.claude/skills/<name>` to `skills/<name>`
- `~/.claude/hooks/<file>` to `targets/claude/hooks/<file>`
- `~/.agents/AGENTS.md` to `targets/codex/AGENTS.md`
- `~/.codex/AGENTS.md` to `targets/codex/AGENTS.md`
- `~/.agents/skills/<name>` to `skills/<name>`

It also ensures `~/.codex/config.toml` has the `codebase-memory-mcp` MCP server entry.

Existing files are backed up instead of overwritten.

If you need to run setup without network access, use:

```bash
scripts/setup-global.sh --both --skip-external
```

## ChatGPT setup

ChatGPT doesn't support automatic skill loading, so the setup is manual. After running `scripts/sync.sh`, the `targets/chatgpt/` directory contains everything you need.

**System prompt** — paste the contents of `targets/chatgpt/INSTRUCTIONS.md` into your Custom GPT's system prompt (or into ChatGPT's custom instructions).

**Knowledge base** — upload all the other files in `targets/chatgpt/` to the Custom GPT's knowledge base: `SKILLS.md` plus one `.md` file per skill.

Once uploaded, you can reference skills explicitly or let ChatGPT retrieve them automatically:

- _"Use my vue and code-style skills."_ — explicit, most reliable
- _"Use my skills."_ — ChatGPT reads `SKILLS.md`, determines which are relevant, and loads them

Re-upload the files after running `scripts/sync.sh` whenever skills change.

## Project setup

From a project root:

```bash
/path/to/repository/scripts/setup-project.sh --both
```

Use `--claude`, `--codex`, or `--both`:

- `--claude` creates `AGENTS.md`, `.claude/settings.json`, `.claude/.claudeignore`, and `.claude/templates/PLAN.md.template`
- `--codex` creates `AGENTS.md` plus `.agents/skills/`
- `--both` creates shared `AGENTS.md`, the Claude `.claude/` files, and `.agents/skills/`

Project setup skips existing files. It does not overwrite or back up project files because those are likely hand-edited.

## Hook dependency

Claude skill-trigger hooks require `jq`:

```bash
brew install jq
```

Codex hooks are separate from the Claude hooks in this repo. See [docs/codex.md](docs/codex.md) for the current Codex behaviour.

## Shell aliases

Add aliases to `~/.zshrc` if you run setup often:

```bash
alias setup:agents:global="/path/to/repository/scripts/setup-global.sh --both"
alias setup:claude:global="/path/to/repository/scripts/setup-global.sh --claude"
alias setup:codex:global="/path/to/repository/scripts/setup-global.sh --codex"
alias setup:agents="/path/to/repository/scripts/setup-project.sh --both"
alias setup:claude="/path/to/repository/scripts/setup-project.sh --claude"
alias setup:codex="/path/to/repository/scripts/setup-project.sh --codex"
```

## Common commands

```bash
scripts/sync.sh
scripts/sync-external-skills.sh
scripts/setup-global.sh --both
scripts/setup-project.sh --both
tests/setup-project.sh
```

## Going deeper

- [docs/setup.md](docs/setup.md) - manual setup steps if the scripts are not suitable
- [docs/codex.md](docs/codex.md) - Codex-specific files, config, skills, and hook notes
- [docs/hooks.md](docs/hooks.md) - Claude-only hook reference
- [docs/skills.md](docs/skills.md) - skills reference and trigger behaviour
- [docs/commands.md](docs/commands.md) - built-in, skill, and plugin commands
- [docs/agents.md](docs/agents.md) - Claude agent types
- [docs/plugins.md](docs/plugins.md) - Claude plugin notes
