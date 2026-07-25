# Harness v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Note (2026-07-25):** `docs/specs/` and `docs/research/` are no longer tracked in
> this repo — they are gitignored and local-only. References to them below are kept as
> the historical record of what this plan was written against.

**Goal:** Build the self-applying instruction repo described in `docs/specs/2026-07-24-harness-design.md`: front doors, principle rubrics, the `.agents/` template, four playbooks, and a thin deterministic audit script — then prove it by seeding a scratch repo and auditing the harness itself.

**Architecture:** Everything is markdown routed from `AGENTS.md`, plus one bash script (`scripts/audit-checks.sh`) for deterministic audit facts and one bash test file. No runtime, no installer. Playbooks follow the spec's conventions: readiness probe first, stop conditions + ledger-on-failure, anti-rationalization table last, idempotent.

**Tech Stack:** Markdown, bash (POSIX-leaning, macOS/Linux), git.

## Global Constraints

- Canonical seeded directory is `.agents/`; worktrees at `.agents/worktrees/` (gitignored in target).
- Adapters never overwrite existing target files — append a clearly-delimited pointer block or create if absent.
- Audit scores outcomes only; never the presence of harness-owned files (teachability is measured as "discoverable from repo alone," not "has our files").
- All findings reported and ranked; no severity-threshold suppression.
- Playbook prose uses action vocabulary ("run", "read", "write"), never agent-specific tool names (no "use the Edit tool", no `claude -p`).
- Every playbook: readiness probe → workflow → stop conditions → anti-rationalization table.
- No `Co-Authored-By` lines in commits.
- Scripts: `#!/usr/bin/env bash`, `set -euo pipefail`, no dependencies beyond git + coreutils; must pass `scripts/test.sh`.

---

### Task 1: Front doors — README.md, AGENTS.md, CLAUDE.md

**Files:**
- Create: `README.md`, `AGENTS.md`, `CLAUDE.md`

**Interfaces:**
- Produces: routing contract used by every later file — playbook paths `playbooks/{seed,audit,improve,verify,self-test}.md`, principles at `principles/{dry,kiss,solid,yagni}.md`, template at `templates/agents-dir/`.

- [ ] **Step 1: Write README.md** — the human front door. Sections:
  - One-paragraph pitch: point any coding agent at this repo to make any repo simpler, DRY-er, KISS, SOLID, YAGNI. No install.
  - **Quick start**: a table of copy-paste prompts, one row per action (Seed / Audit / Improve), each a single prompt string of the form:
    `Read ~/harness/AGENTS.md, then run the <seed|audit|improve> playbook against my repo at <target-path>.`
    with a note that the same prompt works in Claude Code, Codex CLI, Cursor, Gemini CLI, OpenCode, etc.
  - **What gets left behind**: the `.agents/` footprint listing from the spec, verbatim file list with one-line purposes.
  - **How it works**: 5 lines — front door routes to playbooks; audit produces ranked findings + top-actions; improve loop runs audit→fix→verify→de-sloppify→checkpoint in worktrees under `.agents/worktrees/`; ledger survives session death.
  - Link to `docs/specs/` and `docs/research/`.
- [ ] **Step 2: Write AGENTS.md** — the agent front door. Contents:
  - Identity line: "You have been pointed at the harness repo. It operates on a separate *target* repo; if no target path was given, ask for one — never operate on this repo unless explicitly told to."
  - Routing table by *decision*, not topic (harness-engineering pattern), descriptions are triggers only, never workflow summaries (superpowers pattern):
    | If you need to… | Read |
    | set up a repo for agent work / first contact with a target | `playbooks/seed.md` |
    | assess a repo's health / find what to improve | `playbooks/audit.md` |
    | actively improve a repo over a long run | `playbooks/improve.md` |
    | prove a change is done | `playbooks/verify.md` |
    | check this harness still works | `playbooks/self-test.md` |
  - Rule: load one playbook at a time; playbooks reference principles just-in-time.
  - Global rules (copied from spec): action vocabulary; never overwrite target files; all findings ranked; evidence before claims.
