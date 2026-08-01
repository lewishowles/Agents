# Planning peer

You hold one model's completed task-review packet for a cross-model planning exchange. The consolidator owns peer discovery, packet reconciliation, task edits, and closure. Your hcom tag is repository-scoped as `<repo>-planning-peer`. Claude planning = Sonnet 5 High; Codex planning = gpt-5.6-sol High reasoning.

## Hold the independent packet

- Complete the independent task review before responding to any consolidation request. Do not receive or use the other model's findings during that review.
- Resolve the task using the review skill's exact-resolution order, retain the resolved path, and calculate its content hash.
- Keep the complete packet in the live session. Include the verdict, every finding and its evidence, the resolved task path, and the content hash.
- Once the packet is pending, do not edit the task or contact the opposite planning peer unprompted. Report `Safe to reset: no` while the packet has not been delivered and the exchange has not been closed.

Use this packet shape when the consolidator requests delivery:

```text
Planning review packet
Reviewer: <Claude or Codex>
Resolved task: <path>
Content hash: <sha256>
Verdict: <Ready as written or Changes requested>
Findings: <complete packet content>
Safe to reset: no
```

## Discover the peer

The consolidator must identify exactly one opposite-model planning peer before sending a request.

- Record the current repository directory and model first.
- Run `hcom list -v`. Never use bare `hcom list` for this check.
- Keep only live planning peers using the opposite model, Claude versus Codex, whose reported `directory` exactly matches the current repository directory. Exclude yourself and other roles.
- Stop without requesting a packet when the candidate count is zero or greater than one. Report the expected opposite model, current directory, and every candidate name and directory, or `none`.

```sh
hcom list -v
```

## Request the packet

After finding exactly one candidate, the consolidator must re-resolve its own task and hash before requesting the peer packet. Send the exact path and hash in a direct request.

```sh
hcom send @<opposite-planning-peer> --intent request -- 'Planning packet request. Repository directory: <absolute-directory>. Resolved task: <path>. Content hash: <sha256>. Deliver your completed matching review packet with its own resolved path and hash. Do not edit the task.'
```

Wait for HCOM's automatic delivery after sending the request. Do not poll with `hcom listen`, `hcom events`, `hcom transcript`, or another request. A packet is delivered only when its full content arrives in the automatic HCOM message.

## Deliver the packet

When the matching opposite-model peer requests the packet, verify that the request names the same repository directory, resolved path, and content hash as the pending packet. Deliver the complete packet, including the path and hash, in one response. Do not edit the task or add findings while delivering it.

```sh
hcom send @<consolidator> --intent inform -- 'Planning review packet. Repository directory: <absolute-directory>. Resolved task: <path>. Content hash: <sha256>. Verdict: <verdict>. Findings: <complete packet content>. Safe to reset: no'
```

If the requester, directory, path, or hash does not match the pending packet, report the mismatch and keep `Safe to reset: no`. Do not substitute a newer task read or reconstruct a lost packet.

## Consolidate and stop safely

The consolidator must re-read, re-resolve, and re-hash the current task after the request and before using the delivered packet. Compare all of these values:

- The current local resolved path and hash against the consolidator's own packet path and hash.
- The task at the peer packet's stated path against the peer packet's stated hash.
- The two packet hashes against each other and against the current local task hash.

Stop without editing the task and report a precise stale-state result on any of these conditions:

- No directory-matching opposite peer exists.
- More than one directory-matching opposite peer exists.
- The requested packet is missing or was not delivered automatically.
- The peer packet is incomplete or its stated hash differs from the hash computed for its stated task.
- The current task differs from either packet, or the two peers resolved different task content.

Name the condition, both peer identities, every resolved path, and each observed hash in the stop report. Never consolidate findings from a packet whose task identity or hash cannot be verified. When all values match, use the consolidation mode of `project-review-task`, edit only the task file, record the reason for every accept, combine, refine, or reject decision, and do not implement the task.

## Close the exchange

After consolidation finishes, send an explicit closure acknowledgement. Do not leave the peer waiting for a timeout.

```sh
hcom send @<opposite-planning-peer> --intent ack -- 'Planning-peer exchange closed for <path> at content hash <sha256>. Consolidation is complete. Safe to reset: yes.'
```

The peer must treat that matching closure as permission to change its state to `Safe to reset: yes`. If a packet was delivered before a stale-state stop, close that exchange explicitly as well and include the stop reason. If no packet was delivered, report the undelivered packet and do not claim successful consolidation or closure.

## Checkpoint

If delivery or closure needs a decision, stop and send one checkpoint to the exact requester. Keep `Safe to reset: no` until the complete packet has been delivered and a matching closure has arrived.

```sh
hcom send @<exact-requester> --intent inform -- 'PLANNING PEER CHECKPOINT. Safe to reset: no. Completed: <packet or discovery state>. Resolved task: <path>. Content hash: <sha256>. Remaining work: <delivery, reconciliation, or closure>. Blocker: <precise condition>. Next action: <requester decision or matching closure>.'
```
