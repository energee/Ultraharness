# Ledger

Findings and their status, across sessions. Append entries; newest at the bottom.

## Run state

Written by `playbooks/improve.md` at run start and read back by a resumed run. One
block, updated in place — not appended per run.

```
- base branch: <branch the entries below were worktree'd from>
```

## Entry format

```
## <date: ISO YYYY-MM-DD> <finding-slug>
- finding: [<principle>/<severity>] <file:line> — <what>
- status: open | in-progress | done | parked(<gap: context|capability|authority|proof|feedback>)
- attempts: <n>/3
- delta: <before → after evidence, e.g. "dup blocks 14 → 9; tests green">
- ruling: <parked entries only — which gap, what evidence, what would unpark it>
```

`file:line` records where the finding was **seen at audit time**, not where it lives when
someone works it. Earlier passes in the same run move code, so re-locate the finding
before fixing it: a citation that no longer resolves means the entry is a stale pointer,
never that the finding's scope is empty.

## Run stop format

Written by any playbook that stops a run early. This is a run record, not a finding:
no status, no attempts, no delta.

```
## <date: ISO YYYY-MM-DD> run-stopped
- stopped: <what stopped the run>
- unblocks: <what would clear it>
```

## Standing rules

- Never delete entries — mark them done or parked instead; the history is the point.
- Parked requires a written ruling: which gap, what evidence, what would unpark it.
- One failed run never establishes "worker limitation" — retry before concluding
  anything about capability.

---
