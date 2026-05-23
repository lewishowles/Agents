# Claude config improvements — dual-target (Claude + Codex)

**Started:** 2026-05-13
**Project:** `~/Dev/Configuration/Agents`
**Status:** complete for dual-target phases and deferred hooks
**Current priority:** Final cleanup and release

## Legend

- `[ ]` not started
- `[~]` in progress
- `[x]` done
- `[-]` skipped/superseded (with reason)

## Progress conventions

- Checklist items track deliverables or behaviour changes, not progress-file maintenance.
- Put validation under the relevant section's `**Validation:**` block instead of as standalone checklist work.
- Put progress updates in `## Session notes` after the relevant work is complete.

---

## Confirmed Codex behaviour (verified by Lewis)

- **Global rules:** `~/.agents/AGENTS.md` (or `AGENTS.override.md` first if present)
- **Project rules:** walks root → cwd for `AGENTS.override.md` then `AGENTS.md`. Root `AGENTS.md` (real file or symlink) covers both runtimes. `project_doc_fallback_filenames` in `~/.agents/config.toml` works in 0.130.0-alpha.5 but treat as unstable.
- **Skills:** This machine's active Codex setup has core user skills in `~/.agents/skills/`, so this repo uses `~/.agents/skills/<name>` for global symlinks and `.agents/skills/` for project-local Codex skills. Frontmatter `name`+`description` visible upfront; full skill loaded on use. Implicit matching weights description heavily.
- **Skill discovery:** description-driven, not slash-command. `Use this skill when` + action-led wording + file globs inline = better matching.
- **Hooks:** Codex hooks exist (developers.openai.com/codex/hooks) but parity out of scope. Skill descriptions carry discovery weight.

---

## Critical decisions

| Decision | Rationale |
|---|---|
| `shared/` + `targets/<agent>/` structure | Single source of truth; agent outputs grouped; hooks move out of root |
| Per-skill, per-hook symlinks (not whole folder) | Coexists with plugin/system-installed skills in `~/.agents/skills/` and `~/.claude/skills/` |
| Root `AGENTS.md` always real file or symlink | Both Claude and Codex read root `AGENTS.md` — one file covers both runtimes |
| `sync.sh` composes from `shared/` | No manual sync between agent files; one place to edit shared rules |
| Interactive default, `--claude/--codex/--both` flags | Accessible for first-time use; flags for repeat runs |
| Repo rename only after Phase 8 validates end-to-end | Avoid disruption during implementation; rename is symbolic milestone |

---

## Dual-target phases (current priority)

### Phase 0 — Capture dual-target plan

- [x] **0.1** Rewrite `.claude/AGENTS.md` for dual-target purpose, structure, Codex behaviour
- [x] **0.2** Capture the dual-target phases and mark old Phase 6 superseded

**Working state:** Documentation only. No functional change.

---

### Phase 1 — Skill descriptions + rename `claude-config` → `agent-config`

- [x] **1.1** Rewrite `description` in all 19 `skills/*/SKILL.md` — `Use this skill when` prefix, action-led wording, file globs inline, pair-skill mentions
- [x] **1.2** Rename `claude-config` → `agent-config`; broaden content scope to "agent config repo (Claude + Codex)"
- [x] **1.3** Update `hooks/skill-autotrigger.sh` line 50 (continuation list) and line 182 (`claude-config` block)
- [x] **1.4** Update `hooks/skill-file-trigger.sh` lines 67–69 (`claude-config` paths)
- [x] **1.5** Update `settings.json` — `skillOverrides` key `claude-config` → `agent-config`
- [x] **1.6** Update `CLAUDE.md` skills list — `/claude-config` → `/agent-config`
- [x] **1.7** Update `docs/skills.md`, `docs/commands.md`, `docs/hooks.md` — rename references

**Working state:** Claude works with renamed skill and tighter descriptions. Auto-trigger keys updated. No Codex changes yet.

