#!/usr/bin/env bash
# audit-checks.sh — deterministic repo fact collector for playbooks/audit.md.
# Prints FACTS about a target repo (never scores, never judgments); the audit
# playbook quotes this output verbatim. bash + git + coreutils only; runs on
# macOS (BSD toolchain) and Linux. Usage: audit-checks.sh <target-path>.
# Exit 0 on success, exit 2 on invalid target path.
set -euo pipefail

# Byte-order collation, forced, for every sort and comparison below. audit.md quotes
# this report verbatim as fact, so the same tree must produce the same bytes on any
# machine — and collation under a UTF-8 locale orders "Zeta" after "apple" where C
# orders it before. Set once here rather than per-call so a sort added later inherits
# it. scripts/test.sh asserts this by running the script under two locales and
# comparing output byte for byte.
export LC_ALL=C

SCRIPT_VERSION="v3 (2026-07-29)"

TARGET="${1:-}"
if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "audit-checks: invalid target path: '${TARGET}'" >&2
  exit 2
fi
TARGET="$(cd "$TARGET" && pwd)"

# ---------------------------------------------------------------------------
# File inventory: tracked files if a git repo, otherwise a find(1) sweep.
# Lockfiles and vendored/generated dirs are excluded from size/loc/marker
# sections so the facts reflect authored code.
# ---------------------------------------------------------------------------
IS_GIT_REPO=no
if git -C "$TARGET" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  IS_GIT_REPO=yes
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ALL_FILES="$TMP/all-files"       # every inventoried file (relative paths)
CODE_FILES="$TMP/code-files"     # inventory minus lockfiles/vendored dirs

if [ "$IS_GIT_REPO" = yes ]; then
  git -C "$TARGET" ls-files > "$ALL_FILES" || true
else
  (cd "$TARGET" && find . -type f -not -path './.git/*' | sed 's|^\./||') > "$ALL_FILES" || true
fi

grep -Ev '(^|/)(node_modules|vendor|dist|build|target|\.next|__pycache__|\.venv|venv)/' "$ALL_FILES" \
  | grep -Ev '(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|poetry\.lock|uv\.lock|Gemfile\.lock|composer\.lock|go\.sum)$' \
  | grep -Ev '(^|/)\.agents/' \
  > "$CODE_FILES" || true

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
echo "audit-checks $SCRIPT_VERSION — target: $TARGET"

# ---------------------------------------------------------------------------
# detected: ecosystem, from manifest evidence only
# ---------------------------------------------------------------------------
EVIDENCE=""
LANGS=""
[ -f "$TARGET/package.json" ]   && { LANGS="$LANGS node";   EVIDENCE="$EVIDENCE package.json"; }
[ -f "$TARGET/pyproject.toml" ] && { LANGS="$LANGS python"; EVIDENCE="$EVIDENCE pyproject.toml"; }
[ -f "$TARGET/go.mod" ]         && { LANGS="$LANGS go";     EVIDENCE="$EVIDENCE go.mod"; }
[ -f "$TARGET/Cargo.toml" ]     && { LANGS="$LANGS rust";   EVIDENCE="$EVIDENCE Cargo.toml"; }

LANG_COUNT="$(echo "$LANGS" | wc -w | tr -d ' ')"
if [ "$LANG_COUNT" -eq 0 ]; then
  echo "detected: unknown (evidence: none of package.json, pyproject.toml, go.mod, Cargo.toml)"
elif [ "$LANG_COUNT" -eq 1 ]; then
  echo "detected:$LANGS (evidence:$(echo "$EVIDENCE" | sed 's/^ //' | sed 's/^/ /'))"
else
  echo "detected: mixed (evidence:$(echo "$EVIDENCE" | sed 's/ /, /g' | sed 's/^, / /'))"
fi

# ---------------------------------------------------------------------------
# commands: discovered (never run)
# ---------------------------------------------------------------------------
BUILD_CMD="none found"
TEST_CMD="none found"
TYPECHECK_CMD="none found"
if [ -f "$TARGET/package.json" ]; then
  # Best-effort script discovery without jq: look for "<name>": inside the file.
  grep -q '"build"[[:space:]]*:' "$TARGET/package.json" && BUILD_CMD="npm run build" || true
  grep -q '"test"[[:space:]]*:' "$TARGET/package.json" && TEST_CMD="npm test" || true
  grep -q '"typecheck"[[:space:]]*:' "$TARGET/package.json" && TYPECHECK_CMD="npm run typecheck" || true
  if [ "$TYPECHECK_CMD" = "none found" ] && [ -f "$TARGET/tsconfig.json" ]; then
    TYPECHECK_CMD="tsc --noEmit"
  fi
