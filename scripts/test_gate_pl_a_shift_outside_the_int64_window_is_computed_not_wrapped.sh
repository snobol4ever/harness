#!/usr/bin/env bash
# test_gate_pl_a_shift_outside_the_int64_window_is_computed_not_wrapped.sh -- PROLOG ISO LADDER (cto, 2026-09-13).
# THE SUBJECT: (<<)/2 and (>>)/2 were implemented for ONE window only -- a shift count in 0..62 with a result that
# fits int64 -- and every input outside that window was wrong in one of THREE ways, all from the same two lines of
# src/runtime/by_name_dispatch.c. The class is NOT "the shifts raise on bignums"; that is the face the Logtalk
# suite happened to show. Named by the property instead -- what does this operator do outside its window -- the
# census is: (1) a bignum operand raises type_error(integer, <bignum>) because pl_big_binop carried no shl/shr
# clause; (2) an int64 pair whose result exceeds int64 SILENTLY WRAPS, so 1 << 64 answered 1; (3) a count outside
# 0..63, negative counts included, evaluated C's undefined shift and returned whatever the hardware's masked
# count produced, so 1 << (-2) answered 4611686018427387904. Face (2) and face (3) have NO witness anywhere in
# the Logtalk unbounded family -- curing only what the suite could see would have shipped a silent wrong answer
# for 1 << 64 with the row marked green.
# ⛔ THE TWO FACES THE SUITE CANNOT SEE ARE WHY ARMS b AND c EXIST, and they are the ones to keep if this gate is
# ever trimmed: a raising operator announces itself and gets a row, a wrapping one is indistinguishable from a
# correct answer at the call site.
# THE ORACLE IS swipl 9 (unbounded integers), and every want_out below is CUT FROM IT, never from our output.
# ⛔ RED BEFORE, MEASURED not predicted, on clean origin 4b65bca4e with this cure stashed AND THE TREE REBUILT
# (these arms execute the binary, so a stash without a rebuild would have graded the cured build), m3 AND m4:
#   arm a printed NOTHING and died at the first goal with error(type_error(integer,123456789012345678901234567890),_G0);
#   arm b printed a(1) b(-9223372036854775808) c(-4611686018427387904) d(-64) where the oracle answers
#     a(18446744073709551616) b(9223372036854775808) c(13835058055282163712) d(-1180591620717411303424);
#   arm c printed a(4611686018427387904) b(0) and then died on the bignum goal;
#   arms d and e were GREEN in that tree; ARM f WAS RED, AND I HAD WRITTEN THAT IT WOULD BE GREEN.
# ⛔⭐ ARM f IS A SUBJECT ARM, NOT A CONTROL, AND ITS FIRST GOAL IS THE REASON THIS GATE IS WORTH READING.
# I classified it as a control from the armchair and the measurement said otherwise. Worse than the
# misclassification is WHY its first goal passed on the uncured tree: (1 << 100) >> 100 answered 1 there too,
# because << wrapped the count to 100-64=36 and >> masked its own count the same way, and THE TWO DEFECTS
# CANCELLED. A round-trip identity is the test everyone reaches for first on a pair of inverse operators, and
# on this defect it is blind in both modes -- it asks whether << and >> AGREE, never whether either is RIGHT.
# Goal a is kept exactly as it was, green in both trees, as the standing demonstration; goals b, c and e are
# what makes arm f discriminate. ⛔ A TEST THAT TWO WRONGS CAN SATISFY IS NOT A WEAK TEST, IT IS AN UNREAD ONE.
# ⛔ WHAT THIS CURE DOES NOT CLAIM, NAMED RATHER THAN LEFT TO BE DISCOVERED: a shift COUNT that is itself a bignum
# (1 << 10000000000000000000000) still raises type_error(integer, <bignum>) where swipl raises resource_error --
# this tree has no resource_error vocabulary at all (grep: zero sites), and inventing one is a policy decision,
# not this bug. A count above 2^20 with a bignum operand declines to the old path for the same reason: the honest
# answer needs a bit-length accessor bignum.c does not export, and returning the sign bit would be a guess that
# is wrong for any operand wider than the count. Both remainders are outside every arm below BY CONSTRUCTION.
set -u
GATE_NAME=test_gate_pl_a_shift_outside_the_int64_window_is_computed_not_wrapped
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
main :-
    A is 123456789012345678901234567890 << 24, write(a(A)), nl,
    B is 2071261215926550121592655012157194240 >> 24, write(b(B)), nl,
    C is -123456789012345678901234567890 >> 4, write(c(C)), nl,
    D is 123456789012345678901234567890 << 0, write(d(D)), nl,
    halt.
