# Project compact progress

Use this skill to reduce a growing `PROGRESS.md` that is noisy or hard to scan. Cut word count aggressively without losing context, decisions, meaning, or the next concrete action.

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
- Wording that explains process without preserving a decision, result, blocker, or next action

## Compression target

Optimise for context density, like caveman-style compression, but keep normal professional prose. Reduce words first; do not reduce meaning.

- Prefer one precise sentence over a paragraph
- Replace narrative history with outcome, evidence, and current implication
- Collapse completed task lists into one outcome summary
- Keep names, paths, commands, dates, decisions, risks, and blockers exact
- Preserve enough context for the next agent to continue without re-discovery
- Do not make the file cryptic, jokey, or persona-driven

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

## Archive mode

Archiving is part of compacting when completed work is making active work hard to find.

Archive completed sections when:

- Tasks are done and the commit has landed
- The section is no longer relevant to current or upcoming work
- Detailed implementation notes are redundant with the code
- Starting a new major phase and old phases are settled

Do not archive:

- `## Session handoff`
- Decisions that prevent re-debating resolved questions
- Discoveries that still affect active work
- Anything needed to resume the current section

To archive:

1. Summarise the completed section in 1–3 bullet points
2. Move the summary to `## Archived milestones` with a date stamp
3. Delete the full section from the main document
4. Update `## Session handoff` so `### Previous step` and `### Next step` reflect the new state

```markdown
## Archived milestones

### <Section name> — <YYYY-MM-DD>

- Brief summary of what was delivered
- Key decision or discovery worth keeping
```

## When to run

Run compact-progress when:

- `PROGRESS.md` is over ~150 lines and hard to scan
- The current section has grown unwieldy with resolved tasks
- Returning to a project after a gap and the document feels stale
- Before starting a new section with a clean context
- Completed sections make active work hard to find
