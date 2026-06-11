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
| Progress remains in `.claude/PROGRESS.md`                                       | Root `AGENTS.md` / `CLAUDE.md` semantics are reserved for symlinked/generated runtime files             |

---

## Architecture

Editable source: `rules/` (shared rules), `skills/` (skill manifests + bodies), `hooks/` (hook source), `adapters/` (runtime-specific settings base).
Generated output: `dist/` — never author directly; regenerate with `scripts/sync.sh`.
Installed output: symlinks from `~/.claude/`, `~/.agents/`, and `~/.codex/` into `dist/`.
Repo-maintenance state stays in `.claude/PROGRESS.md` so root agent files are not confused with the symlinked/generated target files this repo manages for other projects.

**End-to-end validation target:** `scripts/validate.sh` exits 0; `scripts/sync.sh` exits 0 and is idempotent; `readlink ~/.claude/settings.json` → `dist/claude/settings.json`; writing a `.vue` file fires the vue skill reminder from the data-driven hook.

---

## Archived milestones

### Phases 0–9 (2026-05-13 to 2026-05-28)

Dual-target setup, sync infrastructure, and ecosystem expansion complete. Key deliverables: `rules/` + `dist/` structure; `sync.sh`; `setup-global.sh` (per-skill symlinks, idempotent, backup strategy); `setup-project.sh`; template splits; README + docs rewrite; end-to-end validation of both runtimes; repo renamed to `~/Dev/Configuration/Agents`; Vue ecosystem skills refreshed; external skill sync added.

### Phases 10–18 (2026-05-28 to 2026-06-11)

Manifest-driven refactor complete. Source/output dirs renamed (`shared/` → `rules/`, `targets/` → `dist/`); skills grouped under `vue/`, `swift/`, `testing/`, `writing/`, and `project-management/`; all 33 skills now use `skill.json` + `SKILL.body.md` with generated `SKILL.md`; hook source moved to `hooks/claude/<name>/` with `hook.json`; Claude settings, ChatGPT skill index, global skill index, and docs tables now generate from manifests. Phase 16b renamed 14 skills for prefix-based autocomplete. Phase 17 linked Codex skills into `~/.codex/skills` as well as `~/.agents/skills`. Phase 18 refreshed README/ChatGPT docs and added `scripts/build-docs.py` for skill, command, and hook tables.

### Phase 19 (2026-06-11)

Docs generation hardened: hook manifests now include descriptions; generated hook docs include purpose; file-trigger docs merge duplicate patterns; generated blocks carry edit-source comments; `scripts/build-docs.py --check` and `scripts/validate.sh` catch stale generated docs.

### Phase 20 (2026-06-11)

Project-management skill manifests now carry explicit `title` values; generated `SKILL.md` frontmatter emits Codex-compatible `displayName` from `title` only when present so UI labels can avoid reading markdown headings without broad generated churn.
