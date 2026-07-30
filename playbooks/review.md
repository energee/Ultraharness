# review.md — judge a proposed change before it lands

Judge one change — a working-tree diff, a branch, or a commit range — against the
same rubrics, lenses, and guard precedence the audit uses, and emit ALL findings the
change introduces, ranked, in the standard format. This is the audit's discipline
pointed at a diff: pre-existing problems in touched files belong to
`playbooks/audit.md`, not here, unless the change makes one worse.

Review is judgment only. It runs no commands and issues no verdict — proving a change
*done* is `playbooks/verify.md`'s job, with fresh command output behind it. The two
gates answer different questions: verify asks "does it work as claimed", review asks
"should it land as written". A change can pass one and fail the other.

## Readiness probe

1. You have a target repo path. If none was given, ask for one — never review changes
   to the harness repo itself unless explicitly told to.
2. You can name the change under review in one sentence, and it has a diff: either
   the working tree (`git -C <target> status --porcelain` plus `git -C <target> diff
   HEAD`), or a range the user names (`<base>..<tip>`). If `status` lists untracked
   files (`??`), mark them intent-to-add (`git -C <target> add -AN`) and re-run the
   diff — a new file that carries the whole change must not escape the read. An
   empty diff means nothing to review: stop and report that.
3. Rubrics: if the target is seeded, read `<target>/.agents/principles.md` and every
   lens in `<target>/.agents/lenses/` — a lens that is present applies, exactly as in
   the audit. If not seeded, read the harness copy at
   `<harness>/templates/agents-dir/principles.md`, apply the five rubrics only, and
   say in the report that no lens was evaluated. Review never seeds: it must be
   runnable on a repo you would not write to.

## Workflow

### 1. Pin the diff

Record in the report exactly what is under review: the base and tip SHAs for a range,
or `working tree at <HEAD SHA>` — so a reader can reproduce the same diff. Everything
below judges this diff and nothing else.

### 2. Read every hunk

End to end, never a summary — the same rule as `playbooks/verify.md` step 3, for the
same reason: summaries are claims, and a review of a summary is a review of nothing.
While reading, note changes outside the change's named scope, leftover debug output,
commented-out code, and any edit that weakens a test or assertion — each is a finding
under step 3.

### 3. Judge the change against the rubrics

Apply the five rubrics, every present lens, and the `## Guard precedence` section to
what the diff introduces or worsens. Scope discipline: a finding must cite a line the
diff added or removed. A defect that was already in the file and the diff merely sits
near is out of scope — list it at the end of the report as an observation for the
next audit, never as a finding, and never silently.

Emit every finding in exactly the audit's format:

`[<principle>/<severity high|med|low>] <file:line> — <what> — <smallest fix>`

`file:line` cites the post-change file for additions and the pre-change file for
deletions; say which when it is not obvious.

### 4. Read the deletions against guard precedence

The same check `playbooks/verify.md` step 4 runs: does the diff remove or weaken
validation, an authorization check, an error branch that handles (not hides) a
failure, a timeout, a bound, a cleanup path, a transaction wrapper, a version pin?
Unless the diff also shows the boundary gone, or the same check moved intact to a
home every affected boundary still calls, that is a finding graded **high**, with the
deleted hunk quoted as its evidence. "It had no callers" is not the showing —
framework-dispatched guards never do.

### 5. Rank and report

Rank ALL findings by severity, then blast radius, then effort — the audit's step 4
rules, unchanged, including "never suppress, threshold, or top-N". End the report
with one line: `review: <n> findings (<x> high / <y> med / <z> low)` — or
`review: no findings`, stated exactly, because an absent list and an empty list must
not look alike.

Nothing is written into the target. Findings live in this report; if the change
lands anyway, the next audit owns whatever is still true. If the user asks for the
findings as ledger entries, that is the audit's job — run it after the change lands.

## Stop conditions

- **No diff, or no nameable change** — stop at the probe; report that there is
  nothing to review.
- **Diff too large to read fully in this session** — read whole files, not first
  screens, and state the reviewed set explicitly ("read 9 of 14 changed files:
  <list>") in the report. An unread hunk is an unreviewed change; the report must
  say the review is partial, and a partial review ranks what it saw. No silent caps.
- **On any stop above** — if `<target>/.agents/ledger.md` exists, append one record
  in the ledger's `Run stop` format (see `<harness>/templates/agents-dir/ledger.md`);
  then report the same to the user. Review findings themselves never enter the
  ledger; only the stop record does.

## Anti-rationalization table

This playbook starts with no rows. Rows enter only from an excuse a real run makes
that no numbered step already forbids — never speculatively (`<harness>/docs/ablations.md`
records the rule and the evidence class removals rest on).
