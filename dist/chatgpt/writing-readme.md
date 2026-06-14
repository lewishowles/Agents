---
# Generated — edit skill.json and SKILL.body.md instead.
name: writing-readme
description: >
  Use this skill when writing or editing a README file (README.md or similar). Covers what belongs in a README, what doesn't, structure, and the "no fluff that doesn't help the average reader" principle. Pair with the writing skill for voice and tone baselines.
related-skills:
  - writing
---
# README

README job: help someone who just landed — what it is, why it exists, how to use it. Quick-start guide, not marketing page.

## What belongs

- **Purpose** — one or two sentences: what this is, who it's for
- **Setup / install** — copyable steps. macOS-only? Say once. No Windows alternatives that don't exist
- **Usage** — most common one or two uses, with examples
- **Where to look next** — links to deeper docs, contributing guide, license

## What doesn't belong

- Marketing prose, long origin stories, repeated value-prop sentences
- Step-by-step for unsupported platforms
- Long feature lists — link to dedicated docs file instead
- Internal-only notes (decisions, history, TODOs) — use commit messages, ADRs, or project docs

## Tone

- Friendly, conversational, second-person ("you'll need…")
- Short steps; concrete commands; no preamble before sections
- Sentence-case headings (`## Getting started`, not `## Getting Started`)
- UK spelling

## Quick checklist before publishing

- Can new reader run setup from clean machine using only what's here?
- Platform assumptions stated explicitly?
- Cut anything that doesn't help the average reader?

## Minimal structure

````markdown
# Project name

One or two sentences: what this is and who it's for.

## Requirements

- macOS
- Bun

## Getting started

```bash
bun install
bun run dev
```

## Usage

The most common command or workflow, with one short example.

## More information

- [Detailed docs](docs/)
````
