#!/usr/bin/env bash
#
# skill-autotrigger — UserPromptSubmit hook
#
# Fires on every user message. Reads the prompt text, pattern-matches it
# against known skill triggers, and injects an additionalContext instruction
# telling Claude to invoke the matched skills before responding.
#
# How it works:
#   Claude Code sends {"prompt": "..."} to stdin before each response.
#   This script reads that JSON, runs grep patterns for each skill's domain,
#   then outputs JSON with hookSpecificOutput.additionalContext — a string
#   that Claude sees as a system-level reminder at the top of its context.
#   Claude treats strong instructions in that reminder as mandatory.
#
# Continuation prompts:
#   When the user says something ambiguous ("yes", "let's continue", "next step"),
#   Claude decides what to write independently. In that case all skills are
#   injected so Claude can pick whichever apply. This is intentionally broad —
#   false positives (loading unused skills) are preferable to missing them.
#
# Limitations:
#   - Only analyses the user's typed prompt, not Claude's plan. If Claude
#     independently decides to write a Swift file after "let's go", this hook
#     won't detect that specifically — hence the continuation catch-all.
#   - Pattern matching is keyword-based, not semantic. Unusual phrasing may
#     not trigger the right skills.
#   - The complementary skill-file-trigger.sh hook covers the Write/Edit case.
#
# Requires: jq (brew install jq) — hard fails and blocks the prompt if missing.

# Hard fail if jq is missing — block the prompt so the issue is visible
if ! command -v jq &>/dev/null; then
	printf '{"decision":"block","reason":"skill-autotrigger hook requires jq, which is not installed. Fix: brew install jq"}'
	exit 1
fi

input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt // ""' 2>/dev/null)

[ -z "$prompt" ] && exit 0

skills=()

# ─── Continuation / ambiguous prompts ────────────────────────────────────────
# When the user gives minimal direction ("yes", "let's continue", "next step"),
# Claude decides what to write. Inject all skills so Claude can pick what fits.
if echo "$prompt" | grep -qiE '^\s*(yes|yep|yeah|ok|okay|sure|go ahead|sounds good|perfect|great|looks good|done|next|correct|exactly)\s*[.!]?\s*$' || \
   echo "$prompt" | grep -qiE '\b(continue|carry on|move on|next step|proceed|let'\''s go|what'\''s next|keep going|move forward|let'\''s continue|crack on)\b'; then
	skills+=("code-style" "swift" "vue" "vue-project-stack" "pinia-colada" "typescript" "unit-testing" "writing" "readme" "ui-copy" "bash" "error-handling" "accessibility" "dependencies" "vite-patterns" "e2e-testing" "architecture-decision-records" "session-management")
fi

# ─── code-style ───────────────────────────────────────────────────────────
# "Apply to ALL code being written or edited — even small snippets"
if echo "$prompt" | grep -qiE '\b(write|add|create|implement|fix|update|refactor|edit|change|build|replace|make|generate|scaffold|add)\b' || \
   echo "$prompt" | grep -qiE '\b(function|method|class|struct|enum|property|variable|var|let|const|file|snippet|code|logic|handler|helper|utility)\b'; then
	skills+=("code-style")
fi

# ─── swift ─────────────────────────────────────────────────────────────────
# Swift, SwiftUI, Xcode, macOS app patterns
if echo "$prompt" | grep -qiE '\.swift\b|\bswiftui\b|\bxcode\b|\bswift\b|\bactor\b|\bstruct\b|\@observable\b|\@state\b|\@mainactor\b|\@environment\b|\@binding\b' || \
   echo "$prompt" | grep -qiE '\bnavigationstack\b|\bnavigationsplitview\b|\bnsworkspace\b|\bdispatchsource\b|\blabeledcontent\b|\btabview\b|\bform\b.*\bswift\b' || \
   echo "$prompt" | grep -qiE 'macos app|appkit|uikit|swiftdata|xctest|async.*await.*swift|\bactor\b.*\bswift\b'; then
	skills+=("swift")
fi

