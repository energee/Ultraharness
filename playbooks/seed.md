# seed.md — bootstrap a tailored `.agents/` into a target repo

You are seeding a *target* repo with the harness's `.agents/` working-memory
directory, tailored to that repo's observed reality. All paths below: `<harness>` is
this repo's root; `<target>` is the target repo's root. Seeding is idempotent —
re-running this playbook on an already-seeded repo is the update path, and must
refresh stale content without duplicating anything or clobbering user edits.

## Readiness probe

Check all of these before doing anything else. If one fails, stop and report exactly
what is missing.

1. A target path was given. If not, ask for one — never operate on the harness repo
   itself unless explicitly told to.
2. `<target>` exists and is a directory.
3. `<target>` is a git repo: run `git -C <target> rev-parse --is-inside-work-tree`
   and require success.
4. The working tree is clean: run `git -C <target> status --porcelain` and require
   empty output. If dirty, show the user the output and ask whether to proceed
   anyway; proceed only on explicit acknowledgment.
5. The harness templates are readable: `<harness>/templates/agents-dir/` must contain
   `AGENTS.md`, `conventions.md`, `principles.md`, `ledger.md`, `learnings.md`.

## Workflow

### 1. Gather facts

Run `bash scripts/audit-checks.sh <target>` from the harness repo root. Keep the full
output — you will use its `detected:`, `commands:`, `git:`, and `teachability:` lines
below. Note: its `commands:` line is *discovered, not run* — treat those as
candidates, not verified answers.

### 2. Discover and verify build/test/typecheck commands

Read the target's own documentation of how it is built and tested: `README` (any
extension), `CONTRIBUTING.md`, CI configs (`.github/workflows/*`, `.gitlab-ci.yml`,
`Makefile`, `package.json` scripts, or the ecosystem equivalent). Combine what you
read with the candidates from step 1 into your best candidate for each of build,
test, and typecheck.

Then verify each candidate **by running it** in `<target>`. A command is verified
only if you ran it and it behaved as a working command (it may legitimately fail on
pre-existing test failures — that still verifies the command exists and runs; a
"command not found" or missing-script error does not). Record the verified command
strings; they become `{{BUILD_CMD}}`, `{{TEST_CMD}}`, `{{TYPECHECK_CMD}}`.

If a category genuinely has no such command (e.g. no typechecker in this ecosystem),
record `none` for it — that is an honest answer, not a failure.

### 3. Observe conventions

Observe the target's own code only. Exclude the harness's own footprint — everything
under `<target>/.agents/` and the `<!-- harness:begin -->` blocks in the target's root
`AGENTS.md` / `CLAUDE.md` — from both the conventions and `{{REPO_SUMMARY}}`. That
footprint is yours, not the repo's; counting it makes every re-seed rewrite the
summary with numbers that grew only because you seeded. In those two root files the
exclusion is the delimited block, not the file: content the target already had is the
repo's own, and is evidence like any other file.

Read enough of the target's source to fill each section of `conventions.md`
(Layout, Naming, Testing patterns, Error handling, Commit style — for commit style,
read recent `git -C <target> log` output). Rules of evidence:

- Every claim needs **at least 2 corroborating examples** from the repo. One example
  is an anecdote, not a convention.
- Cite a concrete file (or commit) for each claim, as the template's own comment
  demands.
- If a section has nothing observable, write `nothing observed yet` rather than
  inventing content.

Also draft a 2-4 sentence `{{REPO_SUMMARY}}`: what the repo is, its ecosystem
(from the `detected:` line), and rough size (from the `size:` line).

On a first seed the `size:` line is the target's own size — nothing has been seeded
yet, so use it as printed. On a re-seed it is not: the script inventories tracked
files, so it now also counts the seeded footprint — the five `.agents/` files, both
adapter files, and `.gitignore` if seeding created it (up to 8 added files, on a repo
that had no `.gitignore` and neither adapter file; fewer where any of them already
existed). Do not "correct" the printed number; facts stay the script's. Keep the
size already recorded in `.agents/AGENTS.md` — it was measured pre-seed — and revise
it only when the target's own code has changed.

### 4. Instantiate `.agents/`

Copy the five files from `<harness>/templates/agents-dir/` into `<target>/.agents/`,
replacing every `{{...}}` placeholder:

- `AGENTS.md`: fill `{{REPO_SUMMARY}}`, `{{BUILD_CMD}}`, `{{TEST_CMD}}`,
  `{{TYPECHECK_CMD}}` with the values from steps 2-3.
- `conventions.md`: replace each `{{OBSERVED}}` with that section's observed,
  cited content from step 3.
