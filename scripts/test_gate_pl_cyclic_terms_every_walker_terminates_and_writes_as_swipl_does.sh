#!/usr/bin/env bash
# test_gate_pl_cyclic_terms_every_walker_terminates_and_writes_as_swipl_does.sh -- RATIONAL TREES, THE ROLL-OUT (cto 2026-10-05, CEO-1521, row
# prolog-rational-trees-cyclic-term-unification-comparison-copy-and-write-so-the-logtalk-coinduction-branch-is-graded-as-supported). The core
# (test_gate_pl_cyclic_terms_unify_compare_copy_and_survive_a_collection_as_swipl_does.sh) made unify, ==, compare and copy_term cycle-safe;
# this gate holds every other walker over a term or a list spine to the same standard on ONE 23-line witness vs swipl in m3, m4 and under
# SCRIP_GC_STRESS=1: term_variables, ground, subsumes_term and numbervars over cyclic terms (one visit per compound cell, src/runtime/rt/pl_rational.h
# PLR_WALK1); length/2 of a cyclic list raising type_error(list, L) through SWI's '$skip_list'/3 (a Brent walk); keysort/2, msort/2 and =.. on a
# cyclic list raising type_error(list, L) (Brent in pl_sort_list_ball, plc_list_cells and the univ walk -- every list builtin that sizes a stack
# array from the spine is bounded by it, so a cyclic list can no longer overrun one); assertz of a cyclic clause raising
# representation_error(cyclic_term) from the db guard, which the lowerer now emits for every clause with a variable; and write, print, writeq
# and format of a cyclic term without max_depth factorized as swipl's @(Skeleton, [S_k=Def, ...]) -- a cycle point found by a block-keyed walk
# (a stack hash sized at entry from a cycle-safe count), numbered in detection order, its first position patched to S_k, the original
# variables kept, the wrapper written in functional form. Expected text: swipl 9 (swipl -q), cut at gate-writing time. sort/2 of a cyclic
# list is not graded here: swipl sorts it, the Logtalk suite's ISO expectation (lgt_sort_2_18) is type_error(list, L), and SCRIP answers ISO.
# RED BEFORE on origin 2429d7bca (the core alone): line 1 dies with ERROR 246 in both modes (term_variables recursed down X = f(X, X)).
set -u
GATE_NAME=test_gate_pl_cyclic_terms_every_walker_terminates_and_writes_as_swipl_does
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/w_cyc2.pl" <<'EOP'
:- dynamic(p/1).
main :-
    X1 = f(X1, X1), term_variables(X1, V1), length(V1, N1), write(N1), nl,
    X2 = f(X2, Y2), term_variables(X2, V2), ( V2 == [Y2] -> write(tv2) ; write(notv2) ), nl,
    X3 = f(X3), ( ground(X3) -> write(g3) ; write(ng3) ), X4 = f(X4, _), ( ground(X4) -> write(g4) ; write(ng4) ), nl,
    X5 = f(X5), ( subsumes_term(f(_), f(X5)) -> write(s5) ; write(ns5) ), ( subsumes_term(f(X5), f(_)) -> write(s5b) ; write(ns5b) ), ( subsumes_term(X5, X5) -> write(s5c) ; write(ns5c) ), nl,
    L6 = [A6, B6, C6|L6], numbervars(L6, 0, N6), print(N6-A6-B6-C6), nl,
    X7 = f(X7), numbervars(X7, 0, N7), write(N7), nl,
    L8 = [_|L8], catch(length(L8, _), error(E8, _), true), ( E8 = type_error(list, _) -> write(lerr8) ; write(lnoerr8) ), nl,
    length(L9, 3), length(L9, N9), write(N9), length([a, b|T9], 4), length(T9, M9), write(M9), nl,
    L10 = [c-3, a-1|L10], catch(keysort(L10, _), error(E10, _), true), ( E10 = type_error(list, _) -> write(kerr10) ; write(knoerr10) ), nl,
    L11 = [3, 1|L11], catch(msort(L11, _), error(E11, _), true), ( E11 = type_error(list, _) -> write(merr11) ; write(mnoerr11) ), nl,
    L12 = [a|L12], catch(_ =.. [f|L12], error(E12, _), true), ( E12 = type_error(list, _) -> write(uerr12) ; write(unoerr12) ), nl,
    X13 = f(X13), catch(assertz(p(X13)), error(E13, _), true), write(E13), nl,
    X14 = f(X14), print(X14), nl, writeq(g(X14, 'A b')), nl,
    X15 = f(X15, Y15), Y15 = g(Y15), print(X15), nl,
    X16 = f(Y16, X16), Y16 = g(Y16), print(X16), nl,
    X17 = f(X17), print([X17, X17]), nl, print(-(X17)), nl,
    X18 = -(X18), print(X18), nl,
    X19 = [a|X19], format("~w ~q ~p~n", [X19, X19, X19]),
    X20 = f(X20), with_output_to(string(S20), print(X20)), string_length(S20, N20), write(N20), nl,
    sort([V21], V21), keysort([W21-W21], W21), msort([Z21], Z21), write(ok21), nl,
    compare(O22, 1152921504606846976, 1152921504606846977), write(O22), sort([9007199254740993, 9007199254740992], L22), write(L22), nl.
