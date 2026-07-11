# Project plan task

Add new work to existing plan. Insert where it belongs, not necessarily at the end; reorganise future sections when understanding changed.

## File location

`PROGRESS.md` lives at **project root**, not `.claude/`. Look for `<project-root>/PROGRESS.md` first.

## Workspace file

Use `<project-root>/WORKSPACE.md` when present to choose verification commands, generated outputs, expensive checks, forbidden operations, and progress locations.

When `<project-root>/.agent/scripts/project-diagnostics.py` exists, prefer diagnostics `--check <name>` in `Verify with` over raw package scripts. Use `--list` for names; use `--all` only when section needs broad verification and user agrees.

Do not generate a missing workspace file just to add plan work. If missing, inspect `AGENTS.md`, package scripts, and nearby docs. If workspace context would materially improve the plan, mention the global command:

```sh
agents:workspace --write
```

Run only when user asks and `agents:workspace` exists in current shell.

## Workflow

1. **Discuss** — clarify requirements, scope, and dependencies before editing `PROGRESS.md`
2. **Risk triage** (opt-in, for unfamiliar or complex areas) — identify high-risk files before planning so the section can flag them:
   - **Git churn**: `git log --oneline --since="1 month ago" -- <path> | wc -l` — files with high recent change frequency are defect-prone
   - **Complexity**: large files or high function counts (use codebase-memory `search_graph` with degree filters, or `wc -l` as a proxy)
   - **Fan-in**: high caller count = high blast radius. Use codebase-memory `search_graph(min_degree=10, relationship="CALLS", direction="inbound")` for the target area
   - If any file scores high on two or more signals, note it in the section's **Risks** with a brief reason
   - Skip for routine work, single-file changes, or areas you've recently worked in
3. **Locate** — identify whether the work fits before, after, or between upcoming sections
4. **Approach exploration** (opt-in) — for complex or ambiguous tasks, surface 2–3 structurally different approaches, each with a one-sentence tradeoff, then wait for the user to choose before continuing. Skip when: the task is a single-file change, there is clearly only one sensible approach, or the user has already decided. Do not combine approach selection with plan writing — present options first, write the section after confirmation.
5. **Reorganise** — if the new work changes what's needed later, update upcoming sections to match
6. **Insert** — add a section using standard structure: purpose, expected commit, model tier, files likely to change, tasks, risks, notes
7. **Update parking lot** — move related ideas into the new section or leave them parked

## Placement principles

- Insert before other upcoming sections if this work is a prerequisite
- Split into two sections if the task spans more than one commit
- Avoid appending by default; order reflects dependencies, not arrival
- Treat each section with its own `### Expected commit` as an execution boundary
- If asked to implement multi-section plan, implement only first incomplete section unless user explicitly asks for all chunks
- After implementing one section, stop for review with changed files, verification performed, and the suggested commit message
- Do not combine release code, repo policy, tooling, docs, and roadmap sections into one working-tree change unless the plan explicitly defines them as one expected commit

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
