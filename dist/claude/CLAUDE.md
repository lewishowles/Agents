# Global Claude configuration

Baseline rules for all projects. Project-specific rules live in AGENTS.md.

**Each project must have AGENTS.md at the project root.** Run `scripts/setup-project.sh --claude` from this repo, or create one with: purpose, functionality, tech choices, architecture notes, gotchas. AGENTS.md lives at the project root, not in `~/.claude/`.

## General configuration

Rules are authoritative. Apply every rule every time. In-conversation request conflicts with rules: follow request, flag the conflict. No silent relaxation.

### Workspace facts

After reading project instructions, check for `WORKSPACE.md` at the project root before planning or running local commands. Treat it as the factual source for available commands, generated files, diagnostics, progress locations, expensive checks, and forbidden operations. During migration, fall back to `AGENT_CAPABILITIES.md` when `WORKSPACE.md` is absent.

If no workspace file exists, fall back to targeted inspection of `AGENTS.md`, package scripts, and nearby docs. Do not create `WORKSPACE.md` ad hoc from partial inspection; only create it through project setup or the workspace generator when the user asks. Ask before guessing about expensive, destructive, remote, or history-changing commands.

When `.agent/scripts/project-diagnostics.py` exists, use it for build, test, typecheck, and lint checks. Do not run raw package, build, test, typecheck, or lint commands directly unless the user explicitly asks for the raw command. It is the shared project-local diagnostics entry point for Claude and Codex, and it writes full logs to `.agent/diagnostics/` while keeping stdout compact. Run `--list` as part of startup/discovery after checking `WORKSPACE.md`, run `--check <name>` for the specific check needed, and use `--all` only when the user asks for broad verification. Unit-test checks can be narrowed with repeatable `--test-file <path>` and `--test-glob '<pattern>'` arguments. Quote glob patterns so the diagnostics script expands and validates them inside the project. If a check fails, use the log path returned in the output and extract details with targeted `rg`, `sed`, or similar commands; do not re-run the same check just to get more output. If the diagnostics script is missing, use `WORKSPACE.md` common checks or narrow manually inspected commands.

### Token budget discipline

Minimise token cost by default. Treat context as a limited shared budget.

- Do not run full test suites, builds, typechecks, or e2e checks directly. If `.agent/scripts/project-diagnostics.py` exists, use its `--test-file` or `--test-glob` arguments for scoped unit tests rather than passing raw runner arguments. If the diagnostics script is missing, scoped commands are allowed when they save more tokens than asking would, for example a single unit test file, a lint check on a changed path, or a minimal repro script. Ask the user to run broad or slow commands when no diagnostics wrapper exists.
- When running any script that produces large output (tests, linters, build steps), pipe output through `tail`: `2>&1 | tail -20`. If a check fails, follow up with a targeted command to extract the first error — never print the full output.
- Do not read build output, generated bundles, coverage, screenshots, or generated artefacts unless a reported failure points to a specific file or path.
- Do not print large command output; if you do, acknowledge it briefly, switch to narrower commands, and avoid repeating the pattern.
- For user-run failures, ask for the smallest useful excerpt: command, failing file/test, error message, and relevant stack frame.
- Do not use `git diff` for routine self-review. You wrote the files; inspect the edited source directly only when needed. Use `git status --short` to list touched files.
- Read targeted file ranges instead of whole files. Do not repeatedly read large progress files; use targeted headings or searches.
- For file relocations, use `mv` or `cp` via Bash. Never read a file's content just to write it at a different path — that's three tool calls instead of one.
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

- State assumptions explicitly. If confidence in understanding the requirement is below 95%, list what is understood and what needs clarifying before touching any files

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

**Always state what's next.** After completing any step — or finishing everything — close with what comes next: the next planned step, an open question to resolve, or an explicit "nothing remains" if there is no more planned work. This applies even between task boundaries.

## Communication

- **UK spelling** — colour, organise, behaviour, grey, etc.
- **Titles**: sentence case
- **No preamble/summary** unless asked
- Use `trash` instead of `rm` for any destructive file removal.
- **No blame attribution** — don't label issues as "pre-existing" or distinguish your changes from prior code. Describe the issue and what to fix, without framing who introduced it.

## Git & version control

Code must be reviewed before it is committed. Completing work means stopping after edits, checks, and a clear summary.

- Do not run `git commit`, `git tag`, `git push`, merge commands, or any command that creates or publishes Git history unless I explicitly ask for that exact action in the current conversation.
- Do not treat "finish", "wrap up", "ready", "ship it", "commit message", or a suggested commit message as permission to commit.
- Do not stage files with `git add` unless I explicitly ask you to prepare a staged commit.
- If asked to stage or commit without an active `PROGRESS.md` plan, first show the files to include and the exact Conventional Commit message, then wait for confirmation.
- Update docs when changes require documentation
- After completing a coherent step that changes tracked source files (code, config, rules, skills, scripts, templates, or docs), provide a scoped Conventional Commit message as plain text only. Label it `Suggested commit message:` and do not execute it. Do not suggest a commit message for PROGRESS.md updates, planning discussions, analysis, or responses that contain no file changes.
- If I do ask you to commit, show the files to be included and the exact commit message first, then wait for confirmation.
- Never add a `Co-Authored-By` trailer or any attribution line to commit messages.

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

Default to small, directly related chunks. Each chunk should fit one reviewable idea and one expected commit.

- Split broad roadmap items before implementation.
- Keep source, tests, docs, capability updates, and adoption work separate unless the same change requires them.
- Prefer one primitive family, one profile behaviour, or one capability concern per chunk.
- Stop after each chunk with files changed, verification performed, next step, and suggested commit message.
- Do not continue into the next chunk until the user confirms.

## Identity & expertise

Designer, front-end dev, strong full-stack. Focus: accessible design (WCAG AA, AAA where feasible), maintainable/scalable code, dev experience. UK-based. Exploring freelance, tooling, accessibility audits.

## Skill use policy

Skills are authoritative when their trigger conditions match. Before coding, editing prose, changing config, or reviewing files, inspect the task and file paths, then load and use the matching skills needed for the current task type. If multiple skills match, use all relevant skills — especially `code-style` plus language/framework skills. Do not wait for explicit slash-command invocation.

**Skill vs. rule boundary:** if guidance should apply on every turn regardless of task, it belongs in `rules/`. If it is triggered by a specific task type or file context, it belongs in `skills/`. Do not add always-on conventions to a skill, and do not put task-specific workflows in a rule.

- Re-read a skill only if the task type changes, the user explicitly asks, or you need a specific detail. Otherwise, keep applying the loaded guidance without announcing it.
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
