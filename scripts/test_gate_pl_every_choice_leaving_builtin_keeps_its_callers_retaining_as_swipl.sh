#!/usr/bin/env bash
# test_gate_pl_every_choice_leaving_builtin_keeps_its_callers_retaining_as_swipl.sh -- A PREDICATE THAT CAN LEAVE A CHOICE IS NEVER SPINE TIER
# (hq_zetas 2026-10-15, PROLOG-SPINE-CHUNK-CEO-1757 under CEO-1797; the cto's condition 1 on the chunk's review).
# THE RISK: the frame-tier selector (frame_layout.c fl_select_spine_tier) unpins a Prolog graph only when no box of it can leave a choice and no
# callee of it retains, closed transitively; the boxes that can leave a choice are a hand list (fl_box_retains).  A kind missing from the list is
# SILENT: its graph is unpinned and its staged calls take the spine arm, whose beta never retries the callee -- solutions are lost, or a beta runs
# into a released frame.  THE ARM: twenty-two kinds that can leave a choice, each a single-clause predicate p/1 holding the kind, called from a
# single-clause q/1, enumerated by a fail-driven loop that records every solution (sorted, so a builtin's enumeration order is not graded):
# between/3, repeat (cut at 3), sub_atom/5, nth0/3 and nth1/3 with an unbound index, clause/2, retract/1, current_op/3, current_predicate/1,
# member/2 and select/3 from the prelude, append/3 unbound, atom_concat/3 with the first two unbound, length/2 unbound (cut at 2), bagof/3 and
# setof/3 with a free variable, call/1 and catch/3 of a nondeterministic goal, phrase/2 of a nondeterministic DCG, and a file-defined dynamic
# predicate grown by assertz before it is called, and the two constructs that keep their choice header open past a deterministic exit -- catch/3 of a
# deterministic goal and a soft-cut whose condition succeeds once (hq_zetas 2026-10-17: 0bb392122 unpinned both, and every tabled program, SWI
# core/test_write and core/test_arith bombed at the spine-tier gamma).  The expected text is cut from swipl -q in this run; each of mode 3 and mode 4 is graded plain,
# under SCRIP_GC_STRESS=1, under SCRIP_GC_CHAIN_CHECK=1 and under both (stdout only; the chain check prints its summary on stderr).
# PROVEN RED (CEO-1680, a proper test, no plant in SCRIP): GATE_CORRUPT_REF=1 (this script's own switch) alters one line of swipl's answer and the
# gate reads RED in all eight readings.
# rc=0 all eight readings equal swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
GATE=test_gate_pl_every_choice_leaving_builtin_keeps_its_callers_retaining_as_swipl
refuse() { echo "⛔ REFUSED(2) [$GATE]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate $GATE || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/nd.pl" <<'PL'
:- dynamic(fact/1).
:- dynamic(r/1).
:- dynamic(fd/1).
:- dynamic(sol/2).
fact(1). fact(2). fact(3).
r(a). r(b). r(c).
fd(1).
ab(a) --> [].
ab(b) --> [].
p1(X) :- between(1, 3, X).
p2(X) :- nb_setval(k, 0), repeat, nb_getval(k, K), X is K + 1, nb_setval(k, X), ( X >= 3 -> ! ; true ).
p3(B-S) :- sub_atom(abc, B, 1, _, S).
p4(I-E) :- nth0(I, [a,b,c], E).
p5(I-E) :- nth1(I, [a,b,c], E).
p6(X) :- clause(fact(X), true).
p7(X) :- retract(r(X)).
p8(P-T) :- current_op(P, T, -).
p9(A) :- current_predicate(fact/A).
p10(X) :- member(X, [a,b,c]).
p11(X-R) :- select(X, [a,b,c], R).
p12(X+Y) :- append(X, Y, [1,2]).
p13(X+Y) :- atom_concat(X, Y, abc).
p14(N) :- length(_, N), ( N >= 2 -> ! ; true ).
p15(Y-L) :- bagof(X, member(X-Y, [1-a,2-b,3-a]), L).
p16(Y-L) :- setof(X, member(X-Y, [2-a,1-b,1-a]), L).
p17(X) :- call(member(X, [x,y,z])).
p18(X) :- catch(member(X, [p,q]), _, true).
p19(X) :- phrase(ab(X), []).
p20(X) :- fd(X).
p21(X) :- catch(X = c, _, true).
p22(X) :- ( true *-> X = s ; X = none ).
q1(X) :- p1(X).
q2(X) :- p2(X).
q3(X) :- p3(X).
q4(X) :- p4(X).
q5(X) :- p5(X).
q6(X) :- p6(X).
q7(X) :- p7(X).
q8(X) :- p8(X).
q9(X) :- p9(X).
q10(X) :- p10(X).
q11(X) :- p11(X).
q12(X) :- p12(X).
q13(X) :- p13(X).
q14(X) :- p14(X).
q15(X) :- p15(X).
q16(X) :- p16(X).
q17(X) :- p17(X).
q18(X) :- p18(X).
q19(X) :- p19(X).
q20(X) :- p20(X).
q21(X) :- p21(X).
q22(X) :- p22(X).
run(K, G, X) :- ( call(G), assertz(sol(K, X)), fail ; true ), findall(Y, sol(K, Y), L), msort(L, S), writeq(K-S), nl.
:- initialization(main).
main :- assertz(fd(2)),
    run(1, q1(X1), X1), run(2, q2(X2), X2), run(3, q3(X3), X3), run(4, q4(X4), X4), run(5, q5(X5), X5),
    run(6, q6(X6), X6), run(7, q7(X7), X7), run(8, q8(X8), X8), run(9, q9(X9), X9), run(10, q10(X10), X10),
    run(11, q11(X11), X11), run(12, q12(X12), X12), run(13, q13(X13), X13), run(14, q14(X14), X14), run(15, q15(X15), X15),
    run(16, q16(X16), X16), run(17, q17(X17), X17), run(18, q18(X18), X18), run(19, q19(X19), X19), run(20, q20(X20), X20),
    run(21, q21(X21), X21), run(22, q22(X22), X22).
PL
( cd "$D" && timeout 60 swipl -q -t halt nd.pl < /dev/null > want 2> /dev/null )
[ "$(wc -l < "$D/want")" = 22 ] || refuse "swipl did not print twenty-two answers"
[ "${GATE_CORRUPT_REF:-0}" = 1 ] && sed -i '10s/.*/10-[a,b]/' "$D/want"
( cd "$D" && timeout 120 "$B/scrip" --compile --out=nd.s nd.pl < /dev/null > /dev/null 2> m4.err && gcc nd.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o nd 2>> m4.err ) || refuse "mode 4 did not build: $(tail -2 "$D/m4.err")"
red=0; n=0
for env in "PLAIN=1" "SCRIP_GC_STRESS=1" "SCRIP_GC_CHAIN_CHECK=1" "SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=1"; do
    for m in m3 m4; do
        n=$((n + 1))
        if [ $m = m3 ]; then ( cd "$D" && env $env timeout 120 "$B/scrip" nd.pl < /dev/null > got 2> /dev/null )
        else ( cd "$D" && env $env timeout 120 ./nd < /dev/null > got 2> /dev/null ); fi
        if cmp -s "$D/want" "$D/got"; then echo "  $m [$env] GREEN: 22 of 22 answers as swipl"
        else echo "  $m [$env] RED: $(diff "$D/want" "$D/got" | grep -c '^<') of 22 answers differ from swipl"; diff "$D/want" "$D/got" | head -6 | sed 's/^/    /'; red=1; fi
    done
done
if [ $red = 0 ]; then echo "GATE GREEN [$GATE]: $n of $n readings equal swipl"; exit 0; fi
echo "GATE RED [$GATE]"; exit 1