fi
if [ -f "$TARGET/go.mod" ]; then
  [ "$BUILD_CMD" = "none found" ] && BUILD_CMD="go build ./..." || true
  [ "$TEST_CMD" = "none found" ] && TEST_CMD="go test ./..." || true
  [ "$TYPECHECK_CMD" = "none found" ] && TYPECHECK_CMD="go vet ./..." || true
fi
if [ -f "$TARGET/Cargo.toml" ]; then
  [ "$BUILD_CMD" = "none found" ] && BUILD_CMD="cargo build" || true
  [ "$TEST_CMD" = "none found" ] && TEST_CMD="cargo test" || true
  [ "$TYPECHECK_CMD" = "none found" ] && TYPECHECK_CMD="cargo check" || true
fi
if [ -f "$TARGET/pyproject.toml" ]; then
  if [ "$TEST_CMD" = "none found" ] && grep -q 'pytest' "$TARGET/pyproject.toml"; then
    TEST_CMD="pytest"
  fi
  if [ "$TYPECHECK_CMD" = "none found" ] && grep -q 'mypy' "$TARGET/pyproject.toml"; then
    TYPECHECK_CMD="mypy ."
  fi
fi
if [ "$TEST_CMD" = "none found" ] && [ -f "$TARGET/Makefile" ] && grep -q '^test:' "$TARGET/Makefile"; then
  TEST_CMD="make test"
fi
if [ "$BUILD_CMD" = "none found" ] && [ -f "$TARGET/Makefile" ] && grep -q '^build:' "$TARGET/Makefile"; then
  BUILD_CMD="make build"
fi
echo "commands: build=$BUILD_CMD test=$TEST_CMD typecheck=$TYPECHECK_CMD   # discovered, NOT run"

# ---------------------------------------------------------------------------
# git: commit count, contributors, last commit date
# ---------------------------------------------------------------------------
if [ "$IS_GIT_REPO" = yes ]; then
  COMMIT_COUNT="$(git -C "$TARGET" rev-list --count HEAD 2>/dev/null || echo 0)"
  if [ "$COMMIT_COUNT" -gt 0 ]; then
    CONTRIBUTORS="$(git -C "$TARGET" log --format='%ae' 2>/dev/null | sort -u | wc -l | tr -d ' ' || echo 0)"
    LAST_COMMIT="$(git -C "$TARGET" log -1 --format='%as' 2>/dev/null || echo unknown)"
    echo "git: $COMMIT_COUNT commits, $CONTRIBUTORS contributors, last commit $LAST_COMMIT"
  else
    echo "git: 0 commits, 0 contributors, last commit none"
  fi
else
  echo "git: not a git repository"
fi

# ---------------------------------------------------------------------------
# size: file count and total loc (excluding lockfiles/vendored dirs)
# ---------------------------------------------------------------------------
FILE_COUNT="$(wc -l < "$CODE_FILES" | tr -d ' ')"
TOTAL_LOC=0
if [ "$FILE_COUNT" -gt 0 ]; then
  # Sum per-file counts, skipping wc's per-batch "total" lines: xargs may split
  # a large file list into multiple wc invocations, so tail -1 would capture
  # only the last batch's total and silently undercount.
  TOTAL_LOC="$(cd "$TARGET" && tr '\n' '\0' < "$CODE_FILES" \
    | xargs -0 wc -l 2>/dev/null | awk '$2 != "total" {s+=$1} END {print s+0}' || echo 0)"
fi
echo "size: $FILE_COUNT files, $TOTAL_LOC lines (excluding lockfiles/vendored dirs)"