- [ ] **Step 3: Write CLAUDE.md** — ≤6 lines: `@AGENTS.md` import plus Claude-specific deltas only (worktree tooling note; skills may be available but AGENTS.md governs).
- [ ] **Step 4: Verify** — `grep -l 'playbooks/seed.md' README.md AGENTS.md` lists both; every path referenced in AGENTS.md matches the layout in this plan exactly.
- [ ] **Step 5: Commit** — `git add README.md AGENTS.md CLAUDE.md && git commit -m "Add front doors: README, AGENTS.md, CLAUDE.md shim"`

### Task 2: Principle rubrics

**Files:**
- Create: `principles/dry.md`, `principles/kiss.md`, `principles/solid.md`, `principles/yagni.md`

**Interfaces:**
- Produces: shared rubric format consumed by `playbooks/audit.md` (finding categories named `dry`, `kiss`, `solid`, `yagni`) and by `templates/agents-dir/principles.md` (condensed copy).

- [ ] **Step 1: Write the four rubrics.** Identical structure per file, each ≤120 lines:
  1. **Definition** (2 lines, no essay).
  2. **How to spot it** — concrete detection heuristics an agent can execute, e.g. for DRY: same 5+ line block in 2+ files (`git grep` candidates), parallel switch/if chains on the same discriminant, copy-pasted test setup, config values repeated as literals. For KISS: functions >50 lines or nesting >3, cleverness markers (bit tricks, metaprogramming) where a plain loop works, indirection layers with one caller. For SOLID: per-letter one-paragraph checks focused on the two that pay rent in practice (SRP: file/class with 2+ change reasons; DIP: business logic importing IO/framework directly) — explicitly note LSP/ISP/OCP findings are rarer, don't force them. For YAGNI: unused exports/params/flags, speculative config, abstractions with a single implementation, "for future use" comments, dead feature flags.
  3. **How to fix it** — smallest-intervention moves, ordered (e.g. DRY: extract function < extract module < introduce abstraction; never abstract on the 2nd occurrence if divergence is plausible).
  4. **When NOT to apply** — the over-application failure mode (DRY: incidental duplication, test readability; KISS: don't strip needed validation/error handling; SOLID: no interfaces with one implementation; YAGNI: never delete input validation at trust boundaries, calibration knobs for hardware, or accessibility).
  5. **Finding format**: `[<principle>/<severity high|med|low>] <file:line> — <what> — <smallest fix>`.
- [ ] **Step 2: Verify** — each file contains all five section headers; `wc -l principles/*.md` shows each ≤120.
- [ ] **Step 3: Commit** — `git commit -m "Add DRY/KISS/SOLID/YAGNI rubrics with detection heuristics"`

### Task 3: Seeded-directory template

**Files:**
- Create: `templates/agents-dir/AGENTS.md`, `templates/agents-dir/conventions.md`, `templates/agents-dir/principles.md`, `templates/agents-dir/ledger.md`, `templates/agents-dir/learnings.md`

**Interfaces:**
- Consumes: rubric content from Task 2 (condensed into `principles.md`).
- Produces: exact template file set copied by `playbooks/seed.md`; placeholder syntax `{{LIKE_THIS}}` that seed.md fills; ledger entry format consumed by `playbooks/improve.md` and `playbooks/audit.md`.

- [ ] **Step 1: Write the templates.**
  - `AGENTS.md`: target-local front door. Sections: "About this repo" (`{{REPO_SUMMARY}}`, `{{BUILD_CMD}}`, `{{TEST_CMD}}`, `{{TYPECHECK_CMD}}`), "Conventions" (points at `conventions.md`), "Principles" (points at `principles.md`), "Ongoing work" (points at `ledger.md`), "Worktrees" ("create improvement worktrees under `.agents/worktrees/<slug>/`; they are gitignored").
  - `conventions.md`: headed skeleton seed fills from observation: Layout, Naming, Testing patterns, Error handling, Commit style — each with `{{OBSERVED}}` placeholder and an instruction comment "record only what you verified in ≥2 places; cite an example file for each claim".
  - `principles.md`: condensed self-contained rubric — the "How to spot it" bullets and "When NOT to apply" lines from all four Task-2 files, ~60 lines total, no dependency on the harness repo.
  - `ledger.md`: header + entry format:
    ```
    ## <date> <finding-slug>
    - finding: [<principle>/<severity>] <file:line> — <what>
    - status: open | in-progress | done | parked(<gap: context|capability|authority|proof|feedback>)
    - attempts: <n>/3
    - delta: <before → after evidence, e.g. "dup blocks 14 → 9; tests green">
    ```
    plus the standing rules: never delete entries; parked requires a written ruling; one failed run never establishes "worker limitation".
  - `learnings.md`: format `- [seen:<n>] <lesson> (evidence: <file/commit>)`; promotion rule: a lesson seen 2+ times gets copied into `conventions.md` or `AGENTS.md`; stale unrepeated lessons may be pruned during audits.
- [ ] **Step 2: Verify** — `ls templates/agents-dir/` shows exactly the 5 files; `grep -c '{{' templates/agents-dir/AGENTS.md` ≥ 4.
- [ ] **Step 3: Commit** — `git commit -m "Add .agents/ seed templates"`

### Task 4: Audit script + tests

**Files:**
- Create: `scripts/audit-checks.sh`, `scripts/test.sh`

**Interfaces:**
- Produces: `scripts/audit-checks.sh <target-path>` prints a plain-text fact report (format below) consumed verbatim by `playbooks/audit.md`; exit 0 unless target path invalid (exit 2). Rubric version string `v1 (2026-07-24)` printed in the header.

- [ ] **Step 1: Write `scripts/test.sh` first (failing).** Bash test harness: creates a temp dir fixture repo (`git init`; a `package.json` with a test script; one 400-line file generated via loop; a file containing `TODO`), runs `audit-checks.sh` on it, and asserts with grep: header contains `audit-checks v1`; `detected: node` present; `largest files` lists the 400-line file; `todo/fixme markers:` count ≥1; exit code 0; and running against a nonexistent path exits 2. Use a `fail()` counter; print `PASS`/`FAIL` per assertion; exit nonzero on any FAIL.
- [ ] **Step 2: Run it to confirm failure** — `bash scripts/test.sh` → fails (script missing).
- [ ] **Step 3: Write `scripts/audit-checks.sh`.** Deterministic facts only, no scoring, no LLM judgment. Sections printed:
  ```
  audit-checks v1 (2026-07-24) — target: <path>
  detected: <node|python|go|rust|mixed|unknown> (evidence: package.json, pyproject.toml, go.mod, Cargo.toml)
  commands: build=<cmd|none found> test=<cmd|none found> typecheck=<cmd|none found>   # discovered, NOT run
  git: <commit count> commits, <n> contributors, last commit <date>
  size: <tracked file count> files, <total loc> lines (excluding lockfiles/vendored dirs)
  largest files: top 10 by line count
  longest functions: skipped in v1 (language-specific)  # honest cap, printed so nothing is silently dropped
  todo/fixme markers: <count> (top 10 locations)
  duplication candidates: top 10 pairs of files sharing a basename or >60% identical lines (via sort|uniq -d on normalized lines, best-effort; labeled "candidates — verify before acting")
  teachability: README <present|missing>; build cmd discoverable <yes|no>; test cmd discoverable <yes|no>; contributing/docs dir <present|missing>
  agents dir: .agents/ <present|missing>; ledger <present|missing>   # facts only — never scored
  ```
  Conditional sections: skip language-specific lines that don't apply. `set -euo pipefail`; guard every pipeline that may legitimately be empty with `|| true`.
- [ ] **Step 4: Run `bash scripts/test.sh`** → all PASS.
- [ ] **Step 5: Commit** — `git commit -m "Add deterministic audit-checks script with bash tests"`

### Task 5: seed.md + verify.md playbooks

**Files:**
- Create: `playbooks/seed.md`, `playbooks/verify.md`

**Interfaces:**
- Consumes: `templates/agents-dir/*` (Task 3), `scripts/audit-checks.sh` (Task 4, for repo detection facts).
- Produces: seeded `.agents/` contract that `playbooks/improve.md` and `self-test.md` rely on; `verify.md` gate invoked by name from improve.md.

- [ ] **Step 1: Write `playbooks/seed.md`.** Structure:
  - **Readiness probe**: target path exists, is a git repo, working tree clean or user acknowledged; harness `templates/agents-dir/` readable.
  - **Workflow**: (1) run `scripts/audit-checks.sh <target>` to gather facts; (2) read target's README/docs/CI configs to fill `{{BUILD_CMD}}`/`{{TEST_CMD}}`/`{{TYPECHECK_CMD}}` — verify each command by running it; (3) observe conventions (≥2 corroborating examples per claim, cite files); (4) copy templates into `.agents/`, filling all `{{...}}` placeholders — **idempotent**: if `.agents/` exists, update only lines that are stale-vs-observed reality and never touch user-added content; (5) adapters: if root `AGENTS.md`/`CLAUDE.md` absent, create 3-line pointer ("Canonical agent instructions live in `.agents/AGENTS.md`"); if present, append a delimited block `<!-- harness:begin -->…<!-- harness:end -->` (replace existing block on re-run, never duplicate); (6) add `.agents/worktrees/` to `.gitignore` if absent; (7) commit the seed on the current branch with message `Seed .agents/ harness`.
  - **Stop conditions**: can't verify a build/test command after 3 tries → record `none verified` honestly in `.agents/AGENTS.md` rather than guessing; dirty tree the user won't resolve → stop.
  - **Anti-rationalization table**: "I can skip running the test command, the README says what it is" → verified commands only; "I'll write conventions from one example" → 2+ corroborations; "existing AGENTS.md is bad, I'll rewrite it" → append the delimited block only.
- [ ] **Step 2: Write `playbooks/verify.md`.** The evidence gate:
  - **Readiness probe**: there is a claimed-complete change with a diff.
  - **Workflow**: (1) run the target's test command *fresh*, full output — no caching, no "it passed earlier"; (2) run typecheck/build if they exist; (3) read the actual VCS diff end-to-end (never trust a summary, own or a subagent's); (4) check the change against `principles.md` — did the fix itself add speculative structure?; (5) verdict PASS/FAIL with the command outputs quoted. Rule: on FAIL, the fix iterates — never weaken the test.
  - **Stop conditions**: 3 verify failures on one fix → back to improve.md's park-or-replan step.
  - **Anti-rationalization**: "the diff is tiny, no need to run the suite" / "tests were green two edits ago" / "the subagent said it passed" → all rejected with one-liners.
