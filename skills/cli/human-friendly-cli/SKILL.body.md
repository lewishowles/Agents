# Human-friendly CLI

Design the normal CLI for people first: clear, structured, restrained, discoverable, and predictable. Those same qualities make the CLI reliable for agents.

## Core contract

After loading this skill, design or review CLI changes against this invariant:

> A user who has never seen the command can discover the available actions, valid values, likely next step, and failure reason without reading source.

## Command shape

- Prefer explicit subcommands and flags over free-form payloads.
- Keep command names stable, short, and verb-led: `list`, `info`, `describe`, `preview`, `doctor`, `snippet`, `pattern`, `generate`.
- Use enum-like flag values where possible, and list valid values in help and errors.
- Prefer repeated flags or named fields for structured input: `--field NAME=value`, `--variant compact`.
- Avoid JSON as the primary input format when shell quoting would be part of the common path.
- Offer `--json` for output when automation needs structure.
- Include `--dry-run`, `preview`, or `doctor` when a command can write files, mutate state, or fail late.

## Discovery

Every non-trivial CLI should let users answer these questions through commands:

- What can this tool do?
- What options exist for this command?
- What valid names, IDs, variants, or examples are available?
- What will happen before anything is written?
- What went wrong, and what exact command should I try next?

Useful discovery commands:

```sh
tool --help
tool <command> --help
tool list
tool info <name>
tool describe <name>
tool preview <name> --field NAME=value
tool doctor <name>
```

## Help text

- Show the common path first.
- Include one realistic copyable example per command.
- Keep examples shell-safe: avoid nested quoting and multiline JSON in the primary example.
- Mention defaults, required fields, repeatable flags, and valid enum values.
- Explain output modes briefly: human output by default, `--json` for structured output.
- If a command has interactive and non-interactive modes, document both.

## Output

- Human output should be readable, scan-friendly, and restrained.
- Use headings, tables, status rows, and short panels where they clarify structure.
- Keep success output focused on what changed or what to do next.
- Keep errors specific: name the invalid value, show the valid alternatives, and include the corrected command shape.
- Do not use colour as the only signal.
- Avoid noisy banners, decorative output, or repeated explanatory prose.

## `@lewishowles/cli-style`

CLI projects should use `@lewishowles/cli-style` for terminal output unless a project constraint makes that impossible. Do not hand-roll ANSI codes, tables, panels, status rows, colour handling, or terminal capability detection.

Use these patterns:

```js
import { createCliStyle } from "@lewishowles/cli-style";

const ui = createCliStyle({ argv, env, stdout });
```

- Construct the `ui` instance once at the entrypoint.
- Thread `ui` through command handlers and lower-level functions that print.
- Use library helpers for colour, tables, panels, status rows, and cancellation.
- Keep colour optional and compatible with non-TTY output.
- Inject `argv`, `env`, and `stdout` explicitly when tests need deterministic output.

## Agent use follows human use

Do not create a separate agent-only CLI unless the normal CLI cannot reasonably expose the same action.

Prefer:

- constrained commands over open-ended prompts
- `--help` and `list` over source searching
- `preview` and `doctor` over trial-and-error generation
- structured output via `--json`, not structured input via shell-hostile JSON payloads

Before adding an agent mode, test whether the normal CLI can be made clearer for humans instead.
