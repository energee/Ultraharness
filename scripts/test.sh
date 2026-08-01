#!/usr/bin/env bash
# test.sh — bash test suite for scripts/audit-checks.sh,
# scripts/ledger-graph.sh, and scripts/smoke-check.sh, plus the rubric sync
# tripwire pinning full-form rubrics to their condensed twins.
# Builds a throwaway fixture repo in a temp dir, runs audit-checks.sh against it,
# and asserts on the printed facts with grep. Prints PASS/FAIL per assertion and
# exits nonzero if any assertion fails. No dependencies beyond git + coreutils.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="$SCRIPT_DIR/audit-checks.sh"
GRAPH="$SCRIPT_DIR/ledger-graph.sh"

FAILS=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; FAILS=$((FAILS + 1)); }

assert_grep() {
  # assert_grep <description> <pattern> <file>
  if grep -q "$2" "$3"; then pass "$1"; else fail "$1 (pattern not found: $2)"; fi
}

assert_not_grep() {
  # assert_not_grep <description> <pattern> <file>
  if grep -q "$2" "$3"; then
    fail "$1 (pattern found, expected absent: $2 — $(grep -m1 "$2" "$3"))"
  else
    pass "$1"
  fi
}

# --- rubric sync tripwire ---
# The full-form rubrics (principles/, lenses/) and their condensed twins
# (templates/agents-dir/) are deliberate duplication — README says why — which
# leaves them free to drift apart silently. Each hash below pins one file at its
# last deliberate sync. Editing any of them fails here until the hash is updated:
# re-read the twin, re-sync it if the change affects it, then paste the new hash
# the failure message prints. That converts silent drift into a red test at the
# moment of the edit — the same trick recorded-at plays on targets, pointed inward.
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
check_sync() {
  # check_sync <repo-relative file> <sha256 at last sync>
  local actual
  actual="$(shasum -a 256 "$REPO_ROOT/$1" | awk '{print $1}')"
  if [ "$actual" = "$2" ]; then
    pass "rubric sync: $1 unchanged since last sync"
  else
    fail "rubric sync: $1 changed — re-sync its twin if needed, then record $actual"
  fi
}
check_sync principles/dry.md        e1cc30fc1b1fd14e7160d235b096a7e363b367a1bd5172e45b6986a9448016d8
check_sync principles/kiss.md       81d07de626fea0b0acd751c4f0e4c53ddfe4c7ddc249a4bb15179a321b4865cf
check_sync principles/solid.md      1c29917458db8535e91a311aed23d99b9871a56c875384611741c8b387ecce71
check_sync principles/yagni.md      c724c113841a6cf80ee892eb8cc9df6986ba267fbcbf9fdb55b434f7814d77f9
check_sync principles/fail-fast.md  38b1e68fa1d765accf3de14ce531b0ea738be8fd8dcf31aa81ae1381feb2770b
check_sync lenses/a11y.md           8488cde111a0bb622369b32eb7f2b2effd47e30e6a6e4a259959c4f5bcf72091
check_sync lenses/atomic-design.md  393a6fcdaab01690ddb82b5866481fe396253191a1667e7a8f86ace299573cf2
check_sync lenses/idempotency.md    61a01176cf0d5cb30ea7de4e10219c7cb27d223ce736c36a35618818e2c1a456
check_sync lenses/security-boundary.md  52f201a89f345a7b26931346c78b10fff9789529cecaa3dad550786d7f01042d
check_sync templates/agents-dir/principles.md            e5777b57c21c05d0aa55a62c16a1f4f4a7fb6160c7672e0956325e54102980d8
check_sync templates/agents-dir/lenses/a11y.md           58767016c3c2de6ddc9097167611108b2b61d2e7b020a50437086d6a14271189
check_sync templates/agents-dir/lenses/atomic-design.md  40f7e65a40d11872f0e599c638c84556dad1f2510690daa3503e6ae87c80f686
check_sync templates/agents-dir/lenses/idempotency.md    23b55a5b1c6b1fe94825816dc1541a16057d63ad4765ef7670e2f264e2647e68
check_sync templates/agents-dir/lenses/security-boundary.md  c6126465c617e589ddfa885416386e01fcc1c35c1e62040d9bb0c2020db042a6

# --- Ultraharness branding and protocol namespace ---
assert_grep "branding: README uses Ultraharness name" \
  "^# Ultraharness$" "$REPO_ROOT/README.md"
assert_grep "branding: seed writes Ultraharness pointer marker" \
  "<!-- ultraharness:begin -->" "$REPO_ROOT/playbooks/seed.md"
assert_grep "branding: improve writes Ultraharness branch namespace" \
  "ultraharness/<finding-slug>" "$REPO_ROOT/playbooks/improve.md"
assert_grep "branding: seed uses Ultraharness commit identity" \
  "Seed \.agents/ Ultraharness" "$REPO_ROOT/playbooks/seed.md"
assert_grep "branding: seed migrates the deprecated pointer marker" \
  "Treat the deprecated" "$REPO_ROOT/playbooks/seed.md"
assert_grep "branding: resume recognizes the deprecated branch namespace" \
  "or the deprecated" "$REPO_ROOT/playbooks/resume.md"

# --- fixture repo ---
FIXTURE="$(mktemp -d)"
trap 'kill "$(cat "$FIXTURE.web/pid" 2>/dev/null)" 2>/dev/null || true; rm -rf "$FIXTURE" "$FIXTURE".out* "$FIXTURE".ui "$FIXTURE".web' EXIT

# --- ledger graph readiness ---
# Keep these as literal seeded-ledger fixtures rather than generating fields in a
# loop: the parser contract is the Markdown humans edit, including spaces and the
# documentation/entry `---` boundary.
GRAPH_DIR="$FIXTURE/graph cases"
mkdir -p "$GRAPH_DIR"

