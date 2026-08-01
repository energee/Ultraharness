# Coverage log

Two records `playbooks/self-test.md` keeps between runs: which hard path step 5f
last exercised, and each playbook's line count per run. Both exist for the same
reason as `ablations.md` — without a record, "oldest-untested" is unanswerable and
growth is invisible.

## Hard-path rotation

Step 5f runs exactly one of these per self-test, oldest-untested first. A path with
no row here has never run and is evidence about nothing. Verdicts: `pass` (the
assertions held) or `defect` (an Ultraharness file needed step 7 — say which and what).

Paths: `park-and-hard-stop`, `testless-verify`, `authority-envelope`,
`mid-pass-resume`, `review-guard-removal`.

| date | path | observed | verdict |
| --- | --- | --- | --- |

## Prose budget

One line per self-test run, from `wc -l playbooks/*.md` (step 1 appends it). Growth
without a cause named in the same run's report is itself a finding — the playbooks'
length is Ultraharness's biggest compliance risk, and every defect fix tends to add
lines. The 2026-07-26 baseline follows the table-class removal and the resume split.

| date | audit | improve | resume | review | seed | self-test | unseed | verify | total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-07-26 | 205 | 388 | 69 | — | 300 | 454 | — | 169 | 1585 |
| 2026-07-30 | 213 | 392 | 69 | 101 | 300 | 473 | 84 | 169 | 1801 |
| 2026-07-31 | 213 | 499 | 87 | 101 | 300 | 503 | 84 | 236 | 2023 |

2026-07-30 growth, cause named: `review` and `unseed` are new playbooks (columns
added); audit +8 names the dimensions class; improve +4 records gauges and the
recurring-wishes tally in the run log; self-test +19 covers the unseed exercise, the
four-gate fixture rules, and the `review-guard-removal` rotation path.

2026-07-31 growth, cause named: improve +107 defines bounded graph-aware waves and the
serial update/verify/merge queue; resume +18 triages wave members and merge-queue
evictions; verify +67 defines the independent evaluator node and fixed artifact;
self-test +30 exercises deterministic, non-mutating graph analysis and pins final
verification provenance. The remaining playbooks did not grow.
