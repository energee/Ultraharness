# harness

Point any coding agent at this repo to make any other repo simpler, DRY-er, KISS,
SOLID, and YAGNI. There is no install and no runtime — everything here is markdown
plus a few thin bash scripts. The agent reads a front door, routes to a playbook, and
does the rest.

## Quick start

Copy one of these prompts into your agent CLI, replacing the two paths. The same
prompt works in Claude Code, Codex CLI, Cursor, Gemini CLI, OpenCode, and any other
agent that can read files and run shell commands.

| Action | Prompt |
| --- | --- |
| Seed | `Read /path/to/harness/AGENTS.md, then run the seed playbook against my repo at <target-path>.` |
| Audit | `Read /path/to/harness/AGENTS.md, then run the audit playbook against my repo at <target-path>.` |
| Improve | `Read /path/to/harness/AGENTS.md, then run the improve playbook against my repo at <target-path>.` |

## What gets left behind

Seeding writes one directory, `.agents/`, into the target repo:

```
.agents/
  AGENTS.md               # target-local front door (conventions, routing, principles ref)
  conventions.md          # learned from the target repo during seeding
  principles.md           # condensed rubric (self-contained; no dependency on harness repo)
  ledger.md               # progress ledger — survives compaction and session death
  learnings.md            # repeated lessons, promoted after corroboration
  worktrees/              # gitignored; improvement-run worktrees, visible to all CLIs
```

`AGENTS.md` and `CLAUDE.md` at the target repo's root become thin pointers into
`.agents/` (created only if absent; existing files get a pointer block appended, never
overwritten).

## How it works

- The front door (`AGENTS.md`) routes to a playbook by decision, not topic:
  `playbooks/seed.md`, `playbooks/audit.md`, `playbooks/improve.md`,
  `playbooks/verify.md`, `playbooks/self-test.md`.
- `playbooks/audit.md` produces ranked findings plus a top-actions queue.
- `playbooks/improve.md` runs a loop — audit → fix → verify → de-sloppify →
  checkpoint — in worktrees under `.agents/worktrees/`.
- The ledger in `.agents/ledger.md` survives session death, so a run can pick back up
  cold.

See `docs/specs/` for the full design and `docs/research/` for the reference-project
research behind it.
