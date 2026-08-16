# Port a project to the progress CLI

An ad hoc port loses ordering, dependencies, completed work, or the current handoff. The usual cause is treating the queue table as authoritative, inventing a bulk import, or deleting the source before comparing the live records. This skill keeps the source readable until the database proves that the port is complete.

The invariant is: every roadmap release, task-file field, chunk, dependency, discovery, decision, and handoff value is either represented by a supported `progress` record or is an explicitly reported mismatch awaiting a decision.

## Do not use this skill when

- The project has no existing `PROGRESS.md` or task-file state to migrate.
- The work is only adding one new task to an already-authoritative progress database. Use `project-plan-task`.
- The user wants a database schema change, a bulk importer, or direct SQLite editing. Stop and use the relevant implementation task instead.

## 1. Establish the source and database

1. Read `<project-root>/WORKSPACE.md` when it exists. If it is absent, inspect `AGENTS.md`, package metadata, and nearby docs. Do not create a workspace file during a port.
2. Check `git status --short` before editing. Keep `PROGRESS.md` and every task file until the final comparison has passed.
3. Confirm the project identity and database. Use the database path documented by the project, or pass it explicitly with `--database <path>` on every command. `progress` otherwise resolves `$AGENTS_PROGRESS_DATABASE`, then `~/.agents/progress.db`.
4. Run `progress --help` and the relevant noun help if the installed CLI differs from this skill. The CLI is the contract; do not reconstruct its schema from the Markdown.
5. Initialise only an uninitialised project:

   ```sh
   progress project init --slug <project-slug> --name "<project name>" --json [--database <path>]
   ```

   If the project already exists but is not attached to this Git repository, use the existing project ID:

   ```sh
   progress project attach <project-id> --json [--database <path>]
   progress project current --json [--database <path>]
   ```

   Never initialise blindly or write the database directly. If SQLite cannot open the configured database, stop and report the exact command, exit status, and first error. Do not copy the database or silently switch to a scratch database.

## 2. Inventory before writing

Read the source once and make a bounded inventory. Do not mutate the database while the inventory has unresolved identity or ordering questions.

- From `PROGRESS.md`, record the roadmap rows in order, the session handoff, `## Decisions`, `## Discoveries`, and any freeform backlog sections.
- From every `.agent/tasks/*.md`, record front matter and body fields: title, slug, status, release, dependencies, overview, purpose, contract, model tier, files, acceptance criteria, verification, risks, notes, and commit-plan items.
- Treat task-file front matter as authoritative for task status, release, and dependencies. A stale status or ordering value in the `PROGRESS.md` queue table is a mismatch to report, not a value to import.
- Give every release and task a stable source position. Use the roadmap order for releases and the queue order within each release or the unassigned queue for tasks.
- Mark each commit-plan item as pending or complete. A checked item becomes a completed chunk only after the CLI lifecycle commands confirm it.
- Classify each task-file `## Notes` entry before writing. A verified finding maps to `discovery add`; a resolved choice maps to `decision add`. A note that is neither must remain verbatim in the source and be reported as an unsupported mismatch. Do not hide it in an unrelated task field or delete it during cleanup without an explicit decision.
- Choose the most relevant task for each discovery and decision. If ownership is genuinely ambiguous, stop for a decision or report the mapping for review. Do not attach notes to an arbitrary task merely to make the count match.

Keep the inventory outside the database while porting. A short table, spreadsheet, or one-off read-only comparison is enough; do not add an import script.

## 3. Port releases first

Create each roadmap row with its explicit position. Do not omit `--position`: the pilot exposed position collisions when the flag was omitted.

```text
progress release add --slug <release-slug> --title <release-title> [--overview <overview>] [--status {planned,active,done}] [--position <position>] [--json] [--database <path>]
```

Capture each returned release ID, then use that ID for tasks. Verify the result with `progress release list --json` before adding tasks. If a release already exists, use `progress release get <release-id> --json` and do not create a duplicate.

## 4. Port tasks and dependencies

Create tasks with the fields that exist in the source. Do not pass empty optional flags.

