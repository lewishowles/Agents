---
# Generated — edit skill.json and SKILL.body.md instead.
name: dependencies
description: >
  Use this skill whenever a package installation, npm/bun add, or new dependency is mentioned or considered — even if just suggesting a library. Covers when to add packages, what to avoid, the @lewishowles/helpers and @lewishowles/components libraries that replace common packages, and when to discuss before installing.
do-not-use-when:
  - Using an already-installed dependency without changing package manifests or install guidance
  - Reading package documentation for an API already present in the project
  - Updating project code after a dependency change that has already been decided
---
# Dependencies

## When to add packages

Add only for complex work needing real skill/effort:

- Framework/testing framework (Vue, Vitest, Tailwind)
- Authentication (JWT, OAuth handling)
- Specialised libraries (not trivial utilities)

## Approved ecosystem packages

Default Vue choices when they fit:

- `vue`, `vue-router`, `pinia`, `@pinia/colada`
- `@vueuse/core` and focused `@vueuse/*` packages
- `vite`, `vitest`, `@vitejs/plugin-vue`

Agents may recommend these without full proposal template. Do not install without permission. If installed, use before bespoke equivalents.

Use VueUse before custom reactive/browser utilities: storage, media queries, breakpoints, focus, clipboard, observers, timers, network state, throttling/debouncing, event listeners.

## When not to add packages

- Single-function or trivial packages
- JS helper libraries — `@lewishowles/helpers` replaces them; discuss adding there if missing
- UI component libraries — `@lewishowles/components` replaces them; discuss adding there if missing
- Simple data manipulation — write in project or add to `@lewishowles/helpers`

## Before adding

Always discuss with team/user. Explain:

- What it solves
- Why worth dependency
- What existing approach would be
- Estimated complexity of rolling our own

Never add without discussion/permission.

```markdown
Dependency proposal: `package-name`

- Problem: [what this solves]
- Existing option: [helper/component/local implementation]
- Roll-our-own complexity: low | medium | high — [why]
- Dependency value: [why the package earns its maintenance cost]
- Risk: [bundle size, maintenance, security, API churn]
```
