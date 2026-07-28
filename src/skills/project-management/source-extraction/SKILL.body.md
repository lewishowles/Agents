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

Extraction, not summarisation: preserve every claim, constraint, and example fully rather than compressing. Don't expect verbatim reproduction — models resist this — so restate everything fully and precisely in your own words. Quote exact phrases only where wording itself matters (named rules, specific caveats), nothing dropped or compressed.

Every link needs its actual destination URL, not just anchor text. If destination unresolvable, state that explicitly; a link with no destination is dead weight for the "fetch this?" step later.

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

## Acquire the source

Choose the acquisition path from the URL before reading the source:

- For `github.com`, `raw.githubusercontent.com`, or `gist.github.com` file or blob URLs that point to one file, fetch the raw file content directly: rewrite a `github.com/.../blob/...` URL to its `raw.githubusercontent.com` equivalent, rewrite a `gist.github.com` URL to its `gist.githubusercontent.com/.../raw/...` equivalent, or use `gh api -H "Accept: application/vnd.github.raw" repos/:owner/:repo/contents/:path` (plain `gh api` without that header returns base64-encoded JSON, not the file content). Do not render the HTML page.
- For a GitHub repository root or a URL that needs multi-file exploration, use `gh repo clone --depth 1` (or `git archive`) in a scratch directory. Read only the targeted files with normal Read or `rg` tools. Do not render GitHub pages.
- For every other URL, first check `command -v page-to-markdown`. When available, use `page-to-markdown` to convert the page to compact Markdown before reading it. When unavailable, use WebFetch, condense the result manually, and say in the report that `page-to-markdown` was unavailable.

## Handing this to another agent

If the extraction will run in a tool without repo or conversation context (e.g. pasted into ChatGPT):

1. Give it the method and output shape above as its instructions, then the URL.
2. It must not fetch or follow links itself — links are noted, not chased. Auto-recursion turns one URL into an unbounded, unpredictable amount of work.
3. Bring the raw output plus the source URL back here.

## Multiple sources

Don't paste many URLs into one analysis pass — synthesis over large corpus surfaces only top ideas and drops the rest. Instead:

- Extract each source separately
- Feed into `project-learn-from-source` in small batches, or ask for per-source breakdown before synthesis

## After extraction

If "linked artefacts the article depends on" has entries, decide whether to extract those too — the article alone may be incomplete. Once extraction is done, hand result to `project-learn-from-source` for adopt/adapt/reject/defer/investigate assessment.
