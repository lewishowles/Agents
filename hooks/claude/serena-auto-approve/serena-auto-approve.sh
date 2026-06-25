#!/usr/bin/env bash
# Wrapper for serena-hooks auto-approve — auto-approves Serena MCP tool
# calls when Claude Code is in a permissive permission mode.
exec serena-hooks auto-approve --client=claude-code
