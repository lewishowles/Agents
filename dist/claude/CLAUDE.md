# Global Claude configuration

Baseline rules for all projects. Project-specific rules live in AGENTS.md.

**Each project must have AGENTS.md at the project root.** Run `scripts/setup-project.sh --claude` from this repo, or create one with: purpose, functionality, tech choices, architecture notes, gotchas. AGENTS.md lives at the project root, not in `~/.claude/`.

## General configuration

Rules are authoritative. Apply every rule every time. In-conversation request conflicts with rules: follow request, flag the conflict. No silent relaxation.

### Token budget discipline

Minimise token cost by default. Treat context as a limited shared budget.

Strict rules:

- Do not run tests, builds, typechecks, linters, or visual checks (including single test files). Ask the user to run them unless local execution clearly saves more tokens than the back-and-forth it prevents.
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

### Completing work

**Evidence before claims. Don't assert success without proof.**

- Don't say tests pass, the build works, or a fix is resolved unless you have seen output confirming it
- Evidence can be: the user running a command and sharing output, or agent-run verification when that is clearly token-justified
- When work is done, say what changed and what the user should verify — don't claim it works if you haven't seen it run
- This aligns with `pre-stop-checks.sh` — the hook enforces it; this rule explains why

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

**Maintain PROGRESS.md for significant work.** For multi-file, multi-session, or complex-scope work, keep `.claude/PROGRESS.md` as the persistent record across sessions. Update it after every significant change, decision, or scope shift — mark items done as they complete, record decisions, compact completed sections to brief summaries when starting the next chunk. A starter template is at `.claude/templates/PROGRESS.md.template` if one exists in the project.

**Work in committable chunks** — feature, bugfix, refactor, or documentation update:

- Before: summarise the chunk; wait for confirmation if the user requested it
- After: explain what changed and how the code works; say what's visible to the user (or confirm nothing changed); provide a `feat(scope): description` commit message — do not run `git commit` unless asked; update PROGRESS.md; wait for confirmation before the next chunk

## Identity & expertise

Designer, front-end dev, strong full-stack. Focus: accessible design (WCAG AA, AAA where feasible), maintainable/scalable code, dev experience. UK-based. Exploring freelance, tooling, accessibility audits.

## Skill use policy

Skills are authoritative when their trigger conditions match. Before coding, editing prose, changing config, or reviewing files, inspect the task and file paths, then load and use the matching skills needed for the current task type. If multiple skills match, use all relevant skills — especially `code-style` plus language/framework skills. Do not wait for explicit slash-command invocation.

Minimise repeated skill reads:

- Re-read only if the task type changes, the user explicitly asks, or you need a specific detail. Default: state you're continuing to apply the already-read skill.
- Load the smallest matching set; do not speculatively load adjacent skills.
- Summarise remembered constraints in your own words — do not quote skill sections back.
- If a skill conflicts with the user's token-budget preference, follow the preference and note the tradeoff.

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

- `/archive-progress` — When moving completed PROGRESS.md sections into archived milestones to reduce document size
- `/compact-progress` — When PROGRESS.md has grown noisy or hard to scan; preserves decisions and rewrites active sections
- `/continue-project` — When resuming work from an existing PROGRESS.md
- `/plan-task` — When introducing new work into an existing plan
- `/setup-project` — When starting a new project or feature; explores repo, asks questions, creates PROGRESS.md before coding
- `/accessibility` — When building interfaces, WCAG AA baseline, accessible design
- `/accessibility-audit` — When conducting an accessibility audit of a page, component, or PR; preparing a client report
- `/bash` — When writing shell scripts, bash config, patterns
- `/code-review` — When reviewing a PR or diff, or receiving review feedback
- `/code-style` — When formatting code, covering naming, comments, arrays, objects
- `/debugging` — When encountering any bug, test failure, or unexpected behaviour — before proposing a fix
- `/dependencies` — When adding packages, what to choose, when to add
- `/e2e-testing` — When writing end-to-end tests with Playwright
- `/error-handling` — When validating input, graceful fallbacks, error handling
- `/frontend-security` — When writing or reviewing client-side code for security: XSS, CSP, auth tokens, secrets hygiene
- `/pinia` — When using Pinia for client-side Vue app state and stores
- `/pinia-colada` — When using `@pinia/colada` for async server state — `useQuery`, `useMutation`, cache management, optimistic updates
- `/readme` — When writing a README, structure, what to include/cut
- `/refactoring` — When refactoring existing code or triaging technical debt
- `/swift` — When writing Swift, style, SwiftUI patterns, concurrency
- `/swift-ui` — When writing/reviewing SwiftUI code, views, state management
- `/testing` — When deciding what to test and at which layer — strategy above unit-testing and e2e-testing
- `/typescript` — When using TypeScript, type safety, escape hatches
- `/ui-copy` — When writing microcopy, buttons, errors, empty states, CTAs
- `/unit-testing` — When writing unit tests, Vitest, philosophy, what to skip
- `/vite-patterns` — When configuring vite.config.ts, Vite project patterns
- `/web-performance` — When optimising Core Web Vitals, bundle size, or asset loading for Vue/Vite/GitHub Pages projects
- `/vue` — When writing Vue code, formatting, patterns, composables, components
- `/vue-project-stack` — When working in Vue + Bun + Vitest + Tailwind + Gitflow stack
- `/vue-router` — When using Vue Router routes, guards, params, query strings, and redirects
- `/vueuse-functions` — When using VueUse composables for Vue/Nuxt features
- `/writing` — When writing prose/documentation, voice, tone, structure, style

## Prefer codebase-memory-mcp graph tools

Before reading source files, use codebase-memory-mcp when available. Tool order:

1. `list_projects`/`index_status` — check if indexed
2. `index_repository` — index if needed
3. `search_graph` — find symbols by name, label, or pattern
4. `trace_path` — call chains, data flow, cross-service paths
5. `get_code_snippet` — read source for a discovered symbol
6. `query_graph` — Cypher for complex structural questions
7. `get_architecture` — project structure overview
8. `detect_changes` — git changes → affected symbols

Pass the project name from `list_projects` to query tools. Use `search_code` for text search. Fall back to shell discovery only for non-code files, config values, literals, or when MCP returns insufficient results. If unavailable, state once then use the narrowest file-discovery command.