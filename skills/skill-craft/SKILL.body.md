# Skill-craft

Lifecycle for authoring and evaluating skills in this repo: intake → design → build → eval.

## Quality bar

Apply this before writing anything. A skill earns its context cost only if all three pass:

- **Specific failure mode** — name a concrete example of the model doing this wrong without the skill. "Be thorough" fails this bar; "agent reimplements `clamp()` instead of using the project helper" passes.
- **Repeated** — has appeared more than once across sessions or projects. A single edge case doesn't warrant a skill.
- **Not already covered** — search `skills/` for an existing skill that addresses this domain. Extending an existing skill is almost always better than creating a new one.

If any of the three fails, extend an existing skill or discard the idea.

## Intake

1. Name the failure mode — one sentence: what does the model do wrong today that this skill would correct?
2. Verify it's repeated — more than once, in different sessions or projects.
3. Check for existing coverage — `rg -r "skills/" -l "<keyword>"` before creating anything new.
4. Define the trigger — what user phrase or task type fires this skill? Triggers should be specific enough to avoid misfires, broad enough to catch the real cases.

## Design

1. **State the contract** — what will an agent reliably do differently after loading this skill? Write it as one invariant sentence before drafting the body.
2. **Choose structure** — ordered checklists for procedural workflows; bullet lists for independent constraints; avoid prose paragraphs for anything that needs to be followed step-by-step.
3. **Write do-not-use-when** — at least one exclusion clause. Overly broad trigger coverage creates false positives that waste context.
4. **File-triggered vs. prompt-triggered** — file-triggered loads on every edit of matching file types; prompt-triggered loads when trigger phrases appear. Use file-triggering only when the skill should apply to every edit of those types, not just when the user mentions a topic.

## Build

1. Create `skills/<name>/skill.json` — description under 200 characters; `when` under 100 characters; `promptTriggering: true` unless file-triggered.
2. Create `skills/<name>/SKILL.body.md` — lead with the failure mode the skill corrects; prefer checklists over persona descriptions.
3. Regenerate indexes: `PATH="/opt/homebrew/bin:$PATH" bash scripts/sync.sh </dev/null`.
4. Validate: `PATH="/opt/homebrew/bin:$PATH" bash scripts/validate.sh </dev/null 2>&1 | tail -5`.

## Eval

After writing, run these four checks without re-reading the skill body:

1. **Recall test** — without re-reading, answer: what does an agent do differently after loading this skill? If the answer is vague, the body is too abstract.
2. **Misfire test** — imagine the trigger phrase arriving with no skill loaded. Does the model handle it correctly anyway from training? If yes, the skill is likely redundant.
3. **Scope test** — does the skill cover more than one coherent domain? Each section should belong to one job description. Split if not.
4. **Checklist test** — find any prose instruction paragraph. Can it be rewritten as a numbered list without losing meaning? If yes, do it — checklists are more reliably followed than prose.

## Skill vs. rule boundary

If guidance should apply on every turn regardless of task type, it belongs in `rules/global-rules.md`, not a skill. Skills are task-scoped; rules are always-on. When uncertain: if you'd want this applied even when the user hasn't said anything about the topic, it's a rule.
