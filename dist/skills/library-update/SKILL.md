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

Use GitHub CLI to list releases for relevant repo:

```bash
# For components:
gh release list --repo lewishowles/components --limit 20

# For helpers:
gh release list --repo lewishowles/helpers --limit 20

# For testing:
gh release list --repo lewishowles/testing --limit 20
```

Identify the latest stable release tag. Tags follow the format `v.X.Y.Z`.

If installed version matches latest release, report up to date and stop.

## Step 4 — fetch release notes for all versions between installed and latest

For each newer release tag, ascending:

```bash
gh release view v.X.Y.Z --repo lewishowles/components
```

Collect release notes. Identify:

- **Breaking changes** — API removals, renamed props, changed defaults, removed exports
- **New components or composables** — things the project might benefit from adopting
- **Bug fixes** — particularly for patterns the project already uses
- **Deprecations** — things still working but flagged for removal

## Step 5 — scan the project

Scan project source (`src/`) for library usage. Focus on:

- Imports from `@lewishowles/components` or `@lewishowles/helpers`
- Component names, prop names, composable names, and slot names that appear in the release notes
- Any pattern the release notes flag as changed or removed

Use `rg` scoped to `src/`:

```bash
rg "@lewishowles/components" src/ --files-with-matches
rg "ComponentName" src/ -l   # repeat per affected component
```

## Step 6 — report findings

Structure the output as follows:

### `@lewishowles/<library>`: vX.Y.Z → vA.B.C

#### Must update

Breaking changes affecting project code. Include path(s) and needed change.

#### Worth adopting

New features/components relevant to project, or extracted functionality/boilerplate that can replace local code.

#### Good to know

Fixes/deprecations worth knowing, no immediate action.

#### Not relevant

Omit this section — only report what applies to the project.

---

If multiple libraries in scope, report separately. Keep concrete: file, import/component, specific change.
