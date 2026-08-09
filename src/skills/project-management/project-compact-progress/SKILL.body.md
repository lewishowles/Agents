# Project compact progress

Reduce noisy or hard-to-scan `PROGRESS.md`. Cut words aggressively without losing context, decisions, meaning, or next concrete action.

## File location

`PROGRESS.md` lives at **project root**, not `.claude/`. Look for `<project-root>/PROGRESS.md` first.

## What to preserve

- `## Session handoff` — keep at top, make accurate
- `## Roadmap` table — keep intact; task front matter references its IDs. Update row Status rather than deleting rows.
- Upcoming queue — reconcile the table's Release/Status columns against task front matter (front matter wins); drop done tasks from the queue
- Decisions still relevant to active or upcoming work, with rationale (prevent re-debate)
- Discoveries still affecting current or future work
- Completed milestones: brief summary; move detail to `## Archived milestones`
- **Future roadmap with concrete tasks** — do not collapse to one-liner. Archive only when complete.
- **Acceptance criteria** — preserve verbatim, even when compressing nearby prose
- **Spec links** — preserve; ensure each explains why work matters

## What to remove

- Duplicate notes appearing in multiple sections
- Resolved risks and obsolete TODOs
- Stale investigations that led nowhere
- Implementation details already visible in the code
- Wording that explains process without preserving a decision, result, blocker, or next action
- Archived milestone entries whose roadmap release has shipped — `## Archived milestones` is release-scoped, not a permanent log; drop entries once the release closes
- `## Decisions`/`## Discoveries` entries that have become durable, cross-session facts and haven't been promoted yet — propose the smallest `AGENTS.md` entry, then remove here once approved
- `## Decisions`/`## Discoveries` entries that are now moot — superseded, already visible in shipped code/docs/metadata, or resolved by a decision recorded elsewhere — remove outright, no promotion needed. These two sections are release-scoped like `## Archived milestones`, not a permanent log; an entry that's neither still-active nor worth promoting shouldn't linger just because nobody swept it
- Spec files in `.agent/specs/` that may no longer be active — list every file, check whether each is referenced by a `### Spec` link in active `PROGRESS.md` sections, then inspect enough to explain its real status. Do not flag a spec only because it is unlinked. For each, state whether it appears completed, superseded, partly future-facing, or unclear; give the reason; recommend keep, archive, link from active work, or ask. Do not delete silently.

## Compression target

Optimise for context density — reduce words, not meaning.

- One precise sentence over a paragraph
- Replace history with outcome, evidence, and implication
- Collapse completed tasks to one summary
- Keep names, paths, commands, dates, decisions, risks, blockers exact
- Preserve enough context to continue without re-discovery
- Avoid cryptic, jokey, or persona-driven wording

## What to rewrite

- `## Session handoff` — first section; scannable in 30 seconds
- `### Current goal` — one sentence; update if the goal has shifted
- `### Previous step` — what changed most recently, with verification when useful
- `### Next step` — the first concrete action for the next session
- `### Context` — project-specific patterns, commands, or constraints needed for next step; omit when AGENTS.md and project skills suffice
- `### Verify with` — the scoped command to confirm the step is complete; omit when there is no automated check
- `### Stop here` — preserve guidance to stop reading unless deeper context is needed
- `## Parking lot` — remove stale items; promote urgent items

## Splitting into specs

When a future section has grown large with rationale, alternatives, acceptance criteria, API sketches, or risk analysis, move heavy context into `.agent/specs/<feature>.md`. Keep `PROGRESS.md` as execution tracker with short `### Spec` link.

Do not split small changes into specs. Use specs for larger spikes or ambiguous features where future agents need deeper context only when the feature is active.

Spec files should keep this outline:

```markdown
# <Feature or spike name>

## Why now

## Problem

## Goals

## Current status

## Non-goals

## Proposed approach

## Entry point

## Files to inspect

## API, schema, or interface

## Decisions

## Open questions

## Acceptance criteria

## Risks

## Verification
```

## Extracting inline sections into task files

Inline `PROGRESS.md` sections exist only for genuinely trivial work: a single item, nothing left to decide. During compaction, move any inline section that has grown past that, multiple tasks, unresolved decisions, or its own file list, into `.agent/tasks/<task-slug>.md` (see `project-plan-task`'s "Task files vs progress sections"). Point the queue entry at the new file; don't leave both an inline section and a task file describing the same work. Leave a genuinely trivial section inline; don't create a file just to satisfy this rule.

## Handoff-first format

If missing `## Session handoff`, create it at top. Agents read from top and stop after handoff when it has enough context.

```markdown
## Session handoff

Read first. Stop after this unless task needs deeper context.

### Current goal

### Previous step

### Next step

### Context

Project-specific patterns, scaffold commands, constraints needed for next step. Omit if AGENTS.md and loaded skills suffice.

### Verify with

Scoped command confirming step completion. Single line; pipe through `tail -5` or equivalent. Omit if no automated check.

### Stop here

Only continue if next step is unclear, user asks for planning/review/history, or implementation needs decisions/discoveries/risks/file lists below.
```

## Populating Context and Verify with

`### Context` is not Discoveries summary; it is the minimum a fresh agent needs to _execute the next step correctly_ without reading below `### Stop here`. Populate when:

- The next step uses a project-specific scaffold command or CLI tool
- A known constraint would silently produce wrong output, e.g. slot format restrictions or attribute value quirks
- A co-location or naming convention differs from the global skill default

Keep 3–5 bullets. Omit bullets obvious from AGENTS.md.

`### Verify with` should be one runnable command scoped to changed file/path, not full suite. Pipe output: `2>&1 | tail -5`. Goal: one-line pass/fail check without large output.

## Refresh file lists

If scope changed, update "files likely to change" in the current section.

## Finishing work

After work finishes, refresh the handoff: tick verified implementation steps, update `### Previous step`, and state that the task awaits the user's acceptance. Mark a task complete, promote the queue, or archive it only after the user says “committed”, “continue”, “next”, or equivalent.

## Archive mode

Archive when completed work makes active work hard to find. Task files are deleted at completion time (see `project-plan-task`), so archiving here mostly applies to inline sections and pre-task-file history; a milestone-level summary line in `## Archived milestones` is still worth adding when a whole release lands, and should itself be pruned once that release ships.

Archive completed sections when:

- Tasks are done after the user accepted their handoff
- Section no longer affects current or upcoming work
- Detailed implementation notes are redundant with the code
- New major phase starts and old phases are settled

Do not archive:

- `## Session handoff`
- Decisions preventing re-debate
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

Run when:

- `PROGRESS.md` is over ~150 lines and hard to scan
- The current section has grown unwieldy with resolved tasks
- Returning to a project after a gap and the document feels stale
- Before starting a new section with a clean context
- Completed sections make active work hard to find
- Several features have been archived and their `.agent/specs/` files may now be stale
