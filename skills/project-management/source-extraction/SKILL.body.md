# Source extraction

Extracting a page for later analysis is not the same task as summarising it for a human. The failure this skill prevents: a "summary" pass quietly drops the caveats, config, and dependent links that a downstream analysis (like `project-learn-from-source`) actually needs, and by the time that's discovered the meaning is already gone.

## Scope

Use when asked to:

- prepare a page, article, or artefact for another agent (including a non-Claude tool such as ChatGPT) to extract before analysis
- reduce token cost of reading several sources before running `project-learn-from-source`
- turn a long external page into structured raw material without losing anything load-bearing

Do not use this skill to:

- write a summary meant for a human to read directly — that's lossy by design, which is the opposite goal here
- perform the actual adopt/adapt/reject analysis — that's `project-learn-from-source`
- review this repo's own files or commits — see `project-review-worktree` or `project-review-commits`

## Method

Extraction, not summarisation: preserve every claim, constraint, and example completely rather than compressing them. Do not ask for or expect verbatim/near-verbatim reproduction of the source's prose — models resist reproducing large stretches of source text even when told not to summarise, so treat that as unavailable rather than a target. Instead: quote a short exact phrase (in quotation marks) only where the precise wording itself matters (a named rule, a specific caveat), and restate everything else fully and precisely in your own words — nothing dropped, nothing compressed, just not word-for-word.

Every link that gets listed needs its actual destination URL, not just anchor text. If the destination can't be resolved (e.g. the extracting tool can't see raw hrefs), say so explicitly for that link rather than omitting the field — a link entry with no destination is dead weight for the "decide whether to fetch this" step later.

Output shape:

```markdown
## Source
<URL, title, author/org if present, date if present>

## Claims and statements
- Full, precise restatement of any concrete claim, recommendation, rule, or pattern, with enough surrounding context to stand alone. Quote a short exact phrase only where the wording itself is the point.

## Config, code, or examples
- Any code snippets, config, commands, or worked examples, reproduced exactly, with a one-line note of what each is for.

## Constraints and caveats
- Stated conditions, exceptions, prerequisites, versions, or "this only applies when..." qualifiers.

## Structure and priorities
- What the page emphasises (headings, repeated points, "most important" framing), stated plainly, not interpreted.

## Referenced links worth reviewing separately
- Incidental / further reading: <anchor text, destination URL (or "destination not resolvable"), one-line why>

## Linked artefacts the article depends on
- Links where the article is describing, demonstrating, or quoting from the linked repo/download/doc itself — the article doesn't fully make sense without it. <anchor text, destination URL (or "destination not resolvable"), one-line on what it is>

## Excluded
- Boilerplate skipped (nav, ads, cookie banners, unrelated sidebar content), so it's clear nothing substantive was silently dropped.
```

Do not shorten, generalise, or rank the claims. Completeness of meaning over concision or exact wording — this output feeds a separate analysis step, not a human reader.

## Handing this to another agent

If the extraction will run in a tool without repo or conversation context (e.g. pasted into ChatGPT):

1. Give it the method and output shape above as its instructions, then the URL.
2. It must not fetch or follow links itself — links are noted, not chased. Auto-recursion turns one URL into an unbounded, unpredictable amount of work.
3. Bring the raw output plus the source URL back here.

## Multiple sources

Do not paste many URLs' worth of extraction into one analysis pass — a synthesis step over a large combined corpus tends to surface only the two or three most salient ideas and quietly drop the rest, even when they're applicable. Instead:

- extract each source separately (one pass per URL)
- feed them into `project-learn-from-source` in small batches, or ask explicitly for a per-source breakdown before synthesis

## After extraction

If "linked artefacts the article depends on" has entries, decide whether to extract those too before treating the analysis as complete — the article alone may be an incomplete account of what it's describing. Once extraction is done, hand the result to `project-learn-from-source` for the actual adopt/adapt/reject/defer/investigate assessment.