run_graph_case() {
  # run_graph_case <description> <ledger> <expected-exit> <output>
  local description="$1" ledger="$2" expected="$3" output="$4" actual
  set +e
  bash "$GRAPH" "$ledger" > "$output" 2>&1
  actual=$?
  set -e
  if [ "$actual" -eq "$expected" ]; then
    pass "$description"
  else
    fail "$description (expected exit $expected, got $actual; $(tail -3 "$output" | tr '\n' ' '))"
  fi
}

OUT_GRAPH_NOFILE="$GRAPH_DIR/no-file.out"
run_graph_case "graph: nonexistent ledger exits 2" \
  "$GRAPH_DIR/does not exist.md" 2 "$OUT_GRAPH_NOFILE"
assert_grep "graph: path error gives root cause" "^root cause:" "$OUT_GRAPH_NOFILE"
assert_grep "graph: path error gives safe next action" "^safe next action:" "$OUT_GRAPH_NOFILE"
assert_grep "graph: path error gives stop condition" "^stop condition:" "$OUT_GRAPH_NOFILE"

LEGACY_LEDGER="$GRAPH_DIR/legacy ledger.md"
cat > "$LEGACY_LEDGER" <<'EOF'
# Ledger
---
## 2026-07-01 legacy-open
- finding: [dry/med] src/old.js:1 — old format remains valid
- status: open
- attempts: 0/3
- delta: pending

## 2026-07-01 legacy-done
- finding: [kiss/low] src/done.js:1 — historical done entry has no graph evidence
- status: done
- attempts: 1/3
- delta: tests green
EOF
OUT_GRAPH_LEGACY="$GRAPH_DIR/legacy.out"
run_graph_case "graph: legacy ledger exits 0" "$LEGACY_LEDGER" 0 "$OUT_GRAPH_LEGACY"
assert_grep "graph: legacy ledger requires serial fallback" \
  "^serial fallback required: yes$" "$OUT_GRAPH_LEGACY"
assert_grep "graph: legacy open finding is reported ready in serial order" \
  "^  legacy:legacy-open (open)$" "$OUT_GRAPH_LEGACY"
assert_grep "graph: legacy done without evidence is compatibility-valid" \
  "^malformed graph fields:$" "$OUT_GRAPH_LEGACY"
assert_not_grep "graph: legacy done is not rejected for missing evidence" \
  "typed done finding requires" "$OUT_GRAPH_LEGACY"

INDEPENDENT_LEDGER="$GRAPH_DIR/independent.md"
cat > "$INDEPENDENT_LEDGER" <<'EOF'
# Ledger
---
## 2026-07-02 first
- finding: [dry/med] src/a.js:1 — first independent finding
- status: open
- attempts: 0/3
- delta: pending
- id: F-A
- depends-on: none
- read-path: src/input a.txt
- write-path: src/a.js
- acceptance: first behavior is covered

## 2026-07-02 second
- finding: [kiss/med] src/b.js:1 — second independent finding
- status: open
- attempts: 0/3
- delta: pending
- id: F-B
- depends-on: none
- read-path: src/input b.txt
- write-path: src/b.js
- acceptance: second behavior is covered
EOF
OUT_GRAPH_INDEPENDENT="$GRAPH_DIR/independent.out"
run_graph_case "graph: two independent findings exit 0" "$INDEPENDENT_LEDGER" 0 "$OUT_GRAPH_INDEPENDENT"
assert_grep "graph: fully typed queue does not require serial fallback" \
  "^serial fallback required: no$" "$OUT_GRAPH_INDEPENDENT"
assert_grep "graph: first independent finding ready" "^  F-A (first; open)$" "$OUT_GRAPH_INDEPENDENT"
assert_grep "graph: second independent finding ready" "^  F-B (second; open)$" "$OUT_GRAPH_INDEPENDENT"
assert_grep "graph: zero-valued summary counters print deterministically as zero" \
  "^summary: ready=2 blocked=0 cycles=0 missing=0 conflicts=0 malformed=0$" "$OUT_GRAPH_INDEPENDENT"

UNLOCKED_LEDGER="$GRAPH_DIR/unlocked.md"
cat > "$UNLOCKED_LEDGER" <<'EOF'
# Ledger
---
## 2026-07-03 prerequisite
- finding: [testing/high] test.sh:1 — prerequisite
- status: done
- attempts: 1/3
- delta: suite red -> green
- id: F-BASE
- depends-on: none
- read-path: test.sh
- write-path: src/base.js
- acceptance: suite passes
- evidence: `bash test.sh` exit 0 at abcdef1
- fixed-by: abcdef1
- verified-by: verifier-one @ abcdef1

## 2026-07-03 dependent
- finding: [solid/med] src/dependent.js:1 — unlocked work
- status: open
- attempts: 0/3
- delta: pending
- id: F-DEP
- depends-on: F-BASE
- read-path: src/base.js
- write-path: src/dependent.js
- acceptance: dependent behavior passes
EOF
OUT_GRAPH_UNLOCKED="$GRAPH_DIR/unlocked.out"
run_graph_case "graph: completed dependency fixture exits 0" "$UNLOCKED_LEDGER" 0 "$OUT_GRAPH_UNLOCKED"
assert_grep "graph: completed dependency unlocks dependent" \
  "^  F-DEP (dependent; open)$" "$OUT_GRAPH_UNLOCKED"
assert_grep "graph: completed dependency creates no blocker" \
  "^blocked findings:$" "$OUT_GRAPH_UNLOCKED"

UNFINISHED_LEDGER="$GRAPH_DIR/unfinished.md"
sed 's/- status: done/- status: open/' "$UNLOCKED_LEDGER" > "$UNFINISHED_LEDGER"
OUT_GRAPH_UNFINISHED="$GRAPH_DIR/unfinished.out"
run_graph_case "graph: unfinished dependency fixture exits 0" "$UNFINISHED_LEDGER" 0 "$OUT_GRAPH_UNFINISHED"
assert_grep "graph: unfinished dependency blocks dependent" \
  "^  F-DEP (dependent; open) <- F-BASE (open)$" "$OUT_GRAPH_UNFINISHED"

