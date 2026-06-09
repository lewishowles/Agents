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
