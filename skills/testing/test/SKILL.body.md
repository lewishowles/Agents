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

More tests at the bottom: fast, isolated, cheap. Fewer at the top: slow, realistic, expensive.

When `.agent/scripts/project-diagnostics.py` exists, use `--list` to discover project checks before choosing a verification command. Prefer `--check <name>` for the narrowest useful layer; reserve `--all` for user-approved broad verification.

## What to test at each layer

| Layer     | Test with            | Test what                                                            |
| --------- | -------------------- | -------------------------------------------------------------------- |
| Unit      | Vitest               | Composables, computed properties, helpers, edge cases, invalid input |
| Component | Playwright / Cypress | Rendered output, ARIA attributes, user interactions, slot behaviour  |
| E2E       | Playwright           | Full user journeys: register → login → complete a task               |

**Don't duplicate coverage across layers.** If a composable is unit-tested, the component test only needs to prove it is wired correctly.

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

**Why watch it fail first:** a test that passes immediately proves nothing. The failure proves it exercises the intended path.

### TDD in practice for Vue

- Start with composables — they're pure functions, easy to test in isolation
- Move to component logic once composable behaviour is verified
- Add component tests last for the rendered/interactive layer

## When to write tests after the fact

TDD is not always feasible for existing bugs, exploratory work, or spikes. In those cases:

- Write a failing test that reproduces the bug _before_ fixing it (even for bug fixes)
- Add tests for the paths you touched when refactoring
- Prioritise tests for code that has broken before or is frequently changed

## Coverage

Coverage measures what ran, not what was verified. 100% with weak assertions is worse than 70% with sharp ones. Cover:

- All happy paths
- Key unhappy paths (invalid input, network failure, empty state)
- Boundary conditions (0, 1, many; empty string; null/undefined)
