# VueUse function index

Full composable listing by category. Read this file when searching for a composable that might cover a requirement.

`Invocation` values:

- `AUTO` — use when applicable
- `EXTERNAL` — use only if the dependency already exists; ask to install when needed
- `EXPLICIT_ONLY` — use only when the user explicitly asks for it

## State

| Function                                                         | Description                                                                                      | Invocation |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ---------- |
| [`createGlobalState`](references/createGlobalState.md)           | Keep states in the global scope to be reusable across Vue instances                              | AUTO       |
| [`createInjectionState`](references/createInjectionState.md)     | Create global state that can be injected into components                                         | AUTO       |
| [`createSharedComposable`](references/createSharedComposable.md) | Make a composable function usable with multiple Vue instances                                    | AUTO       |
| [`injectLocal`](references/injectLocal.md)                       | Extended `inject` with ability to call `provideLocal` to provide the value in the same component | AUTO       |
| [`provideLocal`](references/provideLocal.md)                     | Extended `provide` with ability to call `injectLocal` to obtain the value in the same component  | AUTO       |
| [`useAsyncState`](references/useAsyncState.md)                   | Reactive async state                                                                             | AUTO       |
| [`useDebouncedRefHistory`](references/useDebouncedRefHistory.md) | Shorthand for `useRefHistory` with debounced filter                                              | AUTO       |
| [`useLastChanged`](references/useLastChanged.md)                 | Records the timestamp of the last change                                                         | AUTO       |
| [`useLocalStorage`](references/useLocalStorage.md)               | Reactive LocalStorage                                                                            | AUTO       |
| [`useManualRefHistory`](references/useManualRefHistory.md)       | Manually track the change history of a ref when the user calls `commit()`                        | AUTO       |
| [`useRefHistory`](references/useRefHistory.md)                   | Track the change history of a ref                                                                | AUTO       |
| [`useSessionStorage`](references/useSessionStorage.md)           | Reactive SessionStorage                                                                          | AUTO       |
| [`useStorage`](references/useStorage.md)                         | Reactive LocalStorage or SessionStorage ref                                                      | AUTO       |
| [`useStorageAsync`](references/useStorageAsync.md)               | Reactive Storage with async support                                                              | AUTO       |
| [`useThrottledRefHistory`](references/useThrottledRefHistory.md) | Shorthand for `useRefHistory` with throttled filter                                              | AUTO       |

## Elements

| Function                                                           | Description                                                                    | Invocation |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------ | ---------- |
| [`useActiveElement`](references/useActiveElement.md)               | Reactive `document.activeElement`                                              | AUTO       |
| [`useDocumentVisibility`](references/useDocumentVisibility.md)     | Reactively track `document.visibilityState`                                    | AUTO       |
| [`useDraggable`](references/useDraggable.md)                       | Make elements draggable                                                        | AUTO       |
| [`useDropZone`](references/useDropZone.md)                         | Create a zone where files can be dropped                                       | AUTO       |
| [`useElementBounding`](references/useElementBounding.md)           | Reactive bounding box of an HTML element                                       | AUTO       |
| [`useElementSize`](references/useElementSize.md)                   | Reactive size of an HTML element                                               | AUTO       |
| [`useElementVisibility`](references/useElementVisibility.md)       | Tracks the visibility of an element within the viewport                        | AUTO       |
| [`useIntersectionObserver`](references/useIntersectionObserver.md) | Detects changes to a target element's visibility                               | AUTO       |
| [`useMouseInElement`](references/useMouseInElement.md)             | Reactive mouse position related to an element                                  | AUTO       |
| [`useMutationObserver`](references/useMutationObserver.md)         | Watch for changes being made to the DOM tree                                   | AUTO       |
| [`useParentElement`](references/useParentElement.md)               | Get parent element of the given element                                        | AUTO       |
| [`useResizeObserver`](references/useResizeObserver.md)             | Reports changes to the dimensions of an element's content or border-box        | AUTO       |
| [`useWindowFocus`](references/useWindowFocus.md)                   | Reactively track window focus with `window.onfocus` and `window.onblur` events | AUTO       |
| [`useWindowScroll`](references/useWindowScroll.md)                 | Reactive window scroll                                                         | AUTO       |
| [`useWindowSize`](references/useWindowSize.md)                     | Reactive window size                                                           | AUTO       |

## Browser

