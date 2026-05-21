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
