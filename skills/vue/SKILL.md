---
name: vue
description: >
  Use this skill when working with .vue files, Vue components, composables, or Vue templates — even for small edits. Covers Vue 3 Composition API patterns, script setup, macro order, computed property organisation, component patterns, and component directory organisation. For project-specific stack choices (Bun, Vitest, Gitflow, @lewishowles/helpers, @lewishowles/components), see the vue-project-stack skill.
related-skills:
  - code-style
  - vue-project-stack
  - typescript
---

# Vue

## Formatting

- Tab HTML indentation
- Always self-close where possible (`<img />`, `<component />`)
- Prefer `v-bind="{ prop: value }"` for non-string bindings (booleans, numbers, expressions)—the object form reads more clearly, especially with multiple bindings
- Lowercase component names in templates
- Always two-word minimum component names per Vue best practices
- Max 5 attributes per line (single); 1 per line (multiline)
- Import groups: destructurable → non-destructurable → Components, blank line between
- Always wrap named slot content in an explicit `<template #name>` tag — never pass bare content to a named slot without a wrapper

## Macro order

- `defineProps` → `defineModel` → `defineEmits` → implementation → `defineExpose` (last)

## Props and computed properties

### Props

Every prop should have a JSDoc block explaining its purpose. Keep descriptions concise and user-focused:

```vue
const props = defineProps({
	/**
	 * The date to display, formatted as ISO 8601.
	 */
	date: {
		type: String,
		required: true,
	},

	/**
	 * The locale to use when formatting the date. If not provided, uses the user's locale.
	 */
	locale: {
		type: String,
		default: undefined,
	},
});
```

### Prop bindings

Prefer object `v-bind` over `:` shorthand for prop bindings, including when the variable name matches the prop name:

```vue
<!-- ✓ -->
<my-component v-bind="{ count }" />

<!-- ✗ -->
<my-component :count />

<!-- ✗ -->
<my-component :count="count" />
```

### Computed properties

- Non-simple computed: multiline with blank lines around
- Order: variables and single-line computed, then multi-line computed, then functions
- Keep related items together
- Every computed property gets a single-line comment explaining what it represents (following `code-style` baseline)

Example:

```vue
// Whether an error slot has been provided.
const haveError = computed(() => isNonEmptySlot(slots.error));

// The formatted date string, ready for display.
const displayDate = computed(() => {
	if (!isNonEmptyString(props.date)) {
		return null;
	}
	return new Date(props.date).toLocaleDateString(props.locale);
});
```

## Component patterns

- Extract shared logic into composables (`useInputId`, `useFormSupplementary`)
- Computed booleans for state/slot checks (`haveError`, `havePrefix`)
- Slot-driven composition with `isNonEmptySlot` guards

## provide / inject

- Key by the providing component's name so the origin is immediately clear at the inject site: `provide("dropdown-menu", { selectMenuItem })`
- Provide an object, not a bare value — this keeps all related functionality under one key and makes future additions additive rather than breaking
- At the inject site, destructure: `const { selectMenuItem } = inject("dropdown-menu", {})`; supply an empty object as the default so destructuring is always safe when the component is used outside its intended parent

## Component organisation

- `src/views/` — page views, organised by domain (e.g., categories/, settings/)
- `src/components/` — components organised by function/domain (layout/, form/, etc.)
- Fragment components: nested within parent directory, only used by that parent
- `src/composables/` — `use-*` composables, organised by feature
- Tests colocated: `component.test.js`, `component.cy.js`

## Component naming

- Lowercase kebab-case names (`form-input`, `data-table`)
- Always two words minimum — single-word names conflict with native HTML elements
- Name from general to specific — the most specific word goes last: `form-date-picker` not `date-picker-form`, `table-row-actions` not `actions-table-row`

## Conventions

- Named exports for composables and utilities — `export function useX` not `export default function useX`
- Named functions for component methods; arrow functions for inline handlers and callbacks only

