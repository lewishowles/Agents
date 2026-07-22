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
---
```

- `title` — display name for lists and cards.
- `overview` — the at-a-glance reminder; one or two sentences.
- `status` — `ready`, `in-progress`, `blocked`, or `needs-decision`. Use `needs-decision` when an open risk needs the user's input before an agent should implement; don't resolve it by guessing. Use `blocked` when the task isn't actionable yet, whether from an external block or an unresolved prerequisite listed in `depends` — the task file explains which, so the queue never needs to enumerate it. `ready` means actionable now: well-specified, with no unresolved `depends`. `done` is tolerated only in legacy task files that were left mid-archive.
- `depends` — task filename stems that must land first, e.g. `[progress-format-parser, metadata-validation]`, or `[]`. Use it only for real prerequisites; queue order already expresses the intended sequence. A non-empty, unresolved `depends` means `status` should be `blocked`, not `ready`. Legacy numeric stems remain valid references to existing numeric task files.
- `release` — a roadmap ID from the `## Roadmap` table. Omit for backlog tasks.
- `completed` — legacy date field, tolerated when present but not written by current task producers.

Front matter is the source of truth for status. An agent leaves a verified implementation `in-progress` until the user signals acceptance with “committed”, “continue”, “next”, or equivalent; it must not infer completion from Git state. Inline annotations elsewhere (the upcoming queue) are convenience and may lag.

### Body

No `# Title` heading; front matter `title` is the single source. Sections, in order, optional ones marked:

```markdown
## Purpose

## Contract              (required for public or user-visible work)

Public behaviour, data shape, UI states, or API surface affected.

The Contract is the stable “what”: observable outcomes, public behaviour, invariants, constraints, and relevant states, independent of tools. `## Tasks` and `## Verification` describe the workflow and evidence used to satisfy it. Skills own reusable task-type mechanics and tool routing; see `src/rules/skills-policy.md` for the skill-versus-rule split. Always-on rules retain only cross-cutting safety, authorisation, scope, and honesty invariants.

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

```

Step progress is the `- [ ]` / `- [x]` items under `## Tasks`.

### Completion

After the user signals acceptance:

1. Add a one-line, dated outcome to `PROGRESS.md`'s `## Archived milestones`: what landed and how it was verified.
2. Remove the task from the upcoming queue and promote the next entry into the active slot.
3. Trash the task file after the `PROGRESS.md` update is complete.

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

Table under the session handoff, non-done tasks only. Rows are grouped by Release, in roadmap order; within a release, physical row order is priority and the intended pickup sequence. A flat priority order across releases is harder to scan than the Release column suggests — group first, then order within the group:

```markdown
| Task | Release | Status |
| --- | --- | --- |
| [Progress format parser service](.agent/tasks/progress-format-parser.md) | phase-5 | ready |
| [Progress CLI command](.agent/tasks/progress-cli-command.md) | phase-5 | blocked |
```

Release and Status are a convenience so agents (and external consumers like Boilersuit's progress surface) can group, skim pickability, and reorder without opening every file; front matter wins on conflict, and drift is a doctor finding, not a parse error. A `blocked` row does not enumerate what it is waiting on — that can be a long list once a task has several prerequisites, and it is already recorded in the task file's `depends`. Reordering rows or moving a task to a different release ID (rewriting its `release:` front matter) is how a consumer like Boilersuit re-plans the queue; it never needs a duplicate release marker inside the row text itself.

## Tolerance

Consumers parse tolerantly: numeric legacy task filenames, numbered legacy queues, a legacy bulleted queue (a title link to a task file, followed by `(status; depends on ...)`), missing sections, legacy heading-based task files (`## Status` / `## Depends on`), or absent front matter degrade to partial results plus warnings, never errors. Producers (skills, agents) always write the current contract.
