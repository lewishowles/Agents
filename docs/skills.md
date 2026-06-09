# Skills

Skills are focused instruction sets that tell Claude or Codex how to behave in a specific context: what patterns to follow, what to avoid, and what the conventions are.

Claude loads these from `~/.claude/skills/` and can be nudged by the Claude trigger hooks. Codex loads this repo's user skills from `~/.agents/skills/` in this setup and relies more heavily on each skill's frontmatter description for discovery.

## User skills

Defined in `skills/` in this repo, then symlinked into each runtime by `scripts/setup-global.sh`. The `agent-config` maintenance skill is intentionally repo-local under `.claude/skills/agent-config` and `.agents/skills/agent-config`; it is not installed globally for other projects.

Official external skills are listed in `external-skills.json` and synced into `skills/` by `scripts/sync-external-skills.sh`. Global setup runs that sync before linking skills. If the network is unavailable, setup warns and continues with the existing local copy.

| Skill                           | When to use                                                                                                                     | Auto-trigger keywords                                                                                                                                                  |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `accessibility`                 | Building interfaces — WCAG AA baseline, colour contrast, keyboard access, semantic HTML                                         | `wcag`, `a11y`, `aria`, `keyboard nav`, `screen reader`, `colour contrast`, `focus`, `button`, `form`, `label`, `heading`                                              |
| `agentic-engineering`           | Building with Claude API, Anthropic SDK, or managed agents — model selection, token budgeting, batch processing, prompt caching | `claude api`, `anthropic sdk`, `managed agent`, `llm cost`, `token budget`, `prompt caching`, `batch api`                                                              |
| `architecture-decision-records` | Documenting significant technical decisions — framework adoption, major refactors, architectural patterns                       | `adr`, `architecture decision`, `tech decision`, `decision record`, `framework adoption`, `major refactor`                                                             |
| `bash`                          | Shell scripts, zsh functions, `.env` files, config files                                                                        | `.sh`, `bash`, `zsh`, `shell script`, `.env`, `alias`, `export`, `PATH`, `.zshrc`, `cron`                                                                              |
| `codebase-memory`               | Structural code queries via codebase-memory-mcp — graph search, call tracing, architecture, impact analysis                     | `explore the codebase`, `architecture`, `who calls`, `trace call`, `dependencies`, `impact analysis`, `dead code`, `graph query`, `search_graph`                       |
| `code-style`                    | All code in any language — formatting, naming, comments                                                                         | `write`, `add`, `create`, `implement`, `fix`, `function`, `method`, `class`, `variable`, `file`, `code`                                                                |
| `dependencies`                  | Adding packages or considering a new library — when to add, what to avoid, @lewishowles libs                                    | `package.json`, `npm install`, `bun add`, `yarn add`, `install package`, `new library`, `upgrade package`                                                              |
| `e2e-testing`                   | End-to-end tests with Playwright — browser automation, user journeys, test structure                                            | `e2e`, `playwright`, `end-to-end test`, `user journey`, `data-test`                                                                                                    |
| `error-handling`                | Functions with parameters, API calls, response handling                                                                         | `error handling`, `try-catch`, `validate`, `guard let`, `api call`, `fetch`, `async`, `throws`, `Result<`                                                              |
| `pinia`                         | Client-side Vue stores — app/UI state, setup stores, `storeToRefs`, HMR, testing                                                | `pinia`, `defineStore`, `storeToRefs`, `@pinia/testing`, `useXStore`, files in `stores/`                                                                               |
| `pinia-colada`                  | Async server state in Vue — caching, mutations, optimistic updates, cache invalidation via `@pinia/colada`                      | `@pinia/colada`, `pinia colada`, `useQuery`, `useMutation`, `defineQuery`, `defineMutation`, `useQueryCache`, `invalidateQueries`, files in `queries/` or `mutations/` |
| `readme`                        | Writing or editing a README — structure, what belongs, what to cut                                                              | `readme`, `getting started guide`                                                                                                                                      |
| `session-management`            | Saving and resuming work sessions across Claude Code restarts                                                                   | `save session`, `resume session`, `context snapshot`, `checkpoint`, `session management`                                                                               |
| `swift`                         | Swift code — comment style, spacing, concurrency, `@Observable`/`@MainActor`                                                    | `.swift`, `swift`, `swiftui`, `xcode`, `@observable`, `@state`, `@mainactor`, `xctest`                                                                                 |
| `swift-ui`                      | SwiftUI code — state management, view composition, navigation, performance                                                      | (paired with `swift`; triggered by SwiftUI-specific APIs)                                                                                                              |
| `typescript`                    | TypeScript files, type errors, type definitions, generics                                                                       | `.ts`, `.tsx`, `typescript`, `type error`, `interface`, `generics`, `Record<`, `Partial<`, `keyof`, `typeof`                                                           |
| `ui-copy`                       | Microcopy — button labels, error messages, empty states, tooltips, CTAs                                                         | `ui copy`, `microcopy`, `error message`, `button label`, `cta`, `empty state`, `tooltip`, `placeholder`                                                                |
| `unit-testing`                  | Writing or reviewing unit tests — Vitest, XCTest, `@testing-library/vue`                                                        | `test`, `spec`, `coverage`, `.test.`, `.spec.`, `xctest`, `vitest`, `describe`, `mock`, `spy`, `assert`                                                                |
| `vite-patterns`                 | Configuring `vite.config.ts`, environment variables, build optimisation, security                                               | `vite.config`, `VITE_`, `environment var`, `build.lib`, `rollup`, `esbuild`                                                                                            |
| `vue`                           | Vue 3 components, composables, templates — patterns and organisation                                                            | `.vue`, `vue`, `composable`, `<script setup`, `pinia`, `defineProps`, `ref(`, `computed(`                                                                              |
| `vue-project-stack`             | Vue projects using the wider stack: Bun, Vitest, Tailwind, Gitflow, `@lewishowles` libs, Pinia Colada                           | (always paired with `vue`; same triggers)                                                                                                                              |
| `vue-router`                    | Vue Router routes, guards, params, query strings, redirects, and route-driven state                                             | `vue-router`, `router`, `routes`, `useRoute`, `useRouter`, `onBeforeRouteUpdate`, files in `router/`, `routes/`, or `pages/`                                           |
| `vueuse-functions`              | Official VueUse composable guide — map requirements to VueUse functions before writing bespoke code                             | `@vueuse`, `vueuse`, common VueUse composables such as `useLocalStorage`, `useMouse`, `useBreakpoints`                                                                 |
| `writing`                       | Prose — blog posts, documentation, longform content, voice and tone                                                             | `documentation`, `docs`, `blog`, `changelog`, `article`, `reword`, `rephrase`, `proofread`                                                                             |

