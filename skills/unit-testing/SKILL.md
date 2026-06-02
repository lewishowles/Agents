---
name: unit-testing
description: >
  Use this skill when writing, editing, or reviewing unit tests — Vitest, @testing-library/vue, composable testing, XCTest. Covers testing philosophy (happy and unhappy paths), what to skip (methods that delegate to @lewishowles/helpers), and meaningful assertions over snapshots. Always apply when working in *.test.js files or when the user mentions tests, specs, or coverage. For end-to-end tests, see the e2e-testing skill if present.
related-skills:
  - code-style
  - pinia
  - vue
  - typescript
---

# Unit testing

## General

- Over-test: happy/unhappy paths, valid/invalid variants
- Meaningful assertions over snapshots for volatile content
- For JSON or other serialised output, assert decoded structure or user-visible behaviour unless key order is part of a deliberately implemented contract. Do not test object key order from standard encoders because it is often not guaranteed and leads to brittle failures.
- Separate test setup from assertions like separating variables from logic in JS
- Keep imports at the top of the file
- Test and group names are capitalised, human-readable, and self-contained; method/computed names may stay exact
- Group tests by collection, e.g. "Initialisation", "Computed", "Methods"
- **Do not** write interaction, rendered-state, or DOM-presence tests in unit tests; those are covered in Playwright/Cypress component tests. DOM checks like `wrapper.find("[data-test=...]").exists()` belong in browser component tests, not Vitest
- Avoid running tests by default because output is token-heavy. Run only focused tests when needed to verify a specific fix or failure; suggest broader commands for the user to run

## Vue & Vitest

- Vitest; unit-test computed properties and heavily-used methods
- Skip tests for methods delegating to `@lewishowles/helpers`
- Component logic in unit tests: focus on computed properties, emitted events, composables, and heavily-used methods. Rendered state belongs in Playwright/Cypress component tests
- Composables: test reactive state, side effects, lifecycle hooks
- For async updates in tests, import `nextTick` from Vue and use `await nextTick()` instead of `await wrapper.vm.$nextTick()`
- Use `flushPromises()` when waiting for pending promises, API mocks, or async component setup
- Use `vi` for spies, fake timers, and module mocks; restore mocks after each test when state can leak
- Use `expectTypeOf` or `assertType` for type-level assertions when runtime assertions cannot cover the contract
- Test component behaviour as a black box. Avoid assertions tied to internal refs, private methods, or component implementation structure
- Avoid snapshot-only tests. A snapshot may support a focused assertion, but should not be the only proof
- Wrap async setup components in `Suspense` in tests
- Configure Pinia explicitly in tests. Use `@pinia/testing` when component tests need stores without real action side effects
- Test lifecycle-dependent composables through a small helper component when they rely on mount/unmount hooks

For component, composable, helper, and `test.for` input-type examples, see [references/examples.md](references/examples.md).

### Component logic test structure

- Top-level group names use `kebab-case` to match the component (`form-input`, not `FormInput`)
- Only test component logic that can't reasonably be extracted to a composable or helper
- Do not assert visible text, DOM attributes, keyboard behaviour, or rendered states — use Playwright/Cypress for those

### File co-location

Place test file next to component, composable, or utility using `.test.js`. Vitest discovers and runs automatically.
