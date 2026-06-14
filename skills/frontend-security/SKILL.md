---
# Generated — edit skill.json and SKILL.body.md instead.
name: frontend-security
description: >
  Use this skill when writing or reviewing client-side code for security implications. Covers XSS prevention, Content Security Policy, safe v-html usage, authentication token handling, secrets hygiene, and dependency security for Vue/TypeScript projects. Apply proactively when handling user input, rendering dynamic content, or managing auth state.
do-not-use-when:
  - Writing server-side code, API routes, or database queries
  - A general code review with no security implications
related-skills:
  - error-handling
  - vue
  - vue-vite
---
# Frontend security

## XSS prevention

Cross-site scripting is the highest-impact frontend vulnerability. Never put untrusted data into HTML without escaping or sanitisation.

**Vue templates are safe by default** — `{{ value }}` HTML-encodes output. Risk comes from bypasses:

- `v-html` renders raw HTML — only use with content you control or have sanitised
- `innerHTML` bypasses Vue escaping
- Dynamic `href`/`src` attributes can carry `javascript:` URIs — validate URLs before binding

When `v-html` is unavoidable, sanitise with DOMPurify first:

```javascript
import DOMPurify from "dompurify";

const safeHtml = computed(() => DOMPurify.sanitize(props.richContent));
```

```vue
<div v-html="safeHtml" />
```

Never pass `props.richContent` directly to `v-html`.

## Content Security Policy

CSP is a browser-enforced allowlist for scripts, styles, and resources. It is the second line of defence after output encoding.

Key directives:

```
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'nonce-{random}';
  style-src 'self' 'nonce-{random}';
  img-src 'self' data: https:;
  connect-src 'self' https://api.example.com;
  frame-ancestors 'none';
```

- Avoid `'unsafe-inline'` and `'unsafe-eval'` — they defeat the purpose
- Use nonce-based CSP for inline scripts/styles that cannot move to external files
- Start in `Content-Security-Policy-Report-Only` mode to catch violations before enforcing
- Set `frame-ancestors 'none'` to prevent clickjacking

## URL and redirect safety

- Validate `href`/`src` against an allowlist before binding; reject `javascript:`, `data:`, and protocol-relative URLs
- Never build redirect targets from unvalidated query parameters

```javascript
function isSafeUrl(url) {
  try {
    const parsed = new URL(url, window.location.origin);
    return ["https:", "http:"].includes(parsed.protocol);
  } catch {
    return false;
  }
}
```

## Authentication token handling

- Store auth tokens in server-set `httpOnly` cookies, not script-readable `localStorage` or `sessionStorage`
- If cookies aren't viable (SPA with separate API), use memory-only storage (a module-scoped ref, not `window.*`) and accept that tokens don't survive page refresh
- Never log tokens, include them in URLs, or put them in error messages
- Include CSRF tokens for any state-mutating requests when using cookie auth

## Secrets hygiene

Any `VITE_` env var is statically inlined into the client bundle. It is **not** secret; anyone can extract it from shipped JavaScript.

Rules:

- Only public values go in `VITE_` vars: API base URLs, feature flags, public keys
- Private API keys, database credentials, and signing secrets live server-side only
- Check `.gitignore` includes `.env.local` and `.env.*.local`
- Use `rg "VITE_.*KEY\|VITE_.*SECRET\|VITE_.*TOKEN"` to audit before shipping

## Dependency security

- Run `bun audit` (or `npm audit`) regularly; fix high and critical issues before shipping
- Pin major versions; review changelogs before upgrading security-sensitive packages (`dompurify`, auth libraries)
- Prefer packages with active maintenance and security advisories tracked

For detailed patterns (input validation, file upload safety, subresource integrity, clickjacking), see [references/patterns.md](references/patterns.md).
