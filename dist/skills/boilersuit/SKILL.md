---
# Generated — edit skill.json and SKILL.body.md instead.
name: boilersuit
description: >
  Use this skill when consuming an existing Boilersuit generator to create repeatable project files. Covers inspecting project support, listing and describing generators, previewing the complete planned file set, handling existing destinations, and generating only after preview.
do-not-use-when:
  - Creating or editing a generator definition; use boilersuit-generator-authoring
  - Creating a one-off bespoke file where a generator would add overhead
  - Editing existing code without adding a repeatable structure
  - The project has no Boilersuit generators and no boilerplate setup task
---
# Boilersuit

Use existing Boilersuit generators for repeatable project structures, not bespoke one-off files. Use `boilersuit-generator-authoring` when creating or changing a generator definition.

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

If command prints `LLVM Profile Error: Failed to write file "default.profraw"`, rerun with profile output in `/tmp`:

```bash
env LLVM_PROFILE_FILE=/tmp/boilersuit-%p.profraw boilersuit project inspect --json
```

## Command forms

`<project-path>` optional; omitted means current directory.

```bash
boilersuit project inspect [<project-path>] --json
boilersuit generators list [<project-path>] --json
boilersuit generators describe [<project-path>] <generator-id> --json
boilersuit generators doctor [<project-path>] [<generator-id>] --json [--field TOKEN=value] [--variant id]
boilersuit generate preview [<project-path>] <generator-id> --json [--field TOKEN=value] [--variant id] [--path path] [--skip-existing]
boilersuit generate [<project-path>] <generator-id> --field TOKEN=value --json [--variant id] [--path path] [--skip-existing]
boilersuit project open [<project-path>] (--editor | --terminal | --file-manager) --json
```

Opening editor, terminal, or file manager may need sandbox approval.

## Generator path model

- `default_path` is base output directory, not token-rendered file path.
- `files[].output_path` renders field tokens and may include directories.
- If `output_path` has no directory, Boilersuit writes into `<default_path>/<NAME | kebab>/`.
- If `output_path` includes directories, it owns generated subdirectories; Boilersuit does not add name folder.
- For flat files under a tokenised directory, set `default_path` to `""` and put the full path in each `output_path`, e.g. `lib/{{ CATEGORY }}/{{ NAME | kebab }}.js`.
- Use `--path` only to override/prefix base path; always preview because explicit `output_path` directories can make final path differ from naive base-plus-file join.
- CLI generation uses the complete visible file set. Variants define alternative output shapes; individual template selection is not supported.

## Generation workflow

1. Run `boilersuit project inspect --json`.
2. Run `boilersuit generators list --json`.
3. Stop if `has_generator_directory` is false or the generator list is empty.
4. Pick matching generator ID from list; do not invent IDs.
5. Describe it:

```bash
boilersuit generators describe "<generator-id>" --json
```

6. Map required fields from description. Ask for missing values if unsafe to infer.
7. Run doctor with the same representative fields and variant:

```bash
boilersuit generators doctor "<generator-id>" --json --field NAME=<name>
```

Resolve errors before continuing. Review warnings. Supply missing representative fields when checks are deferred.

8. Preview planned files:

```bash
boilersuit generate preview "<generator-id>" --json --field NAME=<name>
```

9. Review every file action and path. `create` writes a file; `skip_existing` is only returned when `--skip-existing` was requested. Do not read full generated content by default.
10. Read previewed content only when path/action is risky, generator unfamiliar, or user asks.
11. Only generate after confirming the planned files match the task:

```bash
boilersuit generate "<generator-id>" --json --field NAME=<name>
```

Use extra `--field TOKEN=value`, `--variant`, or `--path` only when the generator description or user request requires it. Use `--skip-existing` only when existing destinations should remain untouched and the preview lists every intended skip.

## Guardrails

- Prefer Boilersuit when the requested file matches an existing generator.
- Do not use Boilersuit for one-off file faster and clearer to write directly.
- Do not run `generate` before `generate preview`.
- Do not use removed `--file` or invent per-template selection flags.
- Treat preview as a plan check, not a default content review.
- Existing destinations fail safely by default. Do not use `--skip-existing` unless the user expects a partial result.
- Keep broad source reading until after `project inspect` and `generators list`.
- Report when no generator fits instead of forcing a partial match.
