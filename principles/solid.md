# SOLID

## Definition

Five design heuristics for keeping units of code independently changeable and testable.
In practice, SRP and DIP catch the most real defects — spend most of the budget there.

## How to spot it

- **SRP (Single Responsibility)** — the file/class/module has 2+ distinct reasons to
  change: e.g. a `UserService` that both validates business rules and formats HTTP
  responses, or a class where half the methods touch persistence and half touch
  presentation. Signal: grep the file's imports — persistence + presentation + business
  logic imports together in one file is a tell. Also: a class whose methods split cleanly
  into two groups that never call each other.
- **DIP (Dependency Inversion)** — business/domain logic directly imports a concrete IO or
  framework dependency (DB client, HTTP client, filesystem, ORM model) instead of an
  interface/port passed in. Grep domain-layer files for `import` lines referencing
  drivers, SDKs, `fetch`, `requests`, `fs`, or ORM session objects.
- **OCP, LSP, ISP** — rarer in practice; don't force a finding to fill a quota. Only flag
  when concrete and cheap to fix:
  - OCP: adding a new case requires editing a long-established `if`/`switch` chain in
    multiple unrelated files (not just one dispatch point — that's often fine).
  - LSP: a subclass overrides a method to throw/no-op instead of implementing it, or
    narrows a precondition the base type promises.
  - ISP: a consumer is forced to implement/import a large interface but only calls 1-2 of
    its members, and other implementers duplicate no-op stubs for the rest.

## How to fix it

- **SRP**: split into two files/classes along the natural seam found above — smallest
  version is "extract the second responsibility into a sibling module," not a full
  redesign.
- **DIP**: introduce a narrow interface/port for the IO dependency and inject it (function
  param, constructor arg); don't build a generic plugin system for one swap point.
- **OCP/LSP/ISP**: prefer the smallest correcting move — extract the varying case into a
  data-driven map/table (OCP), fix the violating override to honor the contract or split
  the type (LSP), split the fat interface at the seam consumers actually use (ISP).

## When NOT to apply

- Don't introduce an interface/abstraction with a single implementation "for testability"
  or "for the future" — that's speculative and belongs to YAGNI's failure mode too.
  Precedence rule (matches `yagni.md`): if the seam is exercised by an actual test today,
  treat it as DIP (keep it, don't flag); if untested, treat it as YAGNI (flag it).
- Don't split a cohesive class just because it's long; SRP is about reasons to change, not
  line count (see `kiss.md` for length-based findings).
- Small internal helper classes with no external consumers don't need interface
  boundaries — DIP matters at architectural seams (domain/infra), not everywhere.

## Finding format

`[<principle>/<severity high|med|low>] <file:line> — <what> — <smallest fix>`
