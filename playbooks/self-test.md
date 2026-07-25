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
   `<harness>` except a fix you deliberately make in step 7.

## Workflow

### 1. Run the script tests

Run `bash scripts/test.sh` from `<harness>`. Every assertion must print `PASS` and
the run must exit 0. A single `FAIL` stops the self-test here: fix the script or the
test, then start over from this step.

### 2. Build the fixture repo

Create a fresh directory in a temp dir and `git init` it. It must have, at minimum:

- A `README` naming a **real** test command that actually runs — e.g. a `test.sh`
  that prints `ok` — plus a manifest (`package.json` or the ecosystem equivalent)
  wiring that command up, so there is something for seeding to discover *and*
  verify.
- **A planted duplication**: the same 10-line block copied into two source files,
  so the audit has one real finding to catch. If the fixture is clean, step 5 proves
  nothing.
- At least one file large enough to appear in the script's `largest files` list.
- **No lens gate may fire on it.** This fixture is the no-fire case: keep it free of
  retry/queue/webhook/cron/migration/deploy constructs and of component-UI files
  (`.jsx`, `.tsx`, `.vue`, `.svelte`, a `components/` directory with a framework
  import). Run both lenses' gate commands against it before seeding and confirm each
  comes back empty — if one fires, adjust the fixture, because step 3 asserts a
  no-lens footprint and a fixture that quietly fires a gate would mask a real defect.

Commit everything on the fixture's current branch, so seeding starts from a clean
tree. Record the fixture path; every command below runs against it.

### 3. Seed the fixture

Read `playbooks/seed.md` and run it against `<fixture>`, as written — including
verifying the test command by running it. Then assert the exact footprint:

- `<fixture>/.agents/` contains exactly the five files `AGENTS.md`,
  `conventions.md`, `principles.md`, `ledger.md`, `learnings.md` — and, because this
  fixture fires no lens gate (step 2 built it that way), **no `lenses/` directory**.
- The no-fire fixture pays nothing for the lens machinery:
  `grep -ril lens <fixture>/.agents/` returns nothing, and `<fixture>/.agents/AGENTS.md`
  has no `## Lenses` section. Zero added lines in the common case is this design's own
  claim; this is where it is checked.
- No placeholders survive: searching `<fixture>/.agents/` for `{{` returns nothing.
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
- Every finding uses the exact format
  `[<principle>/<severity>] <file:line> — <what> — <smallest fix>`, and the list is
  ranked with nothing suppressed.
- `<fixture>/.agents/ledger.md` gained one `open` entry per finding, in the ledger's
  entry format, plus the top-3 slugs.
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
verdict to PASS (unverified-by-tests) and prove nothing about the gate), plus one
planted finding a minimal fix can close — the duplicated block from step 2 is enough.
Commit it, seed it, and audit it, so the ledger carries a real queue.

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

### 6. Delete the fixture

Remove both temp dirs — `<fixture>` and `<fixture2>`. Leaving one behind means the
next self-test silently runs against a pre-seeded repo and stops testing the seed path
at all.

### 7. Fix what the run broke

Every failed assertion above is a defect in a harness file — the playbook, the
template, or the script — never in the fixture and never in your reading. Fix the
smallest thing that explains the observed failure, then re-run this playbook from the
step that failed. A fix must be traceable to something you watched happen; if you
cannot name the observation, you are editing on taste and the edit does not go in.

Docs travel with the fix: if the behavior you changed is described in `README.md`,
`AGENTS.md`, or another playbook, update those in the same change.

## Not covered

This playbook exercises `seed.md` and `audit.md` end to end, and **one** pass of
`improve.md`/`verify.md` (step 5b), against real fixtures.

Still uncovered, and so not evidence about anything: the **resume** path (step 1's
three worktree states after a session dies mid-pass), the **park** path (3 failed
attempts, gap ruling, parked-baseline hard stop), the **testless** route through
PASS (unverified-by-tests), and any run longer than one pass. A green self-test says a
single pass works end to end; it says nothing about the loop across passes.

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

| Excuse | Rebuttal |
| --- | --- |
| "I read seed.md carefully and it clearly works." | Reading is not running. The assertions are about files that exist after a run; no run, no result. |
| "I'll simulate the seed instead of really creating a fixture." | A simulated run tests your imagination, not the harness. Real dir, real git, real commands. |
| "The fixture is trivial, the audit finding it nothing is fine." | You planted the duplication precisely so there is a known answer. Missing it is a failed self-test. |
| "I'll fix the fixture so the assertion passes." | The fixture is the ruler. Bending the ruler to fit the harness is falsifying the test — fix the harness. |
| "This playbook edit reads better, I'll keep it even though nothing failed." | Every fix traces to an observation from this run. No observation, no edit. |
| "I'll leave the temp dir; deleting it is cleanup nobody sees." | The next self-test would start pre-seeded and quietly skip the seed path. Delete both of them. |
| "Step 5a's second fixture is a lot of setup — the first one proves gating well enough." | The first proves nothing was copied. Only a fixture where one lens fires and another does not proves the gate discriminates rather than always declining. |
