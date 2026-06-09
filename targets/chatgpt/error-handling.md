---
name: error-handling
description: >
  Use this skill when writing functions that accept parameters, making API calls, or handling any response data — even if errors aren't the main topic. Covers input validation with helper utilities, API response validation, graceful fallbacks, and what NOT to handle. Apply proactively when writing JavaScript/TypeScript functions.
---

# Error handling

## Input validation

- JS: use helpers for basic input type validation (`isNonEmptyObject`, `isNonEmptyArray`, etc.)
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

- Validate structurally (is object, is array, etc.)
- Don't validate deep structure — use `get` helper to safely navigate missing props
- Missing prop: `get` returns null, decide how to continue based on context

## Graceful fallbacks

- Handle gracefully when possible. "No items" constructs surface in UI.
- User can't resolve failure → show fallback

## Don't handle

- Structurally impossible failures
- Cases where entire flow must change — crash loudly instead

## Logging

- No verbose logging by default. Noise, little benefit.
