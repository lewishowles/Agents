# End-to-end testing

E2E and component tests verify what users experience in a real browser. Playwright is standard for new projects; respect Cypress where already established.

## General

- Avoid browser tests by default because output is token-heavy. Run focused tests only for a specific fix or failure; suggest broader user-run commands
- Do not run full suites from plan verification steps unless the user explicitly asks

## Which tool to use

- **Playwright** — preferred for new projects and suites. Supports full e2e and component testing
- **Cypress** — used in many existing projects. Continue using it where already established; don't migrate away unless asked
- **No component testing yet?** — add Playwright component tests, not Cypress

## Component testing

Component tests sit between Vitest unit tests and full e2e. They mount one component in a real browser and assert user-visible behaviour. Playwright and Cypress both support this.

### What to test

- Rendered output: visible text, ARIA attributes, element presence driven by props or slots
- User interaction: click, type, keyboard navigation, focus movement
- Slot-driven behaviour: content appears when a slot is populated, absent when it isn't
- Accessibility attributes: `aria-invalid`, `aria-disabled`, `aria-expanded`, `role`, etc.

### What not to test

- Framework internals: computed values, reactive refs, `wrapper.vm.*` belong in Vitest
- Implementation details: internal state, method calls, component structure not visible to the user
- DOM structure for its own sake: assert that an element communicates something, not that a specific tag was used

For Cypress/Playwright examples, setup config, e2e structure, and interaction patterns, see [references/patterns.md](references/patterns.md).

## Selectors

- Prefer `data-test="component.element"` over CSS selectors — stable, intent-clear, namespace-safe
- Group similar element types with `:is()` and apply single negations rather than repeating `:not()` per type:
  - ✓ `:is(button, input, select, textarea):not([disabled]), a[href], [tabindex]:not([tabindex='-1'])`
  - ✗ `:is(button:not([disabled]), input:not([disabled]), select:not([disabled])...)`
- **Extract repeated locators to named variables within a test.** If the same `page.getByTestId(...)` call appears more than once in a test body, assign it to a `const` before the assertions. Child locators (`.locator()`, `.getByTestId()`) can then be derived from it rather than re-querying from `page`.

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

- **One user journey per test** — full flows, not isolated pieces
- **Wait explicitly** — avoid `page.waitForTimeout()`; use `waitForURL()` or `waitForSelector()`
- **Cleanup** — no test data left behind; use `beforeAll`/`afterAll` for setup/teardown
- **Parallel tests** — no execution-order dependency