## File-based routing

Vue Router's file-based routing generates routes from the `src/pages/` directory — the file path is the URL. Requires the Vue Router build plugin.

```
src/pages/
├── (home).vue              → /          group name keeps URL clean; also used for shared layouts
├── about.vue               → /about
├── [...path].vue           → catch-all for unmatched routes
├── users.edit.vue          → /users/edit  dot notation breaks out of the users/ layout
├── users.vue               → layout wrapping everything under /users/ (must contain <router-view />)
└── users/
    ├── (user-list).vue     → /users
    └── [userId].vue        → /users/:userId
```

Rules:
- Avoid `index.vue` — use route groups like `(home).vue` for meaningful names
- Name params explicitly: `[userId]` not `[id]`, `[postSlug]` not `[slug]`
- Optional params: `[[slug]].vue` matches with or without the segment
- Catch-all: `[...path].vue` matches any remaining path including slashes
- Dot notation: `users.edit.vue` produces `/users/edit` without nesting inside the `users.vue` layout
- `definePage()` inside a page component sets per-route `meta`, `name`, or `alias`

```vue
<!-- src/pages/users/[userId].vue -->
<script setup>
import { definePage } from "vue-router";

definePage({
	meta: { requiresAuth: true },
});
</script>
```

---

## Advanced patterns

### Fragment-based component composition

Break complex components into internal `/fragments/` subdirectory. Fragments not exported; used only by parent. Reduces re-render scope, keeps logic isolated.

**Pattern**: parent component → child fragments (via slots, not props)

```vue
<!-- src/components/form/form-field/form-field.vue -->
<script setup>
import { useSlots } from "vue";
import { isNonEmptySlot } from "@lewishowles/components";

const slots = useSlots();
const haveError = isNonEmptySlot(slots.error);
const haveHelp = isNonEmptySlot(slots.help);
</script>

<template>
	<div class="form-field">
		<form-label />
		<form-wrapper>
			<slot />
			<form-prefix v-if="havePrefix" />
			<form-suffix v-if="haveSuffix" />
		</form-wrapper>
		<form-error v-if="haveError"><slot name="error" /></form-error>
		<form-help v-if="haveHelp"><slot name="help" /></form-help>
	</div>
</template>
```

**Benefits**: fragments driven by slots → cleaner composition, easier refactoring.

**Slot checking**: use `useSlots()` + boolean computed/const to detect available slots.

### Composables as global state + API wrapper

For smaller apps (without Pinia), composables expose module-scope refs persisting across component mounts. Multiple components share same instance.

**Pattern**: composable defines module-level ref, exports accessor functions and reactive computed.

```typescript
// src/composables/use-film-finder.js
import { ref, computed } from "vue";
import { useApi } from "./use-api";

// Module-level state — shared across all component instances
const data = ref(null);
const selectedIds = ref([]);

const { get, isLoading } = useApi();

export function useFilmFinder() {
	async function findFilms(query) {
		data.value = await get(`/api/films?q=${query}`);
		selectedIds.value = [];
	}

	const availableFilms = computed(() =>
		data.value ? data.value.filter(film => film.available) : []
	);

	const selectedFilms = computed(() =>
		selectedIds.value.map(id => data.value.find(film => film.id === id))
	);

	return {
		data,
		isLoading,
		findFilms,
		availableFilms,
		selectedFilms,
		selectedIds,
	};
}
```

**Used in component**:

```vue
<script setup>
const { availableFilms, selectedFilms, findFilms } = useFilmFinder();
</script>

<template>
	<div>
		<input @change="findFilms($event.target.value)" />
		<ul>
			<li v-for="film in availableFilms" :key="film.id">
				{{ film.title }}
			</li>
		</ul>
	</div>
</template>
```

**Trade-off**: simpler than Pinia for small apps, but loses Pinia's devtools + time-travel debugging.

### Complex computed chains (filtering pipelines)

