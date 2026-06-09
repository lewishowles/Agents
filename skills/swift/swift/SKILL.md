---
name: swift
description: >
  Use this skill when writing or editing any Swift code — macOS apps, command-line tools, scripts, system tools. Covers comment style, naming, spacing, concurrency, error handling, process management, and environment setup. For SwiftUI-specific patterns, use the swift-ui skill.
related-skills:
  - code-style
---

# Swift code style

## Comments

Swift comments: strict two-tier system.

**Types and functions** — always use `/** */` block form, even single sentence. Never `/** Description. */` one line. Never `//` for types or functions.

```swift
/**
 * Description here.
 */
struct Foo { ... }

/**
 * Does the thing.
 */
func doSomething() { ... }
```

**Properties and inline logic** — `//` only. Multi-line `//` blocks fine. Never `/** */` on property or inside function body.

```swift
// ID of the currently selected project.
var selectedProjectID: UUID?

// Capture value-type snapshots before entering the Task. Inside the Task,
// accessing @MainActor-isolated properties after an `await` crossing is
// a Swift 6 error — captured Sendable values avoid the actor hop entirely.
let projects = projects
```

## Spacing

- Blank line between logical sections in function body — state mutation vs `save()`, setup vs execution, `guard` vs main logic.
- Blank line between declarations of different "weight": single-line property before multi-line property or function, or between two multi-line declarations.
- No blank line between two single-line properties of similar weight.

## Naming

- Full, descriptive names — no abbreviations (`project` not `proj`, `index` not `i`).
- Bool properties/parameters: prefix `is`, `has`, `should`, `can` where natural (`isLoading`, `showSheet`).
- Async fetch functions: name by return value (`currentBranch`, `readPackageJSON`) not mechanism (`fetchBranch`, `loadJSON`).

## Concurrency

- Mark UI-driving classes `@MainActor` — don't sprinkle `await MainActor.run` at call sites.
- `async let` for concurrent fetches that are parallel and needed together.
- Capture value-type snapshots before `Task` body to avoid Swift 6 actor-isolation errors:
  ```swift
  let projects = projects  // captured copy
  saveTask = Task {
      Persistence.save(projects, filename: "projects.json")
  }
  ```
- Actors protect internal state — one instance per operation, not global serialisation queue.
- `AsyncStream` with `continuation` to bridge callback-based APIs (`Process`, `DispatchSource`) into structured concurrency.

## Error handling

- `guard let` / `guard` with early return over deeply nested `if let`.
- `try?` fine for non-critical ops (file reads, process launch) where failure degrades gracefully.
- No `try!` — always handle or suppress explicitly.

## PATH in macOS apps

Apps from Finder don't inherit shell `PATH`. When spawning external tools (`bun`, `git`, etc.), prepend known locations manually:

```swift
var env = ProcessInfo.processInfo.environment
let home = env["HOME"] ?? NSHomeDirectory()
let extraPaths = ["\(home)/.bun/bin", "/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin"]
env["PATH"] = (extraPaths + [env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"]).joined(separator: ":")
process.environment = env
```