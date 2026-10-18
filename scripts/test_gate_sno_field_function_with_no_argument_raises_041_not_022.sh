#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_field_function_with_no_argument_raises_041_not_022.sh
# A DATA field function CALLED WITH NO ARGUMENT is ERROR 041 (field function argument is wrong datatype),
# not ERROR 022 (undefined function called).  SPITBOL supplies the null string for the missing argument and
# the null string is the wrong datatype; the field function IS defined, so 022 is the wrong diagnosis.
# ⛔ WHY THIS NEEDED A GATE AND NOT JUST A FIX.  The row that handed this over said "SPITBOL raises 041 ...
# SCRIP returns the null string".  MEASURED on origin 2026-09-12 (hq_C), that premise was already stale:
# SCRIP raised 041 correctly on a string, an integer, an array, a table and an instance of another data type.
# Exactly ONE shape of the seven diverged -- the zero-argument call -- and it diverged in the other direction,
# raising 022.  A stale premise pointed at a whole class; the class was one cell wide and facing the other way.
# ⭐ SO THE SIX ARMS THAT ALREADY AGREED ARE IN THIS GATE AS CONTROL ARMS, not as decoration: the cure sits in
# the by-name dispatch fall-through in src/driver/driver_call.c, which every one of them also traverses, and
# a cure there that silently converted a correct 041 into something else would otherwise be invisible.
# ⛔ EVERY ARM IS GRADED AGAINST THE LIVE ORACLE, never against a typed-in expectation -- `sbl -bf` per
# lib_oracle_flags.sh, both SCRIP modes independently (RULES.md § MODES MAY DIVERGE: each mode is graded
# against the oracle, never against the other).
# EXIT 0 all arms agree with the oracle in both modes · 1 an arm diverges · 2 REFUSED (not built / no oracle)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
G=sno-field-fn-no-arg-041
. "$HERE/lib_oracle_flags.sh" || { echo "⛔ GATE REFUSE(2) [$G]: cannot load lib_oracle_flags.sh"; exit 2; }
SBL="$(sbl_correctness_bin 2>/dev/null)"; [ -n "$SBL" ] && [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: SPITBOL correctness oracle not executable"; exit 2; }
FLAGS="$(sbl_lang_flags)"
SCRIP="${SCRIP:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: $SCRIP not built"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: $LIBDIR/libscrip_rt.so missing"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/$G.XXXXXX")" || exit 2; trap 'rm -rf "$W"' EXIT
verdict() { grep -oiE 'error [0-9]+|RESULT\[[^]]*\]' | tr 'a-z' 'A-Z' | sed -E 's/ERROR 0+([0-9])/ERROR \1/' | sort -u | tr '\n' ' ' | sed 's/ *$//'; }
FAIL=0; N=0
for arm in "no-argument|X()" "string|X('hello')" "integer|X(7)" "array|X(AR)" "table|X(TB)" "other-data-type|Y(P)" "correct-field|X(P)"; do
    name="${arm%%|*}"; expr="${arm#*|}"; N=$((N+1))
    { printf "\tDATA('A(X)')\n\tDATA('B(Y)')\n\tP = A(1)\n\tQ = B(2)\n\tAR = ARRAY(3)\n\tTB = TABLE()\n"
      printf "\tRES = %s\n\tOUTPUT = 'RESULT[' RES ']'\nEND\n" "$expr"; } > "$W/w.sno"
    want="$( ( cd "$W" && timeout -k 5 20 "$SBL" $FLAGS w.sno ) </dev/null 2>&1 | verdict )"
    [ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no gradable verdict for $name ($expr)"; exit 2; }
    got3="$( timeout -k 5 20 "$SCRIP" "$W/w.sno" </dev/null 2>&1 | verdict )"
    got4=""
    if "$SCRIP" --compile "$W/w.sno" -o "$W/w.s" </dev/null >/dev/null 2>&1 &&
       gcc -m64 -no-pie -rdynamic "$W/w.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$W/w" 2>"$W/ld.log"; then
        got4="$( timeout -k 5 20 "$W/w" </dev/null 2>&1 | verdict )"
    else
        echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link failed for $name ($expr) -- see $W/ld.log"; exit 2
    fi
    st=ok; [ "$got3" = "$want" ] || { st=FAIL; FAIL=$((FAIL+1)); }
    [ "$got4" = "$want" ] || { st=FAIL; FAIL=$((FAIL+1)); }
    printf '  %-16s %-12s oracle=%-14s m3=%-14s m4=%-14s %s\n' "$name" "$expr" "$want" "$got3" "$got4" "$st"
done
[ "$FAIL" = 0 ] || { echo "⛔ GATE FAIL(1) [$G]: $FAIL mode/arm pair(s) diverge from the oracle over $N arms"; exit 1; }
echo "✅ GATE PASS(0) [$G]: $N field-function arms, m3 and m4 each agree with $SBL $FLAGS -- a field function with no argument is ERROR 041, not 022"
exit 0
