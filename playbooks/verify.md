# verify.md — the evidence-before-claims gate

You are verifying a change that someone (possibly you, possibly a subagent) claims
is complete. This playbook exists because "done" claims without fresh evidence are
the single most common way agent work goes wrong. Nothing passes this gate on
memory, summaries, or prior runs — only on output produced *now*.

`<target>` below is the repo containing the change. The target's test/build/
typecheck commands are the verified ones recorded in `<target>/.agents/AGENTS.md`
(seeded by `playbooks/seed.md`).

## Readiness probe

1. There is a specific claimed-complete change to verify — you can name it in one
   sentence.
2. That change has a diff: run `git -C <target> status --porcelain` and
   `git -C <target> diff HEAD` (or diff against the branch base if the change is
   already committed) and confirm it is non-empty. No diff, nothing to verify —
   stop and report that. If `status` lists untracked files (`??`), they are part of
   the change and `git diff HEAD` omits them entirely: mark them intent-to-add
   (`git -C <target> add -AN`) and re-run the diff, so a new file that carries the
   whole fix cannot pass step 3 unread.
3. `<target>/.agents/AGENTS.md` exists and names the test command. If it records
   `none` or `none verified` for tests — the two mean the same thing here, no suite
   to run — note that up front: the verdict below must be
   **PASS (unverified-by-tests)** or FAIL, never a bare PASS, and never a silent
   skip.
   - **Unless the change under verification is the one that adds the suite.** Read
     the step-2 diff: if it introduces tests, the recorded `none` is stale — it
     describes the repo before this change, and this change is what makes it false.
     Determine the new suite's command from the diff and the target's README, run
     it, and verdict on it normally (PASS or FAIL). Verifying a test-adding change
     against the record instead of against the diff is how a broken new suite passes
     its own gate: the one change whose whole purpose is to create a suite would be
     the one change never actually run.

## Workflow

### 1. Run the test command fresh

Run the target's test command now, in full, and capture the complete output.
No caching, no partial runs scoped to "the files I touched", and no reuse of a run
from earlier in the session — "it passed earlier" is not evidence, because the code
has changed since earlier. If the suite offers a cache-bypass flag, use it. If
`.agents/AGENTS.md` records `none` / `none verified` for tests there is nothing to
run here — say so and carry that into the verdict.

### 2. Run typecheck and build

If `.agents/AGENTS.md` records a typecheck command, run it fresh and capture the
output. Same for the build command. Skip only what is recorded as `none` /
`none verified`, and say so in the verdict.

### 3. Read the actual diff, end to end

Read the full VCS diff of the change — every hunk, not the first screen. Never
trust a summary of the diff, whether written by you earlier or reported by a
subagent; summaries are claims, and this playbook trades only in evidence. While
reading, check for: changes outside the claimed scope, leftover debug output,
commented-out code, and any edit that weakens a test or assertion.

### 4. Check the change against principles

Read `<target>/.agents/principles.md` and hold the diff against it — especially
YAGNI and KISS: did the fix itself introduce speculative structure (an abstraction
with one caller, a config knob nothing sets, a "for future use" seam)? A fix that
adds new findings is not done.

### 5. Verdict

Write one of three verdicts — **PASS**, **PASS (unverified-by-tests)**, or **FAIL**
— followed by the evidence — quote the actual
command outputs (at minimum the final summary lines of each run: counts, exit
status, failure names). A verdict with no quoted output is invalid; redo the runs.

- **PASS** requires: every recorded command ran fresh and succeeded, the full diff
  was read, and step 4 raised nothing.
- **PASS (unverified-by-tests)** requires: `.agents/AGENTS.md` records `none` or
  `none verified` for tests *and* the change under verification does not itself add
  a suite (so there was genuinely no suite to run — see probe item 3), the full diff was read
  end to end, step 4 raised nothing, and every command that *is* recorded — build,
  typecheck — ran fresh and succeeded. Name it exactly this way, with the qualifier;
  it is an honest verdict about a testless repo, not a softened PASS, and callers
  must be able to see the difference at a glance. It is **not** a FAIL: it does not
  count as a failed attempt for the caller's retry budget.
- **FAIL** on anything else, listing exactly what failed and the output proving it.
  A recorded test command that ran and failed is always FAIL — the qualified PASS is
  only for a repo with no test command at all.

**Rule: on FAIL, the fix iterates — never the test.** Weakening, skipping, or
deleting a test to get to PASS is falsifying the evidence this gate exists to
collect. If a test is genuinely wrong, that is a separate finding to raise with
its own evidence — not something to slip into a verification pass.

## Stop conditions

- **3 verify failures on the same fix**: stop iterating. Hand the finding back to
  `playbooks/improve.md`'s "Failure path (per finding)" stop condition with the
  three failure outputs attached — more attempts on the same strategy is how
  sessions burn hours.
- **No diff, or no nameable change**: stop at the probe; report that there is
  nothing to verify.
- **Test command itself is broken** (command not found, harness crash before any
  test runs): stop and report it — that is an environment/seed problem, not a
  verdict on the change.
- **On any stop above** — if `<target>/.agents/ledger.md` exists, append one entry
  recording what stopped the verification and what would unblock it, then report the
  same to the user.

## Anti-rationalization table

| Excuse | Rebuttal |
| --- | --- |
| "The diff is tiny — no need to run the whole suite" | Tiny diffs break distant tests all the time; size of diff is not size of blast radius. Run the full suite. |
| "Tests were green two edits ago" | Two edits ago is a different codebase. Only output from a run after the final edit counts. |
| "The subagent said it passed" | A subagent's report is a claim, not evidence. Re-run the commands and read the diff yourself. |
| "I'll skim the diff summary instead of the hunks" | Summaries hide the one hunk that matters. Read every hunk or the verdict is invalid. |
| "No test suite here, so I'll just write PASS" | Write PASS (unverified-by-tests). A bare PASS claims evidence you do not have. |
| "This test is flaky/wrong, I'll just relax it so we pass" | On FAIL the fix iterates, never the test. A wrong test is its own finding, raised separately with evidence. |
