# Idempotency — running it twice does what running it once did

Finding slug: `idempotency`.

## Definition

An operation is idempotent when executing it a second time with the same input leaves
the system in the same state as the first execution. Retries, redeliveries, re-runs,
and double-clicks are not exceptional — they are the normal operating condition of any
system with a network, a queue, or a human in it. The defect is a write path that
assumes it runs exactly once.

## Gate — does this lens apply to this repo?

`scripts/audit-checks.sh` decides this and prints the answer. Read its `gates:` line:

```
gates: idempotency FIRED (3 hits; evidence: workers/consumer.js, migrations/003_jobs.sql, deploy/release.sh)
gates: idempotency not-fired
```

The patterns live in the script, in one place, so they cannot drift from the report the
playbooks already quote as fact — and so the same repo gates the same way on every
machine. The script matches retry/queue/scheduler/webhook vocabulary in file *contents*,
plus migration/deploy/infra paths, over authored code only: `.agents/`, `CHANGELOG`,
`docs/`, and documentation extensions are excluded, because the word "retry" in prose or
a lockfile is not a construct.

**Applies** if the line reads `FIRED` *and* you open one cited path and confirm a real
construct — a retry wrapper, a queue/scheduler registration, a migration or backfill, a
webhook/event handler, or a deploy/infra script. That confirmation is the one judgement
the script cannot make: `grep` cannot tell a retry wrapper from a variable named
`retryCount` in a comment. If the line reads `not-fired`, or you cannot confirm a hit,
this lens does not apply and is not copied.

## How to spot it

Each of these is grep-first, read-second. The grep gives you candidates; the finding
comes from the read.

- A retry or backoff wrapper around an operation that writes, where the write has no
  natural key, no upsert, and no dedup check — the second attempt inserts again.
- A mutating HTTP endpoint (POST/PUT/PATCH) that accepts no idempotency key and is
  reachable from a client that retries (SDK, job, webhook sender, mobile app).
- A migration with no reverse/down path, or a data backfill with no re-run guard
  (no `WHERE ... IS NULL`, no watermark, no `ON CONFLICT`).
- An at-least-once consumer — queue worker, webhook handler, event subscriber — with
  no dedup on message id, event id, or a natural business key.
- A script that is not safe to run twice: `mkdir` without `-p`, an unguarded append to
  a file, an `INSERT` whose second run duplicates a row, an unconditional counter
  increment.

## How to fix it

Smallest intervention first:

1. **Make the write naturally idempotent** — upsert on a unique key, `mkdir -p`,
   `INSERT ... ON CONFLICT DO NOTHING`, a conditional `UPDATE ... WHERE`.
2. **Add a guard at the entry point** — a processed-ids table keyed on message/event
   id, or an accepted idempotency key echoed back on replay.
3. **Add a re-run guard to the batch** — a watermark column or a `WHERE` clause that
   makes the second run select zero rows.

Only reach for a distributed transaction or an outbox when 1-3 provably cannot hold.

## When NOT to apply

- **Exactly-once delivery claims.** Never assert a system does or does not achieve
  exactly-once. That is a claim about a broker and a network, not about code you read.
- **Distributed partial-failure analysis.** Interleavings, split-brain, and clock skew
  need runtime evidence Ultraharness does not gather.
- **Anything needing a call graph or a running system** — "is this endpoint actually
  reached by a retrying client?" answered by inference rather than by a caller you can
  cite. If you cannot name the caller, do not raise the finding.
- Reads, pure functions, and writes idempotent by construction (setting a field to a
  constant) are not findings.
- A write path with a documented at-most-once source and no retry anywhere is fine.

## Evidence discipline

Grep results are CANDIDATES, exactly as in DRY. No finding without reading the code
and naming the concrete double-execution: "the retry at `worker.py:41` re-runs
`create_invoice`, inserting a second invoice row" is a finding; "this looks
non-idempotent" is not.
