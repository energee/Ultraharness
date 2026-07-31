# harness

Point any coding agent at this repo to make **another** repo simpler, DRY-er, KISS,
SOLID, and YAGNI — plus conditional lenses (idempotency, atomic design) that apply
only if the repo has the thing they judge. There is no install and no runtime —
everything here is markdown
plus three thin bash scripts (one opt-in). The agent reads a front door, routes to a
playbook, and does the rest.

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
| Review | `Read ~/harness/AGENTS.md, then run the review playbook on <the change> in <target-path>.` |
| Verify | `Read ~/harness/AGENTS.md, then run the verify playbook on the change I just made in <target-path>.` |
| Unseed | `Read ~/harness/AGENTS.md, then run the unseed playbook against my repo at <target-path>.` |
| Self-test | `Read ~/harness/AGENTS.md, then run the self-test playbook.` |

If you cloned somewhere else, use that path instead — nothing depends on the location.
Pulling the latest is the whole update procedure: the next run picks it up, and
re-running seed refreshes an already-seeded repo.

Start with seed. Audit and improve both expect a seeded repo — or tell the audit your
repo must not be written to, and it runs read-only.

Claude Code users get the same prompts as slash commands when the session is started
from this repo — `/seed`, `/audit`, `/improve`, `/review`, `/verify`, `/unseed` (each
taking `<target-path>`), and `/self-test` — thin launchers in `.claude/commands/`
that route through `AGENTS.md` exactly like the prompts above; copy them into
`~/.claude/commands/` to use them from any directory. CI
(`.github/workflows/test.yml`) runs `scripts/test.sh` on every push and PR, on Linux
and macOS.

## The seven playbooks

Each opens with a readiness probe (what must be true before starting), then a
workflow and explicit stop conditions. Anti-rationalization rows exist only where the
workflow body does not already mandate the action — ablation testing showed rows that
restate a numbered step are decoration, and they were removed (`docs/ablations.md`
holds the evidence).

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
The script also prints one `gauges:` line — files, lines, largest file, TODOs,
duplication candidates, test files — which improve runs record start → end in
`docs/runs.md`, so a repo's trend across runs is a diff of two lines, not a memory.

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
quietly removed from the queue. The triage for a run another session left mid-finding
lives in `playbooks/resume.md`, read only when the ledger shows one — the common path
never loads it. Every real run appends one line to `docs/runs.md` on exit — the
harness's durable record of what it has actually done in the wild.

**`review.md` — judge a change before it lands.** The audit's discipline pointed at
one diff — working tree, branch, or commit range. Same rubrics, lenses, and guard
precedence; every finding must cite a line the diff added or removed, ranked in the
one list, nothing suppressed. Judgment only: it runs no commands and writes nothing
into the repo — proving a change *done* stays verify's job, and the two answer
different questions ("should it land as written" vs "does it work as claimed").
Deletions are read against guard precedence, so a guard removal wearing a refactor's
clothes is a high finding with the hunk quoted.

**`verify.md` — the evidence gate.** Nothing passes on memory, summaries, or a
subagent's report. Run the commands fresh, read every hunk of the diff, then write one
of three verdicts backed by quoted output: **PASS**, **PASS (unverified-by-tests)** —
an honest verdict for a repo with no suite, never a softened PASS — or **FAIL**. On
FAIL the fix iterates, never the test. Where a fresh context is available the diff goes
to it, because whoever wrote a change is its worst reader. For a web-facing change an
optional browser smoke check can add live-page facts — see "Optional browser evidence"
below.

**`unseed.md` — seeding's inverse.** Removes the footprint — `.agents/`, the pointer
blocks, the one ignore rule — and nothing else, in one commit whose revert is a
re-seed with the old record intact. It stops for a live run (a worktree or an
`in-progress` ledger entry) and reports whatever the ledger still held open or parked
before the tree's copy goes. A repo that was never seeded gets "not seeded, nothing
to do" — success, not an error.

**`self-test.md` — prove the harness still works.** Builds throwaway fixtures in a
temp dir, runs the real playbooks against them, and asserts on what actually landed.
Reading a playbook and judging it sound is explicitly not a result.

## Optional browser evidence

Everything above runs on git, bash, and coreutils. This one feature is different, and
is opt-in: `scripts/smoke-check.sh` needs a browser binary you supply. If you never
supply one, nothing changes — no playbook requires it, its absence is never a finding,
and no verdict blocks on it.