# ---------------------------------------------------------------------------
# largest files: top 10 by line count
# ---------------------------------------------------------------------------
echo "largest files: top 10 by line count"
LARGEST_LOC=0
if [ "$FILE_COUNT" -gt 0 ]; then
  # Sorted per-file counts, kept for reuse: the top-10 print here, the top-20
  # duplication scan, and the gauges line all read the same list.
  (cd "$TARGET" && tr '\n' '\0' < "$CODE_FILES" \
    | xargs -0 wc -l 2>/dev/null | grep -v ' total$' | sort -k1,1rn -k2) > "$TMP/wc-sorted" || true
  head -10 "$TMP/wc-sorted" \
    | awk '{ lines=$1; $1=""; sub(/^ /,""); printf "  %s lines  %s\n", lines, $0 }' || true
  LARGEST_LOC="$(head -1 "$TMP/wc-sorted" | awk '{ print $1 + 0 }')"
else
  echo "  (no files inventoried)"
fi

# ---------------------------------------------------------------------------
# longest functions: honest cap in v1 — printed so nothing is silently dropped
# ---------------------------------------------------------------------------
echo "longest functions: skipped in v1 (language-specific)"

# ---------------------------------------------------------------------------
# todo/fixme markers: count + top 10 locations
# ---------------------------------------------------------------------------
TODO_HITS="$TMP/todo-hits"
if [ "$FILE_COUNT" -gt 0 ]; then
  (cd "$TARGET" && tr '\n' '\0' < "$CODE_FILES" \
    | xargs -0 grep -HIn -E 'TODO|FIXME' 2>/dev/null) > "$TODO_HITS" || true
else
  : > "$TODO_HITS"
fi
TODO_COUNT="$(wc -l < "$TODO_HITS" | tr -d ' ')"
echo "todo/fixme markers: $TODO_COUNT (top 10 locations)"
head -10 "$TODO_HITS" | awk -F: '{ printf "  %s:%s\n", $1, $2 }' || true

# ---------------------------------------------------------------------------
# duplication candidates: best-effort, never certainty.
#   (a) files sharing a basename
#   (b) pairs of the 20 largest files with >60% identical normalized lines
# ---------------------------------------------------------------------------
echo 'duplication candidates (candidates — verify before acting): top 10'
DUP_OUT="$TMP/dup-out"
: > "$DUP_OUT"

# (a) shared basenames (ignoring common repo-metadata names)
awk -F/ '{ print $NF "\t" $0 }' "$CODE_FILES" \
  | grep -Ev '^(README\.md|__init__\.py|index\.js|index\.ts|mod\.rs|Makefile|\.gitignore|\.gitkeep)\t' \
  | sort > "$TMP/basenames" || true
cut -f1 "$TMP/basenames" | uniq -d > "$TMP/dup-names" || true
while IFS= read -r name; do
  # awk field match, not grep: a basename can contain regex metacharacters, and
  # grep would interpret them — "a.b.js" as a pattern also matches "axb.js", so a
  # grep lookup emits paths that do not share the basename. audit.md quotes this
  # report verbatim as fact, so a wrong path here becomes a wrong fact in a report.
  PATHS="$(awk -F'\t' -v n="$name" '$1 == n { print $2 }' "$TMP/basenames" | tr '\n' ' ' || true)"
  echo "  shared basename '$name': $PATHS" >> "$DUP_OUT"
done < "$TMP/dup-names"

# (b) normalized-line overlap among the 20 largest files (bounded pairwise scan)
if [ "$FILE_COUNT" -gt 1 ]; then
  head -20 "$TMP/wc-sorted" | awk '{ $1=""; sub(/^ /,""); print }' > "$TMP/top-files" || true
  i=0
  while IFS= read -r f; do
    i=$((i + 1))
    # normalize: strip leading/trailing whitespace, drop blank lines, sort unique
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$TARGET/$f" 2>/dev/null \
      | grep -v '^$' | sort -u > "$TMP/norm.$i" || true
    echo "$f" > "$TMP/name.$i"
  done < "$TMP/top-files"
  N=$i
  a=1
  while [ "$a" -lt "$N" ]; do
    b=$((a + 1))
    while [ "$b" -le "$N" ]; do
      LA="$(wc -l < "$TMP/norm.$a" | tr -d ' ')"
      LB="$(wc -l < "$TMP/norm.$b" | tr -d ' ')"
      SMALL=$(( LA < LB ? LA : LB ))
      if [ "$SMALL" -gt 0 ]; then
        COMMON="$(comm -12 "$TMP/norm.$a" "$TMP/norm.$b" | wc -l | tr -d ' ')"
        PCT=$(( COMMON * 100 / SMALL ))
        if [ "$PCT" -gt 60 ]; then
          echo "  ~${PCT}% shared lines: $(cat "$TMP/name.$a") <-> $(cat "$TMP/name.$b")" >> "$DUP_OUT"
        fi
      fi
      b=$((b + 1))
    done
    a=$((a + 1))
  done
