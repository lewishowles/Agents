# Code style

**Baseline for all code, all projects, all languages.** Also consult language skills: `/vue`, `/swift`, `/typescript`. They extend this foundation.

## Formatting

- Tabs; double quotes; always semicolons
- No trailing spaces, no mixed tabs/spaces
- Comma-dangle always multiline; quote props consistent-as-needed
- No one-liner `if` statements — full block format with braces, body on new line
- Blank lines separate logical steps in functions
- Multi-line variable declarations should have a blank line before and after them
- Repeated inline logic? Extract into named functions with JSDoc or equivalent, don't duplicate
- Prefer line-based parsing, structured APIs, or small named helpers over complex regular expressions. Use regex only when it is the clearest small pattern; assign complex patterns to named constants and explain what they match.
- For multi-line generated strings, prefer small named values and `["line one", value, "line three"].join("\n")` over dense template literals with many escapes.
- Split dense template expressions into named intermediate values before interpolation.

## Naming & imports

- Never abbreviate event parameter names — `event` not `e`
- Prefer "user" over "consumer"
- Destructured keys and imports: alphabetical
- Name variables after what they represent, not how they look — `alertPrefix` not `capitalisedType`
- Fixed string sets: define a named constants object — `const alertTypes = { ERROR: "error", MUTED: "muted" }` — and reference it in switch/if/template expressions

## Query selectors & predicates

- **Simplicity over repetition**: group similar elements with `:is()` and use single negations
  - ✗ Verbose: `:is(button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), a[href], [tabindex]:not([tabindex='-1']))`
  - ✓ Simple: `:is(button, input, select, textarea):not([disabled]), a[href], [tabindex]:not([tabindex='-1'])`
- **Common focusable selector**: `:is(button, input, select, textarea):not([disabled]), a[href], [tabindex]:not([tabindex='-1'])`
- **Readability**: when a selector is complex, assign it to a named constant with a JSDoc comment explaining its purpose

## Comments & documentation

- Every top-level variable: single-line comment describing what it does — all languages
- Functions: JSDoc or equivalent blocks. Parameters: `@param  {type}  name` format, description indented four spaces on next line
- Use TypeScript-style JSDoc types where they stay simple, e.g. `object[]` or `string[]` instead of `Array<object>` or `Array<string>`
- Add a short purpose comment when maintainers could mistake intentional behaviour for a bug, workaround, or accident.
- No banner/divider comments (`// ---`) — use JSDoc or equivalent and blank lines for structure
- **In-code comments explain purpose, not mechanics** — say what a value, prop, branch, or check is for. Explain internals only when needed for safe changes.
- Avoid comments that merely repeat syntax, narrate control flow, or describe a workaround's mechanics. Prefer `// Ensures the dialog has an accessible label.` over `// Wrapped in onMounted to avoid invoking slots outside render context.`
- Remove stale or transactional bug-fix comments once the code expresses the behaviour clearly.
- Block comments for functions explain purpose and externally relevant constraints; avoid internal implementation trivia.
- Comments use the same plain-language voice as prose — see `/writing`. No jargon without explanation, no "etc", write for a newcomer. Purpose over cleverness.
