#!/usr/bin/env bash
# test.sh — bash test harness for scripts/audit-checks.sh, plus the rubric sync
# tripwire pinning full-form rubrics to their condensed twins.
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
check_sync lenses/atomic-design.md  033a38bfb0b266577cf2cf30fc33b2c13a283f1c25ece79ce135d6c5e6f8451f
check_sync lenses/idempotency.md    f6cc63250e4ab2e5c9fb9d21ae4e1a9bc1c1800b4697c5df13d9022c80223948
check_sync lenses/security-boundary.md  b978e51f5166f1ff0aff924c1f29112d7144ec992f2cb0842832b4f0cce7ae37
check_sync templates/agents-dir/principles.md            e5777b57c21c05d0aa55a62c16a1f4f4a7fb6160c7672e0956325e54102980d8
check_sync templates/agents-dir/lenses/a11y.md           58767016c3c2de6ddc9097167611108b2b61d2e7b020a50437086d6a14271189
check_sync templates/agents-dir/lenses/atomic-design.md  40f7e65a40d11872f0e599c638c84556dad1f2510690daa3503e6ae87c80f686
check_sync templates/agents-dir/lenses/idempotency.md    23b55a5b1c6b1fe94825816dc1541a16057d63ad4765ef7670e2f264e2647e68
check_sync templates/agents-dir/lenses/security-boundary.md  c6126465c617e589ddfa885416386e01fcc1c35c1e62040d9bb0c2020db042a6

# --- fixture repo ---
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE" "$FIXTURE".out* "$FIXTURE".ui' EXIT

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

# A seeded harness footprint. Per AGENTS.md it is this harness's own output and is
# never evidence about the target, so no counted section may quote it. Sized and
# shaped to break every one of them if it leaks: long enough to top "largest files",
# 600 TODOs against the fixture's 1, and a basename shared with the root adapter so
# it would surface as a duplication candidate too. Only the "agents dir:" line, whose
# whole job is to report presence, may mention it.
mkdir -p "$FIXTURE/.agents"
: > "$FIXTURE/.agents/AGENTS.md"
for i in $(seq 1 600); do
  echo "seeded line $i — TODO: harness output, not repo evidence" >> "$FIXTURE/.agents/AGENTS.md"
done
printf '<!-- harness:begin -->\nSee .agents/AGENTS.md\n<!-- harness:end -->\n' > "$FIXTURE/AGENTS.md"

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

# --- footprint: .agents/ is the harness's output, never the target's evidence ---
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
case "$LOCALES" in
  *en_US.UTF-8*) HAVE_UTF8=yes ;;
  *)             HAVE_UTF8=no ;;
esac
if [ "$HAVE_UTF8" = yes ]; then
  OUT_C="$FIXTURE.out.c"
  OUT_U="$FIXTURE.out.utf8"
  set +e
  LC_ALL=C            bash "$AUDIT" "$FIXTURE" > "$OUT_C" 2>&1; RC_C=$?
  LC_ALL=en_US.UTF-8  bash "$AUDIT" "$FIXTURE" > "$OUT_U" 2>&1; RC_U=$?
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
