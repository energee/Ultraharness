#!/usr/bin/env bash
# audit-checks.sh — deterministic repo fact collector for playbooks/audit.md.
# Prints FACTS about a target repo (never scores, never judgments); the audit
# playbook quotes this output verbatim. bash + git + coreutils only; runs on
# macOS (BSD toolchain) and Linux. Usage: audit-checks.sh <target-path>.
# Exit 0 on success, exit 2 on invalid target path.
set -euo pipefail

RUBRIC_VERSION="v1 (2026-07-24)"

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
  > "$CODE_FILES" || true

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
echo "audit-checks $RUBRIC_VERSION — target: $TARGET"

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
  TOTAL_LOC="$(cd "$TARGET" && tr '\n' '\0' < "$CODE_FILES" \
    | xargs -0 wc -l 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)"
fi
echo "size: $FILE_COUNT files, $TOTAL_LOC lines (excluding lockfiles/vendored dirs)"

# ---------------------------------------------------------------------------
# largest files: top 10 by line count
# ---------------------------------------------------------------------------
echo "largest files: top 10 by line count"
if [ "$FILE_COUNT" -gt 0 ]; then
  (cd "$TARGET" && tr '\n' '\0' < "$CODE_FILES" \
    | xargs -0 wc -l 2>/dev/null | grep -v ' total$' | sort -rn | head -10 \
    | awk '{ lines=$1; $1=""; sub(/^ /,""); printf "  %s lines  %s\n", lines, $0 }') || true
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
    | xargs -0 grep -In -E 'TODO|FIXME' 2>/dev/null) > "$TODO_HITS" || true
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
  PATHS="$(grep "^$name	" "$TMP/basenames" | cut -f2 | tr '\n' ' ' || true)"
  echo "  shared basename '$name': $PATHS" >> "$DUP_OUT"
done < "$TMP/dup-names"

# (b) normalized-line overlap among the 20 largest files (bounded pairwise scan)
if [ "$FILE_COUNT" -gt 1 ]; then
  (cd "$TARGET" && tr '\n' '\0' < "$CODE_FILES" \
    | xargs -0 wc -l 2>/dev/null | grep -v ' total$' | sort -rn | head -20 \
    | awk '{ $1=""; sub(/^ /,""); print }') > "$TMP/top-files" || true
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

exit 0
