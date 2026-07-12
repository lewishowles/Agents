# Optional runtime tools

These are per-project runtime dependencies that users install — not skills, not plugins, and not managed by this repo. Agents don't load them automatically; users install them in projects where the additional capability is worth the setup cost.

Last reviewed: 2026-07-12.

## Serena MCP

LSP-backed MCP server providing atomic semantic refactoring operations: cross-file renames, moves, reference lookups, and symbol-level edits. Works at the language server level, so it understands types, scopes, and imports.

**What it adds beyond this repo's skills:**

- Atomic cross-file refactors (rename a function and update all references in one operation)
- Symbol-level operations (move a class between files, extract a method)
- Reference-aware edits that respect language semantics

**When to use it:**

- Large refactors spanning many files where manual find-and-replace is error-prone
- When you need to rename a widely-used symbol and update all call sites correctly
- When codebase-memory has identified the impact set and you need to apply the actual changes

**How it complements codebase-memory:** codebase-memory finds the references and traces the impact; Serena applies the changes atomically. Use codebase-memory for analysis, Serena for execution.

**Installation:** MCP server, requires a language server for the target language. This repo manages the server registration and lifecycle hooks for both Claude Code and Codex:

- **Claude Code:** server registered in `dist/claude/.mcp.json`; hooks for activate, remind, auto-approve, and cleanup live in `hooks/claude/serena-activate/`, `hooks/claude/serena-remind/`, `hooks/claude/serena-auto-approve/`, and `hooks/claude/serena-cleanup/`
- **Codex:** server managed in `~/.codex/config.toml` via `ensure_codex_config`; hooks in `dist/codex/hooks.json`

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

## Comparison: codebase-memory vs ast-grep vs repowise vs fallow

|                           | codebase-memory                            | ast-grep                           | repowise                                  | fallow                                                                        |
| ------------------------- | ------------------------------------------ | ---------------------------------- | ----------------------------------------- | ----------------------------------------------------------------------------- |
| **Type**                  | MCP server (skill in this repo)            | CLI or MCP server (user-installed) | Runtime tool (user-installed)             | CLI tool (skill in this repo)                                                 |
| **Languages**             | Language-agnostic (via LSP)                | Multi-language AST patterns        | Language-agnostic                         | JS/TS only (122 framework plugins)                                            |
| **Graph traversal**       | Yes — callers, callees, impact, dead code  | No                                 | Yes — callers, callees, dependencies      | No                                                                            |
| **Structural search**     | Partial — graph symbols and relationships  | Yes — AST-shaped patterns          | Partial — graph symbols and relationships | Partial — JS/TS analysis rules                                                |
| **Codemods and rewrites** | No                                         | Yes — syntax-pattern rewrites      | No                                        | No (use Serena MCP for semantic edits)                                        |
| **Duplication detection** | No                                         | No                                 | No                                        | Yes — 4 modes                                                                 |
| **Boundary violations**   | No                                         | Custom rules only                  | No                                        | Yes — architecture boundary enforcement                                       |
| **Complexity hotspots**   | Partial — fan-out/fan-in via graph queries | No                                 | Yes — composite health scoring            | Yes — with ownership and refactoring targets                                  |
| **Git hotspot analysis**  | No (use `git log` commands directly)       | No                                 | Yes — churn + defect density over time    | No                                                                            |
| **ADR mining**            | No                                         | No                                 | Yes                                       | No                                                                            |
| **Atomic refactors**      | No (analysis only)                         | No (syntax rewrites only)          | No                                        | No (use Serena MCP for execution)                                             |
| **Dead code detection**   | Yes — `search_graph(max_degree=0)`         | Custom rules only                  | Yes                                       | Yes — unused files, exports, types, deps                                      |
| **Cost to adopt**         | Already a skill — zero marginal cost       | New runtime dependency per project | New runtime dependency per project        | Already a skill — zero marginal cost; CLI must be installed in target project |

**Decision guide:**

- Use **codebase-memory** for graph traversal, impact analysis, and dead code detection across any language
- Add **ast-grep** only when syntax-shaped search, custom AST lint rules, or mechanical rewrites would avoid brittle `rg` patterns
- Use **fallow** for JS/TS-specific cleanup: duplication, boundary violations, complexity hotspots, unused exports
- Add **repowise** only for large repos where git-driven defect prediction and health scoring would change prioritisation
- Add **Serena MCP** when you need atomic cross-file refactors that codebase-memory's analysis can't execute
