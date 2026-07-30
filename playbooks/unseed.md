# unseed.md — remove the harness footprint from a target repo

Seeding's inverse: remove `.agents/`, the pointer blocks, and the one ignore rule
seeding added — and nothing else. The footprint rule in `<harness>/AGENTS.md` is what
makes this well-defined: everything the harness owns in a target is enumerable, so
its removal is too. History survives — the seed and every checkpoint were committed,
so unseeding removes the record from the tree, never from `git log`.

## Readiness probe

1. You have a target repo path. If none was given, ask for one — never unseed the
   harness repo itself unless explicitly told to.
2. `<target>/.agents/` exists. If it does not, report "not seeded, nothing to do"
   and stop — that is the idempotent success case, not a failure.
3. The working tree is clean (`git -C <target> status --porcelain` empty). If dirty,
   show the user the output and ask whether to proceed; proceed only on explicit
   acknowledgment — the same rule seeding applies, for the same reason: this playbook
   commits, and a dirty tree entangles the user's edits with the removal.
4. No run is mid-flight: `<target>/.agents/worktrees/` contains no worktree
   (`git -C <target> worktree list` shows only the main checkout), and the ledger has
   no `in-progress` entry. Either one → stop and report it; finish or resume that run
   first (`playbooks/resume.md`). Unseeding under a live run deletes the run's memory
   while its worktree still points into the directory being removed.

## Workflow

### 1. Report what the record still holds

Read the ledger and name, in your report, every entry that is not `done`: open
findings, and parked entries with their rulings. These are true statements about the
repo, and the tree's copy is about to go — the user should see what they are
discarding while the commit that preserves it is still easy to find. Nothing here
blocks the removal; it is a report, not a gate.

### 2. Remove `.agents/`

`git -C <target> rm -r .agents/` for the tracked files, then delete anything left of
the directory — `worktrees/` is gitignored and probe item 4 proved it empty, so what
remains is untracked residue, not work.

### 3. Strip the pointer blocks

For each of `<target>/AGENTS.md` and `<target>/CLAUDE.md` that exists and contains a
`<!-- harness:begin -->`…`<!-- harness:end -->` block:

- If the file consists of exactly that block (surrounding blank lines aside), seeding
  created it — delete the file.
- Otherwise, remove only the delimited lines, the delimiters included, and leave
  every other line exactly as it is. The content around the block is the repo's own;
  this playbook has no opinion about it.

A root file with no block is not an error — seeding may never have touched it, or the
user removed the block themselves. Leave it alone and say so.

### 4. Remove the ignore rule

If `<target>/.gitignore` contains the exact line `.agents/worktrees/`, remove that
line — and only that line. Do not delete `.gitignore` even if the line was all it
held: seeding creates the file only when absent, but proving it did months later
costs more than an empty file does.

### 5. Commit

Stage exactly what this playbook touched and commit with the message
`Unseed .agents/ harness`. No Co-Authored-By line. Then confirm the removal is
complete: `git -C <target> ls-files .agents/` prints nothing, no root file contains
`harness:begin`, and `git -C <target> status --porcelain` is empty. Report the commit
SHA — it is also the recovery pointer: `git revert` of this one commit is a re-seed
with the old record intact.

## Stop conditions

- **A live run** (probe item 4) — stop and report the worktree or `in-progress`
  entry found. Resume or finish it first.
- **Dirty tree the user won't resolve** — stop; report what is dirty and do nothing.
- **On any stop above** — the ledger still exists (removal has not happened at the
  probe), so append one record in the ledger's `Run stop` format (see
  `<harness>/templates/agents-dir/ledger.md`), then report the same to the user.

## Anti-rationalization table

This playbook starts with no rows. Rows enter only from an excuse a real run makes
that no numbered step already forbids — never speculatively (`<harness>/docs/ablations.md`
records the rule and the evidence class removals rest on).
