---
name: vite-patterns
description: >
  Use this skill when configuring vite.config.ts, managing environment variables, or troubleshooting build/dev server issues. Covers config structure, environment variables, security boundaries, library mode, dev vs build differences, and common pitfalls.
---

> Modified from [ECC `vite-patterns`](https://github.com/affaan-m/everything-claude-code/blob/main/skills/vite-patterns/SKILL.md) — MIT © 2026 Affaan Mustafa. Adapted to focus on config, security, and build patterns relevant to Vue projects; omitted plugin authoring and framework-specific HMR details.

# Vite patterns

Build tool patterns for Vite projects. Dev mode serves source files as native ESM with on-demand transforms. Build mode bundles with tree-shaking and code-splitting via Rollup.

## Config structure

### Basic config

```typescript
import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

export default defineConfig({
	plugins: [vue()],
	resolve: {
		alias: { "@": new URL("./src", import.meta.url).pathname },
	},
});
```

### Conditional config

```typescript
import { defineConfig, loadEnv } from "vite";
import vue from "@vitejs/plugin-vue";

export default defineConfig(({ command, mode }) => {
	// Good: explicit prefix list (safe).
	const env = loadEnv(mode, process.cwd(), ["VITE_"]);

	return {
		plugins: [vue()],
		server: command === "serve" ? { port: 5173 } : undefined,
		define: {
			__API_URL__: JSON.stringify(env.VITE_API_URL),
		},
	};
});
```

### Key config options

| Key | Default | Notes |
|-----|---------|-------|
| `root` | `"."` | Project root (where `index.html` lives) |
| `base` | `"/"` | Public base path for deployed assets |
| `envPrefix` | `"VITE_"` | Prefix for client-exposed env vars |
| `build.outDir` | `"dist"` | Output directory |
| `build.minify` | `"oxc"` | Minifier (`"oxc"`, `"terser"`, or `false`) |
| `build.sourcemap` | `false` | `true`, `"inline"`, or `"hidden"` (disable in prod) |

## Environment variables

Vite loads `.env`, `.env.local`, `.env.[mode]`, `.env.[mode].local` in order; later files override earlier. `.local` files gitignored, for local secrets.

### Client-side access

Only `VITE_`-prefixed vars exposed to client code:

```typescript
// Accessible in browser.
import.meta.env.VITE_API_URL;
import.meta.env.MODE; // "development" | "production" | custom
import.meta.env.BASE_URL; // base config value
import.meta.env.DEV; // boolean
import.meta.env.PROD; // boolean
```

### Using env in config

```typescript
import { defineConfig, loadEnv } from "vite";

export default defineConfig(({ mode }) => {
	const env = loadEnv(mode, process.cwd(), ["VITE_", "APP_"]);

	return {
		define: {
			__API_URL__: JSON.stringify(env.VITE_API_URL),
		},
	};
});
```

## Security

### `VITE_` prefix is not a security boundary

Any `VITE_`-prefixed var is **statically inlined into client bundle at build time**. Minification and disabled source maps do NOT hide it. Attacker can extract any `VITE_` var from shipped JavaScript.

**Rule:** Only public values (API URLs, feature flags, public keys) go in `VITE_` vars. Secrets (API tokens, database URLs, private keys) MUST live server-side behind an API.

### The `loadEnv("")` trap

```typescript
// Bad: passing "" loads all env vars, including server secrets,
// making them available to inline into client code.
const env = loadEnv(mode, process.cwd(), "");

// Good: explicit prefix list.
const env = loadEnv(mode, process.cwd(), ["VITE_", "APP_"]);
```

### Source maps in production

Production source maps leak original source code. Disable unless uploading to error tracker (Sentry, Bugsnag) and deleting locally afterward:

```typescript
build: {
	sourcemap: false, // default — keep it this way
}
```

### .gitignore checklist

- `.env.local`, `.env.*.local` — local overrides with secrets
- `dist/` — build output
- `node_modules/.vite` — pre-bundle cache (stale entries cause phantom errors)

## Dev vs build

Dev uses esbuild for on-demand transforms; build uses Rollup for bundling. CJS libs can behave differently between the two. **Always verify with `vite build && vite preview` before deploying.**

`vite build` transpiles but does NOT type-check. Type errors silently ship to production unless you run `tsc --noEmit` in CI or use `vite-plugin-checker`.

## Imports and assets

Use `import.meta.glob` for file-system driven imports instead of hand-maintained registries:

```typescript
const modules = import.meta.glob("./pages/**/*.vue");
```

Use Vite asset query imports when the requested representation matters:

```typescript
import iconUrl from "./icon.svg?url";
import shaderSource from "./shader.glsl?raw";
```

## Plugins

- Keep plugin order intentional; framework plugins usually come before inspection, analysis, or transform helpers
- Use virtual modules only when config-time data genuinely needs to become importable runtime code
- Check current Vite docs before applying version-specific migration guidance, especially around Rolldown, Oxc, and major-version beta features

## Library mode

Publishing npm package: use `build.lib`. Two footguns:

1. **Types not emitted** — add `vite-plugin-dts` or run `tsc --emitDeclarationOnly` separately.
2. **Peer deps MUST be externalized** — unlisted peers bundle into library, causing duplicate-runtime errors in consumers.

```typescript
build: {
	lib: {
		entry: "src/index.ts",
		formats: ["es", "cjs"],
		fileName: (format) => `my-lib.${format}.js`,
	},
	rolldownOptions: {
		external: ["vue", "vue-router"], // every peer dep
	},
}
```

## SSR mode

- Treat SSR builds as a separate runtime: browser globals, env variables, and asset URLs may behave differently
- Keep client-only logic behind component lifecycle hooks or explicit environment guards
- Test both dev SSR and production build output when changing Vite SSR config

## Common pitfalls

### Stale chunks after deployment

New builds produce new chunk hashes. Users with active sessions request old filenames that no longer exist. Mitigations:

- Keep old `dist/assets/` files live for deployment window
- Catch dynamic import errors in router and force page reload

### Docker and containers

Vite binds to `localhost` by default, unreachable from outside container:

```typescript
server: {
	host: true, // bind 0.0.0.0
	hmr: { clientPort: 3000 }, // if behind reverse proxy
}
```

### Monorepo file access

Vite restricts file serving to project root. Packages outside root blocked:

```typescript
server: {
	fs: {
		allow: [".."], // allow parent directory (workspace root)
	},
}
```

### Barrel files slow dev server

Barrel files (`index.ts` re-exporting everything from directory) force Vite to load every re-exported file even when importing single symbol.

```typescript
// Bad: importing one util forces load of whole barrel.
import { slash } from "@/utils";

// Good: direct import.
import { slash } from "@/utils/slash";
```

### Explicit import extensions

Each implicit extension forces multiple filesystem checks. In large codebases, adds up.

```typescript
// Bad.
import Component from "./Component";

// Good.
import Component from "./Component.vue";
```

### Stale pre-bundle cache

Pre-bundle cache (`node_modules/.vite`) causes phantom errors when deps change. Clear when switching branches or after patching deps:

```bash
rm -rf node_modules/.vite
```
