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
trap 'rm -rf "$FIXTURE"' EXIT

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
assert_grep "header contains audit-checks v1" "audit-checks v1" "$OUT"
assert_grep "detected: node present"          "detected: node" "$OUT"
assert_grep "largest files lists big.js"      "big.js" "$OUT"
assert_grep "duplication: shared basename caught" "shared basename 'dup.js'" "$OUT"
assert_grep "duplication: shared lines caught"    "shared lines: .*dup\.js" "$OUT"

# todo/fixme count >= 1
TODO_COUNT="$(grep 'todo/fixme markers:' "$OUT" | sed 's/[^0-9]*\([0-9][0-9]*\).*/\1/' || true)"
if [ -n "$TODO_COUNT" ] && [ "$TODO_COUNT" -ge 1 ]; then
  pass "todo/fixme markers count >= 1 (got $TODO_COUNT)"
else
  fail "todo/fixme markers count >= 1 (got '${TODO_COUNT:-none}')"
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
