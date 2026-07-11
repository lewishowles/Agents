# VueUse Functions

Decision guide for VueUse in Vue/Nuxt. Map requirement to function per invocation rules; prefer composables.

## When to Apply

- Use for Vue / Nuxt development.
- Check whether VueUse covers requirement before custom code.
- Follow the table's `Invocation` value:
  - `AUTO`: use when applicable
  - `EXTERNAL`: use only if the dependency already exists; ask to install only when needed
  - `EXPLICIT_ONLY`: use only when the user asks for it

User instructions in the prompt or `AGENTS.md` override these defaults.

## Finding a composable

Read SKILL.ref.md for functions by category. Consult references docs before using.

## Completion

For composables affecting UI behaviour, run [the accessibility checklist](../../accessibility/references/checklist.md) before handoff.