fi

if [ -s "$DUP_OUT" ]; then
  head -10 "$DUP_OUT"
else
  echo "  none found (best-effort scan)"
fi

# ---------------------------------------------------------------------------
# gauges: the same facts the sections above print, restated as one
# machine-comparable line in a fixed field order. An improve run records this
# line at its first audit and its last, so a trend across runs is a diff of two
# lines rather than a memory. Fields are only ever appended — renaming or
# reordering one breaks every recorded comparison.
# ---------------------------------------------------------------------------
DUP_COUNT="$(wc -l < "$DUP_OUT" | tr -d ' ')"
TEST_FILE_COUNT="$(grep -Ec '(^|/)(tests?|__tests__|spec)(/|$)|\.(test|spec)\.[^/]+$|_test\.[^/]+$|(^|/)test_[^/]+$' "$CODE_FILES" || true)"
echo "gauges: files=$FILE_COUNT loc=$TOTAL_LOC largest=$LARGEST_LOC todos=$TODO_COUNT dup-candidates=$DUP_COUNT test-files=$TEST_FILE_COUNT"

# ---------------------------------------------------------------------------
# teachability: can a newcomer (or agent) find their way in?
# ---------------------------------------------------------------------------
README_STATE=missing
{ [ -f "$TARGET/README.md" ] || [ -f "$TARGET/README" ] || [ -f "$TARGET/README.rst" ]; } && README_STATE=present
BUILD_DISC=no; [ "$BUILD_CMD" != "none found" ] && BUILD_DISC=yes
TEST_DISC=no;  [ "$TEST_CMD" != "none found" ] && TEST_DISC=yes
DOCS_STATE=missing
{ [ -f "$TARGET/CONTRIBUTING.md" ] || [ -d "$TARGET/docs" ]; } && DOCS_STATE=present
echo "teachability: README $README_STATE; build cmd discoverable $BUILD_DISC; test cmd discoverable $TEST_DISC; contributing/docs dir $DOCS_STATE"

# ---------------------------------------------------------------------------
# agents dir: facts only — never scored
# ---------------------------------------------------------------------------
AGENTS_STATE=missing; [ -d "$TARGET/.agents" ] && AGENTS_STATE=present
LEDGER_STATE=missing
{ [ -f "$TARGET/.agents/ledger.md" ] || [ -f "$TARGET/.agents/LEDGER.md" ] || [ -f "$TARGET/.agents/ledger" ]; } && LEDGER_STATE=present
echo "agents dir: .agents/ $AGENTS_STATE; ledger $LEDGER_STATE"

# ---------------------------------------------------------------------------
# gates: which conditional lenses apply (see <ultraharness>/lenses/). Repo *shape*,
# never a verdict on quality — the same class of fact as `detected:`. One line per
# lens, alphabetical, printed every run: "not-fired" is a fact, and a withheld
# lens must be distinguishable from a section that never ran.
#
# ponytail: four lenses, four hardcoded gates, ~8 lines each. An earlier note here
# said a third lens should read its patterns out of the lens files; that was wrong
# and is withdrawn: both lens docs promise "the patterns live in the script", and a
# markdown-parsed pattern line would move gating into prose, where a typo silently
# re-gates every repo. A fifth lens copies one of the shapes below.
# ---------------------------------------------------------------------------

# Gates judge the target's own *code*. CODE_FILES has already dropped Ultraharness
# footprint per the rule in AGENTS.md; these two exclusions go further, and they are
# why this belongs in a script rather than in prose:
#   CHANGELOG, docs/  — prose about the code, not the code
#   .md/.rst/.txt/.adoc — every lens gate already disclaims matches on the word
#                       "retry" in prose; excluding the extensions enforces that
#                       mechanically instead of asking for the judgement each run.
# A repo whose only queue evidence lives in documentation does not fire the gate.
# That is default-deny, and it is the safe direction: a missing lens is a smaller
# wrong than a lens seeded into a repo it does not describe.
GATE_FILES="$TMP/gate-files"
grep -Ev '(^|/)CHANGELOG|(^|/)docs/|\.(md|rst|txt|adoc)$' "$CODE_FILES" > "$GATE_FILES" || true

