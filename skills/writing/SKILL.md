---
name: writing
description: >
  Use this skill when writing or editing prose — blog posts, documentation, longform content, marketing copy. Covers voice, tone, structure, examples, language conventions (UK spelling, sentence case, em-dashes), and what to avoid (preachy tone, padding, opening summaries). For README files specifically, see the readme skill. For UI microcopy (buttons, error messages, empty states), see the ui-copy skill.
---

# Writing style

## Voice & tone

- **First person, personal** — use "I" and "we" naturally. Share relevant personal observations when adds credibility ("This was an interesting one when it dawned on me")
- **Empathetic, not prescriptive** — lead with understanding, not rules. "We should try to think about..." not "You must always..."
- **Conversational** — write as you'd explain to colleague, not policy document
- **Honest** — acknowledge complexity ("There's quite a lot in here") rather than oversimplifying
- **Inclusive** — use "we" for shared actions. Humanise subjects; use real scenarios and real people, not abstract users

## Structure

- **Why before rules** — explain problem or motivation before stating solution or guideline
- **Concrete before abstract** — ground concepts in real scenario before generalising
- **Short before long** — lead with point, then expand. Don't bury key idea in paragraph three
- **Analogies welcome** — use everyday comparisons to land unfamiliar concepts ("just like I'd expect a solicitor to handle the fundamentals of law")

## Examples & evidence

- Provide before/after examples for anything where "better" is subjective
- Use statistics when they exist and support the point — cite source
- Scenarios > rules — concrete "imagine you're on a pricing page..." beats "always provide confirmation"
- Humanise examples — "Lewis Howles" not "User X"

## Language

- **UK spelling** — colour, behaviour, organise, grey, recognise, etc.
- **Sentence case titles** — not Title Case
- **Plain language** — if someone unfamiliar can't follow, simplify. No jargon without explanation
- **Contractions** — fine; keep tone natural
- **Italics** for emphasis; `backticks` for inline code, technical terms, UI strings
- **Em dash** for parenthetical asides — no spaces around it
- **No preamble or summary** unless asked

## What to avoid

- Preachy or lecturing tone — state point once; don't repeat as moral
- Padding ("It's worth noting that...", "As mentioned above...")
- Prescriptive absolutes where context matters — "generally", "ideally", "where possible" are honest
- Capitalising every word in titles or headings
- Opening with summary of what you're about to say

## Technical documentation

Skill files, reference docs, and inline code documentation follow a different style to longform prose. When writing these:

- Lead with the rule or pattern, then the example. Establish *what* before showing *how* — don't bury the rule after a long preamble.
- Prefer a short code snippet over a paragraph of prose when both would convey the same thing. A three-line example beats a sentence of abstract description.
- Use tables for comparisons and trade-offs; bullet lists for independent items that don't have a comparative relationship.
- Write instructions in the imperative: "Pass a getter function" not "You should pass a getter function".
- Em-dash discipline: before writing one, identify the actual relationship between the clauses. Definition or explanation → colon. Separate statement → full stop. Continuation or aside → comma. Genuine interruption or parenthetical contrast → em-dash is appropriate. Most em-dashes in technical writing are a lazy colon or full stop in disguise.