# ─── vue + vue-project-stack ───────────────────────────────────────────────
# Vue 3, Composition API, composables, Pinia, Tailwind, @lewishowles libs.
# vue-project-stack always pairs with vue since both apply to a Vue project.
if echo "$prompt" | grep -qiE '\.vue\b|\bvue\b|\bcomposable\b|<script setup|<template|\bpinia\b|\btailwind\b' || \
   echo "$prompt" | grep -qiE '\b(defineprops|defineemits|defineexpose|ref\(|reactive\(|computed\(|watch\(|onmounted\()\b' || \
   echo "$prompt" | grep -qiE '@lewishowles|vue.router|vue-router|\bvitejs\b|\bvite\b|\bgitflow\b'; then
	skills+=("vue" "vue-project-stack")
fi

# ─── typescript ───────────────────────────────────────────────────────────
# TypeScript files, type errors, type definitions, generics
if echo "$prompt" | grep -qiE '\.tsx?\b|\btypescript\b|lang="ts"|type error|type def|\binterface\b|\bgenerics\b' || \
   echo "$prompt" | grep -qiE '\b(infer|keyof|typeof|Record<|Partial<|Pick<|Omit<|Extract<|Exclude<|ReturnType<)\b' || \
   echo "$prompt" | grep -qiE '\btype alias\b|\bunion type\b|\bintersection type\b|\btype guard\b|\bas any\b'; then
	skills+=("typescript")
fi

# ─── unit-testing ──────────────────────────────────────────────────────────────
# Tests, specs, coverage, Vitest, @testing-library, XCTest
if echo "$prompt" | grep -qiE '\btests?\b|\bspec\b|\bcoverage\b|\.test\.|\.spec\.|\bxctest\b|\bvitest\b' || \
   echo "$prompt" | grep -qiE '\bdescribe\b|\bbeforeeach\b|\baftereach\b|\bmock\b|\bspy\b|\bstub\b|\bassert\b' || \
   echo "$prompt" | grep -qiE '@testing-library|test coverage|unit test|integration test|snapshot test'; then
	skills+=("unit-testing")
fi

# ─── accessibility ────────────────────────────────────────────────────────
# WCAG, ARIA, keyboard access, semantic HTML, UI components, colour contrast
if echo "$prompt" | grep -qiE '\baccessib|\bwcag\b|\ba11y\b|\baria-|\baria\b' || \
   echo "$prompt" | grep -qiE 'color contrast|colour contrast|keyboard nav|screen reader|focus (trap|management|ring|visible)' || \
   echo "$prompt" | grep -qiE '\b(landmark|tabindex|role=|alt text|caption|fieldset)\b'; then
	skills+=("accessibility")
fi

# ─── writing ──────────────────────────────────────────────────────────────
# Prose, longform, documentation, blog. Voice/tone baseline.
if echo "$prompt" | grep -qiE '\bdocumentation\b|\bdocs\b|\bblog\b|\bchangelog\b|\bannouncement\b|\barticle\b|\bpost\b' || \
   echo "$prompt" | grep -qiE '\breword\b|\brephrase\b|\bwording\b|\bproofread\b|\bedit (the )?(text|copy|prose|draft)\b'; then
	skills+=("writing")
fi

# ─── readme ───────────────────────────────────────────────────────────────
# README-specific guidance. Pair with writing for voice baseline.
if echo "$prompt" | grep -qiE '\breadme\b|\bread\.me\b|\bgetting started (doc|guide)\b'; then
	skills+=("readme" "writing")
fi

# ─── ui-copy ──────────────────────────────────────────────────────────────
# Microcopy: buttons, errors, empty states, tooltips, CTAs, placeholders.
# Pair with writing for voice baseline.
if echo "$prompt" | grep -qiE '\bui copy\b|\bmicrocopy\b|\berror message\b|\bbutton (label|copy|text)\b|\bcta\b' || \
   echo "$prompt" | grep -qiE '\bempty state\b|\btooltip\b|\bplaceholder (text|copy)\b|\bconfirmation (dialog|message)\b' || \
   echo "$prompt" | grep -qiE 'user.facing|helper text|form (label|copy)'; then
	skills+=("ui-copy" "writing")
fi

# ─── bash ─────────────────────────────────────────────────────────────────
# Shell scripts, zsh functions, bash utilities, .env, config files
if echo "$prompt" | grep -qiE '\.sh\b|\bbash\b|\bzsh\b|shell (script|function|util)' || \
   echo "$prompt" | grep -qiE '#!/|\.env\b|\balias\b|\bexport\b|\bPATH\b|\.bashrc\b|\.zshrc\b|\bcron\b|\bmakefile\b'; then
	skills+=("bash")
