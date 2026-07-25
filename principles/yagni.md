# YAGNI — You Aren't Gonna Need It

## Definition

Build for the requirement that exists today, not the one that might exist later.
Speculative generality is a cost paid now for a benefit that may never arrive.

## How to spot it

- Unused exports, functions, parameters, or feature flags — grep for a symbol's
  definition and count non-definition references; zero external references is a
  candidate. Language-specific tools as examples only: `knip`/`ts-prune` for JS/TS,
  `vulture` for Python, `deadcode` for Go — never required.
- Config options or env vars with exactly one value ever set across all environments
  (grep the config schema against actual `.env`/deploy configs).
- Abstractions (interface, strategy pattern, plugin registry) with a single concrete
  implementation and no second one on a committed roadmap.
- Comments containing "for future use," "will be needed when," "TODO: support," attached
  to code with no current caller.
- Feature flags that have been at 100% or 0% rollout for a long stretch with no
  in-progress migration — dead flag, dead branch.

## How to fix it

Smallest intervention first:

1. **Delete the unused export/param/flag** and its now-dead branches — verify with a
   repo-wide reference search before removing, not just an IDE hint.
2. **Collapse single-implementation abstractions** — inline the one implementation where
   the interface is called, remove the interface.
3. **Remove speculative config** — replace a config-driven value with the literal it
   always resolves to; reintroduce config only when a second value is actually needed.
4. Leave a short comment/commit message noting what was removed and why, so it's easy to
   reintroduce deliberately if a real second use case shows up.

## When NOT to apply

- Never delete input validation or sanitization at trust boundaries (API inputs, file
  parsing, deserialization) even if only one caller currently exists — the boundary is
  the requirement, not the caller count.
- Never delete anything backing persisted data — a column, table, migration, or
  serialized field — on a zero-reference argument. Rows outlive the code that reads
  them, and a dropped column is the one fix `git revert` cannot undo. Reversibility,
  not caller count, is the test.
- Never delete calibration knobs, tunable thresholds, or config for hardware/sensor
  interfaces even if only one value is set today — hardware variance across units/deploys
  is a real, current requirement, just not one visible in the codebase.
- Never delete accessibility affordances (ARIA attributes, alt text, focus management,
  keyboard handlers) for being "unused" by current automated tests — they have users who
  don't show up in call-site greps.
- A single-implementation interface that exists to break a dependency-injection/test seam
  (see `solid.md` DIP) is not speculative only if the seam is exercised by an actual test
  today. Precedence rule (matches `solid.md`): tested seam → DIP, keep it, don't flag;
  untested seam → YAGNI, flag it as speculative.

## Finding format

`[<principle>/<severity high|med|low>] <file:line> — <what> — <smallest fix>`
