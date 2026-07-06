## Skill use policy

Skills are authoritative when their trigger conditions match. Before coding, editing prose, changing config, or reviewing files, inspect the task and file paths, then load the matching skills. If multiple skills match, use all relevant ones — especially `code-style` plus language/framework skills. Do not wait for explicit slash-command invocation.

**Skill vs. rule boundary:** if guidance should apply on every turn regardless of task, it belongs in `rules/`. If it is triggered by a specific task type or file context, it belongs in `skills/`. Do not add always-on conventions to a skill, and do not put task-specific workflows in a rule.

- Re-read a skill only if the task type changes, the user asks, or you need a specific detail. Otherwise keep applying the loaded guidance without announcing it.
- Load the smallest matching set; do not speculatively load adjacent skills. For analysis, review, or planning, do not load implementation skills (see Scope default in global-rules).
- Summarise constraints in your own words — do not quote skill sections back.
- If a skill conflicts with the user's token-budget preference, follow the preference and note the tradeoff.
