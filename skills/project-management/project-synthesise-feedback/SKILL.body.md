# Project synthesise feedback

Critically combine another agent's suggestions with your own judgement. Produce one stronger recommendation set, not a commentary track on whose answer is better.

Default to analysis and recommendations only; do not edit files unless the user explicitly asks after the synthesis.

## Scope

Use when the user provides advice, a plan, review notes, or implementation suggestions from another agent, reviewer, or prior thread and asks what to keep, change, reject, or add.

Assess practical improvements across the task, plan, implementation, architecture, UX, accessibility, maintainability, testing, performance, developer experience, documentation, security, and long-term quality when relevant.

Broad ideas are welcome when they may materially improve the work. Label them as optional, exploratory, or conditional unless they are necessary. Do not invent requirements, pad the answer with speculative upgrades, or recommend complexity for its own sake.

## Startup

Read the user-provided feedback first. Then gather only the context needed to judge it:

1. Relevant project instructions and capability facts when operating in a repo
2. `PROGRESS.md` when the feedback concerns a project plan or current work
3. Changed files when the feedback concerns uncommitted implementation
4. Source, docs, tests, or generated-file facts directly referenced by the feedback

If the feedback can be judged from the provided text, do not inspect the repo unnecessarily. If evidence is missing, say what would need checking rather than guessing.

Prefer codebase-memory tools for structural code questions when available. Use targeted file reads and searches; avoid broad generated, vendored, cached, build, dependency, coverage, or binary output.

## Review method

1. Identify the original task or decision the feedback is responding to.
2. Extract the other agent's concrete claims, recommendations, assumptions, and implied priorities.
3. Test each recommendation against available evidence, project constraints, user goals, proportionality, and implementation cost.
4. Keep the strongest ideas, but rewrite them into your own practical recommendation.
5. Push back on weak, unsupported, redundant, risky, overbroad, or low-value ideas.
6. Add missing ideas that materially improve the outcome.
7. Convert the synthesis into ordered next steps.

Do not treat the other agent's suggestions as authoritative. Do not reject ideas just because they came from another agent. The goal is the best combined result.

## Judgement standards

Prioritise:

- correctness and user intent before polish
- small, high-impact fixes before broad rewrites
- project conventions before novel architecture
- accessibility, security, and data safety when relevant
- test and verification gaps that could hide regressions
- maintainability and developer experience when they reduce future cost

Challenge suggestions that:

- depend on unverified assumptions
- expand scope without clear value
- introduce new dependencies, tools, abstractions, or process without need
- optimise for theoretical quality while delaying useful delivery
- duplicate existing project patterns or planned work
- conflict with project instructions, capability manifests, or generated-file boundaries

## Output

Use this shape unless the user asks for a different format:

```markdown
## What I agree with and would keep

- <strong idea, with any caveat or refinement>.

## What I would change, remove, or push back on

- <weak or risky idea>. Why: <reason>. Better option: <alternative>.

## Additional ideas to take this further

- [Recommended/Optional/Exploratory] <new idea and why it matters>.

## Specific recommended next steps, ordered by impact

1. <highest-impact action>
2. <next action>

## Risks, assumptions, and open questions

- <risk, assumption, or question that affects confidence>.

## Checks run

- `<command>` — <result>.

## Next step

<One concrete action: choose recommendations, approve edits, or answer an open question.>
```

If a section has no items, say `None found.` or `None.` Keep the answer concise enough to act on; do not preserve every suggestion if it does not change the recommendation.
