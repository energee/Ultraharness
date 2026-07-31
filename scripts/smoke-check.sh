#!/usr/bin/env bash
# smoke-check.sh — optional browser evidence collector for playbooks/verify.md.
# Prints FACTS about one live page (never judgments); verify quotes them under a
# `smoke:` label. The browser is user-supplied equipment: $LIGHTPANDA_BIN or a
# `lightpanda` on PATH. This harness never bundles or downloads one — a missing
# browser is a printed fact and exit 3, never an error (the rule lives in AGENTS.md).
# Usage: smoke-check.sh <url> [--expect <string>]
# Exit: 0 facts collected; 2 usage; 3 browser unavailable; 4 fetch failed;
# 5 --expect string not present in the served DOM.
set -euo pipefail
export LC_ALL=C

SCRIPT_VERSION="v1 (2026-07-31)"

usage() { echo "usage: smoke-check.sh <url> [--expect <string>]" >&2; exit 2; }

URL="${1:-}"
[ -n "$URL" ] || usage
EXPECT=""
if [ "$#" -ge 2 ]; then
  { [ "$2" = "--expect" ] && [ -n "${3:-}" ]; } || usage
  EXPECT="$3"
fi

echo "smoke-check $SCRIPT_VERSION — url: $URL"

BIN="${LIGHTPANDA_BIN:-$(command -v lightpanda || true)}"
if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then
  echo "browser: unavailable — set LIGHTPANDA_BIN or put lightpanda on PATH"
  exit 3
fi
echo "browser: lightpanda $("$BIN" version 2>/dev/null || echo '(version unknown)')"

DUMP="$(mktemp)"
ERR="$(mktemp)"
trap 'rm -f "$DUMP" "$ERR"' EXIT

START="$(date +%s)"
set +e
LIGHTPANDA_DISABLE_TELEMETRY=true "$BIN" fetch --dump html --log_level err "$URL" \
  > "$DUMP" 2> "$ERR"
RC=$?
set -e
if [ "$RC" -ne 0 ]; then
  echo "fetch: FAILED (exit $RC — $(head -c 200 "$ERR" | tr '\n' ' '))"
  exit 4
fi
ELAPSED=$(( $(date +%s) - START ))
echo "fetched: $(wc -c < "$DUMP" | tr -d ' ') bytes in ${ELAPSED}s"

# First <title> only; a title split across lines reads as none — a fact, not a bug.
TITLE="$(grep -oE '<title[^>]*>[^<]*' "$DUMP" | head -1 | sed 's/<title[^>]*>//')"
echo "title: ${TITLE:-none}"

if [ -n "$EXPECT" ]; then
  if grep -qF -- "$EXPECT" "$DUMP"; then
    echo "expect '$EXPECT': found"
  else
    echo "expect '$EXPECT': NOT FOUND"
    exit 5
  fi
fi
