# TypeScript

- No complex type gymnastics; manual runtime checks for external data
- Simplest acceptable types, not clever/complex ones
- Prefer built-in types over framework-specific when no meaningful safety gained
- `as any` / `as unknown` OK as named local escapes, but smelly. May need for proper input validation
- Always explain why type error occurs — never silently fix

## Useful utility types

Reach for these before writing a manual type — they're not gymnastics, they're vocabulary:

| Type             | Use for                                          |
| ---------------- | ------------------------------------------------ |
| `Partial<T>`     | All props optional (update payloads, form state) |
| `Required<T>`    | All props required (after validation)            |
| `Pick<T, K>`     | Subset of props from an existing type            |
| `Omit<T, K>`     | All props except listed ones                     |
| `ReturnType<T>`  | Infer return type of a function                  |
| `Parameters<T>`  | Infer argument tuple of a function               |
| `NonNullable<T>` | Strip `null` and `undefined` from a union        |
| `Record<K, V>`   | Plain object with known key and value shapes     |

## `satisfies` operator

Use `satisfies` to validate a value matches a type without widening it. Useful for config objects where you want autocomplete and type checking, but want the literal type preserved:

```typescript
const routes = {
  home: "/",
  about: "/about",
} satisfies Record<string, string>;

// routes.home is still typed as "/" not string
```

```typescript
import { isNonEmptyObject } from "@lewishowles/helpers/object";

/**
 * Convert untrusted API data into a safe user record.
 *
 * @param  {unknown}  rawUser
 *     The raw user object returned by the API.
 */
function normaliseUser(rawUser: unknown) {
  if (!isNonEmptyObject(rawUser)) {
    return null;
  }

  const user = rawUser as Record<string, unknown>;

  return {
    id: typeof user.id === "string" ? user.id : null,
    name: typeof user.name === "string" ? user.name : "Unknown user",
  };
}
```
