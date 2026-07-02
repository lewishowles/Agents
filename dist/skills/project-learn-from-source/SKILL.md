---
# Generated — edit skill.json and SKILL.body.md instead.
name: project-learn-from-source
displayName: Project learn from source
description: >
  Use this skill when asked to inspect an external artefact, such as a website, AGENTS.md, skill repo, blog post, or docs page, and identify practical lessons for the current repo.
---
# Project learn from source

Extract practical lessons from an external artefact and ground them in the current repo. The failure this skill prevents is generic summarising or uncritical copying from another project.

Default to analysis and recommendations only. Do not edit files unless the user explicitly asks after the assessment.

## Scope

Use when the user points at an external source and asks whether this repo can learn from it.

Sources may include:

- websites or product pages
- another project's `AGENTS.md`, `CLAUDE.md`, rules, prompts, or setup docs
- a skill repo or individual skill
- blog posts, release notes, documentation, talks, checklists, templates, or examples

Assess practical improvements across project instructions, agent workflows, skills, rules, docs, architecture, UX, accessibility, testing, security, performance, developer experience, and maintenance process when relevant.

Do not use this skill for:

- feedback already written about this repo, use `project-synthesise-feedback`
- uncommitted local changes, use `project-review-worktree`
- general repo health checks without an external source, use `project-audit`
- accessibility compliance reviews, use `accessibility-audit`

## Startup

Read the external source first. If the source is a URL and browsing or network access is not available, ask for the relevant excerpt rather than guessing.

Then gather only the local context needed to judge fit:

1. Relevant project instructions and workspace facts when operating in a repo
2. `PROGRESS.md` when the source may affect current plans, rules, skills, or handoff
3. Existing rules, skills, docs, source, tests, or config directly related to the external idea
4. Local commands or diagnostics only when needed to verify a concrete claim

If the source can be judged from high-level context, do not inspect implementation files unnecessarily. If local evidence is missing, say what would need checking rather than filling the gap with assumptions.

Prefer codebase-memory tools for structural code questions when available. Use targeted file reads and searches; avoid broad generated, vendored, cached, build, dependency, coverage, or binary output.

## Review method

1. Identify the source's core claims, patterns, constraints, and implied priorities.
2. Separate transferable ideas from artefact-specific details.
3. Compare each idea with this repo's goals, project instructions, existing patterns, active plans, and cost of adoption.
4. Classify each idea as adopt, adapt, reject, defer, or investigate.
5. Prefer small, high-leverage changes before broad process or architecture shifts.
6. Push back on ideas that duplicate existing guidance, conflict with local constraints, require unneeded dependencies, or add ceremony without reducing real risk.
7. Convert useful ideas into specific local next steps.

Do not treat the external source as authoritative. The goal is better local judgement, not imitation.

## Judgement standards

Prioritise ideas that:

- solve a failure mode this repo has actually shown or is likely to hit
- reduce repeated agent or developer friction
- make instructions easier to trigger, follow, validate, or maintain
- improve accessibility, security, data safety, or user trust where relevant
- fit existing source/generated boundaries, command discipline, and progress workflow
- can be adopted as a small reviewable chunk

Challenge ideas that:

- rely on another repo's constraints without evidence they apply here
- are mostly aesthetic, branding, or wording preference
- add a new tool, dependency, abstraction, or ritual without clear payoff
- conflict with current user goals, active plans, or local rules
- duplicate guidance already present in `AGENTS.md`, `WORKSPACE.md`, `PROGRESS.md`, rules, or skills
- would be hard to reverse without a strong reason

## Output

Use this shape unless the user asks for a different format:

```markdown
## Useful lessons

- [Recommended] <idea>. Why it fits this repo: <reason>. Local action: <specific change or next step>.

## Ideas to adapt carefully

- <idea>. Constraint: <local reason it needs changing before adoption>. Better local shape: <adapted version>.

## Ideas I would not adopt

- <idea>. Why: <cost, mismatch, existing better pattern, or low value>.

## Follow-up to investigate

1. <specific check, question, or source to inspect>
2. <next check, if any>

## Evidence checked

- External source: <URL, file, or excerpt>
- Local context: <files, docs, commands, or none>

## Next step

<One concrete action: approve an edit, choose between options, provide a source excerpt, or close with no action.>
```

If a section has no items, say `None found.` or `None.` Keep recommendations proportional. Include tiny improvements when they are genuinely useful, but do not pad the assessment to make the source seem more valuable than it is.
