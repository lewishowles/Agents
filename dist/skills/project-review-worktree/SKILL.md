---
# Generated — edit skill.json and SKILL.body.md instead.
name: project-review-worktree
displayName: Project review worktree
description: >
  Use this skill when reviewing uncommitted work before commit, especially requests like "review the working tree", "check this before commit", "is this ready to commit", or "review these changes against PROGRESS.md". Assesses correctness, completeness, plan alignment, maintainability, tests, docs, and commit readiness without editing files.
related-skills:
  - code-review
---
# Project review worktree

Review uncommitted repository changes before commit. Default to review and recommendations only; do not edit files unless the user explicitly asks after the review.

## Scope

Assess whether the current working tree is:

- correct and complete for the stated task
- consistent with `PROGRESS.md` and any active handoff
- safe to commit as one coherent change
- covered by appropriate tests or verification
- aligned with project instructions, workspace facts, generated-file boundaries, and existing patterns

Look for bugs, regressions, incomplete work, weak tests, missing docs or plan updates, maintainability issues, accessibility or UX problems, performance risks, security concerns, and small polish items. Include broader ideas that could materially improve the project, labelled optional/exploratory unless necessary.

## Startup

Read in order:

1. `<project-root>/AGENTS.md`
2. `<project-root>/WORKSPACE.md`, when present
3. `.agent/scripts/project-diagnostics.py --list`, when present
4. `PROGRESS.md` — session handoff, active work, relevant risks, expected commit
5. `git status --short`
6. Changed files and relevant nearby context

Skip `WORKSPACE.md` if missing. Use `AGENTS.md`, package scripts, nearby docs as needed.

Apply the `code-lookup` routing skill for structural questions. Use targeted reads; avoid generated, vendored, cached, build, dependency, coverage, or binary output.

## Skill routing

Always apply `code-review` standards. Load additional skills only when the touched files or diff contents make them relevant.

## Review method

1. Identify intended task from user request, `PROGRESS.md`, branch name, changed files
2. List changed files with `git status --short`. Do not stage or commit.
3. Inspect each file to understand behaviour and risk. Search for current line locations; don't rely on memory. For a changed or new component test, confirm it imports and mounts the actual component under test, not inline markup or a substitute: an assertion against hard-coded markup doesn't verify the changed file.
4. Compare implementation with plan: expected commit, active tasks, risks, notes, docs expectations, verification
5. Classify docs: reference must match code; roadmap may describe future shape
6. Check whether generated files were edited directly or source/generated output is stale
7. Run only cheap, justified verification. Use `.agent/scripts/project-diagnostics.py --check <name>` when available
8. Lead with findings. State clearly if no must-fix issues; note remaining verification gaps.

Don't use `git diff` for routine self-review. For independent review, use targeted diffs or file reads when clearest, keeping output narrow.

## Finding standards

Prioritise concrete issues over preferences:

- **Must-fix** — correctness bugs, regressions, broken generated/source boundaries, missing required verification, plan mismatch that would make the commit misleading, security or data-loss risk
- **Recommended** — maintainability, test, documentation, accessibility, UX, performance, or developer-experience improvements that materially improve the change
- **Nice-to-have** — optional polish, simplification, or broader ideas with clear value but no commit-blocking need

Each finding should include:

- file and line reference when possible
- what is wrong
- why it matters
- concrete fix or decision needed

Mark speculative ideas as conditional. Do not invent project requirements or recommend complexity for its own sake.

## Output

Use this shape:

```markdown
## Overall assessment

<Is the work broadly commit-ready? Name the main reason.>

## Must-fix issues before commit

- [Severity] `<file>:<line>` — <issue>. Fix: <specific action>.

## Recommended improvements

- `<file>:<line>` — <improvement and reason>.

## Nice-to-have ideas

- <optional idea, labelled if exploratory>.

## Suggested updates to PROGRESS.md

- <specific plan, handoff, task, risk, or verification update>.

## Questions or assumptions

- <unknown that affects confidence>.

## Checks run

- `<command>` — <result>.

## Next step

<One concrete action: fix a must-fix item, approve commit prep, or decide an open question.>
```

If a section has no items, say `None found.` or `None.` Do not omit sections unless the user's requested format differs.
