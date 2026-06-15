---
# Generated — edit skill.json and SKILL.body.md instead.
name: debugging
description: >
  Use this skill when encountering any bug, test failure, or unexpected behaviour — before proposing a fix. Covers root-cause investigation, hypothesis testing, and minimal targeted fixes for Vue/Vite/Vitest and Swift/SwiftUI projects.
do-not-use-when:
  - The user is asking a general question unrelated to a specific failure
  - You have already identified the root cause and are ready to implement
related-skills:
  - test-unit
  - test-e2e
  - vue-vite
  - swift
---
# Debugging

**Root cause first. Always.** Fixing before finding the cause is guessing; it wastes time and creates bugs.

## When to apply

Any technical failure: test failures, runtime bugs, unexpected output, build errors, integration failures.

Apply especially under time pressure or when a "quick fix" seems obvious.

## Token-discipline note

Prefer scoped commands when they save more back-and-forth than they cost: a single test file, lint on a touched path, or a minimal repro. Ask the user for full suites, builds, and e2e.

## Phase 1 — Build a feedback loop

Before investigating, create a fast, deterministic, repeatable signal that confirms the failure. This is the most important investment — having a reliable way to observe the bug is 90% of fixing it.

A good feedback loop is fast (seconds, not minutes), deterministic (fails consistently), and scoped (minimum setup needed). It can be a failing unit test, a minimal CLI invocation, a script, or a repro route in the app. If you can't create one, ask the user to reproduce it and describe exactly what they observe.

## Phase 2 — Investigate

Do not skip this phase.

1. **Read the error fully.** Stack traces, line numbers, and error codes often contain the answer.
2. **Ask the user to reproduce it.** Get exact steps. If unreliable, gather more data before forming a hypothesis.
3. **Check recent changes.** What changed? Git diff, new dependency, config edit, environment difference.
4. **Trace data flow.** Find where the bad value originates; fix the source, not the symptom.

When adding temporary logging to trace the issue, tag each entry with a short unique prefix — e.g. `[DBG-a4f2]` — so you can grep for it and remove it cleanly at the end.

### Vue/Vite/Vitest specifics

- Check for reactivity loss: was a reactive object destructured without `toRefs`?
- Check `shallowRef` vs `ref` — deep mutations on a `shallowRef` don't trigger updates
- Vite dev/build differences: CJS interop, `import.meta.env`, `define` substitution
- In Vitest, check if the module needs `vi.mock()` or `flushPromises()` before asserting

### Swift/SwiftUI specifics

- Check `@MainActor` isolation — async work off the main actor won't update UI
- SwiftUI view body: expensive work in `body` causes thrashing; it should be in `.task {}`
- `@Observable` vs legacy `ObservableObject` — mixing the two breaks observation

## Phase 3 — Hypothesis

State a single, specific hypothesis: _"I think X is the root cause because Y."_

- Find working code that does something similar — compare it to the broken code
- List every difference, however small
- Do not assume "that can't matter"

## Phase 4 — Fix

1. Run the feedback loop to confirm the failure is reproducible.
2. Write a regression test that fails against the current code. Confirm it fails before changing anything.
3. Implement the smallest fix that makes it pass.
4. One change at a time — no bundled improvements.
5. Ask the user to verify the fix and that no other tests broke.

If the fix fails, return to Phase 2 with new information. After three failed fixes, stop; the architecture may be wrong. Discuss before trying again.

## Cleanup

After resolving the bug:

- Remove all tagged debug logs — grep for `[DBG-` to find them
- Note the pattern to avoid if the bug was a reactivity or type error

## Red flags — stop and go back to Phase 2

- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- Making multiple changes at once
- Proposing solutions before tracing data flow
- "I don't fully understand but this might work"
- Attempting a fourth fix without questioning the architecture

See [references/rationalisations.md](references/rationalisations.md) for a full table of common rationalisations and why they fail.

---

_Feedback loop as Phase 1, tagged debug logs, and regression-before-fix were inspired by [mattpocock/skills](https://github.com/mattpocock/skills) (MIT)._
