# harness

Point any coding agent at this repo to make **another** repo simpler, DRY-er, KISS,
SOLID, and YAGNI — plus conditional lenses (idempotency, atomic design) that apply
only if the repo has the thing they judge. There is no install and no runtime —
everything here is markdown
plus two thin bash scripts. The agent reads a front door, routes to a playbook, and
does the rest.

It never operates on itself unless you explicitly say so. `<target>` below is your
repo; `<harness>` is this one.

## Quick start

Clone it anywhere — there is nothing to install and nothing to build:

```
git clone https://github.com/energee/harness.git ~/harness
```

Then copy one of these prompts into your agent CLI, replacing `<target-path>` with the
repo you want worked on. The same prompt works in Claude Code, Codex CLI, Cursor,
Gemini CLI, OpenCode, and any other agent that can read files and run shell commands.

| Action | Prompt |
| --- | --- |
| Seed | `Read ~/harness/AGENTS.md, then run the seed playbook against my repo at <target-path>.` |
| Audit | `Read ~/harness/AGENTS.md, then run the audit playbook against my repo at <target-path>.` |
| Improve | `Read ~/harness/AGENTS.md, then run the improve playbook against my repo at <target-path>.` |
| Verify | `Read ~/harness/AGENTS.md, then run the verify playbook on the change I just made in <target-path>.` |
| Self-test | `Read ~/harness/AGENTS.md, then run the self-test playbook.` |

If you cloned somewhere else, use that path instead — nothing depends on the location.
Pulling the latest is the whole update procedure: the next run picks it up, and
re-running seed refreshes an already-seeded repo.

Start with seed. Audit and improve both expect a seeded repo — or tell the audit your
repo must not be written to, and it runs read-only.

## The five playbooks

Each opens with a readiness probe (what must be true before starting), then a
workflow, explicit stop conditions, and a table of the excuses agents use to skip the
work.

**`seed.md` — teach the repo to teach the agent.** Reads your code, records what it
observes, and writes `.agents/`. Every convention it records needs two corroborating
examples with a cited file; anything unobserved is written as `nothing observed yet`
rather than invented. Build/test/typecheck commands go in only if it *ran* them —
otherwise `none verified`. Re-running seed is the update path: it refreshes stale
lines, never clobbers your edits, and reports "already current, no commit" when there
is nothing to do.

**`audit.md` — ranked findings, no score.** Facts come from `scripts/audit-checks.sh`
and are quoted verbatim; judgment comes from the rubrics. Every finding uses one
format:

```
[<principle>/<severity high|med|low>] <file:line> — <what> — <smallest fix>
```

All findings are reported, ranked by severity → blast radius → effort. Nothing is
thresholded or truncated — a minor finding is ranked low, not omitted. Categories with
no evidence base are skipped, but an evidence base that *should* exist and doesn't is
itself a high-severity finding: no tests is a finding, not an excuse to skip the
category. Output ends with a top-3 queue, which is what the improve loop consumes.

*Read-only mode*: say your repo must not be written to, and the audit seeds nothing
and writes findings to a scratch file you name, outside the target.

**`improve.md` — the long-runtime fix loop.** Audit → pick the top finding → isolate
in a worktree → minimal fix → verify → de-sloppify → merge → checkpoint → repeat. One
finding, one worktree, one branch, so every failure is attributable and every fix is
revertible. Before any of it, a clean-baseline gate: a red suite becomes finding #1
and is fixed first; a repo with no suite at all makes the missing suite finding #1.
After three failed attempts a finding is **parked** with a written ruling naming which
gap blocked it — context, capability, authority, proof, or feedback — and what would
unpark it. Nothing is silently dropped, and no run is reported finished with work
quietly removed from the queue.

**`verify.md` — the evidence gate.** Nothing passes on memory, summaries, or a
subagent's report. Run the commands fresh, read every hunk of the diff, then write one
of three verdicts backed by quoted output: **PASS**, **PASS (unverified-by-tests)** —
an honest verdict for a repo with no suite, never a softened PASS — or **FAIL**. On
FAIL the fix iterates, never the test. Where a fresh context is available the diff goes
to it, because whoever wrote a change is its worst reader.

**`self-test.md` — prove the harness still works.** Builds throwaway fixtures in a
temp dir, runs the real playbooks against them, and asserts on what actually landed.
Reading a playbook and judging it sound is explicitly not a result.

## What gets left behind

Seeding writes one directory, `.agents/`, into the target repo:

```
.agents/
  AGENTS.md               # target-local front door (summary, commands, routing)
  conventions.md          # learned from the target repo during seeding
  principles.md           # condensed rubric (self-contained; no dependency on this repo)
  ledger.md               # progress ledger — survives compaction and session death
  learnings.md            # repeated lessons, promoted after corroboration
  lenses/                 # optional: conditional rubrics whose gate fired on this repo
  worktrees/              # gitignored; created on the first improve run, not by seeding
```

`AGENTS.md` and `CLAUDE.md` at the target root become thin pointers into `.agents/` —
created only if absent; an existing file gets a delimited pointer block appended and
every other line left alone.

The **ledger** is the loop's memory. Each finding is one entry with a status (`open`,
`in-progress`, `done`, `parked(<gap>)`), an attempt count, and a delta quoting real
before/after evidence. A run killed mid-finding can be resumed cold by any agent from
the ledger alone.

