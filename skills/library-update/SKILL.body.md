# Library update check

Check one or both of Lewis's shared libraries for new releases, surface what changed, and identify what needs updating in the current project.

## Invocation

```
/library-update              — check whichever libraries are present in package.json
/library-update components   — check @lewishowles/components only
/library-update helpers      — check @lewishowles/helpers only
/library-update both         — check both explicitly
```

## Step 1 — determine which libraries to check

If an argument was given, use it. Otherwise read `package.json` and check which of the following are listed as dependencies (direct or dev):

- `@lewishowles/components`
- `@lewishowles/helpers`

If neither is present, stop and say so.

## Step 2 — find the installed version

For each library in scope:

1. Read `package.json` to find the declared version constraint.
2. Find the exact resolved version from the lockfile — check in order:
   - `bun.lock` or `bun.lockb` — search for the package entry
   - `package-lock.json` — look under `packages["node_modules/@lewishowles/<name>"].version`
   - `yarn.lock` — find the resolved block for the package
   - `pnpm-lock.yaml` — find the entry under `packages:`
3. Use the resolved version (e.g. `2.2.1`) as the **installed version** for comparison.

## Step 3 — find the latest release

Use the GitHub CLI to list releases for the relevant repo:

```bash
# For components:
gh release list --repo lewishowles/components --limit 20

# For helpers:
gh release list --repo lewishowles/helpers --limit 20
```

Identify the latest stable release tag. Tags follow the format `v.X.Y.Z`.

If the installed version matches the latest release, report that the library is up to date and stop.

## Step 4 — fetch release notes for all versions between installed and latest

For each release tag that is newer than the installed version (in ascending order):

```bash
gh release view v.X.Y.Z --repo lewishowles/components
```

Collect the release notes. Identify:

- **Breaking changes** — API removals, renamed props, changed defaults, removed exports
- **New components or composables** — things the project might benefit from adopting
- **Bug fixes** — particularly for patterns the project already uses
- **Deprecations** — things still working but flagged for removal

## Step 5 — scan the project

Scan the project source (`src/`) for usage of the library. Focus on:

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

Breaking changes affecting code found in the project. Include the file path(s) and what needs to change.

#### Worth adopting

New features or components relevant to what the project already does.

#### Good to know

Fixes or deprecations that don't require immediate action but are worth being aware of.

#### Not relevant

Omit this section — only report what applies to the project.

---

If both libraries are in scope, report each one separately. Keep findings concrete: name the file, the import or component, and what specifically changed.
