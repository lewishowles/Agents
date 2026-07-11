---
# Generated — edit skill.json and SKILL.body.md instead.
name: vue
description: >
  Use this skill when working with .vue files, Vue components, composables, or Vue templates — even for small edits. Covers Vue 3 Composition API patterns, script setup, macro order, computed property organisation, component patterns, and component directory organisation. For project-specific stack choices (Bun, Vitest, Gitflow, @lewishowles/helpers, @lewishowles/components), see the vue-project-stack skill.
do-not-use-when:
  - Editing a non-Vue TypeScript, JavaScript, Swift, or Markdown file
  - Discussing frontend design, accessibility, performance, or security without Vue component code changes
  - Working only in Vite, router, Pinia, or VueUse configuration where a narrower Vue skill applies
related-skills:
  - code-style
  - vue-pinia
  - vue-project-stack
  - vue-router
  - vue-use
  - typescript
---
# Vue

## Formatting

- Tab HTML indentation
- Always self-close where possible (`<img />`, `<component />`)
- Use v-bind object syntax for variables/expressions, especially multiple
- Use regular attributes for literals: class="...", aria-live="polite"
- Lowercase component names in templates
- Always two-word component names
- Max 5 attributes (single line); 1 per line (multiline)
- Import groups: destructurable → non-destructurable → Components; blank line between
- Always wrap named slot content in explicit `<template #name>`; never pass bare named-slot content

## Macro order

- `defineProps` → `defineModel` → `defineEmits` → implementation → `defineExpose` (last)

## Reactivity

- Prefer ref() (destructures safely, explicit .value)
- Use reactive() only for deep object identity/ergonomics
- Do not destructure reactive objects unless using `toRefs()` or `storeToRefs()`
- Use shallowRef() for large/fetched objects, components, maps, charts, editors
- Use markRaw() for external classes/third-party objects
- Prefer VueUse composables before writing custom browser/reactive utilities

## Props

Every prop gets concise, user-focused JSDoc:

```vue
const props = defineProps({
	/**
	 * The date to display, formatted as ISO 8601.
	 */
	date: {
		type: String,
		required: true,
	},
	/**
	 * The locale to use when formatting the date. If not provided, uses the user's locale.
	 */
	locale: {
		type: String,
		default: undefined,
	},
});
```

### Prop bindings

Use v-bind object syntax for variables. Use v-model for two-way bindings (not v-bind + @update:model-value):

```vue
<!-- ✓ -->
<my-component v-bind="{ count }" />
<my-component class="compact" aria-live="polite" />
<form-input v-model="searchQuery" />

<!-- ✗ -->
<my-component :count />
<my-component :count="count" />
<my-component v-bind="{ class: 'compact', ariaLive: 'polite' }" />
<form-input v-bind="{ modelValue: searchQuery }" @update:model-value="searchQuery = $event" />
```

## Computed properties

- Multiline computed: blank lines around
- Order: single-line, multiline, then functions
- Single-line comment for each computed property
- Pure only: no API calls, mutations, timers, async
- Use computed values for filtered/sorted lists and complex class maps
- Copy arrays before sorting or reversing inside computed values

```vue
// Whether an error slot has been provided.
const haveError = computed(() => isNonEmptySlot(slots.error));

// The formatted date string, ready for display.
const displayDate = computed(() => {
	if (!isNonEmptyString(props.date)) {
		return null;
	}

	return new Date(props.date).toLocaleDateString(props.locale);
});
```

## Component registration

Use local imports (tree-shakeable). Auto-import via Vite plugin (e.g., unplugin-vue-components) preferred. Global registration only for genuinely app-wide primitives.

## Component patterns

- Extract shared logic into composables (`useInputId`, `useFormSupplementary`)
- Computed booleans for state/slot checks (`haveError`, `havePrefix`)
- Slot-driven composition with `isNonEmptySlot` guards

## provide / inject

- Key by component name: provide("dropdown-menu", { selectMenuItem })
- Provide object (not bare value) for extensibility
- Destructure with empty object default: const { selectMenuItem } = inject("dropdown-menu", {})

## Component organisation

- `src/views/` — page views, organised by domain (e.g., `categories/`, `settings/`)
- `src/components/` — components organised by function/domain (`layout/`, `form/`, etc.)
- Fragment components: nested within parent directory, only used by that parent
- `src/composables/` — `use-*` composables, organised by feature
- Tests colocated: `component.test.js`, `component.cy.js`

## Component naming

- Lowercase kebab-case (`form-input`, `data-table`)
- Always two words — single-word names conflict with native HTML elements
- Name general to specific — most specific word last: `form-date-picker` not `date-picker-form`

## Conventions

- Named exports for composables (not default)
- Named functions for methods; arrow only for inline handlers
- Avoid v-if + v-for together; use computed or <template>
- v-html is security risk; use only with trusted, sanitised content
- Avoid dynamic Tailwind strings; map to complete class names
- In Markdown docs, do not place a literal `</script>` inside Vue SFC code fences if the renderer may parse it as HTML. Escape or split the closing tag.

## File-based routing

File-based routing: file path = URL from src/pages/. Requires build plugin.

```
src/pages/
├── (home).vue              → /
├── about.vue               → /about
├── [...path].vue           → catch-all
├── users.edit.vue          → /users/edit  (dot notation, bypasses users.vue layout)
├── users.vue               → layout for /users/* (must contain <router-view />)
└── users/
    ├── (user-list).vue     → /users
    └── [userId].vue        → /users/:userId
```

- Avoid index.vue; use groups like (home).vue for clarity
- Name params explicitly: `[userId]` not `[id]`
- Optional params: `[[slug]].vue` matches with/without segment
- Catch-all [...path].vue matches remaining path (including slashes)
- definePage() sets per-route meta, name, or alias

```vue
<!-- src/pages/users/[userId].vue -->
<script setup>
import { definePage } from "vue-router";

definePage({
	meta: {
		requiresAuth: true,
	},
});
</script>
```

## Advanced patterns

See [references/advanced-patterns.md](references/advanced-patterns.md) for fragment composition, advanced patterns, Suspense, Teleport, etc.

## Completion

For UI changes, run [the accessibility checklist](../../accessibility/references/checklist.md) before handoff.
