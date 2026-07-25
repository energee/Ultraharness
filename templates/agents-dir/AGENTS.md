# AGENTS.md

This `.agents/` directory holds the working memory for agents improving this repo.
Read this file first; follow the pointers below only when you need them.

## About this repo

{{REPO_SUMMARY}}

- Build: `{{BUILD_CMD}}`
- Test: `{{TEST_CMD}}`
- Typecheck: `{{TYPECHECK_CMD}}`

## Conventions

Repo-specific conventions live in `conventions.md`. They were recorded from
observation of this codebase — match them before inventing your own.

## Principles

`principles.md` is the condensed rubric (DRY, KISS, SOLID, YAGNI) used to spot and
rank code-quality findings here. Read it before auditing or improving anything.

## Ongoing work

`ledger.md` tracks findings and their status across sessions. Read it before starting
work so you don't redo or collide with existing entries; update it as you go.
`learnings.md` holds lessons from past sessions — check it for known traps.

## Worktrees

Create improvement worktrees under `.agents/worktrees/<slug>/`; they are gitignored.
