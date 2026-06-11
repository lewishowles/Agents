# Claude config improvements — dual-target + manifest-driven build

**Started:** 2026-05-13
**Project:** `~/Dev/Configuration/Agents`
**Status:** complete

---

## Critical decisions

| Decision                                                                        | Rationale                                                                                              |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `rules/` + `dist/<agent>/` structure                                            | Editable source vs disposable generated output                                                         |
| `skill.json` as canonical metadata source                                       | Separation: metadata (JSON) vs instructions (Markdown); avoids duplicate truth in SKILL.md frontmatter |
| `SKILL.body.md` + generated `SKILL.md`                                          | SKILL.body.md is editable; SKILL.md is generated from skill.json + body                                |
| Capability declarations in skill.json                                           | Skills declare intent; Claude adapter maps to hooks; Codex/ChatGPT can ignore unsupported capabilities |
| Hook source in `hooks/claude/<name>/`                                           | Generated output is not source; scripts authored once, copied into dist by sync.sh                     |
| `settings.base.json` in `adapters/claude/`                                      | Editable settings source not in `dist/`; settings.json = base + generated hooks block                  |
| Skill grouping: `vue/`, `swift/`, `testing/`, `writing/`, `project-management/` | Related skills navigable; build scripts handle one level of nesting                                    |
| Per-skill, per-hook symlinks (not whole folder)                                 | Coexists with plugin/system-installed items in `~/.claude/` and `~/.agents/`                           |
| Skill prefix renames (Phase 16b)                                                | Prefix-based autocomplete discoverability; 14 skills renamed                                           |
| Codex skill links in `~/.codex/skills`                                          | Current Codex builds discover user skills there; `~/.agents/skills` remains linked for compatibility   |

---

## Architecture

Editable source: `rules/` (shared rules), `skills/` (skill manifests + bodies), `hooks/` (hook source), `adapters/` (runtime-specific settings base).
Generated output: `dist/` — never author directly; regenerate with `scripts/sync.sh`.
Installed output: symlinks from `~/.claude/`, `~/.agents/`, and `~/.codex/` into `dist/`.

**End-to-end validation target:** `scripts/validate.sh` exits 0; `scripts/sync.sh` exits 0 and is idempotent; `readlink ~/.claude/settings.json` → `dist/claude/settings.json`; writing a `.vue` file fires the vue skill reminder from the data-driven hook.

---

## Archived milestones

### Phases 0–9 (2026-05-13 to 2026-05-28)

Dual-target setup, sync infrastructure, and ecosystem expansion complete. Key deliverables: `rules/` + `dist/` structure; `sync.sh`; `setup-global.sh` (per-skill symlinks, idempotent, backup strategy); `setup-project.sh`; template splits; README + docs rewrite; end-to-end validation of both runtimes; repo renamed to `~/Dev/Configuration/Agents`; Vue ecosystem skills refreshed; external skill sync added.

### Phases 10–16b (2026-05-28 to 2026-06-10)

Manifest-driven refactor complete. Key deliverables:

- **10:** Source/output dirs renamed (`shared/` → `rules/`, `targets/` → `dist/`)
- **11:** Skill restructuring — removed 3 stale skills; added `project-management` group (5 skills); grouped 15 skills into `vue/`, `swift/`, `testing/`, `writing/`
- **12:** `skill.json` manifests on all 33 skills; `SKILL.body.md` split; `build-skill-mds.py` generates `SKILL.md`; `do-not-use-when` on 7 skills; external skill sync writes `SKILL.body.md`
- **13:** Hook source moved to `hooks/claude/<name>/`; `hook.json` manifests on all 10 hooks; `sync.sh` copies to `dist/`
- **14:** Data-driven trigger hooks — `skill-file-trigger.sh` and `skill-autotrigger.sh` rewritten to iterate `skill.json`; fixture test harness added (56ms execution, no caching needed)
- **15:** `global-skills.md` and `SKILLS.md` (ChatGPT) generated from `skill.json`; no longer manually edited
- **16:** `build-settings.py` generates `settings.json` hooks block from `hook.json`; `settings.base.json` is the editable source
- **16b:** 14 skills renamed for prefix-based autocomplete discoverability (e.g. `pinia` → `vue-pinia`, `testing` → `test`, `readme` → `writing-readme`)
- **17:** Codex global setup now links skills into `~/.codex/skills` as well as `~/.agents/skills`; project-management skill headings now include the `Project` prefix for clearer Codex display names
- **18a:** README refreshed for grouped skill paths and current project setup output
- **18b:** ChatGPT dist refreshed by updating stale cross-skill references in source skill manifests (`test-unit`, `test-e2e`, `writing-readme`, `writing-copy`, `vue-vite`)
- **18c:** Skill, command, and hook docs tables now regenerate from `skill.json` and `hook.json` via `scripts/build-docs.py`
