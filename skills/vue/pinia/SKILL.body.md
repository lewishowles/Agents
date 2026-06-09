# Pinia

Pinia is for app state: UI state, user preferences, cross-page flags, and client-owned data. Use Pinia Colada for server state.

## Store shape

- Prefer setup stores for stores with composables, watchers, or non-trivial logic
- Keep option stores where the project already uses them consistently
- Use one store per domain, not one store per component
- Keep derived state in getters/computed values, not duplicated state
- Keep actions as named functions; actions can be destructured safely

```typescript
import { computed, ref } from "vue";
import { defineStore } from "pinia";

export const usePreferencesStore = defineStore("preferences", () => {
	// The currently selected colour mode.
	const colourMode = ref("system");

	// Whether the current interface should render in dark mode.
	const isDark = computed(() => colourMode.value === "dark");

	function setColourMode(value) {
		colourMode.value = value;
	}

	return { colourMode, isDark, setColourMode };
});
```

## Usage in components

- Use `storeToRefs()` when destructuring state or getters
- Destructure actions directly from the store
- Avoid mutating store state from unrelated components when an action would name the behaviour clearly

```typescript
import { storeToRefs } from "pinia";
import { usePreferencesStore } from "@/stores/preferences";

const preferencesStore = usePreferencesStore();
const { colourMode, isDark } = storeToRefs(preferencesStore);
const { setColourMode } = preferencesStore;
```

## VueUse in stores

- VueUse composables are appropriate inside setup stores when they model client state directly: storage, breakpoints, online state, dark mode, media queries
- Guard browser-only behaviour in SSR contexts where the project renders on the server
- Prefer VueUse storage composables over hand-written `localStorage` watchers

## SSR and lifecycle

- In SSR-capable apps, call `useStore()` inside setup, actions, middleware, or functions with the active app context
- Avoid module-scope `useStore()` calls in files that can run before Pinia is installed
- Clean up watchers or subscriptions created outside component scope

## HMR

Add HMR handling when editing stores in Vite projects:

```typescript
if (import.meta.hot) {
	import.meta.hot.accept(acceptHMRUpdate(usePreferencesStore, import.meta.hot));
}
```

## Testing

- Configure a fresh Pinia instance for each test
- Use `@pinia/testing` for component tests that need store behaviour but not real action side effects
- Test store actions and derived state directly when they contain meaningful logic
- Keep server cache behaviour in Pinia Colada tests, not Pinia tests
