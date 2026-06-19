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

Decision and implementation guide for VueUse composables in Vue.js / Nuxt projects. Map requirements to the right function, apply its invocation rule, and prefer composables over bespoke code.

## When to Apply

- Apply for Vue.js / Nuxt development work.
- Check whether VueUse already covers the requirement before writing custom code.
- Follow the table's `Invocation` value:
  - `AUTO`: use when applicable
  - `EXTERNAL`: use only if the dependency already exists; ask to install only when needed
  - `EXPLICIT_ONLY`: use only when the user asks for it

User instructions in the prompt or `AGENTS.md` override these defaults.

## Finding a composable

When you need to find a composable for a specific requirement, read `./SKILL.ref.md` — it lists every function by category (State, Elements, Browser, Sensors, Network, Animation, Component, Watch, Reactivity, Array, Time, Utilities, and integration packages). Before using a function, consult its `./references` document for usage and types.

## Completion

For composables that affect UI behaviour, run the accessibility gate in [the accessibility checklist](../../accessibility/references/checklist.md) before handoff.
