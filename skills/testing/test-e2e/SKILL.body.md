# End-to-end testing

E2E and component tests verify real-browser user experience. Playwright is standard for new projects; keep Cypress where established.

## General

- Avoid browser tests by default; output is token-heavy. Run focused tests only for specific fixes and suggest broader user-run commands.
- Use diagnostics script: `.agent/scripts/project-diagnostics.py --list` to discover checks, `--check <name>` for specific fixes. Ask before running tests directly if diagnostics script is absent.
- Never run a full Playwright or Cypress suite or use `--all`, including through diagnostics. Diagnostics controls output volume, not execution time. Run only specific test files, and ask the user to run broad browser suites.
- Do not assume a scoped component-test file is cheap. Shared Vite configuration may still compile a broad component graph before running the selected tests. Start with one representative file and observe its startup cost. If compilation dominates, batch the necessary scoped files into one invocation instead of running each file separately; ask before continuing when the combined check may be slow or resource-intensive.

## Which tool to use

- **Playwright** — preferred for new projects/suites. Supports full e2e and component testing
- **Cypress** — use where established; do not migrate unless asked
- **No component testing yet?** — add Playwright component tests, not Cypress

## Playwright

- Use `page.localStorage` and `page.sessionStorage` to seed non-sensitive state (feature flags, onboarding, UI prefs). Never store auth tokens or secrets; use `HttpOnly` cookies instead.

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

- Prefer `data-test="component.element"` over CSS selectors: stable, intent-clear, namespace-safe.
- Group similar types with `:is()` and single negations rather than repeating `:not()`:
  - ✓ `:is(button, input, select, textarea):not([disabled]), a[href], [tabindex]:not([tabindex='-1'])`
  - ✗ `:is(button:not([disabled]), input:not([disabled]), select:not([disabled])...)`
- Extract repeated locators to named variables. Derive child locators from them instead of re-querying:

  ```js
  // ✓
  const formInput = page.getByTestId("form-input");
  const inputElement = formInput.locator("input");

  // ✗
  const inputElement = page.getByTestId("form-input").locator("input");
  ```

## Best practices

- **One user journey per test** — full flow, not isolated pieces
- **Wait explicitly** — avoid `page.waitForTimeout()`; use `waitForURL()` or `waitForSelector()`
- **Cleanup** — no test data left behind; use `beforeAll`/`afterAll` for setup/teardown
- **Parallel tests** — no execution-order dependency
