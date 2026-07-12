# Accessibility

WCAG AA baseline; AAA where feasible. Inaccessible = incorrect. Covers blind/low-vision, colourblind, keyboard-only, neurodivergent, and plain-language users.

Never assert a feature's browser or assistive-tech support from training memory; it ages fast. The MDN MCP server (live docs and browser-compat data) is configured but disabled by default: ask the user to enable it, then query it to confirm support before relying on it.

## Visual

- **Colour contrast**: min 4.5:1 (normal text), 3:1 (large text). Use colorcontrast.app. Check text vs background and button vs page
- **Don't rely on colour alone**: pair colour with icon or text
- **Text readability**: line-height ~1.5, line length ~65 chars, readable font sizes
- **Responsive design**: works on small screens and 400% zoom; still navigable below 250px wide
- **Robust text layout**: set `min-width: 0` in flex/grid children with long text; choose wrapping, truncation, or scrolling deliberately
- **Images**: set dimensions or aspect ratio so layout does not jump. Lazy-load below-fold images

## Content & copy

- **Clear language**: no jargon; assume zero context. Provide hints and links
- **Descriptive links & buttons**: link text explains action alone. Not "Delete" — "Delete user Lewis Howles". Not "Learn more" — "Visit MDN docs for the `button` tag"
- **Confirmation & reassurance**: show chosen option (e.g. plan name). Success messages use identifiable info: "User 'Lewis Howles' successfully deleted", not generic text
- **Vue components**: prefer `@lewishowles/components`. Follow the Vue skill and check live component docs

## Documentation

- Treat accessibility fixes as bug fixes, not features
- Don't update docs or README just to say something is now accessible
- Update documentation only when user-facing workflow, API, configuration, or support guidance changed

Test: if a sighted developer needs to know it, document it. If it only explains a11y mechanics, omit it.

```
❌ "Each option is labelled with a unit-aware string so screen readers announce meaningful names."
✅ No change — internal behaviour; only document props, slots, or emits that changed.

❌ "A visually-hidden data table is always rendered alongside the SVG for screen reader users."
✅ Omit entirely, or if the consumer needs to know it exists (e.g. to style around it):
   "A data table of segment values is rendered alongside the chart."
```

## Structure & semantics

- **Heading hierarchy**: no `h1` to `h4` jumps. Use correct level; change appearance if needed. Looks like heading → make it heading
- **Landmark regions**: use `main`, `article`, `aside`, `nav`
- **DOM order matches visual order**: tab order should match screen layout. Focus must not jump backwards

## Images & media

- **Alt text**: describes image, not "image of". Decorative: `<img alt="" />`
- **Complex images (charts)**: provide a definition-list legend or narrative findings
- **Video & audio**: captions/transcripts
- **No autoplay**: respects data/battery and gives control

## Interaction

