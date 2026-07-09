---
# Generated — edit skill.json and SKILL.body.md instead.
name: component-library
description: >
  Use this skill when choosing or using components from @lewishowles/components. Prefer its CLI and docs before source searches.
do-not-use-when:
  - Creating or changing the component library itself
  - Preparing a library-release
  - General Vue stack guidance without an @lewishowles/components discovery question; use vue-project-stack instead
  - The component API and pattern are already clear from current context
  - Designing CLI command behaviour; use human-friendly-cli instead
related-skills:
  - vue-project-stack
---
# Component library

Use the `@lewishowles/components` discovery surfaces before reading source files when the needed component, API, example, or composition pattern is not already clear.

## Core contract

After loading this skill, do this before searching `src/components/**` or `@lewishowles/components` source:

1. Check whether the current repo already shows the exact component and API needed.
2. If not, use the `components` CLI to inspect available components, examples, props, slots, events, and patterns.
3. Use live docs next when the CLI does not answer the question.
4. Search source only when the CLI/docs are missing, stale, incomplete, or the implementation detail itself is the task.

Skip the check when the current context already gives the exact component and API needed.

## `@lewishowles/components`

`@lewishowles/components` publishes the `components` CLI. Use it as the cheap discovery surface when a project consumes the library and the right component or pattern is uncertain.

Prefer these commands before source searching:

```sh
npx @lewishowles/components list
npx @lewishowles/components info <component>
npx @lewishowles/components snippet <component>
npx @lewishowles/components pattern
```

Use the CLI to answer questions like:

- What components exist for this need?
- What props, slots, events, methods, and styling hooks are available?
- What snippet examples exist for this component?
- Is there a multi-component pattern close to the requested UI?
- What does a data table, form, modal, navigation, or loading state look like without reading source files?

When the CLI does not answer the question, use live docs next if available, then targeted source inspection.

## Helpers library

`@lewishowles/helpers` does not currently publish a consumer CLI. Use its README, package exports, and local project imports to inspect available helpers. Do not claim a helpers CLI exists unless package metadata or workspace context shows one.

## Using the result

- Prefer existing components and documented patterns before building bespoke UI.
- Keep accessibility notes from the component docs or CLI output in the implementation.
- Use component names, prop names, slot names, and examples exactly as documented.
- If the discovered component is close but missing a capability, surface that as a library improvement rather than copying and forking the component locally.
- If a local project wraps the component library, check the wrapper API before importing lower-level components directly.
