# Setup

Use the scripts for normal installs. These manual steps are here as a fallback when you need to inspect or repair the wiring.

## Global Claude setup

Run `scripts/sync.sh`, then link these paths:

```bash
ln -s /path/to/repository/targets/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -s /path/to/repository/targets/claude/settings.json ~/.claude/settings.json
```

Create `~/.claude/skills/`, `~/.claude/hooks/`, and `~/.claude/commands/`, then link each item individually:

```bash
ln -s /path/to/repository/skills/vue ~/.claude/skills/vue
ln -s /path/to/repository/targets/claude/hooks/skill-autotrigger.sh ~/.claude/hooks/skill-autotrigger.sh
ln -s /path/to/repository/targets/claude/commands/new-command.md ~/.claude/commands/new-command.md
```

Repeat for each skill, hook, and command. Per-item links allow plugin-installed items to coexist.

## Global Codex setup

Run `scripts/sync.sh`, then link:

```bash
ln -s /path/to/repository/targets/codex/AGENTS.md ~/.agents/AGENTS.md
```

Create `~/.agents/skills/`, then link each skill folder:

```bash
ln -s /path/to/repository/skills/vue ~/.agents/skills/vue
```

This keeps the active Codex setup in one place: `~/.agents` for config, global `AGENTS.md`, and user skill symlinks.

## Project setup

For Claude-only projects:

```bash
cp /path/to/repository/templates/claude/AGENTS.md.template AGENTS.md
mkdir -p .claude/templates
cp /path/to/repository/templates/claude/settings.json .claude/settings.json
cp /path/to/repository/templates/claude/.claudeignore .claude/.claudeignore
cp /path/to/repository/templates/claude/.oxfmtrc.jsonc .oxfmtrc.jsonc
cp /path/to/repository/templates/PLAN.md.template .claude/templates/PLAN.md.template
```

For Codex-only projects:

```bash
cp /path/to/repository/templates/codex/AGENTS.md.template AGENTS.md
mkdir -p .agents/skills
```

For projects using both:

```bash
cp /path/to/repository/templates/shared/AGENTS.md.template AGENTS.md
mkdir -p .claude/templates
cp /path/to/repository/templates/claude/settings.json .claude/settings.json
cp /path/to/repository/templates/claude/.claudeignore .claude/.claudeignore
cp /path/to/repository/templates/claude/.oxfmtrc.jsonc .oxfmtrc.jsonc
cp /path/to/repository/templates/PLAN.md.template .claude/templates/PLAN.md.template
mkdir -p .agents/skills
```

After copying, replace placeholders in `AGENTS.md` with project-specific rules.
