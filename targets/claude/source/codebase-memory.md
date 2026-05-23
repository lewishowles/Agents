## Prefer codebase-memory-mcp graph tools

Before reading source files or scanning a codebase, use codebase-memory-mcp when its MCP tools are available. The graph gives structural answers faster than broad `Grep`, `Glob`, `Read`, `find`, or `rg` exploration.

Use the graph tools in this order:

1. `list_projects` or `index_status` — check whether the project is indexed.
2. `index_repository` — index the current project if no usable graph exists.
3. `search_graph` — find functions, classes, routes, variables, and files by label, name pattern, or qualified-name pattern.
4. `trace_path` — inspect callers, callees, call chains, data flow, or cross-service paths.
5. `get_code_snippet` — read the exact source for a discovered function, class, or method.
6. `query_graph` — run Cypher for complex structural questions.
7. `get_architecture` — get high-level project structure and relationships.
8. `detect_changes` — map local git changes to affected graph symbols.

For query tools, pass the `project` name returned by `list_projects`.

Use `search_code` for graph-augmented text search. Fall back to normal shell discovery only for non-code files, config values, literal strings, generated assets, or when codebase-memory-mcp returns insufficient results.

If codebase-memory-mcp is unavailable in the current runtime, do not spend tokens searching for it or trying repeated failing calls. State once that the graph tools are unavailable, then use the narrowest normal file-discovery command allowed by the file-discovery rules.
