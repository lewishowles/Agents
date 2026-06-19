# Vue project stack

Stack used across Vue projects. Each choice includes *why* so stale tools or better options can be assessed.

## Core stack

- **Vue 3 with `<script setup>`, Composition API**
  *Why:* smaller runtime, easier composable extraction, less boilerplate, composable reactive primitives
- **Tailwind (utility-first)**
  *Why:* colocates styles with markup, removes class-naming overhead, fast iteration, easy audits
- **Vitest**
  *Why:* Vite-native (no dual config), fast watcher, modern API; natural pairing for Vue 3 + Vite
- **Vue Router**
  *Why:* standard production router for Vue SPAs; keeps navigation, params, query strings, and route metadata explicit
- **Pinia**
  *Why:* official client-side store for Vue; simple Composition API model and strong TypeScript support
- **VueUse**
  *Why:* proven Vue composables for browser/reactive patterns; less bespoke code
- **Bun (package manager)**
  *Why:* fast installs, npm-compatible registry, drop-in replacement; npm/pnpm valid fallbacks
- **Gitflow branching**
  *Why:* release/develop separation suits static-hosted deployment style
- **GitHub Pages**
  *Why:* free static hosting, branch-based deploy, no extra infrastructure
- **Node.js (server-side) / vanilla JS (browser, VS Code extensions)**
  *Why:* Node for tooling/scripts; vanilla JS where bundle size or runtime constraints matter

## Helpers library — `@lewishowles/helpers`

Replaces ad-hoc utility packages. Check before writing helpers or adding utility dependencies. Full docs in package README.

Import path: `import { getNextIndex } from "@lewishowles/helpers/array"`

Key helpers:
- Type guards: `isNonEmptyArray`, `isNonEmptyString`, `isNonEmptyObject`, `isNonEmptySlot`
- Validation: `validateOrFallback`, `validateField`
- Object access: `get`, `set`, `forget`, `deepMerge`, `pick`, `omit`, `pluck`
- Array operations: `getNextIndex`, `chunk`, `compact`, `unique`
- Strings: `StringManipulator`
- URLs: `getUrlParameter`, `updateUrlParameter`
- Vue: `runComponentMethod`

Missing helper — discuss adding to `@lewishowles/helpers`, not inlining or adding dependency.

## Component library — `@lewishowles/components`

Opinionated accessible UI component library. Use live docs at [components.howles.dev](https://components.howles.dev/), not memory. Missing component — discuss adding it there, not one-off duplicates.

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

## Completion

For frontend UI changes, run [the accessibility checklist](../../accessibility/references/checklist.md) before handoff.
