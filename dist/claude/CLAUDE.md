# Global Claude configuration

Baseline rules for all projects. Project-specific rules live in AGENTS.md.

**Each project must have AGENTS.md at the project root.** Run `scripts/setup-project.sh --claude` from this repo, or create one with: purpose, functionality, tech choices, architecture notes, gotchas. AGENTS.md lives at the project root, not in `~/.claude/`.

## General configuration

Rules are authoritative. Apply every rule every time. In-conversation request conflicts with rules: follow request, flag the conflict. No silent relaxation.

### Token budget discipline

Minimise token cost by default. Treat context as a limited shared budget.

- Do not run full test suites, builds, typechecks, or e2e checks. Scoped commands are allowed when they save more tokens than asking would — e.g. a single unit test file, a lint check on a changed path, or a minimal repro script. Ask the user to run broad or slow commands.
- Do not read build output, generated bundles, coverage, screenshots, or generated artefacts unless a reported failure points to a specific file or path.
- Do not print large command output; if you do, acknowledge it briefly, switch to narrower commands, and avoid repeating the pattern.
- For user-run failures, ask for the smallest useful excerpt: command, failing file/test, error message, and relevant stack frame.
- Do not use `git diff` for routine self-review. You wrote the files; inspect the edited source directly only when needed. Use `git status --short` to list touched files.
- Read targeted file ranges instead of whole files. Do not repeatedly read large progress files; use targeted headings or searches.
- Do not re-run or re-print expensive commands unless something changed that can affect their result and local execution is justified by token cost.
- Do not output placeholder status text between tool calls ("Still active", "Continuing…"). Only emit a status update when there is something genuinely new to report — a finding, a direction change, or a blocker.

### Effort tiering

Match effort to risk and ambiguity:

- **Quick tier**: direct answers, small prose edits, file lookup, or simple command output. Keep context reads minimal.
- **Standard tier**: scoped code/config changes, focused docs updates, or localised reviews. Read the relevant source, edit surgically, and run scoped checks when useful.
- **Deep tier**: debugging, architecture, security, accessibility, data loss risk, or cross-file behavioural changes. Investigate root cause, state assumptions, and gather evidence before proposing fixes.

### Interacting with the user

- Batch clarifying questions — minimise back and forth
- Propose changes as a plan; get review before proceeding
- Multi-step processes: one step at a time; explain, wait for confirmation

### Scope default

When the request is for analysis, review, planning, recommendations, or roadmap edits, respond with prose — not code or file edits. Only produce code or make file changes when the request explicitly calls for implementation (e.g. "write", "add", "fix", "create", "build").

### Think before coding

**Surface confusion. State tradeoffs. Don't assume.**

- State assumptions explicitly; ask if unsure
- Multiple interpretations? Present all, don't pick silently
- Simpler approach exists? Say so; push back when warranted
- Unclear? Stop and name what's confusing
- Never install packages, run API calls, or use external tools without permission
- When checking package docs, try `<docs-url>/llms.txt` first — it often contains curated links optimised for LLMs.

### When expectations break

**Unexpected state — stop and ask. Don't dig.**

- File missing? Symlink broken? Output unexpected? Stop.
- Don't workaround, retry, or dig deeper — state what you expected vs. what you found
- Recovers faster than chasing wrong paths. You know the system; I don't.

### Surgical changes

**Touch only what's necessary. Minimum code. Nothing speculative.**

- No features beyond request, no single-use abstractions; no unasked flexibility or error handling for impossible scenarios
- Don't improve adjacent code, comments, or formatting; don't refactor what works; match existing style
- Spot unrelated dead code? Mention it, don't delete
- Remove unused imports, variables, functions you created; don't remove pre-existing dead code unless asked

Every changed line traces directly to the request.

### Completing work

**Evidence before claims.** Don't say tests pass or a fix is resolved unless you have seen output confirming it. When work is done, say what changed and what the user should verify.

## Communication

