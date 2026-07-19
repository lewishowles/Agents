# Progress format

Canonical contract for `PROGRESS.md` and `.agent/tasks/` across projects. The `project-setup`, `project-plan-task`, `project-continue`, and `project-compact-progress` skills embed working templates that must stay in sync with this document. External consumers (Boilersuit's progress surface, `boilersuit progress`) parse and write against this contract.

## Files

- `<project-root>/PROGRESS.md` — session handoff, roadmap, queue, decisions, discoveries.
- `<project-root>/.agent/tasks/<task-slug>.md` — one file per concrete task.
- `<project-root>/.agent/specs/<feature>.md` — durable feature designs, unchanged by this contract.

## Task files

### Naming

New task filenames use stable, descriptive kebab-case slugs such as `progress-format-parser.md`. The filename identifies the task; it does not encode priority or queue position. Choose a concise slug from the task's purpose and add a meaningful qualifier if another task already uses it.

Reordering work changes only the physical order of links in `### Upcoming queue`. Do not rename task files when titles, priorities, or queue positions change. Refer to tasks by their human-facing title or path in prose, not by a positional number or bare filename stem. Existing numeric filenames are valid legacy input and must not be bulk-renamed or renumbered merely to adopt this convention. New tasks use descriptive slugs even when existing tasks are numeric. Task files do not prescribe branch names.

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
- `depends` — task filename stems that must land first, e.g. `[progress-format-parser, metadata-validation]`, or `[]`. Use it only for real prerequisites; queue order already expresses the intended sequence. Legacy numeric stems remain valid references to existing numeric task files.
- `release` — a roadmap ID from the `## Roadmap` table. Omit for backlog tasks.
- `completed` — date (`YYYY-MM-DD`), set when status becomes `done`, otherwise left empty.

Front matter is the source of truth for status. An agent leaves a verified implementation `in-progress` until the user signals acceptance with “committed”, “continue”, “next”, or equivalent; it must not infer completion from Git state. Inline annotations elsewhere (the upcoming queue) are convenience and may lag.

### Body

No `# Title` heading; front matter `title` is the single source. Sections, in order, optional ones marked:

```markdown
## Purpose

## Contract              (required for public or user-visible work)

Public behaviour, data shape, UI states, or API surface affected.

The Contract is the stable “what”: observable outcomes, public behaviour, invariants, constraints, and relevant states, independent of tools. `## Tasks` and `## Verification` describe the workflow and evidence used to satisfy it. Skills own reusable task-type mechanics and tool routing; see `rules/skills-policy.md` for the skill-versus-rule split. Always-on rules retain only cross-cutting safety, authorisation, scope, and honesty invariants.

For public, user-visible, or behaviourally significant work, name only applicable failure and recovery states, such as loading, empty, denied, error, partial, stale, interrupted, or recovery. Keep the contract observable and invariant-focused, not implementation or testing steps; route accessibility, security, error-handling, and testing mechanics to specialist skills. Example: a UI flow might define loading, empty, denied, and error; an API or CLI flow might define partial, stale, interrupted, or recovery.

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

After the user signals acceptance:

1. Append a short `## Outcome` section to the task file: what landed, how it was verified.
2. Condense that outcome into a one-line, dated entry in `PROGRESS.md`'s `## Archived milestones`.
3. Delete the task file.
4. Remove the task from the upcoming queue in `PROGRESS.md` and promote the next entry into the active slot.

`## Archived milestones` is the sole historical record, and it is release-scoped, not permanent: once a roadmap release's Status is `done` and the release has shipped, remove its milestone entries too.

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

Bulleted list under the session handoff, non-done tasks only. Physical order is priority and the intended pickup sequence:

```markdown
- [Progress format parser service](.agent/tasks/progress-format-parser.md) (ready)
- [Progress CLI command](.agent/tasks/progress-cli-command.md) (ready; depends on `progress-format-parser`)
```

The inline status annotation is a convenience so agents can pick work without opening every file; front matter wins on conflict, and drift is a doctor finding, not a parse error.

## Tolerance

Consumers parse tolerantly: numeric legacy task filenames, numbered legacy queues, missing sections, legacy heading-based task files (`## Status` / `## Depends on`), or absent front matter degrade to partial results plus warnings, never errors. Producers (skills, agents) always write the current contract.