EOP
arm subject_a_a_bignum_operand_is_shifted_not_refused "$TMPD/a.pl" "$(printf '%s\n' \
    'a(2071261215926550121592655012157194240)' 'b(123456789012345678901234567890)' \
    'c(-7716049313271604931327160494)' 'd(123456789012345678901234567890)')"
cat > "$TMPD/b.pl" <<'EOP'
:- initialization(main).
main :-
    A is 1 << 64, write(a(A)), nl,
    B is 1 << 63, write(b(B)), nl,
    C is 3 << 62, write(c(C)), nl,
    D is -1 << 70, write(d(D)), nl,
    halt.
EOP
arm subject_b_an_int64_left_shift_that_overflows_promotes_instead_of_wrapping "$TMPD/b.pl" "$(printf '%s\n' \
    'a(18446744073709551616)' 'b(9223372036854775808)' 'c(13835058055282163712)' 'd(-1180591620717411303424)')"
cat > "$TMPD/c.pl" <<'EOP'
:- initialization(main).
main :-
    A is 1 << (-2), write(a(A)), nl,
    B is 16 >> (-2), write(b(B)), nl,
    C is 123456789012345678901234567890 << (-4), write(c(C)), nl,
    D is 5 >> 200, write(d(D)), nl,
    E is -5 >> 200, write(e(E)), nl,
    halt.
EOP
arm subject_c_a_count_outside_zero_to_sixty_three_is_arithmetic_not_hardware "$TMPD/c.pl" "$(printf '%s\n' \
    'a(0)' 'b(64)' 'c(7716049313271604931327160493)' 'd(0)' 'e(-1)')"
cat > "$TMPD/d.pl" <<'EOP'
:- initialization(main).
main :-
    A is 12345 >> 3, write(a(A)), nl,
    B is -12345 >> 3, write(b(B)), nl,
    C is 1 << 62, write(c(C)), nl,
    D is 1024 >> 10, write(d(D)), nl,
    E is 1 << 10, ( E == 1024 -> write(e(narrow)) ; write(e(wide)) ), nl,
    halt.
EOP
arm control_d_a_shift_inside_the_window_does_not_change_answer_or_representation "$TMPD/d.pl" "$(printf '%s\n' \
    'a(1543)' 'b(-1544)' 'c(4611686018427387904)' 'd(1)' 'e(narrow)')"
cat > "$TMPD/e.pl" <<'EOP'
:- initialization(main).
main :-
    A is 123456789012345678901234567890 /\ 24, write(a(A)), nl,
    B is 123456789012345678901234567890 \/ 1, write(b(B)), nl,
    C is 123456789012345678901234567890 xor 1, write(c(C)), nl,
    D is gcd(123456789012345678901234567890, 24), write(d(D)), nl,
    E is 123456789012345678901234567890 // 10, write(e(E)), nl,
    halt.
EOP
arm control_e_the_bitwise_ops_that_already_had_a_bignum_path_are_unmoved "$TMPD/e.pl" "$(printf '%s\n' \
    'a(16)' 'b(123456789012345678901234567891)' 'c(123456789012345678901234567891)' \
    'd(6)' 'e(12345678901234567890123456789)')"
cat > "$TMPD/f.pl" <<'EOP'
:- initialization(main).
main :-
    A is (1 << 100) >> 100, ( A == 1 -> write(a(round_trips)) ; write(a(A)) ), nl,
    B is (123456789012345678901234567890 << 37) >> 37,
    ( B == 123456789012345678901234567890 -> write(b(round_trips)) ; write(b(B)) ), nl,
    C is (1 << 100), D is C >> 99, write(c(D)), nl,
    E is 0 << 1000, write(e(E)), nl,
    halt.
EOP
arm subject_f_the_round_trip_alone_is_blind_because_the_two_defects_cancel "$TMPD/f.pl" "$(printf '%s\n' \
    'a(round_trips)' 'b(round_trips)' 'c(2)' 'e(0)')"
echo "[$GATE_NAME] $((total-red))/$total arms green (modes: $MODES)"
[ "$red" -eq 0 ] || { echo "GATE FAIL($red) [$GATE_NAME]"; exit 1; }
echo "GATE PASS(0) [$GATE_NAME]"
