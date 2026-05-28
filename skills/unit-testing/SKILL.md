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

### Component logic test structure

- Top level component group names should use `kebab-case` to refer to the component (e.g. `form-input`, not `FormInput`)
- Use unit tests for component logic only when the logic cannot reasonably be extracted to a composable or helper
- Do not assert visible text, DOM attributes, keyboard behaviour, or rendered states here; use Playwright/Cypress component tests

```javascript
import { mount } from "@vue/test-utils";
import { describe, expect, test } from "vitest";

import FormCounter from "./form-counter.vue";

describe("form-counter", () => {
	describe("Emits", () => {
		test("Emits an updated count when incremented", () => {
			const wrapper = mount(FormCounter, {
				props: {
					modelValue: 2,
				},
			});

			wrapper.vm.increment();

			expect(wrapper.emitted("update:modelValue")).toEqual([[3]]);
		});
	});
});
```

### Composable test structure

```javascript
// src/composables/use-form.test.js
import { describe, expect, test } from "vitest";

import { useForm } from "./use-form";

describe("useForm", () => {
	describe("Initialisation", () => {
		test("Initialises with default values", () => {
			const { data } = useForm({
				name: "",
				email: "",
			});

			expect(data.value).toEqual({ name: "", email: "" });
		});
	});

	describe("Computed", () => {
		test("hasErrors is true when errors are present", () => {
			const { errors, hasErrors } = useForm({
				name: "",
			});

			errors.value.name = "Name is required";

			expect(hasErrors.value).toBe(true);
		});
	});

	describe("Methods", () => {
		test("Updates field values", () => {
			const { data, updateField } = useForm({
				name: "",
				email: "",
			});

			updateField("name", "Lewis");

			expect(data.value.name).toBe("Lewis");
		});

		test("Validates required fields", () => {
			const { validate, errors } = useForm(
				{ name: "" },
				{
					name: { required: true },
				}
			);

			validate();

			expect(errors.value.name).toBeDefined();
		});

		test("Resets the form to its initial state", () => {
			const { data, updateField, reset } = useForm({
				name: "Lewis",
			});

			updateField("name", "Jane");
			reset();

			expect(data.value.name).toBe("Lewis");
		});
	});
});
```

### Helper test structure

```javascript
import { describe, expect, test } from "vitest";
import get from ".";

describe("get", () => {
	test("Retrieves a top-level property", () => {
		const sampleObject = {
			name: "Sophie",
			profiles: {
				linkedIn: "linkedin/sophie",
				behance: {
					icon: "behance.icon",
					url: "behance/sophie",
				},
			},
		};

		expect(get(sampleObject, "name")).toBe("Sophie");
	});
});
```

### Testing input types

When a function expects a specific input type, test invalid types together with `test.for()` so coverage stays strict without repeating the same assertion.

Start with the shared invalid-type list:

```javascript
test.for([
	["boolean (true)", true],
	["boolean (false)", false],
	["number (positive)", 1],
	["number (negative)", -1],
	["number (NaN)", NaN],
	["string (non-empty)", "string"],
	["string (empty)", ""],
	["object (non-empty)", { property: "value" }],
	["object (empty)", {}],
	["array (non-empty)", [1, 2, 3]],
	["array (empty)", []],
	["null", null],
	["undefined", undefined],
])("Rejects invalid <something>: %s", ([, input]) => {
	expect(myHelper(input)).toBe("...");
});
```

Then remove any cases that should pass for the helper being tested. For example, when testing `isNonEmptyObject`, remove:

```javascript
["object (non-empty)", { property: "value" }],
```

because that is the valid case.

### File co-location

Place test file next to component, composable, or test using `.test.js` extension. Vitest discovers and runs automatically.
