---
# Generated — edit skill.json and SKILL.body.md instead.
name: error-handling
description: >
  Use this skill when writing functions that accept parameters, making API calls, or handling any response data — even if errors aren't the main topic. Covers input validation with helper utilities, API response validation, graceful fallbacks, and what NOT to handle. Apply proactively when writing JavaScript/TypeScript functions.
do-not-use-when:
  - Discussing a user-facing error message or empty-state copy without changing validation or fallback behaviour
  - A test failure is being debugged and the fix is likely in the test or implementation logic, not error handling
  - Reviewing code style, naming, or formatting with no parameter, API, or response handling involved
---
# Error handling

## Input validation

- JS: use helpers for basic validation (`isNonEmptyObject`, `isNonEmptyArray`)
- Critical params: validate and return early if invalid
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
- Don't validate deep structure; use `get` to safely navigate missing props
- Missing prop returns null via `get`; decide by context

## Graceful fallbacks

- Handle gracefully when possible. Surface "No items" states.
- User can't resolve failure: show fallback

## Don't handle

- Structurally impossible failures
- Cases where entire flow must change: crash loudly

## Logging

- No verbose logging by default. It adds noise.
