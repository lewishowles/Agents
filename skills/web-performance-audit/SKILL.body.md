# Web performance audit

Standalone performance review of a page, PR, or app — distinct from building performantly (use the `web-performance` skill for implementation guidance). Two modes: quick triage or full audit.

## Scope reality

There is no single command that audits "the whole codebase" for performance. Two different kinds of check exist, and they don't combine into one:

- **Static checks** — anti-patterns visible in source (missing image dimensions, no lazy-loading, missing `font-display`, synchronous route imports). These are fast, deterministic, and genuinely whole-repo: a handful of `rg` searches cover the entire codebase in seconds.
- **Live checks** — Core Web Vitals (LCP, CLS, INP) only exist for a rendered page under real network/CPU conditions. Lighthouse audits one URL at a time against a running build. Auditing "the whole app" means picking the key pages or routes to run it against, the same way an accessibility audit picks target pages rather than claiming to cover everything at once.

Confirm which pages matter before running live checks — home, highest-traffic routes, and anything the user flags — rather than guessing at full coverage.

## Quick triage (PR / single page)

### 1. Static scan

Run against the touched files or the whole repo:

```bash
# Images missing explicit width/height (CLS risk)
rg -n '<img(?![^>]*\bwidth=)[^>]*>' --pcre2 -g '*.vue' -g '*.html'

# Below-fold images without lazy-loading
rg -n '<img(?![^>]*\bloading=)[^>]*>' --pcre2 -g '*.vue' -g '*.html'

# @font-face without font-display
rg -n -B2 '@font-face' -g '*.css' -g '*.scss' | rg -L 'font-display'

# Route components not lazy-loaded
rg -n 'component:\s*\(\)\s*=>\s*import' -g 'router*' -g 'routes*'
```

A hit isn't automatically wrong (a hero LCP image legitimately skips `loading="lazy"`) — check each against the `web-performance` skill's guidance before flagging it.

### 2. Live check

Ask the user to run Lighthouse against the affected page (production build, not dev — dev numbers are unreliable):

```bash
npx lighthouse <url> --view
```

Or DevTools → Lighthouse → run in Incognito.

If this triage happens before planned fix work rather than after it, record the date, tool, and build/cache conditions alongside the score — this is the "before" baseline the fair-comparison check below will need once the fix lands.

### 3. Fair-comparison check

If the PR claims a measured improvement, confirm before/after numbers used the same page state, cache state, and throttling profile. A faster number from a warmed cache or a narrower test isn't a real improvement (see `code-review` skill).

### Triage output

```markdown
## Performance triage: [Page / PR]

**Tool:** Lighthouse **Scores:** LCP _ / CLS _ / INP \_

### Blockers (fix before merge)

- [issue] — [metric affected] — [suggested fix]

### Warnings (fix soon)

- [issue] — [metric affected]

### Passed

- [what was checked and passed]
```

## Full audit

Systematic pass across an app's key pages, with a report suitable for a client or stakeholder.

### 1. Confirm scope

- Target pages or routes (home, highest-traffic, anything the user flags) — not "everything"
- Whether a production build is available to test against, or one needs building first
- Whether historical CrUX field data exists (PageSpeed Insights) alongside lab data

### 2. Static baseline

Run the quick-triage static scan across the whole repo, not just touched files.

### 3. Live measurement per page

For each target page, run Lighthouse (or `lhci autorun` if CI is set up — see [references/measurement.md](../web-performance/references/measurement.md)) and record LCP, CLS, and INP against the targets in the `web-performance` skill.

If this audit precedes planned fix work, this measurement is the baseline: record the date, tool, and build/cache conditions alongside each score, not just the number. A later "after" comparison is only defensible if it can match this method (see the fair-comparison check in `code-review`).

### 4. Bundle check

Run the bundle visualiser (`rollup-plugin-visualizer`) and note any unexpectedly large chunks or missing code-splitting at route boundaries.

### 5. Map findings to severity

| Severity     | Definition                                           |
| ------------ | ---------------------------------------------------- |
| **Blocker**  | Fails a Core Web Vital target on a key page          |
| **Serious**  | Close to the target but degrading on real conditions |
| **Moderate** | Best-practice gap with measurable but modest impact  |
| **Minor**    | Cosmetic or negligible impact                        |

### 6. Report format

```markdown
## Performance audit report: [Project / URL]

**Date:** [date] **Auditor:** [name]

### Executive summary

[2-3 sentences: overall posture, critical issues count, recommendation]

### Pages audited

[List of pages/routes and why they were chosen]

### Findings

#### [Finding title] — [Severity]

- **Metric:** [e.g. LCP]
- **Location:** [page / component]
- **Issue:** [what's wrong]
- **Impact:** [measured effect — score, timing, or user-facing symptom]
- **Recommendation:** [specific fix, linking to `web-performance` skill guidance]
- **Evidence:** [Lighthouse score, trace, or bundle report]

### What passed

[List of checks verified and passed]
```

## Related skills

- [web-performance](../web-performance/SKILL.body.md) — implementation guidance for fixing anything this audit finds
- [code-review](../code-review/SKILL.body.md) — the fair-comparison check for any PR claiming a measured improvement
- [accessibility-audit](../accessibility-audit/SKILL.body.md) — same two-mode audit shape, for accessibility instead of performance
