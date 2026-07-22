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

For a brand-new project the initial plan is usually small enough to stay inline. Once there's a first concrete unit of ready-to-pick-up work, create it as `.agent/tasks/<task-slug>.md` (see the `project-plan-task` skill's "Task files vs progress sections") rather than growing the `## Active work` section indefinitely. The canonical contract for `PROGRESS.md` and task files is `docs/progress-format.md` in the Configuration/Agents repo — keep the templates below in sync with it.

```markdown
# <Project name>

## Session handoff

Read this section first. Only open the active task file. Stop after this section unless it's unclear or deeper context is genuinely needed.

### Active task

`.agent/tasks/<task-slug>.md`, or, for a brand-new plan with no task file yet, a one-sentence current goal plus next step. Use a stable descriptive kebab-case slug; it identifies the task rather than its position. Verify the active task's front matter status before starting. Check Git separately for safety, but never use Git state as progress state.

### Upcoming queue

Bulleted title links with inline status, non-done tasks only. Physical order is priority and the intended pickup sequence. Reorder links without renaming task files. Front matter wins over the inline annotation on conflict.

### Standing context

Verification commands and recurring gotchas that apply regardless of which task is active.

### Stop here

Only continue reading if the active task is unclear, or you're picking up backlog work not yet in `.agent/tasks/`.

## Roadmap

One table; row order is the timeline. Task front matter references the `ID` column via `release:`. `Status` is `planned` (or blank), `active`, or `done`. Anything needing more than a sentence of overview gets a spec, not a longer cell.

| ID      | Title           | Overview                        | Status |
| ------- | --------------- | ------------------------------- | ------ |
| phase-1 | <Release title> | One sentence on what it means.  | active |

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

Completed work, one dated line per finished task. This is the sole historical record: task files are deleted on completion, not kept. It's also release-scoped, not permanent — prune entries once their roadmap release ships.
```

Task file shape (`.agent/tasks/<task-slug>.md`): stable descriptive kebab-case filename; the human-facing name lives in front matter `title`, and task files do not prescribe branch names. Never rename files to reflect priority or queue position. Existing numeric files are tolerated as legacy and must not be bulk-renamed merely to adopt this convention. Keep in sync with the `project-plan-task` skill's "Section structure" if either changes:

```markdown
---
title: Human-readable task name
overview: One or two sentences reminding a human what this task is and why it exists.
status: ready            # ready | in-progress | blocked | needs-decision
depends: []              # task filename stems that must land first, e.g. [metadata-validation]
release: phase-1         # roadmap ID; omit for backlog
---

## Purpose

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

## Tasks

- [ ] item

## Acceptance criteria

- Observable condition that proves the work is done

## Verification

Focused checks, manual review, or evidence required before handoff.

## Risks

## Notes

Optional.

```

Front matter is a deliberately flat subset of YAML: plain `key: value` pairs treated as strings, inline `[a, b]` lists, no nesting, no quoting, unknown keys ignored. Consumers never need a YAML library.
