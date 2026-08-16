# Project setup

Start a new project or feature. Create initial `PROGRESS.md` after exploration and discussion; do not implement until plan is reviewed.

## File location

`PROGRESS.md` lives at **project root**, not `.claude/`. Create/read `<project-root>/PROGRESS.md`.

## Workspace file

Check `<project-root>/WORKSPACE.md` before planning. Factual source for commands, generated files, diagnostics, progress locations, expensive checks, forbidden operations.

When `.agent/scripts/project-diagnostics.py` exists, prefer it. Plans use `--list` for discovery and `--check <name>` for verification; `--all` for user-approved broad checks only.

If missing and a workspace generator exists, run it:

```sh
agents:workspace --write
```

Confirm `agents:workspace` exists in current shell before running from project root. After generation, tell user to review it before relying on command safety, generated paths, or forbidden operations.

If no generator exists, don't create manually. Inspect `AGENTS.md`, package scripts, nearby docs. Mention `WORKSPACE.md` would improve future sessions.

## Workflow

1. **Explore** — read repo, identify patterns, tech, relevant files; check `PROGRESS.md`, `AGENTS.md`, `WORKSPACE.md`, `CONTEXT.md`, `README.md`
2. **Ask** — identify all known decision-blocking ambiguities, constraints, tradeoffs, and alternatives, then ask them together. Do not cap this initial set. Ask further questions only when an answer reveals a material new unknown.
   - For ambiguous or consequential work, group questions by dependency. In each round, ask every question whose prerequisites are settled, give a recommended default, then reassess after the reply. Do not ask downstream questions that assume an answer still open.
3. **Discuss** — if multiple approaches exist, present them; don't pick silently
4. **Plan** — create initial `PROGRESS.md` using standard schema below
5. **Wait** — do not start until plan is reviewed and approved. For a task file, point to it rather than duplicating it in chat; the user quotes a passage to challenge it or answers an inline `## Open questions` entry. A genuinely trivial inline section can just be shown directly.

## Subagent delegation (optional)

After plan approval, consider delegating implementation tasks to subagents when:

- The plan has 3+ independent tasks that don't share files
- Tasks are well-specified with clear acceptance criteria
- The work is mechanical: scaffolding, repeated pattern changes, test writing

**Do not delegate when:**

- Tasks share files or have high interdependency
- Single-file changes or quick fixes
- The task requires nuanced judgment or architectural decisions
- The agent runtime doesn't support subagents

### Review gate

Delegate exactly one implementation chunk at a time. Do not delegate or begin a second chunk, even when files are independent, until the user has accepted the earlier handoff with “committed”, “continue”, “next”, or equivalent.

For each delegated task:

1. **Delegate** — give the subagent the goal, rationale, constraints, acceptance criteria, and relevant file paths from `PROGRESS.md`
2. **Review** — inspect the subagent's output against acceptance criteria; do not trust blindly
3. **Approve or request changes** — if output is correct, proceed; if not, send specific feedback
4. **Hand off** — after approval, present the verified result and wait for the user's acceptance before delegating the next task

After two comparable failures, escalate to a more capable agent or resume in the main session.

Enables autonomous multi-hour execution while keeping the main agent as architect and reviewer.

**Token tradeoff:** subagents re-read files the main agent already has in context. Use when the plan is too large for one context window.

## Planning principles

- A task file owns a coherent feature or outcome and may contain several ordered commit sections. Each commit section has one reviewable outcome, coherent files, and focused verification. Create a separate task file only for independently schedulable feature work, decisions, dependencies, or release boundaries, not merely because the feature needs multiple commits.
- Apply the `project-plan-task` task-boundary gate before creating a standalone task file.
- For a multi-commit task, add a `## Commit plan` checklist using `- [ ] Commit N: outcome`; work only on the first unchecked entry unless the user asks for all.
- Apply the `project-plan-task` review-size gate to every commit entry: one primary review question and a soft ceiling of three substantive files.
- Multiple small sections over one large one; each independently reviewable
- "Files likely to change" reduces re-exploration in future sessions
- Plan 2–3 sections ahead; detailed planning happens when work starts
- Keep session handoff at top. Agents read from top and stop after handoff when adequate.

### Planning-quality gate

Before asking for approval on any substantive task or feature contract, self-check it against: repository truth, contract, boundary, altitude, failure and recovery states, acceptance evidence, and verification. Leave a strong contract unchanged. Invoke `project-review-task` explicitly when a high-risk or high-ambiguity contract warrants an independent pass, or once a genuine second reviewer is available — a solo self-check by the authoring model is not a substitute.

Apply the clear planning language gate from `docs/progress-format.md` to task files, inline `PROGRESS.md` entries, and feature specs. Write for a reader who does not share the investigation context: state the problem first, use direct statements with a clear subject and action, keep one requirement, decision, recommendation, or question per bullet, explain unfamiliar terms, separate confirmed requirements from recommended defaults and unresolved questions, and make acceptance criteria observable. Preserve exact APIs, paths, commands, edge cases, constraints, failure behaviour, verification requirements, and technical decisions. If clarification would require a new product or architecture decision, leave it unresolved and use `needs-decision` instead of guessing.

## Feature specs

Use linked specs only for larger spikes or ambiguous features. Skip small changes, bug fixes, routine docs, or single-section work.

Specs are per-feature/spike under `.agent/specs/<feature>.md`, linked from `PROGRESS.md`. `PROGRESS.md` stays operational. Spec carries heavier context, read only when active.

Use this outline when a spec is warranted:

