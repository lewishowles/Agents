---
# Generated — edit skill.json and SKILL.body.md instead.
name: code-style
description: >
  Use this skill on every code change — even small snippets. Covers language-aware formatting, naming, documentation, organisation, and reuse. This is the baseline style guide for all code.
do-not-use-when:
  - Reading or reviewing a file without proposing code changes
  - Editing prose-only Markdown where the writing skill is sufficient
  - Working in generated output that should not be edited directly
---
# Code style

**Baseline for all code, all projects, all languages.** Language skills (`/vue`, `/swift`, `/typescript`) extend this.

## Formatting

- Follow the project formatter and language syntax. Do not carry indentation, quote, semicolon, or comma rules between languages.
- JavaScript, TypeScript, and Vue: tabs; double quotes; semicolons; multi-line trailing commas; consistent property quotes.
- No trailing spaces or mixed indentation
- No one-line `if` statements — full block with braces, body on new line
- Blank lines separate distinct logical steps inside functions and loops. Treat initialisation, guards, parsing, validation, transformation, and return/output as separate steps when each has its own purpose.
- Add a blank line after a completed control-flow block before the next logical step. Keep connected clauses (`if`/`elif`/`else`, `try`/`except`/`finally`) together.
- Keep tightly coupled statements together. Don't add blank lines mechanically between every statement.
- Multi-line variable declarations should have a blank line before and after them
- Treat repetition as a design prompt, not automatic abstraction. Extract only a coherent behaviour that reduces risk and clarifies callers.
- Prefer line parsing, structured APIs, or small helpers over complex regex. Use regex only when clearest; name complex patterns and explain match.
- For multi-line generated strings, prefer named values and `["line one", value, "line three"].join("\n")` over dense escaped templates.
- Split dense template expressions into named intermediate values before interpolation.

For example, separate a Python loop's guard, parsing, validation, and collection steps:

```python
records = []

for line in contents.splitlines():
	if not line or len(line) > MAX_RECORD_BYTES:
		malformed_count += int(bool(line))
		continue

	try:
		record = json.loads(line)
	except (TypeError, ValueError):
		malformed_count += 1
		continue

	if not isinstance(record, dict):
		malformed_count += 1
		continue

	records.append(record)
```

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

- Give each module one responsibility. Split mixed concerns, not files merely because they are long; name each new module's job first.
- A function or visitor owns one concern; split grouping, selection, transformation, and reporting into named steps rather than one dense block
- Avoid boolean parameters that switch the algorithm entirely; split into named functions instead of one function with divergent branches
- Avoid shared "switchboard" helpers that accumulate one option per caller; let each caller own its formatting/behaviour, or name distinct modes explicitly
- Prefer explicit, obviously-correct control flow over clever tricks (sentinel loops, index arithmetic) even when the clever version is correct
- For repeated structural logic, compare explicit code, existing code, a helper, and a shared abstraction. Add one only when the behaviour and callers become clearer.

## Comments & documentation

- Every variable declaration has a short purpose comment. Every function has JSDoc, a docstring, or the language's equivalent.
- Documentation explains the declaration's role, purpose, caller contract, external constraint, or surprising behaviour. Never merely restate its name, signature, types, or mechanics.
- In JSDoc, use `@param  {type}  name` and indent the description on the next line.
- Use simple TypeScript JSDoc types (e.g. `object[]` not `Array<object>`)
- Add short purpose comment when intentional behaviour may look like bug/workaround
- No banner/divider comments; use JSDoc and blank lines
- Comments explain purpose, not mechanics; remove stale bug-fix comments once code expresses behaviour
- Check each docstring's claim against the function body it describes. Restating the name, or asserting behaviour the code doesn't have, both fail the same as no docstring
- For fixes, state the rule the code follows, not the avoided mechanism. Use "why" only as a guardrail (e.g. declared after `initialise()` so seeding does not emit)
- Block comments: purpose and external constraints; skip internal trivia
- Document caller contract: return value, mutation, observable edge cases. Omit internal mechanics
- Lead with one line, present tense, no boilerplate. Put options in `@note`; keep `@example` short. Match surrounding tone
- Plain-language voice; no unexplained jargon or "etc". Purpose over cleverness
- Avoid inflated phrasing like "positioning context" or "caller-provided X"; don't invent a term for a concept the codebase doesn't already name (e.g. "wide panel"): reuse existing naming or ask
- Prefer the codebase's concrete verb or noun over abstract process terms such as "classification" or "invocation" when a plain description of the behaviour is available
- This also covers swapping an existing name for a more formal-sounding synonym, not just novel terms: if the code calls `useStorage`, describe it as storing/stored, not "persist"/"persistence"/"reactive". Match the API's own verb.
