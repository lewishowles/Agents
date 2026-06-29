---
# Generated — edit skill.json and SKILL.body.md instead.
name: component-api-design
description: >
  Use this skill when designing a new component's public API — props, slots, emits, v-model, expose — or reviewing whether an existing API is consistent and discoverable.
do-not-use-when:
  - Editing component internals without changing its public props, slots, emits, models, or exposed methods
  - Fixing Vue reactivity, lifecycle, routing, store, or styling issues with no component API decision
  - Reviewing low-level code style where the public component contract is already settled
related-skills:
  - accessibility
  - code-style
  - typescript
  - vue
---
# Component API design

Design public contract before internals: props, slots, emits, `v-model`, `defineExpose`.

## API shape

- Start from component job, not DOM structure.
- Keep smallest API for known use cases; avoid speculative props and escape hatches.
- Prefer one clear composition path over parallel APIs.
- Name entries after domain concepts, not implementation details.
- Treat renaming/removing prop, slot, event, model, or exposed method as breaking.
- **Prefer generic, composable-exposed APIs over hardcoded special-casing.** Expose an identifier or ref (e.g. a generic `focusId`) rather than baking component-specific knowledge (e.g. a hardcoded field name or element type) into the component. First drafts that hardcode component-specific behaviour should be pushed back on in favour of a generic, caller-controlled alternative.

## Props

- Use props for configuration and directly rendered data.
- Prefer named props over catch-all objects unless the object is already a shared domain type.
- Keep boolean props positive and state-based: `disabled`, `loading`, `invalid`, not `notInteractive`.
- Avoid prop pairs that can drift apart; use one structured prop when values belong together.
- Do not add props for content that belongs in slots.

Follow Vue prop JSDoc rule. Describe what consumers pass, not internal use.

## Slots

- Use slots for caller-owned content, layout variation, rich markup, and UI text needing easy translation.
- Name slots by purpose: `header`, `actions`, `empty`, `error`, `item`.
- Provide slot props when translated or caller-owned content needs component state, such as counts, selected items, errors, or IDs.
- Keep slot props stable and minimal; they are part of the public API.
- Do not use a slot when a simple string prop is enough.

Require explicit `<template #name>` for named slots, as covered by Vue skill.

## Emits

- Use emits for user actions and meaningful state transitions.
- Name events after what happened: `submit`, `close`, `select`, `update:open`.
- Emit domain payloads, not DOM events, unless wrapping a native control intentionally.
- Keep payload shape consistent across related events.
- Do not emit internal lifecycle steps consumers cannot act on.

## v-model

- Use `v-model` when the parent owns a value and the component edits it.
- Prefer a single default model for the primary editable value.
- Use named models only for multiple independent parent-owned values.
- Pair model names with the domain concept: `v-model:open`, `v-model:selected-id`, `v-model:filters`.
- Avoid duplicating model with change event unless consumers need controlled state plus explicit action.

## defineExpose

- Expose methods only for imperative actions props/slots/events cannot express cleanly.
- Keep exposed methods narrow: `focus()`, `open()`, `close()`, `reset()`.
- Do not expose internal refs, stores, query state, or implementation helpers.
- Document why imperative API exists when declarative API would look plausible.

## Review checklist

- Can consumers understand the API without reading internals?
- Are props, slots, emits, models, and exposed methods each used for the right responsibility?
- Is there one obvious way to complete the common workflow?
- Are names consistent with neighbouring components?
- Does UI text that may need translation live in slots with enough slot props?
- Does the API preserve accessibility needs: labels, descriptions, focus, and error messaging?
- For UI components, has [the accessibility checklist](../../accessibility/references/checklist.md) been run before handoff?
- Does the API expose generic identifiers/refs rather than hardcoding component-specific knowledge?
