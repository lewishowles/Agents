# Web performance

## Core Web Vitals targets

| Metric  | Target  | What it measures                                    |
| ------- | ------- | --------------------------------------------------- |
| **LCP** | < 2.5s  | Largest visible element painted                     |
| **CLS** | < 0.1   | Layout shift from elements loading or resizing      |
| **INP** | < 200ms | Responsiveness: time from interaction to next paint |

Measure with Lighthouse (DevTools → Lighthouse) or [web.dev/measure](https://web.dev/measure). Ask user to run Lighthouse against production; dev numbers are unreliable.

## LCP

LCP is usually hero image or large heading above fold.

- **Preload the LCP image**: `<link rel="preload" as="image" href="/hero.webp">`
- **Use modern formats**: WebP or AVIF. Provide a fallback with `<picture>` + `<source>`
- **Don't lazy-load the LCP image** — it is already in the viewport
- **Set explicit width/height** on images to reserve space before load

```html
<img src="/hero.webp" width="1200" height="630" alt="…" fetchpriority="high" />
```

## CLS

Layout shift happens when elements change size/position after initial paint.

- **Set width/height on images and video** — or use `aspect-ratio`
- **Reserve space for async content**: skeleton loaders, min-height on dynamic areas
- **Avoid inserting content above existing content**: banners, late cookie bars
- **Use `font-display: swap` or `optional`** to prevent invisible text during font load

## INP

INP measures response time for clicks, taps, and keyboard input.

- **Long tasks block the main thread** — split work with `scheduler.yield()` or deferred promises
- **Avoid expensive Vue `computed` work** — computed is synchronous and runs on every reactive access
- **Keep event handlers fast** — defer non-critical work (analytics, logging) to `requestIdleCallback`
- **Use `v-show` instead of `v-if`** for elements toggled frequently — avoids repeated mount/unmount cost

## Vue reactivity cost

- Use `shallowRef` for large objects, fetched payloads, and library instances not needing deep reactivity
- Avoid deeply reactive objects (`reactive({...})`) for data with many nested properties
- Use `v-memo` on expensive list rows when the template is costly to re-evaluate
- `defineAsyncComponent` to defer component initialisation until needed:

```javascript
const HeavyChart = defineAsyncComponent(() => import("./heavy-chart.vue"));
```

## Code splitting

Vite splits at route boundaries with dynamic imports. Ensure route components use `defineAsyncComponent` or dynamic router imports:

```javascript
const routes = [{ path: "/dashboard", component: () => import("./views/dashboard.vue") }];
```

Check bundles with `rollup-plugin-visualizer`; ask the user to run `bun run build --report` if configured.

## Images

```html
<!-- Lazy-load below-fold images -->
<img src="/photo.webp" loading="lazy" decoding="async" width="800" height="600" alt="…" />

<!-- Responsive images -->
<img
  srcset="/photo-400.webp 400w, /photo-800.webp 800w"
  sizes="(max-width: 600px) 400px, 800px"
  src="/photo-800.webp"
  alt="…"
/>
```

## Fonts

```html
<!-- Preload critical fonts -->
<link rel="preload" href="/fonts/inter-var.woff2" as="font" type="font/woff2" crossorigin />
```

```css
@font-face {
  font-family: "Inter";
  src: url("/fonts/inter-var.woff2") format("woff2");
  font-display: swap; /* or 'optional' to suppress FOUT entirely */
}
```

Prefer variable fonts over multiple static weights.

## GitHub Pages specifics

- Hashed asset filenames get 1-year `Cache-Control` via CDN — Vite does this by default
- `index.html` is short-lived — keep it small and don't inline critical data in it
- No server-side rendering or edge caching — all optimisation is client-side
- Use the `404.html` redirect trick for SPA routing (copy `index.html` to `404.html`)

For measurement tooling and Lighthouse CI setup, see [references/measurement.md](references/measurement.md).

## Completion

For UI-facing performance changes, run [the accessibility checklist](../accessibility/references/checklist.md) before handoff.
