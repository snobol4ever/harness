#!/usr/bin/env bash
# test_gate_pl_the_c_unifier_binds_the_plain_variable_to_the_attributed_one.sh -- EVERY UNIFICATION ROAD BINDS THE PLAIN
# VARIABLE TO THE ATTRIBUTED ONE, AS SWIPL DOES, IN BOTH MODES (cfo 2026-10-10, row prolog-clpfd-the-gnu-fd-spelling-...-ceo-1596;
# the cto's attributed-variable design, ARCH-PROLOG-CLPFD.md sections 2-3, reviewed by the cto on the bus).
#
# THE DEFECT.  plw_unify_oc_leaf, the C leaf behind unify_with_occurs_check/2, JOINED two unbound variables at a fresh cell
# (both bound to it) even when one of them was attributed, so the attributed variable was bound and its wakeup fired
# attr_unify_hook/2 -- where swipl binds the plain variable to the attributed one and wakes nothing.  Its twin
# plw_unify_leaf already had the branch.  Because subsumes_term/2 is a prelude clause over unify_with_occurs_check, every
# single-sided-unification head (=>) inherited the defect, so library(assoc)'s insert (an => rule) died on a tree holding an
# attributed value, and clpfd's all_distinct/1, circuit/1 and global_cardinality/2 died inside difference_arcs' put_assoc.
#
# THE ARM: the fourteen shapes that bisected it -- unify_with_occurs_check in both operand orders, bare and inside a
# compound; subsumes_term with the attributed term on either side; => heads over a compound, a bare argument, a repeated
# variable and a guard; put_assoc/get_assoc over an attributed value; two attributed variables, where BOTH systems run the
# hook -- cut against swipl -q in this run, the error FORMAL only (swipl's context differs), variable names normalized,
# diffed in mode 3 and mode 4.  FAIL-ONCE, measured on 70f3505ed: 11 of 16 lines differ in both modes; with the branch in
# place 16 of 16.  rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_the_c_unifier_binds_the_plain_variable_to_the_attributed_one
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- use_module(library(assoc)).
:- initialization(main).
s(N, G) :- ( catch(G, error(E, _), (writeq(N-E), nl, fail)) -> writeq(N-ok) ; writeq(N-failed) ), nl.
m(t(K,V,B,L,R), Out) => Out = t(K,V,B,L,R).
m2(X, Out) => Out = X.
m3(t(_,V,_,_,_), O) => O = V.
m4(f(X, X), O) => O = X.
m5(A, B), A == B => true.
m5(_, _) => fail.
main :- put_attr(Y, value, 1), T = t(1,Y,<,t,t),
    s(uwoc_fresh_left, (unify_with_occurs_check(V1, Y), V1 == Y)), s(uwoc_fresh_right, (unify_with_occurs_check(Y, V2), V2 == Y)),
    s(uwoc_in_compound, (unify_with_occurs_check(f(V3), f(Y)), V3 == Y)), s(uwoc_compound_right, (unify_with_occurs_check(f(Y), f(V4)), V4 == Y)),
    s(subsumes_compound, subsumes_term(t(_,_,_,_,_), T)), s(subsumes_arg, subsumes_term(f(_), f(Y))), s(subsumes_bare, subsumes_term(_, Y)),
    s(ssu_compound, m(T, _)), s(ssu_bare, m2(T, _)), s(ssu_value, (m3(T, O3), O3 == Y)), s(ssu_repeated, (put_attr(Y2, value, 2), m4(f(Y2, Y2), _))), s(ssu_guard, m5(Y, Y)),
    s(assoc_put_get, (empty_assoc(E0), put_assoc(1, E0, Y, A1), put_assoc(2, A1, Y3, A2), get_assoc(1, A2, Z), Z == Y, get_assoc(2, A2, Z3), Z3 == Y3)),
    s(two_attributed, (put_attr(P, value, 3), put_attr(Q, other, 4), P = Q)),
    s(plain_eq, (f(V5) = f(Y), V5 == Y)), halt.
PL
( cd "$D" && timeout -k 5 30 swipl -q -t halt w.pl < /dev/null 2> /dev/null | sed -E 's/_[0-9]+/_V/g' > want )
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
