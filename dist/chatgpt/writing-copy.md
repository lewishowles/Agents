---
# Generated — edit skill.json and SKILL.body.md instead.
name: writing-copy
description: >
  Use this skill when writing UI microcopy — button labels, error messages, empty states, tooltips, CTAs, form helper text, confirmation dialogs. Covers being specific and action-oriented, surfacing useful context, and avoiding vague filler. Pair with the writing skill for voice baselines and the accessibility skill for screen-reader-friendly phrasing.
related-skills:
  - writing
---
# UI copy

Microcopy = short interface text guiding action. Bar: clear in one read.

## Buttons and CTAs

- Lead with verb — `Save changes`, not `OK`
- Be specific about what happens — `Delete account` beats `Confirm`
- Match surrounding form: `Sign in` form → `Sign in` button, not `Submit`
- Icon-only buttons still need an accessible name. Use a concise action label like `Close menu`, `Delete project`, or `Copy link`

## Error messages

- Say what went wrong AND what to do — `Password must be at least 8 characters`, not `Invalid password`
- Plain language; never expose stack traces or codes alone
- Don't blame user — `That email is already taken` not `You entered an invalid email`
- Inline errors should work with the field label: `Enter an email address`, not `Email error`

## Empty states

- Acknowledge empty and point to the next action — `No projects yet. Create one to get started.`
- Avoid placeholder text that looks like data — confuses screen readers and low-cognition users

## Confirmations

- Confirm with identifiable info — `User "Lewis Howles" deleted`, not `User deleted`
- Destructive actions: restate consequence — `Delete account? This removes 12 projects and can't be undone.`
- Prefer undo for reversible destructive actions. Use confirmation for hard-to-undo or high-impact actions

## Helper and supporting text

- Place near related input. Essential info → not hidden in tooltip
- Keep short; more than two sentences belongs in docs
