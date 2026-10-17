#!/usr/bin/env bash
# test_gate_pl_between_through_a_variable_link_ttyflush_and_time_answer_as_swipl.sh -- THREE BUILTIN GAPS THE CLPFD ROLL-OUT'S SMOKE
# FOUND, ANSWERED AS SWIPL IN BOTH MODES (cfo 2026-10-11; the roll-out of library(clpfd), CEO-1596, over a systematic sample of the
# puzzles package's OUTSIDE_CLPFD programs; the cfo's lane, the Prolog runtime breadth).
#
# (1) between/3 (and for/3) with a bound that reached its value through a variable link -- X = Y, Y = 2, between(X, 5, Z) -- died
# with "scrip: error 1: Illegal data type" in both modes: the bound is lowered as a plain variable read, the guard derefs it fully and
# passes, and the range box (IR TO) received the unresolved link.  A bound bound directly (X = 2) was fine.  hakank_swi_sonet died
# on it through clpfd (C11 #= C1 + 1, between(C11, N, C2)).  The cure, lower_prolog.c: a variable bound is evaluated through unary
# plus AFTER the guard, so the guard keeps ISO's error terms (type_error(integer, a), instantiation_error) and the range box gets the
# dereferenced integer.  (2) ttyflush/0 was absent (hakank_swi_euler20, euler39): flush_output(user_output).  (3) time/1 was absent:
# it calls the goal transparently (every solution, failure passed on) and reports CPU seconds on user_error after each exit -- swipl
# also reports inferences and Lips, which SCRIP does not count, so only stdout is graded.  A program's own ttyflush/0 or time/1 wins.
#
# THE ARM: one witness, stdout cut against swipl -q in this run, diffed in mode 3 and mode 4.  FAIL-ONCE, measured on origin
# baeb39748 (before the cure, its two source files restored into this tree and rebuilt): 16 of 16 lines differ in both modes.  rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_between_through_a_variable_link_ttyflush_and_time_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- initialization(main).
t(N, G) :- ( catch(G, error(E, _), (writeq(N-E), nl)) -> true ; writeq(N-failed), nl ).
p(Y) :- X = Y, X = 2.
main :-
    t(direct, (X1 = 2, between(X1, 5, Z1), writeq(Z1), nl)),
    t(link_low, (X2 = Y2, Y2 = 2, between(X2, 5, Z2), writeq(Z2), nl)),
    t(link_high, (X3 = Y3, Y3 = 5, between(1, X3, Z3), writeq(Z3), nl)),
    t(link_both, (A4 = B4, B4 = 2, C4 = D4, D4 = 3, findall(Z4, between(A4, C4, Z4), L4), writeq(L4), nl)),
    t(link_call, (X5 = Y5, Y5 = 2, call(between, X5, 3, Z5), writeq(Z5), nl)),
    t(link_head, (p(X6), between(X6, 3, Z6), writeq(Z6), nl)),
    t(link_atom, (X7 = Y7, Y7 = a, between(X7, 5, _))),
    t(link_unbound, (X8 = _Y8, between(X8, 5, _))),
    t(link_float, (X9 = Y9, Y9 = 1.5, between(X9, 5, _))),
    t(link_check, (X10 = Y10, Y10 = 3, between(1, 5, X10), writeq(in), nl)),
    t(ttyflush, (ttyflush, writeq(flushed), nl)),
    t(time_all, (findall(M, time(member(M, [a,b,c])), Ms), writeq(Ms), nl)),
    t(time_fail, ((time(fail) -> writeq(no) ; writeq(failed_through)), nl)),
    t(time_bind, (time(X11 = 7), writeq(X11), nl)),
    t(time_cut, (once(time(member(Q, [x,y]))), writeq(Q), nl)),
    writeq(done), nl, halt.
PL
( cd "$D" && timeout -k 5 30 swipl -q w.pl < /dev/null 2> /dev/null | sed -E 's/_[0-9]+/_V/g' > want )
[ -s "$D/want" ] || refuse "swipl printed nothing for the witness"
( cd "$D" && timeout -k 5 30 "$B/scrip" --run w.pl < /dev/null 2> m3.err | sed -E 's/_G?[0-9]+/_V/g' > m3 )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s w.pl < /dev/null 2> m4.err && gcc -no-pie w.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o w 2>> m4.err && timeout -k 5 30 ./w < /dev/null 2>> m4.err | sed -E 's/_G?[0-9]+/_V/g' > m4 )
n=$(wc -l < "$D/want"); red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  $m GREEN: $n of $n lines as swipl"
    else echo "  $m RED: $(diff "$D/want" "$D/$m" 2>/dev/null | grep -c '^<') of $n lines differ from swipl"; diff "$D/want" "$D/$m" 2>/dev/null | head -8 | sed 's/^/    /'; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
