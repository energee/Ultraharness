# Security boundary — untrusted input is checked where it enters, and mutations know their caller

Finding slug: `security`.

## Definition

A trust boundary is anywhere data or control arrives from outside the code you can
read: an HTTP request, a webhook payload, a message off a shared queue, an uploaded
file. At such a boundary three things are the code's job: a mutation identifies and
authorizes its caller, an untrusted value never reaches an interpreter (SQL, a shell,
HTML) as code, and credentials are configuration, not source. This lens judges those
three. Where validation *sits* is already fail-fast's bullet and stays there.

## Gate — does this lens apply to this repo?

`scripts/audit-checks.sh` decides this and prints the answer. Read its `gates:` line:

```
gates: security FIRED (4 hits; evidence: src/server.js, routes/items.js, middleware/auth.js)
gates: security not-fired
```

The patterns live in the script, in one place, so they cannot drift from the report the
playbooks already quote as fact — and so the same repo gates the same way on every
machine. The script matches route-registration and HTTP-handler vocabulary in file
contents (`app.post(`, `@app.route`, `HandleFunc`, `@GetMapping`, …) plus
route/controller/middleware paths, over authored code only.

**Applies** if the line reads `FIRED` *and* you open one cited path and confirm a real
boundary — an actual route registration or handler, not the vocabulary in a comment or
a client-side SDK call to someone else's server. That confirmation is the one
judgement the script cannot make. If the line reads `not-fired`, or you cannot confirm
a hit, this lens does not apply and is not copied.

## How to spot it

Each of these is grep-first, read-second. The grep gives you candidates; the finding
comes from the read.

- A mutating route (POST/PUT/PATCH/DELETE) whose handler chain carries no
  authentication or authorization check. Grep the registrations, then read the
  middleware stack each one mounts — the finding cites both the route and the check
  it lacks, and names where the repo's existing auth *is* applied, so the gap is
  relative to the repo's own pattern, not to an imagined one.
- A query, shell command, or HTML fragment built by concatenation or interpolation
  from a request-derived value — string-built SQL, `exec` with an interpolated
  argument, unescaped template output.
- A webhook or callback handler that acts on its payload without verifying the
  sender's signature, when the sender documents one.
- A credential literal in source — an API key, a password, a signing secret — rather
  than read from configuration.

## How to fix it

Smallest intervention first:

1. **Mount the auth check the repo already has** on the unprotected route — the fix
   is one line when the middleware exists; writing new auth machinery is a different,
   larger finding.
2. **Parameterize the query**; pass exec arguments as a vector, not a string; use the
   template engine's escaping instead of concatenation.
3. **Verify the webhook signature** with the mechanism the sender documents,
   preferably via the SDK the repo already imports.
4. **Move the literal to configuration** and make it required at startup — that
   second half is fail-fast's fix 3, cite it rather than restating it.

## When NOT to apply

- **Never claim exploitability.** This Ultraharness reads code. Whether the route is
  reachable, the value attacker-controlled in practice, or the deployment exposed is
  runtime knowledge; the finding names the missing check, not a vulnerability.
- **Deliberately public routes** — health checks, login and token endpoints, docs,
  a public read API. Unauthenticated is their design, not a defect.
- **Auth that terminates upstream** — a gateway, an ingress rule, mTLS between
  services — when the repo says so. Cite where it says so; if nothing in the repo
  does, raise the *absence of the statement* as the finding (teachability), not the
  missing check.
- **A CLI run by its own operator**: argv, local files, and the operator's
  environment are not trust boundaries there.
- Anything needing a running system, a data-flow proof across services, or a
  penetration test.

## Overlap discipline

Validation deferred past a boundary, and required config read with a silent default,
are fail-fast findings — emit them as `[fail-fast/...]`. This lens earns its slot only
for what the five cannot name: the missing authorization, the untrusted value reaching
an interpreter, the unverified webhook, the credential in source.

## Evidence discipline

Grep results are CANDIDATES, exactly as in DRY. No finding without reading the code
and naming the untrusted source and the sink it reaches: "`req.body.name` at
`routes/items.js:14` is concatenated into SQL at `db.js:40`" is a finding; "this looks
injectable" is not.
