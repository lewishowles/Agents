# Codebase Memory — Knowledge Graph Tools

Graph tools return structural results in ~500 tokens vs ~80K for grep.

## Quick decision matrix

| Question | Tool call |
|----------|----------|
| Who calls X? | `trace_path(direction="inbound")` |
| What does X call? | `trace_path(direction="outbound")` |
| Full call context | `trace_path(direction="both")` |
| Find by name pattern | `search_graph(name_pattern="...")` |
| Dead code | `search_graph(max_degree=0, exclude_entry_points=true)` |
| Cross-service edges | `query_graph` with Cypher |
| Impact of local changes | `detect_changes()` |
| Risk-classified trace | `trace_path(risk_labels=true)` |
| Text search | `search_code` or grep |

## Exploration workflow
1. `list_projects` — check if project is indexed
2. `get_graph_schema` — understand node/edge types
3. `search_graph(label="Function", name_pattern=".*Pattern.*")` — find code
4. `get_code_snippet(qualified_name="project.path.FuncName")` — read source

## Tracing workflow
1. `search_graph(name_pattern=".*FuncName.*")` — discover exact name
2. `trace_path(function_name="FuncName", direction="both", depth=3)` — trace
3. `detect_changes()` — map git diff to affected symbols

## Quality analysis
- Dead code: `search_graph(max_degree=0, exclude_entry_points=true)`
- High fan-out: `search_graph(min_degree=10, relationship="CALLS", direction="outbound")`
- High fan-in: `search_graph(min_degree=10, relationship="CALLS", direction="inbound")`

## Risk signals (pre-work triage)

Before working in an unfamiliar area, combine these signals to identify high-risk files:
- **Fan-in** (blast radius): `search_graph(min_degree=10, relationship="CALLS", direction="inbound")` — files with many callers are high-impact
- **Fan-out** (complexity): `search_graph(min_degree=10, relationship="CALLS", direction="outbound")` — files calling many others tend to be complex
- **Git churn**: `git log --oneline --since="1 month ago" -- <path> | wc -l` — high recent change frequency correlates with defect density
- A file scoring high on two or more signals warrants extra care: smaller changes, more testing, explicit risk notes in the plan

## When to use fallow instead

Codebase-memory is language-agnostic and excels at graph traversal — callers, callees, impact analysis. For JS/TS projects, the **fallow** skill complements this with:
- Code duplication detection (4 modes)
- Architecture boundary violations
- Complexity hotspots with ownership and refactoring targets
- Unused files, exports, types, and dependencies
- Feature flag pattern detection

Use fallow for cleanup and structural health audits; use codebase-memory for tracing and impact analysis.

## 14 MCP Tools
`index_repository`, `index_status`, `list_projects`, `delete_project`,
`search_graph`, `search_code`, `trace_path`, `detect_changes`,
`query_graph`, `get_graph_schema`, `get_code_snippet`, `get_architecture`,
`manage_adr`, `ingest_traces`

## Edge types
CALLS, HTTP_CALLS, ASYNC_CALLS, IMPORTS, DEFINES, DEFINES_METHOD,
HANDLES, IMPLEMENTS, OVERRIDE, USAGE, FILE_CHANGES_WITH,
CONTAINS_FILE, CONTAINS_FOLDER, CONTAINS_PACKAGE

## Cypher examples (for query_graph)
```
MATCH (a)-[r:HTTP_CALLS]->(b) RETURN a.name, b.name, r.url_path, r.confidence LIMIT 20
MATCH (f:Function) WHERE f.name =~ '.*Handler.*' RETURN f.name, f.file_path
MATCH (a)-[r:CALLS]->(b) WHERE a.name = 'main' RETURN b.name
```

## Gotchas
1. `search_graph(relationship="HTTP_CALLS")` filters nodes by degree — use `query_graph` with Cypher to see actual edges.
2. `query_graph` has a 200-row cap — use `search_graph` with degree filters for counting.
3. `trace_path` needs exact names — use `search_graph(name_pattern=...)` first.
4. `direction="outbound"` misses cross-service callers — use `direction="both"`.
5. Results default to 10 per page — check `has_more` and use `offset`.
6. For file lookup, prefer `search_graph(label="File", name_pattern="...")` over BM25 `query`; BM25 may return symbols even when `label="File"` is supplied.
7. If a tracked file is unexpectedly absent from `search_graph` and `search_code`, verify with `git ls-files` and `git check-ignore -v`. If it is tracked and not ignored, touch the file and re-run `index_repository`; the incremental classifier/cache can miss unchanged files.
8. Terminal CLI shape is `codebase-memory-mcp cli <tool> '<json>'`; bare `codebase-memory-mcp` starts the MCP server and may look like it is hanging.
