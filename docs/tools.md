# Optional runtime tools

These are per-project runtime dependencies that users install — not skills, not plugins, and not managed by this repo. Agents don't load them automatically; users install them in projects where the additional capability is worth the setup cost.

Last reviewed: 2026-06-25.

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

**Installation:** MCP server, requires a language server for the target language. See the Serena MCP documentation for setup details.

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

## Comparison: codebase-memory vs repowise vs fallow

| | codebase-memory | repowise | fallow |
|-|-----------------|----------|--------|
| **Type** | MCP server (skill in this repo) | Runtime tool (user-installed) | CLI tool (skill in this repo) |
| **Languages** | Language-agnostic (via LSP) | Language-agnostic | JS/TS only (122 framework plugins) |
| **Graph traversal** | Yes — callers, callees, impact, dead code | Yes — callers, callees, dependencies | No |
| **Duplication detection** | No | No | Yes — 4 modes |
| **Boundary violations** | No | No | Yes — architecture boundary enforcement |
| **Complexity hotspots** | Partial — fan-out/fan-in via graph queries | Yes — composite health scoring | Yes — with ownership and refactoring targets |
| **Git hotspot analysis** | No (use `git log` commands directly) | Yes — churn + defect density over time | No |
| **ADR mining** | No | Yes | No |
| **Atomic refactors** | No (analysis only) | No | No (use Serena MCP for execution) |
| **Dead code detection** | Yes — `search_graph(max_degree=0)` | Yes | Yes — unused files, exports, types, deps |
| **Cost to adopt** | Already a skill — zero marginal cost | New runtime dependency per project | Already a skill — zero marginal cost; CLI must be installed in target project |

**Decision guide:**
- Use **codebase-memory** for graph traversal, impact analysis, and dead code detection across any language
- Use **fallow** for JS/TS-specific cleanup: duplication, boundary violations, complexity hotspots, unused exports
- Add **repowise** only for large repos where git-driven defect prediction and health scoring would change prioritisation
- Add **Serena MCP** when you need atomic cross-file refactors that codebase-memory's analysis can't execute