```text
progress task add --slug <task-slug> --title <task-title> [--overview <overview>] [--purpose <purpose>] [--contract <contract>] [--model-tier <model-tier>] [--files <files>] [--acceptance-criteria <acceptance-criteria>] [--verification <verification>] [--risks <risks>] [--release <release-id> | --release-id <release-id>] [--depends-on <task-id> | --dependency <task-id>] [--position <position>] [--json] [--database <path>]
```

Apply these rules:

1. Pass an explicit task position. Creation without `--position` can collide with an existing position even though the CLI has an automatic-position path.
2. Create the dependency records before using their IDs. Pass the first existing dependency with `--depends-on`; add later dependencies after creation:

   ```text
   progress task dependency add <task-id> <depends-on-task-id> [--json] [--database <path>]
   ```

   `--dependency` is an alias for `--depends-on` on `task add`. Adding a dependency that is still unfinished automatically makes the new task `blocked`. That is expected state, not an import failure.

3. If a dependency points forward in the source order, create the task with its position and without that dependency, then add the edge once the dependency task exists. Verify the resulting status and edge with `task get`.
4. Capture every returned task ID. IDs are prefixed by the CLI; pass the returned value through rather than inventing IDs or using a title as an ID.
5. Do not assume there is a `task edit` command. The current task repair surface has `rename`, `move`, dependency add/remove, and lifecycle commands, but no arbitrary task-field edit. Check every metadata value before creation. If a field is wrong after child records exist, stop instead of using SQL or destructive re-creation.

Use `task move` for an ordering correction rather than removing and re-adding a task:

```text
progress task move <task-id> --before <target-task-id> [--json] [--database <path>]
progress task move <task-id> --after <target-task-id> [--json] [--database <path>]
```

Use `task rename` only for a title correction:

```text
progress task rename <task-id> --title <title> [--json] [--database <path>]
```

There is no release move command in the current surface. Set release positions during creation. The supported release corrections are title and overview changes:

```text
progress release rename <release-id> --title <title> [--json] [--database <path>]
progress release edit <release-id> --overview <overview> [--json] [--database <path>]
progress release edit <release-id> --clear-overview [--json] [--database <path>]
```

## 5. Port task-file chunks

Create one chunk for each commit-plan item, in source order:

```text
progress chunk add --task <task-id> --title <chunk-title> [--description <description>] [--position <position>] [--json] [--database <path>]
```

Use the commit outcome as the chunk title and retain the source's acceptance or verification detail in its description when that detail would otherwise be lost. Always pass `--position` for deterministic order.

The chunk command creates pending chunks. Replay source status only through lifecycle commands:

- For a source `planned` task, leave it `ready` or `blocked` as the dependency state dictates.
- For a source `blocked` task, preserve the dependency edge or use `task block` with the source reason. Add `--needs-decision` only when the source explicitly requires a decision.
- For a source `in-progress` task, start it after all other active work has been resolved. Its first pending chunk becomes active.
- For a source `done` task, start it, complete its active chunks in order, then complete the task. Do this before starting the source's active task.

```text
progress task start <task-id> [--json] [--database <path>]
progress chunk complete <chunk-id> [--json] [--database <path>]
progress task complete <task-id> [--json] [--database <path>]
```

The project permits only one `in-progress` task. If the source claims more than one active task, stop and ask which task is authoritative. Do not force a second active task or silently downgrade one. A task cannot complete while it has pending or active chunks.

Use the remaining lifecycle commands only to preserve a source state or repair a confirmed mismatch:

```text
progress task block <task-id> --reason <reason> [--needs-decision] [--json] [--database <path>]
progress task unblock <task-id> [--json] [--database <path>]
```

`unblock` rechecks dependencies. Do not use it to override an unfinished dependency.

## 6. Port discoveries, decisions, and handoff

The note commands have no date flag. Preserve a source date in the body, using `Date: YYYY-MM-DD` as the first line followed by the original wording. If the source has no date, do not invent one. Then attach each note to the task selected in the inventory:

`\n` below means an actual newline, not the two characters `\` and `n` — a plain double-quoted shell string won't do that; use `$'...'` ANSI-C quoting instead:

```text
progress discovery add --task <task-id> [--json] [--database <path>] $'Date: <YYYY-MM-DD>\n\n<original body>'
progress decision add --task <task-id> [--supersedes <note-id>] [--json] [--database <path>] $'Date: <YYYY-MM-DD>\n\n<original body>'
```

Use `--supersedes` only when the source explicitly replaces an earlier decision and the earlier note ID is known. The pilot had discoveries whose task ownership was a judgement call, so include that mapping in the verification report rather than presenting it as an objective fact.

Replace the old session handoff after records exist. Keep it concrete enough for the next agent to continue without reopening the discarded sections:

```text
progress context set \
  --current-goal "<current goal>" \
  --previous-step "<last completed port step>" \
  --next-step "<next action>" \
  --standing-context "<durable context and gotchas>" \
  --verify-with "<verification command or evidence>" \
  --stop-marker "<condition that tells the next agent to stop>" \
  --json [--database <path>]
progress context get --json [--database <path>]
```

Do not leave the old handoff in the Markdown while claiming the database is authoritative. Update the context only after the task and note IDs it references are known.

## 7. Verify before cleanup

Run all reads against the same database used for writes. Use JSON output and compare the inventory field by field:

```text
progress project current --json [--database <path>]
progress release list --json [--database <path>]
progress release get <release-id> --json [--database <path>]
progress task list --json [--database <path>]
progress task get <task-id> --json [--database <path>]
progress chunk list --task <task-id> --json [--database <path>]
progress current --json [--database <path>]
progress next --json [--database <path>]
progress context get --json [--database <path>]
```

The comparison must confirm:

- release slugs, titles, overviews, statuses, and roadmap positions;
- task slugs, titles, every populated metadata field, release IDs, statuses, dependencies, and queue positions;
- chunk titles, descriptions, positions, and completed or active state;
- discovery and decision body text, preserved date line, type, task ownership, and supersession links;
- task-file `## Notes` entries, including any unsupported entry reported as a mismatch;
- handoff fields, especially the active task and active chunk shown by `progress next`.

The task-file front matter wins over a stale `PROGRESS.md` queue status. Report every source/database mismatch, including intentional judgements, before cleanup. A clean `progress next --json` result must match the active task and next action that the pre-port handoff promised.

Only after the comparison is clean and the task contract permits cleanup:

1. Trim `PROGRESS.md` to the explicitly retained freeform sections, such as `## Upcoming work` and `## Parking lot`. Do not leave a second queue, roadmap, handoff, or discovery store.
2. Remove only the inventoried task files with a recoverable file removal command such as `trash`, never a broad recursive deletion.
3. Run the repository's documented validation. Keep the database comparison receipt with the handoff.

## Current repair and inspection surface

Use the installed help when a version changes. The current surface relevant to a port is:

- Releases: `add`, `list`, `get`, `remove`, `rename`, `edit`, `complete`.
- Tasks: `add`, `move`, `dependency add`, `dependency remove`, `remove`, `rename`, `start`, `complete`, `block`, `unblock`, `get`, `list`.
- Chunks: `add`, `complete`, `remove`, `rename`, `list`.
- Notes: `discovery add` and `decision add`, plus their supported removal commands.
- Handoff: `context get` and `context set`.

For destructive repair, remember that release and task removal are hard deletes and reject records with children or references. Removal does not cascade to chunks, notes, or dependency edges. Inspect `get` and `list` first, and stop if the intended target is not unambiguous.

## Recovery rules

- If a command fails, record the exact command, exit status, and first relevant error. Inspect the affected record with `get` or `list` before deciding whether a supported correction exists.
- Treat an automatic `blocked` status caused by an unfinished dependency as expected. Treat a position collision, a duplicate identity, a stale source field, or a second in-progress task as a porting problem to resolve explicitly.
- Never use direct SQLite writes, an unreviewed bulk importer, or a copied database to make the inventory appear complete.
- Never delete source files to hide an unresolved mismatch. Leave the source intact and hand back the smallest decision or CLI capability that is missing.
