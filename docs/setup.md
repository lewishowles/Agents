# Setup

Use the scripts for normal installs. These manual steps are here as a fallback when you need to inspect or repair the wiring.

## Global Claude setup

Run `scripts/sync-external-skills.sh`, then `scripts/sync.sh`, then link these paths:

```bash
ln -s /path/to/repository/dist/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -s /path/to/repository/dist/claude/settings.json ~/.claude/settings.json
ln -s /path/to/repository/dist/claude/.mcp.json ~/.claude/.mcp.json
```

Create `~/.claude/skills/`, `~/.claude/hooks/`, and `~/.claude/commands/`, then link each item individually:

```bash
ln -s /path/to/repository/skills/vue ~/.claude/skills/vue
ln -s /path/to/repository/dist/claude/commands/new-command.md ~/.claude/commands/new-command.md
```

Repeat for each skill, hook, and command. Per-item links allow plugin-installed items to coexist.

## Global Codex setup

Run `scripts/sync-external-skills.sh`, then `scripts/sync.sh`, then link:

```bash
ln -s /path/to/repository/dist/codex/AGENTS.md ~/.agents/AGENTS.md
ln -s /path/to/repository/dist/codex/AGENTS.md ~/.codex/AGENTS.md
```

Ensure `~/.codex/config.toml` includes:

```toml
approval_policy = "never"
sandbox_mode = "workspace-write"

[mcp_servers.codebase-memory-mcp]
command = "codebase-memory-mcp"
```

codebase-memory-mcp does not auto-index by default. From a project root, index manually with:

```bash
codebase-memory-mcp cli index_repository '{"repo_path":"'$PWD'"}'
```

After indexing, review the architecture summary and store an ADR so future sessions have durable project context:

```bash
codebase-memory-mcp cli get_architecture '{"project":"Users-lewis-Dev-Repositories-example","aspects":["all"]}'
codebase-memory-mcp cli manage_adr '{"project":"Users-lewis-Dev-Repositories-example","mode":"update","content":"Architecture notes from get_architecture"}'
```

If `get_architecture` errors with `aspects:["all"]`, run it without `aspects`. Some CLI versions advertise `manage_adr(mode="store")`, but the current MCP schema uses `mode="update"`.

For zsh, add a helper like this:

```zsh
index:repository() {
	if ! command -v codebase-memory-mcp &>/dev/null; then
		printf 'codebase-memory-mcp is not installed or not on PATH\n' >&2
		return 1
	fi

	if ! command -v jq &>/dev/null; then
		printf 'jq is required to build JSON payloads safely\n' >&2
		return 1
	fi

	local repo_path index_output project architecture

	repo_path="${PWD:A}"
	index_output="$(codebase-memory-mcp cli index_repository "$(jq -cn --arg repo_path "$repo_path" '{repo_path:$repo_path}')")" || return
	project="$(printf '%s' "$index_output" | jq -r '.project // empty' 2>/dev/null)"

	if [[ -z "$project" ]]; then
		project="$(codebase-memory-mcp cli list_projects '{}' | jq -r --arg repo_path "$repo_path" 'first(.projects[] | select(.root_path == $repo_path) | .name) // empty')"
	fi

	if [[ -z "$project" ]]; then
		printf 'Could not find an indexed project for %s\n' "$repo_path" >&2
		printf '%s\n' "$index_output" >&2
		return 1
	fi

	if [[ -n "$index_output" ]]; then
		printf '%s\n' "$index_output"
	fi

	architecture="$(codebase-memory-mcp cli get_architecture "$(jq -cn --arg project "$project" '{project:$project,aspects:["all"]}')" 2>/dev/null || codebase-memory-mcp cli get_architecture "$(jq -cn --arg project "$project" '{project:$project}')")" || return
	printf '%s\n' "$architecture"

	codebase-memory-mcp cli manage_adr "$(jq -cn --arg project "$project" --arg content "$architecture" '{project:$project,mode:"update",content:$content}')"
}
```

Or, inside Claude/Codex when the MCP tools are available, call `index_repository` with the current repository path. Check indexed projects with:

```bash
codebase-memory-mcp cli list_projects '{}'
```

Create `~/.agents/skills/`, then link each skill folder:

```bash
ln -s /path/to/repository/src/skills/vue ~/.agents/skills/vue
```

This keeps Codex skill discovery under `~/.agents` while `~/.codex` holds app config and hooks.

If external skill sync fails because the network is unavailable, keep the existing local `src/skills/<name>` copy and continue setup. `scripts/setup-global.sh --both` does this automatically; pass `--skip-external` to bypass the sync step intentionally.

## Project setup

Run `setup-project.sh` from the project root, passing the agent flag that matches the project:

```bash
cd /path/to/project

# Claude-only
/path/to/repository/scripts/setup-project.sh --claude

# Codex-only
/path/to/repository/scripts/setup-project.sh --codex

# Both
/path/to/repository/scripts/setup-project.sh --both
```

Each flag copies the matching `AGENTS.md` template, links `.agent/scripts/`, writes `WORKSPACE.md`, and (for Claude targets) copies `.claudeignore`. After setup, replace the placeholders in `AGENTS.md` with project-specific rules and review the generated `WORKSPACE.md`.

For project types with useful local skills, setup can install centrally managed project skill packs as symlinks into both `.agents/skills/` and `.claude/skills/`:

```bash
/path/to/repository/scripts/setup-project.sh --both --with-skill-pack macos
```

macOS/Swift projects are detected from Xcode projects, Swift packages with Swift sources, or project instructions mentioning Swift or macOS. Interactive setup offers the macOS pack when detected. Use `--no-skill-packs` to skip detection, or list available packs with:

```bash
/path/to/repository/scripts/setup-project.sh --list-skill-packs
```

### Repair paths for existing projects

To preview a workspace draft without writing it:

```bash
cd /path/to/project
/path/to/repository/scripts/setup-project.sh --init-workspace
```

To write workspace context only (when `AGENTS.md` is already in place):

```bash
cd /path/to/project
/path/to/repository/scripts/setup-project.sh --write-workspace
```

Use `--force-workspace` only after reviewing the existing `WORKSPACE.md`. Recognised manual values are preserved when the draft is refreshed.

The previous `--init-capabilities`, `--write-capabilities`, and `--force-capabilities` flags remain as deprecated aliases during migration.

The default output omits the broad file tree. Pass `--tree-depth <number>` when a tree is useful.

Add `.agent-workspace.json` for reviewed facts that cannot be detected safely:

```json
{
	"architectureNotes": [
		"Requests enter through src/index.js."
	],
	"keyFiles": {
		"`package.json`": "Package scripts and published metadata."
	},
	"lookup": {
		"Add analyser": "`src/analyser`"
	}
}
```

Configured notes are labelled in `WORKSPACE.md`. They should state repository facts, not recommendations or temporary plans.
