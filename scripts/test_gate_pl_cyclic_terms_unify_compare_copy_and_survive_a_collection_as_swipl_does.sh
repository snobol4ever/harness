#!/usr/bin/env bash
# test_gate_pl_cyclic_terms_unify_compare_copy_and_survive_a_collection_as_swipl_does.sh -- RATIONAL TREES, THE CORE (cto 2026-10-05, CEO-1521,
# row prolog-rational-trees-cyclic-term-unification-comparison-copy-and-write-so-the-logtalk-coinduction-branch-is-graded-as-supported).
# Unification without the occurs check builds a cyclic term (X = f(X)); every walk over a term must then terminate on it with SWI-Prolog's answer.
# The walk is SWI's own (pl-prims.c do_unify / do_compare): a left-to-right agenda and a LINK per compound pair, undone at the end, so a revisited
# pair resolves to its partner; the agenda and the link log live on the C stack in VLA-grown segments (src/runtime/rt/pl_rational.h). The asm
# unifier rtx_pl_unify keeps its fast path and runs Brent's cycle detection over the compound pairs it visits; the first repeated pair hands the
# whole unification, from its original two cells, to that engine (a cyclic term, or a shared DAG it would otherwise unfold exponentially).
# ONE WITNESS, 23 LINES, graded in m3 and m4 and twice more in m3 under the collector (SCRIP_GC_STRESS=1, then with SCRIP_GC_PLANT_FLIP=1): ==, =,
# compare/3 and @< over cyclic terms of one and two cycles, cyclic lists of different periods, unify_with_occurs_check over cyclic lists,
# copy_term keeping the cycle and sharing, findall and throw copying a cyclic term, a 2^40-path DAG unified and compared in linear time, a cyclic
# term surviving 3000 allocating iterations, and write_term with max_depth. The expected text is swipl 9's (swipl -q), cut at gate-writing time.
# RED BEFORE on origin b928d3fba: line 1 dies with ERROR 246 (stack overflow) in both modes -- == recursed down X = f(X) on the C stack; = spun
# forever in the asm leaf; copy_term, findall and throw overflowed the same way. The dag line also timed out in m3 under the Brent-only first cut
# (the checkpoint landed on low pairs and the leaf unfolded the upper levels), which is why a repeat restarts the whole unification in C.
set -u
GATE_NAME=test_gate_pl_cyclic_terms_unify_compare_copy_and_survive_a_collection_as_swipl_does
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/w_cyc.pl" <<'EOP'
dag(0, a) :- !.
dag(N, f(T, T)) :- N1 is N - 1, dag(N1, T).
churn(0) :- !.
churn(N) :- _ = g(N, [a, b, c], foo(bar)), N1 is N - 1, churn(N1).
main :-
    X1 = f(X1), ( X1 == X1 -> write(eq1) ; write(neq1) ), nl,
    X2 = f(X2), Y2 = f(Y2), ( X2 == Y2 -> write(eq2) ; write(neq2) ), nl,
    X3 = f(X3), Y3 = f(Y3), ( X3 = Y3 -> write(unif3) ; write(nounif3) ), nl,
    X4 = f(X4), Y4 = f(f(Y4)), ( X4 = Y4 -> write(unif4) ; write(nounif4) ), nl,
    X5 = f(X5), Y5 = f(f(Y5)), ( X5 == Y5 -> write(eq5) ; write(neq5) ), nl,
    X6 = f(X6), Y6 = f(Y6), compare(O6, X6, Y6), write(O6), nl,
    X7 = s(X7, _), Y7 = s(Y7, _), ( X7 @< Y7 -> write(lt7) ; write(nlt7) ), nl,
    X8 = s(_, X8), Y8 = s(_, Y8), ( X8 @< Y8 -> write(lt8) ; write(nlt8) ), ( X8 == Y8 -> write(eq8) ; write(neq8) ), nl,
    X9 = [0, 1|X9], Y9 = [0, 2|Y9], compare(O9, a(1, X9), a(1, Y9)), write(O9), nl,
    L10 = [1, 2, 3|L10], M10 = [1, 2, 3, 1, 2, 3|M10], ( L10 == M10 -> write(eq10) ; write(neq10) ), ( L10 = M10 -> write(unif10) ; write(nounif10) ), nl,
    L11 = [1, 2, 3|L11], M11 = [A11, B11, C11|M11], unify_with_occurs_check(L11, M11), write(A11-B11-C11), nl,
    X12 = f(X12), copy_term(X12, Z12), ( Z12 == X12 -> write(copyeq12) ; write(copyneq12) ), ( acyclic_term(Z12) -> write(acyc12) ; write(cyc12) ), nl,
    L13 = [_, _, _|L13], copy_term(L13, V13), V13 = [_, _, _|T13], ( V13 == T13 -> write(yes13) ; write(no13) ), nl,
    X14 = f(X14), copy_term(foo(X14, Y14), foo(Z14, Y14)), ( Z14 == X14 -> write(yes14) ; write(no14) ), nl,
    copy_term(demoen(X15, X15), demoen(Y15, f(Y15))), ( acyclic_term(Y15) -> write(acyc15) ; write(cyc15) ), nl,
    X16 = f(X16), findall(X16, true, [F16]), ( F16 == X16 -> write(found16) ; write(nf16) ), nl,
    X17 = f(X17), catch(throw(X17), B17, true), ( B17 = f(_) -> write(caught17) ; write(other17) ), ( B17 == X17 -> write(eq17) ; write(neq17) ), nl,
    X18 = f(X18, Y18), Y18 = g(X18), Z18 = f(Z18, W18), W18 = g(Z18), ( X18 == Z18 -> write(eq18) ; write(neq18) ), ( X18 = Z18 -> write(unif18) ; write(nounif18) ), nl,
    X19 = f(X19, a), Y19 = f(Y19, b), ( X19 = Y19 -> write(unif19) ; write(nounif19) ), compare(O19, X19, Y19), write(O19), nl,
    dag(40, D1), dag(40, D2), ( D1 == D2 -> write(dageq) ; write(dagneq) ), ( D1 = D2 -> write(dagunif) ; write(dagnounif) ), compare(O20, D1, D2), write(O20), nl,
    X21 = f(X21), churn(3000), X21 = f(f(Q21)), ( Q21 == X21 -> write(survived21) ; write(lost21) ), nl,
    X22 = f(X22, Y22), copy_term(X22-Y22, C22), C22 = (P22-R22), ( var(R22), R22 \== Y22 -> write(fresh22) ; write(stale22) ), arg(1, P22, P22b), ( P22b == P22 -> write(cyc22) ; write(acyc22) ), nl,
    write_term(X1, [max_depth(3)]), nl.
