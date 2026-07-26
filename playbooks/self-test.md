# self-test.md — prove this harness still works

You are testing the harness repo itself. Everything else here operates on a target
repo; this playbook operates on `<harness>` — and it does so by building a throwaway
target from scratch, running the real playbooks against it, and asserting on what
actually landed. `<harness>` below is this repo's root; `<fixture>` is the throwaway
repo you create in a temp dir.

Nothing in this playbook is satisfied by reading a playbook and judging it sound.
The checks below are assertions about files and command output that exist after a
run. A step you did not run has no result.

## Readiness probe

Check all of these before doing anything else. If one fails, stop and report exactly
what is missing.

1. You are in the harness repo: `<harness>/AGENTS.md`, `<harness>/playbooks/`,
   `<harness>/templates/agents-dir/`, and `<harness>/scripts/` all exist.
2. `git`, `bash`, and a writable temp dir are available.
3. The fixture goes in a temp dir **outside** `<harness>` — never inside it, and
   never in a real repo of the user's. Nothing this playbook does may write to
   `<harness>` except a fix you deliberately make in step 7 and the records steps 1,
   5c, and 5f append (`docs/coverage.md`, `docs/ablations.md`).

## Workflow

### 1. Run the script tests

Run `bash scripts/test.sh` from `<harness>`. Every assertion must print `PASS` and
the run must exit 0. A single `FAIL` stops the self-test here: fix the script or the
test, then start over from this step.

Then record the prose budget: run `wc -l <harness>/playbooks/*.md` and append one
line to the budget table in `<harness>/docs/coverage.md`. If any count grew since
the previous line, name the cause in your report — a budget nobody reads is not a
budget, and growth with no named cause is a finding against whatever run added the
lines.

### 2. Build the fixture repo

Create a fresh directory in a temp dir and `git init` it. It must have, at minimum:

- A `README` naming a **real** test command that actually runs — e.g. a `test.sh`
  that prints `ok` — plus a manifest (`package.json` or the ecosystem equivalent)
  wiring that command up, so there is something for seeding to discover *and*
  verify.
- **A planted duplication**: the same 10-line block copied into two source files,
  so the audit has one real finding to catch. If the fixture is clean, step 5 proves
  nothing.
- **A planted swallowed error**: one call wrapped in a catch that discards it — an
  empty `catch {}`, or a required config value read with a silent default. This is the
  fail-fast rubric's known answer, the way the duplication is DRY's. Unlike the
  duplication it is invisible to `audit-checks.sh`, so it tests whether the rubric was
  applied rather than whether the script ran.
- At least one file large enough to appear in the script's `largest files` list.
- **No lens gate may fire on it.** This fixture is the no-fire case: keep it free of
  retry/queue/webhook/cron/migration/deploy constructs and of component-UI files
  (`.jsx`, `.tsx`, `.vue`, `.svelte`, a `components/` directory with a framework
  import). Run `bash scripts/audit-checks.sh <fixture>` before seeding and confirm both
  its `gates:` lines read `not-fired` — if one fires, adjust the fixture, because step 3
  asserts a no-lens footprint and a fixture that quietly fires a gate would mask a real
  defect.

Commit everything on the fixture's current branch, so seeding starts from a clean
tree. Record the fixture path; every command below runs against it.

### 3. Seed the fixture

Read `playbooks/seed.md` and run it against `<fixture>`, as written — including
verifying the test command by running it. Then assert the exact footprint:

- `<fixture>/.agents/` contains exactly the five files `AGENTS.md`,
  `conventions.md`, `principles.md`, `ledger.md`, `learnings.md` — and, because this
  fixture fires no lens gate (step 2 built it that way), **no `lenses/` directory**.