What it adds: live-page facts for web targets. Verify's honest verdict for a repo
with no suite, `PASS (unverified-by-tests)`, leaves the page itself as evidence going
unused. The script fetches one URL with
[Lightpanda](https://github.com/lightpanda-io/browser) — a single static-binary
headless browser — and prints facts in the `audit-checks.sh` mold:

```
smoke-check v1 — url: http://127.0.0.1:3000
browser: lightpanda 1.0.0-nightly.8450
fetched: 272494 bytes in 2s
title: My App
expect 'Sign out': found
```

Supply the browser in two lines (macOS arm64 shown; Linux: `lightpanda-x86_64-linux`):

```
curl -L -o lightpanda https://github.com/lightpanda-io/browser/releases/download/nightly/lightpanda-aarch64-macos
chmod +x lightpanda && export LIGHTPANDA_BIN="$PWD/lightpanda"
```

The harness never bundles or downloads it — that is what keeps "no install, no
runtime" true for everyone who doesn't opt in. Two honest limits: Lightpanda is beta
with partial Web API coverage, and it renders no pixels — this proves a page stands up
and its DOM says what it should, never how it looks. And a smoke fact is not a test
suite: the verdict for a testless repo stays `PASS (unverified-by-tests)`; only a
*failed* smoke check changes anything, and what it changes it to is FAIL.

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

Leaving is as clean as arriving: `unseed.md` removes the footprint — `.agents/`, the
pointer blocks, the ignore rule — and nothing else. History keeps the record, and the
unseed commit's revert is a re-seed with the old ledger intact.

**The record is checked, not trusted.** `conventions.md`, and both the commands block and
the repo summary of `AGENTS.md`, carry a `recorded-at` stamp — the commit they were
observed at. Every claim cites a file, and nothing derivable from the code is recorded at
all: a doc that restates the code is duplicated knowledge, and duplicated knowledge
diverges. The audit re-checks each claim against the code it cites and reports drift as a
`staleness` finding, so a seeded file that has quietly started lying gets ranked
alongside everything else instead of being believed. Citations are also opened as they are
written, because the stamp catches only what *moved*: a claim that was false the day it
was recorded would otherwise survive every drift check, forever.

## Rubrics, lenses, and dimensions

Five rubrics apply to every repo: **DRY**, **KISS**, **SOLID**, **YAGNI**, and
**fail-fast**. Each states how to spot it, how to fix it (smallest intervention first),
and — just as important — when **not** to apply it, so deliberate choices don't get
flagged as defects.

Fail-fast is the odd one out: swallowed errors, silent defaults on required config, and
errors flattened into `null` are invisible to `audit-checks.sh` — no metric reports
them — so it is the rubric that proves an audit read code rather than quoted facts.

Between the rubrics and the lenses sit the audit's **dimensions** — `teachability`,
`staleness`, and `testing`: always-on judgment categories owned by numbered steps of
`playbooks/audit.md` rather than by rubric files, with no gate to pass. Same severity
anchors, same single ranked list. Every finding's principle slot traces to a rubric,
a lens, or a dimension — nothing else may occupy it.

**Lenses** are conditional rubrics for things not every repo has. Each adds one
section the five rubrics don't have: a **gate**, a condition evaluated against your repo
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
| `security` | route registrations, HTTP handlers, controller/middleware paths | a mutating route with no auth check, request data concatenated into SQL or a shell command, an unverified webhook, a credential in source |
| `a11y` | authored UI markup — `.html`, component files, server templates | an image with no text alternative, a click handler on a `<div>`, a form control with no name |

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
playbooks/                # seed, audit, improve (+ resume), review, verify, unseed, self-test
principles/               # DRY, KISS, SOLID, YAGNI, fail-fast — full-form rubrics
lenses/                   # conditional rubrics, each with a Gate section
templates/agents-dir/     # the .agents/ skeleton seed.md instantiates
scripts/audit-checks.sh   # deterministic fact collector (git + grep + awk only)
scripts/test.sh           # bash tests for the fact collectors + rubric sync tripwire
scripts/smoke-check.sh    # optional browser evidence — needs a user-supplied Lightpanda
docs/ablations.md         # which instruction rules have been tested, and how
docs/coverage.md          # hard-path rotation record + playbook prose budget
docs/runs.md              # one line per real improve run — the field record
```

## Testing the harness itself

Run `bash scripts/test.sh` from this repo's root — the bash tests for
`scripts/audit-checks.sh` and `scripts/smoke-check.sh` (the browser-present
assertions run only when a binary is supplied, and print `SKIP` otherwise), plus a
sync tripwire that pins each full-form rubric to
its condensed twin by hash: editing either fails the suite until the pair is
deliberately re-synced, so the designed-in duplication cannot drift silently. Every
assertion prints `PASS` and the run exits 0.

For the end-to-end check, point an agent at `playbooks/self-test.md`. It seeds,
re-seeds, audits, proves the lens gates both fire *and* withhold, runs a full
improve/verify pass, breaks the seeded record on purpose to confirm the staleness check
catches it, and hands a live run to a fresh context to prove the ledger really is
enough to resume from — all against throwaway fixtures. Then it unseeds a fixture to
prove leaving is as clean as arriving, and deletes them all.

It also ablates one anti-rationalization row per run: remove the row, hand the modified
playbook to a fresh context, and see whether the excuse shows up. A rule no agent ever
needed is decoration. `docs/ablations.md` records each test and its verdict, and a row
— or a whole class of rows sharing the property that failed — comes out only after two
runs decline its excuse. The first class removal (rows restating a numbered step)
happened on exactly that evidence.

The dangerous paths — park and the parked-baseline hard stop, the testless verify
route, the authority envelope, the mid-pass resume — run one per self-test on a
rotation, against manufactured ledger state, with `docs/coverage.md` as the record of
which have actually run. The same file tracks a per-run prose budget of the
playbooks' line counts, so growth has to be justified rather than discovered. A green
self-test is evidence about what it ran, and nothing else — including about who ran
it: instructions cannot force compliance, so a self-test is evidence about the agent
and model tier that executed it as much as about the harness. Run it with the same
agent you intend to point at your repos before trusting that agent with an
unattended improve run.

## License

MIT — see [LICENSE](LICENSE).
