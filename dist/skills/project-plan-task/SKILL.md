---
# Generated — edit skill.json and SKILL.body.md instead.
name: project-plan-task
displayName: Project plan task
description: >
  Use this skill to introduce new work into an existing plan — discusses requirements and inserts a new section at the appropriate location, not simply at the end.
---
# Project plan task

Add new work to existing plan. Insert where it belongs, not necessarily at the end; reorganise future sections when understanding changed.

## File location

`PROGRESS.md` lives at **project root**, not `.claude/`. Look for `<project-root>/PROGRESS.md` first.

## Workspace file

Use `<project-root>/WORKSPACE.md` when present to choose verification commands, generated outputs, expensive checks, forbidden operations, and progress locations.

When `<project-root>/.agent/scripts/project-diagnostics.py` exists, prefer `--check <name>` in `Verify with` over raw package scripts. Use `--list` for names; `--all` only when section needs broad verification and user agrees.

Do not generate a missing workspace file. If missing, inspect `AGENTS.md`, package scripts, nearby docs. Mention this command if workspace context would materially improve the plan:

```sh
agents:workspace --write
```

Run only when user asks and it exists in current shell.

## Workflow

1. **Discuss** — identify all known decision-blocking questions about requirements, scope, and dependencies, then ask them together before editing `PROGRESS.md`. Do not cap this initial set. Ask further questions only when an answer reveals a material new unknown.
   - For ambiguous or consequential work, group questions by dependency. In each round, ask every question whose prerequisites are settled, give a recommended default, then reassess after the reply. Do not ask downstream questions that assume an answer still open.
2. **Risk triage** (opt-in) — identify high-risk files before planning:
   - **Git churn**: `git log --oneline --since="1 month ago" -- <path> | wc -l` — high recent change = defect-prone
   - **Complexity**: large files or high function counts (use a targeted symbol or file measure)
   - **Fan-in**: high caller count = high blast radius (use Serena for an exact symbol, or codebase-memory for a broad multi-hop impact question)
   - Flag files high on two+ signals in **Risks**
   - Skip for routine/single-file/familiar work
3. **Locate** — identify placement relative to upcoming sections
4. **Approach exploration** (opt-in) — for complex tasks, surface 2–3 approaches with tradeoffs; wait for user choice before writing. Skip single-file, obvious, or decided work. Present options first, write after confirmation.
5. **Reorganise** — if new work changes later needs, update upcoming sections
6. **Insert** — add section: purpose, model tier, files likely to change, tasks, risks, notes. Order Tasks steps decisions-first, mechanical-last (see `docs/progress-format.md`)
7. **Review checkpoint** — for a task file, don't duplicate or summarise it in chat; point to it and invite comments. The user quotes a passage to challenge it or answers an inline `## Open questions` entry. Put any decision the agent can't resolve inline in the file, next to the bullet it affects, not in a separate chat summary. When the user replies, re-read only the cited section before patching, report what changed, and wait for approval before implementing. Trivial inline `PROGRESS.md` sections are short enough to show directly instead.
8. **Update parking lot** — move related ideas into new section or leave parked

## Planning for learning

For non-routine or consequential work, establish only the prompts that apply:

- Problem, beneficiary, and observable success condition
- Assumption with the highest cost if wrong, and the earliest evidence that can test it
- For a deadline, whether date or scope is fixed, plus the first work that may be de-scoped
- Smallest usable end-to-end path, including deliberate manual steps
- For production-affecting work, deployment, observation, support, and reversal needs

## Cross-repo work

When a task may span more than one repository, make the repo boundary explicit before adding it to the plan. This gives us most of the coordination benefit of a synthetic monorepo without requiring a hosted tool or account.

Capture these facts in the section, task file, or linked spec:

- **Main repo**: where the parent task should run and where most local commands apply
- **Auxiliary repos**: repos needed for read-only context, implementation, generated output, examples, or downstream validation
- **Relationship**: package consumer, API client, generated-output consumer, documentation/example repo, CI dependency, or release baseline
- **Permission boundary**: do not clone, add, edit, push, open PRs, or run remote/networked commands in another repo without explicit user approval
- **Validation owner**: which repo's diagnostics prove the change, including any downstream checks required before release
- **Handoff references**: PR links, task or session IDs, diagnostic log paths, and repo-specific risks

For broad dependency questions, start with local evidence and apply the `code-lookup` routing skill before choosing Serena, codebase-memory, or targeted search. If the affected repo set is still unclear, mark the task `needs-decision` and ask before expanding the working set.

## Placement principles

- Insert before upcoming sections if this work is a prerequisite
- Order by dependency, not arrival
- Each active section is an execution boundary
- For a multi-commit task, add a `## Commit plan` checklist using `- [ ] Commit N: outcome`; do only the first unchecked entry unless the user asks for all
- After one section, stop for review: changed files, verification, commit message
- Do not combine release, policy, tooling, docs, roadmap into one working-tree change unless explicitly one commit

### Task-boundary gate

