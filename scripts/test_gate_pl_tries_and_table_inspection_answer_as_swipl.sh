#!/usr/bin/env bash
# test_gate_pl_tries_and_table_inspection_answer_as_swipl.sh
#
# THE ROW: prolog-swi-tabling-the-table-directive-and-tabled-resolution-453-swi-cases (hq_prolog), PHASE 2 (a) on the ceo's and the
# cto's approval (the row's QA and LEDGER, 2026-10-09): A TRIE IS ONE TYPED HEAP KIND and the tables live in tries. HB_TRIE (the header:
# root node, entry vector, the tabling status and data DESCR) and HB_TRIEN (a node: token DESCR, value DESCR, parent, child vector) are
# walked by pl_trie_gc_visit in unification.c; the trie registry hangs off the program root at the end of pl_db_reg_t. A key is its
# variant token sequence -- functor id, atomic value, variable number in first-occurrence order -- compared as DESCR values, walked on
# the plr explicit stacks (no C recursion, no printed or joined string). trie_insert/lookup/delete and the entry list are leaves that
# compute and return; '$tbl_call' keeps a variant trie (call variant -> answer trie) and stores answers as their skeleton ret(Vars), as
# SWI does, so current_table/2, '$tbl_table_status'/4 and '$tbl_local_variant_table'/1 read the same objects tabling writes.
#
# THE ARM: 45 lines -- trie_insert's fail and permission_error on a present key, trie_update, lookup by variant (f(X,Y,X) vs
# f(_,_,_)), a fresh copy of a value on lookup, 1 vs 1.0, a nested key with a partial list, a 2000-element list key, trie_gen over a
# partially bound key, trie_delete, trie_term of an insert node, trie_destroy's existence_error, type_error and instantiation_error;
# then a tabled left-recursive a/2: three tables, the variant table's size, complete, the answers read off the answer trie through the
# status skeleton, an empty table, an absent variant, abolish_all_tables -- the ref cut from SWI-Prolog 9.0.4, in both modes.
# Engine-neutral by construction: no variable names, no handle printed, an error reduced to its name and first argument.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
r(G) :- ( catch(G, error(F, _), (( atom(F) -> writeq(ex(F)) ; functor(F, N, _), arg(1, F, A), writeq(ex(N, A)) ), nl, fail)) -> writeq(yes) ; writeq(no) ), nl.
:- table a/2.
a(X, Y) :- a(X, Z), e(Z, Y).
a(X, Y) :- e(X, Y).
e(1, 2). e(2, 3).
cnt(T, N) :- findall(x, trie_gen(T, _, _), L), length(L, N).
main :-
  trie_new(T),
  r(trie_insert(T, b, 1)), r(trie_insert(T, b, 1)), r(trie_insert(T, b, 2)),
  r(trie_update(T, b, 3)), trie_lookup(T, b, Vb), writeq(Vb), nl,
  r(trie_insert(T, f(X, Y, X), v(Y))), r(trie_lookup(T, f(_, _, _), _)), r(trie_lookup(T, f(Q, _, Q), _)),
  trie_lookup(T, f(Q1, R1, Q1), Vf), ( Vf = v(W1), var(W1), W1 \== R1 -> writeq(fresh_value) ; writeq(bound_value) ), nl,
  r(trie_insert(T, [1, 2, 3], z)), r(trie_insert(T, 1.0, x)), r(trie_insert(T, 1, y)), trie_lookup(T, 1, V1), writeq(V1), nl,
  r(trie_insert(T, g(h(i(j)), [k|l]), deep)), r(trie_lookup(T, g(h(i(j)), [k|l]), _)), r(trie_lookup(T, g(h(i(j)), [k]), _)),
  cnt(T, N0), writeq(N0), nl,
  findall(K, (trie_gen(T, K, _), ground(K)), G0), msort(G0, G1), writeq(G1), nl,
  r(trie_gen(T, f(a, _, a), _)), r(trie_gen(T, f(a, _, b), _)),
  r(trie_delete(T, b, Vd)), writeq(Vd), nl, r(trie_delete(T, b, _)),
  cnt(T, N1), writeq(N1), nl,
  trie_insert(T, c, 9, Node), trie_term(Node, Tm), writeq(Tm), nl,
  length(Big, 2000), r(trie_insert(T, big(Big), long)), r(trie_lookup(T, big(Big), _)), length(Big2, 2000), r(trie_lookup(T, big(Big2), _)),
  trie_destroy(T), r(trie_gen(T, _, _)), r(trie_insert(T, a, b)), r(trie_insert(foo, a, b)), r(trie_gen(_, _, _)),
  findall(P-Q2, a(P, Q2), _), ( a(2, _) -> true ; true ), ( a(3, _) -> true ; true ),
  findall(V, current_table(V, _), Vs), length(Vs, NT), writeq(tables(NT)), nl,
  '$tbl_local_variant_table'(VT), cnt(VT, NV), writeq(variants(NV)), nl,
  current_table(a(_, _), AT), '$tbl_table_status'(AT, S, Wr, Sk), writeq(S), nl,
  findall(G, (trie_gen(AT, Sk, _), Wr = _:G), Ws), msort(Ws, Ws1), writeq(Ws1), nl,
  current_table(a(3, _), A3), cnt(A3, N3), writeq(empty_table(N3)), nl,
  r(current_table(a(4, _), _)),
  abolish_all_tables, findall(V, current_table(V, _), V2), length(V2, NT2), writeq(tables(NT2)), nl,
  findall(P-Q3, a(P, Q3), L3), msort(L3, L4), writeq(L4), nl,
  halt.
PL
cat > "$D/g.ref" <<'REF'
yes
no
ex(permission_error,modify)
no
yes
3
yes
no
yes
fresh_value
yes
yes
yes
y
yes
yes
no
6
[1.0,1,b,[1,2,3],g(h(i(j)),[k|l])]
yes
no
yes
3
no
5
c
yes
yes
yes
ex(existence_error,trie)
no
ex(existence_error,trie)
no
ex(type_error,trie)
no
ex(instantiation_error)
no
tables(3)
variants(3)
complete
[a(1,2),a(1,3),a(2,3)]
empty_table(0)
no
tables(0)
[1-2,1-3,2-3]
REF
( cd "$D" && timeout -k 5 60 "$B/scrip" g.pl < /dev/null > g.m3 2>/dev/null )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o g.s g.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 60 ./g.bin < /dev/null > g.m4 2>/dev/null )
red=0
for m in m3 m4; do
    if cmp -s "$D/g.ref" "$D/g.$m"; then echo "  ok   $m: 45 of 45 lines answer as swipl's tries and table inspection"
    else echo "  FAIL $m: diverges from swipl:"; diff "$D/g.ref" "$D/g.$m" | head -12; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): tries and the table inspection answer as swipl in both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 2 mode(s) diverge"; exit 1
