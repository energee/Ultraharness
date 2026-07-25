# Playbook: improve

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
   fresh work while an `in-progress` entry sits unexamined.
4. **Clean-baseline gate.** Run the target's test suite (the test command from
   `<target>/.agents/AGENTS.md`; if none is recorded, discovering it is part of
   seeding — go back). A red baseline does not block the run; it becomes finding #1,
   ranked above everything else, and is fixed first so every later failure is
   attributable to a change, not to the starting state. Record the baseline result
   (pass/fail, quoted summary line) before touching anything.

## Workflow

Loop the following. One pass = one finding.

### 1. Get the queue

- If the ledger has `open` or `in-progress` entries, that is your queue — do not
  re-audit first. An `in-progress` entry is resumed at whatever step its worktree
  and attempts count indicate: if its worktree `.agents/worktrees/<finding-slug>/`
  exists, inspect the diff there and continue from fix or verify; if no worktree
  exists, treat it as `open` and restart the pass (increment nothing — attempts
  count only completed fix attempts).
- If the ledger has no open entries (first run, or queue drained), run
  `playbooks/audit.md` on the target. It writes ranked `open` entries and a top-3
  queue into the ledger.

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

Create a worktree for this one finding at `.agents/worktrees/<finding-slug>/` on a
new branch `harness/<finding-slug>`, branched from the target's current default
branch. One finding, one worktree, one branch. All fix work happens inside it.

### 4. Fix

Make the minimal change that resolves the finding, following the target's recorded
conventions (`<target>/.agents/conventions.md`). Do not refactor surrounding code,
fix unrelated findings you notice (add them to the ledger as `open` instead), or
change approach without recording the pivot in the ledger entry.

### 5. Verify

Run `playbooks/verify.md` inside the worktree. It yields a PASS or FAIL verdict
backed by quoted command output — no completion claim without it. On FAIL, iterate
on the fix (never on the test), increment `attempts: <n>/3` in the ledger, and
return to step 4. After 3 failed attempts, take the failure path below.

### 6. De-sloppify

With fresh eyes, simplify the diff itself — the change, not the surrounding code.
If your environment can spawn a fresh subagent, hand it only the diff and the
finding and ask it to remove slop: leftover debug output, dead branches, needless
abstraction, comments narrating the obvious. Otherwise, do an unrelated
palate-cleanser step first (e.g. write the ledger delta text), then re-read the full
diff line by line and simplify. If de-sloppifying changed anything, run verify again.

### 7. Merge back

Merge the branch into the target's default branch, then delete the worktree and the
branch. If the merge conflicts with work from an earlier pass, resolve it now,
re-verify, then merge — never leave a finding stranded on its branch.

### 8. Checkpoint

- Update the ledger entry: `status: done`, final `attempts`, and `delta` with
  before/after evidence (e.g. `dup blocks 14 → 9; tests green` — quote real output,
  not recollection).
- Make a checkpoint commit in the target (the merged fix plus the ledger update).
  No Co-Authored-By lines.
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
the next finding. Never silently drop a finding, and never conclude "worker
limitation" from a single failed run — retry before concluding anything about
capability.

### Hard stops

- Baseline test command cannot be determined or run at all → stop; that is a seeding
  gap, report it.
- Verify itself is broken (the harness's gate, not the target's tests) → stop and
  report; do not self-certify fixes.
- The target's default branch moved underneath you in ways you cannot cleanly merge
  → stop, write the ledger, report the conflict.

## Anti-rationalization

| Excuse | Rebuttal |
| --- | --- |
| "The baseline is only a little red." | The gate holds. Red baseline = finding #1, fixed first. Nothing else starts before it. |
| "I'll batch five findings in one worktree." | One finding, one worktree, one verify. Batching makes failures unattributable and reverts impossible. |
| "De-sloppify is overhead on a small diff." | It runs. On a small diff it's cheap; on any diff it's where the slop hides. |
| "I'm close — one more attempt past 3 will crack it." | Park it with a gap ruling. The 4th attempt is what the next run, with fresh context, is for. |
| "The envelope tripped but the queue is almost empty." | Stop cleanly, report scope remaining. "Almost empty" is exactly what the next run's ledger is for. |
| "This in-progress entry is stale, I'll just start fresh." | Resume it. The ledger surviving session death is the point — inspect its worktree before deciding anything. |
