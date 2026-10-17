#!/usr/bin/env bash
# test_gate_pl_ieee_float_flags_and_ceil_lgamma_powm_answer_as_swipl.sh
#
# THE ROW: prolog-swi-ieee-float-flags-and-the-evaluables-ceil-lgamma-powm (cfo). SWI's three IEEE float flags --
# float_overflow (error|infinity), float_zero_div (error|infinity), float_undefined (error|nan) -- steer the evaluator:
# an infinite result raises float_overflow unless the flag says infinity; a division by zero raises zero_divisor unless
# float_zero_div says infinity (0/0 and 0.0/0.0 are undefined, never infinite); an undefined result (0.0/0.0, sqrt of a
# negative, asin(2.0), a negative base to a fractional power) raises undefined unless float_undefined says nan. ceil/1 is
# ceiling/1, lgamma/1 is C's lgamma (a pole is float_overflow), powm/3 is modular exponentiation with swipl's type and
# domain errors. Infinities and NaN print as swipl spells them: 1.0Inf, -1.0Inf, 1.5NaN.
#
# THE ARM: one program, both modes, every line written out from swipl 2026-10-07 (the flags persist down the program, as
# in swipl). Line 9 holds the type_error(integer, 2.0) swipl raises; swipl itself then prints a stale 2 because its
# foreign powm/3 did not clear the exception (its own warning says so). rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/f.pl" <<'PL'
:- initialization(main).
r(N, G) :- catch((G -> true ; write(false)), error(E, _), writeq(E)), write(' '), write(N), nl.
main :-
  r(1, (X1 is ceil(2.5), writeq(X1))),
  r(2, (X2 is lgamma(3.0), Y2 is round(X2*1000), writeq(Y2))),
  r(3, (X3 is lgamma(0.0), writeq(X3))),
  r(4, (X4 is powm(2, 10, 1000), writeq(X4))),
  r(5, (X5 is powm(3, 200, 1000007), writeq(X5))),
  r(6, (X6 is powm(12345678901234567890, 3, 1000000007), writeq(X6))),
  r(7, (X7 is powm(2, -1, 7), writeq(X7))),
  r(8, (X8 is powm(2, 10, 0), writeq(X8))),
  r(9, (X9 is powm(2.0, 10, 7), writeq(X9))),
  r(10, (X10 is 0.0/0.0, writeq(X10))),
  r(11, (X11 is 1/0.0, writeq(X11))),
  r(12, (X12 is 10.0**400, writeq(X12))),
  r(13, (X13 is 2+inf, writeq(X13))),
  r(14, (X14 is inf, Y14 is nan, Z14 is -inf, writeq(X14), write(' '), print(Y14), write(' '), write(Z14))),
  r(15, (set_prolog_flag(float_zero_div, infinity), X15 is 1/0.0, writeq(X15))),
  r(16, (X16 is -1/0.0, writeq(X16))),
  r(17, (X17 is 1/0, writeq(X17))),
  r(18, (X18 is 0.0/0.0, writeq(X18))),
  r(19, (set_prolog_flag(float_undefined, nan), X19 is 0.0/0.0, writeq(X19))),
  r(20, (X20 is sqrt(-1.0), writeq(X20))),
  r(21, (X21 is asin(2.0), writeq(X21))),
  r(22, (set_prolog_flag(float_overflow, infinity), X22 is 10.0**400, writeq(X22))),
  r(23, (X23 is exp(1000), writeq(X23))),
  r(24, (current_prolog_flag(float_overflow, V24), current_prolog_flag(float_zero_div, W24), current_prolog_flag(float_undefined, U24), writeq(V24/W24/U24))),
  halt.
PL
cat > "$D/f.want" <<'WANT'
3 1
693 2
evaluation_error(float_overflow) 3
24 4
959082 5
753508595 6
domain_error(not_less_than_zero,-1) 7
domain_error(not_less_than_one,0) 8
type_error(integer,2.0) 9
evaluation_error(undefined) 10
evaluation_error(zero_divisor) 11
evaluation_error(float_overflow) 12
evaluation_error(float_overflow) 13
1.0Inf 1.5NaN -1.0Inf 14
1.0Inf 15
-1.0Inf 16
1.0Inf 17
evaluation_error(undefined) 18
1.5NaN 19
1.5NaN 20
1.5NaN 21
1.0Inf 22
1.0Inf 23
infinity/infinity/nan 24
WANT
( cd "$D" && timeout -k 5 30 "$B/scrip" f.pl < /dev/null > f.m3 2>/dev/null )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o f.s f.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie f.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o f.bin 2>/dev/null ) || refuse "f.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 30 ./f.bin < /dev/null > f.m4 2>/dev/null )
red=0
for m in m3 m4; do
    if cmp -s "$D/f.want" "$D/f.$m"; then echo "  ok   $m: 24 of 24 lines as swipl"
    else echo "  FAIL $m: $(diff "$D/f.want" "$D/f.$m" | grep -c '^<') of 24 lines differ: $(diff "$D/f.want" "$D/f.$m" | grep '^>' | head -4 | tr '\n' ' ')"; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): the IEEE float flags, ceil/1, lgamma/1 and powm/3 answer as swipl in both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 2 mode(s) diverge"; exit 1
