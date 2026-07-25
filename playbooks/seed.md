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
   `AGENTS.md`, `conventions.md`, `principles.md`, `ledger.md`, `learnings.md`, and a
   `lenses/` subdirectory holding one condensed lens per full-form lens in
   `<harness>/lenses/`. A lens present in one directory and missing from the other is
   a harness defect — stop and report it.
6. `.agents/` is not already ignored by the target: run
   `git -C <target> check-ignore -v .agents/AGENTS.md`. If it reports a matching
   rule, stop and tell the user — an ignored `.agents/` means step 7's `git add`
   silently skips everything this playbook writes and the seed is never committed.
   The user must remove or narrow that rule first. Checking here, before anything is
   written, is the point: stopping later would leave the target dirty with
   uncommittable harness files.

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

Running these commands can leave build artifacts behind — `__pycache__/`, `target/`,
`dist/`, coverage output — dirtying a tree that probe item 4 certified clean minutes
earlier, with files this playbook did not write. After verifying, re-run
`git -C <target> status --porcelain`. Anything new is either already covered by the
target's ignore rules, or it is a gap in them. Delete the artifacts; do not stage them
in step 7, and do not add ignore rules on the target's behalf — a missing rule the
target clearly should have is worth naming in your report to the user, not a file to
edit here — step 6's `.agents/worktrees/` line is the one ignore rule this playbook
owns.

### 3. Observe conventions

Observe the target's own code only. Per the footprint rule in `<harness>/AGENTS.md`,
exclude the harness footprint from both the conventions and `{{REPO_SUMMARY}}`:
counting it makes every re-seed rewrite the summary with numbers that grew only
because you seeded.

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
files, so it now also counts the seeded footprint — the five `.agents/` files, any
lens files copied in step 4a, both adapter files, and `.gitignore` if seeding created
it (up to 8 added files where no gate fired, on a repo that had no `.gitignore` and
neither adapter file; fewer where any of them already existed, one more per fired
lens). Do not "correct" the printed number; facts stay the script's. Keep the
size already recorded in `.agents/AGENTS.md` — it was measured pre-seed — and revise
it only when the target's own code has changed.

### 4. Instantiate `.agents/`

Copy the five top-level files from `<harness>/templates/agents-dir/` into
`<target>/.agents/`, replacing every `{{...}}` placeholder:

- `AGENTS.md`: fill `{{REPO_SUMMARY}}`, `{{BUILD_CMD}}`, `{{TEST_CMD}}`,
  `{{TYPECHECK_CMD}}` with the values from steps 2-3.
- `conventions.md`: replace each `{{OBSERVED}}` with that section's observed,
  cited content from step 3.
- `{{RECORDED_AT}}`, in both files: the target's current commit, from
  `git -C <target> rev-parse --short HEAD`, read **before** you write anything. It
  stamps the revision these observations and command runs were made against. What you
  record is true of that commit and promises nothing about later ones — the stamp is
  what lets a future session tell the difference cheaply, instead of trusting prose of
  unknown age.
- `principles.md`, `ledger.md`, `learnings.md`: copy verbatim (no placeholders).

After writing, search `<target>/.agents/` for the string `{{` — it must not appear.
Run this check after step 4a, not before: `AGENTS.md`'s `{{LENSES}}` placeholder is
resolved there (filled if a gate fired, deleted with its section if none did).

**Idempotency — if `<target>/.agents/` already exists:**

- Do not blindly re-copy. For each file, compare its current content against
  observed reality and update **only lines that are stale** (e.g. a test command
  that no longer verifies, a convention contradicted by current code).
- **Let the stamp scope that comparison.** Read `recorded-at` from
  `conventions.md` and `Verified at` from `AGENTS.md`, then run
  `git -C <target> diff <stamp>..HEAD --stat -- <the files those claims cite>`. Paths
  with no changes since the stamp carry claims as good as when they were written —
  leave them, and say in the report that they were skipped and why. Re-examine the
  claims whose cited paths moved, and re-run the commands. Then write today's commit
  as the new stamp on every file you touched, and only those. A stamp advanced without
  re-checking is worse than no stamp: it launders old prose as freshly verified.
  If a stamp is missing (seeded before this existed) or does not resolve —
  `git -C <target> cat-file -e <stamp>^{commit}` fails, as it will after a history
  rewrite — treat the whole file as unscoped and re-examine every claim, then stamp it.
- Never touch user-added content: extra sections, ledger entries, learnings, and
  hand-written notes stay exactly as they are. `ledger.md` and `learnings.md` are
  append-only history — never rewrite or prune their entries here. The ledger's
  `Run state` block is live state owned by `playbooks/improve.md`, not template
  content: leave its recorded values alone even though they differ from the
  template's placeholder. Resetting a recorded base branch would send a resumed run
  merging into the wrong branch.
- A whole section the template has and the target's copy lacks is **missing, not
  deleted** — add it. "Update only stale lines" governs lines the target already has;
  it would otherwise freeze every repo seeded before a template grew a section, which
  is exactly the repo that needs the new content. Harness-owned sections are the ones
  the template defines; anything else in the file is the user's and stays untouched.
  Insert it where the template puts it, relative to the sections either side — never
  appended blindly to the end, which would land `## Guard precedence — governs every
  rubric and lens` beneath the rubrics it claims to govern, and would put a template
  heading after `ledger.md`'s append-only entries. Instantiate any `{{...}}`
  placeholders from steps 2-3 exactly as on a first seed, so step 4's `{{` assertion
  still holds. Name the sections you added in the report.
  - **Except a section the template marks deletable**, which is absent by design, not
    missing. `AGENTS.md`'s `## Lenses` section is the case today: step 4a deletes it
    outright on a target where no lens gate fired, so a repo with no lenses carries no
    lens prose. Re-adding it here would put those lines back on every re-seed and undo
    the one guarantee gating exists to provide. Read the template's own comment on a
    section before calling it missing — a section that says it may be deleted has said
    so on purpose.
