# DRY — Don't Repeat Yourself

## Definition

Every piece of knowledge (a rule, a calculation, a config value) should have one
authoritative representation in the system. Duplicated *knowledge*, not duplicated text, is the defect.

## How to spot it

- `git grep`-able repetition: a block of 5+ contiguous lines appearing near-identically in
  2+ files. Search with `git grep -n` for a distinctive line from a suspect block and check
  hit count.
- Parallel switch/if chains that branch on the same discriminant in multiple places (e.g.
  `if type == "admin"` repeated in 3 files instead of centralized). Grep the discriminant
  value/variable name across the repo.
- Copy-pasted test setup/fixture code across 3+ test files — diff two test files' setup
  sections.
- The same literal (magic number, URL, threshold, error string) hardcoded in 2+ places
  instead of read from one config/constant.
- Language-specific dead-duplication scanners as examples only (not requirements):
  `jscpd`, `pmd-cpd`, `similarity-py`.

## How to fix it

Smallest intervention first — never skip a rung:

1. **Extract function/variable** — same logic, same file or two adjacent call sites.
2. **Extract module/shared file** — logic needed by 3+ call sites across files.
3. **Introduce abstraction (interface, base class, generic)** — only once 3+ concrete
   implementations exist and share behavior, not just shape.

Never jump straight to an abstraction on the 2nd occurrence if divergence between the
two instances is plausible (see below) — extract only what is provably identical.

## When NOT to apply

- **Incidental duplication**: two blocks look alike today but encode unrelated business
  rules that will diverge (e.g. tax calculation vs. discount calculation happen to both be
  `price * rate`). Merging couples things that should change independently.
- **Test readability**: repeating setup inline in each test so the test reads
  top-to-bottom without jumping to a shared fixture is often the right call — don't DRY
  away test clarity.
- Duplication of under 3-4 lines, or duplication that appears only twice with no sign of a
  third occurrence, is usually cheaper to leave than to abstract.

