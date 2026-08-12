# Project review task fixtures

These tiny task files are manual behaviour traps for the prompt-driven `project-review-task` skill. Use the fixture path or title described below as the review input, then compare the result with the expected behaviour.

## Fixtures

- `exact-task.md`: pass its explicit path or exact slug. One candidate resolves, so review proceeds with that task.
- `ambiguous-task-a.md` and `ambiguous-task-b.md`: request the exact title `Add an ambiguous fixture label`. Two candidates match, so resolution stops and reports both paths.
- Missing task: request a path such as tests/fixtures/project-review-task/missing-task.md. That file does not exist in this directory by design, so resolution stops with a missing-task result rather than selecting a nearby fixture.
- `unchanged-approval.md`: review the strong contract as written. The expected verdict is `Ready as written`; do not manufacture findings.
- `altitude-failure.md`: review the deliberately vague contract. The expected result is a change request for insufficient altitude and acceptance detail.
- `task-mutation.md`: read and hash the task, change its contract before the verdict, then re-read it. The expected result is a stale-review result because the task changed during review.

## Peer-scenario behaviour traps

Use `exact-task.md` as the underlying task for each scenario unless the setup says otherwise. These are prompt-driven checks, not an automated harness.

- Missing packet file: write your own packet file, then begin consolidation before the opposite model's packet file exists. The consolidator must stop with an exact missing-packet report naming the expected path, and must not wait, poll, or edit the task.
- Cross-peer hash mismatch: give the two packet files different content hashes for their resolved task. The consolidator must stop with the two paths and hashes, identify the stale-state condition, and leave the task unchanged.
- Task mutation after review across peers: complete both reviews, mutate `exact-task.md`, then begin consolidation. Re-resolution and re-hashing must detect the current hash drift and stop before combining findings or editing the task.
