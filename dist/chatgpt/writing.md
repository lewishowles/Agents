---
# Generated — edit skill.json and SKILL.body.md instead.
name: writing
description: >
  Use this skill when writing or editing prose — blog posts, documentation, longform content, marketing copy. Covers voice, tone, structure, examples, language conventions (UK spelling, sentence case, em-dashes), and what to avoid (preachy tone, padding, opening summaries). For README files specifically, see the writing-readme skill. For UI microcopy (buttons, error messages, empty states), see the writing-copy skill.
do-not-use-when:
  - Editing executable code, configuration, or generated output without prose changes
  - Writing UI labels, validation messages, tooltips, or other microcopy where writing-copy is narrower
  - Editing a README where writing-readme is sufficient
---
# Writing style

## Voice & tone

- **First person, personal** — use "I" and "we" naturally. Share relevant observations when they add credibility
- **Empathetic, not prescriptive** — lead with understanding, not rules
- **Conversational** — write as you'd explain to a colleague, not a policy document
- **Honest** — acknowledge complexity ("There's quite a lot in here") rather than oversimplifying
- **Inclusive** — use "we" for shared actions. Humanise subjects; use real scenarios and real people, not abstract users

## Structure

- **Why before rules** — explain problem or motivation before stating solution or guideline
- **Concrete before abstract** — ground concepts in real scenario before generalising
- **Short before long** — lead with point, then expand. Don't bury key idea in paragraph three
- **Analogies welcome** — use everyday comparisons to land unfamiliar concepts ("just like I'd expect a solicitor to handle the fundamentals of law")
- **Don't command in prose** — frame a step rather than barking it. Step-by-step sequences can be direct when free of padding

## Examples & evidence

- Provide before/after examples for anything where "better" is subjective
- Use statistics when they support the point — cite source
- Scenarios > rules — concrete "imagine you're on a pricing page..." beats "always provide confirmation"
- Humanise examples — "Lewis Howles" not "User X"

## Language

- **UK spelling** — colour, behaviour, organise, grey, recognise
- **Sentence case titles** — not Title Case
- **Plain language** — if someone unfamiliar can't follow, simplify. No unexplained jargon
- **Plain verbs** — prefer everyday words. "Create" or "write" a file, not "emit"
- **Contractions** — use them, in prose and reference alike. They read as friendlier
- **Italics** for emphasis; `backticks` for inline code, technical terms, UI strings
- **Em dash** — default connector for explanation or asides. No spaces: "the token is a role—it already holds the right shade"
- **Lists** — a lead-in sentence ending in a colon, then fragment items with no trailing full stops
- **Passive for system behaviour** — keep focus on the thing acted on: "The URL is checked against the allowlist", not "We check the URL"
- **No preamble or summary** unless asked

## What to avoid

- Preachy or lecturing tone — state point once; don't repeat as moral
- Padding ("It's worth noting that...", "As mentioned above...")
- Prescriptive absolutes where context matters — use "generally", "ideally", "where possible"
- Capitalising every word in titles or headings
- Opening with summary of what you're about to say
- No "etc", "and so on", or trailing "…" lists. Name the items, or say what they share. If a list earns its place, write it in full; if it doesn't, cut it
- No shortcuts. Finish the thought — don't gesture at an idea and leave the reader to close the gap
- Marketing or hype — don't tell the reader how to feel. Describe what it does and let it stand
- "Just" and "simply" as minimisers — they wave away difficulty the reader might be feeling. Drop them, or say plainly how few steps there are

## Phrasing

Go-to wording for recurring moments. Starting points, not the only options.

- **Caveats** — "Note that …", "Ensure that …", or state rule and effect: "The URL is checked against the allowlist, so it must be valid".
- **Optional** — in a form label, "(optional)" at the end. In prose: "If you want to …", "If you'd like …", "Optionally, you may …".
- **Pointing elsewhere** — "For more on X, see Y", "For more information about …", "Learn more about …".
- **Recommending between options** — "X is recommended over Y, because …", "The benefit of X is …", or first person to a person: "I'd choose X because …".
- **Tradeoffs** — "One thing to keep in mind …", "Note that …", "If you do choose X, …".
- **Limitations** — measured and brief. No "Unfortunately", "due to certain technical limitations", or "working hard to address".
- **No presumptuous audience claims** — avoid "most people" and "you probably want", and don't narrate defaults in prose. Don't characterise the reader.
- **Concrete ranges over hype** — "from small changes to big re-designs", not "completely transform everything".
- **Friendly anthropomorphism** — tools can "know", "see", and "pick up": "let Tailwind know about the library so it can pick up the classes".

## Technical documentation

Skill files, reference docs, and inline code documentation follow a different style to longform prose. When writing these:

- The plain-language voice applies everywhere, including code comments and commit messages. If a newcomer can't follow it, rewrite it plainly.
- Lead with the rule or pattern, then the example. Establish _what_ before showing _how_ — don't bury the rule after a long preamble.
- Prefer a short code snippet over a paragraph when both convey the same thing.
- Use tables for comparisons and trade-offs; bullet lists for independent items that don't have a comparative relationship.
- Reference descriptions (props, slots, options) are terse, noun-led, and present tense: "Any title to display with this table.", "The label to use for the search box."
- Describe what a thing is and where it sits, not framework mechanics. Drop "rendered" or "displayed" when placement already says it.
- Match sibling scope. Don't add how-to, override, or translation guidance to one entry when neighbours don't share it.
- In reference docs and JSDoc, write instructions in the imperative: "Pass a getter function", not "You should pass a getter function". In prose, frame the step instead (see Structure).

## Product documentation

User-facing documentation pages — a getting-started guide, a theming guide, a component's usage notes — are narrative like longform, but speak for the product, not for you. This is a third register, between personal longform and terse reference. When writing these:

- **Neutral product voice, no first person.** Subject is "the library", "the component", "Tailwind" — never "I" or "we". Reserve "I"/"we" for blog posts and longform.
- **No scene-setting intro.** Don't open a page or section with a paragraph that summarises what follows. Start at the first heading or the first real instruction. Cut "A component can come into your project three ways" if three subsections already say so.
- **Say it once.** Drop benefit-restatements and comparative editorialising. "Components are automatically imported only when used" stands on its own; don't append "the convenience of global registration with the leanness of named imports".
- **Give the instruction, not the mechanism.** The reader needs what to do, not internals. Let code examples carry detail.
- **Describe system behaviour in the passive, focused on the thing acted on.** "Components are automatically imported only when used", "Each stylesheet is published so you can start from a working copy" — not "you reference a component and your bundler drops the rest".
- **Anthropomorphise tools, address the reader as "you".** Light usage guidance is fine; don't otherwise characterise the reader.
- **Imperative steps are welcome here**, unlike longform. Keep them free of padding.
- **Code-block lead-ins must add information, not announce the code.** Keep where-to-use context; cut lines that only say a snippet follows.
- **Concrete contrast lands abstract ideas.** "Rather than asking for 'purple 800', components ask for 'the primary fill'."
- **Use the docs' own components and conventions, not raw HTML.** External links through the project's link component (e.g. `<link-tag external>`), package and technical names in `<code>`.
