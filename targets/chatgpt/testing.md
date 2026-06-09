---
name: testing
description: >
  Use this skill when deciding what to test, at which layer, and in what order — before writing
  the tests themselves. Covers the test pyramid, TDD red-green-refactor workflow, and what to
  skip. For the mechanics of writing tests, see unit-testing and e2e-testing.
do-not-use-when:
  - Writing the actual test code — use unit-testing or e2e-testing
  - Debugging a failing test — use debugging
related-skills:
  - unit-testing
  - e2e-testing
  - debugging
  - refactoring
---

# Testing strategy

## The test pyramid

```
        /‾‾‾‾‾‾‾‾‾‾‾\
       /   e2e / full  \   Few. Cover critical user journeys only.
      /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\
     /  component / browser \  Some. What the user sees and interacts with.
    /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\
   /    unit / composable     \  Many. Logic, computed values, edge cases.
  /‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\
```

More tests at the bottom (fast, isolated, cheap) and fewer at the top (slow, realistic, expensive).

## What to test at each layer

| Layer     | Test with            | Test what                                                            |
| --------- | -------------------- | -------------------------------------------------------------------- |
| Unit      | Vitest               | Composables, computed properties, helpers, edge cases, invalid input |
| Component | Playwright / Cypress | Rendered output, ARIA attributes, user interactions, slot behaviour  |
| E2E       | Playwright           | Full user journeys: register → login → complete a task               |

**Don't duplicate coverage across layers.** If a composable is unit-tested, the component test doesn't need to re-assert the same logic — test that the component wires it up correctly.

## What to skip

- Methods that delegate entirely to `@lewishowles/helpers` — the library has its own tests
- Implementation details: internal refs, private methods, component structure not visible to the user
- Framework behaviour: Vue's reactivity system, Vitest's mock machinery
- Rendered DOM structure for its own sake — test what something communicates, not which tag was used

## TDD workflow

Use when building new behaviour, especially composables and helpers.

1. **Red** — write the smallest failing test that describes the desired behaviour. Run it; confirm it fails with a meaningful message (not a syntax error).
2. **Green** — write the minimum code to make it pass. Don't over-engineer.
3. **Refactor** — clean up the implementation while keeping tests green.

**Why watch it fail first:** a test that passes immediately proves nothing. The failure proves the test actually exercises the code path you think it does.

### TDD in practice for Vue

- Start with composables — they're pure functions, easy to test in isolation
- Move to component logic once composable behaviour is verified
- Add component tests last for the rendered/interactive layer

## When to write tests after the fact

TDD isn't always feasible — debugging existing code, exploratory work, or time-boxed spikes. In those cases:

- Write a failing test that reproduces the bug _before_ fixing it (even for bug fixes)
- Add tests for the paths you touched when refactoring
- Prioritise tests for code that has broken before or is frequently changed

## Coverage

Coverage measures what was executed, not what was verified — 100% coverage with weak assertions is worse than 70% with sharp ones. Aim for coverage of:

- All happy paths
- Key unhappy paths (invalid input, network failure, empty state)
- Boundary conditions (0, 1, many; empty string; null/undefined)