gate_report() {
  # gate_report <lens-slug> <hits-file>
  local N EV UNIT
  N="$(wc -l < "$2" | tr -d ' ')"
  if [ "$N" -gt 0 ]; then
    EV="$(head -3 "$2" | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g')"
    UNIT=hits; [ "$N" -eq 1 ] && UNIT=hit
    echo "gates: $1 FIRED ($N $UNIT; evidence: $EV)"
  else
    echo "gates: $1 not-fired"
  fi
}

# a11y: authored UI markup, by extension — component files plus common server
# templates. Generated/vendored output is already dropped from the inventory.
A11Y_HITS="$TMP/gate-a11y"
grep -Ei '\.(html|jsx|tsx|vue|svelte|erb|twig|haml)$|\.blade\.php$' "$GATE_FILES" > "$A11Y_HITS" || true
sort -u "$A11Y_HITS" -o "$A11Y_HITS"
gate_report a11y "$A11Y_HITS"

# atomic: component-UI file extensions, or a components dir *and* a framework
# import. Either half of the second condition alone is not enough.
ATOMIC_HITS="$TMP/gate-atomic"
: > "$ATOMIC_HITS"
grep -Ei '\.(jsx|tsx|vue|svelte)$' "$GATE_FILES" >> "$ATOMIC_HITS" || true
COMPONENT_PATHS="$(grep -Ei '(^|/)components?/' "$GATE_FILES" || true)"
if [ -n "$COMPONENT_PATHS" ]; then
  FRAMEWORK_HITS="$(cd "$TARGET" && tr '\n' '\0' < "$GATE_FILES" \
    | xargs -0 grep -lIE "from ['\"](react|vue|svelte|preact|solid-js|@angular/core)" 2>/dev/null || true)"
  [ -n "$FRAMEWORK_HITS" ] && printf '%s\n' "$COMPONENT_PATHS" >> "$ATOMIC_HITS"
fi
sort -u "$ATOMIC_HITS" -o "$ATOMIC_HITS"
gate_report atomic "$ATOMIC_HITS"

# idempotency: retry/queue/scheduler/webhook vocabulary in file contents, or
# migration/deploy/infra paths.
IDEM_HITS="$TMP/gate-idempotency"
: > "$IDEM_HITS"
if [ -s "$GATE_FILES" ]; then
  (cd "$TARGET" && tr '\n' '\0' < "$GATE_FILES" \
    | xargs -0 grep -lIEi 'retry|retries|backoff|idempotenc|celery|sidekiq|bullmq|resque|kafka|sqs|pubsub|amqp|rabbit|webhook|cron|scheduler' 2>/dev/null) >> "$IDEM_HITS" || true
fi
grep -Ei '(^|/)(migrations?|migrate|deploy|infra|terraform)(/|$)|\.sql$' "$GATE_FILES" >> "$IDEM_HITS" || true
sort -u "$IDEM_HITS" -o "$IDEM_HITS"
gate_report idempotency "$IDEM_HITS"

# security: route-registration / HTTP-handler vocabulary in file contents, or
# route/controller/middleware paths.
SEC_HITS="$TMP/gate-security"
: > "$SEC_HITS"
if [ -s "$GATE_FILES" ]; then
  (cd "$TARGET" && tr '\n' '\0' < "$GATE_FILES" \
    | xargs -0 grep -lIEi '(app|router)\.(get|post|put|patch|delete)\(|@(app|bp)\.route|urlpatterns|http\.handlefunc|@(get|post|put|delete|patch|request)mapping|createserver\(|express\(\)|fastify\(' 2>/dev/null) >> "$SEC_HITS" || true
fi
grep -Ei '(^|/)(routes?|controllers?|middleware)(/|$)' "$GATE_FILES" >> "$SEC_HITS" || true
sort -u "$SEC_HITS" -o "$SEC_HITS"
gate_report security "$SEC_HITS"

exit 0
