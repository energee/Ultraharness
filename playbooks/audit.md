# Playbook: audit

Assess a target repo's health: collect facts with the script, judge them against the
principles rubrics, and produce ALL findings ranked plus a top-actions queue, written
to the target's `.agents/ledger.md`. Facts come from the script; judgment comes from
you; the two never blur.

Audits score repo outcomes only — tests, duplication, dead code, teachability. The
presence or absence of harness-owned files (`.agents/`, this repo's playbooks) is
never a scored category.

## Readiness probe

Confirm all of these before proceeding; if any fails, stop and fix it first.

1. You have a target repo path. If none was given, ask for one — never audit the
   harness repo itself unless explicitly told to.
2. The target is seeded: `<target>/.agents/` exists and contains `principles.md` and
   `ledger.md`. If not, run `playbooks/seed.md` first, then return here.
   **Read-only exception**: if the user asked for an audit without seeding, or the
   user said the target must not be written to, run in read-only mode — announce it
   up front, read the rubric from `<harness>/templates/agents-dir/principles.md`
   instead of the target's copy, and write findings to a scratch file the user names
   instead of a ledger (step 6). Everything else in this playbook is unchanged. Never
   choose this mode yourself to avoid seeding; it is the user's call.
3. The fact collector runs clean: from the harness repo root, run
   `scripts/audit-checks.sh <target-path>` and confirm it exits 0 and prints a report
   headed `audit-checks v1 (2026-07-24) — target: <path>`. Exit 2 means the target
   path is invalid — fix the path, not the script.

## Workflow

### 1. Collect facts

Run `scripts/audit-checks.sh <target-path>` from the harness repo root and quote its
full report verbatim into your audit output. The facts are the script's, not yours:
never re-derive, round, "correct", or summarize-away a number it printed. If a fact
looks wrong, say so as a finding — but still quote the script's output unchanged.

### 2. Judgment pass

Read the target's condensed rubric at `<target>/.agents/principles.md` (it is
self-contained; the harness repo's `principles/` directory holds the full versions if
you need the reasoning behind a rule). Then:

- Read each of the top-10 largest files from the script's `largest files` section.
- Read each pair listed under `duplication candidates` — they are candidates, not
  verdicts; verify before flagging.
- Skip harness-owned entries in both lists — anything under `.agents/` and the
  `<!-- harness:begin -->` pointer blocks in the target's root `AGENTS.md` /
  `CLAUDE.md`. On a seeded repo they dominate both lists (the two pointer files are
  ~100% identical by construction). Still quote them in the script's report; just
  never score them. What is excluded is the block, not the file: a root `AGENTS.md`
  or `CLAUDE.md` that also carries the target's own content is still scored on that
  content — skip only the delimited block. Skip such a file whole only when the block
  is all it contains. The same exclusion applies when you count references to decide
  whether something is unused: a symbol or file named only from `.agents/` has zero
  real callers, because the mention is your own note about the repo, not the repo.
- Apply all four rubrics (DRY, KISS, SOLID, YAGNI), including each rubric's
  "do NOT apply when" exclusions.

Emit every finding in exactly this format:

`[<principle>/<severity high|med|low>] <file:line> — <what> — <smallest fix>`

### 3. Teachability judgment

Attempt to state the target's build, test, and run commands using only files in the
repo (README, manifests, Makefile, CI config — anything committed). Cross-check
against the script's `commands:` and `teachability:` lines. Every gap — a command you
could not determine, a README that lies, a setup step that exists only in someone's
head — is a finding. Use `teachability` as the principle slot in the finding format.

### 4. Rank everything

Rank ALL findings by, in order: severity (high > med > low), then blast radius (how
much of the repo the problem touches or infects), then effort (cheaper fixes rank
higher at equal severity and radius). Report every finding in ranked order. Never
suppress, threshold, or "top N" the list — a minor finding is ranked low, not omitted.

Conditional applicability: categories with no evidence base are skipped, not scored —
no type-check findings in a repo with no type system. But a missing evidence base
that should exist is itself a finding: no tests is a high-severity finding, not an
excuse to skip the testing category quietly. Use `testing` as the principle slot for
those, the way step 3 uses `teachability` — a test suite that exists but asserts
nothing counts as missing.

### 5. Top actions

Emit `top actions`: the first 3 findings by rank, restated with their smallest fix.
This is the queue `playbooks/improve.md` consumes.

### 6. Write the ledger

Append each finding to `<target>/.agents/ledger.md` as an `open` entry, newest at the
bottom, in exactly the ledger's entry format:

```
## <date> <finding-slug>
- finding: [<principle>/<severity>] <file:line> — <what>
- status: open
- attempts: 0/3
- delta: <none yet>
```

Before appending, read the existing ledger: a finding already tracked there (open,
in-progress, or parked) gets its existing entry referenced in your report, not a
duplicate entry. Mark the top-3 queue by listing the three slugs at the end of your
appended block.

In read-only mode (probe item 2) there is no ledger: write the same entries, same
format, same top-3 slugs, to the scratch file instead, and say in the report that
nothing was written to the target.

## Stop conditions

- **Script fails** — fix the invocation (path, permissions, working directory) and
  rerun. Never hand-compute the facts as a fallback; an audit without the script's
  report is not an audit.
- **Repo too large to judge fully** — if you cannot read all top-10 files and all
  duplication candidates in this session, state the sampled scope explicitly ("judged
  7 of 10 largest files: <list>") in the audit output and the ledger. No silent caps.
- **Target not seeded and seeding fails** — stop and report why, unless the user
  asked for read-only mode; do not audit an unseeded repo from memory of the rubrics.

## Anti-rationalization

| Excuse | Rebuttal |
| --- | --- |
| "This finding is too minor to report." | Rank it low, report it anyway. The ranking is the filter; you are not. |
| "I'll estimate the line counts / re-derive the facts myself." | Script only. If the script can't produce a fact, its absence is stated — never your estimate. |
| "The duplication candidate is probably real, no need to read both files." | Candidates are best-effort string matches. Read both files or don't flag it. |
| "No tests, so I'll skip the testing category." | Skipped categories need an absent evidence base that's legitimately absent. Missing tests is a high-severity finding. |
| "The repo has our `.agents/` dir, that's worth points." | Never. Audits score outcomes only — harness-owned files are never a scored category. |
| "Seeding is a hassle, I'll just go read-only." | Read-only is the user's call, not your shortcut. Unasked-for, the answer is seed first. |