PARKED_LEDGER="$GRAPH_DIR/parked.md"
sed 's/- status: done/- status: parked(proof)/' "$UNLOCKED_LEDGER" > "$PARKED_LEDGER"
OUT_GRAPH_PARKED="$GRAPH_DIR/parked.out"
run_graph_case "graph: parked dependency fixture exits 0" "$PARKED_LEDGER" 0 "$OUT_GRAPH_PARKED"
assert_grep "graph: parked dependency blocks dependent" \
  "^  F-DEP (dependent; open) <- F-BASE (parked(proof))$" "$OUT_GRAPH_PARKED"

MISSING_LEDGER="$GRAPH_DIR/missing.md"
sed 's/- depends-on: F-BASE/- depends-on: F-NOT-THERE/' "$UNLOCKED_LEDGER" > "$MISSING_LEDGER"
OUT_GRAPH_MISSING="$GRAPH_DIR/missing.out"
run_graph_case "graph: missing dependency exits nonzero" "$MISSING_LEDGER" 1 "$OUT_GRAPH_MISSING"
assert_grep "graph: missing dependency ID named" \
  "^  F-NOT-THERE <- F-DEP (dependent)$" "$OUT_GRAPH_MISSING"
assert_grep "graph: invalid report gives numeric root cause" \
  "^root cause: malformed=0, cycles=0, missing-dependencies=1$" "$OUT_GRAPH_MISSING"
assert_grep "graph: invalid report gives safe next action" "^safe next action:" "$OUT_GRAPH_MISSING"
assert_grep "graph: invalid report gives stop condition" "^stop condition:" "$OUT_GRAPH_MISSING"

DIRECT_CYCLE_LEDGER="$GRAPH_DIR/direct cycle.md"
sed 's/- depends-on: F-BASE/- depends-on: F-DEP/' "$UNLOCKED_LEDGER" > "$DIRECT_CYCLE_LEDGER"
OUT_GRAPH_DIRECT="$GRAPH_DIR/direct-cycle.out"
run_graph_case "graph: direct cycle exits nonzero" "$DIRECT_CYCLE_LEDGER" 1 "$OUT_GRAPH_DIRECT"
assert_grep "graph: direct cycle reported" "^  F-DEP -> F-DEP$" "$OUT_GRAPH_DIRECT"

MULTI_CYCLE_LEDGER="$GRAPH_DIR/multi-cycle.md"
cat > "$MULTI_CYCLE_LEDGER" <<'EOF'
# Ledger
---
## 2026-07-04 alpha
- finding: [dry/med] a:1 — alpha
- status: open
- attempts: 0/3
- delta: pending
- id: F-A
- depends-on: F-B
- read-path: none
- write-path: a
- acceptance: alpha passes
## 2026-07-04 beta
- finding: [dry/med] b:1 — beta
- status: open
- attempts: 0/3
- delta: pending
- id: F-B
- depends-on: F-C
- read-path: none
- write-path: b
- acceptance: beta passes
## 2026-07-04 gamma
- finding: [dry/med] c:1 — gamma
- status: open
- attempts: 0/3
- delta: pending
- id: F-C
- depends-on: F-A
- read-path: none
- write-path: c
- acceptance: gamma passes
EOF
OUT_GRAPH_MULTI="$GRAPH_DIR/multi-cycle.out"
run_graph_case "graph: multi-node cycle exits nonzero" "$MULTI_CYCLE_LEDGER" 1 "$OUT_GRAPH_MULTI"
assert_grep "graph: multi-node cycle reported deterministically" \
  "^  F-A -> F-B -> F-C -> F-A$" "$OUT_GRAPH_MULTI"

CONFLICT_LEDGER="$GRAPH_DIR/write conflicts.md"
cat > "$CONFLICT_LEDGER" <<'EOF'
# Ledger
---
## 2026-07-05 exact-one
- finding: [dry/med] src/shared.js:1 — exact one
- status: open
- attempts: 0/3
- delta: pending
- id: F-EXACT-1
- depends-on: none
- read-path: docs/shared.md
- write-path: .//src///shared.js
- acceptance: exact one passes
## 2026-07-05 exact-two
- finding: [dry/med] src/shared.js:2 — exact two
- status: open
- attempts: 0/3
- delta: pending
- id: F-EXACT-2
- depends-on: none
- read-path: docs/shared.md
- write-path: src/shared.js
- acceptance: exact two passes
## 2026-07-05 parent
- finding: [kiss/med] config:1 — parent
- status: open
- attempts: 0/3
- delta: pending
- id: F-PARENT
- depends-on: none
- read-path: src/read-only.js
- write-path: config
- acceptance: parent passes
## 2026-07-05 child
- finding: [kiss/med] config/app.yml:1 — child
- status: open
- attempts: 0/3
- delta: pending
- id: F-CHILD
- depends-on: none
- read-path: config
- write-path: config/app.yml
- acceptance: child passes
## 2026-07-05 read-write-one
- finding: [solid/low] src/reader.js:1 — reads another write
- status: open
- attempts: 0/3
- delta: pending
- id: F-RW-1
- depends-on: none
- read-path: src/generated.js
- write-path: src/reader.js
- acceptance: reader passes
## 2026-07-05 read-write-two
- finding: [solid/low] src/generated.js:1 — writes another read
- status: open
- attempts: 0/3
- delta: pending
- id: F-RW-2
- depends-on: none
- read-path: src/reader.js
- write-path: src/generated.js
- acceptance: generated output passes
## 2026-07-05 spaced-one
- finding: [dry/low] dir with space/file.js:1 — spaced path one
- status: open
- attempts: 0/3
- delta: pending
- id: F-SPACE-1
- depends-on: none
- read-path: none
- write-path: dir with space/file.js
- acceptance: spaced one passes
## 2026-07-05 spaced-two
- finding: [dry/low] dir with space/file.js:2 — spaced path two
- status: open
- attempts: 0/3
- delta: pending
- id: F-SPACE-2
- depends-on: none
- read-path: none
- write-path: ./dir with space//file.js
- acceptance: spaced two passes
## 2026-07-05 comma-one
- finding: [dry/low] dir/a,b.js:1 — comma path one
- status: open
- attempts: 0/3
- delta: pending
- id: F-COMMA-1
- depends-on: none
- read-path: none
- write-path: dir/a,b.js
- acceptance: comma path one passes
## 2026-07-05 comma-two
- finding: [dry/low] dir/a,b.js:2 — comma path two
- status: open
- attempts: 0/3
- delta: pending
- id: F-COMMA-2
- depends-on: none
- read-path: none
- write-path: ./dir//a,b.js
- acceptance: comma path two passes
EOF
OUT_GRAPH_CONFLICT="$GRAPH_DIR/write-conflicts.out"
run_graph_case "graph: write conflict fixture exits 0" "$CONFLICT_LEDGER" 0 "$OUT_GRAPH_CONFLICT"
assert_grep "graph: identical normalized write paths conflict" \
  "^  F-EXACT-1 <-> F-EXACT-2: src/shared.js$" "$OUT_GRAPH_CONFLICT"