| Function                                                                           | Description                                                             | Invocation |
| ---------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | ---------- |
| [`useBluetooth`](references/useBluetooth.md)                                       | Reactive Web Bluetooth API                                              | AUTO       |
| [`useBreakpoints`](references/useBreakpoints.md)                                   | Reactive viewport breakpoints                                           | AUTO       |
| [`useBroadcastChannel`](references/useBroadcastChannel.md)                         | Reactive BroadcastChannel API                                           | AUTO       |
| [`useBrowserLocation`](references/useBrowserLocation.md)                           | Reactive browser location                                               | AUTO       |
| [`useClipboard`](references/useClipboard.md)                                       | Reactive Clipboard API                                                  | AUTO       |
| [`useClipboardItems`](references/useClipboardItems.md)                             | Reactive Clipboard API                                                  | AUTO       |
| [`useColorMode`](references/useColorMode.md)                                       | Reactive colour mode (dark / light / custom) with auto data persistence | AUTO       |
| [`useCssSupports`](references/useCssSupports.md)                                   | SSR-compatible reactive `CSS.supports`                                  | AUTO       |
| [`useCssVar`](references/useCssVar.md)                                             | Manipulate CSS variables                                                | AUTO       |
| [`useDark`](references/useDark.md)                                                 | Reactive dark mode with auto data persistence                           | AUTO       |
| [`useEventListener`](references/useEventListener.md)                               | Use EventListener with ease                                             | AUTO       |
| [`useEyeDropper`](references/useEyeDropper.md)                                     | Reactive EyeDropper API                                                 | AUTO       |
| [`useFavicon`](references/useFavicon.md)                                           | Reactive favicon                                                        | AUTO       |
| [`useFileDialog`](references/useFileDialog.md)                                     | Open file dialog with ease                                              | AUTO       |
| [`useFileSystemAccess`](references/useFileSystemAccess.md)                         | Create, read, and write local files with File System Access API         | AUTO       |
| [`useFullscreen`](references/useFullscreen.md)                                     | Reactive Fullscreen API                                                 | AUTO       |
| [`useGamepad`](references/useGamepad.md)                                           | Reactive bindings for the Gamepad API                                   | AUTO       |
| [`useImage`](references/useImage.md)                                               | Reactive image loading in the browser                                   | AUTO       |
| [`useMediaControls`](references/useMediaControls.md)                               | Reactive media controls for `audio` and `video` elements                | AUTO       |
| [`useMediaQuery`](references/useMediaQuery.md)                                     | Reactive Media Query                                                    | AUTO       |
| [`useMemory`](references/useMemory.md)                                             | Reactive Memory Info                                                    | AUTO       |
| [`useObjectUrl`](references/useObjectUrl.md)                                       | Reactive URL representing an object                                     | AUTO       |
| [`usePerformanceObserver`](references/usePerformanceObserver.md)                   | Observe performance metrics                                             | AUTO       |
| [`usePermission`](references/usePermission.md)                                     | Reactive Permissions API                                                | AUTO       |
| [`usePreferredColorScheme`](references/usePreferredColorScheme.md)                 | Reactive `prefers-color-scheme` media query                             | AUTO       |
| [`usePreferredContrast`](references/usePreferredContrast.md)                       | Reactive `prefers-contrast` media query                                 | AUTO       |
| [`usePreferredDark`](references/usePreferredDark.md)                               | Reactive dark theme preference                                          | AUTO       |
| [`usePreferredLanguages`](references/usePreferredLanguages.md)                     | Reactive Navigator Languages                                            | AUTO       |
| [`usePreferredReducedMotion`](references/usePreferredReducedMotion.md)             | Reactive `prefers-reduced-motion` media query                           | AUTO       |
| [`usePreferredReducedTransparency`](references/usePreferredReducedTransparency.md) | Reactive `prefers-reduced-transparency` media query                     | AUTO       |
| [`useScreenOrientation`](references/useScreenOrientation.md)                       | Reactive Screen Orientation API                                         | AUTO       |
| [`useScreenSafeArea`](references/useScreenSafeArea.md)                             | Reactive `env(safe-area-inset-*)`                                       | AUTO       |
| [`useScriptTag`](references/useScriptTag.md)                                       | Creates a script tag                                                    | AUTO       |
| [`useShare`](references/useShare.md)                                               | Reactive Web Share API                                                  | AUTO       |
| [`useSSRWidth`](references/useSSRWidth.md)                                         | Global viewport width for SSR components                                | AUTO       |
| [`useStyleTag`](references/useStyleTag.md)                                         | Inject a reactive `style` element in head                               | AUTO       |
| [`useTextareaAutosize`](references/useTextareaAutosize.md)                         | Automatically update the height of a textarea to fit its content        | AUTO       |
| [`useTextDirection`](references/useTextDirection.md)                               | Reactive `dir` of an element's text                                     | AUTO       |
| [`useTitle`](references/useTitle.md)                                               | Reactive document title                                                 | AUTO       |
| [`useUrlSearchParams`](references/useUrlSearchParams.md)                           | Reactive URLSearchParams                                                | AUTO       |
| [`useVibrate`](references/useVibrate.md)                                           | Reactive Vibration API                                                  | AUTO       |
| [`useWakeLock`](references/useWakeLock.md)                                         | Reactive Screen Wake Lock API                                           | AUTO       |
| [`useWebNotification`](references/useWebNotification.md)                           | Reactive Notification                                                   | AUTO       |
| [`useWebWorker`](references/useWebWorker.md)                                       | Simple Web Workers registration and communication                       | AUTO       |
| [`useWebWorkerFn`](references/useWebWorkerFn.md)                                   | Run expensive functions without blocking the UI                         | AUTO       |

