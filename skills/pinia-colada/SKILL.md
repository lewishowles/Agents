---
name: pinia-colada
description: >
  Use this skill when working with @pinia/colada for async data fetching and server state in Vue projects.
  TRIGGER when: code imports from `@pinia/colada`, uses `useQuery`, `useMutation`, `defineQuery`,
  `defineMutation`, `useQueryCache`, or `invalidateQueries`; when setting up async data fetching
  in a Vue project; when working in `src/queries/` or `src/mutations/` directories.
---

# Pinia Colada

Pinia Colada manages server state in Vue apps — caching, deduplication, background revalidation, and mutation coordination. It sits above your fetch layer; you still write the functions that call your API, Pinia Colada handles everything else.

## Setup

```bash
bun add @pinia/colada
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

## Key factories

Centralise cache keys in the query file. Reusing parent keys creates a hierarchy — invalidating a parent key invalidates all its children.

```js
// src/queries/contacts.js
export const CONTACT_KEYS = {
	root: ["contacts"],
	byId: (id) => [...CONTACT_KEYS.root, id],
	byIdWithNotes: (id) => [...CONTACT_KEYS.byId(id), { notes: true }],
};
```

Invalidating `CONTACT_KEYS.root` invalidates every contacts query. Invalidating `CONTACT_KEYS.byId(id)` invalidates that contact and its notes.

## defineQueryOptions

Combine a key factory with a query function into a reusable definition. Pass it to `useQuery` directly rather than inlining keys.

**Static** (no parameters):

```js
import { defineQueryOptions } from "@pinia/colada";
import { getContacts } from "@/api/contacts";

export const contactListQuery = defineQueryOptions({
	key: CONTACT_KEYS.root,
	query: () => getContacts(),
});
```

**Dynamic** (with parameters):

```js
import { getContactById } from "@/api/contacts";

export const contactByIdQuery = defineQueryOptions((id) => ({
	key: CONTACT_KEYS.byId(id),
	query: () => getContactById(id),
}));
```

## useQuery

Pass dynamic options as a getter function so Vue tracks reactivity correctly.

```vue
<script setup>
import { useQuery } from "@pinia/colada";
import { useRoute } from "vue-router";
import { contactByIdQuery } from "@/queries/contacts";

const route = useRoute();

// Getter function — re-evaluates reactively when route.params changes.
const { state, asyncStatus } = useQuery(() => contactByIdQuery(route.params.contactId));
</script>

<template>
	<div v-if="asyncStatus === 'loading'">Loading…</div>
	<div v-else-if="state.status === 'error'">{{ state.error.message }}</div>
	<div v-else-if="state.data">{{ state.data.name }}</div>
</template>
```

Use `state` (not destructured `data`/`error`) for status checks — it narrows types correctly in conditionals.

### Pausing a query

Use `enabled` to prevent a query running until required data is available.

```js
const selectedId = ref(null);

useQuery({
	key: () => ["contacts", selectedId.value],
	query: () => getContactById(selectedId.value),
	enabled: () => selectedId.value != null,
});
```

### Spreading extra options

Override individual options per usage without redefining the whole query.

```js
useQuery(() => ({
	...contactByIdQuery(route.params.contactId),
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

## defineMutation

Reusable mutation definitions, optionally with shared state.

```js
// src/mutations/contacts.js
import { defineMutation, useMutation, useQueryCache } from "@pinia/colada";
import { CONTACT_KEYS } from "@/queries/contacts";
import { deleteContact } from "@/api/contacts";

export const useDeleteContact = defineMutation(() => {
	const queryCache = useQueryCache();

	return useMutation({
		mutation: (id) => deleteContact(id),
		onSettled(_data, _error, id) {
			queryCache.invalidateQueries({ key: CONTACT_KEYS.byId(id) });
			queryCache.invalidateQueries({ key: CONTACT_KEYS.root, exact: true });
		},
	});
});
```

## defineQuery

Shares reactive state (a search ref, filters, etc.) across components using the same query. Without `defineQuery`, each component gets its own copy of any refs defined inside.

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

## State and status

| Property | Values | What it tells you |
|----------|--------|-------------------|
| `state.status` | `'pending'` → `'success'` \| `'error'` | Whether data has ever resolved |
| `asyncStatus` | `'idle'` \| `'loading'` | Whether a fetch is currently in progress |

These are intentionally separate. A query can have `state.status === 'success'` (data loaded before) and `asyncStatus === 'loading'` (currently refreshing in background).

## Folder structure

```
src/
├── api/          # Raw fetch functions — no cache keys, no query logic
│   └── contacts.js
├── queries/      # Key factories + defineQueryOptions + defineQuery
│   └── contacts.js
└── mutations/    # defineMutation definitions
    └── contacts.js
```

State management responsibilities:
- **Pinia stores** — UI state, user preferences, app-wide flags
- **Pinia Colada** — server data: fetching, caching, revalidation
- **Plain composables** — local shared state that doesn't need caching

## Advanced topics

- **[references/advanced-patterns.md](references/advanced-patterns.md)** — optimistic updates, infinite queries, paginated queries, query cancellation, SSR, Nuxt
- **[references/plugins.md](references/plugins.md)** — retry, delay, auto-refetch, cache persistence, query hooks, custom plugins
- **[references/query-cache.md](references/query-cache.md)** — direct cache access, `invalidateQueries` variants, mutation cache
