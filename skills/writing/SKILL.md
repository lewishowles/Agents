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
- **Don't command in prose** — frame a step rather than barking it: "The first step is to import the library", not "Import the library". A genuine step-by-step sequence can be direct, as long as there's no padding around it

## Examples & evidence

- Provide before/after examples for anything where "better" is subjective
- Use statistics when they exist and support the point — cite source
- Scenarios > rules — concrete "imagine you're on a pricing page..." beats "always provide confirmation"
- Humanise examples — "Lewis Howles" not "User X"

## Language

- **UK spelling** — colour, behaviour, organise, grey, recognise
- **Sentence case titles** — not Title Case
- **Plain language** — if someone unfamiliar can't follow, simplify. No jargon without explanation
- **Plain verbs** — prefer everyday words over machine or jargon verbs. "Create" or "write" a file, not "emit". If a word sounds like it belongs in a compiler manual, choose a simpler one
- **Contractions** — use them, in prose and reference alike. They read as friendlier
- **Italics** for emphasis; `backticks` for inline code, technical terms, UI strings
- **Em dash** — your default connector for a statement and its explanation, and for asides. No spaces around it: "the token is a role—it already holds the right shade". Use a full stop only when the two parts stand fully apart
- **Lists** — a lead-in sentence ending in a colon, then fragment items with no trailing full stops
- **Passive for system behaviour** — when describing what the library does to the reader's input, keep the focus on the thing acted on: "The URL is checked against the allowlist", not "We check the URL"
- **No preamble or summary** unless asked

## What to avoid

- Preachy or lecturing tone — state point once; don't repeat as moral
- Padding ("It's worth noting that...", "As mentioned above...")
- Prescriptive absolutes where context matters — "generally", "ideally", "where possible" are honest
- Capitalising every word in titles or headings
- Opening with summary of what you're about to say
- No "etc", "and so on", or trailing "…" lists. Name the items, or say what they share. If a list earns its place, write it in full; if it doesn't, cut it
- No shortcuts. Finish the thought — don't gesture at an idea and leave the reader to close the gap
- Marketing or hype — telling the reader how to feel ("this is the great part", "powerful", "blazing fast"), or cheerleading with exclamation marks ("this is all you need to do!"). Describe what it does and let it stand
- "Just" and "simply" as minimisers — they wave away difficulty the reader might be feeling. Drop them, or say plainly how few steps there are

## Phrasing

Go-to wording for recurring moments. Starting points, not the only options.

- **Caveats** — "Note that …", "Ensure that …", or state the rule and its effect: "The URL is checked against the allowlist, so it must be valid". "Note that" is a caveat marker, not padding, unlike "It's worth noting that".
- **Optional** — in a form label, "(optional)" at the end. In prose: "If you want to …", "If you'd like …", "Optionally, you may …".
- **Pointing elsewhere** — "For more on X, see Y", "For more information about …", "Learn more about …".
- **Recommending between options** — "X is recommended over Y, because …", "The benefit of X is …", or first person to a person: "I'd choose X because …".
- **Tradeoffs** — "One thing to keep in mind …", "Note that …", "If you do choose X, …".
- **Limitations** — measured and brief: "At this time, we're not able to …, but it's something we'll look to include later". No "Unfortunately", no "due to certain technical limitations", no "working hard to address".
- **No presumptuous audience claims** — avoid "most people" and "you probably want", and don't narrate defaults in prose. Don't characterise the reader.
- **Concrete ranges over hype** — "from small changes to big re-designs", not "completely transform everything".
- **Friendly anthropomorphism** — tools can "know", "see", and "pick up": "let Tailwind know about the library so it can pick up the classes".

## Technical documentation

Skill files, reference docs, and inline code documentation follow a different style to longform prose. When writing these:

- The plain-language voice above applies to every piece of writing you produce — code comments and commit messages included, not just longform. A comment a newcomer can't follow is too clever; rewrite it plainly.
- Lead with the rule or pattern, then the example. Establish _what_ before showing _how_ — don't bury the rule after a long preamble.
- Prefer a short code snippet over a paragraph of prose when both would convey the same thing. A three-line example beats a sentence of abstract description.
- Use tables for comparisons and trade-offs; bullet lists for independent items that don't have a comparative relationship.
- Reference descriptions (props, slots, options) are terse, noun-led, and present tense: "Any title to display with this table.", "The label to use for the search box."
- Describe what a thing is and where it sits, not the framework mechanics of how it gets there. Drop "rendered", "displayed", and the like when a placement word already carries it: "an instruction inside each column's heading button", not "an instruction rendered inside each column's heading button".
- Match the scope of sibling entries. Don't volunteer how-to, override, or translation guidance in one entry when the rest of the reference doesn't — a lone aside that no neighbour shares reads as out of place. If such guidance belongs, it belongs everywhere it applies, not in one description.
- In reference docs and JSDoc, write instructions in the imperative: "Pass a getter function", not "You should pass a getter function". In prose, frame the step instead (see Structure).
