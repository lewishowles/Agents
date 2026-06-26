# Unit testing

## General

- Over-test: happy/unhappy paths, valid/invalid variants
- Meaningful assertions over snapshots for volatile content
- For JSON/serialised output, assert decoded structure or user-visible behaviour unless key order is a deliberate contract. Do not test standard encoder key order.
- Separate test setup from assertions like separating variables from logic in JS — use a blank line between the action and any `expect()` calls
- Keep imports at the top of the file
- Test and group names are capitalised, human-readable, and self-contained; method/computed names may stay exact
- Group tests by collection, e.g. "Initialisation", "Render contracts", "Computed", "Methods"
- Static render contracts may live in unit tests when materially cheaper than browser tests and not needing layout, interaction, browser APIs, focus, keyboard behaviour, or timing. Use "Render contracts".
- Keep interaction, layout-sensitive rendered state, browser API behaviour, focus movement, keyboard behaviour, and live-region timing in browser component tests.
- When `.agent/scripts/project-diagnostics.py` exists, it is the default way to run unit tests — not raw CLI commands. Run `--list` to discover unit-test checks and `--check <name>` for the relevant one. For a specific fix, narrow the check with repeatable `--test-file <path>` or `--test-glob '<pattern>'` arguments. Quote glob patterns so diagnostics expands them safely. Ask the user for full suites or diagnostics `--all`.

## Vue & Vitest

- Vitest; unit-test computed properties and heavily-used methods
- Skip tests for methods delegating to `@lewishowles/helpers`
- Component logic in unit tests: computed properties, emitted events, composables, heavily-used methods, cheap static render contracts
- Composables: test reactive state, side effects, lifecycle hooks
- For async updates, import `nextTick` from Vue and use `await nextTick()` instead of `await wrapper.vm.$nextTick()`
- Use `flushPromises()` when waiting for pending promises, API mocks, or async component setup
- Use `vi` for spies, fake timers, and module mocks; restore mocks after each test when state can leak
- Use `expectTypeOf` or `assertType` for type-level assertions when runtime assertions cannot cover the contract
- Test component behaviour as black box. Avoid internal refs, private methods, or implementation structure
- Avoid snapshot-only tests. A snapshot may support a focused assertion, but should not be the only proof
- Wrap async setup components in `Suspense` in tests
- Configure Pinia explicitly in tests. Use `@pinia/testing` when component tests need stores without real action side effects
- Test lifecycle-dependent composables through a small helper component when they rely on mount/unmount hooks

For component, composable, helper, and `test.for` examples, see [references/examples.md](references/examples.md).

### Component logic test structure

- Top-level group names use `kebab-case` to match the component (`form-input`, not `FormInput`)
- Only test component logic that cannot reasonably move to composable/helper
- Put cheap static DOM attributes, slot fallbacks, and prop-driven presence checks in "Render contracts" when no browser needed
- Do not assert keyboard behaviour, focus movement, browser layout, CSS rendering, or timed live-region behaviour — use Playwright/Cypress for those

### File co-location

Place `.test.js` next to component, composable, or utility. Vitest discovers automatically.
