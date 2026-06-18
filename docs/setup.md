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

Create `~/.codex/skills/`, then link each skill folder:

```bash
ln -s /path/to/repository/skills/vue ~/.codex/skills/vue
```

This keeps the active Codex setup in one place: `~/.codex` for config, global `AGENTS.md`, and user skill symlinks. `scripts/setup-global.sh --codex` also maintains compatibility links in `~/.agents/skills/`.

If external skill sync fails because the network is unavailable, keep the existing local `skills/<name>` copy and continue setup. `scripts/setup-global.sh --both` does this automatically; pass `--skip-external` to bypass the sync step intentionally.

## Project setup

For Claude-only projects:

```bash
cp /path/to/repository/templates/claude/AGENTS.md.template AGENTS.md
/path/to/repository/scripts/setup-project.sh --write-capabilities
mkdir -p .claude
cp /path/to/repository/templates/claude/.claudeignore .claude/.claudeignore
```

For Codex-only projects:

```bash
cp /path/to/repository/templates/codex/AGENTS.md.template AGENTS.md
/path/to/repository/scripts/setup-project.sh --write-capabilities
```

For projects using both:

```bash
cp /path/to/repository/templates/shared/AGENTS.md.template AGENTS.md
/path/to/repository/scripts/setup-project.sh --write-capabilities
mkdir -p .claude
cp /path/to/repository/templates/claude/.claudeignore .claude/.claudeignore
```

After setup, replace placeholders in `AGENTS.md` with project-specific rules and review the generated `AGENT_CAPABILITIES.md`.

For an existing project, preview a capabilities draft before writing it:

```bash
cd /path/to/project
/path/to/repository/scripts/setup-project.sh --init-capabilities
```

Write the draft only when the preview is useful:

```bash
cd /path/to/project
/path/to/repository/scripts/setup-project.sh --write-capabilities
```

Use `--force-capabilities` only after reviewing the existing `AGENT_CAPABILITIES.md`. Recognised manual values are preserved when the draft is refreshed.