- If a file is missing, create it from the template as above.

### 4a. Evaluate the lens gates

The four rubrics in `principles.md` are universal. Lenses are not: each one applies
only to repos that have the thing it judges, and each states its own **Gate** — an
observable, greppable condition. Read every file in `<harness>/lenses/` and run that
file's gate commands against `<target>`, from the target's root, exactly as written.

A gate fires only on its stated result *and* your confirmation from reading one hit —
a word matched in prose, a changelog, or a lockfile is not evidence. Record, for each
lens, the command output you based the decision on; a gate decided from memory of the
repo is not a gate.

Gates judge the target's own code, so the footprint rule in `<harness>/AGENTS.md`
applies here too: each gate command already carries the exclusion, and a hit inside
the footprint is not evidence. This matters most on a re-seed — the seeded files
contain words like "retry" in their own prose, and a gate that counted them would fire
on every previously-seeded repo and stop discriminating.

For each lens whose gate **fires**: copy its condensed counterpart from
`<harness>/templates/agents-dir/lenses/<name>.md` into `<target>/.agents/lenses/`
verbatim (no placeholders in these files). Then fill the `{{LENSES}}` placeholder in
`<target>/.agents/AGENTS.md` with one line per fired lens naming the lens and the
evidence that fired it.

For each lens whose gate does **not** fire: copy nothing. Say which lens did not fire
and why in your report to the user — not in the target. A repo where no gate fires
gets no `.agents/lenses/` directory, and the `## Lenses` section is deleted from
`<target>/.agents/AGENTS.md` entirely (the template says so in a comment). That repo
carries zero added lines from this step, which is the point of gating.

**Idempotency — on a re-seed:**

- Re-evaluate every gate against the target as it is now. A repo that has since gained
  a job queue gains the idempotency lens on this run.
- A lens already present whose gate no longer fires is **left in place, not deleted**.
  Note it in the report as a candidate for removal; whether a lens stops applying is
  the user's call, not yours. Leave its `{{LENSES}}`-derived line in `AGENTS.md` too,
  and say in the report that the line now records a gate that no longer fires.
- A lens file the user has edited is never overwritten — refresh only lines that are
  stale against the current harness template, exactly as for the five top-level files.

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

Read `<target>/.gitignore`. If it does not already cover `.agents/worktrees/`,
append a line `.agents/worktrees/` (create `.gitignore` if absent). If it already
covers it, change nothing.

### 7. Commit

On the branch the target has checked out at run start (do not create branches or
switch), stage exactly what this playbook wrote — `.agents/`, the adapter files,
`.gitignore` — and commit with the message `Seed .agents/ harness`. Do not add a
Co-Authored-By line. Then run `git -C <target> status --porcelain` and confirm none
of the seeded files remain unstaged. Also confirm the seeded files are tracked:
`git -C <target> ls-files .agents/` must list all five top-level files, plus one entry
under `lenses/` for each lens whose gate fired in step 4a — and nothing under
`lenses/` if none fired.

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
  `.agents/` layout from memory. A full-form lens with no condensed counterpart (or
  the reverse) is this same stop — report the mismatch rather than authoring the
  missing half here.
- **A lens gate cannot be decided**: if the gate command runs but you cannot confirm a
  hit is a real construct rather than prose, the gate has not fired. Copy nothing,
  and say in the report which hit you could not confirm. An undecidable gate is a
  no-fire, never a fire "to be safe" — a lens that ships on ambiguity is not gated.
- **`.agents/` is gitignored in the target** (probe item 6): stop and report the
  matching rule; a seed that cannot be committed is not a seed. Nothing has been
  written at that point — leave it that way.
- **On any stop above** — if `<target>/.agents/ledger.md` already exists, append one
  record in the ledger's `Run stop` format (see `<harness>/templates/agents-dir/ledger.md`),
  then report the same to the user.

## Anti-rationalization table

| Excuse | Rebuttal |
| --- | --- |
| "I can skip running the test command — the README says what it is" | READMEs go stale. Only commands you ran in this session go into `AGENTS.md`; everything else is `none verified`. |
| "I'll write this convention from the one example I saw" | One example is an anecdote. Two-plus corroborating examples, each with a cited file, or write `nothing observed yet`. |
| "The existing AGENTS.md is bad — I'll just rewrite it" | Not yours to rewrite. Existing files get the delimited `<!-- harness:begin -->` block appended (or replaced in place); every other line stays untouched. |
| "`.agents/` already exists, so re-seeding means re-copying the templates over it" | Re-seeding refreshes only stale lines. User-added content, ledger entries, and learnings are never touched. |
| "audit-checks.sh already told me the commands, no need to run them" | Its own output says `discovered, NOT run`. Discovery finds candidates; only execution verifies. |
| "This repo will probably grow a queue eventually — I'll copy the idempotency lens now" | Gates read the repo as it is. A lens copied on speculation taxes the target forever for a thing it does not have; the re-seed adds it the day the queue lands. |
| "It's a UI repo, obviously the atomic lens applies — no need to run the greps" | Run the gate and record its output. A gate decided by impression is not observable evidence, and the next session cannot check your reasoning. |
| "The gate no longer fires, so I'll delete the lens it put there last time" | Removal is the user's call. Leave it in place and note it in the report — an agent silently dropping a rubric the user has been auditing against is a surprise, not an update. |
