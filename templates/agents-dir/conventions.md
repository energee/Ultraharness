# Conventions

recorded-at: {{RECORDED_AT}}

<!-- Record only what you verified in >=2 places; cite an example file for each claim.

     Two rules keep this file from rotting into a confident lie:

     1. NOTHING DERIVABLE. If an agent can recompute it by reading the repo — module
        lists, directory trees, file counts, "there are three layers" — leave it out.
        Derivable facts are the ones guaranteed to go stale, and restating them is
        duplicated knowledge, which DRY predicts will diverge. Record what the code
        cannot say for itself: intent, rationale, which of two plausible patterns is
        the house style.
     2. NOTHING UNCITED. Every claim names a file, and a line where that helps. The
        citation is not decoration — it is what lets a later reader falsify the claim
        in one read. An uncited claim can never be proven wrong, so it never gets
        fixed. A claim whose citation no longer resolves, or whose cited code no
        longer supports it, is VOID — not "probably still true".

     recorded-at is the commit these observations were made against. It is what makes
     staleness cheap to check: `git diff <recorded-at>..HEAD -- <cited paths>`. If
     nothing under the citations moved, the claims are as good as when written. -->

## Layout

{{OBSERVED}}

## Naming

{{OBSERVED}}

## Testing patterns

{{OBSERVED}}

## Error handling

{{OBSERVED}}

## Commit style

{{OBSERVED}}
