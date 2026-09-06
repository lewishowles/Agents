---
# Generated — edit skill.json and SKILL.body.md instead.
name: project-continue
displayName: Project continue
description: >
  Use this skill to resume work from the progress CLI's task, chunk, and handoff records; compacts stale context, verifies completed work, and picks up where the last session left off.
related-skills:
  - project-compact-progress
---
# Project continue

Resume from the `progress` CLI records, with optional root-level `PROGRESS.md` freeform prose when present.

## Progress records

The `progress` CLI stores the current project, release, task, chunk, discovery, decision, and handoff records. Run `progress next --json` at startup to identify the active task and chunk. Use `progress context get --json` when the current handoff needs more detail.

`PROGRESS.md`, when present, is optional root-level freeform backlog prose. Do not use it as a fallback for task, chunk, queue, release, discovery, decision, or handoff state. If the `progress` project binding is missing or uninitialised, report the explicit error, inspect `AGENTS.md`, `WORKSPACE.md`, package scripts, and nearby docs for safe local context, and ask the user to initialise or install `progress` before writing progress records. Use the full task and chunk contract returned by `progress next --json`.

## Command syntax

Run `progress commands` once per session to confirm the full command list; run `progress <noun> <action> --help` only when that still leaves a flag unclear. Common commands have stable signatures:

```sh
progress next --json                              # session start: active task + chunk
progress task start <task_id>                     # id is positional
progress task complete <task_id>                  # when no pending or active chunks remain
progress chunk start <chunk_id>
progress chunk complete <chunk_id>
progress discovery add --task <task_id> '<body>'  # body is positional, not --body
progress decision add --task <task_id> '<body>'   # body is positional; --supersedes <note_id> optional
progress context get --json
```

`--json` and `--database <path>` are accepted on every command.

**`progress next` selects the current item; it does not validate its scope.** Before resumed or delegated implementation begins, compare the active chunk with its incomplete siblings and stop if it overlaps or subsumes later work.

## Workspace file

Read `<project-root>/WORKSPACE.md` during startup when present. Treat it as factual source for commands, generated files, diagnostics, progress locations, expensive checks, and forbidden operations.

Do not generate a missing workspace file during resume unless the user asks for repo setup. If missing, inspect `AGENTS.md`, package scripts, and nearby docs.

If project guidance conflicts with `WORKSPACE.md`, surface the conflict and trust the workspace file for command safety and generated-file facts. Keep progress state in the CLI records.

When `<project-root>/.agent/scripts/project-diagnostics.py` exists, use `--list` for check discovery and `--check <name>` for verification. Use `--all` only when asked for broad verification.

## HCOM orchestration

When acting as an HCOM Orchestrator, use `hcom list -v` only to identify a same-repository Scout. Send that Scout one bounded request for every factual resume receipt needed, including task or chunk state, outstanding peer reports, and worktree safety. Wait for the Scout's terminal report before deciding and presenting the next task.

Do not inspect source, task state, Git state, peer transcripts, or CLI syntax directly to reconstruct the session. The Scout reports facts; the Orchestrator keeps the decision and human-facing handoff.

On continuation, and before the active chunk is delegated for the first time, obtain `progress chunk list --task <task-id> --json`. An HCOM Orchestrator includes this check in the Scout's bounded resume request instead of running it directly. Review the active chunk and every incomplete sibling using the returned position, title, description, and status. Use `progress chunk get <chunk-id> --json` only when that metadata leaves a boundary vague or suggests an overlap. If the active chunk includes work assigned to a later incomplete sibling, stop before implementation or delegation and narrow or replace it through `project-plan-task`.

## Workflow

1. **Read** — `progress context get --json` first; stop unless the next step is unclear or the task needs deeper context
2. **Compact** — repair stale or missing handoff context; remove duplicate notes and obsolete TODOs; compress completed sub-tasks to one line
3. **Verify** — spot-check recently-completed work landed
4. **Reorient** — confirm active work still fits; move to upcoming if priorities changed
5. **Present** — digest the active task record into the confirmed contract, current repository state, intended files, verification, and unknowns; the user should not need to look up another source. Apply the `project-plan-task` review-size gate to the active chunk. If it exceeds one primary review question or the soft ceiling of three substantive files, propose smaller chunks and wait for confirmation before implementation. Wait for confirmation before editing when the task has material API, behaviour, or interpretation decisions
6. **Complete the chunk plan** — compare the task contract and current discussion with its chunk records. If they reveal additional known chunk boundaries, add or update every known chunk in the same pass before implementation or delegation. Do not defer a known chunk until dispatch
7. **Continue** — work through the confirmed task; record verified discoveries and decisions with `progress discovery add` and `progress decision add` at handoff. Start with the active chunk returned by `progress next --json`, then use the first incomplete chunk when more remain. Change `ready` to `in-progress` before its first implementation step, then stop for review (changed files, verification, commit message) before the next chunk. Complete a chunk only after the user explicitly accepts that handoff; do not implement multiple chunks in one pass without the user asking for all of them
8. **Wrap up** — set the progress handoff context before stopping

## Session startup

Read only enough to orient. Stale sessions (5+ min idle) restart from scratch.

- Read the handoff from `progress context get --json`, including `current_goal`, `previous_step`, `next_step`, `standing_context`, `verify_with`, and `stop_marker`
- Verify the active task and chunk records before starting: the CLI status is the source of truth. If the task record says `done` but accepted chunks remain incomplete, complete the chunk records and task through the CLI, then update release and queue state.
- Check the handoff against the active records and worktree before following it. Treat current evidence as fresher; surface any conflict and do not execute a stale next step.
- Read active task, chunk, discovery, decision, and risk details only when needed
- Read linked feature specs only when active; skip unrelated specs
- Skip completed tasks and old records unless the current task depends on their history
- Run `git status --short` before editing to avoid overwriting work the user has not handled. Do not put its result in `PROGRESS.md`, or use it to infer task completion. Branch creation or switching is not part of task setup unless the user requests it.
- Read `WORKSPACE.md` if present before running local commands
- Surface any open question recorded on a chunk before starting that chunk, and ask it rather than quietly adopting its recommended default
- Verify incomplete tasks and chunks still fit the current scope

