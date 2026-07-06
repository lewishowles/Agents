---
# Generated — edit skill.json and SKILL.body.md instead.
name: project-setup
displayName: Project setup
description: >
  Use this skill to start a new project or feature — explores the repo, asks clarifying questions, and creates an initial PROGRESS.md before any implementation begins.
---
# Project setup

Start a new project or feature. Create initial `PROGRESS.md` after exploration and discussion; do not implement until plan is reviewed.

## File location

`PROGRESS.md` lives at **project root**, not `.claude/`. Create/read `<project-root>/PROGRESS.md`.

## Workspace file

Check `<project-root>/WORKSPACE.md` before planning. Factual source for commands, generated files, diagnostics, progress locations, expensive checks, and forbidden operations.

When `.agent/scripts/project-diagnostics.py` exists, list it as preferred verification route. Plans use `--list` for discovery and `--check <name>` for named verification; `--all` for user-approved broad checks only.

If missing, generate it only when a workspace generator command is discoverable by name. Example:

```sh
agents:workspace --write
```

Before running, confirm `agents:workspace` exists in current shell, then run from project root. After generation, tell user it needs review before relying on command safety, generated paths, or forbidden-operation classifications.

If no generator exists, do not create the file manually. Inspect `AGENTS.md`, package scripts, and nearby docs; mention `WORKSPACE.md` would improve future sessions.

## Workflow

1. **Explore** — read repo; identify patterns, tech choices, relevant files; check root `PROGRESS.md`, `AGENTS.md`, `WORKSPACE.md`, `CONTEXT.md`, and `README.md`
2. **Ask** — clarify ambiguous requirements and constraints before planning; surface tradeoffs and alternatives
3. **Discuss** — if multiple approaches exist, present them; don't pick silently
4. **Plan** — create initial `PROGRESS.md` using standard schema below
5. **Wait** — do not begin implementation until the plan is reviewed and approved

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

1. **Delegate** — give the subagent the task description, acceptance criteria, and relevant file paths from `PROGRESS.md`
2. **Review** — inspect the subagent's output against acceptance criteria; do not trust blindly
3. **Approve or request changes** — if output is correct, proceed; if not, send specific feedback
4. **Commit** — after approval, commit the task's output before delegating the next

Enables autonomous multi-hour execution while keeping the main agent as architect and reviewer.

**Token tradeoff:** subagents re-read files the main agent already has in context. Use when the plan is too large for one context window.

## Planning principles

- Treat commits as unit of work; each section should roughly match one Conventional Commit
- Prefer multiple small sections over one large one; each independently reviewable
- "Files likely to change" reduces re-exploration in future sessions
- Don't plan more than 2–3 sections ahead; detailed planning happens when work starts
- Keep session handoff current at top. Future agents read from top and stop after handoff when it gives enough context.

## Feature specs

Use linked spec only for larger spikes or ambiguous features where `PROGRESS.md` would carry too much rationale. Skip for small changes, bug fixes, routine docs edits, or work that fits one progress section.

Specs are per feature/spike, not global docs. Put under `.agent/specs/<feature>.md`, link from `PROGRESS.md`. `PROGRESS.md` stays operational: current goal, next step, verification, blockers. Spec carries heavier context, read only when active.

Use this outline when a spec is warranted:

```markdown
# <Feature or spike name>

## Why now

Why this matters now, trigger, and consequence if not done.

## Problem

User or system problem.

## Goals

- Outcome that must be true

## Non-goals

- Work deliberately out of scope

## Proposed approach

Intended solution shape, including important alternatives or tradeoffs.

## API, schema, or interface

Commands, routes, data shape, UI states, or public contracts affected.

## Acceptance criteria

- Observable condition that proves the work is done

## Risks

- Risk, uncertainty, or dependency to monitor

## Verification

Focused checks, manual review, or evidence needed before handoff.
```

When permanent decisions emerge, move them to `AGENTS.md`, architecture docs, user docs, or ADR only when ADR criteria are met.

## CONTEXT.md — domain glossary

Root `CONTEXT.md` is pure domain glossary: canonical names, names to avoid, resolved ambiguities. Not spec, scratch pad, or implementation guide.

Create lazily when first term is worth capturing. Add entries when terms are agreed, not in a batch at the end.

Each entry follows this shape:

```markdown
**Term** — one-sentence definition. _Avoid_: synonyms or overloaded words that should not be used.
```

When `CONTEXT.md` exists, use its vocabulary in code, comments, issue titles, and ADRs. If user term conflicts, surface conflict instead of picking silently.

_CONTEXT.md glossary pattern inspired by [mattpocock/skills](https://github.com/mattpocock/skills) (MIT)._

## PROGRESS.md schema

```markdown
# <Project name>

## Session handoff

Read this section first. Stop after this section unless the task needs deeper context.

### Current goal

One sentence. What are we delivering right now?

### Previous step

Plan created; no implementation yet.

### Next step

Review and approve the plan before implementation starts.

### Stop here

Only continue reading if the next step is unclear, the user asks for planning/review/history, or implementation needs decisions, discoveries, risks, or file lists below.

## Project overview

Brief description: purpose, tech, constraints.

## Active work

### Purpose

### Expected commit

<Conventional Commit message>

### Model tier

Optional. Note if this chunk needs a specific tier (Haiku for mechanical/high-volume work, Sonnet for implementation, Opus for planning or cross-file synthesis) — skip if the session default is fine.

### Files likely to change

### Related files to inspect

### Spec

Optional. Link to `.agent/specs/<feature>.md` only when the work is large or ambiguous enough to need one.

### Tasks

- [ ] item

### Risks

### Notes

## Decisions

Key architectural or process decisions. Date-stamped entries.

## Discoveries

Unexpected findings that affect the work. Date-stamped entries.

## Upcoming work

Brief bullets only. Detailed planning happens when work starts.

## Parking lot

Ideas and concerns not belonging to the current section.

## Archived milestones

Completed major sections, moved here to keep the document small.
```
