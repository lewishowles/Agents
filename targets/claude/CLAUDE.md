# Global Claude configuration

Baseline rules for all projects. Project-specific rules live in AGENTS.md.

**Each project must have AGENTS.md at the project root.** Run `scripts/setup-project.sh --claude` from this repo, or create one with: purpose, functionality, tech choices, architecture notes, gotchas. AGENTS.md lives at the project root, not in `~/.claude/`.

## General configuration

Rules are authoritative. Apply every rule every time. In-conversation request conflicts with rules: follow request, flag the conflict. No silent relaxation.

### Token budget discipline

Minimise token cost by default. Treat context as a limited shared budget.

Strict rules:

- Do not run tests, builds, typechecks, linters, or visual checks by default. Ask the user to run them and report errors unless you are sure running the command locally will cost fewer tokens than the back-and-forth it prevents.
- Single test files are still test runs. Do not run them unless the result is necessary to choose the next edit or the user explicitly asks.
- Do not read build output, generated bundles, coverage, screenshots, or generated artefacts unless a reported failure points to a specific file or path.
- Do not print large command output unless the user asked for it or it is needed to diagnose a failure.
- For user-run failures, ask for the smallest useful excerpt: command, failing file/test, error message, and relevant stack frame.
- Do not use `git diff` for routine self-review. You wrote the files; inspect the edited source directly only when needed. Use `git status --short` to list touched files.
- Read targeted file ranges instead of whole files. Do not repeatedly read large progress files; use targeted headings or searches.
- Do not re-run or re-print expensive commands unless something changed that can affect their result and local execution is justified by token cost.
- Never run broad discovery commands that can traverse dependencies, generated output, caches, or build products.
- If you accidentally produce excessive output, acknowledge it briefly, switch to narrower commands, and avoid repeating the pattern.

Multi-step processes: one step at a time unless told otherwise. Explain, wait for confirmation.

### Interacting with the user

- Batch clarifying questions — minimise back and forth
- Propose changes as a plan; get review before proceeding

### Think before coding

**Surface confusion. State tradeoffs. Don't assume.**

- State assumptions explicitly; ask if unsure
- Multiple interpretations? Present all, don't pick silently
- Simpler approach exists? Say so; push back when warranted
- Unclear? Stop and name what's confusing
- Never install packages, run API calls, or use external tools without permission
- Admit mistakes; rewind and restart from first principles

### When expectations break

**Unexpected state — stop and ask. Don't dig.**

- File missing? Symlink broken? Output unexpected? Stop.
- Don't workaround, retry, or dig deeper — state what you expected vs. what you found
- Example: "I expected `CLAUDE.md` in `.claude/`, but it's missing. Should I create one or symlink it?"
- Recovers faster than chasing wrong paths. You know the system; I don't.

### Simplicity first

**Minimum code. Nothing speculative.**

- No features beyond request, no single-use abstractions
- No unasked flexibility, configurability, or error handling for impossible scenarios

### Surgical changes

**Touch only what's necessary. Clean up only your own mess.**

When editing:

- Don't improve adjacent code, comments, or formatting
- Don't refactor what works
- Match existing style
- Spot unrelated dead code? Mention it, don't delete

When your changes create orphans:

- Remove unused imports, variables, functions you created
- Don't remove pre-existing dead code unless asked

Rule: every changed line traces directly to the request

### Research

When checking documentation for a package or library, try `<docs-url>/llms.txt` first — it often contains curated links optimised for LLMs.

### File operations

Use `trash` instead of `rm` for any destructive file removal.

## Communication

- **UK spelling** — colour, organise, behaviour, grey, etc.
- **Titles**: sentence case
- **No preamble/summary** unless asked

## Git & version control

Code must be reviewed before it is committed. Completing work means stopping after edits, checks, and a clear summary.

- Do not run `git commit`, `git tag`, `git push`, merge commands, or any command that creates or publishes Git history unless I explicitly ask for that exact action in the current conversation.
- Do not treat "finish", "wrap up", "ready", "ship it", "commit message", or a suggested commit message as permission to commit.
- Do not stage files with `git add` unless I explicitly ask you to prepare a staged commit.
- Update docs when changes require documentation
- After completing a coherent step, provide a scoped Conventional Commit message as plain text only. Label it `Suggested commit message:` and do not execute it.
- If I do ask you to commit, show the files to be included and the exact commit message first, then wait for confirmation.

