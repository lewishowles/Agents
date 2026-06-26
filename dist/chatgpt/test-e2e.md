---
# Generated — edit skill.json and SKILL.body.md instead.
name: test-e2e
description: >
  Use this skill when writing, reviewing, or planning end-to-end and browser-based component tests with Playwright or Cypress. It guides agents through user-focused browser automation, interaction coverage, test structure, selector strategy, and CI setup. For isolated logic or rendering checks that do not need a browser, use the test-unit skill instead.
related-skills:
  - code-style
  - test-unit
  - vue-project-stack
---
# End-to-end testing

E2E and component tests verify real-browser user experience. Playwright is standard for new projects; keep Cypress where established.

## General

- Avoid browser tests by default; output is token-heavy. Run focused tests only for specific fix/failure; suggest broader user-run commands
- The diagnostics script is the default way to run tests — not `npx playwright test` or `npx cypress run` directly. When `.agent/scripts/project-diagnostics.py` exists, use `--list` to discover browser/e2e checks and `--check <name>` only for a specific fix or failure. If no diagnostics script exists, ask the user before running browser tests directly.
- Do not run full suites or diagnostics `--all` from plan verification unless user explicitly asks

## Which tool to use

- **Playwright** — preferred for new projects/suites. Supports full e2e and component testing
- **Cypress** — use where established; do not migrate unless asked
- **No component testing yet?** — add Playwright component tests, not Cypress

## Component testing

Component tests sit between Vitest unit tests and full e2e. They mount one component in a browser and assert user-visible behaviour. Playwright and Cypress both support this.

### What to test

- Rendered output depending on browser behaviour, component integration, layout, focus, keyboard use, or timing
- User interaction: click, type, keyboard navigation, focus movement
- Slot-driven behaviour: content appears when slot populated, absent when not
- Accessibility attributes: `aria-invalid`, `aria-disabled`, `aria-expanded`, `role`, etc.

### What not to test

- Framework internals: computed values, reactive refs, `wrapper.vm.*` belong in Vitest
- Implementation details: internal state, method calls, component structure users cannot see
- DOM structure for its own sake: assert what element communicates, not specific tag
- Cheap static render contracts such as root styling hooks, slot fallback text, and prop-driven element presence belong in Vitest when they don't need browser behaviour

For Cypress/Playwright examples, setup config, e2e structure, and interaction patterns, see [references/patterns.md](references/patterns.md).

## Selectors

- Prefer `data-test="component.element"` over CSS selectors: stable, intent-clear, namespace-safe
- Group similar element types with `:is()` and apply single negations rather than repeating `:not()` per type:
  - ✓ `:is(button, input, select, textarea):not([disabled]), a[href], [tabindex]:not([tabindex='-1'])`
  - ✗ `:is(button:not([disabled]), input:not([disabled]), select:not([disabled])...)`
- **Extract repeated locators to named variables within a test.** If the same `page.getByTestId(...)` appears more than once, assign it to `const` before assertions. Derive child locators from it instead of re-querying `page`.

  ```js
  // ✓
  const formInput = page.getByTestId("form-input");
  const inputElement = formInput.locator("input");
  const labelElement = formInput.getByTestId("form-label");

  // ✗
  const inputElement = page.getByTestId("form-input").locator("input");
  const labelElement = page.getByTestId("form-input").getByTestId("form-label");
  ```

## Best practices

- **One user journey per test** — full flow, not isolated pieces
- **Wait explicitly** — avoid `page.waitForTimeout()`; use `waitForURL()` or `waitForSelector()`
- **Cleanup** — no test data left behind; use `beforeAll`/`afterAll` for setup/teardown
- **Parallel tests** — no execution-order dependency
