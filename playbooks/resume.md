# resume.md — triage for an improve run another session left mid-finding

Read this from `playbooks/improve.md`, when its readiness probe finds an
`in-progress` ledger entry: a previous run died mid-finding, and this file owns
working out where it died and where to re-enter the loop. It lives apart from
`improve.md` deliberately — the common path (a fresh run on a healthy queue) never
needs any of it, and prose the common path never needs is prose the common path
should not have to read. `<target>`, the base branch, and every step number below
refer to `playbooks/improve.md`.

## Report the handoff quality

Say in your first report what the ledger told you — the entry you are picking up,
its status, its attempts — **and what it failed to tell you**: what you had to
reconstruct from the worktree, the diff, or the branch tip because no entry recorded
it. The second half is the useful half. The ledger is the whole handoff, so every gap
you had to fill is a defect in its format, and one nobody can see from inside the
session that wrote it.

## Triage the in-progress entry

An `in-progress` entry is resumed at whatever step its worktree and attempts count
indicate: if its worktree `<target>/.agents/worktrees/<finding-slug>/` exists, work
out where the pass died from the **worktree status and the branch tip's message**
first; topology alone cannot tell you. In the normal case every merge fast-forwards —
step 3 cuts the branch from base and nothing commits to base until step 8 — so a
landed fix leaves base tip == branch tip, the same shape as a branch that never
committed anything. `--merged` says "merged" for both, and identity with base's tip
proves nothing. (A branch left over from an interrupted run can be stale enough that
later passes moved base; step 7 handles that merge.)

Run `git -C <worktree> add -AN` (so new files show) then
`git -C <worktree> status --porcelain`, and evaluate these **in order**, taking the
first that matches:

- **Non-empty** — the pass died mid-fix and its work is that uncommitted diff.
  Inspect it and continue from step 4 or step 5.
- **Empty, and the branch tip's first line begins `fix(<this finding's slug>):`**
  (step 7 mandates exactly that form): this pass committed its fix. Match the
  closing `):` too — a bare substring test also matches a sibling finding whose slug
  merely extends this one (`dup-blocks` inside `dup-blocks-tests`), and that
  sibling's commit read as this pass's own is the one misfire that silently marks a
  finding `done` with no fix ever written. Only now does topology decide which — if
  that commit is reachable from the base branch it landed, so jump to step 7's
  ledger update; if it is not, the merge never happened, so resume at step 7's merge.
- **Empty, and the branch tip's first line does not begin `fix(<this finding's
  slug>):`** — the tip belongs to some earlier pass, so this one never committed
  anything. Treat it as `open` and restart the pass at step 3, following the reuse
  rules below. Do not test this by comparing the branch tip against base's tip: after
  a fast-forward they match on a landed fix too.

If no worktree exists, treat the entry as `open` and restart the pass (increment
nothing — attempts count only completed fix attempts).

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
