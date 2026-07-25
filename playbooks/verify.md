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
   stop and report that.
3. `<target>/.agents/AGENTS.md` exists and names the test command. If it records
   `none verified` for tests, note that up front — the verdict below must say the
   change is unverifiable by tests, not silently skip them.

## Workflow

### 1. Run the test command fresh

Run the target's test command now, in full, and capture the complete output.
No caching, no partial runs scoped to "the files I touched", and no reuse of a run
from earlier in the session — "it passed earlier" is not evidence, because the code
has changed since earlier. If the suite offers a cache-bypass flag, use it.

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

Write a verdict: **PASS** or **FAIL**, followed by the evidence — quote the actual
command outputs (at minimum the final summary lines of each run: counts, exit
status, failure names). A verdict with no quoted output is invalid; redo the runs.

- **PASS** requires: every recorded command ran fresh and succeeded, the full diff
  was read, and step 4 raised nothing.
- **FAIL** on anything else, listing exactly what failed and the output proving it.

**Rule: on FAIL, the fix iterates — never the test.** Weakening, skipping, or
deleting a test to get to PASS is falsifying the evidence this gate exists to
collect. If a test is genuinely wrong, that is a separate finding to raise with
its own evidence — not something to slip into a verification pass.

## Stop conditions

- **3 verify failures on the same fix**: stop iterating. Hand the finding back to
  `playbooks/improve.md`'s park-or-replan step with the three failure outputs
  attached — more attempts on the same strategy is how sessions burn hours.
- **No diff, or no nameable change**: stop at the probe; report that there is
  nothing to verify.
- **Test command itself is broken** (command not found, harness crash before any
  test runs): stop and report it — that is an environment/seed problem, not a
  verdict on the change.

## Anti-rationalization table

| Excuse | Rebuttal |
| --- | --- |
| "The diff is tiny — no need to run the whole suite" | Tiny diffs break distant tests all the time; size of diff is not size of blast radius. Run the full suite. |
| "Tests were green two edits ago" | Two edits ago is a different codebase. Only output from a run after the final edit counts. |
| "The subagent said it passed" | A subagent's report is a claim, not evidence. Re-run the commands and read the diff yourself. |
| "I'll skim the diff summary instead of the hunks" | Summaries hide the one hunk that matters. Read every hunk or the verdict is invalid. |
| "This test is flaky/wrong, I'll just relax it so we pass" | On FAIL the fix iterates, never the test. A wrong test is its own finding, raised separately with evidence. |
