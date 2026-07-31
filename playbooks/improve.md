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
   run died mid-finding — read `<harness>/playbooks/resume.md` and follow its triage
   before starting anything else. Never start fresh work while an `in-progress` entry
   sits unexamined. This read also tells item 4 whether this is a resumed run.
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
     suite IS finding #1, slug `missing-tests`. While no suite exists, a pass whose
     diff adds no tests gets **PASS (unverified-by-tests)** from `playbooks/verify.md`
     per its own §5 — not a FAIL, and it does not count toward the 3-attempt limit.
     The trigger is the diff, not which finding is being worked: **any** pass whose
     diff introduces test files is verified by running the suite it just added
     (verify's probe item 3), so it earns a normal PASS or FAIL, and those FAILs do
     count. Without that, the pass that adds tests could never fail, never park, and
     never reach the Hard stop below — and a broken new suite would pass its own gate.
   - Only a `.agents/AGENTS.md` that records no test entry at all (neither `none` nor
     `none verified`) means seeding is incomplete — run `playbooks/seed.md` first.

## Workflow

Loop the following. One pass = one finding.

### 1. Get the queue

- If the ledger has `open` or `in-progress` entries, that is your queue — do not
  re-audit first. An `in-progress` entry is resumed at whatever step the triage in
  `<harness>/playbooks/resume.md` indicates — follow it rather than judging from
  branch topology; merges here normally fast-forward, so a landed fix and a branch
  that never committed anything look identical from topology alone.
- If the ledger has no open entries (first run, or queue drained), run
  `playbooks/audit.md` on the target. It writes ranked `open` entries and a top-3
  queue into the ledger.
- **If readiness step 5 recorded a red baseline**, add its entry to the queue now,
  ranked above everything already in the queue: slug `red-baseline`,
  principle slot `testing`, severity `high`, `file:line` the first failing assertion,
  the quoted summary line as evidence.
  - **Unless the ledger already carries a baseline entry** — slug `red-baseline`
    (failing suite) or `missing-tests` (no suite at all), one of each per target, ever.
    If that entry is `open` or `in-progress`, it is already your queue's head; work it.
    If it is `parked`, the baseline is broken for a reason a previous run could not
    resolve and recorded a ruling for: that is the Hard stop below, immediately — stop
    the run and report the existing ruling. Writing a second entry would hand the
    parked finding a fresh 0/3 budget and walk straight back into the loop the hard
    stop exists to end.
- **If readiness step 5 found no test suite at all**, the missing suite is finding #1
  under slug `missing-tests`, ranked above everything already in the queue, subject to
  the same guard. The audit may also raise it under a slug of its own — if so, that is
  this entry; rename it rather than tracking two. For a web target, the smallest suite
  that closes `missing-tests` can be one browser smoke test committed into the target —
  written against CDP (`connectOverCDP`) so the browser stays swappable: Chromium by
  default, Lightpanda where its memory and startup budget earn it.

### 2. Pick

Take the highest-ranked `open` finding and choose the smallest intervention that
owns the problem — the earliest point in the causal chain where one change fixes it,
not the broadest refactor that would also fix it. Update its ledger entry to
`status: in-progress` before doing anything else.

Three standing rules shape what counts as an improvement:

- **Removal earns equal rank.** Deleting code, dependencies, dead config, or harness
  artifacts that no longer earn their maintenance cost — including files this
  harness itself seeded — is a first-class fix, ranked by the same
  severity/radius/effort rules as additions.
  - **Except at a boundary.** Guard precedence (the `## Guard precedence` section of
    `<target>/.agents/principles.md`) binds this rule: a guard is not dead because
    nothing in the tree calls it. Framework-dispatched guards — decorators, route
    registrations, middleware, lifecycle hooks — have zero in-tree callers by
    construction. Removing one requires showing the boundary itself is gone.
- **Irreversible fixes are the human's call.** If the smallest intervention that owns
  the problem would destroy persisted data (dropping a column, table, migration, or
  serialized field) or remove a guard, do not attempt it. Moving a guard is not
  removing one: consolidating duplicated checks into a shared home that every affected
  boundary still calls is a normal fix, not a park — that is the DRY finding doing its
  job.

  Park it `parked(authority)`, with the three fields the ledger requires: gap
  `authority`; evidence, exactly what the fix would destroy; unpark condition, a
  human's explicit go-ahead for that specific deletion. Until then the entry is not in
  the queue, whatever its attempts count says.

  The attempts count depends on how you got here. At **step 2** nothing has been built
  yet — no worktree, no attempt — so record `attempts: 0/3`, and note that this is a
  policy park, not an untouched budget for a later run to spend. Arriving from a
  **step 5 guard FAIL**, a worktree and real attempts exist: leave the count as it
  stands rather than resetting it, and revert the worktree as the failure path does —
  unless this is the baseline finding, whose worktree that path deliberately keeps.

  Commit the ledger on the base branch before moving on: this rule can exit the pass
  before step 8, which would otherwise be what commits it, and an uncommitted ruling
  does not survive a checkout. Then move to the next finding and the run continues —
  unless this is the baseline finding (readiness step 5's #1), which stops the run per
  Hard stops. This loop merges unattended and `playbooks/verify.md` cannot prove a
  deletion was safe, so the one class of fix `git revert` cannot undo is the one class
  a human decides.
- **Docs travel with the change.** Update stale comments, docstrings, and docs that
  reference the changed behavior in the same change, per finding — never deferred to
  a cleanup pass.

### 3. Isolate

Create a worktree for this one finding at
`<target>/.agents/worktrees/<finding-slug>/` on a new branch
`harness/<finding-slug>`, branched from the run's base branch (readiness step 4).
One finding, one worktree, one branch. All fix work happens inside it.

Arriving here from one of `playbooks/resume.md`'s restart routes, the worktree or the
branch — or both — may already exist while holding no work. Follow that file's
"Reusing a leftover worktree or branch" rules rather than improvising; either way the
pass starts from current base, so step 7 has only this pass's fix to merge.

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
the failure path below. One FAIL is not iterable: a guard-precedence FAIL, where the
fix *is* the deletion, so retrying produces the same verdict three times — route that
one to step 2's irreversible-fixes rule instead of incrementing.

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
Co-Authored-By line. Read step 8's docs bullet **before** making that commit: the
`conventions.md` corrections it asks for belong in *this* commit, and by the time you
reach step 8 this branch is merged and gone. That form is not decoration: the resume
triage (`playbooks/resume.md`) matches it, with
the closing `):`, to tell this pass's commit from an earlier pass's. A message without
it leaves a resumed run unable to tell a committed fix from an untouched branch, and a
looser form lets a sibling slug that extends this one match instead. On a resume that
already carries its commit (the
triage's second state), there is nothing left to commit: skip straight to the merge, and
never manufacture an empty commit to satisfy this sentence. Then merge the branch into
the run's base branch,
which requires the target checked out on it (readiness step 4 guaranteed that). If the
merge conflicts with work from an
earlier pass, resolve it now, re-verify, then merge — never leave a finding stranded
on its branch. Then, BEFORE deleting the worktree, update the ledger entry:
`status: done`, final `attempts`, and `delta` with before/after evidence (e.g.
`dup blocks 14 → 9; tests green` — quote real output, not recollection). Re-check the
delta against the tree **as you write it**: run the grep or command that proves each
claim in it, and count what you claim to have changed. A delta is the one line a future
session takes on trust without re-deriving, and nothing downstream verifies it — a
pass that fixed one of two citations and wrote "citations" plural leaves the next
session believing the work is finished. The ledger
must never claim less than reality: a run that dies between merge and ledger write
would otherwise leave a landed fix marked `in-progress` with no worktree, which the
resume triage (`playbooks/resume.md`) cannot distinguish from unstarted work. Only after the ledger
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
- **Name what you actually read.** State, in the report, which seeded context this
  pass consumed: the conventions it followed, the learnings it heeded, the lens or
  rubric entry the finding came from — or `none applied`, which is an honest and
  common answer. Available is not retrieved: a `conventions.md` no pass ever opens is
  indistinguishable from one that does not exist, and `none applied` repeated across
  passes is the evidence that a seeded file is not earning its place.
- **Say what you wished you had.** One line in the report for anything this pass had
  to rediscover, work around, or guess: a fact recorded nowhere, a command that did
  not exist, a rubric that did not cover the case. This is telemetry for whoever
  maintains the harness, not context for the next session — it goes in the report, not
  into the target. Nothing missing, nothing written.
- If the fix changed code that `<target>/.agents/conventions.md` cites, or made one of
  its claims false, correct that claim **in the fix commit** — docs travel with the
  change — which means doing it back at step 7, before that commit closes.
  The stamp cannot travel with it: a file cannot contain its own commit SHA. So advance
  `recorded-at` here, in this checkpoint commit, naming the **merged fix commit's** SHA
  — and `AGENTS.md`'s `Verified at` likewise whenever you re-ran a recorded command.
  Two commits, deliberately: the corrected claim rides with the change, the stamp names
  what it was verified against. Splitting them is not sloppiness to apologise for; one
  commit holding both is impossible.
  Advancing a stamp without re-checking the claims under it is the one thing the stamp
  must never do: it launders old prose as freshly verified. Re-check **every** claim in
  the file, not just the one you set out to change: a fix that shifts lines in a cited
  file voids that file's other citations too, and those are the ones nobody looks at.
- Make a checkpoint commit in the target covering everything this pass still has
  uncommitted: the ledger update, and any `AGENTS.md`, `conventions.md`, or
  `learnings.md` edit above.
  The fix itself is already on the base branch — step 7's merge put it there — so it
  is not part of this commit. No Co-Authored-By lines. Then confirm the target's
  working tree is clean.
- Report scope remaining: findings done this run, findings still open, envelope
  budget left. On multi-hour runs, pause here for a user checkpoint between phases
  before continuing.
- **Hand off here or nowhere.** If your working context is filling — long transcripts,
  a compaction warning, degraded recall of earlier passes — this is the only safe
  place to stop and let a fresh session continue. The tree is committed, the ledger
  says `done`, the worktree is gone: a resumed run needs nothing this session holds.
  Mid-pass is the opposite — an uncommitted worktree is the resume path's messiest
  case, so finish or cleanly abandon the pass first.

  The handoff is one line, and it is deliberately fixed:

  ```
  Read <target>/.agents/AGENTS.md and continue the improve run.
  ```

  Do **not** write a handoff summary. A summary is composed by the most depleted
  context in the run, from memory, at the moment its memory is worst — and every other
  step here refuses summaries in favour of evidence. The ledger is better because each
  line was written by a fresh context at the moment it acted. If that one line is not
  enough for the next session to proceed, the defect is in the ledger, not the prompt:
  fix the ledger, and never grow the prompt to compensate.

### 9. Repeat

Return to step 1. When the queue is empty, re-run `playbooks/audit.md`. Completion
requires 3 consecutive queue-empty confirmations — audit, find nothing new, and
repeat twice more. New findings at any re-audit reset the count and re-enter the
loop, envelope permitting.

## Stop conditions

### Run log — every exit

However a run ends — the queue drained and confirmed empty (step 9), an envelope
trip, or any stop below — append one line to `<harness>/docs/runs.md` before the
final report: date, target, findings done / parked / still open, the verdict mix,
the gauges movement (the script's `gauges:` line from this run's first audit and
from its most recent one, `start → end`), and anything step 8's "say what you wished
you had" produced. One line per run, not per pass. If the wish matches a line already
in that file's `## Recurring wishes` tally, increment its `seen` count instead of
re-recording it — the promotion rule lives with the tally. Fixtures built by
`playbooks/self-test.md` are not runs — self-test improve passes skip this line. The
log is telemetry about the harness, so it lives in the harness repo, never in the
target.

### Authority envelope

The safety envelope below bounds how *much* a run does; this bounds *what* it may do.
Inspection authority is not mutation authority. Without asking, a run may change the
target's own source, tests, and docs, and write the files this harness owns. It may
not, without explicit user say-so in this run: push, open or merge a pull request,
change the target's remote, rewrite published history, touch CI/deploy config or
secrets, add or upgrade a dependency, delete a test, or switch the target's checked-out
branch. Merging a finding's branch into the run's base branch locally is inside the
envelope — that is step 7, and it is local and revertible; getting that work off the
machine is not.

An action outside the envelope is not a hard stop: park nothing, finish the pass, and
name the action in the report as something waiting on the user. If the *fix itself* is
impossible without one — a dependency upgrade is the finding — that is
`parked(authority)` with the ruling naming the grant that would unpark it.

### Safety envelope

Defaults, user-overridable at run start: **max 10 findings or 4 hours per run**,
whichever trips first. **Context is a third dimension** with no fixed number: when
your own working context is filling, treat that as the envelope tripping and take the
handoff in step 8. It trips only at a pass boundary — an envelope that stops a run
mid-fix trades one problem for a worse one. When any of them trips: finish or cleanly
abandon the current pass
(a half-done pass reverts its worktree and returns the entry to `open` with a note),
write the ledger, report scope remaining, and stop — following the record-and-commit
rule at the end of Hard stops, which covers this exit too. Never quietly run past the
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
the resume triage cannot mistake it for a landed fix — and record its **commit SHA**
in the ruling. The SHA, not the branch name: step 3 resets `harness/<finding-slug>` and
step 7 deletes it, so the branch stops pointing at the attempts the moment anyone
unparks the finding, which is exactly when someone follows the pointer. An uncommitted
worktree is not preservation: step 3's reset path wipes it the moment anything
restarts the finding. Leave the worktree in place too, and say in the
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
    `<harness>/templates/agents-dir/ledger.md`). It is a run record, not a finding, so it does
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

Every row this playbook carried restated a numbered step, and the restatement class
was removed 2026-07-26 on ablation evidence — see `<harness>/docs/ablations.md`. A
row goes in only when a real run makes an excuse no numbered step already forbids.
