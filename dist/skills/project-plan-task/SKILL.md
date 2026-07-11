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

1. **Discuss** — clarify requirements, scope, and dependencies before editing `PROGRESS.md`
2. **Risk triage** (opt-in) — identify high-risk files before planning:
   - **Git churn**: `git log --oneline --since="1 month ago" -- <path> | wc -l` — high recent change = defect-prone
   - **Complexity**: large files or high function counts (use codebase-memory or `wc -l`)
   - **Fan-in**: high caller count = high blast radius (use codebase-memory `search_graph(min_degree=10, relationship="CALLS", direction="inbound")`)
   - Flag files high on two+ signals in **Risks**
   - Skip for routine/single-file/familiar work
3. **Locate** — identify placement relative to upcoming sections
4. **Approach exploration** (opt-in) — for complex tasks, surface 2–3 approaches with tradeoffs; wait for user choice before writing. Skip single-file, obvious, or decided work. Present options first, write after confirmation.
5. **Reorganise** — if new work changes later needs, update upcoming sections
6. **Insert** — add section: purpose, expected commit, model tier, files likely to change, tasks, risks, notes
7. **Update parking lot** — move related ideas into new section or leave parked

## Cross-repo work

When a task may span more than one repository, make the repo boundary explicit before adding it to the plan. This gives us most of the coordination benefit of a synthetic monorepo without requiring a hosted tool or account.

Capture these facts in the section, task file, or linked spec:

- **Main repo**: where the parent task should run and where most local commands apply
- **Auxiliary repos**: repos needed for read-only context, implementation, generated output, examples, or downstream validation
- **Relationship**: package consumer, API client, generated-output consumer, documentation/example repo, CI dependency, or release baseline
- **Permission boundary**: do not clone, add, edit, push, open PRs, or run remote/networked commands in another repo without explicit user approval
- **Validation owner**: which repo's diagnostics prove the change, including any downstream checks required before release
- **Handoff references**: branch names, PR links, task or session IDs, diagnostic log paths, and repo-specific risks

For broad dependency questions, start with local evidence: package metadata, import searches, codebase-memory graph queries when available, and documented consumer lists. If the affected repo set is still unclear, mark the task `needs decision` and ask before expanding the working set.

## Placement principles

- Insert before upcoming sections if this work is a prerequisite
- Split into two sections if task spans multiple commits
- Order by dependency, not arrival
- Each section with `### Expected commit` is an execution boundary
- When asked to implement multi-section plan, do only first incomplete section unless user asks for all
- After one section, stop for review: changed files, verification, commit message
- Do not combine release, policy, tooling, docs, roadmap into one working-tree change unless explicitly one commit

## Feature specs

For larger spikes or ambiguous features, create/reference a per-feature spec under `.agent/specs/` instead of expanding `PROGRESS.md` with design history. Keep `PROGRESS.md` focused on execution state and add `### Spec` link in relevant section. Do not create specs for small changes, direct bug fixes, routine docs edits, or work fitting one progress section.

Spec explains why now, problem, goals, current status (optional), non-goals, approach, entry point and files to inspect (optional), API/schema/interface changes, decisions and open questions (optional), acceptance criteria, risks, and verification. Read/update only when working on that feature. Full outline lives in the `project-setup` skill's "Feature specs" section — keep in sync if either changes.

## Task files vs progress sections

Once a plan has more than the current one or two active items, prefer a standalone file under `.agent/tasks/<slug>.md` over an inline `PROGRESS.md` section for concrete, ready-to-pick-up work. This keeps the read surface small: the next agent opens only the active task's file, not the whole plan.

`PROGRESS.md`'s session handoff then holds only: a link to the active task file, a short ordered list of upcoming task file links, and standing context that doesn't change per task (verification commands, recurring gotchas). Backlog items with no concrete task file yet stay as prose bullets elsewhere in `PROGRESS.md` (with a spec link if one exists) — do not create a task file until the item is genuinely next; write it just-in-time.

Each task file uses the same **Section structure** below, promoted one heading level: the task file's own top-level heading (`# <Task name>`) takes the place of `## <Section name>`, so its fields are `##` (Purpose, Expected commit, ...) rather than `###` — semantic nesting, not a fixed heading depth. Add a `## When done` step at the end naming what to delete and what to promote into the active slot next.

Placement follows the same principle as section order: when inserting new work, if it's the immediate next task, write or update the active task file directly; if it's later in the queue, add a new `.agent/tasks/<slug>.md` file and insert its link into the queue list in dependency order, not at the end.

On completion, delete the finished task file and promote the next queue entry into the active slot in `PROGRESS.md`. This mechanical step, not a "stop and read further" instruction, is what keeps the next agent from re-deriving the whole plan.

### Status and dependencies

Every task file states `## Status` (`ready`, `in progress`, `blocked`, or `needs decision`) and `## Depends on` (links to other tasks that must land first, or "None"). This is what lets a second agent, or the user, pick up any task that isn't already claimed instead of assuming the queue order is a strict dependency chain: most queued tasks are independent unless `Depends on` says otherwise. Mark a task `needs decision` rather than `ready` when an open risk or ambiguity needs the user's input before implementation; don't resolve it by guessing.

Default to a plain status convention over building a dispatcher: branch name matches the task slug (`task/<slug>`), and whoever picks up work reads the queue's inline status and opens the file directly. Only propose actual dispatch tooling (a script or bot that assigns tasks) if the backlog is large enough, and independent enough, that manual pickup has become the bottleneck: for a handful of tasks it isn't.

## Section structure

Inline `PROGRESS.md` section (fields nest under the section heading, so `###`):

```markdown
## <Section name>

### Status

Optional. Only needed once tasks can be picked up out of order: `ready`, `in progress`, `blocked`, or `needs decision`.

### Depends on

Optional, paired with Status. Other sections/tasks that must land first, or "None".

### Purpose

### Expected commit

<Conventional Commit message>

### Model tier

Optional. Note if this section needs a specific tier (Haiku for mechanical/high-volume work, Sonnet for implementation, Opus for planning or cross-file synthesis) — skip if the session default is fine.

### Files likely to change

### Related files to inspect

### Spec

Optional. Link to `.agent/specs/<feature>.md` only when this section needs heavier feature context.

### Tasks

- [ ] item

### Risks

### Notes
```

Standalone `.agent/tasks/<slug>.md` file (same fields, one level shallower — the task name is the file's own top-level heading, not nested under it):

```markdown
# <Task name>

## Status

`ready`, `in progress`, `blocked`, or `needs decision`. Use `needs decision` when an open risk needs the user's input before an agent should implement.

## Depends on

Other task files that must land first, or "None". Independent tasks (most of the queue, unless stated otherwise) can be picked up out of order, each on its own `task/<slug>` branch.

## Purpose

## Expected commit

<Conventional Commit message>

## Model tier

Optional. Note if this task needs a specific tier (Haiku for mechanical/high-volume work, Sonnet for implementation, Opus for planning or cross-file synthesis) — skip if the session default is fine.

## Files likely to change

## Related files to inspect

## Spec

Optional. Link to `.agent/specs/<feature>.md` only when this task needs heavier feature context.

## Tasks

- [ ] item

## Risks

## Notes

## When done

What to delete and what to promote into the active slot next.
```
