#!/usr/bin/env bash
# test_gate_pl_module_rule_answers_as_swipl.sh
#
# THE RULE (the ceo, CEO-1607 and CEO-1612): SCRIP flattens modules by QUALIFIED RENAME. prolog_lower.c's first pass
# (pl_module_flatten, the pass that already knows each clause's plunit unit) gives every clause its module -- the unit as
# plunit_<Unit> between begin_tests/end_tests, else the latest module/2 or '$module_restore'/1, else user -- and renames a predicate a
# module defines and does not export to '<M>:<name>' (a unit exports nothing; exports are module/2's list and export/1). Calls resolve
# own module first, then the file module for a unit, then the bare global; closures of meta calls, db terms and declarations,
# context_module/1 (X = M), ':'(M,G) at run time (current_predicate on 'M:name'), module_transparent callers (a hidden first
# argument) and plunit test and unit options follow the same rule. A renamed predicate that one module alone defines keeps a bare
# alias, so a closure held in a variable still reaches it. Hooks (attr_unify_hook/2, attribute_goals/3, term_expansion/2, ...) are
# never renamed.
#
# THE ARM: 12 lines vs swipl 9.0.4 -- an exported predicate calling a private one, the private one from inside, a maplist closure
# naming a private predicate, context_module/1, m:priv statically and M2:priv at run time, a private dynamic predicate through
# retract/assertz, findall over a private predicate, current_predicate/1 on it, a goal held in a variable, clause/2 on a private
# predicate (the clause/3 store road a mutated '=' node once broke), forall/2 -- in both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
:- module(m, [pub/1]).
:- initialization(main).
:- dynamic cnt/1.
pub(X) :- priv(X).
priv(1).
priv2(X, f(X)).
cm(M) :- context_module(M).
bump :- retract(cnt(N)), N1 is N + 1, assertz(cnt(N1)).
reflect :- clause(priv2(_, _), B), B == true.
main :- pub(X), writeq(X), nl, priv(Y), writeq(Y), nl, maplist(priv2, [a,b], L), writeq(L), nl,
        cm(M), writeq(M), nl, m:priv(Z), writeq(Z), nl, M2 = m, M2:priv(W), writeq(W), nl,
        assertz(cnt(0)), bump, bump, cnt(C), writeq(C), nl, findall(Q, priv(Q), Qs), writeq(Qs), nl,
        ( current_predicate(priv/1) -> writeq(cp_yes) ; writeq(cp_no) ), nl,
        G = cm(K), call(G), writeq(K), nl, ( reflect -> writeq(clause_yes) ; writeq(clause_no) ), nl,
        forall(member(V, [1]), priv(V)), writeq(forall_ok), nl, halt.
PL
cat > "$D/g.ref" <<'REF'
1
1
[f(a),f(b)]
m
1
1
2
[1]
cp_yes
m
clause_yes
forall_ok
REF
( cd "$D" && timeout -k 5 60 "$B/scrip" g.pl < /dev/null > g.m3 2>/dev/null )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=g.s g.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 60 ./g.bin < /dev/null > g.m4 2>/dev/null )
red=0
for m in m3 m4; do
    if cmp -s "$D/g.ref" "$D/g.$m"; then echo "  ok   $m: 12 of 12 lines answer as swipl's modules"
    else echo "  FAIL $m: diverges from swipl:"; diff "$D/g.ref" "$D/g.$m" | head -12; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): the module rule answers as swipl in both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 2 mode(s) diverge"; exit 1
