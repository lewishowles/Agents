# Project plan task

Use this skill to add new work to an existing plan. Insert it where it belongs, not necessarily at the end, and reorganise future sections if understanding changed.

## File location

`PROGRESS.md` lives at the **project root** — not in `.claude/`. Always look for `<project-root>/PROGRESS.md` first. Do not assume `.claude/PROGRESS.md`.

## Workflow

1. **Discuss** — clarify requirements, scope, and dependencies before touching `PROGRESS.md`
2. **Locate** — identify whether the work fits before, after, or between upcoming sections
3. **Reorganise** — if the new work changes what's needed later, update upcoming sections to match
4. **Insert** — add a new section using the standard structure (purpose, expected commit, files likely to change, tasks, risks, notes)
5. **Update parking lot** — move related ideas into the new section or leave them parked

## Placement principles

- Insert before other upcoming sections if this work is a prerequisite
- Split into two sections if the task spans more than one commit
- Avoid appending by default — order should reflect dependencies, not arrival
- Treat each section with its own `### Expected commit` as an execution boundary
- If asked to implement a multi-section plan, implement only the first incomplete section unless the user explicitly says to implement all chunks in one pass
- After implementing one section, stop for review with changed files, verification performed, and the suggested commit message
- Do not combine release code, repo policy, tooling, docs, and roadmap sections into one working-tree change unless the plan explicitly defines them as one expected commit

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
