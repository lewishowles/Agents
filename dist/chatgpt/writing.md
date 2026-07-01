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

- **First person, personal** — use "I" and "we" naturally. Share observations when they add credibility
- **Empathetic, not prescriptive** — lead with understanding, not rules
- **Conversational** — write as you'd explain to a colleague, not a policy document
- **Honest** — acknowledge complexity ("There's quite a lot in here"), don't oversimplify
- **Inclusive** — use "we" for shared actions. Use real scenarios and people, not abstract users

## Structure

- **Why before rules** — explain problem or motivation before stating solution or guideline
- **Concrete before abstract** — ground concepts in real scenario before generalising
- **Short before long** — lead with point, then expand. Don't bury key idea
- **Analogies welcome** — use everyday comparisons for unfamiliar concepts
- **Don't command in prose** — frame steps rather than barking them. Step sequences can be direct when free of padding

## Examples & evidence

- Provide before/after examples where "better" is subjective
- Use statistics when they support the point — cite source
- Scenarios > rules — "imagine you're on a pricing page..." beats "always provide confirmation"
- Humanise examples — "Lewis Howles" not "User X"

## Language

- **UK spelling** — colour, behaviour, organise, grey, recognise
- **Sentence case titles** — not Title Case
- **Plain language** — if someone unfamiliar can't follow, simplify. No unexplained jargon
- **Plain verbs** — prefer everyday words. "Create" or "write" a file, not "emit"
- **Contractions** — use them in prose and reference
- **Italics** for emphasis; `backticks` for inline code, technical terms, UI strings
- **Em dash** — default connector for explanation/asides. No spaces: "the token is a role—it already holds the right shade"
- **Lists** — a lead-in sentence ending in a colon, then fragment items with no trailing full stops
- **Passive for system behaviour** — focus on thing acted on: "The URL is checked against the allowlist", not "We check the URL"
- **No preamble or summary** unless asked

## What to avoid

- Preachy or lecturing tone — state point once; don't repeat as moral
- Padding ("It's worth noting that...", "As mentioned above...")
- Prescriptive absolutes where context matters — use "generally", "ideally", "where possible"
- Capitalising every word in titles or headings
- Opening with summary of what you're about to say
- No "etc", "and so on", or trailing "…" lists. Name the items, or say what they share. If a list earns its place, write it in full; if it doesn't, cut it
- No shortcuts. Finish the thought; don't leave reader to close the gap
- Marketing or hype — don't tell reader how to feel. Describe what it does
- "Just" and "simply" as minimisers — they wave away difficulty. Drop them or say plainly how few steps there are

## Phrasing

Go-to wording for recurring moments. Starting points, not only options.

- **Caveats** — "Note that …", "Ensure that …", or state rule and effect: "The URL is checked against the allowlist, so it must be valid".
- **Optional** — form label: "(optional)" at end. Prose: "If you want to …", "If you'd like …", "Optionally, you may …".
- **Pointing elsewhere** — "For more on X, see Y", "For more information about …", "Learn more about …".
- **Recommending between options** — "X is recommended over Y, because …", "The benefit of X is …", or to a person: "I'd choose X because …".
- **Tradeoffs** — "One thing to keep in mind …", "Note that …", "If you do choose X, …".
- **Limitations** — measured and brief. No "Unfortunately", "due to certain technical limitations", or "working hard to address".
- **No presumptuous audience claims** — avoid "most people" and "you probably want". Don't characterise reader.
- **Concrete ranges over hype** — "from small changes to big re-designs", not "completely transform everything".
- **Friendly anthropomorphism** — tools can "know", "see", and "pick up".

## Technical documentation

Skill files, reference docs, and inline code docs use different style to longform prose:

- Plain-language voice applies everywhere, including code comments and commits. If newcomer can't follow, rewrite plainly.
- Lead with rule/pattern, then example. Establish _what_ before _how_.
- Prefer short code snippet over paragraph when both convey same thing.
- Use tables for comparisons and trade-offs; bullet lists for independent items that don't have a comparative relationship.
- Reference descriptions are terse, noun-led, present tense: "Any title to display with this table.", "The label to use for the search box."
- Only document parameters callers pass. Omit internal/implementation-only parameters even if technically accessible.
- No placeholder docs: avoid `{*}`, `any`, or "see types" when local contract can be stated.
- Describe what a thing is and where it sits, not framework mechanics. Drop "rendered"/"displayed" when placement already says it.
- Match sibling scope. Don't add how-to, override, or translation guidance to one entry when neighbours lack it.
- In reference docs and JSDoc, write instructions in the imperative: "Pass a getter function", not "You should pass a getter function". In prose, frame the step instead (see Structure).

## Product documentation

User-facing docs are narrative like longform, but speak for the product, not for you:

- **Neutral product voice, no first person.** Subject is "the library", "the component", "Tailwind" — never "I"/"we".
- **No scene-setting intro.** Don't open a page or section with a paragraph that summarises what follows. Start at the first heading or the first real instruction. Cut "A component can come into your project three ways" if three subsections already say so.
- **Say it once.** Drop benefit-restatements and editorialising. "Components are automatically imported only when used" stands alone.
- **Give instruction, not mechanism.** Reader needs what to do, not internals. Let code examples carry detail.
- **Describe system behaviour in passive, focused on thing acted on.** "Components are automatically imported only when used."
- **Anthropomorphise tools, address reader as "you".** Light usage guidance is fine; don't characterise reader.
- **Imperative steps are welcome here**, unlike longform. Keep them free of padding.
- **Code-block lead-ins must add information, not announce the code.** Keep where-to-use context; cut lines that only say a snippet follows.
- **Concrete contrast lands abstract ideas.** "Rather than asking for 'purple 800', components ask for 'the primary fill'."
- **Use the docs' own components and conventions, not raw HTML.** External links through the project's link component (e.g. `<link-tag external>`), package and technical names in `<code>`.