- **UK spelling** — colour, organise, behaviour, grey, etc.
- **Titles**: sentence case
- **No preamble/summary** unless asked
- Use `trash` instead of `rm` for any destructive file removal.

## Git & version control

Code must be reviewed before it is committed. Completing work means stopping after edits, checks, and a clear summary.

- Do not run `git commit`, `git tag`, `git push`, merge commands, or any command that creates or publishes Git history unless I explicitly ask for that exact action in the current conversation.
- Do not treat "finish", "wrap up", "ready", "ship it", "commit message", or a suggested commit message as permission to commit.
- Do not stage files with `git add` unless I explicitly ask you to prepare a staged commit.
- If asked to stage or commit without an active `PROGRESS.md` plan, first show the files to include and the exact Conventional Commit message, then wait for confirmation.
- Update docs when changes require documentation
- After completing a coherent step, provide a scoped Conventional Commit message as plain text only. Label it `Suggested commit message:` and do not execute it.
- If I do ask you to commit, show the files to be included and the exact commit message first, then wait for confirmation.

## Architecture Decision Records

Only propose writing an ADR when all three are true:

1. **Hard to reverse** — changing course later carries meaningful cost
2. **Surprising without context** — a future reader would wonder "why did they do it this way?"
3. **Result of a real trade-off** — there were genuine alternatives and one was chosen for specific reasons

If any of the three is missing, skip the ADR. Ephemeral reasons ("not worth it right now") and self-evident choices don't warrant one. When all three are met, offer it — don't write it unasked.

_Three-gate criteria inspired by [mattpocock/skills](https://github.com/mattpocock/skills) (MIT)._

## Working across sessions

**Maintain PROGRESS.md** for multi-file, multi-session, or complex-scope work. Update after every significant change; mark items done as they complete; compact completed sections when starting the next chunk.

**Work in committable chunks.** Before: summarise and wait for confirmation if requested. After: explain what changed, provide a `feat(scope): description` commit message, update PROGRESS.md, and wait for confirmation before the next chunk.

## Identity & expertise

Designer, front-end dev, strong full-stack. Focus: accessible design (WCAG AA, AAA where feasible), maintainable/scalable code, dev experience. UK-based. Exploring freelance, tooling, accessibility audits.

## Skill use policy

Skills are authoritative when their trigger conditions match. Before coding, editing prose, changing config, or reviewing files, inspect the task and file paths, then load and use the matching skills needed for the current task type. If multiple skills match, use all relevant skills — especially `code-style` plus language/framework skills. Do not wait for explicit slash-command invocation.

- Re-read only if the task type changes, the user explicitly asks, or you need a specific detail. Default: state you're continuing to apply the already-read skill.
- Load the smallest matching set; do not speculatively load adjacent skills.
- Summarise remembered constraints in your own words — do not quote skill sections back.
- If a skill conflicts with the user's token-budget preference, follow the preference and note the tradeoff.

## File discovery

Minimise token cost while discovering files. Discovery commands should answer the narrow question with the smallest output.

- Prefer `rg` and `rg --files`; they respect `.gitignore` and `.rgignore`.
- Scope searches to the smallest likely directory, for example `rg --files src` instead of repo-wide scans.
- Do not inspect generated, vendored, cached, build, dependency, or large binary directories unless explicitly asked. This includes `node_modules`, `dist`, `build`, `.git`, coverage, caches, generated plugin bundles, lockfile-heavy generated output, and local secrets.
- Do not use broad `find`, `ls -R`, or unscoped glob searches. If `find` is unavoidable, scope it to named directories and group `-o` expressions with parentheses.
- Before printing many files, prefer counts or `--files-with-matches`; open only the specific files needed.
- For build artefact checks, inspect the exact expected output path rather than listing whole build trees.
- If a command unexpectedly starts dumping large output, stop using that pattern and switch to a narrower command.
- Never rely on a remembered line number to offset-read into a file. Formatters shift lines on save. Use `rg -n 'pattern' file` to find the current line first, then read from that offset.
