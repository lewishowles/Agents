# Codebase Memory — Knowledge Graph Tools

Graph tools return structural results in ~500 tokens vs ~80K for grep.

## Quick decision matrix

| Question              | Tool                                                    |
| --------------------- | ------------------------------------------------------- |
| Who calls X?          | `trace_path(direction="inbound")`                       |
| What does X call?     | `trace_path(direction="outbound")`                      |
| Full call context     | `trace_path(direction="both")`                          |
| Find by name          | `search_graph(name_pattern="...")`                      |
| Dead code             | `search_graph(max_degree=0, exclude_entry_points=true)` |
| Cross-service edges   | `query_graph` + Cypher                                  |
| Local change impact   | `detect_changes()`                                      |
| Risk-classified trace | `trace_path(risk_labels=true)`                          |
| Text search           | `search_code` or grep                                   |

## Exploration workflow

1. `list_projects` — check if indexed
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

Combine signals to identify high-risk files:

- **Fan-in** (blast radius): high callers = high impact
- **Fan-out** (complexity): calls many others = complex
- **Git churn**: recent changes correlate with defects
- High on 2+ signals → smaller changes, more testing, explicit risk notes

## When to use fallow instead

Codebase-memory: language-agnostic, excels at graph traversal. Fallow (JS/TS): duplication, boundary violations, complexity hotspots, unused code, feature flags. Use fallow for cleanup/health audits; codebase-memory for tracing/impact. For atomic cross-file refactors, see Serena MCP in [docs/tools.md](../../docs/tools.md).

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

1. `search_graph(relationship="HTTP_CALLS")` filters by degree; use `query_graph` for actual edges.
2. `query_graph` caps at 200 rows; use `search_graph` with degree filters for counting.
3. `trace_path` needs exact names; use `search_graph(name_pattern=...)` first.
4. `direction="outbound"` misses cross-service callers; use `direction="both"`.
5. Results default 10/page; check `has_more` and use `offset`.
6. File lookup: prefer `search_graph(label="File", name_pattern="...")` over BM25 `query`.
7. File unexpectedly absent: verify with `git ls-files` and `git check-ignore -v`. If tracked/not ignored, touch file and re-run `index_repository`.
8. Terminal CLI: `codebase-memory-mcp cli <tool> '<json>'`; bare `codebase-memory-mcp` starts MCP server (may hang).