## Built-in Claude Code skills

Provided by Claude Code itself. No SKILL.md files — managed by the application.

| Skill                      | When to use                                                                                                               |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `claude-api`               | Building, debugging, or optimising Claude API / Anthropic SDK apps, including prompt caching and model version migrations |
| `fewer-permission-prompts` | Scan transcripts and add a permission allowlist to `.claude/settings.json` to reduce approval prompts                     |
| `init`                     | Initialise a new project with Claude Code conventions                                                                     |
| `keybindings-help`         | Customise keyboard shortcuts, rebind keys, or add chord bindings in `~/.claude/keybindings.json`                          |
| `loop`                     | Run a prompt or slash command on a recurring interval (e.g. `/loop 5m /foo`)                                              |
| `review`                   | Run a code review of the current branch or changes                                                                        |
| `schedule`                 | Create, update, list, or run scheduled remote agents on a cron schedule                                                   |
| `security-review`          | Run a security-focused review of code changes                                                                             |
| `simplify`                 | Review changed code for reuse, quality, and efficiency, then fix issues found                                             |
| `update-config`            | Modify Claude Code configuration via `settings.json` — hooks, permissions, env vars, plugins                              |

## Controlling which skills load (skillOverrides)

Skills can be selectively suppressed in any `settings.json` using `skillOverrides`. This is the main tool for reducing token usage — skill descriptions are the bulk of the listing cost.

| Value                   | Effect                                                                                                                           |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `"on"`                  | Default. Full description shown to model and user-invocable                                                                      |
| `"name-only"`           | Skill name listed only — no description. Model knows it exists but doesn't consume description tokens. `/skill-name` still works |
| `"user-invocable-only"` | Hidden from model entirely. `/skill-name` still works for manual use                                                             |
| `"off"`                 | Hidden from both model and user                                                                                                  |

To re-enable a skill suppressed by a parent settings file, set it to `"on"` in the project or local settings file:

```json
{
  "skillOverrides": {
    "vue": "on",
    "vue-project-stack": "on"
  }
}
```

See `templates/claude/settings.json` for a Claude project template with non-universal skills set to `name-only`.

## Invoking a skill

**Manually in Claude:** type `/skill-name` in Claude Code (e.g. `/vue`, `/unit-testing`).

**Automatically in Claude:** the trigger hooks inject skills based on your prompt keywords and the file being written. See [docs/hooks.md](hooks.md) for how this works.

**In Codex:** matching is description-driven. Keep descriptions precise and action-led, with `Use this skill when...` wording.

## Adding a new skill

1. Create a folder in `skills/` matching the slug you want (e.g. `skills/my-skill/`)
2. Add `SKILL.md` with frontmatter:

```markdown
---
name: my-skill
description: Use this skill when... (one sentence — shown in the skills list)
related-skills:
  - code-style
---

# My skill

Content here.
```

1. Register keyword triggers in `targets/claude/hooks/skill-autotrigger.sh` so the hook detects relevant prompts
2. Register file extension triggers in `targets/claude/hooks/skill-file-trigger.sh` if the skill maps to a file type
3. Add the skill to the skills table in this file and to [docs/commands.md](commands.md)
4. Run `scripts/sync.sh` — this regenerates the Claude and Codex targets and also rebuilds `targets/chatgpt/` with the new skill included

After global setup, shared skills are available to Claude via `~/.claude/skills/` and to Codex via `~/.agents/skills/`. The ChatGPT target requires a manual re-upload to the Custom GPT knowledge base after running sync.

## Adding an external skill

Use this only for official upstream skills that should stay managed externally.

1. Add an entry to `external-skills.json` with `slug`, `name`, `source`, `skill_url`, optional `references_api_url`, optional `commit_api_url`, and `license`
2. Run `scripts/sync-external-skills.sh`
3. Register triggers in `targets/claude/hooks/skill-autotrigger.sh` and `targets/claude/hooks/skill-file-trigger.sh`
4. Add the skill to this file and [docs/commands.md](commands.md)

Do not edit synced external `SKILL.md` files directly; change the upstream source or local trigger/docs around it.
