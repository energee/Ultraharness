# Graph model design note

The harness has two related graphs and deliberately stores neither in a graph
database.

The **workflow graph** is short-lived execution state: finding IDs, dependencies,
read/write scope, readiness, blockers, cycles, and write conflicts. The canonical
field and normalization semantics live in `templates/agents-dir/ledger.md`; the safe
wave and serial-merge policy lives in `playbooks/improve.md`. `scripts/ledger-graph.sh`
calculates facts from those fields without mutating the ledger or starting work.

The **knowledge/provenance graph** is durable evidence about why work exists and what
happened to it. The same ledger entry links observation commit, governing
principle/lens, dependencies, attempted worktree, fix commit, evaluator evidence,
measured delta, learning, and a named blocking gap. `playbooks/verify.md` is the
canonical evaluator-node contract. Git supplies temporal history for every ledger
change.

## Decisions

- Flat optional Markdown fields keep first contact human-readable and append-friendly.
  A missing scheduling field means unknown and preserves serial behavior; explicit
  `none` means known empty. Old entries remain valid without fabricated migration.
- Typing is prospective. Once an entry has an ID, `done` requires evidence, a fix
  commit, and verifier identity bound to that commit. Historical ID-less `done`
  entries remain compatibility-valid.
- Dependencies use stable, case-sensitive ASCII IDs, with lowercase `none` reserved
  for empty lists. Read and write scope use repeatable atomic path fields, so commas
  remain part of a normalized repository-relative lexical path; ancestor/descendant
  writes conflict. Reads are
  review/provenance scope and do not conflict because fixes are isolated and every
  candidate is updated and reverified before serial merge.
- Parallelism is a human-authorized execution policy, not analyzer behavior. The
  analyzer remains a dependency-free deterministic report; automatic mutation is out
  of scope.

## Deferred scope

An append-only event stream is deferred. Git already records each ledger transition,
while a second timeline would introduce two truths and reconciliation rules without a
demonstrated query the current fields cannot answer. A graph database, embeddings,
automatic scheduler, distributed locks, cross-repository dependencies, and a durable
binary diff store are likewise deferred. Exact diff inputs remain reproducible from
their recorded base and candidate commits; if real runs demonstrate that Git history
is insufficient, that observation can justify a separate artifact store later.
