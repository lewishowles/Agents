---
# Generated — edit skill.json and SKILL.body.md instead.
name: vue-pinia-colada
description: >
  Use this skill when working with @pinia/colada for async data fetching and server state in Vue projects. TRIGGER when: code imports from `@pinia/colada`, uses `useQuery`, `useMutation`, `defineQuery`, `defineMutation`, `useQueryCache`, or `invalidateQueries`; when setting up async data fetching in a Vue project; when working in `src/queries/`.
related-skills:
  - vue
  - vue-project-stack
  - vue-pinia
---
# Pinia Colada

Pinia Colada manages Vue server state: caching, deduplication, background revalidation, and mutation coordination. It sits above fetch/API functions.

## Setup

```bash
bun add pinia @pinia/colada
bun add -D @pinia/colada-devtools
```

```js
// main.js
import { createApp } from "vue";
import { createPinia } from "pinia";
import { PiniaColada } from "@pinia/colada";

const app = createApp(App);

app.use(createPinia());
app.use(PiniaColada);
```

```vue
<!-- App.vue — devtools only, never shipped to production -->
<script setup>
import { PiniaColadaDevtools } from "@pinia/colada-devtools";
</script>

<template>
	<router-view />

	<pinia-colada-devtools />
</template>
```

## Default conventions

Use Pinia Colada for server state, not transport. Keep API clients focused on HTTP/Xano/fetch; put cache keys, query options, mutations, and wrappers under `src/queries/`.

Prefer feature folders once a resource has queries and mutations:

```
src/queries/auth/
├── index.js          # Public exports only
├── current-user.js   # Current user query + useCurrentUser()
└── login.js          # Login mutation + useAuth()
```

Components import from the feature folder, not implementation files:

```js
import { useAuth, useCurrentUser } from "@/queries/auth";
```

Name reusable definitions `*QueryOptions` / `*MutationOptions`; name live return values after the resource/action:

```js
export const currentUserQueryOptions = defineQueryOptions({
	key: CURRENT_USER_QUERY_KEY,
	query: getCurrentUser,
});

const currentUser = useQuery(() => ({
	...currentUserQueryOptions,
	enabled: hasAuthToken(),
}));
```

Mental model:
- `currentUserQueryOptions` — reusable recipe: key + fetcher
- `currentUser` — live query state from `useQuery()`
- `userDetails` — derived data object exposed to components

Use wrappers when they remove repeated setup or expose derived values. Use route middleware for access decisions, not data preloading: for auth, prefer a token-only guard; components/layouts calling `useCurrentUser()` activate the query when `enabled` is true.

## Key factories

Centralise cache keys in the query file. Parent keys create hierarchy: invalidating a parent invalidates its children.

```js
// src/queries/contacts.js
export const CONTACT_KEYS = {
	root: ["contacts"],
	byId: (id) => [...CONTACT_KEYS.root, id],
	byIdWithNotes: (id) => [...CONTACT_KEYS.byId(id), { notes: true }],
};
```

Invalidating `CONTACT_KEYS.root` invalidates every contacts query. Invalidating `CONTACT_KEYS.byId(id)` invalidates that contact and its notes.

For singleton resources, keep keys simple:

```js
export const CURRENT_USER_QUERY_KEY = ["user"];
```

For collections, include every input that changes returned data:

```js
export const ALERT_KEYS = {
	root: ["alerts"],
	list: (siteId, filters) => [...ALERT_KEYS.root, "list", siteId, filters],
	byId: (alertId) => [...ALERT_KEYS.root, "detail", alertId],
};
```

## defineQueryOptions

Combine a key factory with a query function. Pass the definition to `useQuery` instead of inlining keys.

**Static** (no parameters):

```js
import { defineQueryOptions } from "@pinia/colada";
import { getContacts } from "@/api/contacts";

export const contactListQueryOptions = defineQueryOptions({
	key: CONTACT_KEYS.root,
	query: () => getContacts(),
});
```

**Dynamic** (with parameters):

```js
import { getContactById } from "@/api/contacts";

export const contactByIdQueryOptions = defineQueryOptions((id) => ({
	key: CONTACT_KEYS.byId(id),
	query: () => getContactById(id),
}));
```

## useQuery

Pass dynamic options as a getter so Vue tracks reactivity.

```vue
<script setup>
import { useQuery } from "@pinia/colada";
import { useRoute } from "vue-router";
import { contactByIdQueryOptions } from "@/queries/contacts";

const route = useRoute();

// Getter function — re-evaluates reactively when route.params changes.
const contact = useQuery(() => contactByIdQueryOptions(route.params.contactId));
</script>

<template>
	<div v-if="contact.asyncStatus.value === 'loading'">Loading…</div>
	<div v-else-if="contact.state.value.status === 'error'">{{ contact.state.value.error.message }}</div>
	<div v-else-if="contact.state.value.data">{{ contact.state.value.data.name }}</div>
</template>
```

