---
name: session-management
description: >
  Use this skill when saving or resuming Claude Code sessions, starting meaningful multi-session work, or tracking progress across sessions.
related-skills:
  - code-style
---

# Session management

## Built-in save/resume

Claude Code can snapshot and restore session state:

```
/save-session "feature: add dark mode toggle"
/resume-session
```

Saves conversation history, recently opened files, and task context. Use for long tasks, complex refactors, or any work you'll pick up later. Name sessions descriptively — "fix: auth bug in login flow" not "work on stuff".

Old snapshots may auto-clean. For permanent records, commit to git instead.

## PROGRESS.md — tracking meaningful work

For multi-file, multi-session, or significant-scope work, maintain a `PROGRESS.md` in the project's `.claude/` directory. This is the persistent record that survives session changes.

**When starting work:**

1. Check for `.claude/PROGRESS.md`
2. If present — read it before doing anything else; it has architecture, decisions, and session history
3. If absent and the work is significant — create it from `.claude/templates/PROGRESS.md.template`

**Structure:**

```markdown
# [Work title]

**Started:** [date] **Status:** planning | in-progress | blocked | complete

## Legend

- `[ ]` not started `[~]` in progress `[x]` done `[-]` skipped

## Phase 1 — [name]

- [ ] **1.1 Step** — verify: [how to confirm done]
- [x] **1.2 Step** — actual outcome if it diverged from plan

## Purpose / Context / Architecture / Key files / Decisions

[reference sections — keep these below the checklist]

## Validation

[observable outcomes that confirm the work is complete]

## Discoveries

[unexpected findings, hidden constraints, useful insights — add as you go]

## Session notes

### [Date]

**Completed:** [tasks done] **Next:** [what to pick up]
```

**Keep it live**: Update PROGRESS.md after every significant change, decision, or scope shift — don't wait until session end. This ensures the handoff between sessions is clear:

- Mark checklist items done as they complete
- Record new architectural decisions or constraint discoveries
- Update Phase descriptions if requirements evolve or scope expands
- Append session notes after finishing each logical chunk of work

The pattern: work in **committable chunks** — pieces that are coherent and can be reviewed together (e.g. a feature, bugfix, refactor, or documentation update). After each chunk:

1. Update PROGRESS.md with what you completed
2. Provide a commit message (e.g. `feat(component): add support for X`) — document it, don't execute it
3. Stop and summarise what you did and what's next

When starting the next chunk after the user confirms the previous chunk is reviewed or committed, compact older completed PROGRESS.md detail into short human-readable summaries. Keep decisions, constraints, user-visible test notes, and unresolved follow-ups. Remove blow-by-blow implementation notes that are no longer needed for future work.

This keeps PROGRESS.md in sync with the actual work and makes it trivial to pick up mid-stream in a new session.

## Token efficiency

- Skip plan mode for single-file, single-line, or trivial edits (<20 lines)
- Batch edits in one session — amortise system context across multiple changes
- Try `grep`/`find` first before spawning agents for targeted lookups

## Goal-driven execution

Transform tasks into verifiable goals before starting:

- "Add validation" → write tests, make them pass
- "Fix bug" → reproduce with test, make it pass
- "Refactor X" → tests pass before and after

Multi-step tasks: state plan with verification:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
```

Strong criteria = independent loops. Weak criteria = constant clarification.

**Completed (session 8):** Removed repo-managed references to the memory plugin ahead of uninstall, including settings, templates, docs, credits, and session-management recommendations
**Validation:** pending local checks after memory plugin cleanup
**Next:** Commit cleanup work or revisit deferred hooks
