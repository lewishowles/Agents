---
# Generated — edit skill.json and SKILL.body.md instead.
name: e2e-testing
description: >
  Use this skill when writing, reviewing, or planning end-to-end and browser-based component tests with Playwright or Cypress. It guides agents through user-focused browser automation, interaction coverage, test structure, selector strategy, and CI setup. For isolated logic or rendering checks that do not need a browser, use the unit-testing skill instead.
related-skills:
  - code-style
  - unit-testing
  - vue-project-stack
---
# End-to-end testing

E2E and component tests verify what users see and experience in a real browser. Playwright is the current standard for new projects; Cypress is used in many existing projects and should be respected where already in place.

## General

- Avoid running tests by default because browser-test output is token-heavy. Run only focused tests when needed to verify a specific fix or failure; suggest broader commands for the user to run
- Do not run full suites from plan verification steps unless the user explicitly asks

## Which tool to use

- **Playwright** — preferred for all new projects and new test suites. Supports both full e2e and component-level testing
- **Cypress** — used in many existing projects. Continue using it where already established; don't migrate away unless asked
- **No component testing yet?** — add Playwright component tests, not Cypress

## Component testing

Component tests sit between Vitest unit tests and full e2e. They mount a single component in a real browser and assert what the user sees and experiences. Both Playwright and Cypress support this pattern.

### What to test

- Rendered output: visible text, ARIA attributes, element presence driven by props or slots
- User interaction: click, type, keyboard navigation, focus movement
- Slot-driven behaviour: content appears when a slot is populated, absent when it isn't
- Accessibility attributes: `aria-invalid`, `aria-disabled`, `aria-expanded`, `role`, etc.

### What not to test

- Framework internals: computed values, reactive refs, `wrapper.vm.*` — those belong in Vitest
- Implementation details: internal state, method calls, component structure not visible to the user
- DOM structure for its own sake: assert that an element communicates something, not that a specific tag was used

For Cypress and Playwright component test examples, Playwright setup config, full e2e test structure, and interaction patterns, see [references/patterns.md](references/patterns.md).

## Selectors

- Prefer `data-test="component.element"` over CSS selectors — stable, intent-clear, namespace-safe
- Group similar element types with `:is()` and apply single negations rather than repeating `:not()` per type:
  - ✓ `:is(button, input, select, textarea):not([disabled]), a[href], [tabindex]:not([tabindex='-1'])`
  - ✗ `:is(button:not([disabled]), input:not([disabled]), select:not([disabled])...)`

## Best practices

- **One user journey per test** — full flows, not isolated pieces
- **Wait explicitly** — avoid `page.waitForTimeout()`; use `waitForURL()` or `waitForSelector()`
- **Cleanup** — no test data left behind; use `beforeAll`/`afterAll` for setup/teardown
- **Parallel tests** — no execution-order dependency
