#!/usr/bin/env bash
# test_gate_pl_a_module_qualified_assert_or_retract_of_a_loaded_modules_dynamic_predicate_reaches_the_modules_own_clauses_as_swipl.sh
#
# THE DEFECT (hq_runtime 2026-11-01 17:xx CST, SCRIP fe6b8e516; ProRosetta bulls-and-cows-player-2, red in both modes since 405844605 of 10-31): a program that
# loads a module file with use_module and asserts into the module's own dynamic predicate by a literal qualifier, assert('ia.pl':guess(Ms, Score)), lost the
# clause: the module's own guess/2 never saw it, so the game repeated its first guess forever. In the SWI dialect (any use_module directive selects it) the
# module pass of the parser stage (pl_mod_goal -> pl_mod_clause_term) renames the inner term to the module's private key 'ia.pl:guess' and leaves the qualifier;
# 405844605 then added a compile-time mangle in the lowering (pl_db_mq_term) for the qualifiers the module pass did not resolve, and it prefixed the module a
# second time, so the clause went to 'ia.pl:ia.pl:guess', a predicate nobody reads. assert, asserta, assertz, retract and retractall of a literal M:G all took it.
# THE CURE: pl_db_mq_term returns a name that already carries its module's prefix as it is.
#
# THE ARMS: one program, two files (a module named 'ia.pl' with a dot, as the game's, holding two dynamic predicates, and a main that loads it), 10 lines: the
# module's own bagof/findall/call see what a qualified assert, asserta, assertz, retract, retractall and a qualified rule clause did. The ref is cut from
# swipl 9.0.4 twice and compared. In both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
B="$HERE/../../SCRIP"
NAME=test_gate_pl_a_module_qualified_assert_or_retract_of_a_loaded_modules_dynamic_predicate_reaches_the_modules_own_clauses_as_swipl
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
command -v gcc > /dev/null || refuse "no gcc -- mode 4 cannot link"
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/m1.pl" <<'PL'
:- module('ia.pl', [tirage/1, cnt/1, hasr/1]).
:- dynamic guess/2.
:- dynamic rr/1.
tirage(L) :- ( bagof([P, R], guess(P, R), L) -> true ; L = none ).
cnt(N) :- findall(x, guess(_, _), L), length(L, N).
hasr(X) :- ( rr(X) -> true ; fail ).
PL
cat > "$D/main.pl" <<'PL'
:- use_module('m1.pl').
:- initialization(main).
s(L, G) :- ( catch(G, _, fail) -> R = yes ; R = no ), write(L), write(' '), write(R), nl.
main :-
    tirage(A), write(A), nl,
    assert('ia.pl':guess([0,1], [0,2])), tirage(B), write(B), nl, cnt(N1), write(N1), nl,
    assertz('ia.pl':guess([2,3], [1,1])), tirage(C), write(C), nl,
    asserta('ia.pl':guess([9,9], [9,9])), tirage(C2), write(C2), nl,
    retract('ia.pl':guess([9,9], _)), tirage(C3), write(C3), nl,
    retractall('ia.pl':guess(_, _)), tirage(D), write(D), nl,
    assert('ia.pl':guess([5], [6])), tirage(E), write(E), nl,
    assertz('ia.pl':(rr(X) :- X > 1)), s(rule_5, hasr(5)), s(rule_0, hasr(0)),
    halt.
PL
cat > "$D/g.ref" <<'REF'
none
[[[0,1],[0,2]]]
1
[[[0,1],[0,2]],[[2,3],[1,1]]]
[[[9,9],[9,9]],[[0,1],[0,2]],[[2,3],[1,1]]]
[[[0,1],[0,2]],[[2,3],[1,1]]]
none
[[[5],[6]]]
rule_5 yes
rule_0 no
REF
( cd "$D" && timeout -k 5 60 "$B/scrip" main.pl < /dev/null > g.m3 2>g.m3.err )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=g.s main.pl < /dev/null > /dev/null 2>&1 && gcc g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "main.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 60 ./g.bin < /dev/null > g.m4 2>g.m4.err )
red=0; ok=0
for m in m3 m4; do
    if cmp -s "$D/g.ref" "$D/g.$m"; then echo "  ok   $m: 10 of 10 lines answer as swipl"; ok=$((ok + 1))
    else echo "  FAIL $m: diverges from swipl:"; diff "$D/g.ref" "$D/g.$m" | head -8; head -2 "$D/g.$m.err" 2>/dev/null; red=$((red + 1)); fi
done
echo "PL_MODULE_QUALIFIED_ASSERT_BOARD lang=prolog modes_ok=$ok modes_red=$red lines=10 (tree $(git -C "$B" rev-parse --short HEAD 2>/dev/null))"
if [ $red -eq 0 ]; then echo "GATE OK [$NAME]: both modes answer as swipl"; exit 0; fi
echo "GATE FAIL [$NAME]: $red of 2 mode(s) diverge"; exit 1