**Validation:**
- `/agent-config` slash command works; `claude-config` no longer exists
- Auto-trigger fires `agent-config` for matching prompts
- Spot-check 3 random skill descriptions for `Use this skill when`, action-led wording, and file globs

---

### Phase 2 — Add `## File discovery` + `## Skill use policy` to `CLAUDE.md`

- [x] **2.1** Add `## Skill use policy` block to `CLAUDE.md`:
  > Skills are authoritative when their trigger conditions match. Before coding, editing prose, changing config, or reviewing files, inspect the task and file paths, then load and use every matching skill. If multiple skills match, use all relevant skills — especially `code-style` plus language/framework skills. Do not wait for explicit slash-command invocation.
- [x] **2.2** Add `## File discovery` block to `CLAUDE.md`:
  > Do not inspect generated, vendored, cached, build, dependency, or large binary directories unless explicitly asked. Prefer `rg` / `rg --files`, which respects `.gitignore` and `.rgignore`. Avoid `find`, broad `ls -R`, or reading ignored paths such as `node_modules`, `dist`, `build`, `.git`, coverage, caches, lockfile-heavy generated output, and local secrets.

**Working state:** Claude immediately benefits. Codex inherits when wired in Phase 3.

**Validation:** Both sections present in `CLAUDE.md`.

---

### Phase 3 — Restructure: `shared/` + `targets/<agent>/` + `scripts/sync.sh`

⚠️ Ship Phase 3 + Phase 4 together. When `hooks/` and `settings.json` move, the existing `~/.claude/hooks` symlink (whole folder) and `~/.claude/settings.json` reference break. Phase 4 setup script re-creates per-item symlinks pointing to new paths.

- [x] **3.1** Create `shared/global-rules.md` — extract General config, Think before coding, When expectations break, Simplicity first, Surgical changes, Communication, Git from `CLAUDE.md`
- [x] **3.2** Create `shared/skills-policy.md` — Phase 2 skill use policy block
- [x] **3.3** Create `shared/file-discovery.md` — Phase 2 file discovery block
- [x] **3.4** Create `shared/identity.md` — Identity & expertise block from `CLAUDE.md`
- [x] **3.5** Create `scripts/lib/colours.sh` — `${GREEN}`, `${PURPLE}`, `${YELLOW}`, `${RED}`, `${RESET_COLOUR}`
- [x] **3.6** Create `scripts/sync.sh` — deterministic concatenation from editable source fragments; composes `targets/claude/CLAUDE.md` (shared + Claude-specific fragments) and `targets/codex/AGENTS.md` (shared + Codex-specific fragments)
- [x] **3.7** Move `hooks/*` → `targets/claude/hooks/`
- [x] **3.8** Move `settings.json` → `targets/claude/settings.json`
- [x] **3.9** Delete root `CLAUDE.md` (superseded by `targets/claude/CLAUDE.md`)

**Working state:** `sync.sh` runs cleanly. Until Phase 4 setup script runs, existing symlinks are broken — include migration note in commit.

**Validation:** `scripts/sync.sh` exits 0; `targets/claude/CLAUDE.md` content equivalent to pre-Phase-3 effective rules + new sections; `targets/codex/AGENTS.md` exists and reads cleanly.

---

### Phase 4 — `scripts/setup-global.sh` + fix `~/.claude/settings.json` drift

