# Project compact progress

Use this skill to reduce a growing `PROGRESS.md` that is noisy or hard to scan. Cut word count aggressively without losing context, decisions, meaning, or the next concrete action.

## File location

`PROGRESS.md` lives at the **project root** — not in `.claude/`. Always look for `<project-root>/PROGRESS.md` first. Do not assume `.claude/PROGRESS.md`.

## What to preserve

- `## Session handoff` — keep this at the top and make it accurate
- Decisions — especially rationale that would otherwise be re-debated
- Discoveries — unexpected findings that affect current or future work
- Completed milestones — brief summary only; move detail to `## Archived milestones`
- **Future roadmap sections with concrete task lists** — do not collapse these into a one-liner. If the tasks are not done, the detail is the point. Only archive a roadmap section once it is complete.
- **Acceptance criteria** — these are constraints, not narrative. Preserve them verbatim even when compressing surrounding prose.
- **Spec links** — preserve links from `PROGRESS.md` to feature specs and make sure each linked spec still explains why the work matters.

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
- `### Context` — project-specific patterns, commands, or constraints needed for the next step; omit when AGENTS.md and project skills are sufficient
- `### Verify with` — the scoped command to confirm the step is complete; omit when there is no automated check
- `### Stop here` — preserve guidance to stop reading unless deeper context is needed
- `## Parking lot` — remove items that are no longer relevant; promote items that have become urgent

## Splitting into specs

When a future section has grown large because it contains feature rationale, alternatives, acceptance criteria, API sketches, or risk analysis, move that heavy context into a per-feature spec such as `.agent/specs/<feature>.md`. Keep `PROGRESS.md` as the execution tracker and add a short `### Spec` link to the section.

Do not split small changes into specs. Use specs for larger spikes or ambiguous features where future agents should read the deeper context only when that feature is active.

Spec files should keep this outline:

```markdown
# <Feature or spike name>

## Why now

## Problem

## Goals

## Non-goals

## Proposed approach

## API, schema, or interface

## Acceptance criteria

## Risks

## Verification
```

## Handoff-first format

If the file does not already start with `## Session handoff`, create it above the deeper sections. Agents should be able to read from the top and stop after the handoff when it gives enough context.

```markdown
## Session handoff

Read this section first. Stop after this section unless the task needs deeper context.

### Current goal

### Previous step

### Next step

### Context

Project-specific patterns, scaffolding commands, or known constraints needed for the next step. Omit if the next step needs nothing beyond AGENTS.md and the loaded skills.

### Verify with

The scoped command to confirm the step is complete. Single line; pipe through `tail -5` or equivalent to avoid flooding context. Omit if there is no automated check.

### Stop here

Only continue reading if the next step is unclear, the user asks for planning/review/history, or implementation needs decisions, discoveries, risks, or file lists below.
```

## Populating Context and Verify with

`### Context` is not a summary of Discoveries — it is the minimum a fresh agent needs to _execute the next step correctly_ without reading below `### Stop here`. Populate it when:

- The next step uses a project-specific scaffold command or CLI tool
- There is a known constraint that would silently produce wrong output (e.g. slot format restrictions, attribute value quirks)
- A co-location or naming convention differs from the global skill default

Keep it to 3–5 bullets. If a bullet would be equally obvious from AGENTS.md, omit it.

`### Verify with` should be a single runnable command scoped to the changed file or path, not a full suite. Pipe output to suppress noise: `2>&1 | tail -5`. The goal is a one-line pass/fail check the next agent can run without printing large output to context.

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
