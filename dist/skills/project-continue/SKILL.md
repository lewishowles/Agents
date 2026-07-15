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

The canonical location is `<project-root>/PROGRESS.md`. Read from the root first. For legacy or other-tool setups, fall back to these in order and use the first match:

1. `<project-root>/PROGRESS.md`
2. `<project-root>/.claude/PROGRESS.md`
3. `<project-root>/.agents/PROGRESS.md`

Only ever create a new file at the project root — never create a `.claude/` or `.agent/` copy. If none exist, say so and ask where to create one, defaulting to the root.

## Workspace file

Read `<project-root>/WORKSPACE.md` during startup when present. Treat it as factual source for commands, generated files, diagnostics, progress locations, expensive checks, and forbidden operations.

Do not generate a missing workspace file during resume unless the user asks for repo setup. If missing, inspect `AGENTS.md`, package scripts, and nearby docs.

If `PROGRESS.md` conflicts with `WORKSPACE.md`, surface the conflict and trust the workspace file for command safety and generated-file facts. Update `PROGRESS.md` to reflect those facts.

When `<project-root>/.agent/scripts/project-diagnostics.py` exists, use `--list` for check discovery and `--check <name>` for verification. Use `--all` only when asked for broad verification.

## Workflow

1. **Read** — `## Session handoff` first; stop unless next step is unclear or task needs deeper context
2. **Compact** — repair stale/missing handoff; remove duplicate notes and obsolete TODOs; compress completed sub-tasks to one line
3. **Verify** — spot-check recently-completed work landed
4. **Reorient** — confirm active work still fits; move to upcoming if priorities changed
5. **Present** — digest the active task file into the confirmed contract, current repository state, intended files, verification, and unknowns; the user should not need to open the task file. Wait for confirmation before editing when the task has material API, behaviour, or interpretation decisions
6. **Continue** — work through confirmed task; update `PROGRESS.md` as discoveries emerge
7. **Wrap up** — refresh handoff before stopping

## Session startup

Read only enough to orient. Stale sessions (5+ min idle) restart from scratch.

- Read full `## Session handoff` (all subsections above `### Stop here`, including `### Context` and `### Verify with`)
- Verify the active task file's front matter before starting it: `status` and `completed` are the source of truth and can change outside a session (work reviewed, committed, or marked done from Boilersuit's Progress tab). If the active task is already `done`, promote the next queue entry instead of redoing it; if the queue annotation disagrees with front matter, trust front matter and fix the queue line.
- Continue to `## Active work`, `## Decisions`, `## Discoveries`, `## Risks` only when needed
- Read linked feature specs only when active; skip unrelated specs
- Skip completed or archived sections unless current task depends on their history
- Inspect repository state and any branch or uncommitted-work claims in the task file. Branch creation or switching is not part of task setup unless the user requests it.
- Read `WORKSPACE.md` if present before running local commands
- Verify unfinished tasks belong to current section

## Starting the next task

When user signals readiness ("next please", "let's continue", "what's next") without naming work:

1. **Name the task** — one sentence: what and where in the plan
2. **Explain why** — one or two sentences: what it unlocks or why it's next
3. **Summarise the contract** — include the task file's public behaviour, files, acceptance criteria, and verification in plain language
4. **Flag unknowns** — name key questions or decisions before starting
5. **Wait for confirmation** — do not start until user agrees (applies at all verbosity levels)

Keep outline short: 3–5 sentences. Give enough context to redirect without a full plan.

## Resuming delegated work

If the previous session used subagent delegation:

- Check which tasks were completed and committed vs delegated but not yet reviewed
- Unreviewed subagent output needs the review gate (inspect against acceptance criteria) before continuing
- Do not assume subagent output is correct — verify before committing
- Do not delegate or begin another implementation chunk while an earlier source-change chunk remains uncommitted, even when the files are independent
- If delegation is no longer appropriate (remaining tasks are interdependent or small), switch back to sequential chunked work

## During the session

- Record discoveries under `## Discoveries` as they happen
- Record decisions under `## Decisions` as they are made — one line: what was decided and why
- Update "files likely to change" if the scope shifts
- If a task reveals unexpected complexity, add a risk entry before continuing

## Finishing work

Finishing work includes updating `PROGRESS.md` and giving handoff. Do not leave either to next session.

- Tick completed `## Tasks` checkboxes in the active task file (or completed tasks in an inline `## Active work` section)
- When the active task is finished, keep the file: set `status: done` and `completed: <date>` in front matter, append a short `## Outcome` section (what landed, how it was verified), remove it from the upcoming queue, and promote the next entry into the active slot
- Update `### Previous step` with what just changed and any verification performed
- Update `### Next step` with the first concrete follow-up action
- Update the `## Roadmap` row Status when a release becomes active or its last task lands as done
- If nothing remains for the current goal, say that clearly in the handoff instead of leaving stale TODOs
- Compact now if `PROGRESS.md` has grown significantly; current context makes it cheaper

Before updating `PROGRESS.md`, distil what was learned: what belongs in `## Discoveries` (facts about the codebase or environment), what belongs in `## Decisions` (choices made and why), and whether any dead ends should be recorded in `### Failed approaches` under the current section. Add only what isn't already captured.

After updating `PROGRESS.md`, show brief handoff before offering to continue:

1. **What changed** — 1–3 sentences: what was done and what was verified (or skipped and why)
2. **What's next** — same format as "Starting the next task": name it, explain why it's next
3. **Wait** — do not start the next chunk until the user confirms

Never say "ready to move on to X" without this context. User needs enough to redirect.

## Wrapping up

- Update `## Session handoff` — current goal, previous step, next step, and stop guidance
- Complete finished tasks per the flow above (front matter, `## Outcome`, queue); move done inline sections toward `## Archived milestones`
- Add `### Failed approaches` under the current section when a dead end occurred — one line per entry: `Approach X failed because Y; don't retry`. Omit when nothing failed.
- Do not leave `PROGRESS.md` in a half-updated state
