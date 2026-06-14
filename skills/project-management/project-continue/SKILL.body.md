# Project continue

Use this skill to resume from an existing `PROGRESS.md`. Treat it as a living record, not perfect truth, and update it during the session.

## File location

Look in this order and use the first match:

1. `<project-root>/PROGRESS.md`
2. `<project-root>/.claude/PROGRESS.md`
3. `<project-root>/.agents/PROGRESS.md`

If none exist, say so and ask the user where to create one.

## Workflow

1. **Read** — read root `PROGRESS.md` in full; note the current section and next-session guidance
2. **Compact** — remove duplicate notes and obsolete TODOs; compress completed sub-tasks to a single line
3. **Verify** — spot-check that recently-completed work landed
4. **Reorient** — confirm the current section still fits; move it to upcoming if priorities changed
5. **Continue** — work through the current section; update `PROGRESS.md` as discoveries are made
6. **Wrap up** — refresh "next session" before stopping

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

- Update `## Next session` — first action and context that would otherwise be lost
- Mark completed tasks; move done sections toward `## Archived milestones`
- Do not leave `PROGRESS.md` in a half-updated state
