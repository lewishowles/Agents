---
# Generated — edit skill.json and SKILL.body.md instead.
name: project-continue
displayName: Project continue
description: >
  Use this skill to resume work from an existing PROGRESS.md — compacts stale notes, verifies completed work, and picks up from where the last session left off.
related-skills:
  - project-compact-progress
---
# Project continue

Use this skill to resume from an existing `PROGRESS.md`. Treat it as a living record, not perfect truth, and update it during the session.

## File location

Look in this order and use the first match:

1. `<project-root>/PROGRESS.md`
2. `<project-root>/.claude/PROGRESS.md`
3. `<project-root>/.agents/PROGRESS.md`

If none exist, say so and ask the user where to create one.

## Workflow

1. **Read** — read `## Session handoff` first, then stop unless the next step is unclear or the task needs deeper context
2. **Compact** — repair a stale or missing handoff before continuing; remove duplicate notes and obsolete TODOs; compress completed sub-tasks to a single line
3. **Verify** — spot-check that recently-completed work landed
4. **Reorient** — confirm the active work still fits; move it to upcoming if priorities changed
5. **Continue** — work through the current section; update `PROGRESS.md` as discoveries are made
6. **Wrap up** — refresh the handoff before stopping

## Session startup

Before starting new work, read only enough to orient:

- Start with `## Session handoff`
- Continue into `## Active work`, `## Decisions`, `## Discoveries`, or `## Risks` only when needed
- Do not read completed or archived sections unless the current task depends on their history
- Confirm branch state and any uncommitted work
- Verify unfinished tasks belong to the current section

## During the session

- Record discoveries under `## Discoveries` as they happen — don't defer to the end
- Update "files likely to change" if the scope shifts
- If a task reveals unexpected complexity, add a risk entry before continuing

## Finishing work

Finishing a piece of work includes updating `PROGRESS.md`. Do not leave that to the next session.

- Mark completed tasks in `## Active work`
- Update `### Previous step` with what just changed and any verification performed
- Update `### Next step` with the first concrete follow-up action
- Move finished active work toward `## Archived milestones` when it no longer needs attention
- If nothing remains for the current goal, say that clearly in the handoff instead of leaving stale TODOs

## Wrapping up

- Update `## Session handoff` — current goal, previous step, next step, and stop guidance
- Mark completed tasks; move done sections toward `## Archived milestones`
- Do not leave `PROGRESS.md` in a half-updated state
