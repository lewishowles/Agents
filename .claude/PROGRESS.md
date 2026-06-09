# Claude config improvements — dual-target + manifest-driven build

**Started:** 2026-05-13
**Project:** `~/Dev/Configuration/Agents`
**Status:** in progress — manifest-driven refactor (Phase 10 of 17)

## Legend

- `[ ]` not started
- `[~]` in progress
- `[x]` done
- `[-]` skipped/superseded (with reason)

---

## Critical decisions

| Decision                                                                        | Rationale                                                                                              |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `rules/` + `dist/<agent>/` structure                                            | Editable source vs disposable generated output; names communicate intent                               |
| `skill.json` as canonical metadata source                                       | Separation: metadata (JSON) vs instructions (Markdown); avoids duplicate truth in SKILL.md frontmatter |
| `SKILL.body.md` + generated `SKILL.md`                                          | SKILL.body.md is editable; SKILL.md is generated from skill.json + body                                |
| Capability declarations in skill.json (not hook names)                          | Skills declare intent; Claude adapter maps to hooks; Codex/ChatGPT can ignore unsupported capabilities |
| Hook source in `hooks/claude/<name>/` not `dist/`                               | Generated output is not source; hook scripts authored once, copied into dist by sync.sh                |
| `settings.base.json` in `adapters/claude/`                                      | Editable settings source not in `dist/`; settings.json = base + generated hooks block                  |
| Skill grouping: `vue/`, `swift/`, `testing/`, `writing/`, `project-management/` | Related skills navigable; build scripts handle one level of nesting                                    |
| Data-driven hooks (Phase 14) not deferred                                       | Most valuable part of refactor; regression risk mitigated by fixture tests                             |
| Per-skill, per-hook symlinks (not whole folder)                                 | Coexists with plugin/system-installed skills in `~/.agents/skills/` and `~/.claude/skills/`            |
| `sync.sh` composes from `rules/`                                                | No manual sync between agent files; one place to edit shared rules                                     |

---

## Completed work (2026-05-13 to 2026-05-28)

Phases 0–9 complete. Summary:

- **Phase 0:** Dual-target planning and documentation
- **Phase 1:** Skill descriptions rewritten; `claude-config` renamed to `agent-config`; hooks/settings/docs updated
- **Phase 2:** `## Skill use policy` and `## File discovery` added to `CLAUDE.md`
- **Phase 3:** Restructured into `rules/` (was `shared/`) and `dist/<agent>/` (was `targets/`); `sync.sh` introduced; hooks and settings moved to `dist/claude/`
- **Phase 4:** `scripts/setup-global.sh` — per-skill, per-hook symlinks; idempotent; backup strategy
- **Phase 5:** `scripts/setup-project.sh` with `--claude`, `--codex`, `--both`
- **Phase 6:** Templates split into `templates/claude/`, `templates/codex/`, `templates/shared/`
- **Phase 7:** README rewritten; `docs/setup.md`, `docs/codex.md` added; docs banners for Claude-only features
- **Phase 8:** End-to-end validation — both runtimes verified; Codex YAML frontmatter fixed
- **Phase 9:** Repo renamed to `~/Dev/Configuration/Agents`; symlinks refreshed; aliases updated
- **Old phase 3.5–3.6:** Hook tests validated (`plan-verify.sh`, `progress-resume.sh`)
- **Old phase 4:** Friction logging added to `pre-stop-checks.sh`; `scripts/analyse-friction.sh`
- **Old phase 5:** `test-skeleton-reminder.sh` added
- **2026-05-28:** Vue ecosystem skills refreshed; external skill sync added; `vueuse-functions`, Pinia, Vue Router skills added

---

## Active work — manifest-driven refactor

### Phase 10 — Rename source/output directories

- [x] **10.1** Rename `shared/` → `rules/`, `targets/` → `dist/`
- [x] **10.2** Update all path references in scripts, docs, tests, `.claude/`
- [x] **10.3** Compact `.claude/PROGRESS.md`
- [x] **10.4** Re-run `scripts/setup-global.sh --both` to refresh symlinks

**Validation:** `bash -n scripts/sync.sh`; `scripts/sync.sh` exits 0; `readlink ~/.claude/CLAUDE.md` resolves under `dist/claude/`.

**Commit:** `refactor: rename shared/ → rules/ and targets/ → dist/`

---

### Phase 11 — Skill restructuring

- [x] **11a.1** Delete `skills/architecture-decision-records/`, `skills/agentic-engineering/`, `skills/session-management/`
- [x] **11a.2** Remove their `skillOverrides` entries from `dist/claude/settings.json`
- [x] **11a.3** Remove their entries from `dist/claude/source/global-skills.md`
- [x] **11a.4** Check `dist/claude/hooks/skill-autotrigger.sh` for stale trigger references

**Commit:** `chore(skills): remove architecture-decision-records, agentic-engineering, and session-management`

- [x] **11b.1** Create `skills/project-management/setup-project/` with `SKILL.body.md`
- [x] **11b.2** Create `skills/project-management/continue-project/` with `SKILL.body.md`
- [x] **11b.3** Create `skills/project-management/plan-task/` with `SKILL.body.md`
- [x] **11b.4** Create `skills/project-management/compact-progress/` with `SKILL.body.md`
- [x] **11b.5** Create `skills/project-management/archive-progress/` with `SKILL.body.md`
- [x] **11b.6** Add `skillOverrides` entries (name-only) for new skills in `dist/claude/settings.json`
- [x] **11b.7** Add entries to `dist/claude/source/global-skills.md`

