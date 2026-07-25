# Atomic design — one home per design decision in a component UI

Finding slug: `atomic`.

## Definition

In a component-based UI, a design decision — a colour, a spacing step, a breakpoint —
should have one authoritative home, and a component should be usable without its
consumers reaching past its public surface. This is the general form. Brad Frost's
atoms/molecules/organisms naming is one house style for expressing it; a repo that
does not use those words is not defective.

## Gate — does this lens apply to this repo?

Run both, from the target's root:

```
git ls-files | grep -v '^\.agents/' | grep -Ei '\.(jsx|tsx|vue|svelte)$'
git ls-files | grep -v '^\.agents/' | grep -Ei '(^|/)components?/' && git grep -lE "from ['\"](react|vue|svelte|preact|solid-js|@angular/core)" -- . ':(exclude).agents/'
```

Both commands exclude `.agents/`: the harness's own seeded files are not the target's
code, and counting them would make a re-seed fire gates the repo itself never fired.

**Applies** if the first command prints at least one path, or if both halves of the
second print at least one path each — a components directory *and* a framework import;
either alone is not enough. If neither fires, this lens does not apply and is not
copied.

## How to spot it

- **Design tokens duplicated as literals**: the same hex colour, spacing value, or
  breakpoint hardcoded across 3+ components instead of read from one source (theme
  file, CSS custom property, token module). Grep the literal:
  `git grep -n '#1a73e8'`, `git grep -nE '(max|min)-width: *768px'`.
- **Prop drilling**: the same prop name threaded through 3+ intermediate components
  that only forward it. Grep the prop name and check whether each hit reads it or
  merely passes it down.
- **No single entry point**: a component library whose consumers deep-import internals
  (`from '../../ui/button/Button.internal'`) because no barrel or package export map
  exists.
- A component with several distinct reasons to change (fetches data + formats +
  renders + owns layout) — this is SRP. Cite SOLID; do not restate it here.
- Near-identical components differing only in a literal — this is DRY. Cite DRY and
  apply its rungs.

## How to fix it

1. **Token duplication** — move the literal into the existing token source and
   reference it; create a token module only if none exists.
2. **Prop drilling** — pass the composed child instead of the prop, or read from the
   context/store the intermediates already sit inside.
3. **Entry point** — add one barrel or export map and point consumers at it. Do not
   restructure the directory tree to match a naming hierarchy.

## When NOT to apply

- The repo has a deliberate flat component structure and it works. Flat is an
  architecture, not a missing hierarchy.
- A component is long but cohesive — length alone is not a finding.
- The naming does not match atoms/molecules/organisms. That is a convention, not a
  defect; flagging it prescribes taste.
- One-off literals, or a token duplicated in exactly 2 places — the third occurrence
  is the signal.
- A repo with no design system and no sign of wanting one: raise it with the user as a
  question, not as a finding.

## Overlap discipline

Where a finding is really SOLID or DRY, emit it as `[solid/...]` or `[dry/...]`. This
lens earns its slot only for what the core four cannot name: token duplication spread
across components, prop drilling, and the missing entry point.

## Finding format

`[<principle>/<severity high|med|low>] <file:line> — <what> — <smallest fix>`