A task file owns a coherent feature or outcome and may contain several ordered commit sections. Each commit section has one reviewable outcome, coherent files, and focused verification. Create a separate task file only for independently schedulable feature work, decisions, dependencies, or release boundaries, not merely because the feature needs multiple commits.

Before creating or delegating a task, confirm it has one coherent change surface and one verification bundle. Several files are fine when they jointly deliver that outcome.

Split the task when it would need separate review decisions for public behaviour, packaging or release work, documentation unrelated to the changed interface, or another independently verifiable outcome. Keep documentation with the interface it explains, rather than as a final sweep.

A feature spec can cover a larger goal or implementation phase. Do not copy its phase boundaries into task files automatically: create the next task only when its scope, acceptance criteria, and verification can stand alone.

For a multi-commit task, add `## Commit plan` before `## Tasks`. Each entry has the exact form `- [ ] Commit N: reviewable outcome`. It tracks interim-commit acceptance, not implementation work: keep detailed steps under `## Tasks`. When implementation starts, change the task from `ready` to `in-progress`. Tick a commit-plan entry only after the user explicitly accepts that commit's handoff; the next pickup starts at the first unchecked entry.

### Planning-quality gate

Before implementation or delegation, self-check any substantive task file against: repository truth, contract, boundary, altitude, failure and recovery states, acceptance evidence, and verification. Keep a strong task unchanged; correct only what the evidence supports. Invoke `project-review-task` explicitly for a high-risk or high-ambiguity task, or once a genuine second reviewer (a different model or peer) is available — a solo run by the same model that wrote the plan does not replace an independent check.

Apply the clear planning language gate from `docs/progress-format.md` to task files, inline `PROGRESS.md` entries, and feature specs. Write for a reader who does not share the investigation context: state the problem first, use direct statements with a clear subject and action, keep one requirement, decision, recommendation, or question per bullet, explain unfamiliar terms, separate confirmed requirements from recommended defaults and unresolved questions, and make acceptance criteria observable. Preserve exact APIs, paths, commands, edge cases, constraints, failure behaviour, verification requirements, and technical decisions. If clarification would require a new product or architecture decision, leave it unresolved and use `needs-decision` instead of guessing.

## Feature specs

For larger spikes or ambiguous features, create/reference a per-feature spec under `.agent/specs/` instead of expanding `PROGRESS.md` with design history. Keep `PROGRESS.md` focused on execution state and add `### Spec` link in relevant section. Do not create specs for small changes, direct bug fixes, routine docs edits, or work fitting one progress section.

Spec explains why now, problem, goals, current status (optional), non-goals, approach, entry point and files to inspect (optional), API/schema/interface changes, decisions and open questions (optional), acceptance criteria, risks, and verification. Read/update only when working on that feature. Full outline lives in the `project-setup` skill's "Feature specs" section — keep in sync if either changes.

## Task files vs progress sections

Once a plan has more than the current one or two active items, or the work needs a decision from the user before it can proceed, prefer a standalone file under `.agent/tasks/<task-slug>.md` over an inline `PROGRESS.md` section for concrete, ready-to-pick-up work. This keeps the read surface small: the next agent opens only the active task's file, not the whole plan. Inline sections are for genuinely trivial work only; anything that would need an `## Open questions` entry belongs in a task file, not inline. The canonical contract is `docs/progress-format.md` in the Configuration/Agents repo — keep this skill's template in sync with it.

New task filenames use stable, descriptive kebab-case slugs such as `repair-cli-help.md`. The filename identifies the task, not its priority or queue position. Choose a concise slug from the task's purpose and add a meaningful qualifier on collision. The human-facing name lives in front matter `title`; task files do not prescribe branch names.

Reordering work moves only queue entries. Never rename task files because their title, priority, or position changed, and never renumber or bulk-rename legacy numeric files merely to adopt the current convention. New tasks use descriptive slugs even in a folder containing numeric legacy tasks. Refer to tasks by title or path in user-facing prose, not by a positional number or bare filename stem.

Task files are complete agent-facing contracts, not labels such as “implement form file”. They describe the work still to do and the durable constraints needed to resume it, not a running record of discovery or validation. For public, user-visible, or behaviourally significant work, fill in the contract, acceptance criteria, and verification sections so an agent can implement and check the task without asking the user to restate it.

`PROGRESS.md`'s session handoff then holds only: a link to the active task file, the upcoming queue (a `Task | Release | Status` table, non-done tasks only, rows grouped by Release in roadmap order with priority as the order within each group), and standing context that doesn't change per task (verification commands, recurring gotchas). Backlog items with no concrete task file yet stay as prose bullets elsewhere in `PROGRESS.md` (with a spec link if one exists) — do not create a task file until the item is genuinely next; write it just-in-time.

Release boundaries live in one `## Roadmap` table (`ID | Title | Overview | Status`, row order is the timeline; Status is `planned`/blank, `active`, or `done`). A task's `release:` front matter references a roadmap ID; omit it for backlog tasks.