## Sensors

| Function                                                     | Description                                                                 | Invocation |
| ------------------------------------------------------------ | --------------------------------------------------------------------------- | ---------- |
| [`onClickOutside`](references/onClickOutside.md)             | Listen for clicks outside of an element                                     | AUTO       |
| [`onElementRemoval`](references/onElementRemoval.md)         | Fires when an element or any ancestor is removed from the DOM               | AUTO       |
| [`onKeyStroke`](references/onKeyStroke.md)                   | Listen for keyboard keystrokes                                              | AUTO       |
| [`onLongPress`](references/onLongPress.md)                   | Listen for a long press on an element                                       | AUTO       |
| [`onStartTyping`](references/onStartTyping.md)               | Fires when users start typing on non-editable elements                      | AUTO       |
| [`useBattery`](references/useBattery.md)                     | Reactive Battery Status API                                                 | AUTO       |
| [`useDeviceMotion`](references/useDeviceMotion.md)           | Reactive DeviceMotionEvent                                                  | AUTO       |
| [`useDeviceOrientation`](references/useDeviceOrientation.md) | Reactive DeviceOrientationEvent                                             | AUTO       |
| [`useDevicePixelRatio`](references/useDevicePixelRatio.md)   | Reactively track `window.devicePixelRatio`                                  | AUTO       |
| [`useDevicesList`](references/useDevicesList.md)             | Reactive `enumerateDevices` listing available input/output devices          | AUTO       |
| [`useDisplayMedia`](references/useDisplayMedia.md)           | Reactive `mediaDevices.getDisplayMedia` streaming                           | AUTO       |
| [`useElementByPoint`](references/useElementByPoint.md)       | Reactive element by point                                                   | AUTO       |
| [`useElementHover`](references/useElementHover.md)           | Reactive element hover state                                                | AUTO       |
| [`useFocus`](references/useFocus.md)                         | Reactive utility to track or set the focus state of a DOM element           | AUTO       |
| [`useFocusWithin`](references/useFocusWithin.md)             | Reactive utility to track if an element or one of its descendants has focus | AUTO       |
| [`useFps`](references/useFps.md)                             | Reactive FPS (frames per second)                                            | AUTO       |
| [`useGeolocation`](references/useGeolocation.md)             | Reactive Geolocation API                                                    | AUTO       |
| [`useIdle`](references/useIdle.md)                           | Tracks whether the user is inactive                                         | AUTO       |
| [`useInfiniteScroll`](references/useInfiniteScroll.md)       | Infinite scrolling of the element                                           | AUTO       |
| [`useKeyModifier`](references/useKeyModifier.md)             | Reactive Modifier State                                                     | AUTO       |
| [`useMagicKeys`](references/useMagicKeys.md)                 | Reactive keys pressed state                                                 | AUTO       |
| [`useMouse`](references/useMouse.md)                         | Reactive mouse position                                                     | AUTO       |
| [`useMousePressed`](references/useMousePressed.md)           | Reactive mouse pressing state                                               | AUTO       |
| [`useNavigatorLanguage`](references/useNavigatorLanguage.md) | Reactive `navigator.language`                                               | AUTO       |
| [`useNetwork`](references/useNetwork.md)                     | Reactive Network status                                                     | AUTO       |
| [`useOnline`](references/useOnline.md)                       | Reactive online state                                                       | AUTO       |
| [`usePageLeave`](references/usePageLeave.md)                 | Reactive state for when the mouse leaves the page                           | AUTO       |
| [`useParallax`](references/useParallax.md)                   | Create parallax effects                                                     | AUTO       |
| [`usePointer`](references/usePointer.md)                     | Reactive pointer state                                                      | AUTO       |
| [`usePointerLock`](references/usePointerLock.md)             | Reactive pointer lock                                                       | AUTO       |
| [`usePointerSwipe`](references/usePointerSwipe.md)           | Reactive swipe detection based on PointerEvents                             | AUTO       |
| [`useScroll`](references/useScroll.md)                       | Reactive scroll position and state                                          | AUTO       |
| [`useScrollLock`](references/useScrollLock.md)               | Lock scrolling of the element                                               | AUTO       |
| [`useSpeechRecognition`](references/useSpeechRecognition.md) | Reactive SpeechRecognition                                                  | AUTO       |
| [`useSpeechSynthesis`](references/useSpeechSynthesis.md)     | Reactive SpeechSynthesis                                                    | AUTO       |
| [`useSwipe`](references/useSwipe.md)                         | Reactive swipe detection based on TouchEvents                               | AUTO       |
| [`useTextSelection`](references/useTextSelection.md)         | Reactively track user text selection                                        | AUTO       |
| [`useUserMedia`](references/useUserMedia.md)                 | Reactive `mediaDevices.getUserMedia` streaming                              | AUTO       |

