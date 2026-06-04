---
name: code-style
description: >
  Use this skill on every code change — even small snippets. Covers tabs vs spaces, quote style, semicolons, naming conventions, JSDoc comments, and documentation patterns. This is the baseline style guide for all code.
related-skills:
  - vue
  - vue-project-stack
  - swift
  - typescript
---

# Code style

**Baseline for all code, all projects, all languages.** Working in specific language/framework: also consult language skill: `/vue` for Vue, `/swift` for Swift, `/typescript` for TypeScript. Those extend code-style with language patterns; code-style = foundation.

## Formatting

- Tabs; double quotes; always semicolons
- No trailing spaces, no mixed tabs/spaces
- Comma-dangle always multiline; quote props consistent-as-needed
- No one-liner `if` statements — full block format with braces, body on new line
- Blank lines separate logical steps in functions
- Multi-line variable declarations should have a blank line before and after them
- Repeated inline logic? Extract into named functions with JSDoc or equivalent, don't duplicate

## Naming & imports

- Never abbreviate event parameter names — `event` not `e`
- Prefer "user" over "consumer"
- Destructured keys and imports: alphabetical
- Name variables after what they represent, not how they look — `alertPrefix` not `capitalisedType`
- Fixed string sets: define as a named constants object — `const alertTypes = { ERROR: "error", MUTED: "muted" }` — reference in switch/if and template expressions, not inline literals

## Query selectors & predicates

- **Simplicity over repetition**: Group similar elements with `:is()` and use single negations rather than repeating `:not()` for each type
  - ✗ Verbose: `:is(button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), a[href], [tabindex]:not([tabindex='-1']))`
  - ✓ Simple: `:is(button, input, select, textarea):not([disabled]), a[href], [tabindex]:not([tabindex='-1'])`
- **Common focusable selector**: `:is(button, input, select, textarea):not([disabled]), a[href], [tabindex]:not([tabindex='-1'])` — prefer this pattern when finding elements that can receive focus programmatically
- **Readability**: when a selector is complex, assign it to a named constant with a JSDoc comment explaining its purpose

## Comments & documentation

- Every top-level variable: single-line comment describing what it does — all languages
- Functions: JSDoc or equivalent blocks. Parameters: `@param  {type}  name` format, description indented four spaces on next line
- Use TypeScript-style JSDoc types where they stay simple, e.g. `object[]` or `string[]` instead of `Array<object>` or `Array<string>`
- Add a short purpose comment when future maintainers could reasonably mistake intentional behaviour for a bug, workaround, or accidental omission. Focus on why the code exists or why a surprising choice is deliberate.
- No banner/divider comments (`// ---`) — use JSDoc or equivalent and blank lines for structure
- **In-code comments should explain purpose, not implementation mechanics** — say what a value, prop, branch, or check is for. Do not explain framework internals, historical bugs, or how the code works unless that knowledge is required to safely modify it.
- Avoid comments that merely repeat syntax, narrate control flow, or describe a workaround's mechanics. Prefer `// Ensures the dialog has an accessible label.` over `// Wrapped in onMounted to avoid invoking slots outside render context.`
- Remove stale or transactional bug-fix comments once the code expresses the behaviour clearly.
- Block comments for functions explain purpose and externally relevant constraints; avoid internal implementation trivia.
- Comments use the same plain-language voice as prose — see `/writing`. No jargon without explanation, no "etc", write for a newcomer. Purpose over cleverness.
