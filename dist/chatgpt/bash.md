---
# Generated — edit skill.json and SKILL.body.md instead.
name: bash
description: >
  Use this skill when writing shell scripts, zsh functions, bash utilities, .env files, or config files. Apply even for short scripts or helper functions — covers bash patterns, minimal documentation style, and config file conventions.
do-not-use-when:
  - Running an existing shell command without editing shell, environment, or Makefile content
  - Reading command output to diagnose an application issue
  - Editing JSON, YAML, or app configuration that is not shell-oriented
---
# Bash and Python scripts

Applies to standalone bash scripts and Python build/utility scripts. Keep both consistent.

## Shared conventions

- Tabs for indentation in all files, including Python
- Quote all variables and paths in bash
- Use `/path/to/directory` placeholders in examples, not user-specific paths

## Script-level comments

Every script opens with `#` purpose comment after shebang. For build scripts, include execution order or key constraints.

```bash
#!/usr/bin/env bash
# Generates all dist/ output from source files.
#
# Build order:
#   1. SKILL.md files (build-skill-mds.py)
#   2. Hook scripts copied to dist/claude/hooks/
#   3. Agent instruction files assembled from rules/
```

```python
#!/usr/bin/env python3
# Generate dist/claude/settings.json from adapters/claude/settings.base.json
# and hooks/claude/*/hook.json. The base file holds env, permissions, and
# skillOverrides; all hook entries are derived from manifests.
```

## Function comments

Every function gets purpose comment and JSDoc-style `@param` lines before definition. Bash/Python use code-style parameter format:

`# @param  {type}  name`

Put description on next indented line, even for few words. Add blank `#` line between purpose and first `@param`.

```bash
# Moves a file to its backup location and prints the backup path.
# Backup paths are routed by prefix so each agent's backups stay separate.
#
# @param  {string}  path
#     The file or symlink to back up.
backup_path() {
	local path="$1"
	…
}
```

```python
# Read skill.json and return the fields needed for index generation.
#
# @param  {Path}  skill_dir
#     The skill directory containing skill.json.
def load_manifest(skill_dir: Path) -> dict:
	…
```

Only comment when purpose is not obvious from name/signature. One-line file reader needs none; side effects/constraints need comment.

## Top-level variables

Use trailing `#` comment when variable purpose is not obvious from name.

```bash
MANIFEST="$REPO_DIR/external-skills.json"  # List of skills to sync, with URLs and metadata.
```

```python
PM_GROUP = "project-management"  # Listed first in the global index so it appears near slash-command docs.
```

## No banner dividers

Do not use `# ---` or `# ===` dividers. Use blank lines and plain section comments.

```bash
# Collect all skill names for dependency resolution.
declare -A SKILL_NAMES
```

## Extract repeated logic

If pattern appears more than once, extract named function. Name after what it resolves, not how it works.

```bash
# Returns 0 if the value is in the allowed list, 1 otherwise.
# @param  {string}  value
#     The value to check.
# @param  {string}  ...
#     Allowed values passed as remaining arguments.
is_valid() {
	local value="$1"
	shift
	local allowed
	for allowed in "$@"; do
		[ "$value" = "$allowed" ] && return 0
	done
	return 1
}
```

## Inline scripts in heredocs

When bash embeds Python/awk inline, add comment explaining what it does and why inline if needed.

```bash
# Strips YAML frontmatter and writes the body to the output file.
strip_frontmatter "$temp_file" "$skill_dir/SKILL.body.md"
```

If logic is complex, wrap heredoc in named function so call site stays readable.

## Bash boilerplate

```bash
#!/usr/bin/env bash

set -euo pipefail

if ! command -v jq &>/dev/null; then
	printf 'This script requires jq. Install it with: brew install jq\n' >&2
	exit 1
fi

config_path="${1:-/path/to/config.json}"

if [[ ! -f "$config_path" ]]; then
	printf 'Config file not found: %s\n' "$config_path" >&2
	exit 1
fi

jq -r '.name // "unknown"' "$config_path"
```

## Config files

- Minimal comments, no headers
- `.env`/`.conf` concise, scannable
- Config organised cleanly