- The no-fire fixture pays nothing for the lens machinery: no `<fixture>/.agents/lenses/`
  directory, no `## Lenses` section in `<fixture>/.agents/AGENTS.md`, and no lens *file*
  content anywhere under `.agents/` — `grep -rl 'condensed lens' <fixture>/.agents/`
  returns nothing. Zero added lines in the common case is this design's own claim; this
  is where it is checked.

  Grep a phrase the *seeded* file contains. `condensed lens` is line 1 of both files in
  `templates/agents-dir/lenses/`, which are the only lens files seeding ever copies. An
  earlier version grepped `Gate — does this lens apply`, which appears solely in the
  full-form lenses under `<harness>/lenses/` — so it matched nothing even when a lens
  *had* leaked, and would have passed on the very defect it was written to catch. Check a
  new assertion against the artifact it inspects, not against the file you happened to be
  reading when you wrote it.

  Not `grep -ril lens`. That was the assertion here until a run showed it cannot pass:
  `principles.md` is copied byte-identical whether or not a gate fired, so its guard
  precedence section says "governs every rubric and lens" in both cases, and it has to —
  the same bytes must be correct for a repo that does have a lens. An assertion no
  correct implementation can satisfy is a defect in the assertion.
- No placeholders survive: searching `<fixture>/.agents/` for `{{` returns nothing.
- Both stamps landed and resolve: `conventions.md`'s `recorded-at` and `AGENTS.md`'s
  `Verified at` each name a commit `git -C <fixture> cat-file -e <stamp>^{commit}`
  accepts, and it is the commit that was HEAD when seeding started — not a later one.
  A stamp naming the seed commit itself would claim the observations were made against
  a tree that did not exist when they were made.
- `<fixture>/AGENTS.md` and `<fixture>/CLAUDE.md` exist and each carry one pointer
  block.
- `<fixture>/.gitignore` covers `.agents/worktrees/`.
- The seeded files are actually tracked: `git -C <fixture> ls-files .agents/` lists
  all five files. Porcelain alone cannot catch this — a `.gitignore` covering
  `.agents/` makes `git add` skip it silently and porcelain never mentions ignored
  files, so both weaker assertions below would pass on a seed that committed nothing.
- A commit `Seed .agents/ harness` exists in the fixture's log, and
  `git -C <fixture> status --porcelain` shows nothing seeded left unstaged.

Any assertion that fails is a defect in `seed.md`, not in your run of it.

### 4. Re-seed the fixture

Run `playbooks/seed.md` against `<fixture>` a second time, unchanged. Seeding is the
update path, so a second run on an unchanged repo must be a no-op that says so.
Assert:

- The pointer blocks did not double: counting `harness:begin` in both
  `<fixture>/AGENTS.md` and `<fixture>/CLAUDE.md` gives 1 each.
- `.gitignore` gained no duplicate line.
- The tree is strictly clean: `git -C <fixture> status --porcelain` prints nothing.
  Nothing changed between the two runs, so there is nothing a refresh could
  legitimately be refreshing — any diff means the first run left something stale,
  which is itself a defect to fix in step 7.
- No new commit: the fixture's commit count is unchanged and `Seed .agents/ harness`
  appears exactly once in the log. The re-seed's `git commit` exits nonzero with
  "nothing to commit"; the run must report that as "already current, no commit", not
  as a failed seed and not by forcing an empty commit.

### 5. Audit the fixture

Read `playbooks/audit.md` and run it against `<fixture>`, as written. Assert:

- The script's full report is quoted verbatim in the audit output.
- At least one finding — specifically, the planted duplication is caught. An audit
  that misses the block you planted is a failed self-test, not a clean repo.
- The planted swallowed error is caught too, as `[fail-fast/<severity>]`. This is the
  assertion that proves a rubric was *applied* rather than a script quoted: nothing in
  `audit-checks.sh` reports it, so the only way it appears is judgment against
  `principles/fail-fast.md`. An audit that catches the duplication and misses this one
  has quoted facts without reasoning over them.
- Every finding uses the exact format
  `[<principle>/<severity>] <file:line> — <what> — <smallest fix>`, and the list is
  ranked with nothing suppressed.
