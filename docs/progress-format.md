# Progress format

Canonical reference for the `progress` CLI data model and `.agent/tasks/` across projects. The `project-setup`, `project-plan-task`, `project-continue`, and `project-compact-progress` skills embed task-file templates that must stay in sync with this document. The CLI stores project state in SQLite; `PROGRESS.md` is freeform prose and is not its task-state store.

## Files

- `~/.agents/progress.db`: the default SQLite database used by `progress`; pass `--database PATH` to use another database
- `<project-root>/PROGRESS.md`: optional freeform backlog prose, such as "Upcoming work" or "Parking lot"; it is not parsed as task, queue, roadmap, note, or handoff state
- `<project-root>/.agent/tasks/<task-slug>.md`: one file per concrete task
- `<project-root>/.agent/specs/<feature>.md`: durable feature designs, unchanged by this contract

## Task files

### Naming

New task filenames use stable, descriptive kebab-case slugs such as `progress-format-parser.md`. The filename identifies the task; it does not encode priority or queue position. Choose a concise slug from the task's purpose and add a meaningful qualifier if another task already uses it.

Reordering work changes the ordered task and release records in the progress database. Do not rename task files when titles, priorities, or queue positions change. Refer to tasks by their human-facing title or path in prose, not by a positional number or bare filename stem. Existing numeric filenames are valid legacy input and must not be bulk-renamed or renumbered merely to adopt this convention. New tasks use descriptive slugs even when existing tasks are numeric. Task files do not prescribe branch names.

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
- `release` — a roadmap ID from the CLI's ordered release records. Omit for backlog tasks.
- `completed` — legacy date field, tolerated when present but not written by current task producers.

Front matter is the source of truth for status. An agent leaves a verified implementation `in-progress` until the user signals acceptance with “committed”, “continue”, “next”, or equivalent; it must not infer completion from Git state.

### Execution boundary

A task file owns a coherent feature or outcome and may contain several ordered commit sections. Each commit section has one reviewable outcome, coherent files, and focused verification. Create a separate task file only for independently schedulable feature work, decisions, dependencies, or release boundaries, not merely because the feature needs multiple commits.

Before marking a task `ready` or delegating it, name its one outcome and verification bundle. Split it when it combines independent public behaviours, packaging or release work, unrelated documentation, or separate review decisions. Keep documentation with the interface it explains rather than collecting it in a final sweep.

Plan each commit for human comprehension, with one primary question for the reviewer. Before accepting the plan, inventory its substantive concerns, such as data and state, interaction and accessibility, presentation states, framework integration, public API, and delivery documentation. Treat each as a candidate commit and combine them only when reviewing one without the other would be misleading.

Use three substantive files as a soft ceiling for one commit. A substantive file contains logic, tests, or prose the reviewer must understand; for example, an implementation file, its focused test, and its documentation are three substantive files. Small mechanical registration changes may take the count higher. Split a dense file across commits when it contains several behaviour slices. Broad outcomes such as `complete component`, `full public API`, or `all integration` fail this gate unless the underlying change is genuinely small.

An ordered task may use intermediate commits that are not complete features when each commit is internally consistent, has focused verification, and is not presented or released as complete. Unless project guidance explicitly requires the same commit, instructions to update tests, docs, metadata, and examples together mean within the same ordered review series before the feature is complete.

If a task needs more than one commit, add a `## Commit plan` before `## Tasks`. It is a checklist with one reviewable outcome per commit:

```markdown
## Commit plan

- [ ] Commit 1: reviewable outcome
- [ ] Commit 2: follow-up outcome
```

Do not leave the split implicit in prose elsewhere in the task, such as the Purpose. The commit-plan checklist records interim-commit acceptance, while `## Tasks` holds the detailed implementation steps. Begin with every entry unchecked. When work starts on the first unchecked entry, change the task from `ready` to `in-progress`. Tick an entry only after the user explicitly accepts that commit's handoff. `project-continue` resumes at the first unchecked entry and stops for review before the next.