- `principles.md`, `ledger.md`, `learnings.md`: copy verbatim (no placeholders).

After writing, search `<target>/.agents/` for the string `{{` — it must not appear.

**Idempotency — if `<target>/.agents/` already exists:**

- Do not blindly re-copy. For each file, compare its current content against
  observed reality and update **only lines that are stale** (e.g. a test command
  that no longer verifies, a convention contradicted by current code).
- Never touch user-added content: extra sections, ledger entries, learnings, and
  hand-written notes stay exactly as they are. `ledger.md` and `learnings.md` are
  append-only history — never rewrite or prune their entries here.
- If a file is missing, create it from the template as above.

### 5. Adapter files at the target root

For each of `<target>/AGENTS.md` and `<target>/CLAUDE.md`:

- **If absent**: create it containing exactly this pointer block, delimiters included:

  ```
  <!-- harness:begin -->
  Canonical agent instructions live in `.agents/AGENTS.md`.
  Read that file before doing anything else in this repo.
  <!-- harness:end -->
  ```

- **If present**: never overwrite or rewrite any existing content. If the file
  already contains a `<!-- harness:begin -->`…`<!-- harness:end -->` block, replace
  only the lines between (and including) those delimiters with the block above —
  never add a second block. If no block exists, append the block at the end of the
  file, after a blank line.

### 6. Gitignore the worktrees dir

First check that the target does not already ignore the whole `.agents/` directory:
run `git -C <target> check-ignore -v .agents/AGENTS.md`. If it reports a matching
rule, stop and tell the user — an ignored `.agents/` means step 7's `git add` will
silently skip everything this playbook wrote and the seed will never be committed.
The user must remove or narrow that rule before seeding can complete.

Then read `<target>/.gitignore`. If it does not already cover `.agents/worktrees/`,
append a line `.agents/worktrees/` (create `.gitignore` if absent). If it already
covers it, change nothing.

### 7. Commit

On the branch the target has checked out at run start (do not create branches or
switch), stage exactly what this playbook wrote — `.agents/`, the adapter files,
`.gitignore` — and commit with the message `Seed .agents/ harness`. Do not add a
Co-Authored-By line. Then run `git -C <target> status --porcelain` and confirm none
of the seeded files remain unstaged. Also confirm the seeded files are tracked:
`git -C <target> ls-files .agents/` must list all five.

Caveat on the acknowledged-dirty-tree path (probe item 4): if the user already had
uncommitted edits to a root `AGENTS.md` or `CLAUDE.md`, staging that file stages
their edits too. Say so before committing and let the user decide — stage the file,
or leave the pointer block uncommitted and report it.

On a re-seed that found nothing stale there is nothing to stage, and `git commit`
will exit nonzero saying so. That is the idempotent success case, not a failure:
report "already current, no commit" and stop. Never force an empty commit, and never
touch a file just to have something to commit.

## Stop conditions

- **A command won't verify after 3 attempts**: if you cannot get a candidate
  build/test/typecheck command to run after 3 distinct attempts (different
  candidates count as attempts), stop trying and record `none verified` for that
  entry in `.agents/AGENTS.md` — an honest gap beats a guessed command that sends
  every future session down a dead end.
- **Dirty tree the user won't resolve**: if the probe found a dirty working tree and
  the user does not acknowledge proceeding, stop. Report what is dirty and do
  nothing else.
- **Templates missing or unreadable**: stop and report; do not improvise a
  `.agents/` layout from memory.
- **`.agents/` is gitignored in the target** (step 6): stop and report the matching
  rule; a seed that cannot be committed is not a seed.
- **On any stop above** — if `<target>/.agents/ledger.md` already exists, append one
  entry recording what stopped the seed and what would unblock it, then report the
  same to the user.

## Anti-rationalization table

| Excuse | Rebuttal |
| --- | --- |
| "I can skip running the test command — the README says what it is" | READMEs go stale. Only commands you ran in this session go into `AGENTS.md`; everything else is `none verified`. |
| "I'll write this convention from the one example I saw" | One example is an anecdote. Two-plus corroborating examples, each with a cited file, or write `nothing observed yet`. |
| "The existing AGENTS.md is bad — I'll just rewrite it" | Not yours to rewrite. Existing files get the delimited `<!-- harness:begin -->` block appended (or replaced in place); every other line stays untouched. |
| "`.agents/` already exists, so re-seeding means re-copying the templates over it" | Re-seeding refreshes only stale lines. User-added content, ledger entries, and learnings are never touched. |
| "audit-checks.sh already told me the commands, no need to run them" | Its own output says `discovered, NOT run`. Discovery finds candidates; only execution verifies. |