Build filtering/transformation pipelines where each computed depends on previous. All cached, all reactive.

**Pattern**: raw data → filtered → selected → transformed → results

```typescript
// src/composables/use-film-set-calculator.js
import { computed } from 'vue';
import { useFilmFinder } from './use-film-finder';

export function useFilmSetCalculator() {
	const { selectedFilms, data } = useFilmFinder();

	// Pipeline: selectedFilms → screenings → validScreenings → filmSets
	const filmScreenings = computed(() =>
		selectedFilms.value
			.flatMap(film => film.screenings || [])
			.filter(screening => screening.type === 'cinema')
	);

	const validScreenings = computed(() =>
		filmScreenings.value.filter(s => !isPastScreening(s))
	);

	const filmSets = computed(() => {
		const combinations = [];
		for (const first of validScreenings.value) {
			for (const second of validScreenings.value) {
				if (
					first.filmId !== second.filmId &&
					isTimeGapAcceptable(first, second)
				) {
					combinations.push({
						first,
						second,
						gap: calculateGap(first, second),
					});
				}
			}
		}
		return combinations.sort((a, b) => a.gap - b.gap);
	});

	return {
		validScreenings,
		filmSets,
	};
}
```

**Key**: each computed builds on previous. Vue caches aggressively — no re-computation unless dependency changes.

### Reusable template pattern (VueUse)

Use `createReusableTemplate` from `@vueuse/core` for define-once, render-many patterns. Useful for complex dynamic rendering (e.g., notification templates).

```vue
<script setup>
import { createReusableTemplate } from '@vueuse/core';

const [DefineTemplate, ReuseTemplate] = createReusableTemplate();
</script>

<template>
	<DefineTemplate v-slot="{ data, action }">
		<div class="notification" :class="`notification--${data.type}`">
			<p>{{ data.message }}</p>
			<button @click="action">{{ data.actionLabel }}</button>
		</div>
	</DefineTemplate>

	<div class="notifications-container">
		<ReuseTemplate :data="successNotification" :action="dismissSuccess" />
		<ReuseTemplate :data="errorNotification" :action="dismissError" />
		<ReuseTemplate :data="warningNotification" :action="dismissWarning" />
	</div>
</template>
```

**Trade-off**: cleaner than three separate components, but less obvious than slot-based composition. Use sparingly.

### Dynamic slot names

Use template literals in `#[...]` syntax for computed slot names. Useful for flexible column configs or dynamic field rendering.

```vue
<script setup>
import { computed } from 'vue';

const columns = [
	{ key: 'title', label: 'Film Title' },
	{ key: 'year', label: 'Year Released' },
];

const displayOptions = computed(() =>
	columns.reduce((acc, col) => ({ ...acc, [col.key]: true }), {})
);
</script>

<template>
	<table>
		<thead>
			<tr>
				<th v-for="col in columns" :key="col.key">
					{{ col.label }}
				</th>
			</tr>
		</thead>
		<tbody>
			<tr v-for="row in rows" :key="row.id">
				<td v-for="col in columns" :key="col.key">
					<!-- Dynamic slot name based on column key -->
					<slot :name="`column-${col.key}`" :value="row[col.key]">
						{{ row[col.key] }}
					</slot>
				</td>
			</tr>
		</tbody>
	</table>
</template>

<!-- Usage -->
<data-table :rows="films" :columns="columns">
	<template #[`column-title`]="{ value }">
		<strong>{{ value }}</strong>
	</template>
	<template #[`column-year`]="{ value }">
		{{ new Date(value).getFullYear() }}
	</template>
</data-table>
```

### Skeleton loaders

Build domain-specific skeleton components (e.g., `user-list-skeleton`, `product-card-skeleton`) composing `loading-skeleton` (wrapper) and `loading-skeleton-indicator` (individual "bones") from `@lewishowles/components`. Use `v-show` (not `v-if`) to preserve animation state. Size bones to match template being loaded.

