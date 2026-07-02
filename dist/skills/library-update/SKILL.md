---
# Generated — edit skill.json and SKILL.body.md instead.
name: library-update
displayName: Library update check
description: >
  Use this skill to check whether @lewishowles/components, @lewishowles/helpers, or @lewishowles/testing have new releases since the installed version, review the release notes, and identify what to update in the current project.
do-not-use-when:
  - Updating unrelated packages or general project dependencies
  - Preparing or publishing a new library release
  - Using the installed helper or component APIs without checking for newer releases
---
# Library update check

Check Lewis shared libraries for new releases, surface changes, and identify project updates needed.

## Invocation

```
/library-update              — check whichever libraries are present in package.json
/library-update components   — check @lewishowles/components only
/library-update helpers      — check @lewishowles/helpers only
/library-update testing      — check @lewishowles/testing only
```

## Step 1 — determine which libraries to check

If argument given, use it. Otherwise read `package.json` and check listed dependencies/devDependencies:

- `@lewishowles/components`
- `@lewishowles/helpers`
- `@lewishowles/testing`

If none present, stop and say so.

## Step 2 — find the installed version

For each library in scope:

1. Read `package.json` to find the declared version constraint.
2. Find the exact resolved version from the lockfile — check in order:
   - `bun.lock` or `bun.lockb` — search for the package entry
3. Use resolved version (e.g. `2.2.1`) as **installed version**.

## Step 3 — find the latest release

Use the npm registry as the source of truth for published versions:

```bash
npm view @lewishowles/components version versions time --json
npm view @lewishowles/helpers version versions time --json
npm view @lewishowles/testing version versions time --json
```

Confirm before running npm registry commands if network access has not already been approved. Identify the latest stable published version from `version` or the `latest` dist-tag. Versions follow the format `X.Y.Z`.

If installed version matches latest release, report up to date and stop.

## Step 4 — fetch release notes for all versions between installed and latest

Use npm package metadata and package contents before GitHub. For each newer version, ascending:

```bash
npm view @lewishowles/components@X.Y.Z description homepage repository readme --json
npm pack @lewishowles/components@X.Y.Z --dry-run
```

If npm metadata or package contents include release notes, changelog entries, or README release sections, collect those. If npm does not include enough release detail, ask the user for the release notes excerpt instead of using GitHub releases or GitHub Packages as the primary source.

Identify:

- **Breaking changes** — API removals, renamed props, changed defaults, removed exports
- **Adoption opportunities** — helpers, components, composables, or test utilities that replace local boilerplate or make existing project code simpler
- **New components or composables** — things the project might benefit from using where there is no current equivalent
- **Bug fixes** — particularly for patterns the project already uses
- **Deprecations** — things still working but flagged for removal

## Step 5 — scan the project and generators

Scan project source (`src/`) and project-owned Boilersuit generators (`.boilersuit/generators/`) when present. Generators are starting points for future files, so treat stale imports, props, helper usage, and boilerplate there as adoption work even when generated output in the current project is already up to date.

Focus on:

- Imports from `@lewishowles/components` or `@lewishowles/helpers`
- Component names, prop names, composable names, and slot names that appear in the release notes
- Any pattern the release notes flag as changed or removed
- Local helpers, repeated boilerplate, custom test setup, or generator templates that a newer shared library API now replaces

Use `rg` scoped to `src/` and `.boilersuit/generators/` when those directories exist:

```bash
rg "@lewishowles/components" src/ --files-with-matches
rg "@lewishowles/components" .boilersuit/generators/ --files-with-matches
rg "ComponentName" src/ -l   # repeat per affected component
```

## Step 6 — compare the boilerplate baseline

Check `~/Dev/Repositories/Packages/boilerplate` after the current project scan. It is a baseline for future projects, not an automated freshness oracle.

If the repo exists and is readable, inspect its relevant package files, source templates, and `.boilersuit/generators/` files for the same release-note patterns and adoption opportunities. Report improvements separately from the current project so the user can decide whether to update the boilerplate repo in another chunk.

Do not claim the boilerplate repo is "up to date" from version checks alone. At most, say which relevant files or patterns were checked and whether the current release notes suggested any concrete changes.

## Step 7 — report findings

Structure the output as follows:

### `@lewishowles/<library>`: vX.Y.Z → vA.B.C

#### Must update

Breaking changes affecting project code. Include path(s) and needed change.

#### Adopt now

New shared-library APIs that replace existing project code, reduce local boilerplate, or make current usage more direct. Include all affected paths and say whether the adoption belongs in the same dependency-update chunk or should be split into the next chunk because it touches many files.

Treat `@lewishowles/helpers` simplifications as adoption work by default, even when they require broad mechanical edits. Defer only when adoption changes product behaviour, needs design or product judgement, or is large enough to deserve a separate reviewable chunk.

#### Consider later

New features/components relevant to the project where there is no existing local equivalent to replace.

#### Good to know

Fixes/deprecations worth knowing, no immediate action.

#### Boilerplate baseline

Concrete changes to consider in `~/Dev/Repositories/Packages/boilerplate`, including `.boilersuit/generators/` paths where relevant. Say "not checked" only if the repo was missing or unreadable, or if the user asked to skip it.

#### Not relevant

Omit this section — only report what applies to the project.

---

If multiple libraries in scope, report separately. Keep concrete: file, import/component, specific change.
