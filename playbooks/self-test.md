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

Commit everything on the fixture's current branch, so seeding starts from a clean
tree. Record the fixture path; every command below runs against it.

### 3. Seed the fixture

Read `playbooks/seed.md` and run it against `<fixture>`, as written — including
verifying the test command by running it. Then assert the exact footprint:

- `<fixture>/.agents/` contains exactly the five files `AGENTS.md`,
  `conventions.md`, `principles.md`, `ledger.md`, `learnings.md`.
- No placeholders survive: searching `<fixture>/.agents/` for `{{` returns nothing.
- `<fixture>/AGENTS.md` and `<fixture>/CLAUDE.md` exist and each carry one pointer
  block.
- `<fixture>/.gitignore` covers `.agents/worktrees/`.
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
- The tree is clean, or the only diff is a refresh you can name and justify against
  something that actually changed since the first run.

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
- No finding scores the harness's own footprint — `.agents/` and the pointer blocks
  are quoted in the script report but never judged.

### 6. Delete the fixture

Remove the temp dir. Leaving it behind means the next self-test silently runs against
a pre-seeded repo and stops testing the seed path at all.

### 7. Fix what the run broke

Every failed assertion above is a defect in a harness file — the playbook, the
template, or the script — never in the fixture and never in your reading. Fix the
smallest thing that explains the observed failure, then re-run this playbook from the
step that failed. A fix must be traceable to something you watched happen; if you
cannot name the observation, you are editing on taste and the edit does not go in.

Docs travel with the fix: if the behavior you changed is described in `README.md`,
`AGENTS.md`, or another playbook, update those in the same change.

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
  back to seeding a real repo to keep the self-test moving.

## Anti-rationalization table

| Excuse | Rebuttal |
| --- | --- |
| "I read seed.md carefully and it clearly works." | Reading is not running. The assertions are about files that exist after a run; no run, no result. |
| "I'll simulate the seed instead of really creating a fixture." | A simulated run tests your imagination, not the harness. Real dir, real git, real commands. |
| "The fixture is trivial, the audit finding it nothing is fine." | You planted the duplication precisely so there is a known answer. Missing it is a failed self-test. |
| "I'll fix the fixture so the assertion passes." | The fixture is the ruler. Bending the ruler to fit the harness is falsifying the test — fix the harness. |
| "This playbook edit reads better, I'll keep it even though nothing failed." | Every fix traces to an observation from this run. No observation, no edit. |
| "I'll leave the temp dir; deleting it is cleanup nobody sees." | The next self-test would start pre-seeded and quietly skip the seed path. Delete it. |