- `<fixture>/.agents/ledger.md` gained one `open` entry per finding, in the ledger's
  entry format, plus the top-3 slugs. Count only what is **below the template's `---`
  separator**: `ledger.md` documents its own entry format using the same syntax it
  stores entries in, so a naive `grep -c '^- finding: \['` over the whole file counts
  the documentation as a fifth finding and every count assertion reads one high.
- No finding covers the harness's own footprint — `.agents/` and the pointer blocks
  are quoted in the script report but never judged.

### 5a. Prove the gates gate

A gate that never withholds anything is not a gate. Steps 2-5 covered the no-fire
case; this step covers the fire case, and both halves are needed — one fixture that
fires a gate and one that does not.

Build a second fixture, `<fixture2>`, in its own temp dir: same minimum as step 2
(README, real test command, manifest), plus one construct that fires the idempotency
gate and nothing that fires the atomic gate — e.g. a queue consumer that handles a
message and inserts a row, with a retry wrapper around it, and no component-UI files.
Commit it. Run `playbooks/seed.md` against it as written, then assert:

- The script said so before the agent did: the run's `audit-checks.sh` report reads
  `gates: idempotency FIRED` naming a real path, and `gates: atomic not-fired`. This is
  the assertion that separates "the gate discriminated" from "the agent guessed
  correctly" — the seeded footprint below is only trustworthy if it traces to this line.

- `<fixture2>/.agents/lenses/idempotency.md` exists and is byte-identical to
  `<harness>/templates/agents-dir/lenses/idempotency.md`.
- `<fixture2>/.agents/lenses/atomic-design.md` does **not** exist. This is the
  assertion that makes the others mean something: the same run that copied one lens
  withheld the other, on the same repo, from its gate alone.
- `<fixture2>/.agents/AGENTS.md` has a `## Lenses` section naming `idempotency` and
  the evidence that fired it, contains no `{{`, and does not name `atomic`.
- `git -C <fixture2> ls-files .agents/lenses/` lists exactly the one lens file — a
  lens seeded but untracked is not seeded, for the same reason step 3 checks tracking.
- Re-running `seed.md` against `<fixture2>` unchanged copies nothing new and leaves
  `git -C <fixture2> status --porcelain` empty, exactly as step 4 requires.

Then run `playbooks/audit.md` against `<fixture2>` and assert that the lens is applied
without being re-judged: the audit's report names `lenses/idempotency.md` among the
rubrics it read. If it emits an idempotency finding, that finding uses `idempotency`
in the principle slot and is ranked in the one list with everything else. An audit
that finds nothing idempotency-related is not a failure — the fixture is small — but
an audit that never read the lens is.

Delete `<fixture2>` when done, per step 6.

### 5b. Run one improve pass end to end

`improve.md` and `verify.md` are the loop that actually changes a repo, and prose
that has never been executed is unverified. Run exactly one pass.

Build a third fixture, `<fixture3>`: a manifest and a **real test command whose suite
asserts something and is green at run start** (a testless fixture would route every
verdict to PASS (unverified-by-tests) and prove nothing about the gate), plus **two**
planted findings a minimal fix can close — the duplicated block from step 2, and a
second one like it in another pair of files. Commit it, seed it, and audit it, so the
ledger carries a real queue.

Two, not one, because step 5e resumes this same fixture and needs an entry still `open`
after this step closes one. Relying on the audit to incidentally raise a second finding
would make that step's setup depend on a judgment call this playbook does not control.

Then run `playbooks/improve.md` against it with the safety envelope overridden to
**1 finding**, and assert, in order:

