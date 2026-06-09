# Commands

Commands are typed directly into Claude Code with a `/` prefix. They fall into three categories: built-in Claude Code commands, skills (which double as commands), and plugin skills.

## Built-in Claude Code commands

These are provided by Claude Code itself and are always available.

| Command | What it does |
|---------|-------------|
| `/help` | List available commands and keyboard shortcuts |
| `/clear` | Clear the current conversation context |
| `/compact` | Summarise the conversation to free up context space |
| `/config` | Open Claude Code settings (theme, model, etc.) |
| `/model` | Switch the active model (e.g. `/model claude-sonnet-4-6`) |
| `/cost` | Show token usage and estimated cost for the session |
| `/status` | Show current session status |
| `/init` | Initialise a new `CLAUDE.md` in the current project |
| `/review` | Review a pull request |
| `/fast` | Toggle fast mode (Opus 4.6 with faster output) |
| `/vim` | Toggle Vim keybindings |
| `/bug` | Report a Claude Code bug |
| `/pr_comments` | Fetch comments from a GitHub pull request |

## Skills as commands

Every skill can be invoked manually as a command. Type the skill name with a `/` prefix.

| Command | Skill | When to use it manually |
|---------|-------|------------------------|
| `/accessibility` | accessibility | Auditing an interface for WCAG compliance |
| `/architecture-decision-records` | architecture-decision-records | Documenting a technical decision |
| `/bash` | bash | Writing a shell script or `.env` file |
| `/codebase-memory` | codebase-memory | Exploring structure, tracing callers, or querying the code graph |
| `/code-style` | code-style | Reviewing formatting before committing |
| `/dependencies` | dependencies | Evaluating a new package |
| `/e2e-testing` | e2e-testing | Writing Playwright tests |
| `/error-handling` | error-handling | Adding validation to a function |
| `/pinia` | pinia | Working with client-side Vue stores |
| `/pinia-colada` | pinia-colada | Working with `@pinia/colada` queries, mutations, or cache |
| `/readme` | readme | Starting or editing a README |
| `/session-management` | session-management | Saving or resuming a session |
| `/swift` | swift | Working in a Swift file |
| `/swift-ui` | swift-ui | Working with SwiftUI views |
| `/typescript` | typescript | Resolving type errors |
| `/ui-copy` | ui-copy | Writing button labels or error messages |
| `/unit-testing` | unit-testing | Writing or reviewing tests |
| `/vite-patterns` | vite-patterns | Configuring Vite |
| `/vue` | vue | Working in a `.vue` file |
| `/vue-project-stack` | vue-project-stack | Working in a Vue project |
| `/vue-router` | vue-router | Working with Vue Router routes, guards, params, or query strings |
| `/vueuse-functions` | vueuse-functions | Checking VueUse composables before writing bespoke Vue utilities |
| `/writing` | writing | Writing or editing prose |

Most of these fire automatically via the trigger hooks — manual invocation is for cases the hooks don't catch, or to load a skill at the start of a session.

## Custom commands

Slash commands can be defined as plain markdown files. Claude Code reads them as additional instructions when invoked.

- **Global commands** live in `~/.claude/commands/` and are available in every project. `scripts/setup-global.sh` symlinks everything in `dist/claude/commands/` there automatically.
- **Project commands** live in `.claude/commands/` at the project root and are only available in that project.

The file name becomes the command: `new-command.md` → `/new-command`.

| Command | What it does |
|---------|-------------|
| `/new-command` | Scaffold a new slash command file with the standard structure |

## Plugin commands

No plugin commands are currently documented by this repo. See [docs/plugins.md](plugins.md) if plugin management is added later.
