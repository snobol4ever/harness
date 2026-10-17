#!/usr/bin/env bash
# util_style200_oracle_yl.sh -- THE GOAL-STYLE-200COL ORACLE FOR .y / .l SOURCES: object identity of the COMPILED GENERATED PARSER.
# A grammar has no object of its own; its object-equivalent is the parser bison/flex generate from it. Both sides ($STYLE200_BASE, default
# HEAD, vs the working tree) are generated from an IDENTICAL cwd under the grammar's REAL output basename (X.y -> X.tab.c/X.tab.h): bison
# bakes the input path into #line and the output basename into an #include and an include guard, so two sides generated from different
# places diff by pure path noise, and pascal.y/raku.y #include their own X.tab.h, so a made-up basename leaves that include resolving to
# the committed header beside the generated one and the parser compiles on NEITHER side (measured 2026-09-02: 2 of 9 SKIPped) -- then compiled
# with the build's own command (lib_build_flags.sh reads the Makefile) and compared with obj_fingerprint (instructions + relocations +
# every non-debug section). TEXT identity is the wrong bar: deleting a comment shifts every later #line and bison's yyrline[] (compiled
# only under YYDEBUG), and bison/flex copy action-block comments verbatim -- R4 measured 7 of 9 files failing a raw text compare on a pure
# comment strip. Object identity settles it: without YYDEBUG the line table is not compiled and #line touches only debug info.
# ⛔ This file carried a hand-copied -I list naming src/parser/ and two directories that no longer exist, so it printed
# `OK · 0 byte-identical` while SKIPping every file (R5 FINDING, 2026-09-02): a zero denominator now REFUSES rc=2, and a generated parser that
# compiles on ONE side only is a BREAK, not a silent skip.
# Exit: 0 OK · 1 BREAK/DIFF · 2 REFUSED (bison/flex cannot generate, Makefile unreadable, no files given, or nothing measured).
# Usage: bash ../harness/scripts/util_style200_oracle_yl.sh src/parsers/*/*.y src/parsers/*/*.l     (STYLE200_BASE=<commit> to re-prove a landed sweep)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_build_flags.sh"
build_flags_load "$ROOT" || exit 2
gen_tools_ready || exit 2
BASE="${STYLE200_BASE:-HEAD}"
[ $# -gt 0 ] || { echo "⛔ REFUSE rc=2 [util_style200_oracle_yl] -- no files given. Usage: $0 <grammar.y|lexer.l>...  (STYLE200_BASE=<commit> selects the before-tree)"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ok=0; bad=0; skipg=0; skipc=0; skipx=0; BADF=""
CMD="$(build_compile_cmd c)"
cd "$ROOT"
gen() {
    ( cd "$1" || exit 9
      case "$ext" in
        y) bison -d --warnings=none -Wno-yacc -o "$o" "$base" >/dev/null 2>&1 ;;
        l) flex --noline -o "$o" "$base" >/dev/null 2>&1 ;;
      esac )
}
for f in "$@"; do
    rel="${f#$ROOT/}"; base="$(basename "$rel")"; ext="${rel##*.}"; D="$ROOT/$(dirname "$rel")"
    case "$ext" in y) o="${base%.y}.tab.c";; l) o="${base%.l}.lex.c";; *) skipx=$((skipx+1)); continue;; esac
    rm -rf "$T/before" "$T/after"; mkdir -p "$T/before" "$T/after"
    git show "$BASE:$rel" > "$T/before/$base" 2>/dev/null || { skipc=$((skipc+1)); echo "  SKIP(not in $BASE): $rel"; continue; }
    [ -f "$rel" ] || { skipc=$((skipc+1)); echo "  SKIP(not in working tree): $rel"; continue; }
    cp "$rel" "$T/after/$base"
    gen "$T/before"; rb=$?
    gen "$T/after";  ra=$?
    if [ $rb -ne 0 ] || [ $ra -ne 0 ]; then
        if [ $rb -ne 0 ] && [ $ra -ne 0 ]; then skipg=$((skipg+1)); echo "  SKIP(fails to generate BOTH ways -- broken independently of the reformat): $rel"; continue; fi
        echo "⛔ BREAK ($rel): generates one way only (before=$rb after=$ra) -- the reformat broke the grammar"; bad=$((bad+1)); BADF="$BADF $rel"; continue
    fi
    $CMD -iquote "$D" "$T/before/$o" -o "$T/before/$o.o" 2>/dev/null; cb=$?
    $CMD -iquote "$D" "$T/after/$o"  -o "$T/after/$o.o"  2>/dev/null; ca=$?
    if [ $cb -ne 0 ] || [ $ca -ne 0 ]; then
        if [ $cb -ne 0 ] && [ $ca -ne 0 ]; then skipc=$((skipc+1)); echo "  SKIP(generated parser compiles NEITHER way -- a header it includes is missing on both sides): $rel"; continue; fi
        echo "⛔ BREAK ($rel): generated parser compiles one way only (before=$cb after=$ca)"; bad=$((bad+1)); BADF="$BADF $rel"; continue
    fi
    obj_fingerprint "$T/before/$o.o" "$T/before/fp"; obj_fingerprint "$T/after/$o.o" "$T/after/fp"
    if cmp -s "$T/before/fp" "$T/after/fp"; then ok=$((ok+1)); printf '  ✅ %-40s generated parser byte-identical\n' "$rel"
    else bad=$((bad+1)); BADF="$BADF $rel"; printf '  ⛔ %-40s GENERATED PARSER DIFFERS\n' "$rel"; fi
done
n=$((ok+bad))
echo "------------------------------------------------------------"
echo "Y/L ORACLE: $ok byte-identical · $bad BREAK/DIFF · measured $n of $# · skipped: $skipg no-generate-both-ways · $skipc no-compile-both-ways/absent · $skipx not-a-grammar · base=$BASE · bison $BF_BISON_VERSION flex $BF_FLEX_VERSION · flags from Makefile"
if [ $n -eq 0 ]; then echo "⛔ REFUSE rc=2 -- zero grammars measured: this run proved NOTHING (a zero-denominator OK is the false green RULES.md bans)"; exit 2; fi
[ $bad -ne 0 ] && { echo "⛔ FAIL -- reformat changed the generated parser for:$BADF"; exit 1; }
echo "OK -- $n grammar(s) generate a byte-identical parser against $BASE"; exit 0
