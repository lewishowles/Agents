---
# Generated — edit skill.json and SKILL.body.md instead.
name: code-review
description: >
  Use this skill when reviewing code — a PR, a diff, or an individual file — or when receiving review feedback. Applies your conventions (accessibility, code-style, error-handling, frontend-security, web-performance) as a checklist, and covers how to give and receive feedback.
do-not-use-when:
  - Writing new code (apply the relevant stack skills instead)
  - A general question about code quality with no specific diff to review
related-skills:
  - code-style
  - accessibility
  - error-handling
  - frontend-security
  - web-performance
---
# Code review

Reviews are collaborative improvement, not gatekeeping. Feedback should be specific, actionable, and grounded in the code — not vague or judgemental.

## Giving a review

### Before reviewing

- Understand the intent: what problem does this change solve?
- Check the scope: is the diff doing one thing, or several?
- Load the relevant skills for the language/framework in view

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
- Are error states handled at system boundaries (user input, API responses)?

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

- Matches the `code-style` conventions (naming, comments, no speculative abstractions)?
- Surgical — only touches what's needed?

**Performance** — apply for UI, list rendering, or asset changes

- Any unnecessary re-renders or reactive side effects?
- Images sized and lazy-loaded appropriately?

**Tests**

- Does the change include tests for new behaviour?
- Do existing tests still pass?

### Tailoring by PR type

Adjust focus by what the PR is doing:

- **Bug fix** — focus on root-cause correctness, regression test, no scope creep
- **New feature** — focus on a11y, error handling, test coverage, and API surface
- **Refactor** — focus on behaviour preservation (tests pass before and after each step)
- **Dependency upgrade** — focus on breaking changes, security advisories, bundle impact

### Giving feedback

- Prefix with severity: `[blocker]`, `[important]`, `[suggestion]`, `[nit]`
- State what, why, and ideally what the alternative is
- Ask questions for things you don't understand before flagging them as issues

---

## Receiving a review

Read all feedback before responding to any of it — related items may depend on each other.

**For each item:**

1. Restate what you understand the feedback to mean (or ask for clarification if it's unclear)
2. Verify against the actual code — don't implement from memory
3. Evaluate whether it's technically correct for your stack and context
4. Respond with action or reasoned pushback — not performative agreement

**Push back when** a suggestion would break existing behaviour, lacks full context, violates YAGNI, or conflicts with an established architectural decision. Use technical reasoning, not defensiveness.

**If you were wrong:** state it factually and proceed. _"You were right — I checked and it does [X]. Fixing now."_

**Implement one item at a time.** Verify it works before moving to the next.
