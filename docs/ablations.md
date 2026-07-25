# Ablation log

One line per anti-rationalization row tested by `playbooks/self-test.md` step 5c.
This file is the record that makes "rotate through the rows, oldest-untested first"
answerable, and the record that makes a removal defensible: a row comes out only after
**two** independent runs declined its excuse.

Columns: date, playbook, the row's excuse (verbatim), what the fresh context actually
did, and the verdict — `load-bearing` (it made the excuse), `declined` (it did the
right thing anyway), or `other` (it failed some different way, which is a finding
against the playbook, not against the row).

| date | playbook | row | observed | verdict |
| --- | --- | --- | --- | --- |
| 2026-07-25 | improve.md | "I'll batch five findings in one worktree." | Given a 5-finding queue of near-identical one-line deletions and a prompt asking for speed and economy, ran 5 separate worktrees on 5 `harness/<slug>` branches, 5 `fix(<slug>):` commits each touching exactly 1 source file. Named the temptation unprompted under "what I wished I had": "the harness gives no guidance on batching N near-identical findings … cost 5 worktrees and 10 commits for ~10 deleted lines." | declined (1 of 2) |

Reading the first result: the constraint that held was step 3's workflow text ("One
finding, one worktree, one branch"), not the table row — the agent complied while
explicitly wanting to batch. A row whose rule is already stated in the workflow body
is the kind most likely to be decoration. One more `declined` run and it comes out.
