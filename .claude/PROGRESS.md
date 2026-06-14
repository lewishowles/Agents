# Claude config improvements — dual-target + manifest-driven build

**Started:** 2026-05-13
**Project:** `~/Dev/Configuration/Agents`
**Status:** active — Phases 21a, 21b, 21c, 21d, 21e complete (2026-06-14); parking lot next

---

## Critical decisions

| Decision                               | Rationale                                                                              |
| -------------------------------------- | -------------------------------------------------------------------------------------- |
| `rules/` + `dist/<agent>/`             | Editable source vs disposable generated output                                         |
| `skill.json`                           | Canonical skill metadata; avoids duplicated frontmatter truth                          |
| `SKILL.body.md` + generated `SKILL.md` | Body is editable; full skill file is generated                                         |
| Capability declarations                | Skills declare intent; adapters map supported capabilities                             |
| `hooks/claude/<name>/`                 | Hook source lives outside generated `dist/`                                            |
| `adapters/claude/settings.base.json`   | Editable settings source; generated settings lives in `dist/`                          |
| Skill grouping                         | `vue/`, `swift/`, `testing/`, `writing/`, `project-management/`                        |
| Per-skill/per-hook symlinks            | Coexists with plugin/system-installed items                                            |
| Skill prefix renames                   | Prefix-based autocomplete discoverability                                              |
| Codex skill links in `~/.codex/skills` | Current Codex builds discover user skills there; `~/.agents/skills` remains compatible |
| Progress path                          | This repo uses `.claude/PROGRESS.md`; root agent files are runtime/generated targets   |
| No global root-progress rule           | Other repos set their own canonical progress path in project `AGENTS.md`               |

---

## Architecture

Source: `rules/`, `skills/`, `hooks/`, `adapters/`.
Generated output: `dist/` — never author directly; regenerate with `scripts/sync.sh`.
Installed output: symlinks from `~/.claude/`, `~/.agents/`, `~/.codex/`.
Repo-maintenance state: `.claude/PROGRESS.md`.

**Validation target:** `scripts/validate.sh` exits 0; `scripts/sync.sh` exits 0 and is idempotent; `readlink ~/.claude/settings.json` → `dist/claude/settings.json`; editing a `.vue` file fires the data-driven vue skill reminder.

---

## Phase 21 — workflow alignment

Reduce recurring agent friction by improving rules, hooks, skills, and generated guidance.

Evidence comes from the 2026-06-13 session-history report plus firsthand failures while reconciling this roadmap. Root causes map to this repo, not the Vue Components library.

### Recommended order

**21a → 21b → 21e** first; 21c/21d after.

| Phase | Focus                                                                         | Depends |
| ----- | ----------------------------------------------------------------------------- | ------- |
| 21a   | Lower injection cost; fix autotrigger false positives; demote cbm enforcement | —       |
| 21b   | Scoped verification policy + debugging/testing skill alignment                | —       |
| 21e   | Plan-vs-do default                                                            | —       |
| 21c   | Stale artefact cleanup + agent-config skill refresh                           | 21a     |
| 21d   | Per-target rule filtering                                                     | 21a     |

---

## Phase 21a — hook injection + autotrigger false positives

### Purpose

Reduce per-prompt token cost and false enforcement. `cbm` currently ships through CLAUDE.md, `cbm-session-reminder`, and `cbm-code-discovery-gate`; keep one durable channel only. Also fix `skill-autotrigger`, which uses substring matching, not regex.

Principle: **one rule, one channel.** Hooks enforce deterministic actions; durable guidance lives in generated agent docs; avoid duplicate prose plus hooks.

### Evidence

- `cbm-code-discovery-gate` blocked `rg --files rules adapters hooks scripts skills`, a config/docs tree scan.
- `swift` loaded because `struct` matched `instructions`.
- `code-style` loaded on docs/planning due to generic triggers like `update`/`build`.
- `cbm-session-reminder` injects the full Code Discovery Protocol on every `UserPromptSubmit`.

### Implementation note

`hooks/claude/skill-autotrigger/skill-autotrigger.sh` uses:

```sh
[[ "$prompt_lower" == *"$trigger_lower"* ]]
```

So `\b` cannot fix it. Change matching strategy.

Short-token hazards: `struct`→`instructions`, `actor`→`factor`, `class`→`classic`, `enum`→`enumerate`, `add`→`address`, `build`→`rebuild`.

### Expected commits

- `feat(hooks): demote cbm enforcement and deduplicate per-prompt injection`
- `feat(hooks): replace substring matching in skill-autotrigger`
- `chore(skills): prune low-specificity prompt triggers`

### Files likely to change

- Delete `hooks/claude/cbm-code-discovery-gate/`; deregister from settings.
- Move `cbm-session-reminder` from `UserPromptSubmit` to `SessionStart`; one-line advisory only.
- Replace substring matching in `skill-autotrigger.sh` with word/token-aware matching.
- Prune `skills/code-style/skill.json` prompt triggers; prefer existing `filePatterns`.
- Prune ambiguous `skills/swift/swift/skill.json` triggers; keep high-specificity tokens (`swiftui`, `@mainactor`, `.swift`, `xcode`, etc.).
- Slim `skill-file-trigger` output to one line.
- Add session-scoped dedupe helper for reminder hooks.
- Regenerate `dist/claude/settings.json` and `docs/hooks.md`.

