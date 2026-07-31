---
# Generated — edit skill.json and SKILL.body.md instead.
name: test-unit
description: >
  Use this skill for unit tests, including Vitest, @testing-library/vue, composable tests, or XCTest; also applies to *.test.js, tests, specs, or coverage. For E2E, see test-e2e.
do-not-use-when:
  - Running or interpreting an end-to-end, browser, or integration test
  - Discussing test strategy without writing, editing, or reviewing unit tests
  - Debugging production code where no test file or test assertion is being changed
related-skills:
  - code-style
  - vue-pinia
  - vue
  - typescript
---
# Unit testing

## General

- Over-test: happy/unhappy paths, valid/invalid variants
- Meaningful assertions over snapshots for volatile content
- For JSON/serialised output, assert decoded structure or user-visible behaviour unless key order is a deliberate contract. Do not test standard encoder key order.
- Separate test setup from assertions like separating variables from logic in JS — use a blank line between the action and any `expect()` calls
- Keep imports at the top.
- Test and group names are capitalised, human-readable, and self-contained; method/computed names may stay exact. Name the behaviour in plain active voice ("shows an error when the field is empty"), not a passive or clever restatement of the mechanism.
- Group tests by collection: "Initialisation", "Render contracts", "Computed", "Methods".
- Static render contracts may live in unit tests when cheaper than browser tests and not needing layout, interaction, browser APIs, focus, keyboard, or timing. Use "Render contracts".
- Keep interaction, layout-sensitive state, browser APIs, focus movement, keyboard, and live-region timing in component tests.
- Use diagnostics script: `.agent/scripts/project-diagnostics.py --list` to discover checks, `--check <name>` for the relevant one. For fixes, narrow with `--test-file <path>` or `--test-glob '<pattern>'`. Ask the user for full suites or `--all`.

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

### Vitest API and composable mocks

Use this when mocking API composables, SDK clients, or query-layer dependencies.

- Inspect existing local mock helpers before adding new mocks; prefer extending the project pattern over introducing a package abstraction
- Keep literal `vi.mock(...)` calls in the test file or a project-local test helper. Do not hide `vi.mock(...)` inside an imported package helper; Vitest needs to see literal mock calls for hoisting
- Define mock handlers referenced by `vi.mock(...)` with `vi.hoisted(() => vi.fn())`
- For composables, use project-local adapters that match the local module shape:

```js
const mockGet = vi.hoisted(() => vi.fn());
const mockPost = vi.hoisted(() => vi.fn());

vi.mock("@/composables/api/use-api", () => ({
	default: () => ({
		get: mockGet,
		post: mockPost,
	}),
}));
```

- For SDK clients, keep the SDK-specific class or object shape in the local test/helper:

```js
const mockGet = vi.hoisted(() => vi.fn());

vi.mock("@vendor/sdk", () => ({
	Client: class {
		get = mockGet;
	},
}));
```

- Clear or restore mocks in lifecycle hooks when handler state can leak between tests
- Only promote a shared package helper when it doesn't need to know the mocked module path, export shape, SDK class, or composable return shape.

For component, composable, helper, and `test.for` examples, see [references/examples.md](references/examples.md).

### Component logic test structure

- Top-level group names use `kebab-case` to match the component (`form-input`, not `FormInput`)
- Only test component logic that cannot reasonably move to composable/helper
- Put cheap static DOM attributes, slot fallbacks, and prop-driven presence checks in "Render contracts" when no browser needed
- Do not assert keyboard behaviour, focus movement, browser layout, CSS rendering, or timed live-region behaviour — use Playwright/Cypress for those

### File co-location

Place `.test.js` next to component, composable, or utility. Vitest discovers automatically.
