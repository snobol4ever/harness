#!/usr/bin/env bash
# run_corpus_icon.sh -- run icon_parser and icon_recognizer on all .icn files
# Usage: bash run_corpus_icon.sh [dir ...]
# Prints pass/empty/crash counts. Exits 1 if crash rate > 5%.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

TIMEOUT=${TIMEOUT:-10}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=lib_oracle_flags.sh
. "$SCRIPT_DIR/lib_oracle_flags.sh"                                     # icont_bin(): the ONE authority for the Icon oracle path -- it is NOT on PATH, and bare `icont` reads as "no Icon oracle exists"
ICONT=$(icont_bin) || { echo "ERROR: Icon oracle unresolvable -- refusing rather than printing a false all-crash table"; exit 2; }

# ⛔ RESOLVE BY SEARCH, REFUSE ON UNRESOLVABLE. These two sources moved to corpus/demos/icon/demo/ in the
# 2026-08-24 corpus re-grid; the old hardcoded corpus/demos/scrip/ path had additionally been resolving through
# $REPO_ROOT/.. = /home (one level above the seat root), so it could never have matched even before the move.
icn_src() {                                                             # $1 = basename to find under the corpus
    local hit; hit=$(find "$S4E/corpus" -name "$1" -type f 2>/dev/null | sort | head -1)
    [ -n "$hit" ] || { printf "⛔ ICON SOURCE UNRESOLVABLE UNDER %s: %s\n" "$S4E/corpus" "$1" >&2; return 1; }
    printf '%s\n' "$hit"
}
PARSER_SRC=$(icn_src icon_parser.icn)     || exit 2
RECOG_SRC=$(icn_src icon_recognizer.icn)  || exit 2

TMP=$(mktemp -d)
"$ICONT" -s -o "$TMP/icon_parser"     "$PARSER_SRC"  2>/dev/null || { echo "ERROR: icon_parser compile failed ($PARSER_SRC)"; exit 2; }
"$ICONT" -s -o "$TMP/icon_recognizer" "$RECOG_SRC"   2>/dev/null || { echo "ERROR: icon_recognizer compile failed ($RECOG_SRC)"; exit 2; }

DIRS=("$@")
if [ ${#DIRS[@]} -eq 0 ]; then
  DIRS=()                                                               # ⛔ only directories that EXIST -- a dead path in this list silently shrinks the denominator (find's error is swallowed by 2>/dev/null)
  for d in "$S4E/corpus/tests/icon"; do [ -d "$d" ] && DIRS+=("$d"); done
  [ ${#DIRS[@]} -gt 0 ] || { echo "ERROR: no Icon corpus directory resolved -- refusing"; exit 2; }
fi

mapfile -t FILES < <(find "${DIRS[@]}" -name "*.icn" 2>/dev/null | sort)
TOTAL=${#FILES[@]}
P_PASS=0; P_EMPTY=0; P_CRASH=0
R_PASS=0; R_EMPTY=0; R_CRASH=0
R_KNOWN_EMPTY=0; R_FAIL=0; R_UNGRADED=0
R_FAIL_DETAIL=()

# row icon-recognizer-vacuous-compiland-ungraded: a recognizer result of (compiland "") is
# GRADED, never left in an unexamined empty bucket. r_top() only matches top-level
# procedure/global/record forms, so a source containing one of those SHOULD produce a
# non-empty tree -- empty then means the recognizer failed on something inside it (FAIL,
# a gap to cure elsewhere, not this row's claim). A source with none of those three forms
# has nothing in this recognizer's scope to find, so empty is known-legitimate-empty.
# An unreadable source can't be graded either way -- ungraded, and the script REFUSES on it
# below rather than count it green (a skipped file that reports success is the make-test trap).
recognizer_empty_class() {
  [ -r "$1" ] || return 2
  grep -qE '^[[:space:]]*(procedure|global|record)\b' "$1"
}

for f in "${FILES[@]}"; do
  OUT=$(timeout -k 5 "$TIMEOUT" "$TMP/icon_parser" < "$f" 2>/dev/null); code=$?
  if [ $code -eq 124 ] || [ $code -ne 0 ]; then
    ((P_CRASH++))
  elif [ -z "$OUT" ] || [ "$OUT" = '(compiland "")' ]; then
    ((P_EMPTY++))
  else
    ((P_PASS++))
  fi

  OUT=$(timeout -k 5 "$TIMEOUT" "$TMP/icon_recognizer" < "$f" 2>/dev/null); code=$?
  if [ $code -eq 124 ] || [ $code -ne 0 ]; then
    ((R_CRASH++))
  elif [ -z "$OUT" ] || [ "$OUT" = '(compiland "")' ]; then
    ((R_EMPTY++))
    recognizer_empty_class "$f"; class_rc=$?
    if [ $class_rc -eq 2 ]; then
      ((R_UNGRADED++))
    elif [ $class_rc -eq 0 ]; then
      ((R_FAIL++)); R_FAIL_DETAIL+=("$f")
    else
      ((R_KNOWN_EMPTY++))
    fi
  else
    ((R_PASS++))
  fi
done

rm -rf "$TMP"

echo "=== Icon corpus: parser + recognizer ==="
echo "Files:          $TOTAL"
echo "Parser:         pass=$P_PASS  empty=$P_EMPTY  crash/timeout=$P_CRASH"
echo "Recognizer:     pass=$R_PASS  empty=$R_EMPTY  crash/timeout=$R_CRASH"
echo "Recognizer classes:  pass=$R_PASS  known-legitimate-empty=$R_KNOWN_EMPTY  fail=$R_FAIL  ungraded=$R_UNGRADED"
if [ "$R_FAIL" -gt 0 ]; then
  echo "  fail = vacuous (compiland \"\") despite a top-level procedure/global/record -- recognizer gap(s), see FINDING-2026-09-06-*icon-recognizer*.md:"
  printf '    %s\n' "${R_FAIL_DETAIL[@]}"
fi
if [ "$R_UNGRADED" -gt 0 ]; then
  echo "REFUSE(2): $R_UNGRADED recognizer empty-result(s) could not be classified (source unreadable) -- refusing rather than counting them green"
  exit 2
fi

MAX_CRASH=$(( TOTAL * 5 / 100 + 1 ))
if [ "$P_CRASH" -gt "$MAX_CRASH" ] || [ "$R_CRASH" -gt "$MAX_CRASH" ]; then
  echo "RESULT: FAIL (crash rate > 5%)"
  exit 1
fi
echo "RESULT: PASS"
