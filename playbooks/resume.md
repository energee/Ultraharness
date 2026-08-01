# resume.md — triage for an improve run another session left mid-finding

Read this from `playbooks/improve.md`, when its readiness probe finds an
`in-progress` ledger entry: a previous run died mid-finding or mid-wave, and this file
owns working out where each active finding stopped and where to re-enter the loop. It
lives apart from
`improve.md` deliberately — the common path (a fresh run on a healthy queue) never
needs any of it, and prose the common path never needs is prose the common path
should not have to read. `<target>`, the base branch, and every step number below
refer to `playbooks/improve.md`.

## Report the handoff quality

Say in your first report what the ledger told you — every entry you are picking up,
its status, attempts, dependency/write metadata, and any merge-queue eviction — **and
what it failed to tell you**: what you had to
reconstruct from the worktree, the diff, or the branch tip because no entry recorded
it. The second half is the useful half. The ledger is the whole handoff, so every gap
you had to fill is a defect in its format, and one nobody can see from inside the
session that wrote it.

## Triage every in-progress entry

Triage every `in-progress` entry in ledger rank order before starting new work. An
entry is resumed at whatever step its worktree, attempts count, and recorded evidence
indicate: if its worktree `<target>/.agents/worktrees/<finding-slug>/` exists, work
out where the pass died from the **worktree status and the branch tip's message**
first; topology alone cannot tell you. In the normal case every merge fast-forwards —
step 3 cuts the branch from base — so a landed fix can leave base tip == branch tip,
the same shape as a branch that never committed anything. In a wave, earlier
candidates may also have advanced base while later worktrees still point behind it.
`--merged` says "merged" for untouched branches too, and identity with base's tip
proves nothing. Step 7 owns bringing a real candidate up to current base.

Run `git -C <worktree> add -AN` (so new files show) then
`git -C <worktree> status --porcelain`, and evaluate these **in order**, taking the
first that matches:

- **Non-empty** — the pass died mid-fix and its work is that uncommitted diff.
  Inspect it and continue from step 4 or step 5.
- **Empty, and the ledger evidence begins `merge-queue-evicted:`** — the candidate
  was deliberately withheld after an update conflict or failed post-update
  verification. Follow the recorded root cause and safe next repair, then resume at
  step 4 or step 5. Never route an evicted commit straight back to merge merely
  because its message has the `fix(...)` form.
- **Empty, and the branch tip's first line begins `fix(<this finding's slug>):`**
  (step 7 mandates exactly that form): this pass committed its fix. Match the
  closing `):` too — a bare substring test also matches a sibling finding whose slug
  merely extends this one (`dup-blocks` inside `dup-blocks-tests`), and that
  sibling's commit read as this pass's own is the one misfire that silently marks a
  finding `done` with no fix ever written. Only now does topology decide which — if
  that commit is reachable from the base branch it landed. Require the ledger's
  `fixed-by`, pinned PASS evidence, and `verified-by` to match that tip before jumping
  to step 7's `done` update; if any is absent, rerun the pinned evaluator against
  `<tip>^..<tip>` first. Step 7 permits exactly one finding commit above its base, so
  that range is the complete candidate; if the landed history violates that invariant,
  stop with a `proof` gap instead of reviewing only the tip. If the tip is not
  reachable, the merge never happened, so resume at step 7's update,
  pinned-commit verification, and serial merge gate.
- **Empty, and the branch tip's first line does not begin `fix(<this finding's
  slug>):`** — the tip belongs to some earlier pass, so this one never committed
  anything. Treat it as `open` and restart the pass at step 3, following the reuse
  rules below. Do not test this by comparing the branch tip against base's tip: after
  a fast-forward they match on a landed fix too.

If no worktree exists but `harness/<finding-slug>` does, inspect that branch tip with
the same ordered rules before deciding. Recreate its worktree without `-b`: an evicted
or `fix(...)` commit is durable work to repair or reverify, not something to reset.
Only when neither the worktree nor a branch carrying this pass's commit exists do you
treat the entry as `open` and restart it (increment nothing — attempts count only
completed fix attempts).

## Reusing a leftover worktree or branch

Arriving at step 3 from a restart route above, the worktree or the branch — or both —
may already exist while holding no work. Do not improvise; take the case that applies:

- **Both exist**: reset the branch to the current base branch from *inside* the
  worktree (`git -C <worktree> reset --hard <base>`). `git branch -f` refuses while a
  worktree has that branch checked out. Then reuse the worktree.
- **Branch exists but its worktree does not**: add a worktree onto the existing branch,
  naming it *without* `-b` — `-b` fatals on a name that already exists — then reset as
  above.
- **Neither exists**: step 3's normal path.

Deleting whatever exists and re-cutting both is always a valid substitute. Either way
the pass starts from current base, so step 7 has only this pass's fix to merge.
