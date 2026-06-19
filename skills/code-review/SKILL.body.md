# Code review

Reviews improve code collaboratively. Feedback is specific, actionable, grounded in code.

## Giving a review

### Before reviewing

- Understand intent: what problem does this solve?
- Check scope: is the diff doing one thing, or several?
- Load relevant skills for language/framework

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
- Are edge cases (empty, null, 0, very large input) handled?
- Are error states handled at boundaries (user input, API responses)?

**Accessibility** — apply for any UI change

- Interactive elements reachable by keyboard?
- Labels, roles, and ARIA attributes correct?
- Colour contrast sufficient?
- No `v-html` without sanitisation?

**Security** — apply for any code touching input, auth, or external data

- Is user input validated or sanitised before use?
- Are secrets kept server-side (`VITE_` is not secret)?
- No open redirects from unvalidated params?

**Code style**

- Matches `code-style` conventions: naming, comments, no speculative abstractions?
- Surgical — only touches what's needed?

**Performance** — apply for UI, list rendering, or asset changes

- Any unnecessary re-renders or reactive side effects?
- Images sized and lazy-loaded appropriately?

**Tests**

- Does the change include tests for new behaviour?
- Do existing tests still pass?

### Tailoring by PR type

Adjust focus by PR type:

- **Bug fix** — root-cause correctness, regression test, no scope creep
- **New feature** — focus on a11y, error handling, tests, API surface
- **Refactor** — focus on behaviour preservation (tests pass before and after each step)
- **Dependency upgrade** — focus on breaking changes, security advisories, bundle impact

### Giving feedback

- Prefix with severity: `[blocker]`, `[important]`, `[suggestion]`, `[nit]`
- State what, why, and ideally alternative
- Ask questions for things you don't understand before flagging them as issues

---

## Quick-reference checklist

PR-pasteable checklist: [`references/checklist.md`](references/checklist.md).

## Receiving a review

Read all feedback before responding; related items may depend on each other.

**For each item:**

1. Restate understood feedback, or ask if unclear
2. Verify against code — don't implement from memory
3. Evaluate whether it is correct for stack/context
4. Respond with action or reasoned pushback, not performative agreement

**Push back when** suggestion would break behaviour, lacks context, violates YAGNI, or conflicts with architecture. Use technical reasoning.

**If you were wrong:** state it factually and proceed. _"You were right — I checked and it does [X]. Fixing now."_

**Implement one item at a time.** Verify it works before moving to the next.
