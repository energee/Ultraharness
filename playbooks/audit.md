# audit.md — rank a target repo's findings against the rubrics

Assess a target repo's health: collect facts with the script, judge them against the
principles rubrics, and produce ALL findings ranked plus a top-actions queue, written
to the target's `.agents/ledger.md`. Facts come from the script; judgment comes from
you; the two never blur.

Audits judge repo outcomes only — tests, duplication, dead code, teachability. The
presence or absence of Ultraharness-owned files (`.agents/`, this repo's playbooks) is
never a finding.

Three finding slots come from this playbook itself rather than a rubric file:
`teachability` (step 3), `staleness` (step 2b), and `testing` (step 4's
missing-evidence rule). These are the audit's **dimensions** — always-on judgment
categories that need no gate and no rubric file, judged by the numbered step that
owns each, graded by the same severity anchors, and ranked in the one list with
everything else. Every finding's principle slot therefore traces to a principle, a
lens, or a dimension; nothing else may occupy it.

## Readiness probe

Confirm all of these before proceeding; if any fails, stop and fix it first.

1. You have a target repo path. If none was given, ask for one — never audit the
   Ultraharness repo itself unless explicitly told to.
2. The target is seeded: `<target>/.agents/` exists and contains `principles.md` and
   `ledger.md`. If not, run `playbooks/seed.md` first, then return here.
   **Read-only exception**: if the user explicitly declined seeding, or said the
   target must not be written to, run in read-only mode — announce it up front, read
   the rubric from `<ultraharness>/templates/agents-dir/principles.md`
   instead of the target's copy, and write findings to a scratch file the user names
   instead of a ledger (step 6). That scratch file lives outside the target; if the
   user declined seeding without naming a path, ask for one before proceeding — a
   read-only audit writes nothing into the target, including its own output.
   Everything else in this playbook is unchanged. Never
   choose this mode yourself to avoid seeding; it is the user's call.
3. The fact collector runs clean: from the Ultraharness repo root, run
   `bash scripts/audit-checks.sh <target-path>` and confirm it exits 0 and prints a
   report whose first line starts `audit-checks v` and names the target path. Do not
   pin the version or date — the script owns those. Exit 2 means the target path is
   invalid — fix the path, not the script.

## Workflow

### 1. Collect facts

Run `bash scripts/audit-checks.sh <target-path>` from the Ultraharness repo root and quote
its full report verbatim into your audit output. The facts are the script's, not
yours:
never re-derive, round, "correct", or summarize-away a number it printed. If a fact
looks wrong, say so as a finding — but still quote the script's output unchanged.

### 2. Judgment pass

Read the target's condensed rubric at `<target>/.agents/principles.md` — or the
the Ultraharness copy at `<ultraharness>/templates/agents-dir/principles.md` in read-only mode (it is
self-contained; the Ultraharness repo's `principles/` directory holds the full versions if
you need the reasoning behind a rule). Then:

- Read each of the top-10 largest files from the script's `largest files` section.
- Read each pair listed under `duplication candidates` — they are candidates, not
  verdicts; verify before flagging.
- The script already drops `.agents/` from both lists, so nothing there needs skipping
  by hand. What it cannot drop is the root pair: a bare `AGENTS.md` / `CLAUDE.md`
  holding only the pointer block is ~100% identical by construction and will surface as
  a duplication candidate. That is Ultraharness output — quote it in the script's report,
  never make it a finding. Skip such a file whole only when the pointer block is all it
  contains; anything the target already had is the repo's own, and is evidence like any
  other file. The footprint rule also governs reference counts: a symbol named only from
  `.agents/` has zero real callers, because the mention is your own note about the repo,
  not the repo.
- Apply all five rubrics (DRY, KISS, SOLID, YAGNI, fail-fast), including each rubric's
  "do NOT apply when" exclusions, and the `## Guard precedence` section that governs
  them all: never emit a removal finding against a guard on a zero-reference argument.
  That section is upstream of this step — a finding you do not raise here cannot be
  acted on later. It has no long-form counterpart in Ultraharness's `principles/`
  directory: unlike the five rubrics it has nothing to detect, so the condensed
  statement is the whole rule.
  - Fail-fast is the one rubric with no signal in the script's report — a swallowed
    error is not a metric. It is found only by reading code, so an audit that emits
    findings under the other four and none under fail-fast should say whether it
    looked, rather than leave the absence to be read as a clean result.
- Read `<target>/.agents/lenses/*.md` if that directory exists, and apply each lens
  alongside the five — same severity anchors, same ranking rules, same "do NOT apply
  when" discipline, and the same guard precedence, which binds a lens finding exactly
  as it binds a rubric one. A lens is in that directory because its gate fired at seed
  time: **a lens that is present applies.** There is no second judgment call here — do
  not re-run its gate, and do not decide a present lens is a poor fit. If you believe a
  lens no longer belongs, say so in the report; removal happens through a re-seed and
  the user's decision, never mid-audit. In read-only mode there is no seeded
  `.agents/`, so there are no lenses: audit against the five rubrics only, and say in
  the report that no lens was evaluated.

Emit every finding in exactly this format:

`[<principle>/<severity high|med|low>] <file:line> — <what> — <smallest fix>`

A lens finding uses the lens name in the principle slot, exactly like a rubric —
`[idempotency/high]`, `[atomic/med]`. Lens findings are ranked in the same list as the
rest; they are not a separate section and never a separate report.

### 2b. Staleness of the record

The footprint rule keeps `.agents/` out of your quality findings — it is your output,
not the repo's work. That is about the *repo's* grade, and it leaves one thing
unchecked: whether what the record claims is still true. A seeded file nobody
re-examines becomes a confident lie that every later session trusts, so this step is
the one narrow exception, and it judges only the record's accuracy.

Read `<target>/.agents/conventions.md` and `<target>/.agents/AGENTS.md` — the latter's
commands block *and* its repo summary, which carries citable claims of its own (file
names, counts, what each module is for) under the same stamp, and rots the same way. A
summary naming a file that has since been renamed is as void as a dead line citation;
scoping this step to the commands block is exactly how such a claim survives a re-seed
that stamped the file as freshly verified. Both files carry a stamp — `recorded-at`,
`Verified at` — of the commit they were written against. Then:

- Run `git -C <target> diff <stamp>..HEAD --stat -- <the paths those claims cite>`.
  Nothing moved under a claim's citations → the claim stands; say so and move on.
- For each claim whose cited paths did move, open the citation. Does the cited code
  still support the claim? A claim whose citation no longer resolves — file renamed,
  deleted, line gone — is **void**, not "probably still true".
- A recorded command that no longer runs is the same defect in the same file.

Emit these with `staleness` in the principle slot, the way step 3 uses `teachability`.
Grade by the same anchors: a wrong test command is high — it blocks a contributor and
misleads every later verify; a convention contradicted by current code is med; a
citation pointing at a moved file whose claim still holds is low. The fix is always
"re-seed, or correct that line" — never "delete the claim so it stops being wrong".

A missing stamp is itself a `staleness` finding, low: without one nothing here can be
checked cheaply, and the file's age is unknowable.

In read-only mode there is no seeded `.agents/` to judge — skip this step and say so.

### 3. Teachability judgment

Attempt to state the target's build, test, and typecheck commands using only files in
the repo (README, manifests, Makefile, CI config — anything committed). Cross-check
against the script's `commands:` and `teachability:` lines. Every gap — a command you
could not determine, a README that lies, a setup step that exists only in someone's
head — is a finding. Use `teachability` as the principle slot in the finding format.

### 4. Rank everything

Grade severity by the anchors in the rubric you read in step 2 ("Severity anchors",
just under the finding format) — `<target>/.agents/principles.md`, or Ultraharness
copy in read-only mode — not by feel. Then rank ALL findings by, in order: severity
(high > med > low), then blast radius (how much of the repo the problem touches or
infects), then effort (cheaper fixes rank higher at equal severity and radius).
Report every finding in ranked order. Never suppress, threshold, or "top N" the list
— a minor finding is ranked low, not omitted.

Conditional applicability: categories with no evidence base are skipped, not reported —
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
bottom, in exactly the ledger's entry format, with `<date>` as ISO `YYYY-MM-DD`:

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
  explicitly declined seeding or said the target must not be written to; do not audit
  an unseeded repo from memory of the rubrics.
- **On any stop** — append one record in the ledger's `Run stop` format (see
  `<ultraharness>/templates/agents-dir/ledger.md`) wherever step 6 would have written: the
  target's ledger normally, the scratch file in read-only mode. In read-only mode the
  target's ledger may well exist — writing the stop record into it would put output in
  a repo probe item 2 promised would receive none. Then report the same to the user.

## Anti-rationalization table

Rows whose action a numbered step already mandated were removed 2026-07-26 on
ablation evidence — see `<ultraharness>/docs/ablations.md`. What remains is the only
enforcement its excuse has; new rows enter only from an excuse a real run made.

| Excuse | Rebuttal |
| --- | --- |
| "No `lenses/` directory, but this is clearly a UI repo — I'll apply the atomic lens anyway." | Lenses are chosen by seeding, from gates, and copied into the target. An uncopied lens is not in scope for the audit; re-seed if the repo changed. |
