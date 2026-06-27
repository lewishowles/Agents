---
# Generated — edit skill.json and SKILL.body.md instead.
name: library-release
displayName: Library release
description: >
  Use this skill when preparing to release a new version of @lewishowles/components, @lewishowles/helpers, or @lewishowles/testing.
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

Conservative release guardrails for `@lewishowles/components`, `@lewishowles/helpers` and `@lewishowles/testing`. Inspect current repo process first; preserve explicit approval for irreversible steps.

## Release stance

- Release the smallest coherent change set.
- Decide semver from user-facing impact, not code volume.
- Use existing package scripts/docs; do not invent release tooling unless asked.
- Keep publish, tag, push, and registry actions as explicit confirmation points.
- Record release rough edges instead of baking in workarounds.

## Step 1 — identify the package

Confirm which package is being released:

- `@lewishowles/components`
- `@lewishowles/helpers`
- `@lewishowles/testing`

Read package root instructions, workspace file if present, `package.json`, changelog, and release notes before recommending commands.

## Step 2 — classify the release

Choose version bump from observable consumer impact:

| Bump  | Use when                                                                                                 |
| ----- | -------------------------------------------------------------------------------------------------------- |
| Patch | Bug fixes, docs fixes, internal changes, or compatible polish                                            |
| Minor | New exports, components, helpers, props, slots, options, or compatible behaviour                         |
| Major | Removed or renamed APIs, changed defaults, incompatible behaviour, or migration-required styling changes |

When unsure between bumps, name uncertainty and ask before editing version files.

## Step 3 — prepare notes

Write changelog/release notes before publishing. Include only externally relevant changes:

- Breaking changes and migration notes
- New APIs, components, helpers, props, slots, or options
- Fixes users may notice
- Deprecations and follow-up timing

Do not include internal refactors unless they explain consumer-visible behaviour.

## Step 4 — verify locally

Use package's existing scripts and documented release checks. Prefer scoped checks; ask before broad, slow, networked, or destructive commands.

Minimum verification to look for:

- Typecheck or build command
- Unit test command if present
- Package or export validation if present
- Generated docs or build output freshness if the package publishes generated assets

If useful check is missing, mention gap rather than inventing release blocker.

## Step 5 — inspect publish contents

Before publishing, confirm package contents and metadata:

- Version and package name
- Entry points and export map
- Files included in the package
- Changelog or release notes
- README or docs affected by the release

Use dry-run/pack commands when available, after confirming package tooling.

## Step 6 — explicit release actions

These packages publish to the npm registry for the next version. Treat `npm publish` or any CI workflow that publishes to npm as the publish step. Do not use GitHub Packages as the target registry.

Stop for confirmation before each irreversible/history-changing action:

- Version file edits if not already approved
- Git tag creation
- Git push if the package workflow publishes to npm from CI
- `npm publish` if the package release process publishes manually
- GitHub release creation

Show exact command and expected effect before asking.

## Step 7 — after release

Report:

- Package and version released
- Verification run
- Publish/tag/release status
- Any release-process rough edges worth fixing later

Do not update consuming projects unless user asks; use `library-update` for follow-up.
