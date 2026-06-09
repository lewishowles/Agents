---
# Generated — edit skill.json and SKILL.body.md instead.
name: refactoring
description: >
  Use this skill when refactoring existing code or triaging technical debt. Covers behaviour-preserving refactoring technique (one change at a time, tests pass at every step), and a lightweight debt categorisation and prioritisation approach. Distinct from debugging (fixing a bug) and from new feature work.
do-not-use-when:
  - Fixing a bug — use the debugging skill
  - Adding new behaviour — that is feature work, not refactoring
  - The user hasn't asked for a refactor (don't improve adjacent code unprompted)
related-skills:
  - code-style
  - unit-testing
  - debugging
---
# Refactoring

**Refactoring changes structure, not behaviour.** Tests must pass before the first change and after every subsequent step. If a step breaks tests, revert it — don't pile on more changes.

## Behaviour-preserving technique

1. **Confirm tests exist** for the code being refactored. If they don't, write them first — they're your safety net.
2. **One change at a time.** Each change should be independently reviewable and revertable.
3. **Run tests after each step.** Ask the user to run the relevant test command; don't move forward until they pass.
4. **No scope creep.** A refactor PR does one structural thing. Spotted a bug? Note it, fix it separately.

### Common moves (in order of safety)

| Move                        | What it is                                    | Risk                          |
| --------------------------- | --------------------------------------------- | ----------------------------- |
| Rename                      | Rename variable, function, or component       | Low — text substitution       |
| Extract function/composable | Pull repeated logic into a named unit         | Low                           |
| Inline                      | Replace a one-use abstraction with its body   | Low                           |
| Move                        | Relocate a function or file                   | Medium — update all imports   |
| Simplify condition          | Flatten nested `if`s, remove double negatives | Medium — verify all branches  |
| Split component             | Decompose large component into smaller ones   | Higher — re-test interactions |

## Technical debt triage

Use this when assessing what to address, not when actively refactoring.

### Categories

- **Code debt** — duplication, large functions, unclear naming, dead code
- **Architecture debt** — wrong layer of abstraction, circular dependencies, missing composables
- **Test debt** — no tests, low coverage of critical paths, brittle snapshots
- **Dependency debt** — outdated packages, insecure versions, unneeded transitive deps

### Prioritisation

Score each item by impact (how much it slows down changes or causes bugs) and effort (how hard to fix):

|                 | Low effort              | High effort       |
| --------------- | ----------------------- | ----------------- |
| **High impact** | Fix now (quick win)     | Plan and schedule |
| **Low impact**  | Batch with related work | Defer or drop     |

Don't refactor low-impact, high-effort items unless the surrounding code needs to change anyway.

### Prevention

- Enforce standards in CI (lint, type-check) so debt doesn't silently accumulate
- Address debt incrementally when you're already touching a file — the "campsite rule"
- Note spotted debt with a `// TODO:` comment so it's findable; don't fix it mid-PR unless it's a blocker

For worked examples of common refactoring sequences in Vue and Swift, see [references/examples.md](references/examples.md).