assert_grep "graph: parent and child write paths conflict" \
  "^  F-PARENT <-> F-CHILD: config <-> config/app.yml$" "$OUT_GRAPH_CONFLICT"
assert_grep "graph: paths containing spaces are preserved" \
  "^  F-SPACE-1 <-> F-SPACE-2: dir with space/file.js$" "$OUT_GRAPH_CONFLICT"
assert_grep "graph: paths containing commas are preserved atomically" \
  "^  F-COMMA-1 <-> F-COMMA-2: dir/a,b.js$" "$OUT_GRAPH_CONFLICT"
assert_grep "graph: only the four write/write overlaps conflict" \
  "conflicts=4" "$OUT_GRAPH_CONFLICT"
assert_not_grep "graph: read/read overlap does not conflict" \
  "F-EXACT-1 <-> F-PARENT" "$OUT_GRAPH_CONFLICT"
assert_not_grep "graph: read/write overlap does not conflict" \
  "F-RW-1 <-> F-RW-2" "$OUT_GRAPH_CONFLICT"

RESERVED_ID_LEDGER="$GRAPH_DIR/reserved-id.md"
cat > "$RESERVED_ID_LEDGER" <<'EOF'
# Ledger
---
## 2026-07-05 reserved
- finding: [kiss/med] src/reserved.js:1 — reserved empty-set token used as an ID
- status: open
- attempts: 0/3
- delta: pending
- id: none
- depends-on: none
- read-path: none
- write-path: src/reserved.js
- acceptance: reserved ID is rejected
EOF
OUT_GRAPH_RESERVED_ID="$GRAPH_DIR/reserved-id.out"
run_graph_case "graph: reserved none ID exits nonzero" \
  "$RESERVED_ID_LEDGER" 1 "$OUT_GRAPH_RESERVED_ID"
assert_grep "graph: reserved none ID gives the ambiguity cause" \
  "id 'none' is reserved for empty lists" "$OUT_GRAPH_RESERVED_ID"

MALFORMED_LEDGER="$GRAPH_DIR/malformed.md"
cat > "$MALFORMED_LEDGER" <<'EOF'
# Ledger
---
## 2026-07-06 malformed
- finding: [dry/med] src/a.js:1 — malformed fields
- status: open
- attempts: 0/3
- delta: pending
- id: F-BAD
- depends-on: F-A,,F-B
- read-path: none
- read-path: src/a.js
- write-path: /absolute/path
- write-path: src/a.js
- write-path: ./src//a.js
- acceptance: malformed must fail
EOF
OUT_GRAPH_MALFORMED="$GRAPH_DIR/malformed.out"
run_graph_case "graph: malformed graph fields exit nonzero" "$MALFORMED_LEDGER" 1 "$OUT_GRAPH_MALFORMED"
assert_grep "graph: malformed dependency list gives field cause" \
  "depends-on contains an empty list member" "$OUT_GRAPH_MALFORMED"
assert_grep "graph: malformed write path gives field cause" \
  "write-path path '/absolute/path' is not repository-relative" "$OUT_GRAPH_MALFORMED"
assert_grep "graph: none cannot mix with atomic paths" \
  "read-path mixes none with paths" "$OUT_GRAPH_MALFORMED"
assert_grep "graph: repeated normalized atomic path is rejected" \
  "write-path repeats normalized path 'src/a.js'" "$OUT_GRAPH_MALFORMED"

DEPRECATED_PATHS_LEDGER="$GRAPH_DIR/deprecated-paths.md"
cat > "$DEPRECATED_PATHS_LEDGER" <<'EOF'
# Ledger
---
## 2026-07-06 deprecated-paths
- finding: [kiss/low] src/a.js:1 — removed CSV path fields
- status: open
- attempts: 0/3
- delta: pending
- id: F-DEPRECATED
- depends-on: none
- reads: src/a.js
- writes: src/a.js
- acceptance: deprecated path fields fail clearly
EOF
OUT_GRAPH_DEPRECATED_PATHS="$GRAPH_DIR/deprecated-paths.out"
run_graph_case "graph: deprecated CSV path fields exit nonzero" \
  "$DEPRECATED_PATHS_LEDGER" 1 "$OUT_GRAPH_DEPRECATED_PATHS"
assert_grep "graph: deprecated reads field names atomic replacement" \
  "deprecated graph field reads; use repeatable read-path" "$OUT_GRAPH_DEPRECATED_PATHS"
assert_grep "graph: deprecated writes field names atomic replacement" \
  "deprecated graph field writes; use repeatable write-path" "$OUT_GRAPH_DEPRECATED_PATHS"

