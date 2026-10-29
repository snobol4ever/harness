#!/usr/bin/env bash
# test_gate_pl_a_float_is_written_at_its_dialects_precision_xsb_15_gnu_17_swi_shortest.sh -- ARCH-PROLOG-DIALECTS.md sec 6 step 2, THE FLOAT
# WRITER COLUMN: write/1 and writeq/1 print a float through ONE function (pl_real_iso_str) whose precision is the dialect's -- XSB %.15g,
# GNU %.17g, SWI the shortest round trip -- followed by the rule all three oracles share: a mantissa with no . gets .0 inserted before the
# exponent or at the end (2.0, 1.0e+17, 1000000000000000.0). SWI alone writes a one-digit exponent (1.5e-7); XSB and GNU keep C's two.
#
# THE REFS ARE THE ORACLES' OUTPUT, cut when the gate was written: XSB 5.0.0 (xsb_bin), GNU Prolog 1.6.0 through gplc (gplc_bin -- the
# column's GNU proof the design page asks for), swipl 9. The gate re-cuts each when its oracle is on the box and refuses rc=2 on
# disagreement. Every value is computed or a positive literal: XSB READS the literal -0.0 as 0.0 (a reader difference, not the writer's).
#
# RED BEFORE (measured on SCRIP 5c435f745, hq_icon 2026-10-25): SCRIP wrote the shortest round trip in every dialect, so the XSB arm
# printed 0.3333333333333333 for 0.333333333333333 and 0.30000000000000004 for 0.3 (xsb_tests float_tests_roots and roots_int_comp read
# FAIL on exactly those lines), and the GNU arm 0.3333333333333333 for 0.33333333333333331 and 1.0e+15 for 1000000000000000.0. GREEN
# AFTER: the three dialects, m3 and m4, byte-identical to their oracle's ref.
#
# Usage: bash ../harness/scripts/test_gate_pl_a_float_is_written_at_its_dialects_precision_xsb_15_gnu_17_swi_shortest.sh
set -uo pipefail
GATE_NAME=test_gate_pl_a_float_is_written_at_its_dialects_precision_xsb_15_gnu_17_swi_shortest
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
t(X) :- write(X), write(' '), writeq(X), nl.
main :- X1 is 1/3, t(X1), X2 is -2/3, t(X2), t(2.0), X3 is 0.1+0.2, t(X3), t(1.0e17), t(1.5e-7), t(1.0e22), t(123456789012345680.0), t(1.0e-300), t(0.5), t(100.0),
    t(1.0e15), t(1.0e16), t(3.0e-5), t(0.001), X4 is 10.0**20, t(X4), X5 is sqrt(2.0), t(X5), X6 is -1.0*0.0, t(X6).
PL
cat > "$T/xsb.ref" <<'REF'
0.333333333333333 0.333333333333333
-0.666666666666667 -0.666666666666667
2.0 2.0
0.3 0.3
1.0e+17 1.0e+17
1.5e-07 1.5e-07
1.0e+22 1.0e+22
1.23456789012346e+17 1.23456789012346e+17
1.0e-300 1.0e-300
0.5 0.5
100.0 100.0
1.0e+15 1.0e+15
1.0e+16 1.0e+16
3.0e-05 3.0e-05
0.001 0.001
1.0e+20 1.0e+20
1.4142135623731 1.4142135623731
-0.0 -0.0
REF
cat > "$T/gnu.ref" <<'REF'
0.33333333333333331 0.33333333333333331
-0.66666666666666663 -0.66666666666666663
2.0 2.0
0.30000000000000004 0.30000000000000004
1.0e+17 1.0e+17
1.4999999999999999e-07 1.4999999999999999e-07
1.0e+22 1.0e+22
1.2345678901234568e+17 1.2345678901234568e+17
1.0e-300 1.0e-300
0.5 0.5
100.0 100.0
1000000000000000.0 1000000000000000.0
10000000000000000.0 10000000000000000.0
3.0000000000000001e-05 3.0000000000000001e-05
0.001 0.001
1.0e+20 1.0e+20
1.4142135623730951 1.4142135623730951
-0.0 -0.0
REF
cat > "$T/swi.ref" <<'REF'
0.3333333333333333 0.3333333333333333
-0.6666666666666666 -0.6666666666666666
2.0 2.0
0.30000000000000004 0.30000000000000004
1.0e+17 1.0e+17
1.5e-7 1.5e-7
1.0e+22 1.0e+22
1.2345678901234568e+17 1.2345678901234568e+17
1.0e-300 1.0e-300
0.5 0.5
100.0 100.0
1.0e+15 1.0e+15
1.0e+16 1.0e+16
3.0e-5 3.0e-5
0.001 0.001
1.0e+20 1.0e+20
1.4142135623730951 1.4142135623730951
-0.0 -0.0
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
    if cmp -s "$T/$name.m3" "$T/$ref"; then echo "  ok   ($name m3) 18 floats as $ref"; else echo "  FAIL ($name m3) rc=$rc3, first difference:"; diff "$T/$ref" "$T/$name.m3" | head -6 | sed 's/^/         /'; fail=1; fi
    if ( cd "$T" && "$SCRIP" $sw --compile --out="$name.s" "$src" < /dev/null > /dev/null 2>&1 && gcc -o "$name.bin" "$name.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> /dev/null ); then
        ( cd "$T" && timeout -k 5 20 "./$name.bin" < /dev/null > "$name.m4" 2>&1 ); local rc4=$?
        if cmp -s "$T/$name.m4" "$T/$ref"; then echo "  ok   ($name m4) the same, from the standalone build"; else echo "  FAIL ($name m4) rc=$rc4, first difference:"; diff "$T/$ref" "$T/$name.m4" | head -6 | sed 's/^/         /'; fail=1; fi
    else echo "  FAIL ($name m4) the witness did not compile or link in mode 4"; fail=1; fi
}
arm xsb x.pl xsb.ref ""
arm gnu g.pl gnu.ref "--dialect=gnu"
arm swi s.pl swi.ref ""
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: m3 and m4 write a float at XSB's 15, GNU's 17 and SWI's shortest digits, each with the shared .0 rule"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1
