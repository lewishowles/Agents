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

Before primitive operations (length, clamping, type checks, string/array/object guards, deep copy/merge): search project helper library. Don't reimplement with raw `Array.isArray`, `Math.min`, `typeof x === "string"`, etc. when helpers exist. Existing helpers carry edge-case hardening and are single source of truth.

## Query selectors & predicates

- **Simplicity over repetition**: group similar elements with `:is()` and use single negations
  - ✗ Verbose: `:is(button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), a[href], [tabindex]:not([tabindex='-1']))`
  - ✓ Simple: `:is(button, input, select, textarea):not([disabled]), a[href], [tabindex]:not([tabindex='-1'])`
- **Common focusable selector**: `:is(button, input, select, textarea):not([disabled]), a[href], [tabindex]:not([tabindex='-1'])`
- **Readability**: for complex selectors, use named constant with JSDoc purpose

## Comments & documentation

- Top-level variable: single-line purpose comment (all languages)
- Functions: JSDoc/equivalent blocks. Parameters: `@param  {type}  name` format, description indented next line
- Use simple TypeScript JSDoc types (e.g. `object[]` not `Array<object>`)
- Add short purpose comment when intentional behaviour may look like bug/workaround
- No banner/divider comments; use JSDoc and blank lines
- **In-code comments explain purpose, not mechanics** — what is this for, not how it works
- Avoid comments that repeat syntax, narrate flow, or describe workaround mechanics
- No em dashes in code comments, JSDoc, inline docs unless preserving quoted text
- Don't justify fixes by explaining mechanism avoided. State the rule code follows. "Why" only as guardrail (e.g. "declared after initialise() so seeding doesn't emit")
- Remove stale bug-fix comments once code expresses behaviour
- Block comments: purpose and external constraints; skip internal trivia
- Document caller contract: return value, mutation, observable edge cases. Omit internal mechanics
- Lead with one line, present tense, no boilerplate. Put options in `@note`; keep `@example` short. Match surrounding tone
- Plain-language voice; no unexplained jargon or "etc". Purpose over cleverness
- Avoid inflated phrasing like "positioning context" or "caller-provided X"; don't invent a term for a concept the codebase doesn't already name (e.g. "wide panel"): reuse existing naming or ask
