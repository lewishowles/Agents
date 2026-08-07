# Project learn from source

Extract practical lessons from an external artefact and ground them in the current repo. The failure this skill prevents is a speculative idea list that never decides whether the source itself is worth adopting or checks whether each recommendation is ready.

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

## Decision contract

Every assessment starts with this exact shape, before any other heading or explanation:

```markdown
**Bottom line:** <Adopt the source directly / Adopt specific parts / Take no local action>. Ready recommendations: <number> must, <number> recommended, <number> nice-to-have.
```

Use the plain-language outcome that best fits the evidence. Include all three counts even when they are zero.

Before extracting patterns to reproduce locally, decide whether this repository should adopt the source itself. Check the direct route that fits the artefact: depend on a package, use a tool or service, fork a repository, wrap a component, link to a workflow, or adopt another supported integration. If direct adoption does not apply or does not fit, state the reason briefly before considering local pieces.

A recommendation is ready only when all of these are verified:

- Why and when: in plain English, the concrete consequence of not doing this, and the point at which it should run or be applied. If this cannot be stated in a couple of plain sentences without jargon, the recommendation is not ready.
- Source behaviour: the source's relevant behaviour, claim, or example is identified and checked.
- Local gap: the repository has a current, evidenced problem or missing capability that this would address. User-profile interests and adjacent domains do not establish a gap.
- Coverage: existing or planned local coverage is identified, including the relevant source, tests, documentation, configuration, plan, or repeated friction.
- Adoption route and action: the route into this repository and the smallest concrete local action are clear.
- Cost or risk: proportionate implementation, maintenance, compatibility, security, accessibility, performance, or operational cost and risk are checked.

If a load-bearing fact cannot be checked, keep the candidate blocked. Name the exact missing evidence, explain how it could change the decision, and state the specific recovery needed. Do not guess, and do not present the candidate as ready while reopening it with an unresolved design question. `Investigate` and `defer` may exist as internal states, or as an explicit blocked-evidence explanation, but they are not routine output choices.

Already-covered principles, confirmations of the current approach, and rejected ideas must be visibly separate from ready recommendations. A zero-recommendation result is successful when the evidence supports it.

## Startup

Treat the source through `source-extraction`, not by reading raw content directly.

- If the source is already pasted text, use that text as the source evidence. If it is a source-extraction receipt, keep only the receipt in the learner context and request the indexed excerpts needed for the judgement.
- Otherwise, use `source-extraction` in a delegated or forked discovery context. The extraction worker writes the full structured extraction to a `mktemp` scratch directory outside the repository and returns only its receipt, never the raw extraction. For several sources, use one extraction context per source, then synthesise the receipts and requested excerpts.
- Only read the raw source directly if `source-extraction` cannot be applied (a URL with no browsing and no delegation, nothing pasted) and ask for the relevant excerpt rather than reading raw content into the main conversation.

Then gather only local context needed to judge fit:

1. Relevant project instructions and workspace facts
2. `PROGRESS.md` when source may affect plans, rules, skills, or handoff
3. Existing rules, skills, docs, source, tests, or config directly related
4. Local commands or diagnostics only when verifying concrete claims

If high-level context suffices, skip implementation files. If evidence is missing, say what needs checking rather than guessing.

Apply the `code-lookup` routing skill for structural questions. Use targeted reads; avoid generated, vendored, cached, build, dependency, coverage, or binary output.

## Review method

1. Establish the source identity and request only the indexed source excerpts that are relevant to the repository or to a direct-adoption decision.
2. Check direct adoption first. Record the route considered and the evidence for adopting it or ruling it out.
3. Gather local evidence for the gap, existing or planned coverage, and constraints. Use current plans, source, tests, documentation, configuration, repeated friction, or a repository-inherent risk.
4. Check every candidate against the full readiness gate. Drop candidates with no plausible local gap or with evidence that rules them out. Keep only genuinely unresolved load-bearing evidence as an explicit blocker.
5. Assign each ready candidate a tier: Must, Recommended, or Nice-to-have.
6. Choose the bottom-line outcome. Direct adoption wins when the source itself fits; adopt specific parts only when the source as a whole does not fit but a verified local piece does; take no local action when neither route has a ready recommendation.
7. Write the shortest response that communicates the verdict, ready actions grouped by tier, covered or rejected material, and any genuine blocked evidence.

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

## Recommendation tiers

Every ready recommendation gets exactly one tier, chosen by how much the local gap is already hurting, not by how interesting the source idea is:

- **Must** — an active, currently evidenced problem, wrong instruction, repeated friction, or risk that this recommendation removes. Left unaddressed, that problem stays live.
- **Recommended** — a real, verified gap or missing capability, but nothing is currently breaking or actively causing harm without it. Safe to schedule for a later chunk.
- **Nice-to-have** — small, proportionate polish or convenience. The gap is genuine but minor, and the cost of leaving it is low either way.

## Output

Write the whole response in plain English. Explain technical terms the first time they appear, drop raw links from prose (put them only where a source location is genuinely needed, such as `Source behaviour`), and don't make the reader ask a follow-up question to understand why a recommendation exists. If a sentence would only make sense to someone who already read the source, rewrite it.

After the required first line, use only the sections that contain evidence:

```markdown
**Bottom line:** <outcome>. Ready recommendations: <number> must, <number> recommended, <number> nice-to-have.

## Direct adoption

- Route considered: <depend on, use, fork, wrap, link, or other route>
- Decision: <adopt it / do not adopt it>
- Evidence: <source behaviour and local fit, or the brief reason it does not fit>

## Must

1. <specific local action>

   <One or two plain-English sentences: why this matters, with no jargon or links, as if explaining it to someone who has not read the source.>

   - Why and when: <the concrete consequence of skipping this, and the point at which it should run or be applied>
   - Source behaviour: <verified source evidence, with its receipt index or source location>
   - Local gap: <verified current problem or missing capability>
   - Coverage: <existing or planned local source, tests, docs, config, plan, friction, or risk>
   - Adoption route: <how this repository will take it on>
   - Cost and risk: <proportionate checked trade-offs>

## Recommended

1. <same shape as Must>

## Nice-to-have

1. <same shape as Must>

## Covered, confirmed, or rejected

<Already-covered principles, confirmations of the current approach, and rejected ideas with their evidence.>

## Blocked evidence

- Missing evidence: <exact source or local fact that could not be checked>
- Decision impact: <how it could change the direct-adoption decision or candidate>
- Recovery: <specific excerpt, file, command result, or user decision needed>

## Evidence checked

- External source: <identity and requested receipt indexes or pasted excerpt>
- Local context: <files, docs, commands, or none>
```

For `Take no local action`, keep the response short: the required first line, the direct-adoption reason, the local evidence showing no gap or sufficient coverage, and any decisive source evidence. Do not emit empty template sections. Do not add a routine investigation or deferral list. If evidence is genuinely unavailable, use only the blocked-evidence section and do not call the candidate a recommendation.

## Attribution

The visible rejection and recurring-pattern guidance adapts ideas from `danium/lateral-thinking`, MIT licensed.
