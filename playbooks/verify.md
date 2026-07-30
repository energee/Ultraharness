# verify.md — the evidence-before-claims gate

You are verifying a change that someone (possibly you, possibly a subagent) claims
is complete. This playbook exists because "done" claims without fresh evidence are
the single most common way agent work goes wrong. Nothing passes this gate on
memory, summaries, or prior runs — only on output produced *now*.

`<target>` below is the repo containing the change. The target's test/build/
typecheck commands are the verified ones recorded in `<target>/.agents/AGENTS.md`
(seeded by `playbooks/seed.md`).

**Called from a worktree** — `playbooks/improve.md` step 5 runs this gate inside
`<target>/.agents/worktrees/<slug>/` — `<target>` means that worktree everywhere except
the ledger. Commands, diff, and `.agents/AGENTS.md` all come from there, because the
change under test is what is checked out there. A `Run stop` record does not: write it
to the **main checkout's** `.agents/ledger.md`. The worktree's copy sits on the
finding's branch, where step 7 either folds it into the fix commit or deletes it with
the worktree — so the one record written to explain why a run stopped is the one most
likely to vanish.

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
   - **Unless the diff introduces test files.** Read the step-2 diff: if it adds
     tests, the recorded `none` is stale — it describes the repo before this change,
     and this change is what makes it false. The trigger is the diff, not which
     finding is being worked: any pass that adds tests earns a normal verdict.
     Determine the new suite's command from the diff and the target's README, run
     it, and verdict on it normally (PASS or FAIL). If the added suite cannot be run,
     or crashes before any test executes — no runner, no determinable command, a test
     file that does not parse — that is **FAIL**, not stop condition 3: the change
     itself introduced the broken suite, so it is a verdict on the change, not an
     environment problem.
     Verifying a test-adding change against the record instead of against the diff
     is how a broken new suite passes its own gate: the one change whose whole
     purpose is to create a suite would be the one change never actually run.

## Workflow

### 1. Run the test command fresh

Run the target's test command now, in full, and capture the complete output.
No caching, no partial runs scoped to "the files I touched", and no reuse of a run
from earlier in the session — "it passed earlier" is not evidence, because the code
has changed since earlier. If the suite offers a cache-bypass flag, use it. If
`.agents/AGENTS.md` records `none` / `none verified` for tests there is nothing to
run here — say so and carry that into the verdict — **unless probe item 3 found that
the diff introduces test files**, in which case run that new suite here, as probe
item 3 directs. The record describes the repo before this change; the diff is what
this step verifies.

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

**Prefer fresh eyes.** If your environment can start a fresh context — a subagent, a
second session — hand it the diff and the one-sentence claim from probe item 1, and
have it answer those same checks. Hand the diff over as **output, not prose**: write
`git diff` to a file and give the fresh context that path. A diff retyped into a prompt
is a summary wearing a diff's clothes, and one mistyped line spends the whole review on
your typo instead of on the change — the exact substitution this step exists to prevent. Nothing else: not the plan, not your reasoning, not
this conversation. Whoever wrote the change is its worst reader — they know what the
code was *meant* to do and read that intent into hunks that do not contain it, which
is the failure this gate exists to catch. Its answer does not replace your own read; a
finding it raises that you missed is itself evidence about how carefully you read. If
no fresh context is available, say so in the verdict and read it yourself — that is a
weaker verification, and the verdict must not hide it.

### 4. Check the change against principles

Read `<target>/.agents/principles.md` and hold the diff against it — especially
YAGNI and KISS: did the fix itself introduce speculative structure (an abstraction
with one caller, a config knob nothing sets, a "for future use" seam)? A fix that
adds new findings is not done.

Then read the diff's deletions against that file's `## Guard precedence` section: does
this change remove or weaken validation, an authorization check, an error branch, a
timeout, a bound, a cleanup path, a transaction wrapper, or a version pin? If it does,
the verdict is **FAIL** unless the diff also shows the boundary itself is gone, or the
same check moved intact to a shared home that *every* boundary which had it now calls —
consolidating five copies into one deletes four and weakens nothing, but only if all
five sites still run the check. Confirm each one in the diff; four rewired and one left
bare is a removal wearing a refactor's clothes. "It had no callers" is not that
showing; framework-dispatched guards never do. The evidence for this verdict is the
deleted hunk itself, quoted — it is a reading check, so no command output backs it.

### 5. Verdict

Write one of three verdicts — **PASS**, **PASS (unverified-by-tests)**, or **FAIL**
— followed by the evidence — quote the actual
command outputs (at minimum the final summary lines of each run: counts, exit
status, failure names). A verdict with no quoted output is invalid; redo the runs.

On the **PASS (unverified-by-tests)** route there may be no recorded command at all —
no test, no build, no typecheck — and then there is nothing to redo. Quote the evidence
of absence instead: the record's `none`, and the check that it is not stale (the diff
introduces no test files). That is the honest output for that verdict. Do **not** invent
a run to fill the gap — a smoke command you wrote yourself is not the repo's suite, and
a verdict that quotes one reads as coverage that does not exist. If you ran something ad
hoc to satisfy your own curiosity, it does not belong in the evidence block.

- **PASS** requires: every recorded command ran fresh and succeeded, the full diff
  was read, and step 4 raised nothing.
- **PASS (unverified-by-tests)** requires: `.agents/AGENTS.md` records `none` or
  `none verified` for tests *and* the diff introduces no test files (so there was
  genuinely no suite to run — see probe item 3), the full diff was read
  end to end, step 4 raised nothing, and every command that *is* recorded — build,
  typecheck — ran fresh and succeeded. Name it exactly this way, with the qualifier;
  it is an honest verdict about a testless repo, not a softened PASS, and callers
  must be able to see the difference at a glance. It is **not** a FAIL: it does not
  count as a failed attempt for the caller's retry budget.
- **FAIL** on anything else, listing exactly what failed and the output proving it.
  A recorded test command that ran and failed is always FAIL — the qualified PASS is
  only for a repo with no test command at all.

A FAIL raised by that guard check is the one FAIL the caller must not iterate on: the
fix *is* the deletion, so three attempts produce the same verdict three times. It is a
policy park under `playbooks/improve.md` step 2's irreversible-fixes rule — hand it
back as `parked(authority)` at `attempts: 0/3`, not as a spent budget.

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
  verdict on the change. **Unless the diff introduces the test files**: then the
  change is what broke it, so the verdict is FAIL, per probe item 3.
- **On any stop above** — if `<target>/.agents/ledger.md` exists, append one record
  in the ledger's `Run stop` format (see `<harness>/templates/agents-dir/ledger.md`), then
  report the same to the user.

## Anti-rationalization table

Every row this playbook carried restated a numbered step, and the restatement class
was removed 2026-07-26 on ablation evidence — see `<harness>/docs/ablations.md`. A
row goes in only when a real run makes an excuse no numbered step already forbids.
