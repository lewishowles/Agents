# Boilersuit generator authoring

Create or edit project-owned generators using the installed Boilersuit CLI as the authoritative contract. Do not rely on remembered field types, filters, schema properties, or path behaviour.

Boilersuit generators are project-agnostic. Follow the target project's conventions; do not assume Vue, JavaScript, `src/components`, or a `NAME` field unless the proposed generator requires them.

## Prerequisites

Confirm the CLI and authoring commands are available:

```bash
command -v boilersuit
boilersuit generators contract --help
boilersuit generators doctor --help
```

If either command is unavailable, stop and report that the installed Boilersuit CLI must be updated. Do not reconstruct the schema from this skill.

If a command prints `LLVM Profile Error: Failed to write file "default.profraw"`, rerun it with:

```bash
env LLVM_PROFILE_FILE=/tmp/boilersuit-%p.profraw boilersuit <arguments>
```

## Source of truth

Load the current contract before planning or editing:

```bash
boilersuit generators contract --json
```

Use its structured output for:

- Supported schema versions and properties
- Required and optional fields
- Field types, defaults, validation, and select options
- File conditions and variants
- Placeholder, alias, conditional, and filter syntax
- Output-path behaviour and limitations
- Valid basic and advanced examples

The current implementation includes `pascal`, `kebab`, `camel`, `snake`, `constant`, `upper`, and `lower`. Verify this against the loaded contract rather than relying on the list here; if they differ, the installed CLI wins and the mismatch must be reported.

Do not copy other contract details into the skill or assume a previous project uses the current contract.

## Project contract boundaries

Treat the installed `boilersuit` CLI as the agent automation contract for generator discovery, validation, preview, path resolution, collision handling, and generation. Use command help when an option or response shape is unclear.

Run profiles are a separate project-owned capability:

- Explicit profiles live in `.boilersuit/run.json`
- Boilersuit also infers profiles from `package.json` scripts
- Explicit profiles take precedence when IDs overlap

Do not add or change Run profiles as a side effect of generator authoring. If the requested generator pack also needs Run profiles, plan and review that as a separate project change.

## Authoring workflow

### 1. Inspect the target project

```bash
boilersuit project inspect --json
boilersuit generators list --json
```

Inspect nearby project conventions and existing generators only as needed. Generator files live under:

```text
.boilersuit/generators/<generator-id>/
├── generator.json
└── native template files
```

Template files keep their normal extensions; do not add a `.tpl` suffix.

### 2. Design before writing

Present a concise proposal for review:

- Generator ID, display name, purpose, and default path
- Fields and why each value is needed
- Files and final path patterns
- Variants, only where they represent meaningful alternative output shapes
- Conditions and mapped option tokens
- Required representative values for doctor and preview

Keep the generator to the smallest complete shape. Do not add speculative fields, variants, templates, or flexibility.

### 3. Write the generator

After approval, create or edit `generator.json` and its native template files using the current contract. Every referenced template must exist. Every token used in template content, output paths, and conditions must be declared by a field or mapped select option.

CLI generation always uses the complete visible file set. Use variants for alternative output shapes; do not invent per-template selection.

### 4. Run doctor before debugging preview

Run doctor with representative values for every value-dependent path and condition:

```bash
boilersuit generators doctor "<generator-id>" --json \
	--field NAME=example-name
```

Add repeated `--field TOKEN=value` and `--variant id` as required.

- Resolve every error
- Review every warning
- Supply values needed by deferred checks
- Re-run only after a change that can affect the result

Use `--fail-on-warning` for CI or strict agent verification.

### 5. Preview the complete result

```bash
boilersuit generate preview "<generator-id>" --json \
	--field NAME=example-name
```

Check:

- Every output path
- Every `create` or `skip_existing` action
- Missing tokens and warnings
- Variant and field values
- The complete visible file set

Do not read all rendered content by default. Inspect content when the generator is unfamiliar, placeholder placement is risky, or the user asks.

### 6. Generate only when requested

Authoring and validating a generator does not imply generating an example into the project. Run generation only when the user asks:

```bash
boilersuit generate "<generator-id>" --json \
	--field NAME=example-name
```

Use `--skip-existing` only when a partial result is intended and preview shows every existing destination that will remain unchanged.

## Guardrails

- Contract first; never author from remembered schema details
- Design review before file edits
- Doctor before preview
- Preview before generation
- No removed `--file` or invented `--only` option
- No silent unresolved tokens, missing templates, or ignored doctor errors
- No arbitrary post-generation shell commands
- No overwriting existing files
- Report when a requested behaviour is not supported by the current contract

## Completion

Report:

- Generator directory and templates created or changed
- Doctor result and representative fields used
- Previewed paths and actions
- Whether example files were generated
- Any warnings, deferred checks, or unsupported requirements that remain
