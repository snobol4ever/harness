#!/usr/bin/env bash
# test_gate_pl_tabling_phase_1_answers_as_swipl.sh
#
# THE ROW: prolog-swi-tabling-the-table-directive-and-tabled-resolution-453-swi-cases (hq_prolog; phase 1 on the ceo's YES).
# PHASE 1 is VARIANT tabling of DEFINITE programs. `:- table p/n` is placed by the LOWERER (lower_prolog.c
# pl_table_rewrite): p/n's clauses lower as '$tbl p'/n and one wrapper clause p(A..) :- '$tbl_call'(p(A..), '$tbl p'(A..))
# is added. '$tbl_call'/2 lives in the Prolog prelude: a table per call variant, kept since phase 2 (a) in a trie (one typed heap
# kind, the variant trie mapping a call variant to its answer trie; test_gate_pl_tries_and_table_inspection_answer_as_swipl.sh),
# answers each once by variant; a table whose evaluation touched no incomplete table completes after
# one pass (as SLG evaluates a clause once), and the first table of a strongly connected group is its LEADER, which
# re-evaluates the group's incomplete tables in rounds until none grows (a fixpoint). abolish_all_tables/0 drops them.
# Out of phase 1, each its own row: tnot/WFS, answer subsumption and mode-directed tabling, incremental tabling.
#
# THE ARM: 20 lines -- left recursion on a cyclic graph, a failing reachability, fib(200) and fib(30), mutual recursion
# (even/odd), symmetric-transitive closure, a doubly recursive b/2, non-ground answers kept once each by variant, a
# 0-arity tabled loop, an exception through a tabled call, how many times a side-effecting tabled clause runs before and
# after abolish_all_tables -- the ref cut from SWI-Prolog 9.0.4, in both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
:- table path/2.
edge(a, b). edge(b, c). edge(c, a). edge(c, d).
path(X, Y) :- path(X, Z), edge(Z, Y).
path(X, Y) :- edge(X, Y).
:- table fib/2.
fib(0, 0). fib(1, 1).
fib(N, F) :- N > 1, A is N-1, B is N-2, fib(A, FA), fib(B, FB), F is FA+FB.
:- table even/1, odd/1.
even(0).
even(N) :- odd(M), M < 10, N is M+1.
odd(N) :- even(M), M < 10, N is M+1.
:- table conn/2.
conn(X, Y) :- conn(Y, X).
conn(X, Y) :- link(X, Y).
conn(X, Z) :- conn(X, Y), conn(Y, Z).
link(1, 2). link(2, 3). link(4, 4).
:- table b/2.
b(X, Y) :- b(X, Z), b(Z, Y).
b(X, Y) :- e(X, Y).
e(1, 2). e(2, 3).
:- table nv/1.
nv(f(_)).
nv(f(a)).
nv(g(X, X)).
:- table z/0.
z :- z.
z.
:- table boom/1.
boom(X) :- X = 1 ; throw(oops).
:- dynamic(cnt/1).
cnt(0).
:- table counted/1.
counted(X) :- retract(cnt(N)), N1 is N+1, assertz(cnt(N1)), member(X, [p, q]).
s(T, G) :- findall(T, G, L), msort(L, S), writeq(S), nl.
main :-
  s(X-Y, path(X, Y)), ( path(d, _) -> writeq(yes) ; writeq(no) ), nl,
  fib(200, F), writeq(F), nl, fib(30, F30), writeq(F30), nl,
  s(E, even(E)), s(O, odd(O)),
  s(P-Q, conn(P, Q)), s(P2, conn(4, P2)),
  s(B1-B2, b(B1, B2)), s(B3, b(1, B3)),
  findall(V, nv(V), NV), length(NV, NVn), writeq(NVn), nl,
  ( z -> writeq(z_yes) ; writeq(z_no) ), nl,
  catch(s(W, boom(W)), Ex, (writeq(caught(Ex)), nl)),
  s(K, counted(K)), s(K2, counted(K2)), cnt(C1), writeq(evals(C1)), nl,
  abolish_all_tables, s(K3, counted(K3)), cnt(C2), writeq(evals(C2)), nl,
  s(X4-Y4, path(X4, Y4)),
  halt.
PL
cat > "$D/g.ref" <<'REF'
[a-a,a-b,a-c,a-d,b-a,b-b,b-c,b-d,c-a,c-b,c-c,c-d]
no
280571172992510140037611932413038677189525
832040
[0,2,4,6,8,10]
[1,3,5,7,9]
[1-1,1-2,1-3,2-1,2-2,2-3,3-1,3-2,3-3,4-4]
[4]
[1-2,1-3,2-3]
[2,3]
3
z_yes
caught(oops)
[p,q]
[p,q]
evals(1)
[p,q]
evals(2)
[a-a,a-b,a-c,a-d,b-a,b-b,b-c,b-d,c-a,c-b,c-c,c-d]
REF
( cd "$D" && timeout -k 5 60 "$B/scrip" g.pl < /dev/null > g.m3 2>&1 )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o g.s g.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 60 ./g.bin < /dev/null > g.m4 2>&1 )
red=0
for m in m3 m4; do
    if cmp -s "$D/g.ref" "$D/g.$m"; then echo "  ok   $m: 20 of 20 lines answer as swipl's tabling"
    else echo "  FAIL $m: diverges from swipl:"; diff "$D/g.ref" "$D/g.$m" | head -12; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): tabling phase 1 answers as swipl in both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 2 mode(s) diverge"; exit 1
