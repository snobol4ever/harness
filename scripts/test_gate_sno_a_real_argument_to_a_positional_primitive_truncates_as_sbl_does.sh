#!/usr/bin/env bash
# test_gate_sno_a_real_argument_to_a_positional_primitive_truncates_as_sbl_does.sh -- the argument of LEN, POS, RPOS, TAB and RTAB is converted to an
# integer the way sbl -bf converts it: a REAL (or a string that reads as a real) is TRUNCATED toward zero, so 'v66' ? RTAB(2.5) matches 'v' where SCRIP
# raised error 181 (TAB 183, POS 162, RPOS 185, LEN 120): rt_coerce_int_d took only an integral real and an integer string, and rt_pat_prim_int_take (the
# deferred *X road) took a real but not a real string. The same conversion decides the other two answers, which are NOT the "not an integer" error: a
# negative result (after truncation: -0.5 is 0, -1.5 is -1) is the primitive's "negative or too large" error, and a real past the integer range is that
# same error, while a non-numeric string stays the "not an integer" error.
# Row snobol4-a-real-argument-to-tab-rtab-pos-rpos-or-len-is-truncated-to-an-integer-by-sbl-where-scrip-raises-181 (CEO-1489 probes, hq_snobol4).
#
# THE WITNESSES (each its own program over the subject 'v66', every answer cut from sbl -bf at run time and reduced to MATCH <capture> | FAIL | error N):
#   w01 RTAB(2.5)  w02 TAB(1.9)  w03 POS(0.5)  w04 RPOS(2.7)  w05 LEN(1.5)        literal reals, one per primitive
#   w06 LEN(R) R=2.5   w07 TAB(S) S='1.5'                                          a variable real, a variable string that reads as a real
#   w08 LEN(-0.5) = 0   w09 LEN(-1.5) error 121   w10 POS(1E30) error 163           truncation toward zero, then the negative / too-large error
#   w11 RTAB('abc') error 181                                                      a non-numeric string stays the not-an-integer error
#   w12 LEN(*R) R=2.5   w13 TAB(*S) S='1.5'                                        the deferred roads
# arm 0 (CEO-1680, a proper test, no seam): the comparator grades a corrupted copy of sbl's answer and must read it RED.
set -u
G=test_gate_sno_a_real_argument_to_a_positional_primitive_truncates_as_sbl_does
HERE="$(cd "$(dirname "$0")" && pwd)"; SD="$HERE/../../SCRIP"; SCRIP="$SD/scrip"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2) [$G]: no scrip binary at $SCRIP -- build first (make)"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" "$SCRIP" "${RT_DIR:-$SD/out}/libscrip_rt.so" || exit 2
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "⛔ REFUSE(rc=2) [$G]: no correctness oracle ($SBL) -- the ref is cut from the oracle at run time, never typed"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
names="w01 w02 w03 w04 w05 w06 w07 w08 w09 w10 w11 w12 w13"
prog() { : > "$W/$1.sno"; [ -n "$2" ] && printf ' %s\n' "$2" >> "$W/$1.sno"; printf " 'v66' ? %s . X :S(Y)F(N)\nY\tOUTPUT = 'MATCH ' X\t:(END)\nN\tOUTPUT = 'FAIL'\nEND\n" "$3" >> "$W/$1.sno"; }
prog w01 "" "RTAB(2.5)"
prog w02 "" "TAB(1.9)"
prog w03 "" "POS(0.5)"
prog w04 "" "RPOS(2.7)"
prog w05 "" "LEN(1.5)"
prog w06 "R = 2.5" "LEN(R)"
prog w07 "S = '1.5'" "TAB(S)"
prog w08 "" "LEN(-0.5)"
prog w09 "" "LEN(-1.5)"
prog w10 "" "POS(1E30)"
prog w11 "" "RTAB('abc')"
prog w12 "R = 2.5" "LEN(*R)"
prog w13 "S = '1.5'" "TAB(*S)"
norm() { grep -o -i -E 'MATCH.*|FAIL|error 0*[0-9]+' | head -1 | sed -E 's/[Ee][Rr][Rr][Oo][Rr] 0*/error /'; }
for n in $names; do
    w="$(cd "$W" && timeout -k 5 20 "$SBL" $(sbl_lang_flags) "$n.sno" </dev/null 2>&1 | norm)"
    [ -n "$w" ] || { echo "⛔ REFUSE(rc=2) [$G]: the oracle printed nothing gradable for $n"; exit 2; }
    printf '%s' "$w" > "$W/$n.want"
    (cd "$W" && timeout -k 5 60 "$SCRIP" --compile -o "$n.s" "$n.sno" </dev/null >/dev/null 2>&1) \
        && gcc -no-pie "$W/$n.s" -L"$SD/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$SD/out" -o "$W/$n.bin" 2>/dev/null \
        || { echo "⛔ REFUSE(rc=2) [$G]: $n did not compile and link in mode 4"; exit 2; }
done
grade() { [ "$1" = "$2" ]; }
w1want="$(cat "$W/w01.want")"; bad="X$w1want"
grade "$w1want" "$bad" && { echo "⛔ REFUSE(rc=2) [$G]: arm 0 -- the comparator read a corrupted ref ('$bad') as GREEN; it cannot fail"; exit 2; }
echo "== [$G] a real argument to a positional primitive, graded against $SBL"
echo "  PASS arm0 the comparator reads a corrupted ref ('$bad') RED"
fail=0
for n in $names; do
    want="$(cat "$W/$n.want")"
    v3="$(cd "$W" && timeout -k 5 20 "$SCRIP" "$n.sno" </dev/null 2>&1 | norm)"
    v4="$(cd "$W" && timeout -k 5 20 "$W/$n.bin" -- </dev/null 2>&1 | norm)"
    for m in m3 m4; do
        v="$v3"; [ "$m" = m4 ] && v="$v4"
        if grade "$v" "$want"; then echo "  PASS $n $m = sbl ($want)"; else echo "  ⛔ $n $m RED: got '$v', sbl '$want'"; fail=1; fi
    done
done
[ "$fail" = 0 ] && { echo "OK [$G]: a real argument to LEN, POS, RPOS, TAB and RTAB is truncated as sbl truncates it, both modes, literal, variable and deferred"; exit 0; }
echo "⛔ GATE RED [$G]: a real argument to a positional primitive does not answer as sbl"; exit 1