DONE_NO_EVIDENCE_LEDGER="$GRAPH_DIR/done without evidence.md"
cat > "$DONE_NO_EVIDENCE_LEDGER" <<'EOF'
# Ledger
---
## 2026-07-07 typed-done
- finding: [dry/med] src/a.js:1 — typed done without proof
- status: done
- attempts: 1/3
- delta: claimed done
- id: F-DONE
- depends-on: none
- read-path: src/a.js
- write-path: src/a.js
- acceptance: behavior passes
EOF
OUT_GRAPH_DONE_NO_EVIDENCE="$GRAPH_DIR/done-without-evidence.out"
run_graph_case "graph: typed done without evidence exits nonzero" \
  "$DONE_NO_EVIDENCE_LEDGER" 1 "$OUT_GRAPH_DONE_NO_EVIDENCE"
assert_grep "graph: typed done requires verification evidence" \
  "typed done finding requires evidence" "$OUT_GRAPH_DONE_NO_EVIDENCE"
assert_grep "graph: typed done requires fixed-by commit" \
  "typed done finding requires fixed-by" "$OUT_GRAPH_DONE_NO_EVIDENCE"
assert_grep "graph: typed done requires verified-by identity and commit" \
  "typed done finding requires verified-by" "$OUT_GRAPH_DONE_NO_EVIDENCE"

OUT_GRAPH_REPEAT="$GRAPH_DIR/repeat.out"
run_graph_case "graph: repeated run exits 0" "$CONFLICT_LEDGER" 0 "$OUT_GRAPH_REPEAT"
if cmp -s "$OUT_GRAPH_CONFLICT" "$OUT_GRAPH_REPEAT"; then
  pass "graph: repeated runs are byte-identical"
else
  fail "graph: repeated runs are byte-identical"
fi
GRAPH_LOCALES="$(locale -a 2>/dev/null || true)"
case "$GRAPH_LOCALES" in
  *en_US.UTF-8*) GRAPH_UTF8_LOCALE=en_US.UTF-8 ;;
  *en_US.utf8*)  GRAPH_UTF8_LOCALE=en_US.utf8 ;;
  *)             GRAPH_UTF8_LOCALE= ;;
esac
if [ -n "$GRAPH_UTF8_LOCALE" ]; then
  OUT_GRAPH_LOCALE="$GRAPH_DIR/locale.out"
  set +e
  LC_ALL="$GRAPH_UTF8_LOCALE" bash "$GRAPH" "$CONFLICT_LEDGER" > "$OUT_GRAPH_LOCALE" 2>&1
  RC_GRAPH_LOCALE=$?
  set -e
  if [ "$RC_GRAPH_LOCALE" -eq 0 ] && cmp -s "$OUT_GRAPH_CONFLICT" "$OUT_GRAPH_LOCALE"; then
    pass "graph: output identical under C and $GRAPH_UTF8_LOCALE"
  else
    fail "graph: output identical under C and $GRAPH_UTF8_LOCALE (exit $RC_GRAPH_LOCALE)"
  fi
else
  printf 'SKIP: %s\n' "graph: no en_US UTF-8 locale available on this machine"
fi

assert_grep "graph: analyzer declares contract version 1" \
  "^GRAPH_CONTRACT_VERSION=1$" "$GRAPH"
assert_grep "graph: improve playbook pins analyzer contract version 1" \
  "ledger-graph-contract: v1" "$REPO_ROOT/playbooks/improve.md"
assert_grep "graph: wave docs keep serial execution as default" \
  "^Serial execution is the default" "$REPO_ROOT/playbooks/improve.md"
assert_grep "graph: wave docs require dependencies done before selection" \
  "^every selected finding must already be.*done" "$REPO_ROOT/playbooks/improve.md"
assert_grep "graph: wave docs use analyzer write conflicts" \
  "no reported write" "$REPO_ROOT/playbooks/improve.md"
assert_grep "graph: wave docs keep landing serial" \
  "^Landing is one serial merge queue" "$REPO_ROOT/playbooks/improve.md"
assert_grep "graph: merge docs require one complete candidate commit" \
  "exactly one.*commit ahead of current base" "$REPO_ROOT/playbooks/improve.md"
assert_grep "graph: ledger docs match write/write-only policy" \
  "Only write/write overlap is a conflict" "$REPO_ROOT/templates/agents-dir/ledger.md"
assert_grep "graph: ledger docs match parent/child path policy" \
  "ancestor/descendant overlap as a conflict" "$REPO_ROOT/templates/agents-dir/ledger.md"
assert_grep "graph: ledger docs reserve none from the ID namespace" \
  "none.*reserved for empty lists" "$REPO_ROOT/templates/agents-dir/ledger.md"
assert_grep "graph: ledger docs define atomic repeatable path fields" \
  "one atomic path; repeat the field" "$REPO_ROOT/templates/agents-dir/ledger.md"
assert_grep "graph: ledger docs preserve commas inside paths" \
  "commas and spaces are preserved" "$REPO_ROOT/templates/agents-dir/ledger.md"
assert_not_grep "graph: ledger docs contain no removed reads field" \
  "^- reads:" "$REPO_ROOT/templates/agents-dir/ledger.md"
assert_not_grep "graph: ledger docs contain no removed writes field" \
  "^- writes:" "$REPO_ROOT/templates/agents-dir/ledger.md"

git -C "$FIXTURE" init -q
cat > "$FIXTURE/package.json" <<'EOF'
{
  "name": "fixture",
  "version": "1.0.0",
  "scripts": {
    "test": "echo tests-ok",
    "build": "echo build-ok"
  }
}
EOF

# One 400-line file generated via loop.
: > "$FIXTURE/big.js"
for i in $(seq 1 400); do
  echo "console.log('line $i');" >> "$FIXTURE/big.js"
done

