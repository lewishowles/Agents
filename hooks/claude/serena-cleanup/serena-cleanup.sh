#!/usr/bin/env bash
# Wrapper for serena-hooks cleanup — cleans up Serena hook session data
# at session end.
exec serena-hooks cleanup --client=claude-code