That is also the answer to a long run outgrowing its context. State lives in files, not
in the session, so a handoff is one fixed line — `Read <target>/.agents/AGENTS.md and
continue the improve run.` — taken at a pass boundary, never mid-fix. There is
deliberately no handoff summary: a summary is written by the most depleted context in
the run, from memory, while the ledger was written by a fresh one at each step. If that
one line is not enough, the ledger is what gets fixed.

**The record is checked, not trusted.** `conventions.md` and the commands block carry a
`recorded-at` stamp — the commit they were observed at. Every claim cites a file, and
nothing derivable from the code is recorded at all: a doc that restates the code is
duplicated knowledge, and duplicated knowledge diverges. The audit re-checks each claim
against the code it cites and reports drift as a `staleness` finding, so a seeded file
that has quietly started lying gets ranked alongside everything else instead of being
believed.

## Rubrics and lenses

Four rubrics apply to every repo: **DRY**, **KISS**, **SOLID**, **YAGNI**. Each states
how to spot it, how to fix it (smallest intervention first), and — just as important —
when **not** to apply it, so deliberate choices don't get flagged as defects.

**Lenses** are conditional rubrics for things not every repo has. Each adds one
section the four rubrics don't have: a **gate**, a condition evaluated against your repo
at seed time that decides whether the lens applies at all. Gates are decided by
`scripts/audit-checks.sh`, not by the agent — it prints one line per lens, and the same
repo therefore gates the same way on every machine and in every session:

```
gates: atomic not-fired
gates: idempotency FIRED (3 hits; evidence: workers/consumer.js, migrations/003_jobs.sql, deploy/release.sh)
```

The one judgement left to the agent is opening a cited path to confirm it is a real
construct rather than the word "retry" in a comment. If it can't confirm, the gate did
not fire.

| Lens | Gate fires when the repo has | Catches |
| --- | --- | --- |
| `idempotency` | retries, a queue or scheduler, migrations, webhooks, deploy scripts | a retried write with no upsert or dedup, a backfill with no re-run guard, a script that breaks on its second run |
| `atomic` | a component-based UI | design tokens duplicated across components, prop drilling, a component library with no entry point |

A repo where no gate fires gets no `lenses/` directory and **not one added line** —
that is the point of gating, and the self-test asserts it. Re-seeding re-evaluates the
gates: a repo that grows a queue gains the idempotency lens on the next seed; a lens
whose gate stops firing is left in place and reported, never silently deleted. A lens
that is present applies — the audit does not re-litigate the gate.

Lens findings put the lens name in the principle slot: `[idempotency/high]`,
`[atomic/med]`. To add a lens, write it in `lenses/` with the same sections as a rubric
plus a Gate, its condensed twin in `templates/agents-dir/lenses/`, and its gate patterns
in `scripts/audit-checks.sh` — deliberately three files, because a config format for two
entries is the kind of thing this repo exists to flag in other people's code. Write the
self-test's fire/no-fire assertions (step 5a) **before** the lens itself, and watch
them fail: a gate is only proven by a fixture it fires on and a fixture it withholds
from, and neither exists until you build it.

## Rules the agent is held to

- **Never overwrite your files.** Existing files get a pointer block appended, never
  clobbered.
- **Evidence before claims.** No completion claim without fresh output backing it.
- **All findings are ranked.** Never a partial list, never a silent cap.
- **The harness's own footprint is never evidence about your repo.** `.agents/` and
  the pointer blocks are the agent's output — never counted, judged, or allowed to
  fire a lens gate.
- **Two envelopes bound an improve run.** The *safety* envelope bounds how much it
  does (default: 10 findings or 4 hours). The *authority* envelope bounds what it may
  do: source, tests, docs, and its own files without asking — but nothing that leaves
  the machine or changes your repo's contract with the outside world (push, PR,
  remote, published history, CI or deploy config, secrets, dependencies, deleting a
  test) without your say-so.
- **Agent-agnostic prose.** Playbooks name actions — run, read, write — never any
  specific agent's tool names.

## Repo layout

```
AGENTS.md                 # the front door: routes by decision to one playbook
CLAUDE.md                 # thin shim: @AGENTS.md plus Claude-specific deltas
playbooks/                # seed, audit, improve, verify, self-test
principles/               # DRY, KISS, SOLID, YAGNI — full-form rubrics
lenses/                   # conditional rubrics, each with a Gate section
templates/agents-dir/     # the .agents/ skeleton seed.md instantiates
scripts/audit-checks.sh   # deterministic fact collector (git + grep + awk only)
scripts/test.sh           # bash tests for the fact collector
docs/ablations.md         # which instruction rules have been tested, and how
```

## Testing the harness itself

Run `bash scripts/test.sh` from this repo's root — the bash tests for
`scripts/audit-checks.sh`. Every assertion prints `PASS` and the run exits 0.

For the end-to-end check, point an agent at `playbooks/self-test.md`. It seeds,
re-seeds, audits, proves the lens gates both fire *and* withhold, runs a full
improve/verify pass, breaks the seeded record on purpose to confirm the staleness check
catches it, and hands a live run to a fresh context to prove the ledger really is
enough to resume from — all against throwaway fixtures, then deletes them.

It also ablates one anti-rationalization row per run: remove the row, hand the modified
playbook to a fresh context, and see whether the excuse shows up. A rule no agent ever
needed is decoration. `docs/ablations.md` records each test and its verdict, and a row
comes out only after two runs decline its excuse.

`self-test.md`'s "Not covered" section names what has no fixture yet — the resume path,
the park path, the testless verify route, and the authority envelope. A green
self-test is evidence about what it ran, and nothing else.
