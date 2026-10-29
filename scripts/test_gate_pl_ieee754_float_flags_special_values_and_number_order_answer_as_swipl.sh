#!/usr/bin/env bash
# test_gate_pl_ieee754_float_flags_special_values_and_number_order_answer_as_swipl.sh -- IN THE SWI DIALECT THE FLOAT FLAGS, C11 ANNEX F
# SPECIAL VALUES, roundtoward/2, float_class/2, bounded_number/3 AND THE STANDARD ORDER OF NUMBERS ANSWER AS swipl (cfo 2026-10-14, row
# prolog-swi-rational-test-ieee754-every-case-agrees-with-swipl-in-both-modes-ceo-1664, CEO-1698).
#
# SWI's rational/test_ieee754.pl read 24/45 in both modes. The cures, each in src/runtime unless named: (1) the flags float_underflow
# (error|ignore) and float_rounding (to_nearest|to_positive|to_negative|to_zero, set through fesetround), the read-only
# max_tagged_integer, min_tagged_integer, float_max, float_min and float_max_integer, and in the SWI dialect current_prolog_flag/2 of
# an unknown flag FAILS as swipl does (ISO's domain_error stays outside it); the lowerer's current_prolog_flag(F, V) enumeration
# (lower_prolog.c) is a '$flag_member'/2 walk of the flag list now -- its one-branch-per-flag disjunction passed the IR's 32-branch
# limit once the table grew; (2) the evaluator (by_name_dispatch.c), SWI dialect: log/log10/log2/atanh/acosh/asin/acos/atan2 answer
# their C11 value through the float flags (an infinite result is float_overflow, a NaN undefined), ceiling/floor/round/truncate of
# an infinite or NaN float is that float, X ** 0 is the integer 1, 0.0 ** -1 is zero_divisor, a rational divided by 0 follows
# float_zero_div, float_fractional_part is modf, min/max break a tie by the standard order, a negative base to a rational power
# with an odd denominator is the real root, and roundtoward(E, Mode) evaluates E under Mode -- the rational exponent of a float
# power taken at nearest and the root's rounding mirrored when its sign flips; in every dialect: nan is the positive NaN (it was
# 0.0/0.0, whose sign bit made copysign(0.0, nan) -0.0), sign(nan) is NaN, erf/1 and erfc/1 are evaluable, an integer of 2^1024 or
# more converts to an infinity in every rounding mode; (3) both C unifiers (unification.c plc_unify_leaf, by_name_dispatch.c
# plw_unify_leaf) unify a NaN with a NaN and never 0.0 with -0.0, as the emitted unifier already did (sort/2 into a bound list
# with a NaN failed); (4) the standard order (unification.c): NaN precedes every number, and in the SWI dialect numbers compare by
# value, a float before an integer of equal value and -0.0 before 0.0 (gprolog's floats-before-integers stays outside it);
# (5) the writer puts a space before -0.0 after an infix minus; (6) float_class/2 and bounded_number/3 are base-prelude predicates.
# NOT HERE: swipl's default-flag answers for an infinite ARGUMENT (erf(inf), 1.0 ** inf, inf / 0 raise float_overflow there, SCRIP
# computes them), a directed-rounding root that swipl rounds one ulp further, the shortest-digit printing of a subnormal or of
# 9.007199254740992e+15, and -(1) written as `- 1`.
#
# THE ARMS: one program, fifty-seven lines, stdout cut against swipl in this run, mode 3 and mode 4. FAIL-ONCE, measured on the parent
# b370b6a00 rebuilt: 41 of 57 lines differ in both modes; with the cure 57 of 57 as swipl.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_ieee754_float_flags_special_values_and_number_order_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- module(w, []).
:- initialization(main).
e(N, X) :- catch((Y is X, R = Y), error(E, _), R = err(E)), writeq(N-R), nl.
t(N, G) :- catch((G -> R = yes ; R = no), error(E, _), R = err(E)), writeq(N-R), nl.
main :- e(default_sign_nan, sign(nan)), e(default_log0, log(0.0)), e(default_pow_zero_neg, 0.0 ** -1), e(default_acos2, acos(2)),
    t(underflow_flag, (current_prolog_flag(float_underflow, U), U == ignore, set_prolog_flag(float_underflow, error), set_prolog_flag(float_underflow, U))),
    t(rounding_flag, (current_prolog_flag(float_rounding, R0), R0 == to_nearest, set_prolog_flag(float_rounding, to_zero), current_prolog_flag(float_rounding, to_zero), set_prolog_flag(float_rounding, R0))),
    t(unknown_flag_fails, \+ current_prolog_flag(no_such_flag_x, _)), t(tagged, (current_prolog_flag(max_tagged_integer, M), integer(M), M > 0)),
    t(float_max, (current_prolog_flag(float_max, FM), FM =:= 1.7976931348623157e308)), t(flags_enumerate, (findall(F, current_prolog_flag(F, _), Fs), memberchk(float_rounding, Fs), memberchk(bounded, Fs))),
    forall(member(F-V, [float_overflow-infinity, float_zero_div-infinity, float_undefined-nan]), set_prolog_flag(F, V)),
    forall(member(N-X, [sign_nan-sign(nan), ceiling_inf-ceiling(inf), floor_nan-floor(nan), round_ninf-round(-inf), truncate_inf-truncate(inf), log0-log(0.0), log10_m0-log10(-0.0),
        atanh1-atanh(1.0), atan2_00-atan2(0.0,0.0), atan2_m0m0-atan2(-0.0,-0.0), pow_inf_0-(inf**0.0), pow_nan_0-(nan**0.0), pow_0_neg-(0.0** -1), div_int_0-(1/0), div_rat_0-(-1r2/0),
        ffp_m0-float_fractional_part(-0.0), ffp_inf-float_fractional_part(inf), ffp_minf-float_fractional_part(-inf), copysign_0_nan-copysign(0.0,nan), copysign_nan-copysign(nan,-0.0), erf1-erf(1.0),
        max_m0_0-max(-0.0,0), max_m0_p0-max(-0.0,0.0), min_0_m0-min(0,-0.0), root3_neg-(-8.0**1r3), root3_neg_sq-(-8.0**2r3), root_even_neg-(-4.0**3r2), rt_up-roundtoward(1/3, to_positive),
        rt_down-roundtoward(1/3, to_negative), rt_neg_root_up-roundtoward(-2.0**1r3, to_positive), rt_small_root_up-roundtoward(0.0002**1r3, to_positive),
        big_below_overflow_down-roundtoward(float(2^1024-1), to_negative), big_overflow_down-roundtoward(float(2^1024), to_negative), neg_big_overflow_up-roundtoward(float(-(2^1024)), to_positive)]), e(N, X)),
    X1 is -0.0, I is inf, NI is -inf, NN is nan, msort([I, 0.0, X1, NI, NN, 0, -1], L1), writeq(msort-L1), nl,
    findall(O, (member(A-B, [NN-0.0, X1-0.0, X1-0, 0.0-0, 0-0.0]), compare(O, A, B)), Os), writeq(compare-Os), nl,
    t(sort_bound_nan, sort([1.0Inf, 0.0, -0.0, -1.0Inf, 1.5NaN], [1.5NaN, -1.0Inf, -0.0, 0.0, 1.0Inf])), t(sort_bound_zero_sign, sort([0.0], [-0.0])),
    findall(C, (member(Z0, [1.0, 0.0, -0.0, inf, nan, -inf, 1.0e-310]), Z is Z0, float_class(Z, C)), Cs), writeq(float_class-Cs), nl, t(float_class_int, float_class(1, _)),
    t(bounded_ints, bounded_number(0, 10, 1)), t(bounded_rat_out, \+ bounded_number(0, 1r2, 1)), t(bounded_int_fill, (bounded_number(L2, H2, -1), [L2, H2] == [-2, 0])),
    t(bounded_float_fill, (bounded_number(L3, H3, -1.0), [L3, H3] == [-1.0000000000000002, -0.9999999999999999])), t(bounded_inf, \+ bounded_number(_, _, I)), t(bounded_nan, \+ bounded_number(_, _, NN)),
    writeq(spacing-(a - X1)), nl.
PL
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>/dev/null | grep .)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 57 ] || refuse "swipl did not answer the fifty-seven lines: [$want]"
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 ) || refuse "mode 4 compile failed"
( cd "$D" && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || refuse "mode 4 link failed"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^>')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 57 of 57 lines as swipl"
    else echo "  $label RED: $n of 57 lines differ from swipl"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
arm m4 timeout -k 5 20 ./w.bin < /dev/null
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
