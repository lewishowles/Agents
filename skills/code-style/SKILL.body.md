# Code style

**Baseline for all code, all projects, all languages.** Language skills (`/vue`, `/swift`, `/typescript`) extend this.

## Formatting

- Tabs; double quotes; always semicolons
- No trailing spaces, no mixed tabs/spaces
- Comma-dangle always multiline; quote props consistent-as-needed
- No one-line `if` statements — full block with braces, body on new line
- Blank lines separate logical steps in functions
- Multi-line variable declarations should have a blank line before and after them
- Repeated inline logic? Extract named function with JSDoc/equivalent; don't duplicate
- Prefer line parsing, structured APIs, or small helpers over complex regex. Use regex only when clearest; name complex patterns and explain match.
- For multi-line generated strings, prefer named values and `["line one", value, "line three"].join("\n")` over dense escaped templates.
- Split dense template expressions into named intermediate values before interpolation.

## Naming & imports

- Never abbreviate event parameter names — `event` not `e`
- Prefer "user" over "consumer"
- Destructured keys and imports: alphabetical
- Name variables after what they represent, not how they look — `alertPrefix` not `capitalisedType`
- Fixed string sets: define a named constants object — `const alertTypes = { ERROR: "error", MUTED: "muted" }` — and reference it in switch/if/template expressions

## Reuse existing helpers

Before implementing any primitive operation — length, clamping, type/emptiness checks, string/array/object guards, deep copy/merge — search the project's own helper library and use what exists. Do not reimplement with raw `Array.isArray`, `array.length`, `Math.min`/`Math.max`, `typeof x === "string" && x.length`, manual `hasOwnProperty`, etc. when a named helper already covers it.

Existing helpers carry edge-case hardening and are the single source of truth for that behaviour — reimplementing inline drifts from it silently.

## Query selectors & predicates

- **Simplicity over repetition**: group similar elements with `:is()` and use single negations
  - ✗ Verbose: `:is(button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), a[href], [tabindex]:not([tabindex='-1']))`
  - ✓ Simple: `:is(button, input, select, textarea):not([disabled]), a[href], [tabindex]:not([tabindex='-1'])`
- **Common focusable selector**: `:is(button, input, select, textarea):not([disabled]), a[href], [tabindex]:not([tabindex='-1'])`
- **Readability**: for complex selectors, use named constant with JSDoc purpose

## Comments & documentation

- Every top-level variable: single-line comment describing purpose — all languages
- Functions: JSDoc or equivalent blocks. Parameters: `@param  {type}  name` format, description indented four spaces on next line
- Use TypeScript-style JSDoc types where they stay simple, e.g. `object[]` or `string[]` instead of `Array<object>` or `Array<string>`
- Add short purpose comment when intentional behaviour may look like bug/workaround/accident.
- No banner/divider comments (`// ---`) — use JSDoc or equivalent and blank lines for structure
- **In-code comments explain purpose, not mechanics** — say what value, prop, branch, or check is for. Explain internals only when needed.
- Avoid comments that repeat syntax, narrate control flow, or describe workaround mechanics. Prefer purpose comments.
- Avoid em dashes in code comments, JSDoc, inline docs, and generated code strings unless preserving quoted text or matching an external style requirement.
- Don't justify a fix by explaining the mechanism it avoids (reactivity loops, render timing, re-entrancy). State the rule the code follows, not the failure it prevents. Keep a "why" only as a guardrail against a likely future edit, for example "declared after initialise() so the initial seeding doesn't emit". Use one clause, no mechanism, and no punctuation addendum restating the consequence.
- Remove stale/transactional bug-fix comments once code expresses behaviour.
- Block comments for functions explain purpose and externally relevant constraints; avoid internal implementation trivia.
- Document the contract a caller relies on: return value, mutation behaviour, and observable edge cases. Omit internal mechanics (e.g. "after clamping", "a shallow clone is returned with identical content").
- Lead with one line, present tense, no boilerplate opening ("Creates a function that…"). Put option/edge-case behaviour in `@note`; keep `@example` short. Match the tone of surrounding functions in the same file.
- Comments use plain-language voice — see `/writing`. No unexplained jargon, no "etc"; write for newcomer. Purpose over cleverness.
