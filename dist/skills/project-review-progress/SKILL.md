---
# Generated — edit skill.json and SKILL.body.md instead.
name: project-review-progress
displayName: Project review progress
description: >
  Use this skill when reviewing an existing PROGRESS.md plan or project roadmap, especially requests like "review PROGRESS.md", "check the plan", "is this a good plan", or "what is missing from the progress plan". Assesses both PROGRESS.md as an execution plan and the quality of the project direction it describes, without editing files.
---
# Project review progress

Review an existing `PROGRESS.md` before changing it. Assess both the document as an execution plan and the quality of the project direction it describes.

Default to review and recommendations only; do not edit files unless the user explicitly asks after the review.

## Scope

Evaluate two layers:

- **Plan quality** — whether `PROGRESS.md` is clear, coherent, sequenced, resumable, split into committable chunks, and specific about verification
- **Project judgement** — whether the planned work itself is likely to produce the strongest version of the repo, or whether it is missing important work, overbuilding, under-specifying, sequencing poorly, or carrying hidden risk

Suggest broader ideas when they could materially improve the project, even if they are not already in the plan. Label them as optional or exploratory unless they are necessary for correctness, maintainability, accessibility, security, performance, developer experience, or long-term quality.

Do not invent requirements or recommend complexity for its own sake. If an idea depends on missing context, mark it as conditional.

## Startup

Read in this order, stopping when you have enough context:

1. `<project-root>/AGENTS.md`
2. `<project-root>/WORKSPACE.md`, when present
3. `.agent/scripts/project-diagnostics.py --list`, when present
4. `PROGRESS.md`
5. Related specs, docs, source files, or generated-file facts only when `PROGRESS.md` references them or the review needs evidence

If `WORKSPACE.md` is missing, do not create it. Use `AGENTS.md`, package scripts, and nearby docs only as needed.

Prefer codebase-memory tools for structural code questions when available. Use targeted file reads and searches; avoid broad generated, vendored, cached, build, dependency, coverage, or binary output.

## Review method

1. Identify the project goal, active work, upcoming milestones, expected commits, risks, decisions, discoveries, and session handoff.
2. Check whether the plan is actionable for a fresh agent: next step, stop point, verification, files likely to change, and open questions.
3. Check whether work is sequenced by dependency and value, not just by when ideas were added.
4. Check whether each chunk can become a coherent commit with a clear Conventional Commit message.
5. Look for gaps in architecture, UX, accessibility, maintainability, testing, performance, documentation, developer experience, release safety, and operational risk.
6. Look for low-value, speculative, or overcomplicated work that should be removed, parked, or deferred.
7. Recommend specific edits to `PROGRESS.md`, but do not apply them yet.

When reviewing content, challenge the plan rather than polishing only the file. A well-formatted plan can still point in the wrong direction.

## Judgement standards

Prioritise recommendations by impact:

- **Must address** — plan gaps that risk incorrect work, broken verification, misleading commits, data loss, security issues, accessibility regressions, or blocked handoff
- **Recommended** — changes that materially improve sequencing, scope, tests, docs, maintainability, or developer experience
- **Optional** — broader or exploratory ideas that could raise quality but should not block current work

Be practical. Prefer small plan edits when they solve the problem. Recommend a new spec or ADR only when the existing plan cannot carry the context cleanly and the decision is durable, surprising, and trade-off driven.

## Output

Use this shape:

```markdown
## Overall assessment of the project direction

<Is the planned work directionally strong? Name the main reason.>

## Assessment of PROGRESS.md as an execution plan

<Is the file usable for multi-session execution? Mention clarity, sequencing, commit boundaries, and verification.>

## Gaps or issues

- [Impact] <gap or issue, with file/section reference when useful>. Why it matters: <reason>.

## Recommended changes to the plan

- <specific change to an existing section, task, risk, note, expected commit, or verification step>.

## New ideas worth considering

- [Optional/Exploratory/Recommended] <idea and why it may improve the project>.

## Suggested priority order

1. <highest-impact next plan change>
2. <next>

## Specific edits to make to PROGRESS.md

- <concrete edit, insertion, removal, or move>.

## Assumptions, risks, and open questions

- <unknown or assumption that affects confidence>.

## Checks run

- `<command>` — <result>.

## Next step

<One concrete action: approve edits, answer an open question, or choose which recommendation to apply first.>
```

If a section has no items, say `None found.` or `None.` Do not omit sections unless the user's requested format differs.
