#!/usr/bin/env bash
# test_gate_pl_an_int64_overflow_promotes_to_the_bignum_core_instead_of_raising.sh -- PROLOG ISO LADDER (cto, 2026-09-13).
# THE SUBJECT: every arithmetic site that raises evaluation_error(int_overflow) where the oracle PROMOTES to the
# bignum core this tree already carries. The population is ENUMERABLE BY GREP and that is deliberate: it is
# exactly the set of lines matching rt_pl_ball_eval_error("int_overflow", ...) -- 8 lines across
# src/runtime/by_name_dispatch.c and src/runtime/unification.c, covering neg/1 abs/1 //2 div/2 +/2 -/2 */2
# succ/2 plus/3. A class defined by a property nobody can grep is a class that grades itself green.
# ⛔ THE ROW THAT MINTED THIS GATE SAID THE CLASS WAS ONE VALUE WIDE. THAT WAS FALSE AND ARM b IS WHY:
# 9223372036854775807 + 1 needs no INT64_MIN, was reachable from an ordinary literal long before the rung-8
# negative-literal cure, and raises today. The five INT64_MIN witnesses are a CORNER of the class -- the corner
# the reader cure made reachable -- not the class. Arm a is that corner; arm b is the general case; arm c is the
# two predicate sites, which are in the population by the same grep and answer the same way in the oracle.
# ⛔ THE ARMS DISCRIMINATE, THEY ARE NOT A TRIPWIRE (cto's law THE UNEXPLAINED GREEN, hq_B's two-lever bar):
# arms a-c are the subject; arms d-f are CONTROLS THAT PASS IN BOTH TREES -- the three readings that were always
# correct at INT64_MIN (sign, +1, comparison), in-range arithmetic that must not change representation, and the
# wide-literal path rung 8 already holds. A regression in bignum.c lights d-f; a regression in the guards lights
# only a-c. So this gate names WHICH half moved, and a cure that promotes by widening every integer to DT_BIG
# lights arm e rather than passing.
# THE ORACLE IS swipl 9, and every want_out below is CUT FROM IT, never from our output.
# ⛔ RED BEFORE, on the clean origin build 8f7f0d394, m3 AND m4: arm a died at the first goal with
#   error(evaluation_error(int_overflow),context(abs/1,_G0)), arm b with context(+/2,_G0), arm c with
#   context(succ/2,_G0); arms d, e and f were GREEN in that same tree.
# ⛔ ARM g EXISTS BECAUSE THE SUITE DID NOT MOVE. With arms a-f green the Logtalk unbounded family still read
# 82/111, and an unexplained NO-MOVE owes an attribution exactly as much as an unexplained green does. Naming
# its reds found succ_01/02 and plus_01/02/03 failing with type_error(integer, <bignum>): the INPUT side of the
# same two predicates arms c had just cured on the OUTPUT side. THE GREP-DEFINED POPULATION WAS UNDER-
# APPROXIMATED -- defining the class by the lines that RAISE int_overflow found every site that raises and no
# site that refuses, and for succ/2 and plus/3 those are two halves of one predicate. Shipping a-f alone would
# have left both predicates promoting a result they would refuse as an argument.
set -u
GATE_NAME=test_gate_pl_an_int64_overflow_promotes_to_the_bignum_core_instead_of_raising
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
MODES="${PL_RUNG_MODES:-m3,m4}"
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0; total=0
run_m3() { timeout -k 5 20 "$SCRIP" "$1" </dev/null 2>"$TMPD/err"; }
run_m4() {
    local src="$1" s="$TMPD/w.s" b="$TMPD/w.bin"
    timeout -k 5 60 "$SCRIP" --compile --out="$s" "$src" </dev/null 2>"$TMPD/err" || { echo "  (m4: compile failed: $(head -c 160 "$TMPD/err"))"; return 97; }
    gcc -m64 -no-pie "$s" -o "$b" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  (m4: link failed: $(head -c 160 "$TMPD/err"))"; return 98; }
    timeout -k 5 20 "$b" </dev/null 2>"$TMPD/err"
}
arm() {
    local name="$1" src="$2" want_out="$3" mode got rc
    for mode in m3 m4; do
        case "$MODES" in *"$mode"*) : ;; *) continue ;; esac
        total=$((total+1))
        got="$("run_$mode" "$src")"; rc=$?
        if [ "$got" = "$want_out" ] && [ "$rc" = "0" ]; then echo "  ok  $name $mode"
        else echo "  RED $name $mode: rc=$rc want 0; out=[$got] want [$want_out] $(head -c 200 "$TMPD/err" 2>/dev/null)"; red=$((red+1)); fi
    done
}
cat > "$TMPD/a.pl" <<'EOP'
:- initialization(main).
main :- X = -9223372036854775808,
    A is abs(X), write(a(A)), nl,
    B is -(X), write(b(B)), nl,
    C is X * -1, write(c(C)), nl,
    D is X // -1, write(d(D)), nl,
    E is 0 - X, write(e(E)), nl,
    halt.
