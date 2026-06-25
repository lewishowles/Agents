---
# Generated — edit skill.json and SKILL.body.md instead.
name: project-continue
displayName: Project continue
description: >
  Use this skill to resume work from an existing PROGRESS.md — compacts stale notes, verifies completed work, and picks up from where the last session left off.
related-skills:
  - project-compact-progress
---
# Project continue

Resume from existing `PROGRESS.md`. Treat it as living record, not perfect truth; update during session.

## File location

Look in this order and use the first match:

1. `<project-root>/PROGRESS.md`
2. `<project-root>/.claude/PROGRESS.md`
3. `<project-root>/.agents/PROGRESS.md`

If none exist, say so and ask where to create one.

## Workspace file

Read `<project-root>/WORKSPACE.md` during startup when present. Treat it as factual source for commands, generated files, diagnostics, progress locations, expensive checks, and forbidden operations.

Do not generate missing workspace file during resume unless user asks for repo setup or new manifest. If missing, inspect `AGENTS.md`, package scripts, and nearby docs.

If `PROGRESS.md` conflicts with `WORKSPACE.md`, surface the conflict and trust the workspace file for command safety and generated-file facts. Update `PROGRESS.md` when the plan needs to reflect those facts.

When `<project-root>/.agent/scripts/project-diagnostics.py` exists, use `--list` for check discovery and `--check <name>` for verification. Use `--all` only when asked for broad verification.

## Workflow

1. **Read** — read `## Session handoff` first, then stop unless next step is unclear or task needs deeper context
2. **Compact** — repair a stale or missing handoff before continuing; remove duplicate notes and obsolete TODOs; compress completed sub-tasks to a single line
3. **Verify** — spot-check that recently-completed work landed
4. **Reorient** — confirm the active work still fits; move it to upcoming if priorities changed
5. **Present** — state the next task (name, why, any unknowns) and wait for the user to confirm before starting; do not skip this even when the next step is explicit in `PROGRESS.md`
6. **Continue** — work through the confirmed task; update `PROGRESS.md` as discoveries are made
7. **Wrap up** — refresh the handoff before stopping

## Session startup

Before new work, read only enough to orient:

- Read full `## Session handoff` — every subsection above `### Stop here`, including `### Context` and `### Verify with`
- Continue into `## Active work`, `## Decisions`, `## Discoveries`, or `## Risks` only when needed
- If active section links a feature spec, read it only when needed; do not read unrelated specs
- Do not read completed or archived sections unless the current task depends on their history
- Confirm branch state and any uncommitted work
- Read `WORKSPACE.md` if it exists before running local commands
- Verify unfinished tasks belong to the current section

## Starting the next task

When user signals readiness to move on ("next please", "let's continue", "what's next") without naming work:

1. **Name the task** — one sentence: what it is and where it sits in the plan
2. **Explain why** — one or two sentences on what it unlocks or why it is next
3. **Flag unknowns** — if approach is not obvious, name key question or decision before starting
4. **Wait for confirmation** — do not start implementation until the user agrees

Keep outline short: 3–5 sentences total. Give enough context to redirect without spending tokens on a full plan.

## During the session

- Record discoveries under `## Discoveries` as they happen
- Update "files likely to change" if the scope shifts
- If a task reveals unexpected complexity, add a risk entry before continuing

## Finishing work

Finishing work includes updating `PROGRESS.md` and giving handoff. Do not leave either to next session.

- Mark completed tasks in `## Active work`
- Update `### Previous step` with what just changed and any verification performed
- Update `### Next step` with the first concrete follow-up action
- Move finished active work toward `## Archived milestones` when it no longer needs attention
- If nothing remains for the current goal, say that clearly in the handoff instead of leaving stale TODOs
- Compact now if `PROGRESS.md` has grown significantly; current context makes it cheaper

After updating `PROGRESS.md`, show brief handoff before offering to continue:

1. **What changed** — 1–3 sentences: what was done and what was verified (or skipped and why)
2. **What's next** — same format as "Starting the next task": name it, explain why it's next
3. **Wait** — do not start the next chunk until the user confirms

Never say "ready to move on to X" without this context. User needs enough to redirect.

## Wrapping up

- Update `## Session handoff` — current goal, previous step, next step, and stop guidance
- Mark completed tasks; move done sections toward `## Archived milestones`
- Do not leave `PROGRESS.md` in a half-updated state
