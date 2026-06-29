## Skill use policy

Skills are authoritative when their trigger conditions match. Before coding, editing prose, changing config, or reviewing files, inspect the task and file paths, then load and use the matching skills needed for the current task type. If multiple skills match, use all relevant skills — especially `code-style` plus language/framework skills. Do not wait for explicit slash-command invocation.

**Skill vs. rule boundary:** if guidance should apply on every turn regardless of task, it belongs in `rules/`. If it is triggered by a specific task type or file context, it belongs in `skills/`. Do not add always-on conventions to a skill, and do not put task-specific workflows in a rule.

- Re-read a skill only if the task type changes, the user explicitly asks, or you need a specific detail. Otherwise, keep applying the loaded guidance without announcing it.
- Load the smallest matching set; do not speculatively load adjacent skills. For analysis, review, or planning requests, do not load implementation skills — see Scope default in global-rules.
- Summarise remembered constraints in your own words — do not quote skill sections back.
- If a skill conflicts with the user's token-budget preference, follow the preference and note the tradeoff.
