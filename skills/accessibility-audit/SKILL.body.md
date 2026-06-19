# Accessibility audit

WCAG 2.2 AA baseline; AAA where feasible. Choose mode by context.

## Quick triage (PR / pre-release)

Fast check before release or PR merge. Not compliance audit.

### Automated scan first

Ask user to run one:

```bash
npx @axe-core/cli <url>
npx pa11y <url> --standard WCAG2AA
```

Or use Lighthouse: DevTools → Lighthouse → Accessibility.

### Manual checks

**Keyboard**

| Check                                      | Pass? |
| ------------------------------------------ | ----- |
| All interactive elements reachable via Tab |       |
| Focus indicator always visible             |       |
| No keyboard traps                          |       |
| Logical tab order                          |       |
| Skip link present and working              |       |

**Semantics & labels**

| Check                                                  | Pass? |
| ------------------------------------------------------ | ----- |
| Single descriptive `<h1>`; logical heading order       |       |
| Form inputs have visible labels or `aria-label`        |       |
| Buttons and links have clear names                     |       |
| Images have meaningful alt text (empty for decorative) |       |

**Visual contrast**

| Element                         | Minimum ratio |
| ------------------------------- | ------------- |
| Normal text                     | 4.5:1         |
| Large text (18pt+ / 14pt bold+) | 3:1           |
| UI components and focus rings   | 3:1           |

**Motion & dynamic updates**

| Check                                     | Pass? |
| ----------------------------------------- | ----- |
| Respects `prefers-reduced-motion`         |       |
| Dynamic updates announced via `aria-live` |       |

### Triage output

```markdown
## Accessibility triage: [Component / Page]

**Tool:** axe / pa11y / Lighthouse **Score:** \_

### Blockers (fix before merge)

- [issue] — [WCAG criterion] — [suggested fix]

### Warnings (fix soon)

- [issue] — [WCAG criterion]

### Passed

- [what was checked and passed]
```

---

## Full client audit

Systematic WCAG 2.2 AA audit with client-ready report.

### 1. Confirm scope

- Platforms in scope (web, iOS, Android)
- WCAG level (AA minimum; AAA where feasible)
- Target pages and key user journeys
- Assistive technologies to cover

### 2. Automated baseline

Ask user to run axe, pa11y, or Lighthouse across in-scope pages. Automated tools catch roughly 30–50%; manually verify rest.

### 3. Manual verification

Work through WCAG 2.2 AA. For the per-criterion checklist, see [references/wcag-checklist.md](references/wcag-checklist.md).

Priority areas:

- **Perceivable**: alt text, captions, colour contrast, reflow at 400% zoom
- **Operable**: keyboard access, focus management, no timing traps, skip links, motion control
- **Understandable**: error messages, form labels, consistent navigation, plain language
- **Robust**: valid HTML, ARIA used correctly, works with screen readers

Screen reader testing is manual and needs AT on real device. For VoiceOver, NVDA, and JAWS commands, see [references/screen-reader-testing.md](references/screen-reader-testing.md).

### 4. Map findings to severity

| Severity     | Definition                                    |
| ------------ | --------------------------------------------- |
| **Blocker**  | Prevents task completion for an affected user |
| **Serious**  | Significantly impairs task completion         |
| **Moderate** | Creates difficulty; workaround exists         |
| **Minor**    | Low impact; best practice                     |

### 5. Report format

```markdown
## Accessibility audit report: [Project / URL]

**Date:** [date] **Standard:** WCAG 2.2 AA **Auditor:** [name]

### Executive summary

[2–3 sentences: overall posture, critical issues count, recommendation]

### Findings

#### [Finding title] — [Severity]

- **Criterion:** [e.g. 1.4.3 Contrast (AA)]
- **Location:** [page / component]
- **Issue:** [what's wrong]
- **Impact:** [who is affected and how]
- **Recommendation:** [specific fix]
- **Evidence:** [screenshot, code snippet, or tool output]

### What passed

[List of criteria verified and passed]

### Remediation priorities

1. [Blocker] …
2. [Serious] …
```
