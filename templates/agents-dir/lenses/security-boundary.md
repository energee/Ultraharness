# Security boundary — condensed lens

This file is here because its gate fired on this repo at seed time. A lens that is
present applies — do not re-judge the gate while auditing.

Findings use the standard format, with `security` in the principle slot, and the same
severity anchors as `principles.md`:

`[security/<severity high|med|low>] <file:line> — <what> — <smallest fix>`

At a trust boundary — an HTTP request, a webhook payload, a message off a shared
queue, an uploaded file — a mutation identifies and authorizes its caller, an
untrusted value never reaches an interpreter (SQL, shell, HTML) as code, and
credentials are configuration, not source.

## Spot it

- A mutating route (POST/PUT/PATCH/DELETE) whose handler chain carries no auth check —
  cite the route, the missing check, and where the repo's existing auth is applied.
- A query, shell command, or HTML fragment built by concatenation from a
  request-derived value.
- A webhook handler that acts on its payload without verifying the sender's
  signature, when the sender documents one.
- A credential literal in source instead of configuration.

## Fix it

Smallest rung first: mount the auth check the repo already has → parameterize the
query / pass exec args as a vector / use the engine's escaping → verify the webhook
signature with the documented mechanism → move the literal to configuration, required
at startup (that half is fail-fast's fix).

## Do NOT apply when

- It would claim exploitability — reachability and exposure are runtime knowledge;
  the finding names the missing check, never a vulnerability.
- The route is deliberately public (health, login/token, docs, a public read API).
- Auth terminates upstream (gateway, ingress, mTLS) and the repo says so — cite where.
- It's a CLI run by its own operator: argv and local files are not trust boundaries
  there.
- It needs a running system, cross-service data flow, or a pentest.

Overlap discipline: validation placement and silent config defaults are fail-fast —
emit them as `[fail-fast/...]`. This lens only earns findings the five cannot name:
missing authorization, untrusted values reaching an interpreter, unverified webhooks,
credentials in source.

Grep results are candidates. No finding without reading the code and naming the
untrusted source and the sink it reaches.
