#!/usr/bin/env bash
# test_gate_pl_a_big_integer_past_the_double_range_raises_float_overflow.sh -- float/1, exp/1, log/1 AND sqrt/1 OF A BIG INTEGER PAST THE DOUBLE RANGE RAISE evaluation_error(float_overflow) (ISO 9.1.4.1; Logtalk unbounded float_03, exp_01, log_01, sqrt_01).
# hq_prolog 2026-09-25, CEO-1270; the cure is by_name_dispatch.c: pl_big_as_real converted a big integer by printing it to decimal and running
# strtod -- quadratic in its digits, and on 7^7^7's 695,975 digits it returned inf SILENTLY, which pl_ax_float_result will not call an overflow
# because its input was already infinite. A big integer past 1025 bits now converts to +-inf from its limb count (bignum.c rt_big_bits), anything
# in range keeps the exact decimal path (so no printed float moves by an ulp), and the unary path raises float_overflow when a big operand
# converts to inf after the big-integer ops (sign, abs, ...) have had their turn. NO MONITOR BRACKET: error expectations. THE ORACLE IS swipl
# (gprolog's integers are bounded). RED BEFORE on origin, m3 AND m4: the four 7^823543 lines and float(2^1024) printed a float or nothing.
set -u
GATE_NAME=test_gate_pl_a_big_integer_past_the_double_range_raises_float_overflow
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/w.pl" <<'EOP'
t(G) :- catch((X is G, write(X)), error(E, _), write(E)), nl.
main :- B is 7^823543, t(float(B)), t(exp(B)), t(log(B)), t(sqrt(B)), t(float(2^1023)), t(float(2^1024)), t(float(-(2^2000))), t(sign(B)), t(abs(-(2^70))), t(float(2^80)).
:- initialization(main).
EOP
want='evaluation_error(float_overflow)
evaluation_error(float_overflow)
evaluation_error(float_overflow)
evaluation_error(float_overflow)
8.98846567431158e+307
evaluation_error(float_overflow)
evaluation_error(float_overflow)
1
1180591620717411303424
1.2089258196146292e+24'
red=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 20 "$SCRIP" w.pl </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 60 "$SCRIP" --compile -o "$TMPD/w.s" "$TMPD/w.pl" </dev/null 2>"$TMPD/err" || refuse "m4 compile failed: $(head -c 160 "$TMPD/err")"
        gcc -m64 -no-pie "$TMPD/w.s" -o "$TMPD/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link failed: $(head -c 160 "$TMPD/err")"
        got="$(cd "$TMPD" && timeout -k 5 20 ./w.bin </dev/null 2>"$TMPD/err")"; rc=$?
        rm -f "$TMPD/w.s" "$TMPD/w.bin"
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $mode"
    else echo "  RED $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-200)] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red mode(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: a big integer past the double range raises float_overflow, one in range converts exactly, both modes as swipl"
exit 0