A feature spec may describe a larger goal, investigation, or phase sequence. Its phases are not task boundaries by default: create the next concrete task only when its scope, acceptance criteria, and verification are independently reviewable.

### Clear planning language

Write task files, feature specs, chunk titles, and chunk descriptions for a reader who does not share the investigation context. Before marking a task `ready`:

- State the concrete problem before the proposed work.
- Use direct statements with a clear subject and action. Where shorthand could be ambiguous, name the actor, input, behaviour, and result.
- Keep one requirement, decision, recommendation, or question per bullet.
- Explain unfamiliar terms at first use, while preserving exact API names, paths, commands, standards, and platform terms.
- Keep confirmed requirements, recommended defaults, and unresolved questions visibly separate.
- Describe interactions explicitly, including ordering, filtering, focus, state composition, and failure or recovery behaviour where relevant.
- Write accessibility requirements and acceptance criteria as observable behaviour.
- Preserve edge cases, constraints, failure behaviour, verification requirements, and technical decisions when simplifying the wording.
- Make a task's `title`/`overview` and a chunk's title/description readable on their own: state what changed and why in plain words. Keep implementation detail, file paths, technique names, and discovery notes out of them; put those in `## Tasks`, `## Notes`, or a `discovery`/`decision` record instead. For example, write `fix the blank cell for dotted column IDs` / `the cell lookup fails when a column ID contains a dot`, not `treat column IDs as opaque configuration keys and build cells from configured columns`.

If clearer wording would require making a product or architecture decision, leave the requirement unresolved and mark the task `needs-decision` instead of guessing. A rewrite clarifies the existing contract; it does not change scope, behaviour, decisions, or evidence.

### Body

No `# Title` heading; front matter `title` is the single source. Sections, in order, optional ones marked:

```markdown
## Purpose

State the user, business, or operational problem being solved, who experiences it, and the observable result that would show the work succeeded. For routine maintenance, one concise sentence is enough.

## Contract              (required for public or user-visible work)

Public behaviour, data shape, UI states, or API surface affected.

The Contract is the stable “what”: observable outcomes, public behaviour, invariants, constraints, and relevant states, independent of tools. `## Tasks` and `## Verification` describe the workflow and evidence used to satisfy it. The task file remains a prospective execution contract: replace affected bullets only when a material decision changes the outcome, affected files, verification, status, or risk. Do not append a discovery or validation history. Skills own reusable task-type mechanics and tool routing; see `src/rules/skills-policy.md` for the skill-versus-rule split. Always-on rules retain only cross-cutting safety, authorisation, scope, and honesty invariants.

For public, user-visible, or behaviourally significant work, name only applicable failure and recovery states, such as loading, empty, denied, error, partial, stale, interrupted, or recovery. Keep the contract observable and invariant-focused, not implementation or testing steps; route accessibility, security, error-handling, and testing mechanics to specialist skills. Example: a UI flow might define loading, empty, denied, and error; an API or CLI flow might define partial, stale, interrupted, or recovery.

## Model tier          (optional)

## Files likely to change

## Related files to inspect   (optional)

## Spec                (optional; link to .agent/specs/<feature>.md)

## Commit plan         (required for multi-commit tasks)

- [ ] Commit 1: reviewable outcome
- [ ] Commit 2: follow-up outcome

## Tasks

- [ ] step

## Acceptance criteria

- Observable condition that proves the work is done

## Verification

Focused checks, manual review, or evidence required before handoff.

## Risks

## Open questions      (optional)

Unresolved decisions the user needs to weigh in on before implementation, kept next to the bullet they affect rather than restated elsewhere. Omit once resolved.

## Notes               (optional)

Durable execution constraints needed to resume the task. Do not use this as a running session log.

```

Step progress is the `- [ ]` / `- [x]` items under `## Tasks`. For multi-commit tasks, these are distinct from the `## Commit plan` checklist: task checkboxes track implementation detail, while commit-plan checkboxes track explicit user acceptance of each reviewable commit.