# A queue consumer with a retry wrapper: fires the idempotency gate and nothing
# else. Paired with the absence of any .jsx/.tsx/.vue/.svelte file, this makes one
# fixture prove the discrimination that matters — the same run fires one lens and
# withholds the other. A gate that always fires is not a gate.
mkdir -p "$FIXTURE/workers"
cat > "$FIXTURE/workers/consumer.js" <<'EOF'
// consumes from the job queue; retries on failure
export function handleMessage(msg, retry) {
  return retry(() => insertRow(msg), { backoff: 200 });
}
EOF

# A file containing TODO.
cat > "$FIXTURE/notes.js" <<'EOF'
// TODO: fix this later
function noop() {}
EOF

# A planted duplication: same block, same basename, in two directories. Exercises
# both duplication-candidate branches (shared basename, and >60% shared lines
# among the largest files) — the script's most intricate logic, and otherwise
# never run by Ultraharness.
mkdir -p "$FIXTURE/alpha" "$FIXTURE/beta"
: > "$FIXTURE/alpha/dup.js"
for i in $(seq 1 80); do
  echo "export const dupValue$i = $i;" >> "$FIXTURE/alpha/dup.js"
done
cp "$FIXTURE/alpha/dup.js" "$FIXTURE/beta/dup.js"

# Two duplicated basenames where one is a regex that matches the other: "a.b.js"
# as a pattern also matches "axb.js". Proves the basename lookup compares fields
# literally instead of interpreting the name.
echo "export const x = 1;" > "$FIXTURE/alpha/a.b.js"
cp "$FIXTURE/alpha/a.b.js" "$FIXTURE/beta/a.b.js"
echo "export const y = 2;" > "$FIXTURE/alpha/axb.js"
cp "$FIXTURE/alpha/axb.js" "$FIXTURE/beta/axb.js"

# Two more duplicated basenames differing in case class: C collation sorts
# uppercase before lowercase ("Zeta" < "apple"), en_US.UTF-8 collation does not.
# Without a pair like this the locale assertion below passes on a fixture that
# never exercises the difference — a green test proving nothing.
echo "export const z = 3;" > "$FIXTURE/alpha/Zeta.js"
cp "$FIXTURE/alpha/Zeta.js" "$FIXTURE/beta/Zeta.js"
echo "export const a = 4;" > "$FIXTURE/alpha/apple.js"
cp "$FIXTURE/alpha/apple.js" "$FIXTURE/beta/apple.js"

# A seeded Ultraharness footprint. Per AGENTS.md it is Ultraharness's own output and is
# never evidence about the target, so no counted section may quote it. Sized and
# shaped to break every one of them if it leaks: long enough to top "largest files",
# 600 TODOs against the fixture's 1, and a basename shared with the root adapter so
# it would surface as a duplication candidate too. Only the "agents dir:" line, whose
# whole job is to report presence, may mention it.
mkdir -p "$FIXTURE/.agents"
: > "$FIXTURE/.agents/AGENTS.md"
for i in $(seq 1 600); do
  echo "seeded line $i — TODO: Ultraharness output, not repo evidence" >> "$FIXTURE/.agents/AGENTS.md"
done
printf '<!-- ultraharness:begin -->\nSee .agents/AGENTS.md\n<!-- ultraharness:end -->\n' > "$FIXTURE/AGENTS.md"

git -C "$FIXTURE" add -A
git -C "$FIXTURE" -c user.name=fixture -c user.email=fixture@example.com \
  commit -qm "fixture commit"

# --- run audit-checks.sh on the fixture ---
OUT="$FIXTURE.out"
set +e
bash "$AUDIT" "$FIXTURE" > "$OUT" 2>&1
RC=$?
set -e

if [ "$RC" -eq 0 ]; then pass "exit code 0 on valid target"; else fail "exit code 0 on valid target (got $RC)"; fi
# Full header shape, so it cannot drift away from what audit.md's readiness probe
# requires: "audit-checks v<version> — target: <absolute path>" on the first line.
HEADER="$(head -1 "$OUT")"
case "$HEADER" in
  "audit-checks v"*" — target: /"*) pass "header shape: audit-checks v<version> — target: <abs path>" ;;
  *) fail "header shape: audit-checks v<version> — target: <abs path> (got: $HEADER)" ;;
esac
assert_grep "detected: node present"          "detected: node" "$OUT"
assert_grep "largest files lists big.js"      "big.js" "$OUT"
assert_grep "duplication: shared basename caught" "shared basename 'dup.js'" "$OUT"
assert_grep "duplication: shared lines caught"    "shared lines: .*dup\.js" "$OUT"
# Both paths must be listed — a regex-interpreted basename would drop or mis-collect
# them, and audit.md quotes this report verbatim as fact.
if grep -qxF "  shared basename 'a.b.js': alpha/a.b.js beta/a.b.js " "$OUT"; then
  pass "duplication: regex-metachar basename listed literally"
else
  fail "duplication: regex-metachar basename listed literally (got: $(grep -F "a.b.js':" "$OUT" || echo none))"
fi

# todo/fixme count >= 1
TODO_COUNT="$(grep 'todo/fixme markers:' "$OUT" | sed 's/[^0-9]*\([0-9][0-9]*\).*/\1/' || true)"
if [ -n "$TODO_COUNT" ] && [ "$TODO_COUNT" -ge 1 ]; then
  pass "todo/fixme markers count >= 1 (got $TODO_COUNT)"
else
  fail "todo/fixme markers count >= 1 (got '${TODO_COUNT:-none}')"
fi

# --- gauges: one machine-comparable line of repo-level counts ---
# Pinned values are the fixture's known answers: big.js is the largest authored
# file at 400 lines, the fixture's own code carries exactly 1 TODO (the footprint's
# 600 are excluded), and it has no test files. The counts that grow with the
# fixture are asserted present, not pinned.
assert_grep "gauges: line present with pinned fixture values" \
  "^gauges: files=[0-9][0-9]* loc=[0-9][0-9]* largest=400 todos=1 dup-candidates=[0-9][0-9]* test-files=0$" "$OUT"