## Network

| Function                                         | Description                                                        | Invocation |
| ------------------------------------------------ | ------------------------------------------------------------------ | ---------- |
| [`useEventSource`](references/useEventSource.md) | EventSource / Server-Sent Events with a persistent HTTP connection | AUTO       |
| [`useFetch`](references/useFetch.md)             | Reactive Fetch API with abort support                              | AUTO       |
| [`useWebSocket`](references/useWebSocket.md)     | Reactive WebSocket client                                          | AUTO       |

## Animation

| Function                                       | Description                                           | Invocation |
| ---------------------------------------------- | ----------------------------------------------------- | ---------- |
| [`useAnimate`](references/useAnimate.md)       | Reactive Web Animations API                           | AUTO       |
| [`useInterval`](references/useInterval.md)     | Reactive counter that increases on every interval     | AUTO       |
| [`useIntervalFn`](references/useIntervalFn.md) | Wrapper for `setInterval` with controls               | AUTO       |
| [`useNow`](references/useNow.md)               | Reactive current Date instance                        | AUTO       |
| [`useRafFn`](references/useRafFn.md)           | Call a function on every `requestAnimationFrame`      | AUTO       |
| [`useTimeout`](references/useTimeout.md)       | Reactive value that becomes `true` after a given time | AUTO       |
| [`useTimeoutFn`](references/useTimeoutFn.md)   | Wrapper for `setTimeout` with controls                | AUTO       |
| [`useTimestamp`](references/useTimestamp.md)   | Reactive current timestamp                            | AUTO       |
| [`useTransition`](references/useTransition.md) | Transition between values                             | AUTO       |

## Component

| Function                                                         | Description                                                                   | Invocation |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------- | ---------- |
| [`computedInject`](references/computedInject.md)                 | Combine `computed` and `inject`                                               | AUTO       |
| [`createReusableTemplate`](references/createReusableTemplate.md) | Define and reuse template inside the component scope                          | AUTO       |
| [`createTemplatePromise`](references/createTemplatePromise.md)   | Template as Promise                                                           | AUTO       |
| [`templateRef`](references/templateRef.md)                       | Shorthand for binding ref to template element                                 | AUTO       |
| [`tryOnBeforeMount`](references/tryOnBeforeMount.md)             | Safe `onBeforeMount`                                                          | AUTO       |
| [`tryOnBeforeUnmount`](references/tryOnBeforeUnmount.md)         | Safe `onBeforeUnmount`                                                        | AUTO       |
| [`tryOnMounted`](references/tryOnMounted.md)                     | Safe `onMounted`                                                              | AUTO       |
| [`tryOnScopeDispose`](references/tryOnScopeDispose.md)           | Safe `onScopeDispose`                                                         | AUTO       |
| [`tryOnUnmounted`](references/tryOnUnmounted.md)                 | Safe `onUnmounted`                                                            | AUTO       |
| [`unrefElement`](references/unrefElement.md)                     | Retrieve the underlying DOM element from a Vue ref or component instance      | AUTO       |
| [`useCurrentElement`](references/useCurrentElement.md)           | Get the DOM element of current component as a ref                             | AUTO       |
| [`useMounted`](references/useMounted.md)                         | Mounted state in ref                                                          | AUTO       |
| [`useTemplateRefsList`](references/useTemplateRefsList.md)       | Shorthand for binding refs to template elements and components inside `v-for` | AUTO       |
| [`useVirtualList`](references/useVirtualList.md)                 | Create virtual lists with ease                                                | AUTO       |
| [`useVModel`](references/useVModel.md)                           | Shorthand for v-model binding                                                 | AUTO       |
| [`useVModels`](references/useVModels.md)                         | Shorthand for props v-model binding                                           | AUTO       |

