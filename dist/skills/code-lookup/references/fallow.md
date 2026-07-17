# Fallow

Use Fallow for project-wide JavaScript and TypeScript analysis:

- unused files, exports, types, members, and dependencies
- duplication and circular dependencies
- complexity, ownership, coverage gaps, and refactoring targets
- architecture boundaries, feature flags, styling drift, and security candidates
- changed-code and release audits

## Workflow

1. Prefer connected Fallow tools when available; otherwise use the installed CLI.
2. Run `fallow schema` or `fallow <command> --help` for the current command contract.
3. Choose the narrowest command and scope that answers the request.
4. Request machine-readable output with `--format json --quiet` when consuming results programmatically.
5. Treat exit code 1 as findings and exit code 2 as a runtime or configuration error.
6. Verify a finding before changing source. Fallow's tracing is syntactic and may not resolve dynamic behaviour.

Do not install packages, initialise configuration, add hooks, enable impact tracking, or enable telemetry without permission. For `fallow fix`, preview with `--dry-run`, review the exact targets, then apply only when the user requested the mutation. Use Serena for reference-aware source edits after a concrete finding is selected.
