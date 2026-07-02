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

More tests at bottom: fast, isolated, cheap. Fewer at top: slow, realistic, expensive.

When `.agent/scripts/project-diagnostics.py` exists, it is the default way to run tests — not raw CLI commands. Use `--list` before choosing verification. Prefer `--check <name>` for narrowest useful layer; reserve `--all` for user-approved broad checks.

## What to test at each layer

| Layer     | Test with            | Test what                                                            |
| --------- | -------------------- | -------------------------------------------------------------------- |
| Unit      | Vitest               | Composables, computed properties, helpers, edge cases, invalid input |
| Component | Playwright / Cypress | Rendered output, ARIA attributes, user interactions, slot behaviour  |
| E2E       | Playwright           | Full user journeys: register → login → complete a task               |

**Don't duplicate coverage across layers.** If a composable is unit-tested, component test only proves wiring.

## Strategy by system type

Use this when deciding where coverage belongs:

| System type | Useful coverage |
| ----------- | --------------- |
| API endpoints | Unit-test business rules; integration-test HTTP contracts, auth failures, validation, and error responses |
| Data pipelines | Validate inputs, transformations, idempotency, retry behaviour, and corrupt or partial data |
| Frontend | Cover composables, component interactions, accessibility states, and critical user journeys |
| Infrastructure | Prefer smoke tests, config validation, rollback rehearsal, and monitoring checks over brittle implementation assertions |

## What to skip

- Methods that delegate entirely to `@lewishowles/helpers` — the library has its own tests
- Implementation details: internal refs, private methods, component structure users cannot see
- Framework behaviour: Vue's reactivity system, Vitest's mock machinery
- Rendered DOM structure for its own sake — test what it communicates, not which tag was used

## TDD workflow

Use for new behaviour, especially composables and helpers.

1. **Red** — write smallest failing test for desired behaviour. Run it; confirm meaningful failure, not syntax error.
2. **Green** — write the minimum code to make it pass. Don't over-engineer.
3. **Refactor** — clean up the implementation while keeping tests green.

**Why watch it fail first:** a test that passes immediately proves nothing. Failure proves it exercises intended path.

### TDD in practice for Vue

- Start with composables — pure functions, easy to test in isolation
- Move to component logic once composable behaviour is verified
- Add component tests last for the rendered/interactive layer

## When to write tests after the fact

TDD is not always feasible for existing bugs, exploratory work, or spikes. In those cases:

- Write a failing test that reproduces the bug _before_ fixing it (even for bug fixes)
- Add tests for touched paths when refactoring
- Prioritise tests for code that has broken before or is frequently changed

## Coverage

Coverage measures what ran, not what was verified. 100% with weak assertions is worse than 70% with sharp ones. Cover:

- All happy paths
- Key unhappy paths (invalid input, network failure, empty state)
- Boundary conditions (0, 1, many; empty string; null/undefined)