## Watch

| Function                                             | Description                                             | Invocation |
| ---------------------------------------------------- | ------------------------------------------------------- | ---------- |
| [`until`](references/until.md)                       | Promised one-time watch for changes                     | AUTO       |
| [`watchArray`](references/watchArray.md)             | Watch for an array with additions and removals          | AUTO       |
| [`watchAtMost`](references/watchAtMost.md)           | `watch` with a limit on how many times it triggers      | AUTO       |
| [`watchDebounced`](references/watchDebounced.md)     | Debounced watch                                         | AUTO       |
| [`watchDeep`](references/watchDeep.md)               | Shorthand for watching a value with `{deep: true}`      | AUTO       |
| [`watchIgnorable`](references/watchIgnorable.md)     | Ignorable watch                                         | AUTO       |
| [`watchImmediate`](references/watchImmediate.md)     | Shorthand for watching a value with `{immediate: true}` | AUTO       |
| [`watchOnce`](references/watchOnce.md)               | Shorthand for watching a value with `{ once: true }`    | AUTO       |
| [`watchPausable`](references/watchPausable.md)       | Pausable watch                                          | AUTO       |
| [`watchThrottled`](references/watchThrottled.md)     | Throttled watch                                         | AUTO       |
| [`watchTriggerable`](references/watchTriggerable.md) | Watch that can be triggered manually                    | AUTO       |
| [`watchWithFilter`](references/watchWithFilter.md)   | `watch` with additional EventFilter control             | AUTO       |
| [`whenever`](references/whenever.md)                 | Shorthand for watching a value to be truthy             | AUTO       |

## Reactivity

| Function                                                   | Description                                                       | Invocation    |
| ---------------------------------------------------------- | ----------------------------------------------------------------- | ------------- |
| [`computedAsync`](references/computedAsync.md)             | Computed for async functions                                      | AUTO          |
| [`computedEager`](references/computedEager.md)             | Eager computed without lazy evaluation                            | AUTO          |
| [`computedWithControl`](references/computedWithControl.md) | Explicitly define the dependencies of computed                    | AUTO          |
| [`createRef`](references/createRef.md)                     | Returns a `deepRef` or `shallowRef` depending on the `deep` param | AUTO          |
| [`extendRef`](references/extendRef.md)                     | Add extra attributes to Ref                                       | AUTO          |
| [`reactify`](references/reactify.md)                       | Converts plain functions into reactive functions                  | AUTO          |
| [`reactifyObject`](references/reactifyObject.md)           | Apply `reactify` to an object                                     | AUTO          |
| [`reactiveComputed`](references/reactiveComputed.md)       | Computed reactive object                                          | AUTO          |
| [`reactiveOmit`](references/reactiveOmit.md)               | Reactively omit fields from a reactive object                     | AUTO          |
| [`reactivePick`](references/reactivePick.md)               | Reactively pick fields from a reactive object                     | AUTO          |
| [`refAutoReset`](references/refAutoReset.md)               | A ref that resets to its default value after some time            | AUTO          |
| [`refDebounced`](references/refDebounced.md)               | Debounce execution of a ref value                                 | AUTO          |
| [`refDefault`](references/refDefault.md)                   | Apply a default value to a ref                                    | AUTO          |
| [`refManualReset`](references/refManualReset.md)           | Create a ref with manual reset functionality                      | AUTO          |
| [`refThrottled`](references/refThrottled.md)               | Throttle changing of a ref value                                  | AUTO          |
| [`refWithControl`](references/refWithControl.md)           | Fine-grained controls over ref and its reactivity                 | AUTO          |
| [`syncRef`](references/syncRef.md)                         | Two-way refs synchronisation                                      | AUTO          |
| [`syncRefs`](references/syncRefs.md)                       | Keep target refs in sync with a source ref                        | AUTO          |
| [`toReactive`](references/toReactive.md)                   | Converts ref to reactive                                          | AUTO          |
| [`toRef`](references/toRef.md)                             | Normalise value/ref/getter to `ref` or `computed`                 | EXPLICIT_ONLY |
| [`toRefs`](references/toRefs.md)                           | Extended `toRefs` that also accepts refs of an object             | AUTO          |

## Array

