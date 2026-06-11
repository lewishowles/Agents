---
# Generated — edit skill.json and SKILL.body.md instead.
name: project-plan-task
description: >
  Use this skill to introduce new work into an existing plan — discusses requirements and inserts a new section at the appropriate location, not simply at the end.
---
# Project plan task

Use this skill to introduce new work into an existing plan. Inserts the work at the most appropriate location — not necessarily the end — and reorganises future sections if understanding has changed.

## File location

`PROGRESS.md` lives at the **project root** — not in `.claude/`. Always look for `<project-root>/PROGRESS.md` first. Do not assume `.claude/PROGRESS.md`.

## Workflow

1. **Discuss** — clarify requirements, scope, and dependencies before touching `PROGRESS.md`
2. **Locate** — identify where the new work fits: before existing upcoming sections, after them, or interleaved
3. **Reorganise** — if the new work changes what's needed later, update upcoming sections to match
4. **Insert** — add a new section using the standard structure (purpose, expected commit, files likely to change, tasks, risks, notes)
5. **Update parking lot** — move any related ideas into the new section or keep them in the parking lot if they don't fit yet

## Placement principles

- Insert before other upcoming sections if this work is a prerequisite
- Split into two sections if the task spans more than one commit
- Avoid simply appending — sequential order should reflect dependency order, not arrival order

## Section structure

```markdown
## <Section name>

### Purpose

### Expected commit

<Conventional Commit message>

### Files likely to change

### Related files to inspect

### Tasks

- [ ] item

### Risks

### Notes
```