## Starting the next task

When user signals readiness ("next please", "let's continue", "what's next") without naming work:

Treat `progress ready` as an ordered queue. When it returns multiple tasks, use the first task. Do not offer the tasks as choices or ask which one to start unless a concrete blocker, dependency conflict, or explicit user request requires reordering.

1. **Name the task** — one sentence: what and where in the plan
2. **Explain why** — one or two sentences: what it unlocks or why it's next
3. **Summarise the contract** — include the task record's public behaviour, files, acceptance criteria, and verification in plain language
4. **Flag unknowns** — name key questions or decisions before starting
5. **Wait for confirmation** — do not start until user agrees (applies at all verbosity levels)

Keep outline short: 3–5 sentences. Give enough context to redirect without a full plan.

Skip this whole flow if the contract was already shown in the finishing-work handoff for the task just completed (see below): the readiness signal that accepted that handoff already confirms it, so start the task instead of re-presenting the contract. Use this flow only for a cold start, where no contract has been shown yet, such as a new session or a mid-session "what's next" with no prior handoff.

## Resuming delegated work

If the previous session used subagent delegation:

- Check which delegated tasks were implemented and which still need review
- Unreviewed subagent output needs the review gate (inspect against acceptance criteria) before continuing
- Do not assume subagent output is correct — verify before handing it back to the user
- Do not begin another implementation chunk until the user has accepted the previous handoff with “committed”, “continue”, “next”, or equivalent
- If delegation is no longer appropriate (remaining tasks are interdependent or small), switch back to sequential chunked work

## During the session

- Keep discoveries and decisions in mind as the session runs; add them with `progress discovery add` / `progress decision add` once at the handoff update, not as separate edits while work is ongoing
- Exception: a durable interruption — material scope change, blocker, or user decision that changes the next session's safe action — is worth recording immediately, since it prevents a future session from repeating costly investigation
- Treat the active task record as a prospective execution contract, not a session log. Change it through the progress CLI only when a material decision changes its outcome, affected files, verification, status, or risk.
- Keep investigation notes, failed attempts, command output, reviewer receipts, and completion recaps out of the task record. Put only the latest result needed to resume in the compact progress handoff; keep durable discoveries and decisions in their CLI records.
- Update "files likely to change" if the scope shifts
- If a task reveals unexpected complexity, add a risk entry before continuing

## Finishing work

Finishing work includes completing the accepted progress CLI records and setting the handoff context. Do not leave either to the next session.

Make one Edit/Write call covering every section below, not a separate call per bullet.

- Keep implementation detail in the progress chunk records. These records capture implementation detail, not interim-commit acceptance.
- When implementation for a chunk is finished, refresh the compact handoff with the last state change, the verification outcome in one clause, and the first next action. Do not list implementation details or individual checks. Leave the chunk and task `in-progress` until the user explicitly accepts it with “committed”, “continue”, “next”, or equivalent. Then complete the chunk with `progress chunk complete <chunk-id>`. If another chunk remains, resume from it later. After the final chunk is accepted, mark the task done with `progress task complete <task-id>` when no pending or active chunks remain. Update release and queue state through `progress release` and `progress task move` as needed. Do not archive completion in `PROGRESS.md`.
- Set `previous_step` to the last state change and, when it affects continuation, a concise verification outcome using `progress context set`
- Set `next_step` with the first concrete follow-up action using `progress context set`
- Put unresolved facts and constraints in `standing_context`. Put the interruption, blocker, or in-flight command and its known state in `stop_marker`; state clearly when nothing is interrupted or nothing remains.
- Update release status and queue order through `progress release` and `progress task move` when a release's last task lands as done
- If nothing remains for the current goal, say that clearly in the handoff instead of leaving stale TODOs
- Compact now if the project keeps root-level `PROGRESS.md` prose and it has grown significantly; current context makes it cheaper

Before setting the handoff context, distil what was learned: add verified facts with `progress discovery add --task <task-id> "<note>"`, choices with `progress decision add --task <task-id> "<note>"`, and record failed approaches in the task record or linked spec only when they will help future work. Add only what isn't already captured.

After running `progress context set`, do not print or paraphrase its fields. Outside a tool-call checkpoint, present this acceptance packet before offering to continue:

1. **What changed** — 1–3 sentences: what was done and what was verified (or skipped and why)
2. **What's next** — if a task is already queued in the progress records, give its full contract now, not just its name: what it is, why it's next, files, acceptance criteria, and verification, the same detail as "Starting the next task" step 3. If nothing is queued yet, name the open question or say so.
3. **Wait** — do not start the next chunk until the user confirms. The contract is already in front of them, so that confirmation both accepts the finished task and greenlights the next; don't make them confirm a second time once the contract is re-presented.

Never say "ready to move on to X" without this context. User needs enough to redirect.

## Wrapping up

- Set the progress handoff context with the current goal, previous step, next step, verification, and stop guidance using `progress context set`
- Complete user-accepted tasks per the flow above: mark CLI chunks and tasks done, and update release and queue state. Do not recreate an archive section in `PROGRESS.md`.
- If a dead end needs preserving, record one line in the active task record or linked spec: `Approach X failed because Y; don't retry`. Omit it when nothing failed.
- Do not leave the progress CLI records or handoff context half-updated
