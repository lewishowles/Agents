## File discovery

Minimise token cost while discovering files; answer the narrow question with the smallest output.

- Prefer `rg` and `rg --files`, but include gitignored files during file discovery. For glob tools, set `include_gitignored: true`; for `rg`, include ignored files while keeping the search scoped to the smallest likely path.
- Scope searches to the smallest likely directory, for example `rg --files src` instead of repo-wide scans.
- Do not inspect generated, vendored, cached, build, dependency, or large binary directories unless explicitly asked: `node_modules`, `dist`, `build`, `.git`, coverage, caches, generated plugin bundles, lockfile-heavy generated output, local secrets.
- Do not use broad `find`, `ls -R`, or unscoped glob searches. If `find` is unavoidable, scope it to named directories and group `-o` expressions with parentheses.
- Before printing many files, prefer counts or `--files-with-matches`; open only the specific files needed.
- If a task packet, handoff, or the user's message already names the exact target file(s), symbol, or finding, skip indexing and search entirely and read the named location directly. Only search when the target is genuinely unknown or the handoff is incomplete.
- Once a search or graph query identifies the exact file, symbol, or line to change, stop exploratory reads and searches. Use the narrowest source snippet, symbolic tool, or patch anchor needed for the edit; reserve another search for verifying the changed reference.
- After a source-inspection guard hook blocks consecutive searches or reads, change cadence: use one symbolic lookup, known-symbol read, or single targeted file range, then reassess before issuing another search/read. Project guard hooks override generic advice to parallelise file reads.
- If symbolic tools described in loaded guidance are not visible, use tool discovery for the specific missing tool names before falling back to grep, sed, or direct file reads.
- After making file edits, do not self-review by reading several changed files in sequence. Prefer diagnostics, formatter output, targeted symbol lookup, or a single patch-anchor read only when needed.
- For build artefact checks, inspect the exact expected output path rather than listing whole build trees.
- If a command unexpectedly starts dumping large output, stop using that pattern and switch to a narrower command.
- If a user says a file exists and a search cannot find it, state that gitignored files were included before concluding it is missing.
- Never rely on a remembered line number to offset-read into a file. Formatters shift lines on save. Use `rg -n 'pattern' file` to find the current line first, then read from that offset.
- Never use a `&&` chain to conclude a file exists or is absent. A `&&` exits non-zero silently on any failure in the chain, not just a missing file. Use the Read tool or an explicit `[[ -f path ]]` check with a verified exit status instead.
