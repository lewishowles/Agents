---
name: setup-project
description: >
  Use this skill to start a new project or feature — explores the repo, asks
  clarifying questions, and creates an initial PROGRESS.md before any
  implementation begins.
---

# Setup project

Use this skill to start a new project or feature with a solid foundation. Creates an initial `PROGRESS.md` after exploration and discussion — do not begin implementation until the plan is reviewed.

## Workflow

1. **Explore** — read the repository; identify existing patterns, tech choices, and relevant files; check for `PROGRESS.md`, `AGENTS.md`, and `README.md`
2. **Ask** — clarify ambiguous requirements and constraints before planning; surface tradeoffs and alternatives
3. **Discuss** — if multiple approaches exist, present them; don't pick silently
4. **Plan** — produce an initial `PROGRESS.md` following the standard schema (see below)
5. **Wait** — do not begin implementation until the plan is reviewed and approved

## Planning principles

- Treat commits as the primary unit of work — each section of PROGRESS.md should correspond roughly to one Conventional Commit
- Prefer multiple small sections over one large one; each section should be independently reviewable
- "Files likely to change" is important — reduces re-exploration in future sessions
- Don't plan more than 2–3 sections ahead; detailed planning happens when work starts

## PROGRESS.md schema

```markdown
# <Project name>

## Project overview

Brief description: purpose, tech, constraints.

## Current goal

One sentence. What are we delivering right now?

## Decisions

Key architectural or process decisions. Date-stamped entries.

## Discoveries

Unexpected findings that affect the work. Date-stamped entries.

## Current section

### Purpose

### Expected commit

<Conventional Commit message>

### Files likely to change

### Related files to inspect

### Tasks

- [ ] item

### Risks

### Notes

## Upcoming sections

Brief bullets only. Detailed planning happens when work starts.

## Parking lot

Ideas and concerns not belonging to the current section.

## Next session

What to do first when resuming. Should be scannable in 30 seconds.

## Archived milestones

Completed major sections, moved here to keep the document small.
```
