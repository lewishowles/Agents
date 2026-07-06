# Project compact progress

Reduce noisy or hard-to-scan `PROGRESS.md`. Cut words aggressively without losing context, decisions, meaning, or next concrete action.

## File location

`PROGRESS.md` lives at **project root**, not `.claude/`. Look for `<project-root>/PROGRESS.md` first.

## What to preserve

- `## Session handoff` — keep this at the top and make it accurate
- Decisions, especially rationale that would otherwise be re-debated
- Discoveries — unexpected findings that affect current or future work
- Completed milestones: brief summary only; move detail to `## Archived milestones`
- **Future roadmap sections with concrete task lists** — do not collapse to one-liner. If tasks are not done, detail is the point. Archive only once complete.
- **Acceptance criteria** — constraints, not narrative. Preserve verbatim even when compressing nearby prose.
- **Spec links** — preserve links from `PROGRESS.md` to specs and ensure each linked spec still explains why work matters.

## What to remove

- Duplicate notes appearing in multiple sections
- Resolved risks and obsolete TODOs
- Stale investigations that led nowhere
- Implementation details already visible in the code
- Wording that explains process without preserving a decision, result, blocker, or next action
- Spec files in `.agent/specs/` that may no longer be active — list every file, check whether each is referenced by a `### Spec` link in active `PROGRESS.md` sections, then inspect enough to explain its real status. Do not flag a spec only because it is unlinked. For each, state whether it appears completed, superseded, partly future-facing, or unclear; give the reason; recommend keep, archive, link from active work, or ask. Do not delete silently.

## Compression target

Optimise for context density — reduce words, not meaning. Keep normal professional prose.

- Prefer one precise sentence over a paragraph
- Replace narrative history with outcome, evidence, and current implication
- Collapse completed task lists into one outcome summary
- Keep names, paths, commands, dates, decisions, risks, and blockers exact
- Preserve enough context for next agent to continue without re-discovery
- Do not make the file cryptic, jokey, or persona-driven

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

## Handoff-first format

If file does not start with `## Session handoff`, create it above deeper sections. Agents read from top and stop after handoff when it gives enough context.

```markdown
## Session handoff

Read this section first. Stop after this section unless the task needs deeper context.

### Current goal

### Previous step

### Next step

### Context

Project-specific patterns, scaffold commands, or known constraints needed for next step. Omit if AGENTS.md and loaded skills are enough.

### Verify with

Scoped command to confirm step completion. Single line; pipe through `tail -5` or equivalent. Omit if no automated check.

### Stop here

Only continue reading if the next step is unclear, the user asks for planning/review/history, or implementation needs decisions, discoveries, risks, or file lists below.
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

After work finishes, treat work as incomplete unless handoff is refreshed. Mark completed tasks, update `### Previous step`, set next concrete action in `### Next step`, archive/remove stale active notes.

## Archive mode

Archive when completed work makes active work hard to find.

Archive completed sections when:

- Tasks are done and the commit has landed
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
