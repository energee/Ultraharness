# improve.md — the long-runtime fix loop

The long-runtime loop: audit the target, then work the findings queue one at a time —
isolate, fix minimally, verify, de-sloppify, checkpoint — until the queue is empty or
the safety envelope trips. The ledger at `<target>/.agents/ledger.md` is the loop's
memory: every state change is written there first, so a run killed mid-finding can be
resumed by any agent from the ledger alone.

## Readiness probe

Confirm all of these before starting the loop; if any fails, stop and fix it first.

1. You have a target repo path. If none was given, ask for one.
2. The target is seeded: `<target>/.agents/` exists with `ledger.md`,
   `principles.md`, and `conventions.md`. If not, run `playbooks/seed.md` first.
3. Read the ledger top to bottom. Entries with status `in-progress` mean a previous
   run died mid-finding — resume those first (see Workflow step 1). Never start
   fresh work while an `in-progress` entry sits unexamined. This read also tells
   item 4 whether this is a resumed run.
4. **Base branch.** Read the ledger's `Run state` block. A `- base branch:` still
   holding the seeded placeholder — any angle-bracket `<...>` value — is not a
   recorded value; treat it as absent. Then:
   - **Resumed run** (item 3 found `in-progress` entries) *and* a real recorded
     branch: that recorded branch is this run's base branch — a resumed run must
     merge back into the branch its worktrees were cut from, not into whatever
     happens to be checked out now. Then confirm the target is still checked out on
     it; if not, stop and report both branches. Merging back requires that checkout
     and this playbook never switches it, so a disagreement is unresolvable here —
     do not guess which is right.
   - **Otherwise** — a fresh run, or no recorded value — the base branch is the
     branch the target has checked out at run start; write it to the ledger's
     `Run state` block as `- base branch: <name>` before starting. A ledger seeded
     before that block existed has no `Run state` section: add one, matching the
     template's, directly above `## Entry format`.

   Either way, every branch below is cut from it and merged back into it. Never
   substitute `main`/`master` for it, and never switch the target's checkout.
