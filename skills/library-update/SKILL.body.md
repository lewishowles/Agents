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