Placement follows the same principle as section order: when inserting new work, if it's the immediate next task, write or update the active task file directly; if it's later in the queue, add a new task file and insert its link into the queue list in dependency order, not at the end.

After the user signals acceptance with “committed”, “continue”, “next”, or equivalent: add what changed and how it was verified as a one-line, dated entry in `PROGRESS.md`'s `## Archived milestones`, remove the task from the queue, promote the next entry into the active slot, then trash the task file. Before that signal, leave the task `in-progress` even when implementation and verification are complete. `## Archived milestones` is the sole historical record and is release-scoped, not permanent: once a roadmap release ships, remove its milestone entries too.

### Status and dependencies

Every task file's front matter states `status` (`ready`, `in-progress`, `blocked`, or `needs-decision`) and `depends` (task filename stems that must land first, or `[]`). Use `depends` only for real prerequisites; physical queue order already expresses priority and intended sequence. It lets a second agent or the user safely pick independent work out of order. Legacy numeric stems and `done` statuses remain valid input. Mark a task `needs-decision` rather than `ready` when an open risk or ambiguity needs the user's input before implementation; don't resolve it by guessing. Mark it `blocked` whenever it isn't actionable yet, whether from an external block or an unresolved entry in `depends` — `ready` is reserved for tasks with no unresolved prerequisite. Don't enumerate the prerequisite in the queue; the task file's own `depends` already names it, and that list can get long.

Front matter is the source of truth for status: the queue's inline annotation is convenience and may lag. A verified implementation remains `in-progress` until the user signals acceptance; Git state does not change this. Check the active task's front matter before starting it. Only propose actual dispatch tooling (a script or bot that assigns tasks) if the backlog is large enough, and independent enough, that manual pickup has become the bottleneck: for a handful of tasks it isn't.

## Section structure

Inline `PROGRESS.md` section (fields nest under the section heading, so `###`):

```markdown
## <Section name>

### Status

Optional. Only needed once tasks can be picked up out of order: `ready`, `in-progress`, `blocked`, or `needs-decision`.

### Depends on

Optional, paired with Status. Other sections/tasks that must land first, or "None".

### Purpose

State the user, business, or operational problem being solved, who experiences it, and the observable result that would show the work succeeded. For routine maintenance, one concise sentence is enough.

### Contract

Public behaviour, data shape, UI states, or API surface affected. Required for public or user-visible work.

### Model tier

Optional. Note if this section needs a specific tier (Haiku for mechanical/high-volume work, Sonnet for implementation, Opus for planning or cross-file synthesis) — skip if the session default is fine.

### Files likely to change

### Related files to inspect

### Spec

Optional. Link to `.agent/specs/<feature>.md` only when this section needs heavier feature context.

### Tasks

- [ ] item

### Acceptance criteria

- Observable condition that proves the work is done

### Verification

Focused checks, manual review, or evidence required before handoff.

### Risks

### Notes
```

Standalone `.agent/tasks/<task-slug>.md` file. No `# Title` heading — front matter `title` is the single source. Front matter is a deliberately flat subset of YAML (plain `key: value`, values are strings, inline `[a, b]` lists, no nesting, no quoting) so consumers never need a YAML library:

```markdown
---
title: Human-readable task name
overview: One or two sentences reminding a human what this task is and why it exists.
status: ready            # ready | in-progress | blocked | needs-decision
depends: []              # task filename stems that must land first, e.g. [metadata-validation]
release: phase-5         # roadmap ID; omit for backlog
---

## Purpose

State the user, business, or operational problem being solved, who experiences it, and the observable result that would show the work succeeded. For routine maintenance, one concise sentence is enough.

## Contract

Public behaviour, data shape, UI states, or API surface affected. Required for public or user-visible work.

For public, user-visible, or behaviourally significant work, name only applicable failure and recovery states, such as loading, empty, denied, error, partial, stale, interrupted, or recovery. Keep the contract observable and invariant-focused, not implementation or testing steps; route accessibility, security, error-handling, and testing mechanics to specialist skills. Example: a UI flow might define loading, empty, denied, and error; an API or CLI flow might define partial, stale, interrupted, or recovery.

See docs/progress-format.md for the Contract, Tasks, and Verification boundary, including the skill and rule split.

## Model tier

Optional. Note if this task needs a specific tier (Haiku for mechanical/high-volume work, Sonnet for implementation, Opus for planning or cross-file synthesis) — skip if the session default is fine.

## Files likely to change

## Related files to inspect

Optional.

## Spec

Optional. Link to `.agent/specs/<feature>.md` only when this task needs heavier feature context.

## Commit plan

- [ ] Commit 1: reviewable outcome
- [ ] Commit 2: follow-up outcome

## Tasks

- [ ] item

## Acceptance criteria

- Observable condition that proves the work is done

## Verification

Focused checks, manual review, or evidence required before handoff.

## Risks

## Open questions

Optional. Unresolved decisions the user needs to weigh in on, kept next to the bullet they affect. Omit once resolved.

## Notes

Optional. Use only for durable execution constraints; do not use it as a running session log.

```
