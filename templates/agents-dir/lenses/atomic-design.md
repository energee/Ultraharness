# Atomic design — condensed lens

This file is here because its gate fired on this repo at seed time. A lens that is
present applies — do not re-judge the gate while auditing.

Findings use the standard format, with `atomic` in the principle slot, and the same
severity anchors as `principles.md`:

`[atomic/<severity high|med|low>] <file:line> — <what> — <smallest fix>`

A design decision — a colour, a spacing step, a breakpoint — should have one
authoritative home, and a component should be usable without consumers reaching past
its public surface. The atoms/molecules/organisms naming is a house style, not a
requirement.

## Spot it

- The same hex colour, spacing value, or breakpoint hardcoded across 3+ components
  instead of read from one token source.
- The same prop threaded through 3+ intermediate components that only forward it.
- A component library with no single entry point, so consumers deep-import internals.
- Several distinct reasons to change in one component — emit that as `[solid/...]`.
- Near-identical components differing only in a literal — emit that as `[dry/...]`.

## Fix it

Move the literal into the existing token source; replace drilled props with
composition or the context the intermediates already sit inside; add one barrel or
export map. Never restructure the directory tree to match a naming hierarchy.

## Do NOT apply when

- The repo has a deliberate flat component structure and it works.
- A component is long but cohesive — length alone is not a finding.
- The naming does not match atoms/molecules/organisms; that is a convention, not a
  defect.
- A literal appears in only 2 places — the third occurrence is the signal.

Overlap discipline: anything the core four already name is emitted as SOLID or DRY.
This lens only earns findings the core four cannot name — token duplication across
components, prop drilling, and the missing entry point.