| Function                                                 | Description                            | Invocation |
| -------------------------------------------------------- | -------------------------------------- | ---------- |
| [`useArrayDifference`](references/useArrayDifference.md) | Reactive difference between two arrays | AUTO       |
| [`useArrayEvery`](references/useArrayEvery.md)           | Reactive `Array.every`                 | AUTO       |
| [`useArrayFilter`](references/useArrayFilter.md)         | Reactive `Array.filter`                | AUTO       |
| [`useArrayFind`](references/useArrayFind.md)             | Reactive `Array.find`                  | AUTO       |
| [`useArrayFindIndex`](references/useArrayFindIndex.md)   | Reactive `Array.findIndex`             | AUTO       |
| [`useArrayFindLast`](references/useArrayFindLast.md)     | Reactive `Array.findLast`              | AUTO       |
| [`useArrayIncludes`](references/useArrayIncludes.md)     | Reactive `Array.includes`              | AUTO       |
| [`useArrayJoin`](references/useArrayJoin.md)             | Reactive `Array.join`                  | AUTO       |
| [`useArrayMap`](references/useArrayMap.md)               | Reactive `Array.map`                   | AUTO       |
| [`useArrayReduce`](references/useArrayReduce.md)         | Reactive `Array.reduce`                | AUTO       |
| [`useArraySome`](references/useArraySome.md)             | Reactive `Array.some`                  | AUTO       |
| [`useArrayUnique`](references/useArrayUnique.md)         | Reactive unique array                  | AUTO       |
| [`useSorted`](references/useSorted.md)                   | Reactive sorted array                  | AUTO       |

## Time

| Function                                         | Description                         | Invocation |
| ------------------------------------------------ | ----------------------------------- | ---------- |
| [`useCountdown`](references/useCountdown.md)     | Reactive countdown timer in seconds | AUTO       |
| [`useDateFormat`](references/useDateFormat.md)   | Format dates with token strings     | AUTO       |
| [`useTimeAgo`](references/useTimeAgo.md)         | Reactive time ago                   | AUTO       |
| [`useTimeAgoIntl`](references/useTimeAgoIntl.md) | Reactive time ago with i18n support | AUTO       |

## Utilities

| Function                                                               | Description                                                          | Invocation    |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------- | ------------- |
| [`createDisposableDirective`](references/createDisposableDirective.md) | Utility for authoring disposable directives                          | AUTO          |
| [`createEventHook`](references/createEventHook.md)                     | Utility for creating event hooks                                     | AUTO          |
| [`createUnrefFn`](references/createUnrefFn.md)                         | Make a plain function accepting ref and raw values as arguments      | AUTO          |
| [`get`](references/get.md)                                             | Shorthand for accessing `ref.value`                                  | EXPLICIT_ONLY |
| [`isDefined`](references/isDefined.md)                                 | Non-nullish checking type guard for Ref                              | AUTO          |
| [`makeDestructurable`](references/makeDestructurable.md)               | Make a value destructurable as both object and array                 | AUTO          |
| [`set`](references/set.md)                                             | Shorthand for `ref.value = x`                                        | EXPLICIT_ONLY |
| [`useAsyncQueue`](references/useAsyncQueue.md)                         | Run async tasks sequentially, passing each result to the next        | AUTO          |
| [`useBase64`](references/useBase64.md)                                 | Reactive base64 transforming                                         | AUTO          |
| [`useCached`](references/useCached.md)                                 | Cache a ref with a custom comparator                                 | AUTO          |
| [`useCloned`](references/useCloned.md)                                 | Reactive clone of a ref                                              | AUTO          |
| [`useConfirmDialog`](references/useConfirmDialog.md)                   | Creates event hooks to support modals and confirmation dialog chains | AUTO          |
| [`useCounter`](references/useCounter.md)                               | Basic counter with utility functions                                 | AUTO          |
| [`useCycleList`](references/useCycleList.md)                           | Cycle through a list of items                                        | AUTO          |
| [`useDebounceFn`](references/useDebounceFn.md)                         | Debounce execution of a function                                     | AUTO          |
| [`useEventBus`](references/useEventBus.md)                             | A basic event bus                                                    | AUTO          |
| [`useMemoize`](references/useMemoize.md)                               | Reactive function result cache keyed by arguments                    | AUTO          |
| [`useOffsetPagination`](references/useOffsetPagination.md)             | Reactive offset pagination                                           | AUTO          |
| [`usePrevious`](references/usePrevious.md)                             | Holds the previous value of a ref                                    | AUTO          |
| [`useStepper`](references/useStepper.md)                               | Helpers for building a multi-step wizard interface                   | AUTO          |
| [`useSupported`](references/useSupported.md)                           | SSR-compatible `isSupported`                                         | AUTO          |
| [`useThrottleFn`](references/useThrottleFn.md)                         | Throttle execution of a function                                     | AUTO          |
| [`useTimeoutPoll`](references/useTimeoutPoll.md)                       | Use timeout to poll something                                        | AUTO          |
| [`useToggle`](references/useToggle.md)                                 | A boolean switcher with utility functions                            | AUTO          |
| [`useToNumber`](references/useToNumber.md)                             | Reactively convert a string ref to number                            | AUTO          |
| [`useToString`](references/useToString.md)                             | Reactively convert a ref to string                                   | AUTO          |

