# Accessibility checklist

Quick-reference for WCAG 2.2 AA. Paste into a PR description or use as a review gate. For implementation detail, see the accessibility skill.

## Visual

- [ ] Colour contrast ≥ 4.5:1 for body text, ≥ 3:1 for large text and UI components
- [ ] Colour is not the only means of conveying information (pair with icon or text)
- [ ] Layout works at 400% zoom without horizontal scrolling
- [ ] No content lost or overlapping below 320px wide

## Structure and semantics

- [ ] Heading hierarchy is logical — no skipped levels (h1 → h2 → h3)
- [ ] Landmark regions used: `<main>`, `<nav>`, `<aside>`, `<article>`
- [ ] Lists use `<ul>`, `<ol>`, or `<dl>` — no fake lists with divs or paragraphs
- [ ] Tables have `<caption>`, `<thead>`, and `<th scope="col|row">`
- [ ] `lang` attribute set on `<html>`

## Keyboard and focus

- [ ] Every interactive element is reachable and operable by keyboard alone
- [ ] Focus order matches visual/logical reading order
- [ ] Focus indicator is visible (no `outline: none` without a replacement)
- [ ] Modals trap focus on open; focus returns to trigger on close
- [ ] Skip link present: `<a href="#main">Skip to main content</a>`
- [ ] Widgets follow ARIA keyboard contract: Arrow keys navigate, Enter/Space activate, Escape closes

## Forms

- [ ] Every input has an associated `<label>` (not placeholder-only)
- [ ] Related inputs grouped with `<fieldset>` + `<legend>`
- [ ] Errors linked with `aria-errormessage` and `aria-invalid="true"`
- [ ] Help text linked with `aria-describedby`
- [ ] Form is not cleared on submission error

## Images and media

- [ ] Informative images have descriptive `alt` text
- [ ] Decorative images have `alt=""`
- [ ] Complex images (charts, diagrams) have a text alternative
- [ ] Video has captions; audio has a transcript
- [ ] No autoplay

## Dynamic content

- [ ] Status messages use `aria-live="polite"` (or `"assertive"` for urgent alerts)
- [ ] No auto-dismissing messages
- [ ] Icon-only buttons have an accessible name (`aria-label` or visually hidden text)

## Motion

- [ ] Animations respect `prefers-reduced-motion: reduce`
- [ ] No content flashes more than 3 times per second

## Touch and mobile

- [ ] Touch targets ≥ 44 × 44px (iOS) / 48 × 48dp (Android)
- [ ] Viewport meta does not disable zoom (`user-scalable=no` absent)