- [x] **4.1** Create `scripts/setup-global.sh` with `--claude | --codex | --both`
  - No flag → interactive prompt: "Which agent(s)? [1] Claude  [2] Codex  [3] Both"
  - Self-discovers repo via `REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)`
  - Idempotent; re-run reports `↪ already linked` for unchanged
  - Fail-fast on first error; partial results not rolled back (they're symlinks)
- [x] **4.2** `--claude` symlinks: `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, `~/.claude/skills/<name>` ×19, `~/.claude/hooks/<file>` per-hook — all → `repo/targets/claude/`
- [x] **4.3** `--codex` symlinks: `~/.agents/AGENTS.md` → `repo/targets/codex/AGENTS.md`; `~/.agents/skills/<name>` ×19 → `repo/skills/<name>`
- [x] **4.4** Backup strategy (never overwrites, never deletes):
  - Doesn't exist → create symlink → `✓ linked <name>`
  - Symlink → correct repo path → skip → `↪ already linked <name>`
  - Symlink → elsewhere → move to `<path>.bak.<YYYYMMDD-HHMMSS>`, create new → `⟳ relinked <name>`
  - Real file, no `.bak` → move to `<path>.bak`, create symlink → `⟳ replaced <name> (backup at <bak>)`
  - Real file, `.bak` exists → move to `<path>.bak.<YYYYMMDD-HHMMSS>`, create symlink → `⟳ replaced <name> (backup at <bak>.<timestamp>)`
  - Runtime-scanned skills/hooks back up under `~/.claude/backups/` or `~/.agents/backups/` so stale backups are not loaded as active skills
- [x] **4.5** Specific drift fix: `~/.claude/settings.json` is currently a real file with `.bak` from 2026-05-14 11:15. Script moves it to `.bak.<timestamp>`, creates symlink → `repo/targets/claude/settings.json`.
- [x] **4.6** Update README with global setup instructions and aliases

**Working state:** Fresh install or migration from old layout — both work via one command. Settings.json drift fixed.

**Validation:** `setup-global.sh --claude` creates per-skill, per-hook symlinks; `~/.claude/settings.json` is a symlink; re-run is idempotent; backups exist for any pre-existing real files.

---

### Phase 5 — `scripts/setup-project.sh`

- [x] **5.1** Create `scripts/setup-project.sh` with `--claude | --codex | --both`; no flag → interactive prompt; skip existing files (no overwrite)
- [x] **5.2** `--claude`: `cp templates/claude/AGENTS.md.template AGENTS.md`; `mkdir -p .claude/`; copy `templates/claude/settings.json`, `templates/claude/.claudeignore`, `templates/PLAN.md.template` → `.claude/templates/`
- [x] **5.3** `--codex`: `cp templates/codex/AGENTS.md.template AGENTS.md`; `mkdir -p .agents/skills`
- [x] **5.4** `--both`: `cp templates/shared/AGENTS.md.template AGENTS.md`; `mkdir -p .claude/`; copy Claude `.claude/` layout; `mkdir -p .agents/skills`

**Working state:** Per-project setup for Claude, Codex, or both via one command. Existing project files are skipped, not overwritten or backed up.

**Validation:** `tests/setup-project.sh` covers each flag in a fresh dir plus re-run skip behaviour.

---

### Phase 6 — Templates filled in

- [x] **6.1** Write `templates/claude/AGENTS.md.template` — project-specific, Claude framing
- [x] **6.2** Write `templates/codex/AGENTS.md.template` — project-specific, Codex framing; no Claude-only references
- [x] **6.3** Write `templates/shared/AGENTS.md.template` — neutral, both runtimes
- [x] **6.4** Move `templates/settings.json` → `templates/claude/settings.json`
- [x] **6.5** Move `templates/.claudeignore` → `templates/claude/.claudeignore`

**Working state:** All `setup-project.sh` flag combinations have valid template inputs.

**Validation:** `tests/setup-project.sh` verifies the selected template marker for Claude, Codex, and both.

---

### Phase 7 — Documentation pass

- [x] **7.1** Rewrite `README.md` — three setup paths (Claude / Codex / both); single-source-of-truth model; alias setup snippet
- [x] **7.2** Create `docs/setup.md` — manual setup steps as fallback
- [x] **7.3** Create `docs/codex.md` — `~/.agents/config.toml` schema, skill loading, hook absence note (link to OpenAI hooks docs as future work), plugin parity notes
- [x] **7.4** Update `docs/hooks.md` — banner: "Claude-only. Codex hooks exist but parity out of scope; skill descriptions carry discovery weight instead."
- [x] **7.5** Update `docs/skills.md` — auto-trigger (Claude) vs description-driven (Codex); note descriptions written for both
- [x] **7.6** Update `docs/plugins.md` — banner Claude-only; Codex marketplace exists
- [x] **7.7** Update `docs/commands.md` — rename `/claude-config` → `/agent-config` (completed in Phase 1)
- [x] **7.8** Update `docs/agents.md` — Claude agents only; note distinct from Codex top-level "agents" concept

**Validation:** README links `docs/codex.md`; stale-template-path scan returned no matches.

---

### Phase 8 — End-to-end validation

- [x] **8.1** Run `setup-global.sh --both` on this machine. Verify all symlinks per topology table. Verified `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, `~/.agents/AGENTS.md`, 19 Claude skill symlinks, 6 Claude hook symlinks, and 19 Codex skill symlinks.
- [-] **8.2** Backup `~/.claude/` and `~/.agents/AGENTS.md`. Run script in clean state. Verify same result. Restore. — skipped per Lewis: current setup is fresh; no separate backup/restore validation needed.
- [x] **8.3** In fresh test project: `setup:agents --claude`, then `--codex`, then `--both` — three separate test projects. Verify file layouts. Validated in `/private/tmp/agent-setup-validation.H6aRj1`.
- [x] **8.4** Open Claude in test project — confirms CLAUDE.md + skill descriptions load correctly. Verified global Claude rules and `code-style` skill are available; Claude reads project `AGENTS.md` when following global instructions, not by automatic discovery.
- [x] **8.5** Open Codex in test project — confirms AGENTS.md + skills visible. Verified project `AGENTS.md`, global Codex rules, and `code-style` skill. Fixed strict YAML frontmatter parsing by converting skill descriptions to block scalars; moved stale `*.bak` skill directories out of active scan paths.
- [x] **8.6** Run `scripts/sync.sh` after editing `shared/global-rules.md`. Diff both targets — confirm both update. Added the scoped commit-message rule to shared rules and verified it appears in both generated targets.

**Working state:** Confidence to ship. Both runtimes verified end-to-end.

---

### Phase 9 — Repo rename `Configuration/Claude` → `Configuration/Agents`

Only after Phase 8 passes.

- [x] **9.1** `mv ~/Dev/Configuration/Claude ~/Dev/Configuration/Agents`
- [-] **9.2** Update git remote URL if changed on hosting side — skipped; remote still points at `https://github.com/lewishowles/Claude.git`
- [x] **9.3** Update README references to new path — no hard-coded old repo path remained in README
- [x] **9.4** Update aliases in `~/.zshrc` — updated sourced zsh config helpers in `~/Dev/Configuration/zsh/`
- [x] **9.5** Re-run `setup-global.sh --both` — updates all symlinks to new repo path
- [x] **9.6** Update `.claude/skills/agent-config/SKILL.md` repo path reference
- [x] **9.7** Update `.claude/AGENTS.md` path references

**Working state:** Final form. Repo name reflects content.

---

## Key files

| Phase | File | Change |
|---|---|---|
| 0 | `.claude/AGENTS.md`, `.claude/PROGRESS.md` | Dual-target documentation |
| 1 | `skills/*/SKILL.md` (×19) | Tighten descriptions |
| 1 | `claude-config` skill | Rename → `agent-config`; broaden content |
| 1 | `hooks/skill-autotrigger.sh` | Lines 50, 182 — rename |
| 1 | `hooks/skill-file-trigger.sh` | Lines 67–69 — rename |
| 1 | `settings.json` | `skillOverrides` rename key |
| 1 | `CLAUDE.md` | Skill list rename |
| 1 | `docs/skills.md`, `docs/commands.md`, `docs/hooks.md` | Rename references |
| 2 | `CLAUDE.md` | Add `## Skill use policy` and `## File discovery` |
| 3 | `shared/*.md` | New — extracted shared content |
| 3 | `targets/claude/source/codebase-memory.md`, `targets/codex/source/codebase-memory.md` | Agent-specific codebase-memory guidance composed into generated targets |
| 3 | `targets/claude/CLAUDE.md`, `targets/codex/AGENTS.md` | New — composed by sync.sh |
| 3 | `targets/claude/hooks/*` | Moved from `hooks/` |
| 3 | `targets/claude/settings.json` | Moved from repo root |
| 3 | `scripts/sync.sh`, `scripts/lib/colours.sh` | New |
| 3 | `CLAUDE.md` (root) | Deleted |
| 4 | `scripts/setup-global.sh` | New |
| 5 | `scripts/setup-project.sh` | New |
| 6 | `templates/claude/`, `templates/codex/`, `templates/shared/` | Restructure + new Codex template |
| 7 | `README.md`, `docs/*` | Rewrite for dual-target |
| 9 | Repo directory | Rename to `Configuration/Agents` |

---

## Script output style

All scripts load from `scripts/lib/colours.sh`. Blank line before/after each section header.

```
→ Setting up Claude (global)

  ✓ linked CLAUDE.md
  ✓ linked skills/vue
  ⟳ replaced settings.json (backup at ~/.claude/settings.json.bak)

→ Setting up Codex (global)

  ✓ linked AGENTS.md
  ✓ linked skills/vue

Done.
```

---

## Deferred phases (Writ-inspired — queued, not blocking dual-target)

### Old Phase 1 — Foundation [x]

- [x] Create `.claude/PROGRESS.md`
- [x] Add skill/hook maintenance rules to `claude-config` skill
- [x] Create `templates/PLAN.md.template`
- [x] Add progress tracking workflow to `session-management` skill

### Old Phase 2 — Slim CLAUDE.md [x]

- [x] Audit and classify CLAUDE.md rules
- [x] Move token efficiency + goal-driven execution → `session-management`
- [x] Remove communicating-with-humans detail

**Validation:** Line count verified at 100 lines, down from 141.

### Old Phase 3 — Plan verify + progress-resume hooks [x]

- [x] Write `hooks/plan-verify.sh` (PostToolUse:ExitPlanMode)
- [x] Write `hooks/progress-resume.sh` (UserPromptSubmit)
- [x] Register both in `settings.json`
- [x] Document in `docs/hooks.md`

**Validation:** `plan-verify.sh` warns when the latest plan lacks `## Validation` and stays silent when that section exists. `progress-resume.sh` injects `.claude/PROGRESS.md` for continue-intent prompts and stays silent when no progress file exists.

### Old Phase 4 — Friction logging [x]

- [x] Add friction log write to `pre-stop-checks.sh` — appends timestamp, project path, failed checks, and first error line to `~/.claude/logs/friction.log`
- [x] Write `scripts/analyse-friction.sh` — parses log, shows top friction causes

**Validation:** `tests/friction-logging.sh` covers failed lint/unit checks creating a log line, successful checks leaving no log, and analyser grouping by project/check/error summary.

### Old Phase 5 — PreWrite test-skeleton reminder [x]

- [x] Write `hooks/test-skeleton-reminder.sh` — detects test-enabled projects and reminds on implementation writes when no matching test file exists
- [x] Register in `settings.json`

**Validation:** `tests/test-skeleton-reminder.sh` covers a Vitest implementation write without a sibling test emitting a reminder, an existing sibling test staying silent, test files staying silent, and projects without a recognised test stack staying silent.

### Old Phase 6 — install.sh [-] superseded

Superseded by `scripts/setup-global.sh` (dual-target Phase 4). Per-skill, per-hook symlinks are a strict improvement over the old whole-folder approach.

---

## Architecture

Enforcement stays in hooks, not prompts. `shared/` is single source of truth for rules. `sync.sh` composes agent-specific outputs deterministically. Setup scripts handle both runtimes from one entry point with a consistent backup strategy.

Progress tracking is flow-driven (updated at task completion), not session-driven — `SessionEnd` doesn't fire reliably when conversations are archived in the desktop app. Progress updates and validation notes are part of the relevant work section, not separate checklist items.

After each completed phase or coherent implementation step, provide a scoped Conventional Commit message as plain text only. Label it `Suggested commit message:` and do not execute it.

## Validation (end-to-end)

Clone repo to clean machine, run `setup:agents:global --both`, then `cd` to a fresh project and run `setup:agents --both`. Both runtimes pick up global rules and project-local instructions.

## Session notes

### 2026-05-13
**Completed:** Old phases 1 & 2 — PROGRESS.md, PLAN.md.template, claude-config skill maintenance rules, session-management skill expanded, CLAUDE.md slimmed 141→100 lines, autotrigger updated
**Completed (session 2):** Old phase 3 — `plan-verify.sh`, `progress-resume.sh`, registered in settings.json, docs/hooks.md updated
**Next:** Old phase 3.5–3.6 tests; dual-target phases 0–9

### 2026-05-14
**Completed:** Phase 0 — `.claude/AGENTS.md` and `.claude/PROGRESS.md` rewritten to capture dual-target plan in full
**Completed (session 2):** Phase 1 — all skill descriptions rewritten with `Use this skill when`, action-led discovery, and file globs; `claude-config` renamed to `agent-config`; hooks/settings/docs updated
**Completed (session 3):** Phase 2 — added `## Skill use policy` and `## File discovery` to `CLAUDE.md`
**Completed (session 4):** Phases 3 and 4 — restructured into `shared/` and `targets/<agent>/`, added `scripts/sync.sh`, moved Claude hooks/settings, removed root `CLAUDE.md`, added global setup script
**Completed (session 4 follow-up):** Refactored `scripts/sync.sh` to join editable source fragments instead of embedding generated prose in the script; clarified project-local `AGENTS.md` template paths in generated Claude and Codex headers
**Next:** Phase 5 — create `scripts/setup-project.sh`

### 2026-05-15
**Completed:** Phases 5, 6, and 7 — added `scripts/setup-project.sh`, split project templates into `templates/claude`, `templates/codex`, and `templates/shared`, added shell tests, rewrote README, added setup and Codex docs, and updated docs banners for Claude-only hooks/plugins/agents
**Validation:** `bash -n scripts/setup-project.sh`; `bash -n scripts/setup-global.sh`; `tests/setup-project.sh`; stale-template-path `rg` scan
**Next:** Phase 8 — run end-to-end global and fresh-project validation, including real symlink topology checks

**Completed (session 2):** Phase 8.1 and 8.3 — ran `scripts/setup-global.sh --both`, verified Claude/Codex global symlinks, skipped clean-state backup validation per Lewis, and validated `setup-project.sh` layouts in three fresh temporary projects
**Validation:** `readlink ~/.claude/CLAUDE.md`; `readlink ~/.claude/settings.json`; `readlink ~/.agents/AGENTS.md`; counted 19 Claude skill links, 6 Claude hook links, 19 Codex skill links; checked fresh `--claude`, `--codex`, and `--both` project layouts
**Next:** Phase 8.4/8.5 — launch Claude and Codex in test projects to confirm each runtime loads the generated rules and skills

**Completed (session 3):** Phase 8.4 and 8.5 — validated Claude non-interactive startup with global rules, `code-style`, and project `AGENTS.md` read-through; validated Codex non-interactive startup with project `AGENTS.md`, global rules, and `code-style`
**Validation fixes:** Converted all skill frontmatter descriptions to YAML block scalars for Codex; updated setup backups for runtime-scanned skills/hooks to live under `backups/`; moved stale `~/.agents/skills/*.bak` directories out of the active scan path
**Next:** Phase 8.6 — edit `shared/global-rules.md`, run `scripts/sync.sh`, and confirm both generated targets update

**Completed (session 4):** Phase 8.6 — added the scoped commit-message rule to `shared/global-rules.md`, ran `scripts/sync.sh`, and confirmed both generated targets received the change
**Validation:** `rg` found the new rule in `shared/global-rules.md`, `targets/claude/CLAUDE.md`, and `targets/codex/AGENTS.md`; `git diff` shows matching generated target updates
**Next:** Phase 9 — rename repo to `Configuration/Agents` and refresh symlinks/paths

**Completed (session 5):** Phase 9 — renamed repo to `~/Dev/Configuration/Agents`, refreshed Claude/Codex symlinks, updated agent-config and `.claude/AGENTS.md` path references, and updated sourced zsh setup helpers
**Validation:** old repo path absent; global symlinks point to `Configuration/Agents`; 19 Claude and 19 Codex skill symlinks present; remote unchanged at `lewishowles/Claude.git`
**Next:** Deferred hook validation or commit final dual-target work

**Completed (session 6):** Follow-up cleanup — removed generated backup skill files, removed compressed-mode plugin references from repo-managed docs/settings/templates, and kept `agent-config` as a repo-local skill shared between `.claude/skills` and `.agents/skills`
**Validation:** no active references to the removed plugin wording; no backup skill files remain; JSON/YAML parsing passes; setup scripts parse; setup-project tests pass; agent-config Codex symlink resolves
**Next:** Commit cleanup work or revisit deferred hooks

**Completed (session 7):** Removed the broad Claude presence gate from the repo and active `~/.claude/hooks`; it was no longer registered in settings but still existed as a linked hook file
**Validation:** no remaining references to the removed hook; active `~/.claude/hooks` contains 6 links; setup scripts parse; setup-project tests pass
**Next:** Commit cleanup work or revisit deferred hooks

**Completed (session 8):** Removed repo-managed references to the memory plugin ahead of uninstall, including settings, templates, docs, credits, and session-management recommendations
**Validation:** no remaining repo references to the removed memory plugin; JSON/YAML parsing passes; setup scripts parse; setup-project tests pass
**Next:** Commit cleanup work or revisit deferred hooks

**Completed (session 9):** Captured the graph-memory sections added by the plugin as source fragments and wired them into `scripts/sync.sh`, so `targets/claude/CLAUDE.md` and `targets/codex/AGENTS.md` rebuild with those sections instead of carrying manual target-only edits
**Validation:** `scripts/sync.sh` rebuilds both targets; `bash -n scripts/sync.sh`; `rg` confirms the Claude and Codex graph-memory sections appear in their generated targets and source fragments
**Next:** Commit cleanup work or revisit deferred hooks

**Completed (session 10):** Validated deferred hook tests 3.5 and 3.6 for `plan-verify.sh` and `progress-resume.sh`
**Validation:** Temporary hook harness confirmed missing `## Validation` warns, present validation is silent, continue-intent with `.claude/PROGRESS.md` injects content, and continue-intent without progress is silent
**Next:** Deferred friction logging or pre-write test-skeleton gate

**Completed (session 11):** Added friction logging to `pre-stop-checks.sh` and added `scripts/analyse-friction.sh`
**Validation:** `tests/friction-logging.sh`; `bash -n targets/claude/hooks/pre-stop-checks.sh`; `bash -n scripts/analyse-friction.sh`; `tests/setup-project.sh`
**Next:** Deferred pre-write test-skeleton gate

**Completed (session 12):** Added `test-skeleton-reminder.sh` and registered it for Claude `Write|Edit` hooks
**Validation:** `tests/test-skeleton-reminder.sh`; `bash -n targets/claude/hooks/test-skeleton-reminder.sh`; `jq empty targets/claude/settings.json`; `tests/setup-project.sh`
**Next:** Final cleanup, commit, and push

**Completed (session 13):** Removed stale session-note text from `docs/skills.md` and updated progress status now that deferred hooks are complete
**Validation:** current progress status reflects completed dual-target and deferred hook work
**Next:** Commit and push the completed maintenance work