## @Electron

| Function                                                     | Description                                                 | Invocation |
| ------------------------------------------------------------ | ----------------------------------------------------------- | ---------- |
| [`useIpcRenderer`](references/useIpcRenderer.md)             | `ipcRenderer` and all its APIs with Vue reactivity          | EXTERNAL   |
| [`useIpcRendererInvoke`](references/useIpcRendererInvoke.md) | Reactive `ipcRenderer.invoke` API result                    | EXTERNAL   |
| [`useIpcRendererOn`](references/useIpcRendererOn.md)         | `ipcRenderer.on` with automatic `removeListener` on unmount | EXTERNAL   |
| [`useZoomFactor`](references/useZoomFactor.md)               | Reactive WebFrame zoom factor                               | EXTERNAL   |
| [`useZoomLevel`](references/useZoomLevel.md)                 | Reactive WebFrame zoom level                                | EXTERNAL   |

## @Firebase

| Function                                     | Description                                 | Invocation |
| -------------------------------------------- | ------------------------------------------- | ---------- |
| [`useAuth`](references/useAuth.md)           | Reactive Firebase Auth binding              | EXTERNAL   |
| [`useFirestore`](references/useFirestore.md) | Reactive Firestore binding                  | EXTERNAL   |
| [`useRTDB`](references/useRTDB.md)           | Reactive Firebase Realtime Database binding | EXTERNAL   |

## @Head

