#!/usr/bin/env bash
# Wrapper for serena-hooks remind — nudges the agent to prefer Serena's
# symbolic tools over consecutive grep/read_file calls.
exec serena-hooks remind --client=claude-code