- **Baseline gate**: the run recorded the pre-run suite result before touching
  anything, and the ledger's `Run state` block records `- base branch: <the branch the
  fixture had checked out>` — not `main` unless that is what was checked out.
- **Isolation**: a worktree exists at `<fixture3>/.agents/worktrees/<slug>/` on branch
  `harness/<slug>`, cut from the base branch, while the pass is in flight, and the
  entry reads `status: in-progress` before any fix is written.
- **Verify ran for real**: the pass's verdict is one of the three verdicts, and it
  quotes fresh command output. A verdict with no quoted output is a defect in
  `verify.md`, not a formatting nit.
- **Merge back**: the base branch carries a commit whose first line begins exactly
  `fix(<slug>): `, with no Co-Authored-By line, and the fix is present in the
  fixture's working tree.
- **Ledger before deletion**: the entry reads `status: done` with a `delta` quoting
  real before/after evidence, and only then are the worktree and branch gone —
  `git -C <fixture3> worktree list` shows one entry and `git -C <fixture3> branch
  --list 'harness/*'` is empty.
- **Checkpoint**: `git -C <fixture3> status --porcelain` is empty — the ledger update
  is committed, not left dirtying the target.

Assert the negative too, the way step 5a does: the run stopped after one finding
because the envelope said 1, reported scope remaining, and left the still-`open`
entries open. An envelope that never stops a run is not an envelope.

### 5c. Ablate one anti-rationalization row

The playbooks' anti-rationalization tables hold only rows whose action the workflow
body does not already mandate. The 2026-07-26 class removal (recorded in
`<harness>/docs/ablations.md`) deleted every restating row: three independent fresh
contexts, each given a playbook with a restatement row removed, declined the excuse
anyway and cited the body — never the table. Each row still claims an agent would
otherwise make its excuse, and an unfalsified claim is decoration: this step tests
one remaining row per run. A row — or a class of rows sharing the property that
failed — comes out after two independent runs decline its excuse.

The run must be done by a **fresh context** — a subagent, a second session, an agent
that has not read this playbook. You cannot ablate a table you have already read: you
know the rebuttals, so your behaviour is evidence about your memory, not about the
prose. If no fresh context is available, skip this step and say so in the report; a
self-ablation reported as a result is worse than no result.

Pick one row — rotate through them across runs, oldest-untested first, reading
`<harness>/docs/ablations.md` to see which have been tested and when. That file is the
record; without it "oldest-untested" is unanswerable and every run re-tests whatever
row catches your eye. Then:

1. Copy the playbook to a scratch file with **that one row removed**, everything else
   intact.
2. Give the fresh context the modified playbook and a fixture built so the excuse is
   tempting — cheap to make, costly to decline.
3. Record what it actually did, verbatim — not whether it "seemed to understand".

Then judge:

- **It made the excuse** → the row is load-bearing. Keep it, and note the observed
  wording in the report; the row should quote what agents really say, not a
  paraphrase of what you imagined.
- **It did the right thing anyway** → the row is unsupported. Do not delete it on one
  run — record the result and mark the row tested; two independent runs that both
  decline the excuse are grounds for removing it. A table that only ever grows is how
  playbooks become unreadable, and unreadable playbooks are skipped whole.
- **It failed in some *other* way** → that is the more valuable finding. It is a real
  observation about a real run, so step 7 applies: fix the smallest thing that
  explains it, and consider whether that failure deserves a row.

Append the result as one row in `<harness>/docs/ablations.md`, and report it. It does
not go into the target, and it does not go into the playbook — except the row edit
itself, once two runs justify one. New rows enter the same way removals leave:
by observation. A row goes in when a real run actually made its excuse — never
speculatively, and never when a numbered step already mandates the action, which is
the refuted restatement class.

### 5d. Make the record lie, and check the audit notices

A staleness check that has never caught anything is not a check. Break the record on
purpose and confirm the audit reports it.

In `<fixture>`, make two changes and commit them, leaving the seeded `.agents/`
untouched:

1. Move or rename a file that `conventions.md` cites by name.
2. Change the test command in `package.json` (or the ecosystem equivalent) so the one
   recorded in `.agents/AGENTS.md` no longer runs.

Then run `playbooks/audit.md` again and assert:

- It emits a `staleness` finding for the void citation and one for the dead test
  command, both in the standard format, both ranked in the one list.
- The dead command is graded **high** — it blocks a contributor and misleads every
  later verify — and the void citation is not graded high by reflex.
- It did **not** rewrite `.agents/` to make the findings go away. The audit reports;
  re-seeding fixes.
- Claims whose cited paths did not move are reported as still standing rather than
  re-litigated. The stamp exists to make this check cheap; an audit that re-reads
  everything regardless has not used it.

Then re-seed and assert the corrections landed and the stamps advanced **only** on the
files that changed. A stamp advanced without re-checking is the failure this step
exists to catch — it launders old prose as freshly verified — and if a third audit
still reports the same staleness findings, the re-seed did not do its job.

### 5e. Hand off to a fresh context

`improve.md` claims a run can be picked up cold from the ledger alone. That claim is
the whole context-management story, and it is worth nothing untested. Test it by
performing the handoff.

Run a second improve pass on `<fixture3>` far enough to complete one finding — through
step 8, so the tree is committed and the ledger says `done` — with at least one entry
still `open`. Then stop, and hand the run to a **fresh context** with exactly the line
`improve.md` step 8 specifies, and nothing else:

```
Read <fixture3>/.agents/AGENTS.md and continue the improve run.
```

No summary, no explanation of what happened, no pointer to the finding. If you add
context to the prompt, you have tested your own summary rather than the ledger, which
is the one thing this step exists to rule out.

Assert:

- The fresh context picks up the remaining `open` entry without being told it exists,
  works it to `done`, and leaves a clean tree.
- It does not redo the finished finding. Re-executing completed work is the classic
  cold-resume failure, and the ledger's `done` status is what should prevent it.
- Its first report names what the ledger told it **and what it had to reconstruct**
  (readiness item 3). Every reconstructed fact is a defect in the ledger format: fix
  the format under step 7, not the prompt.

Do the same from a mid-pass death if you want the harder case: kill the run with a
worktree left dirty, then hand off. That exercises `playbooks/resume.md`'s three
worktree states,
which nothing else here covers.

### 5f. Cover one hard path

Steps 3-5e exercise the paths a healthy run takes. The paths below are where an
unattended run does damage, and covering all of them every run would double the
self-test — so run exactly **one** per self-test: read the rotation record in
`<harness>/docs/coverage.md`, take the oldest-untested, run its recipe, and append
the result there.

Manufactured state is legitimate here, and it is what makes these cheap: the ledger
is the loop's only memory, so a ledger written to encode "two attempts already
failed" enters the third-attempt path as surely as failing twice for real — and
deterministically.

- **park-and-hard-stop** — build a fixture whose suite fails on a pure contradiction,
  e.g. `const x = f(1); if (!(x === 1 && x === 2)) { throw new Error("impossible") }`
  — no change to `f` can go green, and verify.md forbids touching the test. Seed it,
  then run improve. Assert: the red baseline became finding #1; after 3 attempts the
  entry reads `parked(<gap>)` with a ruling naming gap, evidence, and unpark
  condition; the last attempt is committed with a first line beginning
  `parked(red-baseline): ` and the ruling records that commit's SHA; the worktree is
  left in place; the run stopped at the hard stop rather than moving on; the ledger
  is committed. Then run improve **again** and assert it stops immediately, reporting
  the existing ruling — no second baseline entry, no fresh 0/3 budget.
- **testless-verify** — seed a fixture with no test suite (the record reads `none
  verified`), make one small scripted change, and run verify.md on it. Assert the
  verdict is exactly `PASS (unverified-by-tests)`; the evidence block quotes the
  record's `none` plus the check that the diff adds no test files; and no invented
  smoke run appears as evidence.
- **authority-envelope** — seed a fixture, then append one manufactured `open` ledger
  entry whose smallest fix is a dependency change (e.g. a pinned dependency the
  finding says to upgrade). Run improve with the envelope at 1 finding. Assert the
  entry ends `parked(authority)` at `attempts: 0/3` with a ruling naming the grant
  that would unpark it, no dependency file was touched, and the parked ruling was
  committed on the base branch.
- **mid-pass-resume** — step 5e's harder variant, as written there: kill a pass with
  a dirty worktree, hand off with the fixed line, and assert the fresh context takes
  `playbooks/resume.md`'s first triage state (non-empty worktree status → continue
  from fix or verify), does not re-cut the worktree, and lands the finding exactly
  once.

A failed assertion here is a defect in a harness file, exactly as in step 7 — fix the
smallest thing that explains it and re-run the path. Delete these fixtures with the
rest (step 6).

### 6. Delete the fixture

Remove every temp dir this run created — `<fixture>`, `<fixture2>`, and `<fixture3>`.
Leaving one behind means the next self-test silently runs against a pre-seeded repo and
stops testing the seed path at all. `<fixture3>` also carries git worktrees and
`harness/*` branches from step 5b; deleting its directory takes those with it.

### 7. Fix what the run broke

Every failed assertion above is a defect in a harness file — the playbook, the
template, or the script — never in the fixture and never in your reading. Fix the
smallest thing that explains the observed failure, then re-run this playbook from the
step that failed. A fix must be traceable to something you watched happen; if you
cannot name the observation, you are editing on taste and the edit does not go in.

Docs travel with the fix: if the behavior you changed is described in `README.md`,
`AGENTS.md`, or another playbook, update those in the same change.

Assertions travel with the fix too, and they go **first**. If the fix touches
`scripts/audit-checks.sh`, add the `assert_grep` — and any fixture file it needs — to
`scripts/test.sh` before the fix, and re-run step 1 to watch it fail. An assertion
written afterwards was never tested; it was checked against code that already
satisfied it. Same order for a check you add unprompted: red in `test.sh`, then green
in `audit-checks.sh`.

## Not covered

This playbook exercises `seed.md` and `audit.md` end to end, **one** pass of
`improve.md`/`verify.md` (step 5b), and the clean handoff (step 5e), against real
fixtures. The hard paths — park and the parked-baseline hard stop, the testless
verify route, the authority envelope, the mid-pass resume — are covered one per run
by step 5f's rotation: `<harness>/docs/coverage.md` is the record of which have
actually run and when, and a path with no row there is unproven, whatever this
section says.

Still uncovered by anything: runs longer than two passes. A green self-test says a
single pass works end to end; it says nothing about the loop across passes.

Step 5c tests exactly **one** remaining anti-rationalization row per run, and only
when a fresh context is available. Every untested row is an unfalsified claim.

## Stop conditions

- **`scripts/test.sh` fails**: stop at step 1. A red script harness makes every fact
  downstream untrustworthy — there is nothing to learn from continuing.
- **The same assertion fails 3 times**: stop fixing. Report the assertion, the three
  attempted fixes, and the output each time. A fourth attempt on the same theory is
  how sessions burn hours.
- **A playbook cannot be run as written** (it asks for something impossible in this
  environment): stop and report it as a finding against that playbook. Do not
  improvise a substitute step and count the run as passing.
- **The fixture cannot be created** (no temp dir, no git): stop at step 2. Never fall
  back to seeding a real repo to keep the self-test moving. The same holds for
  `<fixture2>` at step 5a.
- **On any stop above** — record what stopped the self-test and what would unblock
  it in the ledger's `Run stop` format (see `<harness>/templates/agents-dir/ledger.md`): in
  `<fixture>/.agents/ledger.md` if the fixture got far enough to have one, otherwise
  in the report to the user. Delete the fixture either way (step 6).

## Anti-rationalization table

Every row this playbook carried restated a numbered step, and the restatement class
was removed 2026-07-26 on ablation evidence — see `<harness>/docs/ablations.md`. A
row goes in only when a real run makes an excuse no numbered step already forbids.