| Function                                           | Description                      | Invocation |
| -------------------------------------------------- | -------------------------------- | ---------- |
| [`createHead`](https://github.com/vueuse/head#api) | Create the head manager instance | EXTERNAL   |
| [`useHead`](https://github.com/vueuse/head#api)    | Update head meta tags reactively | EXTERNAL   |

## @Integrations

| Function                                               | Description                        | Invocation |
| ------------------------------------------------------ | ---------------------------------- | ---------- |
| [`useAsyncValidator`](references/useAsyncValidator.md) | Wrapper for `async-validator`      | EXTERNAL   |
| [`useAxios`](references/useAxios.md)                   | Wrapper for `axios`                | EXTERNAL   |
| [`useChangeCase`](references/useChangeCase.md)         | Reactive wrapper for `change-case` | EXTERNAL   |
| [`useCookies`](references/useCookies.md)               | Wrapper for `universal-cookie`     | EXTERNAL   |
| [`useDrauu`](references/useDrauu.md)                   | Reactive instance for `drauu`      | EXTERNAL   |
| [`useFocusTrap`](references/useFocusTrap.md)           | Reactive wrapper for `focus-trap`  | EXTERNAL   |
| [`useFuse`](references/useFuse.md)                     | Fuzzy search with Fuse.js          | EXTERNAL   |
| [`useIDBKeyval`](references/useIDBKeyval.md)           | Wrapper for `idb-keyval`           | EXTERNAL   |
| [`useJwt`](references/useJwt.md)                       | Wrapper for `jwt-decode`           | EXTERNAL   |
| [`useNProgress`](references/useNProgress.md)           | Reactive wrapper for `nprogress`   | EXTERNAL   |
| [`useQRCode`](references/useQRCode.md)                 | Wrapper for `qrcode`               | EXTERNAL   |
| [`useSortable`](references/useSortable.md)             | Wrapper for `sortable`             | EXTERNAL   |

## @Math

| Function                                                           | Description                                            | Invocation |
| ------------------------------------------------------------------ | ------------------------------------------------------ | ---------- |
| [`createGenericProjection`](references/createGenericProjection.md) | Generic version of `createProjection`                  | EXTERNAL   |
| [`createProjection`](references/createProjection.md)               | Reactive numeric projection from one domain to another | EXTERNAL   |
| [`logicAnd`](references/logicAnd.md)                               | `AND` condition for refs                               | EXTERNAL   |
| [`logicNot`](references/logicNot.md)                               | `NOT` condition for ref                                | EXTERNAL   |
| [`logicOr`](references/logicOr.md)                                 | `OR` conditions for refs                               | EXTERNAL   |
| [`useAbs`](references/useAbs.md)                                   | Reactive `Math.abs`                                    | EXTERNAL   |
| [`useAverage`](references/useAverage.md)                           | Reactive average of an array                           | EXTERNAL   |
| [`useCeil`](references/useCeil.md)                                 | Reactive `Math.ceil`                                   | EXTERNAL   |
| [`useClamp`](references/useClamp.md)                               | Reactively clamp a value between two others            | EXTERNAL   |
| [`useFloor`](references/useFloor.md)                               | Reactive `Math.floor`                                  | EXTERNAL   |
| [`useMath`](references/useMath.md)                                 | Reactive `Math` methods                                | EXTERNAL   |
| [`useMax`](references/useMax.md)                                   | Reactive `Math.max`                                    | EXTERNAL   |
| [`useMin`](references/useMin.md)                                   | Reactive `Math.min`                                    | EXTERNAL   |
| [`usePrecision`](references/usePrecision.md)                       | Reactively set the precision of a number               | EXTERNAL   |
| [`useProjection`](references/useProjection.md)                     | Reactive numeric projection from one domain to another | EXTERNAL   |
| [`useRound`](references/useRound.md)                               | Reactive `Math.round`                                  | EXTERNAL   |
| [`useSum`](references/useSum.md)                                   | Reactive sum of an array                               | EXTERNAL   |
| [`useTrunc`](references/useTrunc.md)                               | Reactive `Math.trunc`                                  | EXTERNAL   |

## @Motion

| Function                                                                     | Description                                                | Invocation |
| ---------------------------------------------------------------------------- | ---------------------------------------------------------- | ---------- |
| [`useElementStyle`](https://motion.vueuse.org/api/use-element-style)         | Sync a reactive object to a target element's CSS styling   | EXTERNAL   |
| [`useElementTransform`](https://motion.vueuse.org/api/use-element-transform) | Sync a reactive object to a target element's CSS transform | EXTERNAL   |
| [`useMotion`](https://motion.vueuse.org/api/use-motion)                      | Putting your components in motion                          | EXTERNAL   |
| [`useMotionProperties`](https://motion.vueuse.org/api/use-motion-properties) | Access Motion Properties for a target element              | EXTERNAL   |
| [`useMotionVariants`](https://motion.vueuse.org/api/use-motion-variants)     | Handle the Variants state and selection                    | EXTERNAL   |
| [`useSpring`](https://motion.vueuse.org/api/use-spring)                      | Spring animations                                          | EXTERNAL   |

## @Router

| Function                                         | Description                             | Invocation |
| ------------------------------------------------ | --------------------------------------- | ---------- |
| [`useRouteHash`](references/useRouteHash.md)     | Shorthand for a reactive `route.hash`   | EXTERNAL   |
| [`useRouteParams`](references/useRouteParams.md) | Shorthand for a reactive `route.params` | EXTERNAL   |
| [`useRouteQuery`](references/useRouteQuery.md)   | Shorthand for a reactive `route.query`  | EXTERNAL   |

## @RxJS

| Function                                                             | Description                                                                   | Invocation |
| -------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ---------- |
| [`from`](references/from.md)                                         | Wrappers around RxJS's `from()` and `fromEvent()` to accept `ref`s            | EXTERNAL   |
| [`toObserver`](references/toObserver.md)                             | Convert a `ref` into an RxJS Observer                                         | EXTERNAL   |
| [`useExtractedObservable`](references/useExtractedObservable.md)     | Use an RxJS Observable extracted from one or more composables                 | EXTERNAL   |
| [`useObservable`](references/useObservable.md)                       | Use an RxJS Observable                                                        | EXTERNAL   |
| [`useSubject`](references/useSubject.md)                             | Bind an RxJS Subject to a `ref` and propagate value changes both ways         | EXTERNAL   |
| [`useSubscription`](references/useSubscription.md)                   | RxJS Subscription with cleanup                                                | EXTERNAL   |
| [`watchExtractedObservable`](references/watchExtractedObservable.md) | Watch the values of an RxJS Observable extracted from one or more composables | EXTERNAL   |

## @SchemaOrg

| Function                                                                                | Description                            | Invocation |
| --------------------------------------------------------------------------------------- | -------------------------------------- | ---------- |
| [`createSchemaOrg`](https://vue-schema-org.netlify.app/api/core/create-schema-org.html) | Create the schema.org manager instance | EXTERNAL   |
| [`useSchemaOrg`](https://vue-schema-org.netlify.app/api/core/use-schema-org.html)       | Update schema.org reactively           | EXTERNAL   |

## @Sound

| Function                                               | Description                   | Invocation |
| ------------------------------------------------------ | ----------------------------- | ---------- |
| [`useSound`](https://github.com/vueuse/sound#examples) | Play sound effects reactively | EXTERNAL   |
