---
# Generated — edit skill.json and SKILL.body.md instead.
name: library-release
displayName: Library release
description: >
  Use this skill when preparing to release a new version of @lewishowles/components or @lewishowles/helpers.
do-not-use-when:
  - Updating a project to consume an already-published library release
  - Publishing an unrelated package
  - Using installed helper or component APIs without preparing a release
related-skills:
  - dependencies
  - typescript
  - writing
---
# Library release

Use this as conservative release guardrails for `@lewishowles/components` and `@lewishowles/helpers`. Do not treat the current repo process as automatically correct; inspect it first and preserve explicit user approval for irreversible steps.

## Release stance

- Release the smallest coherent change set.
- Decide semver from user-facing impact, not amount of code changed.
- Use existing package scripts and docs; do not invent release tooling during a release unless asked.
- Keep publish, tag, push, and registry actions as explicit confirmation points.
- Record rough edges found during release instead of baking in workarounds.

## Step 1 — identify the package

Confirm which package is being released:

- `@lewishowles/components`
- `@lewishowles/helpers`
- `@lewishowles/testing`

Read the package root instructions, capability manifest if present, `package.json`, changelog, and release notes files before recommending commands.

## Step 2 — classify the release

Choose the version bump from observable consumer impact:

| Bump  | Use when                                                                                                 |
| ----- | -------------------------------------------------------------------------------------------------------- |
| Patch | Bug fixes, docs fixes, internal changes, or compatible polish                                            |
| Minor | New exports, components, helpers, props, slots, options, or compatible behaviour                         |
| Major | Removed or renamed APIs, changed defaults, incompatible behaviour, or migration-required styling changes |

When unsure between two bumps, name the uncertainty and ask before editing version files.

## Step 3 — prepare notes

Write changelog or release notes before publishing. Include only externally relevant changes:

- Breaking changes and migration notes
- New APIs, components, helpers, props, slots, or options
- Fixes users may notice
- Deprecations and follow-up timing

Do not include internal refactors unless they explain consumer-visible behaviour.

## Step 4 — verify locally

Use the package's existing scripts and documented release checks. Prefer scoped checks first; ask before broad, slow, networked, or destructive commands.

Minimum verification to look for:

- Typecheck or build command
- Unit test command if present
- Package or export validation if present
- Generated docs or build output freshness if the package publishes generated assets

If a useful check is missing, mention the gap rather than inventing a release blocker.

## Step 5 — inspect publish contents

Before publishing, confirm the package contents and metadata:

- Version and package name
- Entry points and export map
- Files included in the package
- Changelog or release notes
- README or docs affected by the release

Use dry-run or pack-style commands when available, but only after confirming the package's tooling.

## Step 6 — explicit release actions

Stop for confirmation before each irreversible or history-changing action:

- Version file edits if not already approved
- `bun run deploy`
- Git tag creation
- Git push, including tags
- GitHub release creation

Show the exact command and expected effect before asking.

## Step 7 — after release

Report:

- Package and version released
- Verification run
- Publish/tag/release status
- Any release-process rough edges worth fixing later

Do not immediately update consuming projects unless the user asks; use `library-update` for that follow-up.
