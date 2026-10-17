#!/usr/bin/env bash
# run_corpus_prolog.sh -- run prolog_parser and prolog_recognizer on all .pro/.pl files
# Usage: bash run_corpus_prolog.sh [dir ...]
# Prints pass/empty/crash counts. Exits 1 if crash rate > 5%.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

TIMEOUT=${TIMEOUT:-10}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ⛔ FIXED (row prolog-parser-corpus-vacuous-gate-422-files, 2026-08-27): both bugs the task diagnosed, confirmed
# by direct check before fixing, not guessed. (1) EXTENSION: the two tool files were never named .pro anywhere in
# this tree's git history (checked -- zero hits) -- they are, and always were, prolog_parser.pl/prolog_recognizer.pl
# (the .pl files' own header comments say "% prolog_parser.pro", a stale comment from whenever the extension was
# last touched, not evidence a .pro file ever existed on disk). (2) PATH: $REPO_ROOT already correctly resolves to
# the sibling root (same computation $S4E performs above it) -- the old "$REPO_ROOT/../corpus/..." had one extra
# ".." that escaped the sibling root entirely, so PARSER_SRC/RECOG_SRC pointed nowhere real regardless of extension.
# Using $S4E directly (already computed, same value) instead of re-deriving REPO_ROOT for this.
PARSER_SRC="$S4E/corpus/demos/prolog/prolog_parser.pl"
RECOG_SRC="$S4E/corpus/demos/prolog/prolog_recognizer.pl"

DIRS=("$@")
if [ ${#DIRS[@]} -eq 0 ]; then
  DIRS=(
    $S4E/corpus/tests/prolog
  )
fi

mapfile -t FILES < <(find "${DIRS[@]}" -name "*.pro" -o -name "*.pl" 2>/dev/null | sort)
TOTAL=${#FILES[@]}
if [ "$TOTAL" -eq 0 ]; then
  echo "No Prolog files found in: ${DIRS[*]}"
  exit 0
fi

P_PASS=0; P_EMPTY=0; P_CRASH=0
R_PASS=0; R_EMPTY=0; R_CRASH=0

for f in "${FILES[@]}"; do
  OUT=$(timeout -k 5 "$TIMEOUT" swipl -q -f "$PARSER_SRC" -t halt < "$f" 2>/dev/null); code=$?
  if [ $code -eq 124 ] || [ $code -ne 0 ]; then
    ((P_CRASH++))
  elif [ -z "$OUT" ]; then
    ((P_EMPTY++))
  else
    ((P_PASS++))
  fi

  OUT=$(timeout -k 5 "$TIMEOUT" swipl -q -f "$RECOG_SRC" -t halt < "$f" 2>/dev/null); code=$?
  if [ $code -eq 124 ] || [ $code -ne 0 ]; then
    ((R_CRASH++))
  elif [ -z "$OUT" ] || [ "$OUT" = '(compiland)' ]; then
    ((R_EMPTY++))
  else
    ((R_PASS++))
  fi
done

echo "=== Prolog corpus: parser + recognizer ==="
echo "Files:          $TOTAL"
echo "Parser:         pass=$P_PASS  empty=$P_EMPTY  crash/timeout=$P_CRASH"
echo "Recognizer:     pass=$R_PASS  empty=$R_EMPTY  crash/timeout=$R_CRASH"

MAX_CRASH=$(( TOTAL * 5 / 100 + 1 ))
if [ "$P_CRASH" -gt "$MAX_CRASH" ] || [ "$R_CRASH" -gt "$MAX_CRASH" ]; then
  echo "RESULT: FAIL (crash rate > 5%)"
  exit 1
fi
echo "RESULT: PASS"
