#!/usr/bin/env bash
# test_gate_sno_an_opsyn_of_a_built_in_that_the_guard_skips_leaves_the_built_in_callable_in_both_modes.sh
#
# THE DEFECT (row snobol4-with-corpus-include-io-inc-included-scrip-remaps-input-where-spitbol-keeps-the-builtin-and-mode-4-dies-with-error-22-on-apply-through-an-opsyn-alias): corpus/include/io.inc is a
# CSNOBOL4 portability layer: DEFINE('input_(...)'), OPSYN('input__', 'INPUT'), then a guard -- IDENT(REPLACE(DATATYPE(FENCE), &LCASE, &UCASE), dPATTERN) :S(io_no_remap) -- that SKIPS OPSYN('INPUT', 'input_') under
# SPITBOL (which forbids it, error 248). SCRIP's lowerer pre-registers every OPSYN of a DEFINEd function as a user definition at compile time, whatever the control flow: the skipped OPSYN('INPUT', 'input_') made every
# INPUT(...) call a call of input_, which APPLYs the alias input__ of the now-user-defined INPUT: error 22 'undefined function called' (and, because the stub was entered with the stack unaligned, the error voice's
# unwinder SIGSEGV'd). THE CURE: the compile-time fold leaves a protected system function (INPUT, OUTPUT, ...) to the run-time OPSYN, and rt_ab_undef_fn_stub aligns the stack before it calls C. The expected output
# is cut from sbl -bf at run time; the corpus claws5 demo with the layer in front is graded against its ref. Both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
C="$B/../corpus"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
SBLB="${SBLB:-/home/resources/spitbol-bench-oracle/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent"
[ -f "$C/include/io.inc" ] && [ -f "$C/demos/snobol4/claws5/claws5.ref" ] || refuse "the corpus include layer or the claws5 demo is absent at $C"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
LAYER="-INCLUDE 'global.inc'
        digits = '0123456789'
-INCLUDE 'is.inc'
-INCLUDE 'FENCE.inc'
-INCLUDE 'io.inc'"
printf '%s\n        OUTPUT = IDENT(REPLACE(DATATYPE(FENCE), &LCASE, &UCASE), dPATTERN) %s\n        INPUT(.IN, 5, %s)\n        OUTPUT = %s\nEND\n' "$LAYER" "'guard-skips-remap'" "'x.txt'" "'after'" > "$D/small.sno"
{ printf '%s\n' "$LAYER"; cat "$C/demos/snobol4/claws5/claws5.sno"; } > "$D/claws5.sno"
( cd "$C/include" && timeout -k 5 20 "$SBL" -bf "$D/small.sno" < /dev/null 2>/dev/null > "$D/small.want" )
[ "$(tr '\n' '|' < "$D/small.want")" = "guard-skips-remap|after|" ] || refuse "sbl -bf does not answer the small witness as pinned: [$(tr '\n' '|' < "$D/small.want")]"
( cd "$C/include" && timeout -k 5 120 "$SBLB" -bf -d512m -i64m -s256m "$D/claws5.sno" < "$C/demos/snobol4/claws5/claws5.input" 2>/dev/null | cmp -s - "$C/demos/snobol4/claws5/claws5.ref" ) || refuse "the oracle itself no longer prints claws5's ref with the layer"
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
m4bin() { ( cd "$C/include" && timeout -k 5 90 "$B/scrip" --compile "$D/$1.sno" < /dev/null > "$D/$1.s" 2>/dev/null ) && gcc "$D/$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$D/$1.bin" 2>/dev/null; }
( cd "$C/include" && timeout -k 5 30 "$B/scrip" "$D/small.sno" < /dev/null > "$D/small.m3" 2>"$D/small.m3e" )
m4bin small && ( cd "$C/include" && timeout -k 5 30 "$D/small.bin" < /dev/null > "$D/small.m4" 2>"$D/small.m4e" )
( cd "$C/include" && timeout -k 5 120 "$B/scrip" --run -d512m -i64m -s256m "$D/claws5.sno" < "$C/demos/snobol4/claws5/claws5.input" > "$D/claws5.m3" 2>/dev/null )
m4bin claws5 && ( cd "$C/include" && timeout -k 5 120 "$D/claws5.bin" -d512m -i64m -s256m < "$C/demos/snobol4/claws5/claws5.input" > "$D/claws5.m4" 2>/dev/null )
for m in m3 m4; do
    if [ -f "$D/small.$m" ] && cmp -s "$D/small.want" "$D/small.$m"; then arm "small $m (the guard skips the remap, INPUT stays the built-in)" ok
    else arm "small $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/small.$m")] $(head -1 "$D/small.${m}e" 2>/dev/null | cut -c1-80) want [$(tr '\n' '|' < "$D/small.want")]"; fi
    if [ -f "$D/claws5.$m" ] && cmp -s "$D/claws5.$m" "$C/demos/snobol4/claws5/claws5.ref"; then arm "claws5 $m with the io.inc layer in front prints its ref" ok
    else arm "claws5 $m" "differs from claws5.ref"; fi
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): an OPSYN of a built-in that a guard skips leaves the built-in callable -- the corpus io.inc layer is inert, as under SPITBOL -- both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
