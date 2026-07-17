# Plugins

This page describes Claude Code plugins. Codex has its own plugin and connector surfaces; this repo currently treats Codex plugin parity as separate from the Claude plugin setup.

Plugins extend Claude Code with additional skills, hooks, and capabilities. They're installed globally and available in every session.

Plugins differ from skills: skills are files in this repository that you maintain directly; plugins are versioned packages installed from a marketplace (GitHub-based) and managed by Claude Code.

## Installed plugins

No Claude Code plugins are currently managed by this repo.

## Installing a plugin

```
/plugins install <marketplace>/<plugin-name>
```

Plugins are installed globally (user scope) and registered in `settings.json` under `enabledPlugins` when this repo manages them. Adding a new marketplace:

```json
"extraKnownMarketplaces": {
  "marketplace-name": {
    "source": {
      "source": "github",
      "repo": "owner/repo"
    }
  }
}
```

## Optional runtime tools

For MCP servers and CLI tools that complement this repo's skills (Serena MCP, repowise, and Fallow), see [docs/tools.md](tools.md). These are runtime dependencies, not plugins or upstream-managed skills in this repo.

## Plugin vs skill

| | Plugins | Skills |
|-|---------|--------|
| Maintained by | Plugin author (versioned releases) | You (files in this repo) |
| Installed via | `/plugins install` | Already available via symlinked `skills/` |
| Updated via | `/plugins update` | `git pull` on this repo |
| Scope | User-global | User-global (via symlink) |
| Best for | General-purpose tools (memory, compression) | Project conventions, language standards |
