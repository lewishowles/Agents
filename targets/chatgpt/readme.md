---
name: readme
description: >
  Use this skill when writing or editing a README file (README.md or similar). Covers what belongs in a README, what doesn't, structure, and the "no fluff that doesn't help the average reader" principle — example: a bash script for macOS shouldn't mention Windows alternatives that don't exist. Pair with the writing skill for voice and tone baselines.
---

# README

README job: help person who just landed — what is it, why exist, how use. Quick-start guide, not marketing page.

## What belongs

- **Purpose** — one or two sentences: what this is, who it's for
- **Setup / install** — concrete steps reader can copy. macOS-only? Say once. No Windows alternatives that don't exist
- **Usage** — most common one or two uses, with examples
- **Where to look next** — links to deeper docs, contributing guide, license

## What doesn't belong

- Marketing prose, long origin stories, repeated value-prop sentences
- Step-by-step for unsupported platforms
- Long feature lists — link to dedicated docs file instead
- Internal-only notes (decisions, history, TODOs) — commit messages, ADRs, per-project docs

## Tone

- Friendly, conversational, second-person ("you'll need…")
- Short steps; concrete commands; no preamble before sections
- Sentence-case headings (`## Getting started`, not `## Getting Started`)
- UK spelling

## Quick checklist before publishing

- Can new reader run setup from clean machine using only what's here?
- Platform assumptions stated explicitly?
- Cut anything that doesn't help average reader?

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