EOP
arm subject_a_the_int64_min_corner_promotes "$TMPD/a.pl" "$(printf '%s\n' \
    'a(9223372036854775808)' 'b(9223372036854775808)' 'c(9223372036854775808)' \
    'd(9223372036854775808)' 'e(9223372036854775808)')"
cat > "$TMPD/b.pl" <<'EOP'
:- initialization(main).
main :-
    A is 9223372036854775807 + 1, write(a(A)), nl,
    B is 9223372036854775807 * 9223372036854775807, write(b(B)), nl,
    C is -9223372036854775807 - 10, write(c(C)), nl,
    D is 4611686018427387904 * 4, write(d(D)), nl,
    halt.
EOP
arm subject_b_the_general_overflow_promotes_both_directions "$TMPD/b.pl" "$(printf '%s\n' \
    'a(9223372036854775808)' 'b(85070591730234615847396907784232501249)' \
    'c(-9223372036854775817)' 'd(18446744073709551616)')"
cat > "$TMPD/c.pl" <<'EOP'
:- initialization(main).
main :-
    succ(9223372036854775807, A), write(a(A)), nl,
    plus(9223372036854775807, 1, B), write(b(B)), nl,
    halt.
EOP
arm subject_c_the_two_predicate_sites_promote "$TMPD/c.pl" "$(printf '%s\n' \
    'a(9223372036854775808)' 'b(9223372036854775808)')"
cat > "$TMPD/d.pl" <<'EOP'
:- initialization(main).
main :- X = -9223372036854775808,
    A is sign(X), write(a(A)), nl,
    B is X + 1, write(b(B)), nl,
    ( X < 0 -> write(c(yes)) ; write(c(no)) ), nl,
    halt.
EOP
arm control_d_the_three_int64_min_readings_that_were_always_right "$TMPD/d.pl" "$(printf '%s\n' \
    'a(-1)' 'b(-9223372036854775807)' 'c(yes)')"
cat > "$TMPD/e.pl" <<'EOP'
:- initialization(main).
main :-
    A is 2 + 2, write(a(A)), nl,
    B is 7 // 2, write(b(B)), nl,
    C is -7 // 2, write(c(C)), nl,
    D is 7 mod -2, write(d(D)), nl,
    E is abs(-5), write(e(E)), nl,
    F is 0 - 5, write(f(F)), nl,
    G is 6 * 7, write(g(G)), nl,
    ( integer(42) -> write(h(yes)) ; write(h(no)) ), nl,
    succ(3, I), write(i(I)), nl,
    plus(3, 4, J), write(j(J)), nl,
    halt.
EOP
arm control_e_in_range_arithmetic_does_not_change_representation "$TMPD/e.pl" "$(printf '%s\n' \
    'a(4)' 'b(3)' 'c(-3)' 'd(-1)' 'e(5)' 'f(-5)' 'g(42)' 'h(yes)' 'i(4)' 'j(7)')"
cat > "$TMPD/f.pl" <<'EOP'
:- initialization(main).
main :-
    A is 123456789012345678901234567890 * 2, write(a(A)), nl,
    B is -123456789012345678901234567890, write(b(B)), nl,
    C is 123456789012345678901234567890 // 123456789012345678901234567890, write(c(C)), nl,
    halt.
EOP
arm control_f_the_wide_literal_path_rung_8_already_holds "$TMPD/f.pl" "$(printf '%s\n' \
    'a(246913578024691357802469135780)' 'b(-123456789012345678901234567890)' 'c(1)')"
cat > "$TMPD/g.pl" <<'EOP'
:- initialization(main).
main :-
    succ(123456789012345678901234567890, A), write(a(A)), nl,
    succ(B, 123456789012345678901234567891), write(b(B)), nl,
    plus(123456789012345678901234567890, 1, C), write(c(C)), nl,
    plus(123456789012345678901234567890, D, 987654321098765432109876543210), write(d(D)), nl,
    plus(E, 1, 123456789012345678901234567890), write(e(E)), nl,
    ( succ(X, 0) -> write(f(X)) ; write(f(fail)) ), nl,
    halt.
EOP
arm subject_g_succ_and_plus_accept_a_bignum_argument "$TMPD/g.pl" "$(printf '%s\n' \
    'a(123456789012345678901234567891)' 'b(123456789012345678901234567890)' \
    'c(123456789012345678901234567891)' 'd(864197532086419753208641975320)' \
    'e(123456789012345678901234567889)' 'f(fail)')"
echo "[$GATE_NAME] $((total-red))/$total arms green (modes: $MODES)"
[ "$red" -eq 0 ] || { echo "GATE FAIL($red) [$GATE_NAME]"; exit 1; }
echo "GATE PASS(0) [$GATE_NAME]"
