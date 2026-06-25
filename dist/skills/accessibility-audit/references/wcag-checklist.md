# WCAG 2.2 AA checklist

Use this during a full client audit. Automated tools catch ~30–50%; the rest need manual verification.

---

## Perceivable

### 1.1 Text alternatives

- [ ] All meaningful images have descriptive alt text
- [ ] Decorative images have `alt=""`
- [ ] Complex images (charts, diagrams) have long descriptions or data tables
- [ ] Icon-only buttons have accessible names

### 1.2 Time-based media

- [ ] Audio-only content has a text transcript
- [ ] Video has synchronised captions (accurate, complete, with speaker IDs)
- [ ] Video has audio description for visual-only content

### 1.3 Adaptable

- [ ] Heading hierarchy is logical (h1 → h2 → h3, no jumps)
- [ ] Lists use `<ul>`, `<ol>`, `<dl>` — not fake lists with paragraphs/divs
- [ ] Tables have `<th scope="col/row">` and a `<caption>`
- [ ] Form inputs have associated `<label>` elements (not placeholder-only)
- [ ] Landmark regions present (`<main>`, `<nav>`, `<aside>`, `<header>`)
- [ ] Reading order in DOM matches visual order
- [ ] Instructions don't rely on shape, colour, or position alone

### 1.4 Distinguishable

- [ ] Text contrast ≥ 4.5:1 (normal) / 3:1 (large text, 18pt+ or 14pt bold+)
- [ ] UI component contrast ≥ 3:1 (inputs, buttons, focus rings)
- [ ] Colour is not the only way to convey information
- [ ] Text resizes to 200% without content loss or horizontal scroll
- [ ] Content reflows at 400% zoom / 320px viewport width (no two-dimensional scrolling)
- [ ] No background audio, or user can pause/stop it

---

## Operable

### 2.1 Keyboard accessible

- [ ] Every interactive element is reachable and operable via keyboard
- [ ] No keyboard traps (Tab always moves forward, Shift+Tab always moves back)
- [ ] Keyboard shortcuts don't conflict with AT shortcuts; can be remapped or disabled

### 2.2 Enough time

- [ ] No auto-dismissing messages (or user can pause/extend/disable timing)
- [ ] No moving/blinking content that can't be paused after 5 seconds

### 2.3 Seizures & physical reactions

- [ ] Nothing flashes more than 3 times per second
- [ ] `prefers-reduced-motion` respected — animations/carousels/parallax disabled or reduced

### 2.4 Navigable

- [ ] Skip link present and functional (`<a href="#main">Skip to main content</a>`)
- [ ] Each page has a descriptive `<title>`
- [ ] Focus indicator visible at all times (no `outline: none` without replacement)
- [ ] Focus order is logical — tab sequence matches visual/reading order
- [ ] Focus after errors: moves to error summary or first invalid field
- [ ] Focus in modals: trapped inside while open, restored to trigger on close
- [ ] Heading structure allows users to understand and navigate the page
- [ ] Link text is descriptive in context (not "click here" or "learn more")

### 2.5 Input modalities

- [ ] Touch targets ≥ 44×44px (iOS) / 48×48dp (Android); adequate spacing between targets
- [ ] No drag-only interactions — a button alternative exists
- [ ] Form fields don't block paste

---

## Understandable

### 3.1 Readable

- [ ] `<html lang="en">` set; inline `lang` attributes on blocks in other languages

### 3.2 Predictable

- [ ] Navigation is consistent across pages
- [ ] Components with the same function have consistent labels
- [ ] No unexpected context changes on focus or input (no auto-submit on select)

### 3.3 Input assistance

- [ ] Error messages identify the field and describe the issue
- [ ] `aria-invalid="true"` and `aria-errormessage` on invalid inputs
- [ ] Error summary at top of form, linked to each invalid field
- [ ] Required fields indicated (not colour-only)
- [ ] `autocomplete` attributes set for personal data fields
- [ ] Form is not cleared on error — user can fix and resubmit
- [ ] Destructive actions require confirmation or can be undone

---

## Robust

### 4.1 Compatible

- [ ] HTML is valid (no duplicate IDs, no unclosed elements)
- [ ] ARIA roles, states, and properties are used correctly
- [ ] Interactive widgets follow ARIA Authoring Practices (keyboard contract: Arrow keys navigate, Enter/Space activate, Escape closes)
- [ ] Dialogs: `role="dialog"` + `aria-modal="true"` + `aria-labelledby` pointing at heading
- [ ] Status messages use `aria-live` regions so screen readers announce without focus change
- [ ] Custom components tested with at least VoiceOver + Safari (macOS) and NVDA + Firefox (Windows)
