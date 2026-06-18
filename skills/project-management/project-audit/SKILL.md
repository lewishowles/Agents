---
# Generated — edit skill.json and SKILL.body.md instead.
name: project-audit
displayName: Project audit
description: >
  Use this skill when auditing a project for setup drift, stale generated output, missing diagnostics, command-safety gaps, or agent-readiness issues. Covers AGENT_CAPABILITIES.md, .agent/scripts tooling, PROGRESS.md handoff health, validation commands, and generated/source boundaries.
---
# Project audit

Use this skill to audit a project for agent-readiness and maintenance drift. Default to findings and recommendations, not implementation.

## Scope

Audit:

- project instruction health (`AGENTS.md`)
- factual capability coverage (`AGENT_CAPABILITIES.md`)
- project-local agent tools under `.agent/scripts/`
- diagnostics discoverability and command safety
- generated/source boundaries
- `PROGRESS.md` handoff quality when multi-session work is active
- setup drift after this configuration repo changes

Do not turn this into a broad code-quality review. Use `code-review` for code diffs and `accessibility-audit` for UI/WCAG audits.

## Startup

Read in this order, stopping as soon as you have enough context:

1. `<project-root>/AGENTS.md`
2. `<project-root>/AGENT_CAPABILITIES.md`
3. `<project-root>/.agent/scripts/repo-context.py` output, if present
4. `<project-root>/.agent/scripts/generated-file-guard.py` output, if present
5. `<project-root>/.agent/scripts/project-diagnostics.py --list`, if present
6. `PROGRESS.md` handoff only, when active work or session continuity is part of the audit

If `AGENT_CAPABILITIES.md` is missing, do not create it unless the user asks. Report that the project lacks a reviewed capability manifest and continue with targeted inspection of `AGENTS.md`, package scripts, and nearby docs.

## Tooling checks

When these scripts exist, prefer them over manual inference:

```sh
.agent/scripts/repo-context.py
.agent/scripts/generated-file-guard.py
.agent/scripts/project-diagnostics.py --list
```

Do not run `.agent/scripts/project-diagnostics.py --all` unless the user asks for broad verification. For a focused audit, `--list` is enough unless a specific check is relevant to a finding.

If a generated-file guard reports findings, treat them as high priority because they often mean review will happen against generated output or stale output.

## Findings

Lead with findings, ordered by risk:

- **High** — unsafe commands, missing capability manifest in an active project, generated/source mismatch, stale diagnostics, broken setup scripts
- **Medium** — incomplete project instructions, missing progress handoff for active multi-session work, stale generated paths, unclear package manager/runtime facts
- **Low** — minor wording drift, convenience tooling not installed, non-blocking docs gaps

Each finding should include:

- exact file or command involved
- why it matters for future agents
- concrete fix

## Output

Use this shape:

```markdown
Findings

- [High] <path or command>: <problem>. Fix: <action>.

Checks run

- `<command>` — <result>

Recommended next step

<one concrete action>
```

If no issues are found, say that clearly and list the checks run. Do not invent improvements.