5. **Clean-baseline gate.** Run the target's test suite (the test command from
   `<target>/.agents/AGENTS.md`). A red baseline does not block the run; it becomes
   finding #1, ranked above everything else, and is fixed first so every later
   failure is attributable to a change, not to the starting state. Record the
   baseline result (pass/fail, quoted summary line) before touching anything.
   - A red baseline is *your* finding to write, not the audit's — `playbooks/audit.md`
     grades code quality, and its `testing` slot covers only a missing evidence base
     (no suite, or a suite that asserts nothing). A suite that runs, asserts, and
     fails is neither, so audit emits nothing for it. Carry the red result into step
     1, which writes the entry; do not write it here, or step 1 would see a non-empty
     queue and skip the audit entirely.
   - If `.agents/AGENTS.md` records `none verified` or `none` for tests, proceed:
     both mean the same thing here — there is no test suite to run. The missing test
     suite IS finding #1. For every *other* finding, while no suite exists,
     `playbooks/verify.md` returns **PASS (unverified-by-tests)** per its own §5 —
     that verdict is not a FAIL and does not count toward the 3-attempt limit. Finding
     #1 itself is the exception: the pass that adds the suite is verified by running
     the suite it just added (verify's probe item 3), so it earns a normal PASS or
     FAIL, and its FAILs do count. Without that exception the missing-tests finding
     could never fail, never park, and never reach the Hard stop below — and a broken
     new suite would pass its own gate.
   - Only a `.agents/AGENTS.md` that records no test entry at all (neither `none` nor
     `none verified`) means seeding is incomplete — run `playbooks/seed.md` first.

## Workflow

Loop the following. One pass = one finding.

### 1. Get the queue

- If the ledger has `open` or `in-progress` entries, that is your queue — do not
  re-audit first. An `in-progress` entry is resumed at whatever step its worktree
  and attempts count indicate: if its worktree
  `<target>/.agents/worktrees/<finding-slug>/` exists, work out where the pass died
  from the **worktree status and the branch tip's message** first; topology alone
  cannot tell you. In the normal case every merge here fast-forwards — step 3 cuts the
  branch from base and nothing commits to base until step 8 — so a landed fix leaves
  base tip == branch tip, the same shape as a branch that never committed anything.
  `--merged` says "merged" for both, and identity with base's tip proves nothing.
  (A branch left over from an interrupted run can be stale enough that later passes
  moved base; step 7 handles that merge.)

  Run `git -C <worktree> add -AN` (so new files show) then
  `git -C <worktree> status --porcelain`, and evaluate these **in order**, taking the
  first that matches:
  - **Non-empty** — the pass died mid-fix and its work is that uncommitted diff.
    Inspect it and continue from fix or verify.
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
    anything. Treat it as `open` and restart the pass. Do not test this by comparing
    the branch tip against base's tip: after a fast-forward they match on a landed fix
    too.

  If no worktree exists, treat it as `open` and restart the pass (increment nothing —
  attempts count only completed fix attempts).
- If the ledger has no open entries (first run, or queue drained), run
  `playbooks/audit.md` on the target. It writes ranked `open` entries and a top-3
  queue into the ledger.
- **If readiness step 5 recorded a red baseline**, add its entry to the queue now,
  after the audit, ranked above everything the audit produced: slug `red-baseline`,
  principle slot `testing`, severity `high`, `file:line` the first failing assertion,
  the quoted summary line as evidence.
  - **Unless the ledger already carries a `red-baseline` entry** — one per target,
    ever. If that entry is `open` or `in-progress`, it is already your queue's head;
    work it. If it is `parked`, the suite is red for a reason a previous run could not
    resolve and recorded a ruling for: that is the Hard stop below, immediately — stop
    the run and report the existing ruling. Writing a second entry would hand the
    parked finding a fresh 0/3 budget and walk straight back into the loop the hard
    stop exists to end.

### 2. Pick

Take the highest-ranked `open` finding and choose the smallest intervention that
owns the problem — the earliest point in the causal chain where one change fixes it,
not the broadest refactor that would also fix it. Update its ledger entry to
`status: in-progress` before doing anything else.

Two standing rules shape what counts as an improvement:

- **Removal earns equal rank.** Deleting code, dependencies, dead config, or harness
  artifacts that no longer earn their maintenance cost — including files this
  harness itself seeded — is a first-class fix, ranked by the same
  severity/radius/effort rules as additions.
- **Docs travel with the change.** Update stale comments, docstrings, and docs that
  reference the changed behavior in the same change, per finding — never deferred to
  a cleanup pass.

### 3. Isolate

Create a worktree for this one finding at
`<target>/.agents/worktrees/<finding-slug>/` on a new branch
`harness/<finding-slug>`, branched from the run's base branch (readiness step 4).
One finding, one worktree, one branch. All fix work happens inside it.

Arriving here from either of step 1's restart routes, the worktree or the branch — or
both — may already exist while holding no work. Do not improvise; take the case that
applies:

- **Both exist**: reset the branch to the current base branch from *inside* the
  worktree (`git -C <worktree> reset --hard <base>`). `git branch -f` refuses while a
  worktree has that branch checked out. Then reuse the worktree.
- **Branch exists but its worktree does not**: add a worktree onto the existing branch,
  naming it *without* `-b` — `-b` fatals on a name that already exists — then reset as
  above.
- **Neither exists**: the normal path above.

Deleting whatever exists and re-cutting both is always a valid substitute. Either way
the pass starts from current base, so step 7 has only this pass's fix to merge.

### 4. Fix

Make the minimal change that resolves the finding, following the target's recorded
conventions (`<target>/.agents/conventions.md`). Do not refactor surrounding code,
fix unrelated findings you notice (add them to the ledger as `open` instead), or
change approach without recording the pivot in the ledger entry.

### 5. Verify

Run `playbooks/verify.md` inside the worktree. It yields **PASS**,
**PASS (unverified-by-tests)**, or **FAIL**, backed by quoted command output — no
completion claim without it. Both PASS forms are non-FAIL: carry on to step 6, and
record the qualifier verbatim in the ledger `delta` so the run's evidence level is
never overstated. On FAIL, iterate on the fix (never on the test), increment
`attempts: <n>/3` in the ledger, and return to step 4. After 3 failed attempts, take
the failure path below.

### 6. De-sloppify

With fresh eyes, simplify the diff itself — the change, not the surrounding code.
If your environment can spawn a fresh subagent, hand it only the diff and the
finding and ask it to remove slop: leftover debug output, dead branches, needless
abstraction, comments narrating the obvious. Otherwise, do an unrelated
palate-cleanser step first (e.g. write the ledger delta text), then re-read the full
diff line by line and simplify. If de-sloppifying changed anything, run verify again.

### 7. Merge back

Commit the fix on the finding's branch first — an uncommitted worktree has nothing to
merge — with a first line beginning exactly `fix(<finding-slug>): ` and no
Co-Authored-By line. That form is not decoration: step 1's resume path matches it, with
the closing `):`, to tell this pass's commit from an earlier pass's. A message without
it leaves a resumed run unable to tell a committed fix from an untouched branch, and a
looser form lets a sibling slug that extends this one match instead. On a resume that
already carries its commit (step
1's second state), there is nothing left to commit: skip straight to the merge, and
never manufacture an empty commit to satisfy this sentence. Then merge the branch into
the run's base branch,
which requires the target checked out on it (readiness step 4 guaranteed that). If the
merge conflicts with work from an
earlier pass, resolve it now, re-verify, then merge — never leave a finding stranded
on its branch. Then, BEFORE deleting the worktree, update the ledger entry:
`status: done`, final `attempts`, and `delta` with before/after evidence (e.g.
`dup blocks 14 → 9; tests green` — quote real output, not recollection). The ledger
must never claim less than reality: a run that dies between merge and ledger write
would otherwise leave a landed fix marked `in-progress` with no worktree, which the
resume path in step 1 cannot distinguish from unstarted work. Only after the ledger
says `done`, delete the worktree and the branch.

### 8. Checkpoint

Write every file this pass owes before committing; the commit comes last, so nothing
this pass wrote is left dirtying the target.

- If the fix added or changed the target's build, test, or typecheck command —
  finding #1 on a testless repo is exactly this case — update that entry in
  `<target>/.agents/AGENTS.md` in this same pass, verified by running it. Leaving a
  stale `none verified` there makes every later `playbooks/verify.md` pass skip a
  suite that now exists and return PASS (unverified-by-tests) against real tests. If
  the new command does not run when you verify it, do not record it: fix it or record
  the honest `none verified`, and raise the discrepancy as a new `open` finding.
- If this pass taught something a future session in this repo would need — a
  convention the fix had to follow, a trap that cost an attempt — append one line to
  `<target>/.agents/learnings.md` in that file's format, incrementing `seen` on an
  existing line rather than adding a duplicate. Nothing learned, nothing written.
- Make a checkpoint commit in the target covering everything this pass still has
  uncommitted: the ledger update, and any `AGENTS.md` or `learnings.md` edit above.
  The fix itself is already on the base branch — step 7's merge put it there — so it
  is not part of this commit. No Co-Authored-By lines. Then confirm the target's
  working tree is clean.
- Report scope remaining: findings done this run, findings still open, envelope
  budget left. On multi-hour runs, pause here for a user checkpoint between phases
  before continuing.

### 9. Repeat

Return to step 1. When the queue is empty, re-run `playbooks/audit.md`. Completion
requires 3 consecutive queue-empty confirmations — audit, find nothing new, and
repeat twice more. New findings at any re-audit reset the count and re-enter the
loop, envelope permitting.

## Stop conditions

### Safety envelope

Defaults, user-overridable at run start: **max 10 findings or 4 hours per run**,
whichever trips first. When either trips: finish or cleanly abandon the current pass
(a half-done pass reverts its worktree and returns the entry to `open` with a note),
write the ledger, report scope remaining, and stop. Never quietly run past the
envelope, and never shrink the reported queue to make the run look finished.

### Failure path (per finding)

After 3 failed fix attempts on one finding: stop attempting, set
`status: parked(<gap: context|capability|authority|proof|feedback>)` choosing the
gap that blocked you, and write the ruling the ledger's standing rules require —
which gap, what evidence, what would unpark it. Then revert the worktree and move to
the next finding.

Unless this is the baseline finding (readiness step 5's #1): then the run stops here
instead, and its attempts are kept as evidence — a human resolving an `authority` gap
reads them to see what was already tried. Keeping them means **committing** them, not
just leaving the worktree: commit the last attempt on the finding's branch with a
first line beginning `parked(<finding-slug>): ` — deliberately not the `fix(` form, so
step 1's resume path cannot mistake it for a landed fix — and name that branch in the
ruling. An uncommitted worktree is not preservation: step 3's reset path wipes it the
moment anything restarts the finding. Leave the worktree in place too, and say in the
report that it is there. Everything else about the stop is in Hard stops below.

Never silently drop a finding, and never conclude "worker limitation" from a single
failed run — retry before concluding anything about capability.

### Hard stops

- `.agents/AGENTS.md` records no test entry at all, or the recorded test command
  errors before running any test (command not found, harness crash) → stop; that is
  a seeding gap, report it. A recorded `none` or `none verified` is NOT this stop —
  it proceeds with missing tests as finding #1 (readiness step 5).
- The baseline finding (readiness step 5's finding #1) parked → stop the run.
  Continuing would spend the envelope on the same cause: with a red suite, no later
  fix can be verified at all; with a suite the run failed to *add*, later fixes could
  only earn PASS (unverified-by-tests), so the run would merge a pile of unverified
  changes and call it done. Neither is worth the remaining budget. Write the ledger
  and report it — and leave the baseline worktree in place per the failure path above.
- Verify itself is broken (the harness's gate, not the target's tests) → stop and
  report; do not self-certify fixes.
- The run's base branch moved underneath you in ways you cannot cleanly merge
  → stop, write the ledger, report the conflict.
- **On any stop — the ones above and the safety envelope alike** — record the stop in
  the ledger, then commit it, then report to the user. Both halves matter:
  - **Record it** in the ledger's `Run stop` format (see
    `templates/agents-dir/ledger.md`). It is a run record, not a finding, so it does
    not take the `Entry format` fields — no status, no attempts, no delta. Skip it
    entirely when a parked finding's own `- ruling:` already says both things, as the
    parked-baseline stop does; one honest record beats two that can drift apart.
  - **Commit it.** Every stop bypasses step 8, the only step that commits anything in
    the target, so the ledger write lands in the working tree and stays there. That
    defeats the point of writing it: an uncommitted ledger does not survive a
    checkout, a stash, or a branch switch, and the parked ruling is the most expensive
    thing the run produced. Commit `.agents/ledger.md` on the base branch before
    reporting, and leave the target's tree clean.

## Anti-rationalization table

| Excuse | Rebuttal |
| --- | --- |
| "The baseline is only a little red." | The gate holds. Red baseline = finding #1, fixed first. Nothing else starts before it. |
| "The suite is still red, so I'll open a fresh red-baseline finding." | One per target, ever. A parked `red-baseline` is the hard stop, not a new entry with a new 0/3 budget. |
| "I'll batch five findings in one worktree." | One finding, one worktree, one verify. Batching makes failures unattributable and reverts impossible. |
| "De-sloppify is overhead on a small diff." | It runs. On a small diff it's cheap; on any diff it's where the slop hides. |
| "I'm close — one more attempt past 3 will crack it." | Park it with a gap ruling. The 4th attempt is what the next run, with fresh context, is for. |
| "The envelope tripped but the queue is almost empty." | Stop cleanly, report scope remaining. "Almost empty" is exactly what the next run's ledger is for. |
| "This in-progress entry is stale, I'll just start fresh." | Resume it. The ledger surviving session death is the point — inspect its worktree before deciding anything. |
| "The recorded base branch isn't checked out — I'll just check it out and carry on." | Stop and report both. This playbook never switches the target's checkout; something moved it, and guessing which branch is right is how a fix lands on the wrong one. |
| "The branch reports merged, so the fix is done." | Merges here normally fast-forward, so "merged" — and base-tip identity — is also what a branch that committed nothing looks like. Worktree status and the tip message come first; only then does reachability decide landed vs unmerged. Skipping that last check strands a finding on its branch. |
