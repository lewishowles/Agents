## Subagent delegation

Delegation is opt-in, not default. Consider it when a plan has 3+ independent tasks that don't share files and the work is well-specified. Do not delegate single-file changes, quick fixes, or tasks with high interdependency — the token overhead of re-reading files outweighs the benefit.

**Review gate.** When reviewing subagent output, use a fresh agent with no intent framing — describe the current behaviour and what to verify, not what you hoped it would do. For security-sensitive or high-stakes work, require two independent runs to agree before committing. For load-bearing changes, run one pass that checks whether the test or verification would have failed under the old broken behaviour, separate from the general code/architecture pass.

**Delegation packet.** Before launching a subagent, state its scope, explicit non-scope, and the evidence or gate that proves the work is done — not just what to build. When the task includes a cohesive subsystem whose ownership is not obvious from its caller, name the owning unit and its public contract. State which state, lifecycle, accessibility, and responsive behaviours it owns, and which remain with the caller. Leave internal implementation choices to the implementer. Known future consumers make this especially important. State the abstraction budget as part of the packet: name any composable, helper, or shared file the implementer may create. Absent that, the answer is none.

**Receipt contract.** Delegated agents must return: files touched, tests run, exact blocker encountered, or "no change" if nothing was modified, plus a stopping reason (done, blocked, needs approval, or no further progress possible). Reject any result that omits this.

**Mid-session advisor.** In Claude CLI, `/advisor` can escalate to Opus for a second opinion mid-session without spawning a full subagent. Use it for planning, synthesis, or final review when the task doesn't warrant full delegation.

**Model by role.** Match model capability to the task: Haiku for mechanical extraction, high-volume formatting, file inventories, structured fact extraction, mechanical comparison of identified file sets, and log categorisation. Delegate those tasks only when there are 3+ independent, well-bounded batches. Keep task selection, interpretation, change decisions, root-cause analysis, and final verification with the main agent. Do not dispatch Haiku for a single known-file read, existence check, or one-off lookup, because dispatch overhead exceeds the saving. Sonnet is for implementation and focused code changes; Opus is for planning, cross-file synthesis, and final review.

The main agent acts as architect and reviewer; subagents act as implementers. Subagent support depends on the agent runtime — if unavailable, fall back to sequential chunked work.
