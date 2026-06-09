# Skills

Reusable instruction files covering coding style, frameworks, testing, writing, and process.

## How to use

- Say **"use my [skill name] skill"** to load a specific file — for example, "use my vue and code-style skills."
- Say **"use my skills"** and I'll determine which are relevant and load them automatically.

When the task makes a skill's relevance obvious — editing a `.vue` file, writing docs, reviewing a PR — load the relevant skills without being asked.

## Available skills

### accessibility
**When to use:** Use this skill when writing or reviewing any HTML, UI components, or interface copy — even if accessibility isn't mentioned. Covers WCAG 2.2 AA baseline (AAA where feasible): colour contrast, keyboard access, screen readers, semantic HTML, focus management, forms & validation, live regions, touch targets (iOS 44×44, Android 48×48), dynamic content, and inclusive design. Apply proactively: accessible design is correct design.
**Combine with:** code-style, vue, swift-ui

### accessibility-audit
**When to use:** Use this skill when conducting an accessibility audit of a page, component, or PR — distinct from building accessibly (use the accessibility skill for that). Two modes: quick PR triage or full client audit. Triggers: "audit for accessibility", "a11y check", "WCAG compliance", "is this accessible?", preparing a client accessibility report.
**Avoid:** Building or fixing a component (use the accessibility skill for guidance); A general UI design review with no accessibility scope; No UI, design artefacts, or code to review
**Combine with:** accessibility, ui-copy

### bash
**When to use:** Use this skill when writing shell scripts, zsh functions, bash utilities, .env files, or config files. Apply even for short scripts or helper functions — covers bash patterns, minimal documentation style, and config file conventions.

### code-review
**When to use:** Use this skill when reviewing code — a PR, a diff, or an individual file — or when receiving review feedback. Applies your conventions (accessibility, code-style, error-handling, frontend-security, web-performance) as a checklist, and covers how to give and receive feedback.
**Avoid:** Writing new code (apply the relevant stack skills instead); A general question about code quality with no specific diff to review
**Combine with:** code-style, accessibility, error-handling, frontend-security, web-performance

### code-style
**When to use:** Use this skill on every code change — even small snippets. Covers tabs vs spaces, quote style, semicolons, naming conventions, JSDoc comments, and documentation patterns. This is the baseline style guide for all code.
**Combine with:** vue, vue-project-stack, swift, typescript

### codebase-memory
**When to use:** Use this skill when answering structural code queries with the codebase knowledge graph, including architecture, callers, dependencies, impact analysis, dead code, graph query syntax, Cypher examples, edge types, and search_graph usage.

### debugging
**When to use:** Use this skill when encountering any bug, test failure, or unexpected behaviour — before proposing a fix. Covers root-cause investigation, hypothesis testing, and minimal targeted fixes for Vue/Vite/Vitest and Swift/SwiftUI projects.
**Avoid:** The user is asking a general question unrelated to a specific failure; You have already identified the root cause and are ready to implement
**Combine with:** unit-testing, e2e-testing, vite-patterns, swift

### dependencies
**When to use:** Use this skill whenever a package installation, npm/bun add, or new dependency is mentioned or considered — even if just suggesting a library. Covers when to add packages, what to avoid, the @lewishowles/helpers and @lewishowles/components libraries that replace common packages, and when to discuss before installing.

### e2e-testing
**When to use:** Use this skill when writing, reviewing, or planning end-to-end and browser-based component tests with Playwright or Cypress. It guides agents through user-focused browser automation, interaction coverage, test structure, selector strategy, and CI setup. For isolated logic or rendering checks that do not need a browser, use the unit-testing skill instead.
**Combine with:** code-style, unit-testing, vue-project-stack

### error-handling
**When to use:** Use this skill when writing functions that accept parameters, making API calls, or handling any response data — even if errors aren't the main topic. Covers input validation with helper utilities, API response validation, graceful fallbacks, and what NOT to handle. Apply proactively when writing JavaScript/TypeScript functions.

### frontend-security
**When to use:** Use this skill when writing or reviewing client-side code for security implications. Covers XSS prevention, Content Security Policy, safe v-html usage, authentication token handling, secrets hygiene, and dependency security for Vue/TypeScript projects. Apply proactively when handling user input, rendering dynamic content, or managing auth state.
**Avoid:** Writing server-side code, API routes, or database queries; A general code review with no security implications
**Combine with:** error-handling, vue, vite-patterns

### pinia
**When to use:** Use this skill when working with Pinia client-side stores in Vue projects. Covers setup stores, state/getter/action usage, storeToRefs, SSR-safe access, HMR, testing with @pinia/testing, and the boundary between Pinia, Pinia Colada, and VueUse.
**Combine with:** vue, vue-project-stack, unit-testing

### pinia-colada
**When to use:** Use this skill when working with @pinia/colada for async data fetching and server state in Vue projects. TRIGGER when: code imports from `@pinia/colada`, uses `useQuery`, `useMutation`, `defineQuery`, `defineMutation`, `useQueryCache`, or `invalidateQueries`; when setting up async data fetching in a Vue project; when working in `src/queries/`.

### readme
**When to use:** Use this skill when writing or editing a README file (README.md or similar). Covers what belongs in a README, what doesn't, structure, and the "no fluff that doesn't help the average reader" principle — example: a bash script for macOS shouldn't mention Windows alternatives that don't exist. Pair with the writing skill for voice and tone baselines.

