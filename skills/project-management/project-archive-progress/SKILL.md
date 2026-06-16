---
# Generated — edit skill.json and SKILL.body.md instead.
name: project-archive-progress
displayName: Project archive progress
description: >
  Use this skill to reduce the size of a long-running PROGRESS.md by moving completed sections into an archived milestones block at the bottom.
related-skills:
  - project-compact-progress
---
# Project archive progress

Use this skill to shrink a long-running `PROGRESS.md` by moving completed sections into `## Archived milestones`. Keep active work small without losing history.

## File location

`PROGRESS.md` lives at the **project root** — not in `.claude/`. Always look for `<project-root>/PROGRESS.md` first. Do not assume `.claude/PROGRESS.md`.

## What to archive

- Completed sections where tasks are done and the commit has landed
- Sections that are no longer relevant to current or upcoming work
- Detailed implementation notes that are now redundant with the code

## What not to archive

- `## Session handoff` — keep it at the top and update it after archiving
- Decisions — keep in `## Decisions`; they prevent re-debating resolved questions
- Discoveries — keep these if they still affect active work
- Anything needed to resume the current section

## How to archive

1. Summarise the completed section in 1–3 bullet points
2. Move the summary to `## Archived milestones` with a date stamp
3. Delete the full section from the main document
4. Update `## Session handoff` so `### Previous step` reflects the archived work when it was the latest meaningful change, and `### Next step` points to the next concrete action

```markdown
## Archived milestones

### <Section name> — <YYYY-MM-DD>

- Brief summary of what was delivered
- Key decision or discovery worth keeping
```

## When to run

Run archive-progress when:

- The document is over ~200 lines and most of it is done work
- Completed sections make active work hard to find
- Starting a new major phase and the old phases are fully settled

## Relationship with compact-progress

Compact-progress cleans in place; archive-progress moves sections. Run together when useful: compact first, then archive.
