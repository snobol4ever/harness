#!/usr/bin/env bash
# util_style200_oracle.sh -- THE GOAL-STYLE-200COL ORACLE, per file: a reformat is proven by OBJECT IDENTITY, never by a test suite.
#   (1) the TRUE original is `git show $STYLE200_BASE:<path>` (default HEAD; STYLE200_BASE=<commit> re-proves a landed sweep against its
#       pre-sweep tree) -- never a manual cp backup: the goal records a miss that hid for two turns behind exactly that;
#   (2) both sides compile with THE BUILD'S OWN COMMAND: lib_build_flags.sh reads RT_OPT/RT_INCS/ZCFLAGS/CBASE from the Makefile at run
#       time. This file carried a hand-copied -I list naming src/parser/, src/contracts and src/machine for months after they moved, so every
#       file SKIPped and the summary read OK over a denominator of ZERO (R5 FINDING, 2026-09-02). A zero denominator now REFUSES rc=2;
#   (3) obj_fingerprint: `objdump -d -r` (instructions WITH relocations -- without -r a call retargeted to another function is byte-
#       identical) plus `objdump -s` of EVERY non-debug section (-fPIC pointer tables live in .data.rel.local / .data.rel.ro, which the old
#       -j .data/.rodata/.bss list never saw) must match byte for byte.
# Exit: 0 OK · 1 BREAK (compiles one way only) or DIFF · 2 REFUSED (nothing measured, no files given, Makefile unreadable).
# Headers are SKIP(header): a lone .h yields no object and both-sides-fail reads as a false PASS -- verify them through a consumer TU.
# Both sides are compiled under the file's OWN basename in two directories: a C++ TU with global constructors gets a symbol named after its
# source file (_GLOBAL__sub_I_emit.cpp), so before.cpp/after.cpp copies DIFF on every such TU (measured on emit.cpp 2026-09-02).
# Usage: bash ../harness/scripts/util_style200_oracle.sh <file>...
#        git diff --name-only 46db4457 922cfaf4 | STYLE200_BASE=46db4457 xargs bash ../harness/scripts/util_style200_oracle.sh   # re-prove R5
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_build_flags.sh"
build_flags_load "$ROOT" || exit 2
BASE="${STYLE200_BASE:-HEAD}"
[ $# -gt 0 ] || { echo "⛔ REFUSE rc=2 [util_style200_oracle] -- no files given. Usage: $0 <file>...  (STYLE200_BASE=<commit> selects the before-tree)"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ok=0; bad=0; skiph=0; skipc=0; skipx=0; BADF=""
cd "$ROOT"
for f in "$@"; do
    rel="${f#$ROOT/}"; ext="${rel##*.}"
    case "$ext" in h|hpp|inc) skiph=$((skiph+1)); continue;; c|cpp|S|s) ;; *) skipx=$((skipx+1)); continue;; esac
    base="$(basename "$rel")"; rm -rf "$T/before" "$T/after"; mkdir -p "$T/before" "$T/after"
    git show "$BASE:$rel" > "$T/before/$base" 2>/dev/null || { skipc=$((skipc+1)); echo "  SKIP(not in $BASE): $rel"; continue; }
    [ -f "$rel" ] || { skipc=$((skipc+1)); echo "  SKIP(not in working tree): $rel"; continue; }
    cp "$rel" "$T/after/$base"
    CMD="$(build_compile_cmd "$ext" "$rel")"; D="$ROOT/$(dirname "$rel")"
    $CMD -iquote "$D" "$T/before/$base" -o "$T/before.o" 2>/dev/null; rb=$?
    $CMD -iquote "$D" "$T/after/$base"  -o "$T/after.o"  2>/dev/null; ra=$?
    if [ $rb -ne 0 ] || [ $ra -ne 0 ]; then
        if [ $rb -ne 0 ] && [ $ra -ne 0 ]; then skipc=$((skipc+1)); echo "  SKIP(no-compile-both-ways): $rel"; continue; fi
        echo "⛔ BREAK (compiles one way only, before=$rb after=$ra): $rel"; bad=$((bad+1)); BADF="$BADF $rel"; continue
    fi
    obj_fingerprint "$T/before.o" "$T/b.fp"; obj_fingerprint "$T/after.o" "$T/a.fp"
    if cmp -s "$T/b.fp" "$T/a.fp"; then ok=$((ok+1)); else echo "⛔ DIFF: $rel"; bad=$((bad+1)); BADF="$BADF $rel"; fi
done
n=$((ok+bad))
echo "------------------------------------------------------------"
echo "ORACLE: $ok byte-identical · $bad BREAK/DIFF · measured $n of $# · skipped: $skiph header(verify via consumer) · $skipc no-compile-both-ways/absent · $skipx not-a-TU · base=$BASE · flags from Makefile (RT_OPT=$(printf '%s' "$BF_RT_OPT" | tr -s ' '))"
if [ $n -eq 0 ]; then echo "⛔ REFUSE rc=2 -- zero files measured: this run proved NOTHING (a zero-denominator OK is the false green RULES.md bans)"; exit 2; fi
[ $bad -ne 0 ] && { echo "⛔ FAIL -- reformat touched semantics in:$BADF"; exit 1; }
echo "OK -- $n file(s) byte-identical against $BASE"; exit 0
