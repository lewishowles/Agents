# Writing style

## Voice & tone

- **First person, personal** — use "I" and "we" naturally. Share observations when they add credibility
- **Empathetic, not prescriptive** — lead with understanding, not rules
- **Conversational** — write as you'd explain to a colleague
- **Honest** — acknowledge complexity, don't oversimplify
- **Inclusive** — use "we" for shared actions; use real people, not abstract users

## Structure

- **Why before rules** — explain problem or motivation before stating solution or guideline
- **Concrete before abstract** — ground concepts in real scenario before generalising
- **Short before long** — lead with point, then expand. Don't bury key idea
- **Analogies welcome** — use everyday comparisons for unfamiliar concepts
- **Frame steps, not commands** — step sequences can be direct when free of padding
- **Obvious before nuance** — name plain truths first. Skipping to subtle points removes the foundation readers need. Verify it's unspoken, not uncomfortable

## Examples & evidence

- Provide before/after examples where "better" is subjective
- Use statistics when they support the point — cite source
- Scenarios > rules — "imagine you're on a pricing page..." beats "always provide confirmation"
- Humanise examples — "Lewis Howles" not "User X"

## Language

- **UK spelling** — colour, behaviour, organise, grey, recognise
- **Sentence case titles** — not Title Case
- **Plain language** — simplify if newcomers can't follow; no unexplained jargon
- **Plain verbs** — prefer "create" or "write", not "emit"
- **Contractions** — use in prose and reference
- **Italics** for emphasis; `backticks` for code, technical terms, UI strings
- **Em dashes** — avoid by default. Use comma, colon, semicolon, parentheses, or new sentence. Only when preserving quoted text or no other mark keeps meaning clear
- **Lists** — a lead-in sentence ending in a colon, then fragment items with no trailing full stops
- **Passive for system behaviour** — focus on thing acted on: "The URL is checked against the allowlist", not "We check the URL"
- **No preamble or summary** unless asked

## What to avoid

- Em dashes as routine separators
- Preachy or lecturing tone — state once
- Padding like "It's worth noting that..." or "As mentioned above..."
- Prescriptive absolutes — use "generally", "ideally", "where possible"
- Title Case in headings
- Opening summaries
- "Etc", "and so on", trailing "…" lists — name items or say what they share, then cut if not essential
- Incomplete thoughts or shortcuts
- Marketing or hype — describe what it does
- "Just" and "simply" — drop or state plainly how few steps

## AI prose tells

Use this as a final pass when prose sounds generated or over-shaped:

- **Announcement phrases** — cut lines that only introduce the point: "Here's what matters", "The key thing is", "This is not just..."
- **Formulaic contrast** — avoid mechanical "not X, but Y" pivots. State the useful claim directly
- **Vague significance** — replace "important", "significant", "crucial", or "meaningful" with the specific effect or risk
- **False agency** — avoid abstract nouns doing human work unless the product voice needs it. Name the actor when responsibility matters
- **Punch-line endings** — vary paragraph endings. Don't make every section finish with a quotable final sentence

## Phrasing

Go-to wording for recurring moments. Starting points, not only options.

- **Caveats** — "Note that…" or "Ensure that…", or rule + effect: "The URL is checked against the allowlist, so it must be valid"
- **Optional** — form label: "(optional)". Prose: "If you want to…", "Optionally…"
- **Pointing elsewhere** — "For more on X, see Y" or "Learn more about…"
- **Recommending options** — "X over Y, because…" or "I'd choose X because…"
- **Tradeoffs** — "Note that…" or "If you choose X…"
- **Limitations** — brief and measured; no "Unfortunately" or "working hard to address"
- **Avoid "most people" and "you probably want"** — don't characterise reader
- **Concrete over hype** — "small changes to big re-designs", not "completely transform everything"
- **Friendly anthropomorphism** — tools can "know", "see", "pick up"

## Technical documentation

Skill files, reference docs, and inline code docs differ from longform:

- Plain language everywhere, including comments and commits — rewrite if newcomer can't follow
- Lead with rule/pattern, then example. Establish _what_ before _how_
- Prefer short code snippet over paragraph when equivalent
- Tables for comparisons; bullets for independent items
- Reference descriptions: terse, noun-led, present tense: "Any title to display with this table"
- Document only caller-facing parameters
- No placeholder docs — avoid `{*}`, `any`, "see types" when contract can be stated
- Describe what a thing is and where it sits, not framework mechanics
- Match sibling scope and guidance
- Imperative instructions in reference/JSDoc: "Pass a getter function", not "You should pass"

## Product documentation

User-facing docs are narrative like longform, but speak for the product, never first person:

- **Neutral product voice** — subject is "the library", "the component", never "I"/"we"
- **No scene-setting intros** — start at the first heading or instruction. Cut summaries if subsections already detail them
- **Say it once** — drop benefit-restatements and editorialising
- **Instruction, not mechanism** — reader needs what to do, not internals
- **System behaviour in passive** — "Components are automatically imported only when used"
- **Anthropomorphise tools; address reader as "you"** — light guidance only, don't characterise
- **Imperative steps are fine** — keep free of padding
- **Code-block lead-ins add information, not announce** — keep context; cut lines that only say a snippet follows
- **Concrete contrast lands abstract ideas** — "Rather than asking for 'purple 800', ask for 'the primary fill'"
- **Use the docs' components and conventions** — external links via the project's link component, technical names in `<code>`

## Attribution

The "AI prose tells" checklist adapts ideas from Hardik Pandya's `stop-slop` skill, MIT licensed.