- **Keyboard access**: every action works by keyboard. For drag-drop, provide button alternative. Focusable selectors: see code-style
- **Visible focus**: show keyboard focus with ring indicator; never remove outline. After delete, move focus sensibly (next row, not page top)
- **Focus after errors**: after failed form submission, move focus to the error summary or first invalid field
- **Skip links**: `<a href="#main">Skip to main content</a>` with `<main id="main" tabindex="-1">`
- **Motion**: respect `prefers-reduced-motion`. Guard animations: `@media (prefers-reduced-motion: reduce) { ... }`
- **Transitions**: avoid `transition: all`; animate explicit properties with reduced-motion fallbacks
- **Timing**: no auto-dismiss messages. User closes them
- **Touch targets**: min 44×44px; add space to avoid accidental taps
- **Focus trap in modals**: on open, save `document.activeElement` and move focus into dialog; on close, restore saved element. Without restoration, keyboard users lose page position
- **Keyboard contract for interactive widgets** (dropdowns, menus, tabs, comboboxes): Arrow keys navigate; Enter or Space activates; Escape cancels/closes. Match [ARIA authoring practices](https://www.w3.org/WAI/ARIA/apg/patterns/)
- **Dialog ARIA**: `role="dialog"` + `aria-modal="true"` + `aria-labelledby` pointing at dialog heading

## Touch & mobile

- **Platform touch targets**: iOS 44×44pt min; Android 48×48dp min. 56–60px is better
- **Spacing between targets**: leave room between controls
- **Viewport meta tag**: `<meta name="viewport" content="width=device-width, initial-scale=1">` — enables zoom (never `user-scalable=no`)
- **No horizontal scroll at 400% zoom**: test reflow, not overflow

## Forms & inputs

- **Label association**: `<label for="inputId">` → `<input id="inputId">`, or wrap. Never placeholder alone
- **Input type and mode**: use most specific `type`, `inputmode`, and `autocomplete` for expected data
- **Grouped inputs**: `<fieldset>` + `<legend>` for radio, checkboxes, related fields
- **Help text & instructions**: `aria-describedby="helpId"` pointing at `<span id="helpId">`
- **Validation & errors**: `aria-invalid="true"` + `aria-errormessage="errorId"` pointing at error text. Error summary at top, linked to fields
- **Autocomplete attributes**: `autocomplete="email"`, `autocomplete="password"`, `autocomplete="current-password"` — helps password managers, reduces friction
- **Error recovery**: don't clear form on error. Let user fix and resubmit

```html
<label for="email">Email address</label>
<input
  id="email"
  type="email"
  autocomplete="email"
  aria-describedby="email-help email-error"
  aria-invalid="true"
  aria-errormessage="email-error"
/>
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

- **Live regions**: `aria-live="polite"` for validation feedback, success messages, notifications. Use `assertive` only for urgent alerts
- **Region announcement**: pair with `aria-label`: `<div aria-live="polite" aria-label="Form errors">`
- **No auto-dismiss**: messages stay until user closes them
- **Screenreader-only content**: `.sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(1px, 1px, 1px, 1px); }` — hidden visually, announced to assistive tech

## Controls

- Icon-only buttons need an accessible name via visible text, `aria-label`, or `aria-labelledby`
- Use `aria-label` and `aria-labelledby` only when the element's implicit or explicit role supports an author-provided name. Prefer visible or visually hidden text, and don't add ARIA names to paragraphs, generic spans/divs, or presentational content
- Do not put click handlers on non-interactive elements when button/link is correct semantic control
- Do not block paste in form fields
- Destructive actions need confirmation, undo, or both
- **Accessible names built from multiple pieces of state** (tree nodes, list rows, grid cells): put the most important disambiguating information first, not last — a screen reader user often stops listening once they've heard enough to act. Don't rely on visual position or component configuration to convey what the label prioritises in speech

## Semantics & structure (expanded)

- **Tables**: `<table>` + `<caption>`, `<thead>` + `<th scope="col">`, `<th scope="row">`
- **Lists**: `<ul>` unordered, `<ol>` ordered, `<dl>` definition lists. No div/paragraph fake lists
- **Abbreviations**: `<abbr title="full text">` for acronyms
- **Language tag**: `lang="en"` on `<html>`. Use `lang="cy"` or `lang="fr"` where content switches
- **Navigation & landmarks**: use `<nav>`, `<main>`, `<aside>`, `<article>`

## Quick-reference checklist

PR-pasteable checklist: [`references/checklist.md`](references/checklist.md).

## Before handoff

Review changed UI against [`references/checklist.md`](references/checklist.md), fix issues found, and state which checks were actually performed. Passing the checklist or an automated scan does not prove WCAG conformance; manual and assistive-technology testing may still be needed.

## Content warnings & safety

- **Flashing & strobing**: max 3 flashes/second in any 1-second window. Test GIFs, videos, carousels
- **Content warnings**: flag violence, self-harm, abuse, graphic medical, trauma triggers before user encounters. Give visibility control
- **Reduced motion**: respect `prefers-reduced-motion: reduce`. Disable autoplay animations, carousels, parallax. Keep interactions responsive, not flashy
