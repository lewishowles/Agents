# Boilersuit

Use Boilersuit for repeatable project structures, not bespoke one-off files. Inspect project before broad reading or guessing generator names.

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
boilersuit generate preview [<project-path>] <generator-id> --json [--field TOKEN=value] [--variant id] [--path path] [--file template]
boilersuit generate [<project-path>] <generator-id> --field TOKEN=value --json [--variant id] [--path path] [--file template]
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
7. Preview planned files:

```bash
boilersuit generate preview "<generator-id>" --json --field NAME=<name>
```

8. Review preview plan: paths, create/update/overwrite actions, required fields, variant, warnings. Do not read full generated content by default.
9. Read previewed content only when path/action is risky, generator unfamiliar, or user asks.
10. Only generate after confirming the planned files match the task:

```bash
boilersuit generate "<generator-id>" --json --field NAME=<name>
```

Use extra `--field TOKEN=value`, `--variant`, `--path`, or `--file` only when generator description/user request requires.

## Guardrails

- Prefer Boilersuit when the requested file matches an existing generator.
- Do not use Boilersuit for one-off file faster and clearer to write directly.
- Do not run `generate` before `generate preview`.
- Treat preview as a plan check, not a default content review.
- Do not overwrite files unless preview shows it and user agreed.
- Keep broad source reading until after `project inspect` and `generators list`.
- Report when no generator fits instead of forcing a partial match.
