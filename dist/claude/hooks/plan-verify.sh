#!/usr/bin/env bash
#
# plan-verify — PostToolUse:ExitPlanMode hook
#
# Warns if the most recently modified plan file lacks a ## Validation section.
# Silent on pass, silent if no plan files exist.

plans_dir="$HOME/.claude/plans"
[ -d "$plans_dir" ] || exit 0

plan_file=$(ls -t "$plans_dir"/*.md 2>/dev/null | head -1)
[ -z "$plan_file" ] && exit 0

if ! grep -qi "^## Validation" "$plan_file"; then
	jq -n '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: "⚠️  Plan is missing a ## Validation section. Add one before exiting plan mode."}}'
fi
