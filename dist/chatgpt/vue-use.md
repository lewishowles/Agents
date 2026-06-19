---
# Generated — edit skill.json and SKILL.body.md instead.
name: vue-use
description: >
  Apply VueUse composables where appropriate to build concise, maintainable Vue.js / Nuxt features.
related-skills:
  - vue
  - vue-project-stack
---
# VueUse Functions

Decision guide for VueUse composables in Vue.js / Nuxt projects. Map requirement to function, apply invocation rule, prefer composables over bespoke code.

## When to Apply

- Apply for Vue.js / Nuxt development work.
- Check whether VueUse covers requirement before custom code.
- Follow the table's `Invocation` value:
  - `AUTO`: use when applicable
  - `EXTERNAL`: use only if the dependency already exists; ask to install only when needed
  - `EXPLICIT_ONLY`: use only when the user asks for it

User instructions in the prompt or `AGENTS.md` override these defaults.

## Finding a composable

To find a composable, read `./SKILL.ref.md` — all functions by category. Before using one, consult its `./references` document for usage and types.

## Completion

For composables affecting UI behaviour, run [the accessibility checklist](../../accessibility/references/checklist.md) before handoff.