# --- footprint: .agents/ is Ultraharness's output, never the target's evidence ---
# The counted sections must not quote it. Asserting on the path rather than on a
# count keeps this honest as the fixture grows: "agents dir:" prints a bare
# ".agents/", so the full path appearing anywhere means a counted section leaked it.
assert_not_grep "footprint: .agents/ absent from every counted section" \
  "\.agents/AGENTS\.md" "$OUT"
# The count itself, so a leak that somehow avoids printing the path still fails: the
# footprint carries 600 TODOs and the fixture's own code carries exactly 1.
assert_grep "footprint: todo count is the target's alone" \
  "^todo/fixme markers: 1 " "$OUT"
# ...while presence reporting, which is the one line allowed to mention it, still works.
assert_grep "footprint: presence still reported" \
  "^agents dir: \.agents/ present" "$OUT"

# --- gates: fires one lens, withholds the other, on the same repo ---
assert_grep "gates: idempotency FIRED on the queue consumer" \
  "^gates: idempotency FIRED" "$OUT"
# Anchored to the gates line, not loose in the report: the path also appears in the
# inventory and largest-files sections, so an unanchored pattern passes whether or
# not the gate ever cited anything.
assert_grep "gates: idempotency evidence names the consumer" \
  "^gates: idempotency FIRED.*workers/consumer\.js" "$OUT"
# The assertion that makes the other two mean something: same run, same repo, the
# other gate declined. Without this, a gate hardwired to fire would pass.
assert_grep "gates: atomic withheld on a repo with no component UI" \
  "^gates: atomic not-fired$" "$OUT"
assert_grep "gates: a11y withheld on a repo with no UI markup" \
  "^gates: a11y not-fired$" "$OUT"
assert_grep "gates: security withheld on a repo with no routes or handlers" \
  "^gates: security not-fired$" "$OUT"

# --- gates, the other directions: a second repo that fires atomic, a11y, and
# security while idempotency withholds. One fixture can only ever show each gate in
# one direction, and README.md states the rule as "a fixture it fires on AND a
# fixture it withholds from" — for EVERY gate, not one each. Without this, deleting
# the .tsx branch from the atomic gate passes the whole suite.
FIXTURE2="$FIXTURE.ui"
mkdir -p "$FIXTURE2/src/components"
git -C "$FIXTURE2" init -q
cat > "$FIXTURE2/package.json" <<'EOF'
{ "name": "ui-fixture", "version": "1.0.0", "scripts": { "test": "echo tests-ok" } }
EOF
# Deliberately free of retry/queue/webhook/cron/scheduler/migration/deploy/.sql
# vocabulary, so idempotency has nothing to fire on. Keep it that way.
cat > "$FIXTURE2/src/components/Button.tsx" <<'EOF'
export function Button({ label }: { label: string }) {
  return <button>{label}</button>;
}
EOF
# A mutating route with request data concatenated into SQL: fires the security
# gate. Kept free of the idempotency vocabulary above so that gate still has
# nothing to fire on — this fixture must show security firing while idempotency
# withholds, on the same run.
cat > "$FIXTURE2/src/server.js" <<'EOF'
const app = express();
app.post('/items', (req, res) => {
  db.run("INSERT INTO items (name) VALUES ('" + req.body.name + "')");
  res.send('ok');
});
EOF
git -C "$FIXTURE2" add -A
git -C "$FIXTURE2" -c user.name=fixture -c user.email=fixture@example.com \
  commit -qm "ui fixture"
OUT2="$FIXTURE.out.ui"
# Guarded, like every other invocation here. Unguarded under `set -e`, a nonzero exit
# from audit-checks.sh kills this script outright: the run stops mid-suite, every
# assertion below never executes, and no summary line prints. A suite that aborts
# reports nothing — which reads far more like "finished" than a FAIL does.
set +e
bash "$AUDIT" "$FIXTURE2" > "$OUT2" 2>&1; RC_UI=$?
set -e
if [ "$RC_UI" -eq 0 ]; then
  pass "exit code 0 on the component-UI fixture"
else
  fail "exit code 0 on the component-UI fixture (got $RC_UI)"
fi
assert_grep "gates: atomic FIRED on a component-UI repo" \
  "^gates: atomic FIRED" "$OUT2"
assert_grep "gates: atomic evidence names the component" \
  "^gates: atomic FIRED.*Button\.tsx" "$OUT2"
assert_grep "gates: idempotency withheld on a repo with no queue or retry" \
  "^gates: idempotency not-fired$" "$OUT2"
assert_grep "gates: a11y FIRED on component markup" \
  "^gates: a11y FIRED" "$OUT2"
assert_grep "gates: a11y evidence names the component" \
  "^gates: a11y FIRED.*Button\.tsx" "$OUT2"
assert_grep "gates: security FIRED on the mutating route" \
  "^gates: security FIRED" "$OUT2"
assert_grep "gates: security evidence names the server" \
  "^gates: security FIRED.*src/server\.js" "$OUT2"

# --- determinism: one tree, two locales, byte-identical facts ---
# The header calls this script a deterministic fact collector, and audit.md quotes
# its output verbatim as fact. Determinism therefore has to hold across machines,
# not just across two runs in one shell — two runs here would share a locale and
# pass while collation-dependent output is live. Hence two explicit locales.
# Captured, not piped: `locale -a | grep -q` dies to SIGPIPE under `set -o pipefail`
# (grep exits on the first match before locale finishes writing), which reports the
# locale as missing on a machine that has it — the check would skip itself forever.
LOCALES="$(locale -a 2>/dev/null || true)"
# glibc spells it en_US.utf8, BSD/macOS en_US.UTF-8 — accept either and run the
# check under the exact name this machine advertises, so neither platform skips.
case "$LOCALES" in
  *en_US.UTF-8*) UTF8_LOCALE=en_US.UTF-8 ;;
  *en_US.utf8*)  UTF8_LOCALE=en_US.utf8 ;;
  *)             UTF8_LOCALE= ;;