**Domain-specific skeleton** (user-list-skeleton.vue):

```vue
<script setup>
const skeletonCount = 5;
</script>

<template>
	<div class="space-y-2" data-test="user-list-skeleton">
		<loading-skeleton v-for="i in skeletonCount" :key="i" data-test="user-list-skeleton.item">
			<loading-skeleton-indicator class="mb-2 h-4 w-2/3" data-test="user-list-skeleton.item.name" />
			<loading-skeleton-indicator class="h-3 w-1/2" data-test="user-list-skeleton.item.email" />
		</loading-skeleton>
	</div>
</template>
```

**Usage**:

```vue
<script setup>
import { ref } from 'vue';
import { useApi } from '@/composables/use-api';

const users = ref(null);
const { get, isLoading } = useApi();

onMounted(async () => {
	users.value = await get('/api/users');
});
</script>

<template>
	<div>
		<user-list-skeleton v-show="isLoading" />
		<headline-users v-show="!isLoading" :users="users" />
	</div>
</template>
```

**Key**: `v-show` keeps DOM mounted (preserves animations), `v-if` destroys/recreates (breaks transitions). Add `data-test` namespaced attributes so e2e tests can target specific skeletons.

### Pinia setup store (Composition API)

Use `defineStore` with setup function (not Options API). Simpler syntax, native composition API.

```typescript
// src/stores/security.js
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

export const useSecurityStore = defineStore('security', () => {
	const status = ref('unknown');
	const lastUpdated = ref(null);

	const isSecure = computed(() => status.value === 'secure');

	async function updateStatus() {
		const result = await fetch('/api/security/status');
		const data = await result.json();

		status.value = data.status;
		lastUpdated.value = new Date();
	}

	return {
		status,
		isSecure,
		lastUpdated,
		updateStatus,
	};
});
```

**Usage**:

```vue
<script setup>
import { useSecurityStore } from '@/stores/security';

const security = useSecurityStore();

onMounted(() => security.updateStatus());
</script>

<template>
	<div :class="{ secure: security.isSecure }">
		Status: {{ security.status }}
		<p>Last updated: {{ security.lastUpdated }}</p>
		<button @click="security.updateStatus">Refresh</button>
	</div>
</template>
```

**vs module-level refs**: Pinia offers devtools, time-travel debugging, type-safe mutations. Use for complex state; module refs for simple shared data.

### keep-alive (cache component state)

Cache component instance when hidden (e.g., tabs, routes). Preserves state, skips re-run of `onMounted`.

```vue
<script setup>
import { ref } from 'vue';

const activeTab = ref('films');
</script>

<template>
	<div>
		<div class="tabs">
			<button
				@click="activeTab = 'films'"
				:class="{ active: activeTab === 'films' }"
			>
				Films
			</button>
			<button
				@click="activeTab = 'settings'"
				:class="{ active: activeTab === 'settings' }"
			>
				Settings
			</button>
		</div>

		<keep-alive>
			<film-list v-if="activeTab === 'films'" />
			<watch-settings v-else-if="activeTab === 'settings'" />
		</keep-alive>
	</div>
</template>
```

**Without keep-alive**: switching tabs unmounts film-list, losing scroll position and form state. With keep-alive: state preserved.

**With include/exclude**:

```vue
<keep-alive :include="['film-list', 'watch-settings']" :exclude="['search-form']">
	<component :is="currentComponent" />
</keep-alive>
```

### Suspense (async component boundaries)

Boundary for async setup or data loading. Shows fallback UI while child loads; renders child when ready. Works well with skeleton loaders — put skeleton in `#fallback` slot.

```vue
<script setup>
import { defineAsyncComponent } from 'vue';
import { LoadingSkeleton } from '@lewishowles/components';

const FilmDetails = defineAsyncComponent(
	() => import('./film-details.vue')
);
</script>

<template>
	<Suspense>
		<template #default>
			<film-details :id="filmId" />
		</template>

		<template #fallback>
			<loading-skeleton />
		</template>
	</Suspense>
</template>
```

