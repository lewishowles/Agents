---
# Generated — edit skill.json and SKILL.body.md instead.
name: project-compact-progress
displayName: Project compact progress
description: >
  Use this skill to refactor a growing PROGRESS.md — removes noise, preserves decisions and discoveries, and rewrites active sections for clarity.
---
# Project compact progress

Use this skill to clean a growing `PROGRESS.md` that is noisy or hard to scan. Preserve what matters, remove what doesn't, and clarify active sections.

## File location

`PROGRESS.md` lives at the **project root** — not in `.claude/`. Always look for `<project-root>/PROGRESS.md` first. Do not assume `.claude/PROGRESS.md`.

## What to preserve

- `## Session handoff` — keep this at the top and make it accurate
- Decisions — especially rationale that would otherwise be re-debated
- Discoveries — unexpected findings that affect current or future work
- Completed milestones — brief summary only; move detail to `## Archived milestones`

## What to remove

- Duplicate notes appearing in multiple sections
- Resolved risks and obsolete TODOs
- Stale investigations that led nowhere
- Implementation details already visible in the code

## What to rewrite

- `## Session handoff` — first section in the file; scannable in 30 seconds
- `### Current goal` — one sentence; update if the goal has shifted
- `### Previous step` — what changed most recently, with verification when useful
- `### Next step` — the first concrete action for the next session
- `### Stop here` — preserve guidance to stop reading unless deeper context is needed
- `## Parking lot` — remove items that are no longer relevant; promote items that have become urgent

## Handoff-first format

If the file does not already start with `## Session handoff`, create it above the deeper sections. Agents should be able to read from the top and stop after the handoff when it gives enough context.

```markdown
## Session handoff

Read this section first. Stop after this section unless the task needs deeper context.

### Current goal

### Previous step

### Next step

### Stop here

Only continue reading if the next step is unclear, the user asks for planning/review/history, or implementation needs decisions, discoveries, risks, or file lists below.
```

## Refresh file lists

If scope changed, update "files likely to change" in the current section.

## Finishing work

When compacting after work finishes, treat the work as incomplete unless the handoff is refreshed. Mark completed tasks, update `### Previous step`, set the next concrete action in `### Next step`, and archive or remove stale active notes.

## When to run

Run compact-progress when:

- `PROGRESS.md` is over ~150 lines and hard to scan
- The current section has grown unwieldy with resolved tasks
- Returning to a project after a gap and the document feels stale
- Before starting a new section with a clean context

## Relationship with archive-progress

Compact-progress cleans in place. Use `archive-progress` to move large completed sections out of the main document.
