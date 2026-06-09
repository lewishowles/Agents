# Dependencies

## When to add packages

Add only for complex work needing real skill/effort:

- Framework/testing framework (Vue, Vitest, Tailwind)
- Authentication (JWT, OAuth handling)
- Specialised libraries (not trivial utilities)

## Approved ecosystem packages

These packages are default choices in Vue projects when they fit the job:

- `vue`, `vue-router`, `pinia`, `@pinia/colada`
- `@vueuse/core` and focused `@vueuse/*` packages
- `vite`, `vitest`, `@vitejs/plugin-vue`

Agents may proactively recommend these without the full dependency proposal template. Still do not install them without permission. If already installed, use them before writing bespoke equivalents.

Use VueUse before custom reactive/browser utilities for storage, media queries, breakpoints, focus, clipboard, observers, timers, network state, throttling/debouncing, and event listeners.

## When not to add packages

- Single-function or trivial packages
- JS helper libraries — `@lewishowles/helpers` replaces them (discuss adding to helpers if missing)
- UI component libraries — `@lewishowles/components` replaces them (discuss adding to components if missing)
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