## Working across sessions

**Maintain PROGRESS.md for significant work.** For multi-file, multi-session, or complex-scope work, keep `.claude/PROGRESS.md` as the persistent record that survives session changes.

**Keep it live**: Update PROGRESS.md after every significant change, decision, or scope shift — don't wait until session end:
- Mark checklist items done as they complete
- Record new architectural decisions or constraint discoveries
- Update Phase descriptions if requirements evolve
- Append session notes after finishing each logical chunk of work

**Work in committable chunks**: Break work into pieces that can be reviewed together:
- Each chunk = a feature, bugfix, refactor, or documentation update — something coherent and meaningful
- Avoid accumulating unrelated changes in a single review
- Before starting a chunk, summarise what needs to be done and wait if the user asked for confirmation between chunks
- After completing a chunk, explain what changed and, when code changed, walk through the new code and how it works so the user can keep a mental model
- After completing a chunk, say what the user should see differently in the app/plugin/tool, if anything, so they can test it; if there is no user-visible change, say that clearly
- After completing a chunk, provide a human-readable Conventional Commit message (e.g. `feat(component): add support for X`) — document it for review, but don't execute `git commit` unless asked
- If a chunk reworks earlier implementation, the commit message should describe the coherent chunk outcome, not meta-commentary about rework
- Do not start the next chunk until the user confirms the previous chunk has been reviewed or committed
- Update PROGRESS.md to reflect what was completed
- When starting the next chunk, compact completed PROGRESS.md sections into short human-readable summaries, retaining only decisions, verification status, user-visible test notes, and future-relevant constraints

**Default continuation prompt expectations**: When the user asks to continue from progress, read only the current relevant progress section, keep it live with every meaningful change, decision, or scope shift, work in targeted reviewable chunks, do not commit, summarise before each chunk, explain each completed chunk, include user-visible test notes, provide a suggested Conventional Commit message, and stop until the user confirms the next chunk.

**Why it matters**: You know the full session history and can pick up mid-stream without re-reading 100 lines of context. PROGRESS.md is the handoff mechanism between sessions.

## Identity & expertise

Designer, front-end dev, strong full-stack. Focus: accessible design (WCAG AA, AAA where feasible), maintainable/scalable code, dev experience. UK-based. Exploring freelance, tooling, accessibility audits.

## Skill use policy

Skills are authoritative when their trigger conditions match. Before coding, editing prose, changing config, or reviewing files, inspect the task and file paths, then load and use the matching skills needed for the current task type. If multiple skills match, use all relevant skills — especially `code-style` plus language/framework skills. Do not wait for explicit slash-command invocation.

Minimise repeated skill reads:

- Do not re-read the same skill file within a continuous session unless the task type changes, the user explicitly asks, or you need a specific detail not already loaded.
- Reusing an already-read skill is the default. State briefly that you are continuing to apply it instead of opening it again.
- Prefer loading the smallest relevant skill set. Do not load broad adjacent skills speculatively.
- If a platform requires skill invocation every turn, invoke only the required matching skill and avoid opening long reference files unless needed.
- Summarise remembered skill constraints in your own words; do not paste or quote long skill sections back to the user.
- If a skill conflicts with the user's token-budget preference, follow the user's preference and note the tradeoff briefly.

The goal is strict compliance without paying repeated token cost for unchanged instructions.

## File discovery

Minimise token cost while discovering files. Discovery commands should answer the narrow question with the smallest output.

Strict rules:

