# Project review task

Assess a task file or implementation plan before coding so stale repository facts, vague contracts, wrong scope, untestable acceptance criteria, and over-prescriptive recipes are caught while they are cheap to change. Give an evidence-backed `Ready as written` verdict when the task is clear, proportionate, and verifiable; otherwise request only changes that improve evidence, reduce ambiguity or risk, improve maintainability, or make completion more verifiable. An independent review does not edit the task or begin implementation.

## Scope

Review planning quality, not an implementation diff, commit range, existing `PROGRESS.md` roadmap, or another agent's feedback. Keep the task's contract separate from implementation mechanics, specialist skill guidance, and delivery coordination.

## Resolve the task

Resolve exactly one task in this order:

1. Use an explicit task path from the request or handoff.
2. Try `.agent/tasks/<name>`.
3. Try `.agent/tasks/<name>.md`.
4. Match an exact `title:` value in task front matter.

Include ignored task files in each candidate lookup. If the supplied path is missing, no exact candidate is found, or any lookup is ambiguous, stop and report the exact paths found. Do not choose a fuzzy, partial, newer, or more convenient match.

## Review method

1. Read the resolved task and current repository guidance. Check `AGENTS.md`, `WORKSPACE.md` when present, `PROGRESS.md` when relevant, and only the source, metadata, docs, or scripts needed to test the task's claims.
2. Record the resolved path and a content hash. Re-check the task before the verdict; if its path or content changed during review, stop with a stale-review result.
3. Compare task claims with current repository evidence. Verify named files, commands, generated boundaries, dependencies, existing patterns, and permission or cross-repository limits instead of accepting them from the task alone.
4. Assess the quality rubric below. Mark an item as a finding only when the evidence supports a concrete planning change.
5. Stress the task's boundary and altitude. It must be detailed enough for implementation and verification without prescribing incidental code structure, inventing architecture, or hiding independently reviewable work.
6. Report one verdict. Use `Ready as written` only when no **Must-fix** or **Recommended** finding remains; non-blocking **Nice-to-have** ideas do not prevent readiness.

## Quality rubric

- **Repository truth** — named paths, commands, generated outputs, dependencies, and current patterns are real and applicable.
- **Purpose** — the problem, beneficiary, and observable outcome are clear.
- **Behavioural contract** — inputs, outputs, states, boundaries, and relevant failure or recovery behaviour are stated without implementation recipes.
- **Task boundary** — one coherent outcome, explicit non-goals, and independently reviewable files and verification.
- **Dependencies** — real prerequisites, cross-repository relationships, permission limits, and sequencing are named.
- **Altitude** — enough detail to act safely, with no speculative architecture or line-by-line solution disguised as a requirement.
- **Maintainability** — existing helpers and patterns are considered; abstractions, flexibility, and process are proportionate to the evidence.
- **Acceptance and verification** — each load-bearing claim has observable evidence, with static, executed, observed, or blocked checks distinguished where useful.
- **Risks and proportionality** — concrete failure modes, recovery paths, and checks match the task's impact and complexity.

## Finding standards

- **Must-fix** — stale or false repository facts, missing contract or boundary, unsafe ambiguity, impossible acceptance, missing required verification, or a risk that blocks implementation.
- **Recommended** — a material maintainability, evidence, failure-state, or clarity gap that should be corrected before implementation.
- **Nice-to-have** — useful polish that is neither required nor a reason to delay the task.

Every finding names the task or evidence location where possible, the problem, its effect, and the smallest planning change that resolves it. Mark assumptions and blocked checks explicitly. If the evidence does not support a change, do not manufacture one.

## Output

Use this shape and keep empty sections explicit with `None.` or `None found.`:

```markdown
## Task review

- Resolved task: `<path>`
- Content hash: `<sha256>`
- Verdict: `Ready as written` | `Changes requested`

## Must-fix findings

- **[M1]** `<path>:<line>` — <problem>. Effect: <impact>. Change: <smallest planning change>.

## Recommended findings

- **[R1]** `<path>:<line>` — <problem>. Effect: <impact>. Change: <smallest planning change>.

## Nice-to-have ideas

- `<optional improvement>`.

## Evidence checked

- **Repository truth** — <paths, commands, or current patterns checked>.
- **Contract and boundary** — <result>.
- **Acceptance and verification** — <result>.

## Assumptions and blocked checks

- <assumption or blocked check, with what would settle it>.

## Next step

<If ready, accept the task and begin its approved implementation boundary. If changes are requested, update the task and repeat this review.>
```
