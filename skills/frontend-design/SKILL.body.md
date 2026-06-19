# Frontend design

Before UI code, establish design direction. Aesthetic decisions are cheap upfront; mismatched typography/colour is expensive after implementation.

## Decision sequence

Work through in order. If answer is missing, ask — don't guess.

1. **Purpose** — what must this page or component achieve? (inform, convert, demonstrate, delight)
2. **Tone** — what feeling should it produce? (confident, calm, playful, minimal, authoritative)
3. **Constraints** — existing brand tokens, design system, target platform, viewport range, motion preferences
4. **Differentiation** — what makes this distinct from the generic version of this UI pattern?
5. **Code** — only then, reach for the editor

If (4) is "nothing yet", resolve before proceeding. A landing page that could belong to any product fails.

## Typography

Choose type that reflects tone, not type that avoids controversy.

- **Default pairings to avoid**: Inter + anything, Roboto + anything. Both signal "safe option".
- Pick scale intentionally: modular ratio (1.25, 1.333, 1.5), then stick to it
- Limit to two typefaces: one for display/headings, one for body. Use weight and size for hierarchy before reaching for a third face
- Line height: 1.4–1.6 for body, tighter (1.1–1.2) for large display headings
- Measure (line length): 60–75 characters for body, no constraint on short display lines

## Colour

Colour should carry meaning, not just decoration.

- Start from the purpose: a medical dashboard needs restraint; a food brand can be saturated
- Establish a palette with one dominant hue, one accent used sparingly, and neutral surface tones
- **Contrast is non-negotiable**: 4.5:1 body text, 3:1 large text and UI components (WCAG AA). Check light and dark variants
- Don't default to purple-blue or teal-green gradients — visual equivalent of Inter
- If using a gradient, make sure it has a clear directional rationale (light source, brand direction)

## Motion and animation

Motion should reinforce meaning, not demonstrate capability.

- Define motion vocabulary before animating: what enters, leaves, transitions?
- Prefer `transform` and `opacity`; avoid animating layout properties (`width`, `height`, `padding`, `top/left`)
- Duration guide: micro-interactions 100–150ms; component transitions 200–350ms; page-level transitions 400–500ms
- Easing: ease-out for things entering (fast start, gentle stop); ease-in for things leaving; ease-in-out for reversible transitions
- Always provide `prefers-reduced-motion` fallbacks — remove/replace animations, don't just slow them

## Layout and composition

- Establish grid before placing elements. 8pt grid (or 4pt for dense UIs) enforces rhythm
- Use whitespace as a design element, not just padding to fill
- Hierarchy should read in 3 seconds: primary action, secondary, tertiary?
- Avoid symmetrical layouts by default — asymmetry creates tension and movement; symmetry signals formality or stasis. Choose deliberately
- For heroes: lead with specific claim, not generic value prop. "Build accessible Vue components in minutes" beats "The modern component library"

## Anti-patterns

Defaults to reject, not rules to follow:

| Avoid                                     | Because                                                     | Instead                                                                                     |
| ----------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Inter as default body font                | Ubiquitous; signals no typographic decision was made        | Outfit, DM Sans, Fraunces, Syne, or a system stack used deliberately                        |
| Purple-to-blue gradient hero              | The most common SaaS visual pattern of the last five years  | Derive colour from the product's purpose; one strong hue beats a gradient                   |
| Card grid on a white background           | Looks like a dashboard template                             | Vary density, use full-bleed sections, break the grid intentionally                         |
| `transition: all`                         | Animates layout properties and causes jank                  | Animate explicit properties: `transition: transform 200ms ease-out, opacity 200ms ease-out` |
| Placeholder copy ("Lorem ipsum")          | Obscures whether the layout actually works for real content | Use real or realistic content from the start                                                |
| "Flat" icons with no visual weight system | Inconsistent visual density across a UI                     | Pick one icon set; use consistent stroke width and optical size                             |
| Centred body text beyond a short tagline  | Hard to read; signals "I saw this on a landing page"        | Left-align body copy; centre sparingly for display-sized single lines                       |

## Completion gate

Before handing off to implementation, confirm:

- Typography scale and typefaces documented (or using existing tokens)
- Colour palette defined with contrast ratios checked
- Motion vocabulary described (or explicitly "no animation")
- Design reviewed at the narrowest and widest breakpoints
- Checked against the accessibility skill: keyboard access, focus, colour contrast, reduced-motion

---

_Adapted from the Anthropic Claude Code frontend-design skill (MIT). Reworded and extended._
