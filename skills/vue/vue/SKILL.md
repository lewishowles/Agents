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
- Prefer `v-bind="{ prop: value }"` for variable/expression bindings, especially multiple bindings
- Use regular attributes for literal strings, including classes and ARIA values: `class="..."`, `aria-live="polite"`
- Lowercase component names in templates
- Always two-word minimum component names per Vue best practices
- Max 5 attributes per line (single); 1 per line (multiline)
- Import groups: destructurable → non-destructurable → Components, blank line between
- Always wrap named slot content in an explicit `<template #name>` tag — never pass bare content to a named slot without a wrapper

## Macro order

- `defineProps` → `defineModel` → `defineEmits` → implementation → `defineExpose` (last)

## Reactivity

- Prefer `ref()` over `reactive()` by default. Refs destructure safely and make `.value` mutations explicit
- Use `reactive()` only when object identity and deep object ergonomics matter
- Do not destructure reactive objects unless using `toRefs()` or `storeToRefs()`
- Use `shallowRef()` for large objects, fetched payloads, component/library instances, maps, charts, editors, and other values that do not need deep reactivity
- Use `markRaw()` for external class instances or third-party objects Vue should not proxy
- Prefer VueUse composables before writing custom browser/reactive utilities

## Props

Every prop gets a concise, user-focused JSDoc block:

```vue
const props = defineProps({ /** * The date to display, formatted as ISO 8601. */ date: { type:
String, required: true, }, /** * The locale to use when formatting the date. If not provided, uses
the user's locale. */ locale: { type: String, default: undefined, }, });
```

### Prop bindings

Prefer object `v-bind` over `:` shorthand for variable/expression prop bindings:

```vue
<!-- ✓ -->
<my-component v-bind="{ count }" />
<my-component class="compact" aria-live="polite" />

<!-- ✗ -->
<my-component :count />
<my-component :count="count" />
<my-component v-bind="{ class: 'compact', ariaLive: 'polite' }" />
```

## Computed properties

- Non-simple computed: multiline with blank lines around
- Order: variables and single-line computed, then multi-line computed, then functions
- Every computed property gets a single-line comment explaining what it represents
- Computed properties must be pure: no API calls, no mutations, no timers, no async side effects
- Use computed values for filtered/sorted lists and complex class maps
- Copy arrays before sorting or reversing inside computed values

```vue
// Whether an error slot has been provided. const haveError = computed(() =>
isNonEmptySlot(slots.error)); // The formatted date string, ready for display. const displayDate =
computed(() => { if (!isNonEmptyString(props.date)) { return null; } return new
Date(props.date).toLocaleDateString(props.locale); });
```

## Component patterns

- Extract shared logic into composables (`useInputId`, `useFormSupplementary`)
- Computed booleans for state/slot checks (`haveError`, `havePrefix`)
- Slot-driven composition with `isNonEmptySlot` guards

## provide / inject

- Key by the providing component's name: `provide("dropdown-menu", { selectMenuItem })`
- Provide an object, not a bare value — keeps related functionality under one key and additions non-breaking
- At the inject site, destructure with an empty object default: `const { selectMenuItem } = inject("dropdown-menu", {})`

## Component organisation

- `src/views/` — page views, organised by domain (e.g., `categories/`, `settings/`)
- `src/components/` — components organised by function/domain (`layout/`, `form/`, etc.)
- Fragment components: nested within parent directory, only used by that parent
- `src/composables/` — `use-*` composables, organised by feature
- Tests colocated: `component.test.js`, `component.cy.js`

## Component naming

- Lowercase kebab-case (`form-input`, `data-table`)
- Always two words minimum — single-word names conflict with native HTML elements
- Name from general to specific — most specific word last: `form-date-picker` not `date-picker-form`

## Conventions

- Named exports for composables and utilities — `export function useX` not `export default function useX`
- Named functions for component methods; arrow functions for inline handlers and callbacks only
- Do not combine `v-if` and `v-for` on the same element — filter with a computed value or wrap in `<template>`
- Treat `v-html` as a security risk. Use only with trusted, sanitised content
- Avoid dynamic Tailwind class string construction that prevents class detection. Map states to complete class names
- In Markdown docs, do not place a literal `</script>` inside Vue SFC code fences if the renderer may parse it as HTML. Escape it or split the closing tag.

## File-based routing

Vue Router file-based routing generates routes from `src/pages/`; the file path is the URL. Requires the build plugin.

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

- Avoid `index.vue` — use route groups like `(home).vue` for meaningful names
- Name params explicitly: `[userId]` not `[id]`
- Optional params: `[[slug]].vue` matches with or without the segment
- Catch-all: `[...path].vue` matches any remaining path including slashes
- `definePage()` inside a page component sets per-route `meta`, `name`, or `alias`

```vue
<!-- src/pages/users/[userId].vue -->
<script setup>
import { definePage } from "vue-router";

definePage({
  meta: { requiresAuth: true },
});
</script>
```

## Advanced patterns

Fragment composition, composables as global state, computed chains, reusable templates, dynamic slots, skeleton loaders, Pinia setup store, keep-alive, Suspense, Teleport, v-memo, watch/watchEffect — see [references/advanced-patterns.md](references/advanced-patterns.md).

## Completion

For UI changes, run the accessibility gate in [the accessibility checklist](../../accessibility/references/checklist.md) before handoff.
