#!/usr/bin/env bash
# test_gate_pl_slash_on_two_integers_is_a_float_in_xsb_and_gnu_and_an_exact_integer_in_swi.sh -- ARCH-PROLOG-DIALECTS.md sec 6 step 3, INTEGER DIVISION IS A COLUMN: / on two integers answers the
# integer when the quotient is exact in SWI (and the ISO default, graded against swipl; the iso flag still forces a float), and a float
# always in XSB and GNU; //, mod, rem and truncate agree across the three and stay.
#
# THE REFS ARE THE ORACLES' OUTPUT, cut when the gate was written: XSB 5.0.0 (xsb_bin), GNU Prolog 1.6.0 through gplc (gplc_bin), swipl 9;
# each is re-cut when its oracle is on the box and the gate refuses rc=2 on disagreement.
#
# RED BEFORE (measured on SCRIP 1a142c4c3, hq_icon 2026-10-25): the XSB and GNU arms answered 2 int for 4/2, -2 int for -6/3, 0 int for 0/5
# (xsb_tests float_tests_roots and roots_int_comp read FAIL on "x1 = x2 = -1" for -1.0). GREEN AFTER: the three dialects, m3 and m4,
# byte-identical to their oracle's ref.
#
# Usage: bash ../harness/scripts/test_gate_pl_slash_on_two_integers_is_a_float_in_xsb_and_gnu_and_an_exact_integer_in_swi.sh
set -uo pipefail
GATE_NAME=test_gate_pl_slash_on_two_integers_is_a_float_in_xsb_and_gnu_and_an_exact_integer_in_swi
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
. "$HERE/lib_gate.sh"
. "$HERE/lib_oracle_flags.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
command -v gcc >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gcc -- the mode-4 arm cannot be linked"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/w.pl" <<'PL'
t(E) :- X is E, write(X), ( integer(X) -> write(' int') ; write(' float') ), nl.
main :- t(4/2), t(7/2), t(-6/3), t(0/5), t(6/(-3)), t(4.0/2), t(9//2), t(9 mod 4), t(-9 rem 4), t(truncate(7/2)).
PL
cat > "$T/xsb.ref" <<'REF'
2.0 float
3.5 float
-2.0 float
0.0 float
-2.0 float
2.0 float
4 int
1 int
-1 int
3 int
REF
cat > "$T/gnu.ref" <<'REF'
2.0 float
3.5 float
-2.0 float
0.0 float
-2.0 float
2.0 float
4 int
1 int
-1 int
3 int
REF
cat > "$T/swi.ref" <<'REF'
2 int
3.5 float
-2 int
0 int
-2 int
2.0 float
4 int
1 int
-1 int
3 int
REF
recut() { cmp -s "$T/$1.out" "$T/$1.ref" || { echo "⛔ REFUSED(2) [$GATE_NAME]: $2 no longer prints the carried $1.ref -- re-cut it from the oracle, never from SCRIP"; diff "$T/$1.ref" "$T/$1.out" | head -4; exit 2; }; }
if xb="$(xsb_bin 2>/dev/null)"; then ( cd "$T" && timeout -k 5 60 "$xb" --noprompt --quietload --nobanner -e "consult(w), main, halt." < /dev/null 2>/dev/null | grep -v '^\[' > xsb.out ); recut xsb "XSB 5.0.0"; fi
if gc="$(gplc_bin 2>/dev/null)"; then
    ( cd "$T" && { cat w.pl; echo ':- initialization((main, halt)).'; } > wg.pl && timeout -k 5 120 "$gc" -o wg wg.pl > /dev/null 2>&1 && timeout -k 5 20 ./wg < /dev/null > gnu.out 2>/dev/null )
    recut gnu "GNU Prolog 1.6.0 (gplc)"
fi
if command -v swipl > /dev/null; then ( cd "$T" && timeout -k 5 60 swipl -g main -t halt w.pl < /dev/null > swi.out 2>/dev/null ); recut swi "swipl"; fi
{ echo ':- compiler_options([]).'; cat "$T/w.pl"; echo ':- initialization((main, halt)).'; } > "$T/x.pl"
{ cat "$T/w.pl"; echo ':- initialization((main, halt)).'; } > "$T/g.pl"
{ echo ':- use_module(library(lists)).'; cat "$T/w.pl"; echo ':- initialization((main, halt)).'; } > "$T/s.pl"
fail=0
arm() {
    local name=$1 src=$2 ref=$3 sw=$4
    ( cd "$T" && timeout -k 5 20 "$SCRIP" $sw "$src" < /dev/null > "$name.m3" 2>&1 ); local rc3=$?
    if cmp -s "$T/$name.m3" "$T/$ref"; then echo "  ok   ($name m3) 10 quotients as $ref"; else echo "  FAIL ($name m3) rc=$rc3, first difference:"; diff "$T/$ref" "$T/$name.m3" | head -6 | sed 's/^/         /'; fail=1; fi
    if ( cd "$T" && "$SCRIP" $sw --compile -o "$name.s" "$src" < /dev/null > /dev/null 2>&1 && gcc -o "$name.bin" "$name.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> /dev/null ); then
        ( cd "$T" && timeout -k 5 20 "./$name.bin" < /dev/null > "$name.m4" 2>&1 ); local rc4=$?
        if cmp -s "$T/$name.m4" "$T/$ref"; then echo "  ok   ($name m4) the same, from the standalone build"; else echo "  FAIL ($name m4) rc=$rc4, first difference:"; diff "$T/$ref" "$T/$name.m4" | head -6 | sed 's/^/         /'; fail=1; fi
    else echo "  FAIL ($name m4) the witness did not compile or link in mode 4"; fail=1; fi
}
arm xsb x.pl xsb.ref ""
arm gnu g.pl gnu.ref "--dialect=gnu"
arm swi s.pl swi.ref ""
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: m3 and m4 answer / on two integers as a float in XSB and GNU and as the exact integer in SWI"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1
