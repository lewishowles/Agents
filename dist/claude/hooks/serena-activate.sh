#!/usr/bin/env bash
# Wrapper for serena-hooks activate — prompts the agent to activate the
# Serena project at session start.  The actual command used in settings.json
# calls serena-hooks directly; this script exists for validation and manual use.
exec serena-hooks activate --client=claude-code
