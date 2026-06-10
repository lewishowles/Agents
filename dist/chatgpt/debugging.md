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

**Root cause first. Always.** Proposing a fix before finding the cause is guessing — it wastes time and creates new bugs.

## When to apply

Any technical failure: test failures, runtime bugs, unexpected output, build errors, integration failures.

Apply especially when under time pressure or when a "quick fix" seems obvious — those are when guessing is most tempting and most costly.

## Token-discipline note

Don't run tests or builds — ask the user. Phrase it as the smallest useful command they need to run, and ask what output they get.

## Phase 1 — Investigate

Do not skip this phase.

1. **Read the error message fully.** Stack traces, line numbers, error codes. They often contain the answer.
2. **Ask the user to reproduce it.** Get exact steps. If it isn't reliably reproducible, gather more data before forming any hypothesis.
3. **Check recent changes.** What changed? Git diff, new dependency, config edit, environment difference.
4. **Trace data flow.** Where does a bad value originate? Trace backward up the call stack to the source — fix at the source, not at the symptom.

### Vue/Vite/Vitest specifics

- Check for reactivity loss: was a reactive object destructured without `toRefs`?
- Check `shallowRef` vs `ref` — deep mutations on a `shallowRef` don't trigger updates
- Vite dev vs build differences: CJS interop, `import.meta.env` availability, `define` substitution
- In Vitest, check if the module needs `vi.mock()` or `flushPromises()` before asserting

### Swift/SwiftUI specifics

- Check `@MainActor` isolation — async work off the main actor won't update UI
- SwiftUI view body: expensive work in `body` causes thrashing; it should be in `.task {}`
- `@Observable` vs legacy `ObservableObject` — mixing the two breaks observation

## Phase 2 — Hypothesis

State a single, specific hypothesis: _"I think X is the root cause because Y."_

- Find working code that does something similar — compare it to the broken code
- List every difference, however small
- Do not assume "that can't matter"

## Phase 3 — Minimal fix

1. Ask the user to run the smallest test or repro that would confirm or refute the hypothesis
2. If confirmed: implement the smallest possible fix addressing the root cause
3. One change at a time — no bundled improvements
4. Ask the user to verify the fix works and no other tests broke

If the fix doesn't work, return to Phase 1 with new information. After three failed fixes, stop — the architecture may be wrong. Discuss with the user before trying again.

## Prevention

After resolving the bug:

- Note whether a test would have caught it, and suggest adding one if so
- If it was a reactivity or type error, note the pattern to avoid

## Red flags — stop and go back to Phase 1

- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- Making multiple changes at once
- Proposing solutions before tracing data flow
- "I don't fully understand but this might work"
- Attempting a fourth fix without questioning the architecture

See [references/rationalisations.md](references/rationalisations.md) for a full table of common rationalisations and why they fail.
