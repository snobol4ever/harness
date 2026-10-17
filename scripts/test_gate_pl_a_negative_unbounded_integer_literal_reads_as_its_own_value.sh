#!/usr/bin/env bash
# test_gate_pl_a_negative_unbounded_integer_literal_reads_as_its_own_value.sh -- PROLOG ISO LADDER, RUNG 8's OTHER HALF (cto, 2026-09-13).
# THE SUBJECT: a NEGATIVE integer literal wider than 64 bits, read through the unary-minus fold in
# prolog_parse.c. Rung 8 wired the POSITIVE path onto the shared bignum core and its gate tested negation as
# the functor form -(123...) -- parsed through TK_LPAREN -- so the literal fold, which is a different
# construct, was never read. A NEGATIVE LITERAL AND A NEGATED LITERAL ARE TWO CONSTRUCTS.
# ⛔ THE ARMS ARE DISCRIMINATING, NOT A TRIPWIRE (hq_B's bar, cto's law THE UNEXPLAINED GREEN): arms a-e are the
# subject and arms f-j are CONTROLS that pass BOTH before and after the cure -- the positive literal of the same
# width, the functor negation rung 8 already held, an in-range negative literal, INT64_MIN's positive
# neighbour, and plain small arithmetic. A future regression in the positive reader or in bignum.c lights the
# controls; a regression in the fold lights only a-e. The gate therefore names WHICH half moved.
# THE ORACLE IS swipl 9. gprolog 1.4.5 is a BOUNDED implementation -- it refuses -9223372036854775808 at read
# time with 'integer underflow (exceeds min_integer)' -- so it is not an oracle for this construct.
# ⛔ RED BEFORE, on the clean origin build e62070ca8, m3 AND m4:
#   a(-9223372036854775807) b(-9223372036854775807) c(evaluation_error(int_overflow)) d(no) e(-9223372036854775807)
# against swipl's a(-9223372036854775808) b(-123456789012345678901234567890)
# c(-246913578024691357802469135780) d(yes) e(-9223372036854775808).
set -u
GATE_NAME=test_gate_pl_a_negative_unbounded_integer_literal_reads_as_its_own_value
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
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
    timeout -k 5 60 "$SCRIP" --compile -o "$s" "$src" </dev/null 2>"$TMPD/err" || { echo "  (m4: compile failed: $(head -c 160 "$TMPD/err"))"; return 97; }
    gcc -m64 -no-pie "$s" -o "$b" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  (m4: link failed: $(head -c 160 "$TMPD/err"))"; return 98; }
    timeout -k 5 20 "$b" </dev/null 2>"$TMPD/err"
}
arm() {
    local name="$1" src="$2" want_out="$3" want_rc="$4" mode got rc
    for mode in m3 m4; do
        case "$MODES" in *"$mode"*) : ;; *) continue ;; esac
        total=$((total+1))
        got="$("run_$mode" "$src")"; rc=$?
        if [ "$got" = "$want_out" ] && [ "$rc" = "$want_rc" ]; then echo "  ok  $name $mode"
        else echo "  RED $name $mode: rc=$rc want $want_rc; out=[$got] want [$want_out] $(head -c 200 "$TMPD/err" 2>/dev/null)"; red=$((red+1)); fi
    done
}
cat > "$TMPD/neg.pl" <<'EOP'
:- initialization(main).
main :-
    A = -9223372036854775808, write(a(A)), nl,
    B = -123456789012345678901234567890, write(b(B)), nl,
    C is -123456789012345678901234567890 * 2, write(c(C)), nl,
    ( integer(-9223372036854775808) -> write(d(yes)) ; write(d(no)) ), nl,
    E is -9223372036854775808, write(e(E)), nl,
    halt.
EOP
arm subject_a_negative_literal_reads_as_its_own_value "$TMPD/neg.pl" "$(printf '%s\n' \
    'a(-9223372036854775808)' \
    'b(-123456789012345678901234567890)' \
    'c(-246913578024691357802469135780)' \
    'd(yes)' \
    'e(-9223372036854775808)')" 0
cat > "$TMPD/ctl.pl" <<'EOP'
:- initialization(main).
main :-
    F = 123456789012345678901234567890, write(f(F)), nl,
    G is -(123456789012345678901234567890), write(g(G)), nl,
    H = -42, write(h(H)), nl,
    I = -9223372036854775807, write(i(I)), nl,
    J is 2 + 3, write(j(J)), nl,
    halt.
EOP
arm control_positive_functor_inrange_neighbour_and_small_arith "$TMPD/ctl.pl" "$(printf '%s\n' \
    'f(123456789012345678901234567890)' \
    'g(-123456789012345678901234567890)' \
    'h(-42)' \
    'i(-9223372036854775807)' \
    'j(5)')" 0
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
