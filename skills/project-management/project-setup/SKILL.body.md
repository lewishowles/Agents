# Project setup

Use this skill to start a new project or feature. Create initial `PROGRESS.md` after exploration and discussion; do not implement until the plan is reviewed.

## File location

`PROGRESS.md` lives at the **project root** — not in `.claude/`. Create and read it at `<project-root>/PROGRESS.md`. Do not assume `.claude/PROGRESS.md`.

## Capability manifest

Check for `<project-root>/AGENT_CAPABILITIES.md` before planning. It is the factual source for available commands, generated files, diagnostics, progress locations, expensive checks, and forbidden operations.

When `<project-root>/.agent/scripts/project-diagnostics.py` exists, list it as the preferred verification route. Plans should use `--list` for discovery and `--check <name>` for named verification; reserve `--all` for user-approved broad checks.

If it is missing, generate it only when a capability generator command is discoverable by name. Example global command:

```sh
agents:capabilities --write
```

Before running it, confirm `agents:capabilities` exists in the current shell, then run the command from the project root. After generating the file, tell the user it was generated from detected repo facts and should be reviewed before relying on command safety, generated paths, or forbidden-operation classifications.

If no generator command with that name exists, do not guess its path or create the file manually. Continue with targeted inspection of `AGENTS.md`, package scripts, and nearby docs, and mention that adding `AGENT_CAPABILITIES.md` would improve future sessions.

## Workflow

1. **Explore** — read the repository; identify patterns, tech choices, and relevant files; check for root `PROGRESS.md`, `AGENTS.md`, `AGENT_CAPABILITIES.md`, `CONTEXT.md`, and `README.md`
2. **Ask** — clarify ambiguous requirements and constraints before planning; surface tradeoffs and alternatives
3. **Discuss** — if multiple approaches exist, present them; don't pick silently
4. **Plan** — produce an initial `PROGRESS.md` following the standard schema (see below)
5. **Wait** — do not begin implementation until the plan is reviewed and approved

## Planning principles

- Treat commits as the unit of work — each PROGRESS.md section should roughly match one Conventional Commit
- Prefer multiple small sections over one large one; each section should be independently reviewable
- "Files likely to change" reduces re-exploration in future sessions
- Don't plan more than 2–3 sections ahead; detailed planning happens when work starts
- Keep the session handoff at the top current at all times. Future agents should be able to read from the top and stop after the handoff when it gives enough context.

## CONTEXT.md — domain glossary

`CONTEXT.md` at the project root is a pure glossary of domain terms. It is not a spec, a scratch pad, or an implementation guide — only canonical names, what to avoid calling them, and resolved ambiguities.

Create it lazily: only when the first term is worth capturing. Add an entry when a term is agreed, not in a batch at the end.

Each entry follows this shape:

```markdown
**Term** — one-sentence definition. _Avoid_: synonyms or overloaded words that should not be used.
```

When `CONTEXT.md` exists, use its vocabulary in code, comments, issue titles, and ADRs. If the user uses a term that conflicts with it, surface the conflict rather than picking silently.

_CONTEXT.md glossary pattern inspired by [mattpocock/skills](https://github.com/mattpocock/skills) (MIT)._

## PROGRESS.md schema

```markdown
# <Project name>

## Session handoff

Read this section first. Stop after this section unless the task needs deeper context.

### Current goal

One sentence. What are we delivering right now?

### Previous step

Plan created; no implementation yet.

### Next step

Review and approve the plan before implementation starts.

### Stop here

Only continue reading if the next step is unclear, the user asks for planning/review/history, or implementation needs decisions, discoveries, risks, or file lists below.

## Project overview

Brief description: purpose, tech, constraints.

## Active work

### Purpose

### Expected commit

<Conventional Commit message>

### Files likely to change

### Related files to inspect

### Tasks

- [ ] item

### Risks

### Notes

## Decisions

Key architectural or process decisions. Date-stamped entries.

## Discoveries

Unexpected findings that affect the work. Date-stamped entries.

## Upcoming work

Brief bullets only. Detailed planning happens when work starts.

## Parking lot

Ideas and concerns not belonging to the current section.

## Archived milestones

Completed major sections, moved here to keep the document small.
```
