#!/usr/bin/env bash
# test_gate_pl_moded_tabling_and_the_semi_naive_leader_answer_as_swipl.sh
#
# THE ROW: prolog-swi-tabling-mode-directed-tabling-and-answer-subsumption (hq_prolog, rank 1, class b1 of CEO-1624).
# MODE-DIRECTED TABLING: `:- table p(M1,..,Mn)` with Mi a variable, index or + (the variant's arguments) or first, -, last, min,
# max, sum, lattice(PI) or po(PI) (the moded arguments). The LOWERER (lower_prolog.c pl_table_specs) reads the spec and gives the
# wrapper p(A..) :- '$tbl_mcall'(p(A..), '$tbl p'(A..), Spec); the module rule (prolog_lower.c pl_mod_table_pi) renames the spec's
# predicate and the closure inside lattice/po like any other reference of the unit. '$tbl_mcall'/3 (the prelude) keys the table on
# the call with its moded arguments replaced by fresh variables, keeps ONE answer per variant of the index arguments, and joins each
# new answer into it by the mode; an answer whose join changes the value is re-inserted at the end of the answer trie, so it is new.
# THE SEMI-NAIVE LEADER: a re-evaluation of an incomplete table runs once per incomplete-consumer position r (the r-th call of an
# incomplete table on the derivation path, counted in b_setval('$tbl_cpos')): consumers before r read the answers the table's last
# evaluation saw (an index range of '$trie_slice'/4), the consumer at r only the answers since, the ones after r all -- so every
# derivation runs exactly once, which is also what makes a non-idempotent lattice (sum, plus/3) count as SWI's SLG does.
#
# THE ARM: 16 lines -- first on a cycle, min and max, lattice(Name/3) on paths, the + index mode with max, nested lattice components,
# lattice(plus/3) over two derivations of one answer (2, not 1), an or-lattice over and-paths (either join order, as SWI's own test
# accepts), po('>'/2), sum, two moded arguments (min and max), last, the uninstantiation error for a bound moded argument, the tabled
# DCG bas//0 over a 1000-element list (1001 answers; the naive leader took ~530 s, n^3), mutual recursion 3000 deep, and a moded
# table after abolish_all_tables -- the ref cut from SWI-Prolog 9.0.4, in both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
:- table path(index, index, first).
path(X, Y, N) :- path(X, Z, N1), edge(Z, Y), N is N1 + 1.
path(X, Y, 1) :- edge(X, Y).
edge(a, b). edge(b, a).
:- table conn(_, _, min).
conn(X, Y, 1) :- c(X, Y).
conn(X, Y, N) :- conn(X, Z, N1), c(Z, Y), N is N1 + 1.
:- table connx(_, _, max).
connx(X, Y, 1) :- c(X, Y).
connx(X, Y, N) :- connx(X, Z, N1), c(Z, Y), N is N1 + 1.
c(ams, sch). c(ams, haa). c(sch, lei). c(haa, lei). c(ams, lei).
:- table train(_, _, lattice(shortest/3)).
train(X, Y, [X, Y]) :- c(X, Y).
train(X, Y, P) :- train(X, Z, P0), c(Z, Y), append(P0, [Y], P).
shortest(P1, P2, P) :- length(P1, L1), length(P2, L2), ( L1 < L2 -> P = P1 ; P = P2 ).
:- table t1(+, +, max).
t1(L, L2, V) :- member(V1, L), member(V2, L2), V is V1 + V2.
:- table p2(lattice(orp/3)), s2(lattice(ors/3)).
orp(A, B, A+B).
ors(A, B, A-B).
p2(A) :- s2(A).
s2(1). s2(2).
:- table adv(_, _, lattice(plus/3)), r11(_, _, _, lattice(plus/3)).
adv(A, B, 1) :- proj(C, A), proj(C, B), A \== B, r11(A, B, C, _).
r11(A, B, C, 1) :- pub(D, A, C), pub(D, B, C).
proj(p1, h). proj(p1, b). proj(p2, h). proj(p2, b).
pub(x1, h, p1). pub(x1, b, p1). pub(x2, h, p1). pub(x2, b, p1). pub(x3, h, p2). pub(x3, b, p2).
:- table opa(_, _, lattice(or/3)), oe(_, _, lattice(or/3)).
opa(X, X, one).
opa(X, Y, C) :- oe(X, Z, A), opa(Z, Y, B), and(A, B, C).
opa(A, B, zero) :- nonvar(A), nonvar(B).
oe(a, b, e(a, b)). oe(b, e, e(b, e)). oe(a, e, e(a, e)).
oe(A, B, zero) :- nonvar(A), nonvar(B).
or(zero, B, B) :- !.
or(B, zero, B) :- !.
or(one, one, one) :- !.
or(A, A, A) :- !.
or(A, B, or(A, B)).
and(zero, _, _) :- !, fail.
and(_, zero, _) :- !, fail.
and(one, B, B) :- !.
and(B, one, B) :- !.
and(A, A, A) :- !.
and(A, B, and(A, B)).
:- table big(_, po('>'/2)).
big(k, 3). big(k, 9). big(k, 4).
:- table tot(_, sum).
tot(k, 3). tot(k, 9). tot(k, 4).
:- table two(_, min, max).
two(k, 5, 1). two(k, 2, 7). two(k, 8, 3).
:- table lst(_, last).
lst(k, x). lst(k, y). lst(k, z).
:- table bas/2.
bas --> "b".
bas --> bas, "a".
:- table d/1, e/1.
d(X) :- e(Y), Y < 3000, X is Y + 1.
d(0).
e(X) :- d(Y), Y < 3000, X is Y + 1.
e(0).
s(T, G) :- findall(T, G, L), msort(L, S), writeq(S), nl.
main :-
  s(t(X, Y, L), path(X, Y, L)),
  conn(ams, lei, N), writeq(N), nl, connx(ams, lei, M), writeq(M), nl,
  train(ams, lei, P), writeq(P), nl,
  L1 = [1, 2, 3, 5, 98, 3, 103, 4, 4, 21], t1(L1, L1, Max), writeq(Max), nl,
  s(A, p2(A)), s(Q, adv(h, b, Q)),
  ( opa(a, e, T), member(T, [or(e(a, e), and(e(a, b), e(b, e))), or(and(e(a, b), e(b, e)), e(a, e))]) -> writeq(or_join_ok) ; writeq(or_join_bad) ), nl,
  s(K-V, big(K, V)), s(K2-V2, tot(K2, V2)), s(K3-Mn-Mx, two(K3, Mn, Mx)), s(K4-V4, lst(K4, V4)),
  catch((conn(ams, sch, 3) -> writeq(y) ; writeq(n)), error(Er, _), writeq(caught(Er))), nl,
  length(As, 1000), maplist(=(0'a), As), findall(R, bas([0'b|As], R), Rs), length(Rs, NR), writeq(bas(NR)), nl,
  ( d(3000) -> writeq(deep_yes) ; writeq(deep_no) ), nl,
  abolish_all_tables, conn(ams, lei, N2), writeq(N2), nl,
  halt.
PL
cat > "$D/g.ref" <<'REF'
[t(a,a,2),t(a,b,1),t(b,a,1),t(b,b,2)]
1
2
[ams,lei]
206
[1-2]
[2]
or_join_ok
[k-9]
[k-16]
[k-2-7]
[k-z]
caught(uninstantiation_error(3))
bas(1001)
deep_yes
1
REF
( cd "$D" && timeout -k 5 120 "$B/scrip" g.pl < /dev/null > g.m3 2>&1 )
( cd "$D" && timeout -k 5 120 "$B/scrip" --compile -o g.s g.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 120 ./g.bin < /dev/null > g.m4 2>&1 )
red=0
for m in m3 m4; do
    if cmp -s "$D/g.ref" "$D/g.$m"; then echo "  ok   $m: 16 of 16 lines answer as swipl's moded tabling"
    else echo "  FAIL $m: diverges from swipl:"; diff "$D/g.ref" "$D/g.$m" | head -12; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): moded tabling and the semi-naive leader answer as swipl in both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 2 mode(s) diverge"; exit 1
