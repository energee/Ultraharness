#!/usr/bin/env bash
# test.sh — bash test harness for scripts/audit-checks.sh.
# Builds a throwaway fixture repo in a temp dir, runs audit-checks.sh against it,
# and asserts on the printed facts with grep. Prints PASS/FAIL per assertion and
# exits nonzero if any assertion fails. No dependencies beyond git + coreutils.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="$SCRIPT_DIR/audit-checks.sh"

FAILS=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; FAILS=$((FAILS + 1)); }

assert_grep() {
  # assert_grep <description> <pattern> <file>
  if grep -q "$2" "$3"; then pass "$1"; else fail "$1 (pattern not found: $2)"; fi
}

# --- fixture repo ---
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE" "$FIXTURE".out*' EXIT

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
# never run by this harness.
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

# --- determinism: one tree, two locales, byte-identical facts ---
# The header calls this script a deterministic fact collector, and audit.md quotes
# its output verbatim as fact. Determinism therefore has to hold across machines,
# not just across two runs in one shell — two runs here would share a locale and
# pass while collation-dependent output is live. Hence two explicit locales.
# Captured, not piped: `locale -a | grep -q` dies to SIGPIPE under `set -o pipefail`
# (grep exits on the first match before locale finishes writing), which reports the
# locale as missing on a machine that has it — the check would skip itself forever.
LOCALES="$(locale -a 2>/dev/null || true)"
case "$LOCALES" in
  *en_US.UTF-8*) HAVE_UTF8=yes ;;
  *)             HAVE_UTF8=no ;;
esac
if [ "$HAVE_UTF8" = yes ]; then
  OUT_C="$FIXTURE.out.c"
  OUT_U="$FIXTURE.out.utf8"
  LC_ALL=C            bash "$AUDIT" "$FIXTURE" > "$OUT_C" 2>&1 || true
  LC_ALL=en_US.UTF-8  bash "$AUDIT" "$FIXTURE" > "$OUT_U" 2>&1 || true
  if cmp -s "$OUT_C" "$OUT_U"; then
    pass "determinism: identical output under C and en_US.UTF-8"
  else
    fail "determinism: identical output under C and en_US.UTF-8 (first diff: $(diff "$OUT_C" "$OUT_U" | head -4 | tr '\n' ' '))"
  fi
else
  # Not a pass. An assertion that did not run has no result, and saying so is the
  # whole point of the check.
  printf 'SKIP: %s\n' "determinism: en_US.UTF-8 locale unavailable on this machine"
fi

# --- nonexistent path exits 2 ---
set +e
bash "$AUDIT" "$FIXTURE/does-not-exist" > /dev/null 2>&1
RC2=$?
set -e
if [ "$RC2" -eq 2 ]; then pass "nonexistent path exits 2"; else fail "nonexistent path exits 2 (got $RC2)"; fi

echo
if [ "$FAILS" -eq 0 ]; then
  echo "all assertions passed"
  exit 0
else
  echo "$FAILS assertion(s) failed"
  exit 1
fi
