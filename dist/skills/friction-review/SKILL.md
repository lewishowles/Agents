---
# Generated — edit skill.json and SKILL.body.md instead.
name: friction-review
description: >
  Use this skill to turn recurring friction-log patterns into specific, minimal, human-reviewed amendments to rules/ or skills/. Runs scripts/analyse-friction.sh, proposes a diff per pattern, never auto-applies.
do-not-use-when:
  - Logging a single friction entry — use .agent/scripts/log-friction.sh directly
  - The friction log is empty or has no recurring patterns
---
# Friction review

Turns recurring friction-log patterns into specific, minimal, human-reviewed amendments to `rules/` or `skills/`. Captured friction with no review step has no payoff — this closes that gap.

## Workflow

1. **Run the analyser** — `bash scripts/analyse-friction.sh`. Output is `count ⇥ category ⇥ cwd ⇥ detail`, sorted most-frequent-first. By default combines central friction log with project-local logs under `$HOME/Dev` and excludes automated `check-fail` rows; set `FRICTION_INCLUDE_CHECK_FAILS=1` only when reviewing verification debt. Pass explicit paths for scoped review.
2. **Take top recurring patterns** — entries with count ≥ 2 warrant review; a single occurrence is usually not yet a pattern. Group entries describing the same failure even if `cwd`/`detail` differ slightly. Treat `check-fail` rows as verification debt unless detail shows repeated agent behaviour existing guidance would not prevent.
3. **Skip already-resolved patterns** — later `RESOLVED` markers exclude patterns from analyser output automatically. If a resolved pattern reappears, state so explicitly; the earlier fix didn't hold, and the amendment should account for why.
4. **Decide the fix's home** — if guidance applies every turn regardless of task, it belongs in `rules/global-rules.md` (mirror in `skills/global-rules/SKILL.body.md`). If task-specific, it belongs in the relevant `skills/<name>/SKILL.body.md`.
5. **Propose a diff** — for each pattern, show exact before/after text change. State which file, why this warrants a rule (not a one-off fix), and what evidence supports it.
6. **Never auto-apply** — this skill proposes; the user reviews and confirms before any file change. Human review is the write gate.
7. **Record the resolution** — once the user confirms an amendment lands, append `RESOLVED ⇥ <category> ⇥ <pattern> ⇥ <ref>` to the friction log (`ref` can be a commit message, PR link, or short description). This excludes the pattern from future runs unless it resurfaces.

## What makes a good amendment

- **Specific** — name the exact behaviour to change, not "be careful"
- **Minimal** — the smallest wording change preventing recurring failures. Don't restructure the section
- **Evidenced** — cite the friction-log pattern (category + count), not a hunch
- **Placed correctly** — always-on goes in `rules/`; task-triggered in `skills/`. If both mirror it (like `global-rules.md`), update both in the same proposal

## Skip conditions

- Friction log is empty or has no entries with count ≥ 2: report that; don't force a proposal
- Recurring pattern already covered by existing guidance and agent simply didn't follow once: flag as possible one-off, not a guidance gap; suggest logging one more before amending
