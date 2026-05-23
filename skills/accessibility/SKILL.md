---
name: accessibility
description: >
  Use this skill when writing or reviewing any HTML, UI components, or interface copy — even if accessibility isn't mentioned. Covers WCAG 2.2 AA baseline (AAA where feasible): colour contrast, keyboard access, screen readers, semantic HTML, focus management, forms & validation, live regions, touch targets (iOS 44×44, Android 48×48), dynamic content, and inclusive design. Apply proactively: accessible design is correct design.
related-skills:
  - code-style
  - vue
  - swift-ui
---

# Accessibility

WCAG AA baseline; AAA where feasible. Inaccessible = incorrect. Affects: blind/low-vision, colourblindness, keyboard-only, neurodivergence, plain-language users.

## Visual

- **Colour contrast**: min 4.5:1 (normal text), 3:1 (large text). Use colorcontrast.app. Check text vs background AND button vs page
- **Don't rely on colour alone**: 1 in 12 men, 1 in 200 women colourblind. Pair colour with icon or text
- **Text readability**: line-height ~1.5, line length ~65 chars, readable font sizes
- **Responsive design**: works small screens AND 400% zoom. At max zoom viewport may be <250px; still navigable

## Content & copy

- **Clear language**: no jargon; assume zero context. Provide hints and links
- **Descriptive links & buttons**: link text alone explains action. Not "Delete" — "Delete user Lewis Howles". Not "Learn more" — "Visit MDN docs for the `button` tag"
- **Confirmation & reassurance**: show chosen option (e.g. plan name). Success messages with identifiable info: "User 'Lewis Howles' successfully deleted", not "User deleted"
- **Vue components**: prefer `@lewishowles/components` before building bespoke UI. The component library is accessibility-focused; follow the Vue skill and check live component docs when available

## Documentation

- Treat accessibility fixes and improvements as bug fixes, not announceable features
- Don't update docs, README files, changelogs, or UI copy just to say something is now accessible or "now does" the accessible behaviour
- Only update documentation when the user-facing workflow, API, configuration, or support guidance genuinely changed

## Structure & semantics

- **Heading hierarchy**: no `h1` to `h4` jumps. Use correct level, change appearance if needed. Looks like heading → make it heading
- **Landmark regions**: use `main`, `article`, `aside`, `nav`. Helps assistive tech skip to relevant sections
- **DOM order matches visual order**: tab order should match screen layout. Focus must not jump backwards

## Images & media

- **Alt text**: describes image, not "image of". Decorative: `<img alt="" />`
- **Complex images (charts)**: provide legend as definition list or narrative of findings
- **Video & audio**: captions/transcripts. Helps deaf users AND noisy-environment users
- **No autoplay**: respects data/battery; gives control

## Interaction

- **Keyboard access**: every action via keyboard. Drag-drop? Provide button alternative. When programmatically querying focusable elements, see the code-style skill for the standard selector pattern
- **Visible focus**: show keyboard focus. Ring indicator, no outline removal. Delete in table? Move focus sensibly (next row), not page top
- **Skip links**: `<a href="#main">Skip to main content</a>` with `<main id="main" tabindex="-1">`
- **Motion**: respect `prefers-reduced-motion`. Guard animations: `@media (prefers-reduced-motion: reduce) { ... }`
- **Timing**: no auto-dismiss messages. User closes. Some need more time
- **Touch targets**: min 44×44px; space to avoid accidental taps
- **Focus trap in modals**: on open, save `document.activeElement` and move focus into dialog; on close, restore saved element. Without restoration, keyboard users lose page position
- **Keyboard contract for interactive widgets** (dropdowns, menus, tabs, comboboxes): Arrow keys navigate; Enter or Space activates; Escape cancels/closes. Match [ARIA authoring practices](https://www.w3.org/WAI/ARIA/apg/patterns/)
- **Dialog ARIA**: `role="dialog"` + `aria-modal="true"` + `aria-labelledby` pointing at dialog heading. Tells screen readers rest of page is inert

## Touch & mobile

- **Platform touch targets**: iOS 44×44pt min; Android 48×48dp min. Bigger better (56–60px ideal)
- **Spacing between targets**: motor-impaired and shaky-hand users need breathing room
- **Viewport meta tag**: `<meta name="viewport" content="width=device-width, initial-scale=1">` — enables zoom (never `user-scalable=no`)
- **No horizontal scroll at 400% zoom**: test reflow, not overflow

## Forms & inputs

- **Label association**: `<label for="inputId">` → `<input id="inputId">`, or wrap. Never placeholder alone
- **Grouped inputs**: `<fieldset>` + `<legend>` for radio, checkboxes, related fields. Legend read to screen reader users
- **Help text & instructions**: `aria-describedby="helpId"` pointing at `<span id="helpId">`. Screen readers announce with field
- **Validation & errors**: `aria-invalid="true"` + `aria-errormessage="errorId"` pointing at error text. Error summary at top, linked to fields
- **Autocomplete attributes**: `autocomplete="email"`, `autocomplete="password"`, `autocomplete="current-password"` — helps password managers, reduces friction
- **Error recovery**: don't clear form on error. Let user fix and resubmit

```html
<label for="email">Email address</label>
<input id="email" type="email" autocomplete="email" aria-describedby="email-help email-error" aria-invalid="true" aria-errormessage="email-error" />
<p id="email-help">Use the email address for your account.</p>
<p id="email-error">Enter an email address, like name@example.com.</p>
```

```html
<section role="dialog" aria-modal="true" aria-labelledby="delete-title">
	<h2 id="delete-title">Delete project?</h2>
	<p>This removes "Website refresh" and can't be undone.</p>
	<button type="button">Cancel</button>
	<button type="button">Delete project</button>
</section>
```

## Dynamic content & updates

- **Live regions**: `aria-live="polite"` for validation feedback, success messages, notifications. Polite waits for pause; `aria-live="assertive"` only for urgent alerts (rare)
- **Region announcement**: pair with `aria-label`: `<div aria-live="polite" aria-label="Form errors">`
- **No auto-dismiss**: messages stay until user closes. Some need extra read time
- **Screenreader-only content**: `.sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(1px, 1px, 1px, 1px); }` — hides visually, announced to assistive tech

## Semantics & structure (expanded)

- **Tables**: `<table>` + `<caption>`, `<thead>` + `<th scope="col">` for columns, `<th scope="row">` for rows. Screen readers use scope to map cells
- **Lists**: `<ul>` unordered, `<ol>` ordered, `<dl>` definition lists. No div/paragraph fake lists
- **Abbreviations**: `<abbr title="full text">` for acronyms
- **Language tag**: `lang="en"` on `<html>`. Use `lang="cy"` or `lang="fr"` on blocks where content switches. Helps screen reader pronunciation
- **Navigation & landmarks**: `<nav>`, `<main>`, `<aside>`, `<article>` to structure. Screen reader users jump to landmarks

## Content warnings & safety

- **Flashing & strobing**: max 3 flashes/second in any 1-second window (seizure risk). Test animated GIFs, videos, carousels
- **Content warnings**: flag violence, self-harm, abuse, graphic medical, trauma triggers before user encounters. Give visibility control
- **Reduced motion**: respect `prefers-reduced-motion: reduce`. Disable autoplay animations, carousels, parallax. Keep interactions responsive, not flashy
