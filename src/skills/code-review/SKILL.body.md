# Code review

Reviews improve code collaboratively. Feedback is specific, actionable, grounded in code. Reviewers should understand what changed, why, and how it's maintained. If difficult, treat as maintainability issue.

## Giving a review

### Before reviewing

- Inspect changes summary-first: start with status, changed file names, and stats or numstat. Read a patch only for the selected file or hunk needed to assess a risk; do not print the entire diff by default.
- Understand intent: what problem does this solve?
- Check scope: one thing or several?
- Load relevant language/framework skills.
- **Risk-aware focus**: high git churn or high fan-in → scrutinise more. Defects cluster in churn-heavy files; high fan-in = wider blast radius.

### Severity levels

| Level          | Meaning                                                                          | Must fix?         |
| -------------- | -------------------------------------------------------------------------------- | ----------------- |
| **Blocker**    | Incorrect behaviour, security issue, or accessibility failure that affects users | Yes, before merge |
| **Important**  | Violates a convention or pattern; degrades maintainability                       | Yes, before merge |
| **Suggestion** | Better approach exists; worth discussing                                         | Author's call     |
| **Nit**        | Minor style or clarity issue                                                     | Optional          |

### Checklist by area

**Correctness**

- Does it do what it claims?
- Edge cases handled (empty, null, 0, large input)?
- Error states at boundaries (user input, API)?
- Race conditions, off-by-one, unbounded loops, leaks?

**Accessibility** (any UI change)

- Keyboard-reachable interactive elements?
- Labels, roles, ARIA correct?
- Colour contrast sufficient?
- No unsanitised `v-html`?

**Security** (input, auth, external data)

- User input validated/sanitised?
- Secrets server-side (not `VITE_`)?
- No open redirects from unvalidated params?
- Auth/authorisation checks match operation, not just route?
- No injection, path traversal, SSRF, unsafe deserialisation?

**Code style**

- Matches `code-style`: naming, comments, no speculative abstractions?
- Surgical: only needed changes?
- Organisation: each function/visitor owns one concern, no boolean flags swapping the algorithm, no switchboard helpers or logic duplicated across sibling files, clear control flow over clever tricks?

**Simplification** (this diff only)

- Has this change added unnecessary abstraction or machinery?
- Classify each flagged spot with exactly one tag: `[delete]` remove it; `[stdlib]` use the standard library; `[native]` use a platform feature; `[yagni]` avoid an unneeded addition; `[shrink-style]` use simpler code.
- For whole-repo debt, use `refactoring`'s **Technical debt triage** categories instead; these tags classify only the reviewed diff.
- For a fuller reuse/simplification/efficiency/altitude pass over a diff with dedicated review agents, use the built-in `/simplify` command instead of hand-rolling that pass here.

**Altitude**

- Is each change implemented at the right depth, or is it a fragile bandaid: a special case layered on shared infrastructure because the underlying mechanism wasn't generalised?
- Prefer generalising the shared mechanism over stacking another special case on top of it.

**Performance** (UI, list rendering, assets)

- Unnecessary re-renders or reactive side effects?
- Images sized and lazy-loaded?
- N+1 queries, missing indexes, unbounded queries, hot-path complexity?
- Long-lived objects built from closures or captured environments? They keep the entire enclosing scope alive for the object's lifetime, a memory leak when that scope holds large values. Prefer a class/struct that copies only the fields it needs.
- If claiming improvement, were before/after taken under same conditions (state, cache, throttling)? Warmed cache or narrow tests aren't real.

**Tests**

- Does the change include tests for new behaviour?
- Do existing tests still pass?

### Tailoring by PR type

- **Bug fix**: root-cause correctness, regression test, no scope creep
- **New feature**: a11y, error handling, tests, API surface
- **Refactor**: behaviour preservation (tests pass before/after each step)
- **Dependency upgrade**: breaking changes, security advisories, bundle impact

### Giving feedback

- Prefix with severity: `[blocker]`, `[important]`, `[suggestion]`, `[nit]`.
- State what, why, ideally alternative.
- Ask before flagging unclear things as issues.

---

## Quick-reference checklist

PR-pasteable checklist: [`references/checklist.md`](references/checklist.md). PR description template: [`references/pr-description-template.md`](references/pr-description-template.md).

## Receiving a review

Read all feedback before responding; items may depend on each other.

**For each item:**

1. Restate understood feedback or ask if unclear
2. Verify against code; don't implement from memory
3. Evaluate if correct for stack/context
4. Respond with action or reasoned pushback, not agreement

**Push back when** suggestion breaks behaviour, lacks context, violates YAGNI, or conflicts with architecture. Use technical reasoning.

**If wrong:** state factually and proceed. _"You're right — it does [X]. Fixing now."_

**Implement one at a time.** Verify it works before next.
