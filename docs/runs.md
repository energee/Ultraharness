# Run log

One line per improve run against a real target, appended by `playbooks/improve.md`
when the run ends — however it ends. Fixtures built by `playbooks/self-test.md` are
not runs and never appear here. The per-target evidence lives in each target's
`.agents/ledger.md`; this file is Ultraharness's own durable record of what it has
actually done in the wild, and the aggregation point for the "wished I had" telemetry
that otherwise evaporates with each run's report.

Columns: date, target (path or name), findings done / parked / still open at exit,
the verdict mix (e.g. `3 PASS, 1 PASS (unverified-by-tests)`), the gauges movement
(the script's `gauges:` line from the run's first audit and from its most recent one,
`start → end`; one value if only one audit ran), and anything step 8's "say what you
wished you had" produced (or `none`).

| date | target | done | parked | open | verdicts | gauges (start → end) | wished I had |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Recurring wishes

The tally that makes the last column actionable. When appending a run line whose
wish matches one already recorded here, increment `seen` instead of adding a
duplicate — the same rule as a target's `learnings.md`, pointed at Ultraharness:

```
- [seen:<n>] <wish> (first: <date>, <target>)
```

A wish seen 2+ times has earned a look: it is a candidate for an Ultraharness change — a
new lens, a dimension, a rubric line, a playbook edit — made deliberately by whoever
maintains this repo, never automatically by a run. A promoted line is not deleted;
mark it `(promoted: <what changed>)` so the tally stays the record of why the change
exists. This section is append-and-increment only, like the table above it.

