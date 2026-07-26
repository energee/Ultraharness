# Coverage log

Two records `playbooks/self-test.md` keeps between runs: which hard path step 5f
last exercised, and each playbook's line count per run. Both exist for the same
reason as `ablations.md` — without a record, "oldest-untested" is unanswerable and
growth is invisible.

## Hard-path rotation

Step 5f runs exactly one of these per self-test, oldest-untested first. A path with
no row here has never run and is evidence about nothing. Verdicts: `pass` (the
assertions held) or `defect` (a harness file needed step 7 — say which and what).

Paths: `park-and-hard-stop`, `testless-verify`, `authority-envelope`,
`mid-pass-resume`.

| date | path | observed | verdict |
| --- | --- | --- | --- |

## Prose budget

One line per self-test run, from `wc -l playbooks/*.md` (step 1 appends it). Growth
without a cause named in the same run's report is itself a finding — the playbooks'
length is the harness's biggest compliance risk, and every defect fix tends to add
lines. The 2026-07-26 baseline follows the table-class removal and the resume split.

| date | audit | improve | resume | seed | self-test | verify | total |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-07-26 | 205 | 388 | 69 | 300 | 454 | 169 | 1585 |
