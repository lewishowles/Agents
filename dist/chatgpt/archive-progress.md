---
# Generated — edit skill.json and SKILL.body.md instead.
name: archive-progress
description: >
  Use this skill to reduce the size of a long-running PROGRESS.md by moving completed sections into an archived milestones block at the bottom.
related-skills:
  - compact-progress
---
# Archive progress

Use this skill to reduce the size of a long-running `PROGRESS.md` by moving completed sections into an `## Archived milestones` block. Keeps active work small and easy to scan without losing the project history.

## What to archive

- Fully completed sections where all tasks are done and the commit has landed
- Sections that are no longer relevant to current or upcoming work
- Detailed implementation notes that are now redundant with the code

## What not to archive

- Decisions — keep these in `## Decisions` permanently; they prevent re-debating resolved questions
- Discoveries — keep these if they still affect active work
- Anything that would be needed to resume the current section

## How to archive

1. Summarise the completed section in 1–3 bullet points
2. Move the summary to `## Archived milestones` with a date stamp
3. Delete the full section from the main document

```markdown
## Archived milestones

### <Section name> — <YYYY-MM-DD>

- Brief summary of what was delivered
- Key decision or discovery worth keeping
```

## When to run

Run archive-progress when:

- The document is over ~200 lines and most of it is done work
- Completed sections are making it hard to find active work
- Starting a new major phase and the old phases are fully settled

## Relationship with compact-progress

Compact-progress cleans and condenses; archive-progress moves. They can be run together — compact first, then archive — or separately depending on what the document needs.