fi

# ─── dependencies ─────────────────────────────────────────────────────────
# Package installation, new libraries, npm/bun/yarn, version upgrades
if echo "$prompt" | grep -qiE 'package\.json|\bnpm (add|install|i)\b|\bbun (add|install)\b|yarn add|pnpm add' || \
   echo "$prompt" | grep -qiE '\b(install|add).*(package|library|dependency|dep)\b|\b(new|use|try).*(library|package)\b' || \
   echo "$prompt" | grep -qiE '\bpeer dep|\bdevdependenc|\bupgrade.*package|\bpackage.*version\b'; then
	skills+=("dependencies")
fi

# ─── error-handling ───────────────────────────────────────────────────────
# Error handling, validation, API calls, async functions with responses
if echo "$prompt" | grep -qiE '\berror handling\b|\btry[- ]catch\b|\bvalidat(e|ion)\b|\bguard (let|var)\b' || \
   echo "$prompt" | grep -qiE '\bapi (call|request|response)\b|\bfetch\b|\basync.*(function|func)\b|\bawait\b.*\bresponse\b' || \
   echo "$prompt" | grep -qiE '\boptional chaining\b|\bnil coalescing\b|\bthrow\b|\bcatch\b|\bResult<\b|\bthrows\b'; then
	skills+=("error-handling")
fi

# ─── vite-patterns ────────────────────────────────────────────────────────────
# Vite config, environment variables, build optimisation, security
if echo "$prompt" | grep -qiE 'vite\.config|vite\.config\.ts|environment var|\benv\b|\bVITE_\b' || \
   echo "$prompt" | grep -qiE 'build\.lib|external.*dep|pre-bundle|bundle.*size|dev.*build.*differ' || \
   echo "$prompt" | grep -qiE '\bvite\b.*config|\brollup\b|\besbuild\b'; then
	skills+=("vite-patterns")
fi

# ─── e2e-testing ──────────────────────────────────────────────────────────────
# End-to-end tests, Playwright, browser automation, user journeys
if echo "$prompt" | grep -qiE '\be2e\b|\be2e.test|\bplaywright\b|\bbrowser.automatio\b' || \
   echo "$prompt" | grep -qiE 'end.to.end.*test|user.*journey.*test|integration.*test' || \
   echo "$prompt" | grep -qiE '\bdata-test\b'; then
	skills+=("e2e-testing")
fi

# ─── architecture-decision-records ────────────────────────────────────────────
# ADRs, architectural decisions, framework adoption, major refactors
if echo "$prompt" | grep -qiE '\badr\b|\barchitecture.decision\b|\btech.decision\b|\bdecision.record\b' || \
   echo "$prompt" | grep -qiE 'framework.*adoption|major.*refactor|architectural.*pattern'; then
	skills+=("architecture-decision-records")
fi

# ─── pinia-colada ─────────────────────────────────────────────────────────────
# Async server state for Vue — useQuery, useMutation, cache, optimistic updates
if echo "$prompt" | grep -qiE '@pinia/colada|pinia colada|\busequery\b|\busemutation\b|\bdefinequery\b|\bdefinemutation\b|\bquerycache\b|\binvalidatequeries\b|\busequerycache\b'; then
	skills+=("pinia-colada")
fi

# ─── session-management ───────────────────────────────────────────────────────
# Save/resume sessions, PROGRESS.md tracking, token efficiency, goal-driven execution
if echo "$prompt" | grep -qiE '\bsave.session\b|\bresume.session\b|\bcontext.*snapshot\b|\bcheckpoint\b' || \
   echo "$prompt" | grep -qiE 'session.*management|pause.*resume' || \
   echo "$prompt" | grep -qiE '\bPROGRESS\.md\b|progress.*track|token.*efficien|goal.driven'; then
	skills+=("session-management")
fi

# ─── Deduplicate and output ───────────────────────────────────────────────────
[ ${#skills[@]} -eq 0 ] && exit 0

unique=($(printf '%s\n' "${skills[@]}" | sort -u))
list="${unique[*]}"

jq -n \
	--arg ctx "SKILL AUTO-TRIGGER: Before writing any code or content, you MUST invoke these skills using the Skill tool: ${list}. Call each one now, before any other response." \
	'{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
