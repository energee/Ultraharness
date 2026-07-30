# AGENTS.md

You have been pointed at the harness repo. It operates on a separate *target* repo; if
no target path was given, ask for one — never operate on this repo unless explicitly
told to.

## Routing

| If you need to… | Read |
| --- | --- |
| set up a repo for agent work / first contact with a target | `playbooks/seed.md` |
| assess a repo's health / find what to improve | `playbooks/audit.md` |
| actively improve a repo over a long run | `playbooks/improve.md` |
| judge a proposed change (diff, branch, PR) before it lands | `playbooks/review.md` |
| prove a change is done | `playbooks/verify.md` |
| remove the harness footprint from a repo | `playbooks/unseed.md` |
| check this harness still works | `playbooks/self-test.md` |

Load one playbook at a time. Playbooks reference `principles/` (universal rubrics) and
`lenses/` (conditional rubrics, each gated on evidence in the target) just-in-time —
don't preload either. A third finding class, **dimensions** (`teachability`,
`staleness`, `testing`), lives in the playbooks themselves: always-on judgment
categories with no rubric file and no gate.

## Global rules

- Use action vocabulary (run, read, write) — never name agent-specific tools.
- Never overwrite target files; existing files get a pointer block appended, not
  clobbered.
- All findings are ranked — never report a partial list.
- Evidence before claims: no completion claim without fresh output to back it.
- **The harness footprint is never evidence about the target.** Everything under
  `<target>/.agents/` and the `<!-- harness:begin -->`…`<!-- harness:end -->` blocks in
  the target's root `AGENTS.md` / `CLAUDE.md` is your own output. Never count it, judge
  it, measure it, or let it fire a gate. In those two root files the exclusion is the
  delimited block, not the file — content the target already had is the repo's own, and
  is evidence like any other file. Playbooks state only what this means at their step;
  the rule itself lives here. **One exception, narrow:** whether the record is *true*
  is fair game — `playbooks/audit.md` step 2b checks seeded claims against the code
  they cite and reports drift under `staleness`. Never counted toward the repo's grade;
  always checked for accuracy, because a stale record is trusted by every later
  session.
