# KISS — Keep It Simple, Stupid

## Definition

Prefer the simplest solution that correctly handles the real requirements. Complexity
must be justified by a requirement, not by anticipated cleverness or taste.

## How to spot it

- Functions/methods longer than ~50 lines, or with nesting depth greater than 3
  (`if`/`for`/`while` stacked 4+ deep). Grep-able via linter line-count/complexity rules
  (e.g. eslint `max-lines-per-function`, `radon` for Python, `gocyclo` for Go — examples,
  not requirements).
- Cyclomatic complexity or branch count noticeably higher than sibling functions in the
  same file — a red flag, not a hard number.
- Cleverness markers where a plain loop or explicit branch would work: bit-twiddling
  tricks, dynamic metaprogramming (`eval`, reflection-heavy dispatch, monkey-patching),
  one-liner chains that require re-reading twice to parse.
- Indirection layers with exactly one caller and one implementation: a wrapper function,
  factory, or adapter that adds a hop but no variability.
- Configuration or parameterization for cases that don't exist yet (overlaps with YAGNI —
  flag under whichever principle fits the finding better, not both).

## How to fix it

Smallest intervention first:

1. **Inline the wrapper** — collapse a single-caller indirection layer back to its call
   site.
2. **Flatten nesting** — use early returns/guard clauses to cut nesting depth before
   splitting the function.
3. **Split the function** — extract named sub-steps only when flattening isn't enough,
   preserving one level of abstraction per function.
4. **Replace clever code with the boring equivalent** — swap bit tricks/metaprogramming
   for the plain-language version; keep the clever version only if a comment shows a
   measured perf requirement it satisfies and the plain version doesn't.

## When NOT to apply

- Don't strip input validation, error handling, or edge-case branches to hit a line-count
  or nesting target — those branches are requirements, not accidental complexity.
- Don't flatten a state machine or parser into "simpler" code that loses correctness for
  malformed input; some domains are irreducibly branchy.
- A short function that's genuinely hard to follow is worse than a longer function that
  reads linearly — line count is a heuristic, not the goal.

