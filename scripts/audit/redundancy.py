#!/usr/bin/env python3
"""Detect redundant tool patterns: identical repeated bash, re-read after edit, repeated reads."""
import json, os, glob, collections, datetime, sys

ROOT = os.path.expanduser("~/.claude/projects")
CUTOFF = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=21)

agg = collections.Counter()
examples = collections.defaultdict(list)

for path in glob.glob(os.path.join(ROOT, "*", "*.jsonl")):
    st = os.stat(path)
    if datetime.datetime.fromtimestamp(st.st_mtime, datetime.timezone.utc) < CUTOFF:
        continue
    calls = []
    with open(path, errors="replace") as f:
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue
            if d.get("type") != "assistant" or d.get("isSidechain"):
                continue
            for b in d.get("message", {}).get("content", []) or []:
                if isinstance(b, dict) and b.get("type") == "tool_use":
                    calls.append((b.get("name"), b.get("input") or {}, (d.get("timestamp") or "")[:19]))

    sess = os.path.basename(path)[:8]
    proj = os.path.basename(os.path.dirname(path))[-32:]

    # 1. identical repeated bash commands (>=3 times)
    bash = collections.Counter(str(i.get("command", ""))[:300] for n, i, t in calls if n == "Bash")
    for cmd, c in bash.items():
        if c >= 4 and cmd.strip():
            agg["repeat_bash"] += 1
            examples["repeat_bash"].append((c, proj, sess, cmd[:120]))

    # 2. read of a file immediately after editing it (within next 3 calls)
    for idx, (n, i, t) in enumerate(calls):
        if n in ("Edit", "Write"):
            fp = i.get("file_path")
            for n2, i2, t2 in calls[idx + 1: idx + 4]:
                if n2 == "Read" and i2.get("file_path") == fp:
                    agg["read_after_edit"] += 1
                    examples["read_after_edit"].append((proj, sess, t2, str(fp)[-60:]))
                    break

    # 3. same file read >=4 times
    reads = collections.Counter(i.get("file_path") for n, i, t in calls if n == "Read" and i.get("file_path"))
    for fp, c in reads.items():
        if c >= 6:
            agg["repeat_read"] += 1
            examples["repeat_read"].append((c, proj, sess, str(fp)[-70:]))

print(dict(agg))
for k in examples:
    print(f"\n=== {k} (top) ===")
    ex = examples[k]
    if k in ("repeat_bash", "repeat_read"):
        ex.sort(key=lambda x: -x[0])
    for e in ex[:14]:
        print("  ", e)
