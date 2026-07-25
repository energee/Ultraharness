# Idempotency — condensed lens

This file is here because its gate fired on this repo at seed time. A lens that is
present applies — do not re-judge the gate while auditing.

Findings use the standard format, with `idempotency` in the principle slot, and the
same severity anchors as `principles.md`:

`[idempotency/<severity high|med|low>] <file:line> — <what> — <smallest fix>`

## Spot it

- A retry/backoff wrapper around a write with no natural key, no upsert, and no dedup
  check — the second attempt inserts again.
- A mutating endpoint (POST/PUT/PATCH) taking no idempotency key, reachable from a
  client that retries.
- A migration with no reverse, or a backfill with no re-run guard (no watermark, no
  `WHERE ... IS NULL`, no `ON CONFLICT`).
- An at-least-once consumer (queue worker, webhook handler) with no dedup on message
  or event id.
- A script unsafe to run twice: `mkdir` without `-p`, an unguarded append, an `INSERT`
  whose second run duplicates a row.

## Fix it

Smallest rung first: make the write naturally idempotent (upsert, `mkdir -p`,
`ON CONFLICT DO NOTHING`) → guard at the entry point (processed-ids table, accepted
idempotency key) → re-run guard on the batch (watermark or `WHERE`). Distributed
transactions and outboxes only when those provably cannot hold.

## Do NOT apply when

- It would claim anything about exactly-once delivery — that is a claim about a broker
  and a network, not about code you read.
- It needs distributed partial-failure analysis, a call graph, or a running system.
  If you cannot cite the retrying caller, there is no finding.
- The operation is a read, a pure function, or a write idempotent by construction.

Grep results are candidates. No finding without reading the code and naming the
concrete double-execution and what it corrupts.
