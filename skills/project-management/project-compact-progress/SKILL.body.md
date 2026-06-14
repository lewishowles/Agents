# Project compact progress

Use this skill to clean a growing `PROGRESS.md` that is noisy or hard to scan. Preserve what matters, remove what doesn't, and clarify active sections.

## File location

`PROGRESS.md` lives at the **project root** — not in `.claude/`. Always look for `<project-root>/PROGRESS.md` first. Do not assume `.claude/PROGRESS.md`.

## What to preserve

- Decisions — especially rationale that would otherwise be re-debated
- Discoveries — unexpected findings that affect current or future work
- Completed milestones — brief summary only; move detail to `## Archived milestones`

## What to remove

- Duplicate notes appearing in multiple sections
- Resolved risks and obsolete TODOs
- Stale investigations that led nowhere
- Implementation details already visible in the code

## What to rewrite

- `## Current goal` — one sentence; update if the goal has shifted
- `## Next session` — first action; scannable in 30 seconds
- `## Parking lot` — remove items that are no longer relevant; promote items that have become urgent

## Refresh file lists

If scope changed, update "files likely to change" in the current section.

## When to run

Run compact-progress when:

- `PROGRESS.md` is over ~150 lines and hard to scan
- The current section has grown unwieldy with resolved tasks
- Returning to a project after a gap and the document feels stale
- Before starting a new section with a clean context

## Relationship with archive-progress

Compact-progress cleans in place. Use `archive-progress` to move large completed sections out of the main document.
