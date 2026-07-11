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
2. **Ask** — clarify ambiguous requirements, constraints; surface tradeoffs and alternatives
3. **Discuss** — if multiple approaches exist, present them; don't pick silently
4. **Plan** — create initial `PROGRESS.md` using standard schema below
5. **Wait** — do not start until plan is reviewed and approved

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

For each delegated task:

1. **Delegate** — give the subagent the goal, rationale, constraints, acceptance criteria, and relevant file paths from `PROGRESS.md`
2. **Review** — inspect the subagent's output against acceptance criteria; do not trust blindly
3. **Approve or request changes** — if output is correct, proceed; if not, send specific feedback
4. **Commit** — after approval, commit the task's output before delegating the next

After two comparable failures, escalate to a more capable agent or resume in the main session.

Enables autonomous multi-hour execution while keeping the main agent as architect and reviewer.

**Token tradeoff:** subagents re-read files the main agent already has in context. Use when the plan is too large for one context window.

## Planning principles

- Commits as unit of work; each section roughly matches one Conventional Commit
- Multiple small sections over one large one; each independently reviewable
- "Files likely to change" reduces re-exploration in future sessions
- Plan 2–3 sections ahead; detailed planning happens when work starts
- Keep session handoff at top. Agents read from top and stop after handoff when adequate.

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

## Current status

Optional; omit if obvious or the spec is new. What's already done vs what's still outstanding, so a fresh agent can gauge progress without reading history.

## Non-goals

- Work deliberately out of scope

## Proposed approach

Intended solution shape, including important alternatives or tradeoffs.

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

For a brand-new project the initial plan is usually small enough to stay inline. Once there's a first concrete unit of ready-to-pick-up work, create it as `.agent/tasks/<slug>.md` (see the `project-plan-task` skill's "Task files vs progress sections") rather than growing the `## Active work` section indefinitely.

```markdown
# <Project name>

## Session handoff

Read this section first. Only open the active task file. Stop after this section unless it's unclear or deeper context is genuinely needed.

### Active task

`.agent/tasks/<slug>.md`, or, for a brand-new plan with no task file yet, a one-sentence current goal plus next step.

### Upcoming queue

Ordered links to `.agent/tasks/<slug>.md` files, or brief bullets if not yet broken into files.

### Standing context

Verification commands and recurring gotchas that apply regardless of which task is active.

### Stop here

Only continue reading if the active task is unclear, or you're picking up backlog work not yet in `.agent/tasks/`.

## Project overview

Brief description: purpose, tech, constraints.

## Decisions

Key architectural or process decisions. Date-stamped entries.

## Discoveries

Unexpected findings that affect the work. Date-stamped entries. Promote a discovery to `AGENTS.md`'s `## Need to know` section once it proves durable rather than task-specific.

## Upcoming work

Brief bullets for backlog items with no task or spec file yet. Detailed planning, and a task file, happen when work starts.

## Parking lot

Ideas and concerns not belonging to the current section.

## Archived milestones

Completed major sections, moved here to keep the document small.
```

Task file shape (`.agent/tasks/<slug>.md`), same fields as an inline `## Active work` section would have used, one heading level shallower (`# <Task name>` in place of `## <Section name>`, so fields are `##` not `###`) — keep in sync with the `project-plan-task` skill's "Section structure" if either changes:

```markdown
# <Task name>

## Status

`ready`, `in progress`, `blocked`, or `needs decision`. Use `needs decision` when an open risk needs the user's input before an agent should implement.

## Depends on

Other task files that must land first, or "None". Independent tasks can be picked up out of order, each on its own `task/<slug>` branch.

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

What to delete, and what to promote into the active slot in `PROGRESS.md` next.
```