Use `state`, not destructured `data`/`error`, for status checks; it narrows types in conditionals.

### Pausing a query

Use `enabled` to pause until required data exists.

```js
const selectedId = ref(null);

useQuery({
	key: () => ["contacts", selectedId.value],
	query: () => getContactById(selectedId.value),
	enabled: () => selectedId.value != null,
});
```

### Spreading extra options

Override individual options without redefining the query.

```js
useQuery(() => ({
	...contactByIdQueryOptions(route.params.contactId),
	enabled: isReady.value,
}));
```

## useMutation

```js
import { useMutation, useQueryCache } from "@pinia/colada";
import { CONTACT_KEYS } from "@/queries/contacts";
import { updateContact } from "@/api/contacts";

const queryCache = useQueryCache();

const { mutate: saveContact, asyncStatus } = useMutation({
	mutation: (contact) => updateContact(contact),
	onSettled(_data, _error, contact) {
		queryCache.invalidateQueries({ key: CONTACT_KEYS.byId(contact.id) });
	},
});
```

- `mutate()` — fire-and-forget, catches errors silently
- `mutateAsync()` — returns a promise, re-throws errors

Prefer `mutateAsync()` when the caller already has `try/catch`, such as login forms or save buttons that redirect after success.

## defineMutationOptions and defineMutation

Use `defineMutationOptions` for reusable mutation recipes. Use `defineMutation` only when the wrapper needs shared reactive state.

```js
// src/queries/contacts/delete.js
import { defineMutationOptions, useMutation, useQueryCache } from "@pinia/colada";
import { CONTACT_KEYS } from "@/queries/contacts";
import { deleteContact } from "@/api/contacts";

export const deleteContactMutationOptions = defineMutationOptions({
	mutation: (id) => deleteContact(id),
});

export function useDeleteContact() {
	const queryCache = useQueryCache();

	return useMutation({
		...deleteContactMutationOptions,

		onSettled(_data, _error, id) {
			queryCache.invalidateQueries({ key: CONTACT_KEYS.byId(id) });
			queryCache.invalidateQueries({ key: CONTACT_KEYS.root, exact: true });
		},
	});
}
```

## defineQuery

Shares reactive state, such as search refs or filters, across components using the same query. Without it, each component gets its own internal refs.

```js
// src/queries/contacts.js
import { defineQuery, useQuery } from "@pinia/colada";
import { ref } from "vue";
import { searchContacts } from "@/api/contacts";

export const useContactSearch = defineQuery(() => {
	// Shared across all components using this query.
	const search = ref("");

	const { state, ...rest } = useQuery({
		key: () => ["contacts", { search: search.value }],
		query: () => searchContacts(search.value),
	});

	return { ...rest, contacts: state, search };
});
```

## refresh() vs refetch()

| Method | Behaviour |
|--------|-----------|
| `refresh()` | Reuses any in-flight request; skips if data is still fresh (`staleTime`). Prefer this. |
| `refetch()` | Always triggers a new network request regardless of cache state. |

Pass `true` when the caller handles failures with `try/catch`:

```js
await currentUser.refetch(true);
```

## State and status

| Property | Values | What it tells you |
|----------|--------|-------------------|
| `state.status` | `'pending'` → `'success'` \| `'error'` | Whether data has ever resolved |
| `asyncStatus` | `'idle'` \| `'loading'` | Whether a fetch is currently in progress |

These are separate. A query can have `state.status === 'success'` from earlier data and `asyncStatus === 'loading'` while refreshing.

## Active queries

A query is active while live Vue code uses it through `useQuery()` or a wrapper. Invalidating an active query refetches it; invalidating an inactive one marks it stale for next use.

## Folder structure

```
src/
├── api/          # Raw fetch functions — no cache keys, no query logic
│   └── contacts.js
└── queries/      # Feature folders: keys + options + wrappers
    └── contacts/
        ├── index.js
        ├── list.js
        └── update.js
```

State management responsibilities:
- **Pinia stores** — UI state, user preferences, app-wide flags
- **Pinia Colada** — server data: fetching, caching, revalidation
- **Plain composables** — local shared state that doesn't need caching

## Advanced topics

- **[references/advanced-patterns.md](references/advanced-patterns.md)** — optimistic updates, infinite queries, paginated queries, query cancellation, SSR, Nuxt
- **[references/plugins.md](references/plugins.md)** — retry, delay, auto-refetch, cache persistence, query hooks, custom plugins
- **[references/query-cache.md](references/query-cache.md)** — direct cache access, `invalidateQueries` variants, mutation cache