- [ ] **Step 3: Verify** — both files contain the four convention sections (probe/workflow/stop/anti-rationalization); every file path referenced exists in the repo.
- [ ] **Step 4: Commit** — `git commit -m "Add seed and verify playbooks"`

### Task 6: audit.md + improve.md playbooks

**Files:**
- Create: `playbooks/audit.md`, `playbooks/improve.md`

**Interfaces:**
- Consumes: `scripts/audit-checks.sh` output format (Task 4), rubric finding format `[<principle>/<severity>] <file:line> — <what> — <smallest fix>` (Task 2), ledger entry format (Task 3), `playbooks/verify.md` (Task 5).
- Produces: ranked findings list + top-actions queue written to `.agents/ledger.md`; the loop contract for long runs.

- [ ] **Step 1: Write `playbooks/audit.md`.**
  - **Readiness probe**: target seeded (`.agents/` exists — if not, run seed.md first); `scripts/audit-checks.sh` runs clean.
  - **Workflow**: (1) run the script, quote its report verbatim into the audit — facts are the script's, not yours (never re-derive or "correct" them); (2) judgment pass: read the top-10 largest files and duplication candidates, apply each of the four rubrics from `principles/` (target's condensed `.agents/principles.md` suffices), emit findings in the standard format; (3) teachability judgment: attempt to state build/test/run commands using only repo files, note every gap; (4) rank ALL findings by (severity, blast radius, effort) — report every finding, never suppress below a threshold; (5) emit `top actions` = first 3 by rank; (6) write findings + top-actions into `.agents/ledger.md` as `open` entries. Conditional applicability: skip categories with no evidence base (no tests → that's a finding, not a scored category).
  - **Stop conditions**: script fails → fix invocation, don't hand-compute facts; repo too large to judge fully → state the sampled scope explicitly (no silent caps).
  - **Anti-rationalization**: "this finding is too minor to report" → rank it low, report it anyway; "I'll estimate the line counts" → script only.
- [ ] **Step 2: Write `playbooks/improve.md`.** The long-runtime loop, exactly the spec's steps 0–8:
  - **Readiness probe**: seeded; clean-baseline gate — run the test suite; red baseline becomes finding #1, fixed first.
  - **Workflow**: audit (or resume open ledger entries) → pick highest-ranked `open` finding, smallest owning intervention → create worktree `.agents/worktrees/<finding-slug>/` on a branch `harness/<finding-slug>` → fix minimally per conventions → run verify.md in the worktree → de-sloppify: with fresh eyes (fresh subagent if the environment has them, otherwise re-read the full diff after an unrelated palate-cleanser step) simplify the diff itself → merge back, delete worktree → update ledger entry (`done`, attempts, delta with before/after evidence) → checkpoint commit → next finding.
  - **Safety envelope**: defaults max 10 findings or 4 hours per run (user can override); stop cleanly when either trips, report scope remaining, pause for user checkpoint between phases on multi-hour runs; completion requires 3 consecutive "queue empty" confirmations (re-audit each time).
  - **Failure path**: 3 attempts per finding → park with gap-taxonomy classification and written ruling in ledger; never silently drop.
  - **Standing rules** (from spec): removal earns equal rank; update stale docs/comments in the same change per finding.
  - **Anti-rationalization**: "baseline is only a little red" → gate holds; "I'll batch five findings in one worktree" → one finding, one worktree, one verify; "de-sloppify is overhead on a small diff" → it runs, it's cheap on a small diff.
- [ ] **Step 3: Verify** — cross-references resolve: audit.md names the exact script path and ledger format fields; improve.md names verify.md and the ledger `parked(gap:…)` statuses; formats match Task 3's templates verbatim.
- [ ] **Step 4: Commit** — `git commit -m "Add audit and improve playbooks"`

### Task 7: self-test.md + dogfood run

**Files:**
- Create: `playbooks/self-test.md`
- Modify: whatever the dogfood run reveals (fix inline, smallest change)

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write `playbooks/self-test.md`.** Checklist the executing agent performs:
  1. `bash scripts/test.sh` → all PASS.
  2. Create a throwaway repo in a temp dir (git init, tiny node or plain-file project with a README naming a real test command that actually runs, e.g. `sh ./test.sh` printing ok).
  3. Run `playbooks/seed.md` against it. Assert exact footprint: 5 files in `.agents/` + `worktrees/` gitignored + root pointer files + no `{{` placeholders remain (`grep -r '{{' .agents/` empty) + seed commit exists.
  4. Re-run seed.md. Assert idempotency: `git status` clean or only meaningful refresh; no duplicated pointer blocks (`grep -c 'harness:begin' AGENTS.md` = 1).
  5. Run `playbooks/audit.md` against it. Assert: script report quoted, ≥1 finding (the fixture plants one: a duplicated 10-line block in two files), findings in standard format, ledger updated.
  6. Delete the temp dir.
- [ ] **Step 2: Execute the self-test now** (this session or a dispatched subagent), fixing any harness file that fails it — smallest fix, re-run until the checklist passes end to end.
- [ ] **Step 3: Commit** — `git commit -m "Add self-test playbook; fixes from first dogfood run"`

### Task 8: Harness audits itself

**Files:**
- Modify: any harness file the audit flags (fix inline)

- [ ] **Step 1:** Run `playbooks/audit.md` with the harness repo itself as target (explicit exception to the "never operate on this repo" rule, noted in the run). No seeding — audit only, findings to a scratch file, not a committed ledger.
- [ ] **Step 2:** Fix every `high` finding; report `med`/`low` findings to the user with the final summary (all findings, ranked — user decides).
- [ ] **Step 3:** `bash scripts/test.sh` still green.
- [ ] **Step 4: Commit** — `git commit -m "Apply self-audit fixes"`

---

## Self-review (done at write time)

- Spec coverage: every spec section maps to a task (front doors→1, rubrics→2, footprint→3, deterministic audit→4, playbook conventions + seed/verify→5, loop + taxonomy + envelope→6, self-test→7, "passes own audit" success criterion→8). README-as-product→Task 1.
- No placeholders: content requirements are concrete (formats, section lists, exact assertions); scripts have executable specs with test-first ordering.
- Consistency: finding format, ledger format, script header string, and playbook section order are each defined once and referenced verbatim across tasks.
