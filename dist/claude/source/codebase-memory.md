## Prefer codebase-memory-mcp graph tools

Before reading source files, use codebase-memory-mcp when available. Tool order:

1. `list_projects`/`index_status` — check if indexed
2. `index_repository` — index if needed
3. `search_graph` — find symbols by name, label, or pattern
4. `trace_path` — call chains, data flow, cross-service paths
5. `get_code_snippet` — read source for a discovered symbol
6. `query_graph` — Cypher for complex structural questions
7. `get_architecture` — project structure overview
8. `detect_changes` — git changes → affected symbols

Pass the project name from `list_projects` to query tools. Use `search_code` for text search. Fall back to shell discovery only for non-code files, config values, literals, or when MCP returns insufficient results. If unavailable, state once then use the narrowest file-discovery command.