**In child component** (film-details.vue):

```vue
<script setup>
const { data } = await fetch(`/api/films/${props.id}`).then(r => r.json());
</script>

<template>
	<div>{{ data.title }}</div>
</template>
```

**Suspense + skeletons**: Suspense handles multiple async children together, coordinates loading state. Use skeleton loaders (from component library) as fallback. Simpler for async setup when data is critical to rendering.

### Teleport (render outside hierarchy)

Render component to different DOM location. Useful for modals, tooltips, popovers (keep in component tree, render elsewhere).

```vue
<script setup>
const showModal = ref(false);
</script>

<template>
	<button @click="showModal = true">Open Dialog</button>

	<!-- Renders into #modal-portal, not here -->
	<teleport to="#modal-portal">
		<base-modal v-if="showModal" @close="showModal = false">
			<p>This is rendered in the portal.</p>
		</base-modal>
	</teleport>
</template>
```

**In main HTML**:

```html
<body>
	<div id="app"></div>
	<div id="modal-portal"></div>
</body>
```

**Benefits**: modal doesn't inherit parent's CSS constraints (z-index, overflow); stays in logical component tree (for events/props). Accessibility: use `role="dialog"` + `aria-modal="true"` on teleported modal and mark main app `aria-hidden="true"` while modal open, so screen readers skip inert content.

### v-memo (skip expensive re-renders)

Skip re-render if dependency array unchanged. Use only when re-render is known expensive (complex template, large list).

```vue
<script setup>
import { ref, computed } from 'vue';

const items = ref([...]);
const filter = ref('');

const filtered = computed(() =>
	items.value.filter(i => i.name.includes(filter.value))
);
</script>

<template>
	<div>
		<input v-model="filter" placeholder="Filter..." />

		<!-- Only re-render if filtered array changes -->
		<div v-memo="[filtered]">
			<expensive-list-item
				v-for="item in filtered"
				:key="item.id"
				:item="item"
			/>
		</div>
	</div>
</template>
```

**Without v-memo**: list re-renders even if parent state changes but filtered array identical. With v-memo: skips render if filtered array reference unchanged.

**Caveat**: premature optimization. Use only if profiler shows re-render is bottleneck. Vue's reactivity fast; avoid `v-memo` unless needed.

### watch and watchEffect (alternative patterns)

`computed` preferred for derived state. `watch` and `watchEffect` handle side effects and conditional reactions.

**Always comment why the watch is needed.** Following `code-style` baseline, add a single-line comment explaining the purpose before the watch declaration. Explain why this side effect matters, not what the watch does:

```typescript
// Fetch film details whenever the user selects a different film.
watch(
	() => filmId.value,
	async (newId) => {
		// ...
	}
);
```

**watch** — explicit dependencies, triggers when they change:

```typescript
import { ref, watch } from 'vue';

const filmId = ref(null);
const filmData = ref(null);

watch(
	() => filmId.value,
	async (newId) => {
		if (newId) {
			filmData.value = await fetch(`/api/films/${newId}`).then(r =>
				r.json()
			);
		}
	}
);
```

**watchEffect** — auto-tracks dependencies inside effect:

```typescript
import { ref, watchEffect } from 'vue';

const filmId = ref(null);
const filmData = ref(null);

watchEffect(async () => {
	if (filmId.value) {
		filmData.value = await fetch(
			`/api/films/${filmId.value}`
		).then(r => r.json());
	}
});
```

**Prefer computed when possible** — caches results, skips re-run if dependencies unchanged. Use watch/watchEffect only for:
- Side effects (API calls, analytics, DOM manipulation)
- Reactions that don't compute values (logging, validation)
- Conditional reactions (only run if X is true)

**Common mistake**: using watch to compute derived state. Use computed instead — cached and reactive.
