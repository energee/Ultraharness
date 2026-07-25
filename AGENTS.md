# AGENTS.md

You have been pointed at the harness repo. It operates on a separate *target* repo; if
no target path was given, ask for one — never operate on this repo unless explicitly
told to.

## Routing

| If you need to… | Read |
| --- | --- |
| set up a repo for agent work / first contact with a target | `playbooks/seed.md` |
| assess a repo's health / find what to improve | `playbooks/audit.md` |
| actively improve a repo over a long run | `playbooks/improve.md` |
| prove a change is done | `playbooks/verify.md` |
| check this harness still works | `playbooks/self-test.md` |

Load one playbook at a time. Playbooks reference `principles/` just-in-time — don't
preload them.

## Global rules

- Use action vocabulary (run, read, write) — never name agent-specific tools.
- Never overwrite target files; existing files get a pointer block appended, not
  clobbered.
- All findings are ranked — never report a partial list.
- Evidence before claims: no completion claim without fresh output to back it.