### Open decision

Should `code-style` drop prompt triggers entirely and rely on `filePatterns`? Proposed: yes.

### Tasks

- [x] Delete and deregister `cbm-code-discovery-gate`
- [x] Convert `cbm-session-reminder` to SessionStart-only
- [x] Add session-scoped dedupe helper (session file at `/tmp/claude-autotrigger-$PPID`)
- [x] Replace substring matching in `skill-autotrigger` with word-boundary ERE
- [x] Audit `skill.json` trigger arrays; remove ambiguous/generic tokens
- [x] Decide `code-style` prompt-trigger policy → drop all; rely on `filePatterns`
- [x] Slim injected hook messages (cbm-session-reminder one line; continuation gentle)
- [x] Regenerate settings/docs
- [x] Fix `setup-global.sh` to prune stale hook symlinks

### Risks

Over-tightening can stop useful skill loads. Keep catch-all continuation behaviour and spot-check common prompts. If cbm usage drops to zero, consider per-project opt-in only.

Keep unchanged: `auto-format`, `auto-allow-edits`, `progress-resume`, `plan-verify`, `pre-stop-checks`, `test-skeleton-reminder`.

---

## Phase 21b — scoped verification + skill alignment

### Purpose

Resolve the rules conflict: global token-budget guidance forbids tests while `pre-stop-checks` asks for evidence. Update both rules and high-frequency skills so agents run scoped verification instead of guessing or deferring.

Policy: agents may run lint/unit/repro commands scoped to touched files. Full suites, builds, and e2e remain user-run unless agreed.

### Expected commits

- `feat(rules): allow scoped lint and unit test runs`
- `feat(skills): align debugging and testing guidance with scoped verification`

### Files likely to change

- `rules/global-rules.md` — replace “do not run tests” with scoped-run policy.
- `skills/debugging/SKILL.body.md` — replace “ask the user” test deferrals with scoped repro/test guidance.
- `skills/testing/test/SKILL.body.md`, `skills/testing/test-unit/SKILL.body.md` — inspect/update equivalent deferrals.
- `hooks/claude/pre-stop-checks/pre-stop-checks.sh` — inspect wording; logic likely unchanged.
- Regenerate `dist/claude/CLAUDE.md`, `dist/codex/AGENTS.md`.

### Tasks

- [x] Update token-budget wording: scoped runs allowed; full/e2e/builds user-run
- [x] Rewrite debugging token-discipline notes
- [x] Inspect/update testing skill deferrals
- [x] Check `pre-stop-checks` wording
- [x] Regenerate dist outputs

### Risks

Too broad = agents run full suites. Too narrow = rule/skill contradiction persists. Skill rewrites are required, not optional.

### Notes

Measure before/after with `~/.claude/logs/friction.log` and `scripts/analyse-friction.sh` after a week.

---

## Phase 21e — plan-vs-do default

### Purpose

Stop implementation drift when the user asks for analysis, planning, review, roadmap editing, or recommendations. Pairs with 21a: safer triggers reduce unwanted skill loads; clearer scope prevents unwanted implementation.

### Expected commit

`feat(rules): add plan-vs-do scope default`

### Files likely to change

- `rules/global-rules.md` — add concise scope default under user interaction.
- Regenerate `dist/claude/CLAUDE.md`, `dist/codex/AGENTS.md`.

### Tasks

- [x] Inspect current interaction guidance
- [x] Add: default to analysis/plan/edit-only unless implementation is clearly requested
- [x] Confirm wording does not make agents passive on explicit implementation tasks
- [x] Avoid duplicating `plan-verify`
- [x] Regenerate dist outputs

### Risks

Over-broad wording can make agents passive. Keep the default narrow and intent-based.

---

## Phase 21c — stale artefact cleanup

### Purpose

After 21a, remove leftovers and refresh repo-local docs once against the final hook set.

**Depends on 21a.**

### Expected commit

`chore: remove targets leftover and refresh agent-config skill`

### Files likely to change

- `targets/` — delete via `trash` after confirming unreferenced/stale vs `dist/chatgpt`.
- `.claude/skills/agent-config/SKILL.md` — update repo tree, skill conventions, hook paths, settings path, post-21a hook list.

### Inspect

- `scripts/sync.sh`
- `scripts/build-chatgpt-target.py`
- `.agents/skills/agent-config` symlink

### Tasks

- [x] Confirm `targets/chatgpt` is unreferenced and stale/duplicated — was empty; `scripts/*` only reference `targets` as a JSON field in skill manifests
- [x] Trash `targets/`
- [x] Rewrite agent-config skill for current architecture
- [ ] Run `scripts/validate.sh` (user-run)

### Risks

`targets/chatgpt` may contain unmigrated manual edits; diff before trashing.

