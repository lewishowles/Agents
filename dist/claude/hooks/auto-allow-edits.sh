#!/usr/bin/env bash
# Auto-approves all file edits inside this configuration repo without prompting.
# Only registered for paths within the repo, so it never fires in other projects.

printf '{"decision": "allow"}\n'
