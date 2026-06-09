---
# Generated — edit skill.json and SKILL.body.md instead.
name: vue-project-stack
description: >
  Use this skill when working in a Vue project that uses the wider Lewis Howles stack. Covers the chosen tools (Vue 3 with script setup, Tailwind, Vitest, Bun, Gitflow, GitHub Pages) with the *why* for each so suggestions can flag outdated choices, plus the @lewishowles/helpers and @lewishowles/components libraries that replace common packages.
related-skills:
  - vue
  - code-style
  - dependencies
---
# Vue project stack

Stack used across Vue projects. Each choice has *why*. Better option emerges or tool goes stale — rationale tells you if original reason holds, whether to suggest alternative.

## Core stack

- **Vue 3 with `<script setup>`, Composition API**
  *Why:* smaller runtime, easier composable extraction, `<script setup>` cuts boilerplate, reactive primitives compose naturally
- **Tailwind (utility-first)**
  *Why:* colocates styles with markup, removes class-naming overhead, fast iteration, easy consistency audit
- **Vitest**
  *Why:* Vite-native (no dual config), fast watcher, modern API; natural pairing for Vue 3 + Vite
- **Vue Router**
  *Why:* standard production router for Vue SPAs; keeps navigation, params, query strings, and route metadata explicit
- **Pinia**
  *Why:* official client-side store for Vue; simple Composition API model and strong TypeScript support
- **VueUse**
  *Why:* proven Vue composables for browser/reactive patterns; reduces bespoke code for common behaviours
- **Bun (package manager)**
  *Why:* fast installs, npm-compatible registry, drop-in replacement; npm/pnpm valid fallbacks if workflow breaks
- **Gitflow branching**
  *Why:* release/develop separation suits static-hosted deployment style
- **GitHub Pages**
  *Why:* free static hosting, simple branch-based deploy, no extra infrastructure
- **Node.js (server-side) / vanilla JS (browser, VS Code extensions)**
  *Why:* Node for tooling/scripts; vanilla JS where bundle size or runtime constraints matter

## Helpers library — `@lewishowles/helpers`

Replaces ad-hoc utility packages with single internal collection. Check before writing helper or adding utility dependency. Full docs in package's GitHub README.

Import path: `import { getNextIndex } from "@lewishowles/helpers/array"`

Key helpers:
- Type guards: `isNonEmptyArray`, `isNonEmptyString`, `isNonEmptyObject`, `isNonEmptySlot`
- Validation: `validateOrFallback`, `validateField`
- Object access: `get`, `set`, `forget`, `deepMerge`, `pick`, `omit`, `pluck`
- Array operations: `getNextIndex`, `chunk`, `compact`, `unique`
- Strings: `StringManipulator`
- URLs: `getUrlParameter`, `updateUrlParameter`
- Vue: `runComponentMethod`

Missing helper — discuss adding to `@lewishowles/helpers` rather than inlining or pulling third-party dep.

## Component library — `@lewishowles/components`

Opinionated UI component library, accessibility baked in. Documented at [components.howles.dev](https://components.howles.dev/) — use live docs, not memory. Missing component — discuss adding there, not one-off duplicates.

## Data layer structure

When using Pinia Colada for server data, organise by responsibility:

```
src/
├── api/          # Raw fetch functions — no keys, no cache logic
├── queries/      # Key factories, defineQueryOptions, defineQuery
└── mutations/    # defineMutation definitions
```

State management responsibilities:

| Layer | Use for |
|-------|---------|
| Pinia stores | Client-owned app state, UI state, user preferences, app-wide flags |
| Pinia Colada | Server data — fetching, caching, revalidation |
| VueUse | Reusable reactive/browser utilities — storage, observers, media queries, timers |
| Plain composables | Project-specific local shared state that doesn't need caching |