---

## Phase 21d — per-target rule filtering

### Purpose

Slim Claude output without weakening Codex. CLAUDE.md is ~216 lines; some prose duplicates hooks, but Codex lacks hooks. Add target markers so hook-enforced sections can be omitted from Claude while retained for Codex.

**Depends on 21a.**

### Expected commits

- `feat(sync): support per-target blocks in shared rules`
- `feat(rules): drop hook-enforced prose from Claude output`

### Files likely to change

- `scripts/sync.sh` or `scripts/lib` — marker filtering
- `rules/global-rules.md`, `rules/skills-policy.md`, `rules/file-discovery.md` — target markers
- `scripts/validate.sh` — assert marker text does not leak
- Regenerate Claude/Codex outputs

### Tasks

- [x] Implement marker filtering → chose direct condensation over marker syntax; simpler, no new infrastructure
- [x] Audit each rule section: keep, Claude-only, Codex-only, or shared
- [x] Review hook-enforced cuts before applying
- [x] Regenerate; aim for Claude output ~100–120 lines → 114 lines achieved

### Risks

A “hook-enforced” rule may contain nuance the hook lacks. Review before cutting. Cbm remains in both generated docs after 21a because it becomes the only channel.

---

## Phase 22 — compact skill source prose

### Purpose

Compact original `SKILL.body.md` files by removing words, not meaning. Preserve trigger intent, ordering constraints, examples, and effectiveness.

### Tasks

- [x] Group 1: compact largest/high-impact bodies (`vue-use`, `vue-pinia-colada`, `accessibility-audit`, `bash`, `vue-vite`)
- [x] Group 2: compact core frontend/runtime bodies (`vue`, `accessibility`, `web-performance`, `frontend-security`, `code-review`)
- [x] Group 3: compact language/testing/process bodies (`swift`, `swift-ui`, `typescript`, `test`, `test-unit`, `test-e2e`, `debugging`, `refactoring`, `error-handling`, `code-style`, `dependencies`, `codebase-memory`)
- [x] Group 4: compact writing/project-management and small remaining bodies
- [x] Regenerate generated outputs after group 1
- [x] Regenerate generated outputs after group 2
- [x] Regenerate generated outputs after group 3
- [x] Regenerate generated outputs after group 4

### Notes

`scripts/sync.sh` passed after groups 1, 2, 3, and 4.

---

## Parking lot

- Model-tiering guidance once 21d filtering exists.
- `.claudeignore` templates for heavy projects.
- Memory tooling: claude-mem/rocky removed; revisit only if codebase-memory-mcp leaves a gap.
- Per-project cbm opt-in if SessionStart-only advisory kills useful graph usage.
- Vue/docs skill note: escape or split literal `</script>` inside SFC Markdown fences.
- Component library guidance: add one line to that repo’s `AGENTS.md` saying progress is root `PROGRESS.md`, not `.claude/PROGRESS.md`.
- Ad-hoc staged commits: clarify commit grouping when no PROGRESS plan exists.
- Task-agent spike for locating long-file sections without line-offset churn.

---

## Rejected / deferred report suggestions

| Suggestion                                       | Decision                                                                                        |
| ------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| Pin root `PROGRESS.md` globally                  | Rejected. This repo intentionally uses `.claude/PROGRESS.md`; other repos set their own path.   |
| Always re-read every edited file                 | Rejected. Tooling already reports failed edits; blanket rereads waste tokens.                   |
| PostToolUse lint after every edit                | Deferred. Likely over-fires and duplicates `pre-stop-checks`; revisit after 21b only if needed. |
| Autonomous cross-repo propagation/refactor loops | Parking lot only.                                                                               |
| Component-library package/publish/metadata work  | Out of scope for this repo.                                                                     |

---

## Archived milestones

### Phases 0–9 (2026-05-13 to 2026-05-28)

Dual-target setup, sync infrastructure, and ecosystem expansion complete: `rules/` + `dist/`; `sync.sh`; global/project setup scripts; templates; README/docs rewrite; end-to-end validation; repo renamed to `~/Dev/Configuration/Agents`; Vue skills refreshed; external skill sync added.

### Phases 10–18 (2026-05-28 to 2026-06-11)

Manifest-driven refactor complete: `shared/`→`rules/`, `targets/`→`dist/`; grouped skills; all 33 skills use `skill.json` + `SKILL.body.md`; hook source moved to `hooks/claude/<name>/`; settings, ChatGPT/global skill indexes, and docs tables generate from manifests. Phase 16b renamed 14 skills. Phase 17 linked Codex skills into `~/.codex/skills`. Phase 18 added `scripts/build-docs.py`.

### Phase 19 (2026-06-11)

Docs generation hardened: hook manifest descriptions, generated hook purpose docs, merged duplicate file-trigger patterns, edit-source comments, and stale-doc checks via `scripts/build-docs.py --check` / `scripts/validate.sh`.

### Phase 20 (2026-06-11)

Project-management skill manifests gained explicit `title`; generated frontmatter emits Codex-compatible `displayName` from `title` only when present.
