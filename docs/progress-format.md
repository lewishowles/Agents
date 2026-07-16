# Progress format

Canonical contract for `PROGRESS.md` and `.agent/tasks/` across projects. The `project-setup`, `project-plan-task`, `project-continue`, and `project-compact-progress` skills embed working templates that must stay in sync with this document. External consumers (Boilersuit's progress surface, `boilersuit progress`) parse and write against this contract.

## Files

- `<project-root>/PROGRESS.md` — session handoff, roadmap, queue, decisions, discoveries.
- `<project-root>/.agent/tasks/NNN.md` — one file per concrete task.
- `<project-root>/.agent/specs/<feature>.md` — durable feature designs, unchanged by this contract.

## Task files

### Naming

Filenames are three-digit IDs: `001.md`, `002.md`. Allocate the next ID as max existing + 1 (including done files); never reuse an ID. Filenames carry no meaning; the human-facing name lives in front matter. Task files do not prescribe branch names.

### Front matter

Front matter is a deliberately flat subset of YAML so consumers never need a YAML library: plain `key: value` pairs, values treated as strings, inline `[a, b]` lists, no nesting, no quoting, unknown keys ignored.

```yaml
---
title: Human-readable task name
overview: One or two sentences reminding a human what this task is and why it exists.
status: ready
depends: []
release: phase-5
completed:
---
```

- `title` — display name for lists and cards.
- `overview` — the at-a-glance reminder; one or two sentences.
- `status` — `ready`, `in-progress`, `blocked`, `needs-decision`, or `done`. Use `needs-decision` when an open risk needs the user's input before an agent should implement; don't resolve it by guessing. Use `blocked` for external blocks; blocking by another task is expressed through `depends` instead.
- `depends` — task IDs that must land first, e.g. `[001, 003]`, or `[]`. Most queued tasks are independent unless this says otherwise.
- `release` — a roadmap ID from the `## Roadmap` table. Omit for backlog tasks.
- `completed` — date (`YYYY-MM-DD`), set when status becomes `done`, otherwise left empty.

Front matter is the source of truth for status. An agent leaves a verified implementation `in-progress` until the user signals acceptance with “committed”, “continue”, “next”, or equivalent; it must not infer completion from Git state. Inline annotations elsewhere (the upcoming queue) are convenience and may lag.

### Body

No `# Title` heading; front matter `title` is the single source. Sections, in order, optional ones marked:

```markdown
## Purpose

## Contract              (required for public or user-visible work)

Public behaviour, data shape, UI states, or API surface affected.

## Model tier          (optional)

## Files likely to change

## Related files to inspect   (optional)

## Spec                (optional; link to .agent/specs/<feature>.md)

## Tasks

- [ ] step

## Acceptance criteria

- Observable condition that proves the work is done

## Verification

Focused checks, manual review, or evidence required before handoff.

## Risks

## Notes               (optional)

## Outcome             (appended at completion)
```

Step progress is the `- [ ]` / `- [x]` items under `## Tasks`.

### Completion

After the user signals acceptance, keep the file:

1. Set `status: done` and `completed: <date>` in front matter.
2. Append a short `## Outcome` section: what landed, how it was verified.
3. Remove the task from the upcoming queue in `PROGRESS.md` and promote the next entry into the active slot.

Done task files are the historical record, replacing most per-task `## Archived milestones` prose. When every task file in `.agent/tasks/` is done, the folder may be bulk-cleaned (a deliberate user or agent action, never automatic).

## PROGRESS.md

### Session handoff

Unchanged from the handoff-first convention: `## Session handoff` first (current goal, active task link, previous/next step, standing context, verify with, stop marker). Verify the active task's front matter before starting it rather than trusting the handoff alone. `git status --short` is a separate safety check before editing, and does not change progress status.

### Roadmap

One canonical table. Row order is the timeline; `ID` is what task `release:` fields reference.

```markdown
## Roadmap

| ID      | Title                  | Overview                                              | Status |
| ------- | ---------------------- | ----------------------------------------------------- | ------ |
| phase-5 | MCP automation surface | In-process MCP server mirroring the CLI JSON contract | active |
| phase-6 | Generator app health   | Doctor results, empty states, create-generator flows  |        |
```

`Status` is `planned` (or blank), `active`, or `done`. Anything needing more than a sentence of overview gets a spec, not a longer cell.

### Upcoming queue

Numbered list under the session handoff, non-done tasks only, priority order:

```markdown
1. [001 — Progress format parser service](.agent/tasks/001.md) — ready
2. [002 — Progress CLI command](.agent/tasks/002.md) — ready, depends on 001
```

The inline status annotation is a convenience so agents can pick work without opening every file; front matter wins on conflict, and drift is a doctor finding, not a parse error.

## Tolerance

Consumers parse tolerantly: missing sections, legacy heading-based task files (`## Status` / `## Depends on`), or absent front matter degrade to partial results plus warnings, never errors. Producers (skills, agents) always write the full contract.
