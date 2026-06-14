# Error handling

## Input validation

- JS: use helpers for basic input validation (`isNonEmptyObject`, `isNonEmptyArray`)
- Critical params: validate + early return if invalid
- Non-critical params: default in signature, no explicit check
- Uncertain types: use `validateOrFallback` or similar

```javascript
import { isNonEmptyString } from "@lewishowles/helpers/string";

/**
 * Load projects for a user.
 *
 * @param  {string}  userId
 *     The user ID to fetch projects for.
 * @param  {number}  limit
 *     The maximum number of projects to return.
 */
async function loadProjects(userId, limit = 20) {
	if (!isNonEmptyString(userId)) {
		return [];
	}

	return api.get(`/users/${userId}/projects`, { limit });
}
```

## API responses

- Validate structurally (object, array)
- Don't validate deep structure — use `get` helper to safely navigate missing props
- Missing prop: `get` returns null; decide by context

## Graceful fallbacks

- Handle gracefully when possible. Surface "No items" states in UI.
- User can't resolve failure → show fallback

## Don't handle

- Structurally impossible failures
- Cases where entire flow must change — crash loudly instead

## Logging

- No verbose logging by default. It adds noise.
