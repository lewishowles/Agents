---
# Generated — edit skill.json and SKILL.body.md instead.
name: code-style
description: >
  Use this skill on every code change — even small snippets. Covers formatting, naming, JSDoc, and reusing project helper libraries before implementing primitive operations. This is the baseline style guide for all code.
do-not-use-when:
  - Reading or reviewing a file without proposing code changes
  - Editing prose-only Markdown where the writing skill is sufficient
  - Working in generated output that should not be edited directly
---
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
- **Readability**: for complex selectors, use named constant with JSDoc purpose

## Organisation & abstraction

- A function or visitor owns one concern; split grouping, selection, transformation, and reporting into named steps rather than one dense block
- Avoid boolean parameters that switch the algorithm entirely; split into named functions instead of one function with divergent branches
- Avoid shared "switchboard" helpers that accumulate one option per caller; let each caller own its formatting/behaviour, or name distinct modes explicitly
- Prefer explicit, obviously-correct control flow over clever tricks (sentinel loops, index arithmetic) even when the clever version is correct
- Repeated structural logic across sibling files, not just repeated lines, is a duplication smell — extract a named shared helper

## Comments & documentation

- Variable declaration (`const`/`let`, any scope): single-line purpose comment (all languages)
- Functions: JSDoc/equivalent blocks. Parameters: `@param  {type}  name` format, description indented next line
- Use simple TypeScript JSDoc types (e.g. `object[]` not `Array<object>`)
- Add short purpose comment when intentional behaviour may look like bug/workaround
- No banner/divider comments; use JSDoc and blank lines
- Comments explain purpose, not mechanics; remove stale bug-fix comments once code expresses behaviour
- For fixes, state the rule the code follows, not the avoided mechanism. Use "why" only as a guardrail (e.g. declared after `initialise()` so seeding does not emit)
- Block comments: purpose and external constraints; skip internal trivia
- Document caller contract: return value, mutation, observable edge cases. Omit internal mechanics
- Lead with one line, present tense, no boilerplate. Put options in `@note`; keep `@example` short. Match surrounding tone
- Plain-language voice; no unexplained jargon or "etc". Purpose over cleverness
- Avoid inflated phrasing like "positioning context" or "caller-provided X"; don't invent a term for a concept the codebase doesn't already name (e.g. "wide panel"): reuse existing naming or ask