:- initialization((main, halt)).
EOP
want='eq1
eq2
unif3
unif4
eq5
=
lt7
lt8neq8
<
eq10unif10
1-2-3
copyeq12cyc12
yes13
yes14
cyc15
found16
caught17eq17
eq18unif18
nounif19<
dageqdagunif=
survived21
fresh22cyc22
f(f(f(...)))'
red=0
run_arm() {
    local arm="$1" got rc
    case "$arm" in
        m3) got="$(cd "$TMPD" && env -u SCRIP_GC_STRESS -u SCRIP_GC_PLANT_FLIP timeout -k 5 60 "$SCRIP" w_cyc.pl </dev/null 2>"$TMPD/err")"; rc=$? ;;
        m4) timeout -k 5 120 "$SCRIP" --compile --out="$TMPD/w_cyc.s" "$TMPD/w_cyc.pl" </dev/null 2>"$TMPD/err" || { echo "  RED m4: the compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); return; }
            gcc -m64 -no-pie "$TMPD/w_cyc.s" -o "$TMPD/w_cyc.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  RED m4: the assembler or linker refused: $(grep -m1 -E 'Error|error' "$TMPD/err")"; red=$((red+1)); return; }
            got="$(cd "$TMPD" && env -u SCRIP_GC_STRESS -u SCRIP_GC_PLANT_FLIP timeout -k 5 60 ./w_cyc.bin </dev/null 2>"$TMPD/err")"; rc=$? ;;
        stress) got="$(cd "$TMPD" && SCRIP_GC_STRESS=1 timeout -k 5 300 "$SCRIP" w_cyc.pl </dev/null 2>"$TMPD/err" | grep -v '^\[GC-')"; rc=${PIPESTATUS[0]} ;;
        flip) got="$(cd "$TMPD" && SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_FLIP=1 timeout -k 5 300 "$SCRIP" w_cyc.pl </dev/null 2>"$TMPD/err" | grep -v '^\[GC-')"; rc=${PIPESTATUS[0]}; grep -q '^\[GC-FLIP\] plant:' "$TMPD/err" || { echo "  FAIL flip: the flip plant printed no applied banner, so this arm graded an unplanted run"; rc=99; } ;;
    esac
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $arm"
    else echo "  RED $arm: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-240)] err=[$(head -c 160 "$TMPD/err" | tr '\n' '|')]"; red=$((red+1)); fi
}
for arm in m3 m4 stress flip; do run_arm "$arm"; done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red of 4 arms red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: the 23-line cyclic-term witness (==, =, compare, @<, unify_with_occurs_check, copy_term, findall, throw, a 2^40-path DAG, a collection, max_depth) matches swipl in m3, m4, under SCRIP_GC_STRESS=1 and under the flip plant"
