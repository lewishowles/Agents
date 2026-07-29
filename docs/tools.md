# Optional runtime tools

These are per-project runtime dependencies that users install — not skills, not plugins, and not managed by this repo. Agents don't load them automatically; users install them in projects where the additional capability is worth the setup cost.

Last reviewed: 2026-07-17.

## Serena MCP

LSP-backed MCP server providing atomic semantic refactoring operations: cross-file renames, moves, reference lookups, and symbol-level edits. Works at the language server level, so it understands types, scopes, and imports.

**What it adds beyond this repo's skills:**

- Atomic cross-file refactors (rename a function and update all references in one operation)
- Symbol-level operations (move a class between files, extract a method)
- Reference-aware edits that respect language semantics

**When to use it:**

- Large refactors spanning many files where manual find-and-replace is error-prone
- When you need to rename a widely-used symbol and update all call sites correctly
- Exact definitions, references, diagnostics, and reference-aware source changes

**How it complements codebase-memory:** Serena is the default for exact language-server relationships and semantic edits. Use codebase-memory first only for broader multi-hop, cross-service, cross-repository, or language-agnostic graph questions.

**Installation:** MCP server, requires a language server for the target language. This repo manages the server registration and lifecycle hooks for both Claude Code and Codex:

- **Claude Code:** server registered in `dist/claude/.mcp.json`; hooks for activate, remind, auto-approve, and cleanup live in `src/hooks/claude/serena-activate/`, `src/hooks/claude/serena-remind/`, `src/hooks/claude/serena-auto-approve/`, and `src/hooks/claude/serena-cleanup/`
- **Codex:** server and hook feature managed in `~/.codex/config.toml` via `ensure_codex_config`; hooks linked from `dist/codex/hooks.json`

Run `scripts/setup-global.sh --both` after cloning or pulling changes to Serena hook configuration.

## MDN MCP

HTTP MCP server from Mozilla exposing MDN documentation and live browser-compatibility (Baseline) data. It answers "does this feature exist, and where is it supported?" from a current source rather than model training data, which goes stale quickly for web-platform features.

**When to use it:**

- Confirming browser or Baseline support for a CSS, HTML, or JavaScript feature before relying on it
- Checking whether a newer web-platform feature exists at all
- Accessibility, performance, or frontend-design work where feature support is load-bearing

**Shipped disabled by default.** It's registered for both agents but stays off until enabled, so it loads no tool schemas and sends no queries during normal work. When an agent needs it, it asks the user to enable it:

- **Claude Code:** listed in `dist/claude/.mcp.json`; held off via `disabledMcpjsonServers` in `dist/claude/settings.json`. Enable per session from `/mcp`.
- **Codex:** `[mcp_servers.mdn]` in `~/.codex/config.toml` with `enabled = false`, managed by `ensure_codex_config`. Toggle with `codex mcp` or by editing the flag.

Queries go to Mozilla's experimental endpoint (`https://mcp.mdn.mozilla.net/`); no local install is needed.

## ast-grep

Syntax-aware search, lint, and rewrite tooling for code patterns. It matches AST shapes rather than plain text, so it can find call sites, declarations, imports, or nested structures without needing a full language server.

**What it adds beyond this repo's skills:**

- Structural search for repeated code shapes that are awkward or brittle with `rg`
- Mechanical rewrites and codemod previews where semantic refactoring is not needed
- Project-specific lint rules for recurring AST patterns

**Overlap with Serena:** both understand code structure, but at different levels. Serena uses the language server for semantic operations such as reference-aware renames and symbol edits. ast-grep uses syntax patterns for search, lint, and rewrite tasks; it does not replace semantic refactoring.

**When it's worth adding:**

- You repeatedly search for or rewrite the same syntactic pattern
- A project needs custom lint rules that depend on AST shape rather than text
- The target files are supported by ast-grep but do not have a reliable language-server workflow

**When it's not worth adding:**

- `rg` is enough for text, docs, config, or simple literal search
- Serena can perform the semantic edit safely, such as renaming a widely-used symbol
- The pattern is one-off and cheaper to inspect manually

**Installation:** Standalone CLI or MCP server. Treat it as a per-project runtime dependency; do not add it to global rules unless the target project has installed and documented it.

**Gotchas once adopted:**

- Relational rules (`inside`, `has`, `precedes`, `follows`) default to `stopBy: "neighbor"`, which stops at the immediately adjacent node and commonly misses matches silently. Use `stopBy: end` unless neighbor-only matching is actually intended.
- Test a rule against a representative snippet before running it across a project, matching the match-count-first discipline this repo already applies to broad `replace_all`/cross-file `sed`.
- Where output format is configurable, prefer text or compact output over JSON for exploratory search: it costs a fraction of the tokens. Use JSON only when metavariable captures or full range metadata are needed programmatically.

## repowise

Code intelligence tool that combines graph traversal with git history analysis for code health scoring and defect prediction.

**What it adds beyond this repo's skills:**

- Code health scoring (weighted combination of complexity, churn, fan-in, test coverage gaps)
- Git hotspot analysis (files with high churn and high defect density over time)
- ADR mining (extracting architectural decisions from commit history and code comments)

**Overlap with codebase-memory:** both do graph traversal (callers, callees, dependencies). Repowise adds temporal analysis (git history over time) and composite health scoring. codebase-memory is language-agnostic and already integrated as a skill; repowise is a separate runtime tool.

**When it's worth adding:**

- Large repos with active development where defect prediction matters
- When you need to prioritise technical debt work based on data, not intuition
- When git hotspot analysis would change which files you tackle first

**When it's not worth adding:**

- Small or medium repos where codebase-memory's graph queries + `git log` churn commands (see the risk triage pattern in the project-plan-task skill) cover the same ground
- Projects where the setup cost of a new tool outweighs the analytical benefit

**Installation:** Standalone tool. See the repowise documentation for setup details.

## Comparison: Serena vs codebase-memory vs ast-grep vs repowise

|                           | Serena                            | codebase-memory                   | ast-grep                          | repowise                                  |
| ------------------------- | --------------------------------- | --------------------------------- | --------------------------------- | ----------------------------------------- |
| **Primary job**           | Exact semantic lookup and editing | Broad graph traversal and impact  | Syntax-shaped search and rewrites | Git-informed health and defect prediction |
| **Languages**             | Language-server dependent         | Language-agnostic                 | Multi-language AST patterns       | Language-agnostic                         |
| **Graph traversal**       | Exact symbol relationships        | Multi-hop and cross-service paths | No                                | Callers, callees, and dependencies        |
| **Codemods and rewrites** | Semantic renames and symbol edits | No                                | Syntax-pattern rewrites           | No                                        |
| **Project health**        | Diagnostics only                  | Structural graph signals          | Custom rules only                 | Composite scoring and temporal signals    |
| **Literal text/config**   | No                                | No                                | Usually unnecessary               | No                                        |

**Decision guide:**

- Apply **`code-lookup`** first when the correct discovery tool is unclear
- Use **Serena** for exact symbols, references, diagnostics, and semantic edits
- Use **codebase-memory** for broad multi-hop, cross-service, cross-repository, or language-agnostic graph questions
- Add **ast-grep** only when syntax-shaped search, custom AST lint rules, or mechanical rewrites would avoid brittle `rg` patterns
- Add **repowise** only for large repos where git-driven defect prediction and health scoring would change prioritisation
- Use targeted text or file lookup for literals, configuration, documentation, and generated assets
