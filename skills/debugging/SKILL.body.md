# Debugging

**Root cause first. Always.** Fixing before cause is guessing; it wastes time and creates bugs.

## When to apply

Any technical failure: tests, runtime bugs, unexpected output, build errors, integration failures.

Apply especially under pressure or when "quick fix" seems obvious.

## Phase 1 — Build a feedback loop

Before investigating, create fast, deterministic, repeatable signal confirming failure. Reliable observation is 90% of fix.

**First step — use project diagnostics.** If `.agent/scripts/project-diagnostics.py` exists, run `--list` then `--check <name>` for the relevant check. This is the default way to get signal — not raw CLI commands (`npx vitest`, `npx playwright test`, etc.). Narrow unit-test checks with `--test-file <path>` or `--test-glob '<pattern>'`; both arguments are repeatable, and glob patterns must be quoted. Prefer scoped commands when they save back-and-forth: single test file, lint on touched path, minimal repro. Ask user for full suites, builds, e2e, or diagnostics `--all`.

A good loop is fast (seconds), deterministic (fails consistently), and scoped (minimum setup). It can be diagnostics `--check`, failing unit test, minimal CLI invocation, script, or app repro route. If none possible, ask user for exact reproduction and observation.

## Phase 2 — Investigate

Do not skip this phase.

1. **Read the error fully.** Stack traces, line numbers, and error codes often contain the answer.
2. **Ask user to reproduce it.** Get exact steps. If unreliable, gather more data before hypothesis.
3. **Check recent changes.** What changed? Git diff, new dependency, config edit, environment difference.
4. **Trace data flow.** Find where the bad value originates; fix the source, not the symptom.

For temporary logging, tag each entry with short unique prefix like `[DBG-a4f2]` so grep/removal is clean.

### Vue/Vite/Vitest specifics

- Check for reactivity loss: was a reactive object destructured without `toRefs`?
- Check `shallowRef` vs `ref` — deep mutations on `shallowRef` don't trigger updates
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
2. Write regression test failing against current code. Confirm failure before changing code.
3. Implement the smallest fix that makes it pass.
4. One change at a time — no bundled improvements.
5. Ask user to verify fix and no other tests broke.

If fix fails, return to Phase 2 with new info. After three failed fixes, stop; architecture may be wrong. Discuss before trying again.

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