- Prefer `rg` and `rg --files`; they respect `.gitignore` and `.rgignore`.
- Scope searches to the smallest likely directory, for example `rg --files src` instead of repo-wide scans.
- Do not inspect generated, vendored, cached, build, dependency, or large binary directories unless explicitly asked. This includes `node_modules`, `dist`, `build`, `.git`, coverage, caches, generated plugin bundles, lockfile-heavy generated output, and local secrets.
- Do not use broad `find`, `ls -R`, or unscoped glob searches. If `find` is unavoidable, scope it to named directories and group `-o` expressions with parentheses.
- Before printing many files, prefer counts or `--files-with-matches`; open only the specific files needed.
- For build artefact checks, inspect the exact expected output path rather than listing whole build trees.
- If a command unexpectedly starts dumping large output, stop using that pattern and switch to a narrower command.

Good examples:

```bash
rg --files src
rg "formatWarnings" src/webview
find src sketch-to-tailwind.sketchplugin -type f \( -name "*.js" -o -name "*.css" -o -name "*.html" \)
```

Bad examples:

```bash
find . -type f
find . -name "*.js" -o -name "*.css"
ls -R
```

## Global skills

Apply across all projects. See individual skills for detailed rules. Per-project `.claude/settings.json` can disable skills via `skillOverrides` — useful if a skill's tech (Vue, Swift) isn't used in that project.

- `/accessibility` — When building interfaces, WCAG AA baseline, accessible design
- `/agentic-engineering` — When building with Claude API, Anthropic SDK, or managed agents
- `/architecture-decision-records` — When documenting significant architectural decisions
- `/bash` — When writing shell scripts, bash config, patterns
- `/code-style` — When formatting code, covering naming, comments, arrays, objects
- `/dependencies` — When adding packages, what to choose, when to add
- `/e2e-testing` — When writing end-to-end tests with Playwright
- `/error-handling` — When validating input, graceful fallbacks, error handling
- `/pinia` — When using Pinia for client-side Vue app state and stores
- `/pinia-colada` — When using `@pinia/colada` for async server state — `useQuery`, `useMutation`, cache management, optimistic updates
- `/readme` — When writing a README, structure, what to include/cut
- `/session-management` — When saving/resuming sessions, tracking multi-session work, token efficiency, goal-driven execution
- `/swift` — When writing Swift, style, SwiftUI patterns, concurrency
- `/swift-ui` — When writing/reviewing SwiftUI code, views, state management
- `/typescript` — When using TypeScript, type safety, escape hatches
- `/ui-copy` — When writing microcopy, buttons, errors, empty states, CTAs
- `/unit-testing` — When writing unit tests, Vitest, philosophy, what to skip
- `/vite-patterns` — When configuring vite.config.ts, Vite project patterns
- `/vue` — When writing Vue code, formatting, patterns, composables, components
- `/vue-project-stack` — When working in Vue + Bun + Vitest + Tailwind + Gitflow stack
- `/vue-router` — When using Vue Router routes, guards, params, query strings, and redirects
- `/vueuse-functions` — When using VueUse composables for Vue/Nuxt features
- `/writing` — When writing prose/documentation, voice, tone, structure, style

## Prefer codebase-memory-mcp graph tools

Before reading source files or scanning a codebase, use codebase-memory-mcp when its MCP tools are available. The graph gives structural answers faster than broad `Grep`, `Glob`, `Read`, `find`, or `rg` exploration.

Use the graph tools in this order:

1. `list_projects` or `index_status` — check whether the project is indexed.
2. `index_repository` — index the current project if no usable graph exists.
3. `search_graph` — find functions, classes, routes, variables, and files by label, name pattern, or qualified-name pattern.
4. `trace_path` — inspect callers, callees, call chains, data flow, or cross-service paths.
5. `get_code_snippet` — read the exact source for a discovered function, class, or method.
6. `query_graph` — run Cypher for complex structural questions.
7. `get_architecture` — get high-level project structure and relationships.
8. `detect_changes` — map local git changes to affected graph symbols.

For query tools, pass the `project` name returned by `list_projects`.

Use `search_code` for graph-augmented text search. Fall back to normal shell discovery only for non-code files, config values, literal strings, generated assets, or when codebase-memory-mcp returns insufficient results.

If codebase-memory-mcp is unavailable in the current runtime, do not spend tokens searching for it or trying repeated failing calls. State once that the graph tools are unavailable, then use the narrowest normal file-discovery command allowed by the file-discovery rules.
