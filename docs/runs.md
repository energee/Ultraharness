# Run log

One line per improve run against a real target, appended by `playbooks/improve.md`
when the run ends — however it ends. Fixtures built by `playbooks/self-test.md` are
not runs and never appear here. The per-target evidence lives in each target's
`.agents/ledger.md`; this file is the harness's own durable record of what it has
actually done in the wild, and the aggregation point for the "wished I had" telemetry
that otherwise evaporates with each run's report.

Columns: date, target (path or name), findings done / parked / still open at exit,
the verdict mix (e.g. `3 PASS, 1 PASS (unverified-by-tests)`), and anything step 8's
"say what you wished you had" produced (or `none`).

| date | target | done | parked | open | verdicts | wished I had |
| --- | --- | --- | --- | --- | --- | --- |