esac
if [ -n "$UTF8_LOCALE" ]; then
  OUT_C="$FIXTURE.out.c"
  OUT_U="$FIXTURE.out.utf8"
  set +e
  LC_ALL=C              bash "$AUDIT" "$FIXTURE" > "$OUT_C" 2>&1; RC_C=$?
  LC_ALL="$UTF8_LOCALE" bash "$AUDIT" "$FIXTURE" > "$OUT_U" 2>&1; RC_U=$?
  set -e
  # Exit status first. Swallowing both with `|| true` and comparing only the bytes
  # let this assertion pass on a script that died early under BOTH locales — two
  # identical error messages compare equal. A crash is not determinism.
  if [ "$RC_C" -ne 0 ] || [ "$RC_U" -ne 0 ]; then
    fail "determinism: both locale runs exit 0 (C=$RC_C utf8=$RC_U)"
  # Compared against $OUT, the known-good run every assertion above was made against,
  # not just against each other: two runs that agree with each other but not with that
  # report are still a regression.
  elif ! cmp -s "$OUT" "$OUT_C"; then
    fail "determinism: C-locale run differs from the verified report (first diff: $(diff "$OUT" "$OUT_C" | head -4 | tr '\n' ' '))"
  elif cmp -s "$OUT_C" "$OUT_U"; then
    pass "determinism: identical output under C and $UTF8_LOCALE"
  else
    fail "determinism: identical output under C and $UTF8_LOCALE (first diff: $(diff "$OUT_C" "$OUT_U" | head -4 | tr '\n' ' '))"
  fi
else
  # Not a pass. An assertion that did not run has no result, and saying so is the
  # whole point of the check.
  printf 'SKIP: %s\n' "determinism: no en_US UTF-8 locale available on this machine"
fi

# --- nonexistent path exits 2 ---
set +e
bash "$AUDIT" "$FIXTURE/does-not-exist" > /dev/null 2>&1
RC2=$?
set -e
if [ "$RC2" -eq 2 ]; then pass "nonexistent path exits 2"; else fail "nonexistent path exits 2 (got $RC2)"; fi

# --- smoke-check.sh: optional browser evidence ---
# The optionality contract is the tested thing: absence must be a printed fact and a
# distinct exit code on every machine, browser or not. The live path runs only when a
# binary is supplied — the locale check's SKIP precedent, for the same reason.
SMOKE="$SCRIPT_DIR/smoke-check.sh"
set +e
bash "$SMOKE" > /dev/null 2>&1; RC_SU=$?
set -e
if [ "$RC_SU" -eq 2 ]; then pass "smoke: no url exits 2"; else fail "smoke: no url exits 2 (got $RC_SU)"; fi
OUT_SM="$FIXTURE.out.smoke"
set +e
LIGHTPANDA_BIN=/nonexistent bash "$SMOKE" "http://127.0.0.1:1/" > "$OUT_SM" 2>&1; RC_SA=$?
set -e
if [ "$RC_SA" -eq 3 ]; then pass "smoke: missing browser exits 3"; else fail "smoke: missing browser exits 3 (got $RC_SA)"; fi
assert_grep "smoke: absence is a printed fact, not an error" "^browser: unavailable" "$OUT_SM"

SMOKE_BIN="${LIGHTPANDA_BIN:-$(command -v lightpanda || true)}"
if [ -n "$SMOKE_BIN" ] && [ -x "$SMOKE_BIN" ] && command -v python3 > /dev/null 2>&1; then
  WEB="$FIXTURE.web"
  mkdir -p "$WEB"
  printf '<html><head><title>smoke-fixture</title></head><body>smoke-marker-7f3a</body></html>' > "$WEB/index.html"
  # -u so the "Serving HTTP ... port N" line is unbuffered; port 0 = OS-assigned.
  (cd "$WEB" && python3 -u -m http.server 0 --bind 127.0.0.1 > "$WEB/server.log" 2>&1 & echo $! > "$WEB/pid")
  PORT=""
  for _ in $(seq 1 20); do
    PORT="$(sed -n 's/.*port \([0-9][0-9]*\).*/\1/p' "$WEB/server.log" | head -1)"
    [ -n "$PORT" ] && break
    sleep 0.25
  done
  if [ -z "$PORT" ]; then
    fail "smoke live: local http server never came up"
  else
    OUT_SL="$FIXTURE.out.smokelive"
    set +e
    bash "$SMOKE" "http://127.0.0.1:$PORT/" --expect smoke-marker-7f3a > "$OUT_SL" 2>&1; RC_SL=$?
    set -e
    if [ "$RC_SL" -eq 0 ]; then pass "smoke live: exit 0 on served fixture"; else fail "smoke live: exit 0 on served fixture (got $RC_SL — $(tail -2 "$OUT_SL" | tr '\n' ' '))"; fi
    assert_grep "smoke live: title fact printed" "^title: smoke-fixture" "$OUT_SL"
    assert_grep "smoke live: expect found" "^expect 'smoke-marker-7f3a': found" "$OUT_SL"
    set +e
    bash "$SMOKE" "http://127.0.0.1:$PORT/" --expect not-on-this-page > "$OUT_SL.miss" 2>&1; RC_SM2=$?
    set -e
    if [ "$RC_SM2" -eq 5 ]; then pass "smoke live: missing expect exits 5"; else fail "smoke live: missing expect exits 5 (got $RC_SM2)"; fi
    assert_grep "smoke live: NOT FOUND printed" "NOT FOUND" "$OUT_SL.miss"
  fi
  kill "$(cat "$WEB/pid")" 2>/dev/null || true
else
  printf 'SKIP: %s\n' "smoke live path: no browser supplied (set LIGHTPANDA_BIN to run it)"
fi

echo
if [ "$FAILS" -eq 0 ]; then
  echo "all assertions passed"
  exit 0
else
  echo "$FAILS assertion(s) failed"
  exit 1
fi
