# Bash

## Config files

- Minimal comments, no headers
- `.env`/`.conf` concise, scannable
- Config organised cleanly

## Documentation

- Use `/path/to/directory` placeholders, not user-specific paths

## Styling

- Simple functions
- No premature abstraction
- Quote variables and paths
- Use `set -euo pipefail` for standalone scripts unless a command may legitimately fail
- Check required commands before using them

```bash
#!/usr/bin/env bash

set -euo pipefail

if ! command -v jq &>/dev/null; then
	printf 'This script requires jq. Install it with: brew install jq\n' >&2
	exit 1
fi

config_path="${1:-/path/to/config.json}"

if [[ ! -f "$config_path" ]]; then
	printf 'Config file not found: %s\n' "$config_path" >&2
	exit 1
fi

jq -r '.name // "unknown"' "$config_path"
```