```markdown
# <Feature or spike name>

## Why now

Why this matters now, trigger, and consequence if not done.

## Problem

User or system problem.

## Goals

- Outcome that must be true

## First usable version

Smallest end-to-end path that solves the problem, including deliberate manual steps.

## Current status

Optional; omit if obvious or the spec is new. What's already done vs what's still outstanding, so a fresh agent can gauge progress without reading history.

## Non-goals

- Work deliberately out of scope

## Proposed approach

Intended solution shape, including important alternatives or tradeoffs.

## High-cost assumptions

Optional. Assumptions most costly if wrong, and the earliest evidence that can test them.

## Entry point

Optional; omit if obvious. Where an agent with zero prior context should start reading — the first file, command, or concept to look at.

## Files to inspect

Optional; omit if obvious. Files most relevant to understanding or continuing this work.

## API, schema, or interface

Commands, routes, data shape, UI states, or public contracts affected.

## Decisions

Optional; omit if none yet. Choices already made and why, so they aren't re-debated.

## Open questions

Optional; omit if none. What's still unresolved.

## Acceptance criteria

- Observable condition that proves the work is done

## Risks

- Risk, uncertainty, or dependency to monitor

## Verification

Focused checks, manual review, or evidence needed before handoff.
```

When permanent decisions emerge, move them to `AGENTS.md`'s `## Need to know` section, architecture docs, user docs, or ADR only when ADR criteria are met. `AGENTS.md` is read every session and never gets compacted, so it's the right home for a fact once it proves durable, rather than waiting for it to survive several rounds of `PROGRESS.md` compaction.

## CONTEXT.md — domain glossary

Root `CONTEXT.md` is pure domain glossary: canonical names, names to avoid, resolved ambiguities. Not spec, scratch pad, or guide.

Create lazily as terms emerge. Add entries when agreed, not in batches.

Each entry:

```markdown
**Term** — one-sentence definition. _Avoid_: synonyms or overloaded words.
```

Use vocabulary from `CONTEXT.md` in code, comments, issue titles, ADRs. Surface conflicts instead of picking silently.

_Pattern inspired by [mattpocock/skills](https://github.com/mattpocock/skills) (MIT)._

## PROGRESS.md schema

For a brand-new project the initial plan is usually small enough to stay inline. Once there's a first concrete unit of ready-to-pick-up work, create it as `.agent/tasks/<task-slug>.md` (see the `project-plan-task` skill's "Task records and chunks") rather than growing the `## Active work` section indefinitely. The canonical contract for `PROGRESS.md` and task files is `docs/progress-format.md` in the Configuration/Agents repo — keep the templates below in sync with it.

```markdown
# <Project name>

## Session handoff

Read this section first. Only open the active task file. Stop after this section unless it's unclear or deeper context is genuinely needed.

### Active task

`.agent/tasks/<task-slug>.md`, or, for a brand-new plan with no task file yet, a one-sentence current goal plus next step. Use a stable descriptive kebab-case slug; it identifies the task rather than its position. Verify the active task's front matter status before starting. Check Git separately for safety, but never use Git state as progress state.

### Upcoming queue

A `Task | Release | Status` table, non-done tasks only, rows grouped by Release in roadmap order with priority as the order within each group. Reorder rows without renaming task files; move a task between releases by editing its `release:` front matter and its row's group, not by annotating the row text. Front matter wins over the table's Status column on conflict. A `blocked` row doesn't say what it's waiting on — that's in the task file's `depends`, which can be long.

### Standing context

Verification commands and recurring gotchas that apply regardless of which task is active.

### Stop here

Only continue reading if the active task is unclear, or you're picking up backlog work not yet in `.agent/tasks/`.

## Roadmap

One table; row order is the timeline. Task front matter references the `ID` column via `release:`. `Status` is `planned` (or blank), `active`, or `done`. Anything needing more than a sentence of overview gets a spec, not a longer cell.

| ID      | Title           | Overview                        | Status |
| ------- | --------------- | ------------------------------- | ------ |
| phase-1 | <Release title> | One sentence on what it means.  | active |

Purpose, tech, and constraints belong in `AGENTS.md`, not a `## Project overview` section here — don't duplicate it.

## Decisions

Key architectural or process decisions still relevant to active or upcoming work. Date-stamped entries. Not a permanent log: promote a decision to `AGENTS.md` once it's durable and cross-session, or drop it once it's superseded or moot, and remove it from here either way.

## Discoveries

Unexpected findings that affect the work. Date-stamped entries. Not a permanent log: promote a discovery to `AGENTS.md`'s `## Need to know` section once it proves durable rather than task-specific, or drop it once it's stale or already visible in shipped code/docs, and remove it from here either way.

## Upcoming work

Brief bullets for backlog items with no task or spec file yet. Detailed planning, and a task file, happen when work starts.

## Parking lot

Ideas and concerns not belonging to the current section.

## Archived milestones

Completed work, one dated line per finished task. This is the sole historical record: task files are deleted on completion, not kept. It's also release-scoped, not permanent — prune entries once their roadmap release ships.
```

Task file shape (`.agent/tasks/<task-slug>.md`): stable descriptive kebab-case filename; the human-facing name lives in front matter `title`, and task files do not prescribe branch names. Never rename files to reflect priority or queue position. Existing numeric files are tolerated as legacy and must not be bulk-renamed merely to adopt this convention. Keep in sync with the `project-plan-task` skill's "Task records and chunks" if either changes:

```markdown
---
title: Human-readable task name
overview: One or two sentences reminding a human what this task is and why it exists.
status: ready            # ready | in-progress | blocked | needs-decision
depends: []              # task filename stems that must land first, e.g. [metadata-validation]
release: phase-1         # roadmap ID; omit for backlog
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

Front matter is a deliberately flat subset of YAML: plain `key: value` pairs treated as strings, inline `[a, b]` lists, no nesting, no quoting, unknown keys ignored. Consumers never need a YAML library.
