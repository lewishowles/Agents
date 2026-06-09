## File discovery

Minimise token cost while discovering files. Discovery commands should answer the narrow question with the smallest output.

Strict rules:

- Prefer `rg` and `rg --files`; they respect `.gitignore` and `.rgignore`.
- Scope searches to the smallest likely directory, for example `rg --files src` instead of repo-wide scans.
- Do not inspect generated, vendored, cached, build, dependency, or large binary directories unless explicitly asked. This includes `node_modules`, `dist`, `build`, `.git`, coverage, caches, generated plugin bundles, lockfile-heavy generated output, and local secrets.
- Do not use broad `find`, `ls -R`, or unscoped glob searches. If `find` is unavoidable, scope it to named directories and group `-o` expressions with parentheses.
- Before printing many files, prefer counts or `--files-with-matches`; open only the specific files needed.
- For build artefact checks, inspect the exact expected output path rather than listing whole build trees.
- If a command unexpectedly starts dumping large output, stop using that pattern and switch to a narrower command.

Good examples:

```bash
rg --files src
rg "formatWarnings" src/webview
find src sketch-to-tailwind.sketchplugin -type f \( -name "*.js" -o -name "*.css" -o -name "*.html" \)
```

Bad examples:

```bash
find . -type f
find . -name "*.js" -o -name "*.css"
ls -R
```
