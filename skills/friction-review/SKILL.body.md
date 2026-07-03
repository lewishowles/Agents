# Friction review

Turns recurring friction-log patterns into specific, minimal, human-reviewed amendments to `rules/` or `skills/`. Captured friction with no review step has no payoff — this closes that gap.

## Workflow

1. **Run the analyser** — `bash scripts/analyse-friction.sh`. Output is `count ⇥ category ⇥ cwd ⇥ detail`, sorted most-frequent-first. By default it combines the central friction log with project-local fallback logs under `$HOME/Dev`; pass explicit log paths only for a scoped review.
2. **Take the top recurring patterns** — entries with count ≥ 2 are worth reviewing; a single occurrence is usually not yet a pattern. Group entries that describe the same underlying failure even if `cwd`/`detail` differ slightly.
3. **Skip already-resolved patterns** — if a later `RESOLVED` marker exists for a pattern, it's excluded from analyser output automatically. If a pattern you're reviewing was previously resolved and has reappeared, say so explicitly — the earlier fix didn't hold, and the new amendment should account for why.
4. **Decide the fix's home** — apply the existing rule/skill boundary: if the guidance should apply on every turn regardless of task, it belongs in `rules/global-rules.md` (mirror in `skills/global-rules/SKILL.body.md`). If it's specific to a task type or file context, it belongs in the relevant `skills/<name>/SKILL.body.md`.
5. **Propose a diff, not a summary** — for each pattern, show the exact before/after text change as a diff. State which file, why this pattern warrants a rule (not a one-off fix), and what evidence (which friction-log entries) supports it.
6. **Never auto-apply** — this skill proposes; the user reviews and confirms before any file changes are made. Human review is the write gate, same as every other rule/skill change in this repo.
7. **Record the resolution** — once the user confirms an amendment lands, append `RESOLVED ⇥ <category> ⇥ <pattern> ⇥ <ref>` to the friction log (`ref` can be a commit message, PR link, or short description). This excludes the pattern from future analyser runs unless it resurfaces.

## What makes a good amendment

- **Specific** — names the exact behaviour to change, not a vague reminder to "be careful."
- **Minimal** — the smallest wording change that would have prevented the recurring failures. Don't restructure the surrounding section.
- **Evidenced** — cites the friction-log pattern (category + count) that justifies it, not a hunch.
- **Placed correctly** — always-on → `rules/`; task-triggered → `skills/`. If both a rule and a skill mirror it (like `global-rules.md`), update both in the same proposal.

## Skip conditions

- Friction log is empty or has no entries with count ≥ 2 — report that, don't force a proposal.
- The recurring pattern is already covered by existing guidance the agent simply didn't follow that one time — flag as a possible one-off, not a guidance gap, and suggest logging one more occurrence before amending.
