---
# Generated — edit skill.json and SKILL.body.md instead.
name: session-retrospective
displayName: Session retrospective
description: >
  Use this skill when asked to learn from, retrospect on, review, or extract lessons from a difficult agent session without jumping straight to creating a new skill.
do-not-use-when:
  - Reviewing an external artefact such as a website, docs page, repo, or skill collection — use project-learn-from-source instead
  - Reviewing recurring entries already captured in the friction log — use friction-review instead
---
# Session retrospective

Turn a difficult agent session into a non-blaming learning brief for this agents repo. The failure this skill prevents is overfitting one painful session into an automatic new skill, rule, or process change without checking evidence and existing coverage.

Default to analysis and recommendations only. Do not edit files, log friction, create skills, or amend rules unless the user explicitly asks after the assessment.

## Scope

Use when the user asks to learn from, retrospect on, review, or extract lessons from a specific agent session.

The session evidence may be:

- the current conversation
- a pasted transcript or excerpt
- a user's summary of what went wrong
- a friction note that has not yet become a recurring pattern

Do not use this skill for:

- recurring friction-log review, use `friction-review`
- external artefacts such as websites, repos, docs, or skill collections, use `project-learn-from-source`
- feedback already written by another agent or reviewer, use `project-synthesise-feedback`
- general repo health checks, use `agent-config-review` for this repo or `project-audit` for other projects
- creating a new skill directly, use `skill-craft` after the retrospective recommends that route

## Startup

Start from user-visible evidence. Do not rely on private chain of thought, hidden tool outputs the user did not ask to evaluate, or reconstructed context the user may not have seen.

If the evidence is too thin to assess, ask for the smallest useful excerpt:

1. What the user asked for
2. Where the session became difficult
3. Any correction the user gave
4. The final outcome, if there was one

Then gather only local context needed to judge whether the issue is already covered:

1. Relevant `rules/` sections for always-on behaviour
2. Existing skills that match the task type or proposed fix
3. `friction-review` output only if the user asks to compare against logged patterns
4. Repo scripts or diagnostics only when the lesson concerns tooling coverage

Avoid broad repo reads. This skill is for learning triage, not a full audit.

## Review method

1. **Describe neutrally** — state what made the session difficult without attributing blame or intent.
2. **Name the behavioural gap** — identify the specific agent behaviour that should change, if any.
3. **Separate causes** — distinguish missing guidance, guidance not followed, ambiguous user intent, tool limitation, repo tooling gap, and unavoidable task complexity.
4. **Check existing coverage** — decide whether current rules, skills, hooks, diagnostics, or docs already address the gap.
5. **Choose the destination** — route each lesson to one of: no change, friction log, existing rule, existing skill, new skill idea, script/check improvement, docs/update, or user preference.
6. **Apply the evidence bar** — one session can justify a note or proposed wording, but a new skill usually needs a repeated concrete failure mode.
7. **Prefer minimal changes** — recommend the smallest amendment that would have prevented or shortened the difficult part of the session.

## Routing guidance

- **No change** — use when the issue was a one-off, already resolved by existing guidance, too ambiguous, or not preventable by repo instructions.
- **Friction log** — use when the issue is concrete but needs recurrence evidence before changing rules or skills.
- **Existing rule** — use when the behaviour should apply on every turn, regardless of task type.
- **Existing skill** — use when the behaviour is task-specific and an appropriate skill already exists.
- **New skill idea** — use only when there is a specific, repeated failure mode not already covered.
- **Script or check** — use when automation would catch the issue more reliably than prose guidance.
- **Docs or template** — use when the user-facing project contract, setup path, or generated reference is missing context.
- **User preference** — use when the session exposed a personal workflow preference rather than a general agent rule.

## Output

Use this shape unless the user asks for a different format:

````markdown
## Session signals

- <Neutral description of what made the session difficult.>

## Lessons

- **<Short lesson>**: <specific behavioural gap or system gap>.
  - Evidence: <user-visible moment or excerpt>
  - Existing coverage: <covered by X, partially covered by Y, or not found>
  - Recommended destination: <no change | friction log | rule | existing skill | new skill idea | script/check | docs/template | user preference>
  - Proposed action: <specific next step, or "watch for recurrence">

## Suggested friction entries

```sh
scripts/log-friction.sh "<category>" "<detail>"
```

## Proposed guidance changes

```diff
<Only include when evidence is strong enough for a concrete wording change.>
```

## No-change items

- <Issue that should not become repo guidance, with reason.>

## Next step

<One concrete next action for the user.>
````

If a section has no items, write `None.` Keep the brief proportionate to the evidence. Do not invent lessons to fill the template.

## Quality checks

Before responding, verify:

- The brief is non-blaming and describes behaviours, not character or intent.
- Every proposed change names the existing file or skill it would affect.
- New skill recommendations pass the `skill-craft` quality bar: specific failure mode, repeated, and not already covered.
- The output distinguishes "guidance exists but was not followed" from "guidance is missing."
- The next step is a review decision or data-gathering step, not an automatic edit.