Order steps by how likely they are to change on review: decisions likely to be revisited, such as data model, public interface, or user-facing behaviour, come first; mechanical or plumbing steps (wiring, boilerplate, formatting) come last. This puts what's worth a second look before the routine work in the read order.

### Completion

After the user explicitly accepts a commit-plan handoff, tick that entry. If another entry remains unchecked, keep the task `in-progress` and resume there next. After the final entry is accepted, or after the user accepts a single-commit task:

1. Mark each accepted chunk `done` with the supported `progress chunk` command, then mark the task `done` with the supported `progress task` command when no pending or active chunks remain.
2. Update release and queue state through the progress CLI, including starting the next ready task when appropriate and refreshing handoff context with `progress context set`.
3. If the project removes completed task files, do so after the CLI records are complete. Do not use `PROGRESS.md` as a completion archive or queue.

## PROGRESS.md

`PROGRESS.md` is optional. Keep it at the project root when a project needs freeform backlog prose, such as an "Upcoming work" or "Parking lot" section. Write and read that prose directly. Do not put task status, active chunk, release roadmap, queue order, discoveries, decisions, or handoff context there; those records belong in the `progress` database.

### Session handoff

The CLI stores one handoff context record per project. It contains `current_goal`, `previous_step`, `next_step`, `standing_context`, `verify_with`, and `stop_marker`. Set it with `progress context set`; read it with `progress context get --json`. The session-start hook reads `progress next --json` for the current task and chunk. Do not recreate this context in `PROGRESS.md`.

## Roadmap

Releases are the ordered roadmap, stored in the CLI's `release` records rather than in `PROGRESS.md`. A release has an ID, slug, title, overview, status, and position. Its status is `planned`, `active`, or `done`; tasks can refer to a release ID. Use `progress release` commands to inspect and change releases instead of maintaining a roadmap table in `PROGRESS.md`.

## CLI data model

The database is scoped to the project bound to the current Git repository. Its data model has seven record types:

| Record      | Role                                                        | State or links                                                                                            |
| ----------- | ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `project`   | Identifies the current repository and project.              | Has a stable ID, slug, and name.                                                                          |
| `release`   | Groups related tasks in roadmap order.                      | `planned`, `active`, or `done`; tasks may refer to it.                                                    |
| `task`      | Stores one reviewable outcome and its planning fields.      | `ready`, `in-progress`, `blocked`, `needs-decision`, or `done`; may have dependencies, chunks, and notes. |
| `chunk`     | Stores one unit of work within a task.                      | `pending`, `active`, `done`, or `skipped`; at most one is active per task.                                |
| `discovery` | Stores a verified finding that helps future work.           | A note attached to the project and optionally a task.                                                     |
| `decision`  | Stores a decision and, when needed, the note it supersedes. | A note attached to the project and optionally a task.                                                     |
| `context`   | Stores the current handoff for one project.                 | One record per project, replaced by `progress context set`.                                               |

Use `progress next`, `progress context get`, and `progress ready` for bounded read surfaces. Use `progress --help`, then `progress <noun> --help`, for the exact command and flag syntax. Use `--json` when another tool or hook needs the stable agent response envelope. The active task is the project's single `in-progress` task. Its active chunk is the next unit of work. `progress next --json` returns that task and chunk; `progress ready --json` lists tasks whose dependencies allow them to start. Task position, release position, dependency edges, and lifecycle status are stored in the database, so no queue table is needed in `PROGRESS.md`.

## Tolerance

The CLI database is authoritative for project state. Missing or uninitialised project bindings are reported as explicit errors, so agents can fall back to `WORKSPACE.md`, `AGENTS.md`, package scripts, and nearby docs without guessing. `PROGRESS.md` may be absent because its freeform backlog prose is outside the CLI data model. Task-file consumers remain tolerant of numeric legacy filenames, missing sections, legacy heading-based task files (`## Status` / `## Depends on`), or absent front matter; producers always write the current task-file contract.