:- initialization((main, halt)).
EOP
want='0
tv2
g3ng4
s5ns5bs5c
3-A-B-C
0
lerr8
32
kerr10
merr11
uerr12
representation_error(cyclic_term)
@(S_1,[S_1=f(S_1)])
@(g(S_1,'\''A b'\''),[S_1=f(S_1)])
@(S_1,[S_1=f(S_1,S_2),S_2=g(S_2)])
@(S_2,[S_1=g(S_1),S_2=f(S_1,S_2)])
@([S_1,S_1],[S_1=f(S_1)])
@(-S_1,[S_1=f(S_1)])
@(S_1,[S_1= -S_1])
@(S_1,[S_1=[a|S_1]]) @(S_1,[S_1=[a|S_1]]) @(S_1,[S_1=[a|S_1]])
19
ok21
<[9007199254740992,9007199254740993]'
red=0
run_arm() {
    local arm="$1" got rc
    case "$arm" in
        m3) got="$(cd "$TMPD" && env -u SCRIP_GC_STRESS -u SCRIP_GC_PLANT_FLIP timeout -k 5 60 "$SCRIP" w_cyc2.pl </dev/null 2>"$TMPD/err")"; rc=$? ;;
        m4) timeout -k 5 120 "$SCRIP" --compile -o "$TMPD/w_cyc2.s" "$TMPD/w_cyc2.pl" </dev/null 2>"$TMPD/err" || { echo "  RED m4: the compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); return; }
            gcc -m64 -no-pie "$TMPD/w_cyc2.s" -o "$TMPD/w_cyc2.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  RED m4: the assembler or linker refused: $(grep -m1 -E 'Error|error' "$TMPD/err")"; red=$((red+1)); return; }
            got="$(cd "$TMPD" && env -u SCRIP_GC_STRESS -u SCRIP_GC_PLANT_FLIP timeout -k 5 60 ./w_cyc2.bin </dev/null 2>"$TMPD/err")"; rc=$? ;;
        stress) got="$(cd "$TMPD" && SCRIP_GC_STRESS=1 timeout -k 5 300 "$SCRIP" w_cyc2.pl </dev/null 2>"$TMPD/err" | grep -v '^\[GC-')"; rc=${PIPESTATUS[0]} ;;
    esac
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $arm"
    else echo "  RED $arm: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-240)] err=[$(head -c 160 "$TMPD/err" | tr '\n' '|')]"; red=$((red+1)); fi
}
for arm in m3 m4 stress; do run_arm "$arm"; done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red of 3 arms red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: the 23-line roll-out witness (term_variables, ground, subsumes_term, numbervars, length, keysort, msort, =.., assertz, and the @/2 factorized write of cyclic terms) matches swipl in m3, m4 and under SCRIP_GC_STRESS=1"
