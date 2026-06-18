---
# Generated — edit skill.json and SKILL.body.md instead.
name: boilersuit
description: >
  Use this skill when a project provides Boilersuit generators or when creating repeatable files from a Boilersuit boilerplate. Covers inspecting project support, listing and describing generators, previewing planned files, and only generating after preview.
do-not-use-when:
  - Creating a one-off bespoke file where a generator would add overhead
  - Editing existing code without adding a repeatable structure
  - The project has no Boilersuit generators and no boilerplate setup task
---
# Boilersuit

Use Boilersuit for repeatable project structures, not bespoke one-off files. Inspect the project before reading broadly or guessing generator names.

## First checks

Confirm the CLI exists:

```bash
command -v boilersuit
```

From the project folder, inspect support:

```bash
boilersuit project inspect --json
boilersuit generators list --json
```

If a command prints `LLVM Profile Error: Failed to write file "default.profraw"`, rerun it with profile output in `/tmp`:

```bash
env LLVM_PROFILE_FILE=/tmp/boilersuit-%p.profraw boilersuit project inspect --json
```

## Command forms

`<project-path>` is optional; when omitted, Boilersuit uses the current directory.

```bash
boilersuit project inspect [<project-path>] --json
boilersuit generators list [<project-path>] --json
boilersuit generators describe [<project-path>] <generator-id> --json
boilersuit generate preview [<project-path>] <generator-id> --json [--field TOKEN=value] [--variant id] [--path path] [--file template]
boilersuit generate [<project-path>] <generator-id> --field TOKEN=value --json [--variant id] [--path path] [--file template]
boilersuit project open [<project-path>] (--editor | --terminal | --file-manager) --json
```

Opening an editor, terminal, or file manager may need user approval in sandboxed environments.

## Generation workflow

1. Run `boilersuit project inspect --json`.
2. Run `boilersuit generators list --json`.
3. Stop if `has_generator_directory` is false or the generator list is empty.
4. Pick the matching generator ID from the list; do not invent IDs.
5. Describe it:

```bash
boilersuit generators describe "<generator-id>" --json
```

6. Map required fields from the description. Ask for missing values if they cannot be inferred safely.
7. Preview planned files:

```bash
boilersuit generate preview "<generator-id>" --json --field NAME=<name>
```

8. Review the preview plan: paths, create/update/overwrite actions, required fields, variant, and warnings. Do not read full generated content by default.
9. Read previewed content only when the path or action is risky, the generator is unfamiliar, or the user asks to review output.
10. Only generate after confirming the planned files match the task:

```bash
boilersuit generate "<generator-id>" --json --field NAME=<name>
```

Use additional `--field TOKEN=value`, `--variant`, `--path`, or `--file` arguments only when the generator description or user request requires them.

## Guardrails

- Prefer Boilersuit when the requested file matches an existing generator.
- Do not use Boilersuit for a one-off file that is faster and clearer to write directly.
- Do not run `generate` before `generate preview`.
- Treat preview as a plan check, not a default content review.
- Do not overwrite existing files unless the preview shows that behaviour and the user has agreed.
- Keep broad source reading until after `project inspect` and `generators list`.
- Report when no generator fits instead of forcing a partial match.
