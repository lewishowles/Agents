---
# Generated — edit skill.json and SKILL.body.md instead.
name: project-continue
description: >
  Use this skill to resume work from an existing PROGRESS.md — compacts stale notes, verifies completed work, and picks up from where the last session left off.
related-skills:
  - project-compact-progress
---
# Continue project

Use this skill to resume work from an existing `PROGRESS.md`. Treats the document as a living record — not a perfect source of truth — and updates it as the session progresses.

## Workflow

1. **Read** — read `PROGRESS.md` in full; note the current section and next-session guidance
2. **Compact** — remove duplicate notes and obsolete TODOs; compress completed sub-tasks to a single line
3. **Verify** — check that recently-completed work actually landed (spot-check files, not assumptions)
4. **Reorient** — confirm the current section still makes sense given any new discoveries; move it to upcoming sections if priorities have changed
5. **Continue** — work through the current section; update `PROGRESS.md` as discoveries are made
6. **Wrap up** — before stopping, refresh "next session" so the next resume is instant

## Session startup

Before starting new work, do a lightweight cleanup:

- Re-read completed sections; confirm they can be archived
- Remove stale notes and resolved risks
- Confirm branch state and any uncommitted work
- Verify unfinished tasks belong to the current section

## During the session

- Record discoveries under `## Discoveries` as they happen — don't defer to the end
- Update "files likely to change" if the scope shifts
- If a task reveals unexpected complexity, add a risk entry before continuing

## Wrapping up

- Update `## Next session` — what to do first, what context would be lost without it
- Mark completed tasks; move done sections toward `## Archived milestones`
- Do not leave `PROGRESS.md` in a half-updated state
