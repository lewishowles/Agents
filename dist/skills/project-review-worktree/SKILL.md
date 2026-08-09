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

Look for regressions, missing work, weak tests, documentation gaps, and quality issues.

## Startup

Read `AGENTS.md`, `WORKSPACE.md`, diagnostics, `PROGRESS.md`, `git status --short`, and relevant changed files. If no workspace file exists, use `AGENTS.md`, package scripts, and nearby docs.

Gather routine orientation in one bounded call where possible. A supplied review packet may provide paths, prior results, exact commands, and unresolved risks; independently verify load-bearing claims instead of rediscovering unchanged facts.

Use `code-lookup` for structural questions. Use targeted reads; avoid generated, vendored, cached, build, dependency, coverage, and binary output.

## Skill routing

Apply `code-review`, `code-style`, and relevant language or framework skills. Loading them does not prove their standards were checked.

## Review method

1. Identify the task from the request, handoff, and changed files. List them with `git status --short`; do not stage or commit.
2. List the load-bearing review claims and the cheapest evidence that could settle each one.
3. When a safe, focused diagnostic or repro is already known, run it early and use its result to direct later reads. If command discovery is needed, inspect only enough context to identify it. Use `.agent/scripts/project-diagnostics.py --check <name>` when available.
4. Inspect changed files in context and find current lines, prioritising paths connected to failed, blocked, or uncovered claims. Component tests must mount the component under test, not substitute markup.
5. Compare implementation and documentation with the plan, risks, verification, and generated-source boundary. Reference documentation must match code; roadmaps may describe future work.
6. Re-check PROGRESS.md's deferred or forward-looking notes (e.g. "optional hardening", "if a third caller ever needs this") against this diff. If the stated trigger condition is now met, treat it as a finding, not a resolved deferral.
7. Run any remaining cheap, justified checks raised by source inspection.
8. Lead with findings and evidence gaps. State when no must-fix issue exists.

Don't use `git diff` for routine self-review. For independent review, use targeted diffs or file reads when clearest, keeping output narrow.

## Finding standards

Use **Must-fix** for correctness, regression, generated-boundary, required-verification, misleading-plan, security, or data-loss issues; **Recommended** for material maintainability, tests, documentation, accessibility, UX, performance, or developer experience; **Nice-to-have** for non-blocking polish.

Give each finding a file and line where possible, problem, effect, and fix or decision. Mark speculation as conditional; do not invent requirements.

## Conventions

Check these against changed files and state which were checked:

- **Helper reuse** — reuse an existing helper, component, or command where it covers this
- **No switchboard drift** — a reused helper hasn't accumulated a boolean/option flag per new caller; that's a maintainability finding, not reuse
- **No single-use abstractions** — no composable, helper, or test utility with one caller
- **Naming and sibling consistency** — matches neighbouring conventions
- **Comment, JSDoc, prop and test wording** — treat changed prose as a draft. Read each item beside the code it describes: correct tags and grammar are not enough. Preserve required documentation, but rewrite from scratch when it repeats the symbol name or mechanics. State the domain rule, caller contract, or useful distinction in the codebase's plain-English terms; replace robotic or jargon wording
- **No out-of-contract changes** — every line traces to the task; adjacent improvements are findings, not edits

## Craftsmanship result

Before approval, report skills applied, ready or changes requested, and concrete findings.

## Evidence status

Classify each load-bearing acceptance criterion:

- **Observed** — seen in a rendered browser page or the running app
- **Executed** — a specific assertion or repro step ran and would fail if this claim were false, not merely that the containing suite exited 0
- **Static** — read the code and reasoned about it
- **Blocked** — could not be checked here, with the reason

Rendered layout, visibility, overflow, and responsiveness are **Static** from jsdom or code reading. Do not approve unconditionally with a load-bearing Static or Blocked criterion: say what would settle it.

## Output

Use this shape:

```markdown
## Overall assessment

<Verdict, qualified when any load-bearing criterion is Static or Blocked.>

## Evidence status

- <criterion> — <Observed|Executed|Static|Blocked>. <Settling evidence, when needed.>

## Conventions checked

- <convention> — <pass or finding>.

## Craftsmanship

- <ready or changes requested>. Skills applied: <skills>. <Findings, if any.>

## Must-fix issues before commit

- [Severity] `<file>:<line>` — <issue>. Fix: <action>.

## Recommended improvements

- `<file>:<line>` — <improvement>.

## Nice-to-have ideas

- <optional idea>.

## Suggested updates to PROGRESS.md

- <specific update>.

## Questions or assumptions

- <unknown>.

## Checks run

- `<command>` — <result>.

## Next step

<One concrete action.>
```

Use `None found.` or `None.` for empty sections, unless the user asks for another format.