### refactoring
**When to use:** Use this skill when refactoring existing code or triaging technical debt. Covers behaviour-preserving refactoring technique (one change at a time, tests pass at every step), and a lightweight debt categorisation and prioritisation approach. Distinct from debugging (fixing a bug) and from new feature work.
**Avoid:** Fixing a bug — use the debugging skill; Adding new behaviour — that is feature work, not refactoring; The user hasn't asked for a refactor (don't improve adjacent code unprompted)
**Combine with:** code-style, unit-testing, debugging

### swift
**When to use:** Use this skill when writing or editing any Swift code — macOS apps, command-line tools, scripts, system tools. Covers comment style, naming, spacing, concurrency, error handling, process management, and environment setup. For SwiftUI-specific patterns, use the swift-ui skill.
**Combine with:** code-style

### swift-ui
**When to use:** Use this skill when writing or reviewing SwiftUI code — views, state management, view composition, navigation, and performance. Covers modern patterns (@Observable, @Bindable), anti-patterns (ObservableObject, @Published), and optimization techniques for responsive interfaces.
**Combine with:** swift, code-style, accessibility

### testing
**When to use:** Use this skill when deciding what to test, at which layer, and in what order — before writing the tests themselves. Covers the test pyramid, TDD red-green-refactor workflow, and what to skip. For the mechanics of writing tests, see unit-testing and e2e-testing.
**Avoid:** Writing the actual test code — use unit-testing or e2e-testing; Debugging a failing test — use debugging
**Combine with:** unit-testing, e2e-testing, debugging, refactoring

### typescript
**When to use:** Use this skill when working in TypeScript files (.ts, .tsx, .vue with lang="ts") or when type errors, type definitions, or generics are involved. Covers keeping types simple, when `as any` is acceptable, avoiding type gymnastics, and always explaining type errors rather than silently suppressing them.
**Combine with:** code-style

### ui-copy
**When to use:** Use this skill when writing UI microcopy — button labels, error messages, empty states, tooltips, CTAs, form helper text, confirmation dialogs. Covers being specific and action-oriented, surfacing useful context, and avoiding vague filler. Pair with the writing skill for voice baselines and the accessibility skill for screen-reader-friendly phrasing.

### unit-testing
**When to use:** Use this skill when writing, editing, or reviewing unit tests — Vitest, @testing-library/vue, composable testing, XCTest. Covers testing philosophy (happy and unhappy paths), what to skip (methods that delegate to @lewishowles/helpers), and meaningful assertions over snapshots. Always apply when working in *.test.js files or when the user mentions tests, specs, or coverage. For end-to-end tests, see the e2e-testing skill if present.
**Combine with:** code-style, pinia, vue, typescript

### vite-patterns
**When to use:** Use this skill when configuring vite.config.ts, managing environment variables, or troubleshooting build/dev server issues. Covers config structure, environment variables, security boundaries, library mode, dev vs build differences, and common pitfalls.

### vue
**When to use:** Use this skill when working with .vue files, Vue components, composables, or Vue templates — even for small edits. Covers Vue 3 Composition API patterns, script setup, macro order, computed property organisation, component patterns, and component directory organisation. For project-specific stack choices (Bun, Vitest, Gitflow, @lewishowles/helpers, @lewishowles/components), see the vue-project-stack skill.
**Combine with:** code-style, pinia, vue-project-stack, vue-router, vueuse-functions, typescript

### vue-project-stack
**When to use:** Use this skill when working in a Vue project that uses the wider Lewis Howles stack. Covers the chosen tools (Vue 3 with script setup, Tailwind, Vitest, Bun, Gitflow, GitHub Pages) with the *why* for each so suggestions can flag outdated choices, plus the @lewishowles/helpers and @lewishowles/components libraries that replace common packages.
**Combine with:** vue, code-style, dependencies

### vue-router
**When to use:** Use this skill when working with Vue Router routes, navigation guards, params, query strings, layouts, redirects, or route-driven state. Covers async guards, same-route param updates, side-effect cleanup, and the boundary between router state and component state.
**Combine with:** vue, vue-project-stack, accessibility

### vueuse-functions
**When to use:** Apply VueUse composables where appropriate to build concise, maintainable Vue.js / Nuxt features.

### web-performance
**When to use:** Use this skill when optimising runtime performance, Core Web Vitals, bundle size, or asset loading for Vue/Vite projects — including GitHub Pages deployments. Covers LCP, CLS, INP, Vue reactivity cost, code splitting, images, fonts, and measurement. Distinct from vite-patterns (build config) and accessibility (which covers prefers-reduced-motion).
**Avoid:** Configuring the Vite build — use vite-patterns; Writing animation or transition code — check accessibility for reduced-motion first
**Combine with:** vite-patterns, vue, accessibility

### writing
**When to use:** Use this skill when writing or editing prose — blog posts, documentation, longform content, marketing copy. Covers voice, tone, structure, examples, language conventions (UK spelling, sentence case, em-dashes), and what to avoid (preachy tone, padding, opening summaries). For README files specifically, see the readme skill. For UI microcopy (buttons, error messages, empty states), see the ui-copy skill.