**Commit:** `feat(skills): add project-management skill group`

- [x] **11c.1** Move 15 skills into group folders (vue ×7, swift ×2, testing ×3, writing ×3)
- [x] **11c.2** Update `scripts/setup-global.sh` to discover skills at `skills/<name>/` and `skills/<group>/<name>/`
- [x] **11c.3** Update `scripts/build-chatgpt-target.py` and `scripts/sync.sh` to iterate both path depths
- [x] **11c.4** Add `"group"` field to `external-skills.json`; update `sync-external-skills.sh` to use grouped path

**Commit:** `refactor(skills): group vue, swift, testing, and writing skills into category folders`

---

### Phase 12 — Skill manifests and generated SKILL.md

- [x] **12a.1** Add `skill.json` to all 33 skills (schema: name, description, triggers, filePatterns, pathPatterns, dependencies, capabilities)
- [x] **12a.2** Project-management skills have `skill.json` (promptTriggering: false — name-only invocation)

**Commit:** `feat(skills): add skill.json manifests to all skills`

- [x] **12b.1** Add `do-not-use-when` to 7 `skill.json` files; bootstrap `SKILL.body.md` by stripping frontmatter from existing `SKILL.md`
- [x] **12b.2** Write `scripts/build-skill-mds.py`; call from `sync.sh` as first build step
- [x] **12b.3** Update `scripts/build-chatgpt-target.py` to read from `skill.json` instead of parsing `SKILL.md` frontmatter
- [x] **12b.4** `# Generated` comment in every `SKILL.md`; `.gitattributes` marks `skills/*/SKILL.md` as generated
- [x] **12b.5** Update `scripts/sync-external-skills.sh` to write stripped body to `SKILL.body.md`

**Commit:** `refactor(build): split SKILL.body.md from SKILL.md; generate SKILL.md via sync.sh`

---

### Phase 13 — Hook source structure

- [x] **13a.1** Create `hooks/claude/<name>/` for each of the 10 hook scripts
- [x] **13a.2** Add `hook.json` beside each hook script (name, runtime, events[], dependencies, failureMode)

**Commit:** `feat(hooks): add hook.json manifests and move hook source to hooks/claude/<name>/`

- [x] **13b.1** Update `scripts/sync.sh` to copy `hooks/claude/<name>/<name>.sh` → `dist/claude/hooks/<name>.sh`
- [x] **13b.2** Remove hook scripts from `dist/claude/hooks/` as authored files

**Commit:** `refactor(build): generate dist/claude/hooks/ from hooks/claude/ source in sync.sh`

---

### Phase 14 — Data-driven skill trigger hooks

- [ ] **14a.1** Add `tests/fixtures/skill-file-trigger/` — JSON inputs + expected output
- [ ] **14a.2** Add `tests/fixtures/skill-autotrigger/` — prompt inputs + expected output
- [ ] **14a.3** Write `tests/skill-triggers.sh` harness

**Commit:** `test(hooks): add fixtures for skill-file-trigger and skill-autotrigger`

- [ ] **14b.1** Rewrite `skill-file-trigger.sh` to iterate `skill.json` for `filePatterns`/`pathPatterns`
- [ ] **14b.2** Profile hook execution time; pre-cache in sync.sh if needed

**Commit:** `refactor(hooks): drive skill-file-trigger from skill.json filePatterns and pathPatterns`

- [ ] **14c.1** Rewrite `skill-autotrigger.sh` to iterate `skill.json` for `triggers`

**Commit:** `refactor(hooks): drive skill-autotrigger from skill.json triggers`

---

### Phase 15 — Generated indexes

- [ ] **15.1** Update `scripts/sync.sh` (or add build step) to generate `dist/claude/source/global-skills.md` from `skill.json`
- [ ] **15.2** Update `scripts/build-chatgpt-target.py` to generate `dist/chatgpt/SKILLS.md` from `skill.json`
- [ ] **15.3** Remove `dist/claude/source/global-skills.md` as a manually-edited file

**Commit:** `refactor(build): generate global skill indexes from skill.json`

---

### Phase 16 — Generated Claude settings

- [ ] **16.1** Create `adapters/claude/settings.base.json` from current `dist/claude/settings.json` minus `hooks` block
- [ ] **16.2** Update `scripts/sync.sh` to assemble `dist/claude/settings.json` from base + hook manifests
- [ ] **16.3** Handle inline `.env` guard (extract to script or keep in base with comment)

**Commit:** `refactor(build): generate settings.json hooks block from hook manifests`

---

### Phase 17 — Validation

- [ ] **17.1** Write `scripts/validate.sh` — manifests, dependencies, capabilities, executables, generated file freshness
- [ ] **17.2** Wire `validate.sh` into `scripts/sync.sh` (run after generation)

**Commit:** `feat(scripts): add validate.sh for manifest integrity and generated file freshness`

---

## Architecture

Editable source: `rules/` (shared rules), `skills/` (skill manifests + bodies), `hooks/` (hook source), `adapters/` (runtime-specific settings base).
Generated output: `dist/` — never author directly; regenerate with `scripts/sync.sh`.
Installed output: symlinks from `~/.claude/` and `~/.agents/` into `dist/`.

## Validation (end-to-end)

After all phases: `scripts/validate.sh` exits 0; `scripts/sync.sh` exits 0 and is idempotent; `readlink ~/.claude/settings.json` → `dist/claude/settings.json`; writing a `.vue` file fires the vue/code-style skill reminder from the data-driven hook.
