#!/usr/bin/env bash
# test_gate_pl_a_call_of_a_dynamic_predicate_with_a_rational_or_bignum_argument_matches_only_an_equal_value_as_swipl.sh
#
# THE DEFECT (hq_runtime 2026-11-01 16:xx CST, SCRIP 1a3e50692; ProRosetta fast-fourier-transform, red in both modes): a call of a dynamic predicate whose
# argument is a bound rational (1r8) or a bignum answered the FIRST stored fact whatever its value (dn(1r4) stored, dn(1r8) called: yes). The data road
# of a ground asserted fact (rt_pl_db_data_unify) unifies each argument through plw_unify_leaf, the trailed unifier; for a value that is not an integer, an
# atom, a string or a float it fell to rt_descr_equal, which has no case for DT_DATA (a rational) or DT_BIG and compared the type's text, equal for any
# two. The plain =, a static fact, the asm leaf (rtx_plunify.s -> rt_pl_unify_atomic_cold) and ==/2 were right, so the program's twiddle cache (assert of a
# rational-keyed fact, then a lookup) returned the wrong twiddle for every key but the first and the FFT's table came out wrong.
# THE CURE: plw_unify_leaf and its occurs-check twin plw_unify_oc_leaf send a pair holding a DT_BIG or a rational to rt_pl_unify_atomic_cold (rt_big_eq,
# pl_rat_eq) before the generic fallback, which still serves the other DT_DATA values (a stream compares by identity).
#
# THE ARMS: one program, 14 questions asked twice (the second time under occurs_check=true, which takes the twin leaf) of a stored fact, a stored rule
# clause and a fact keyed in its second argument: a different rational, the same rational, the same value in another form (2r8 against 1r4), a rational
# against an integer, a bignum plus one, the same bignum, a bignum against an integer, and the count of what a lookup finds. The ref is cut from
# swipl 9.0.4 twice and compared. In both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
B="$HERE/../../SCRIP"
NAME=test_gate_pl_a_call_of_a_dynamic_predicate_with_a_rational_or_bignum_argument_matches_only_an_equal_value_as_swipl
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
command -v gcc > /dev/null || refuse "no gcc -- mode 4 cannot link"
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
:- dynamic(fr/1).
:- dynamic(rl/2).
:- dynamic(pr/2).
t(L, G) :- ( catch(G, _, fail) -> R = yes ; R = no ), write(L), write(' '), write(R), nl.
run :-
    A is 1 rdiv 4, B is 1 rdiv 8, C is 2 rdiv 8, G is 10^30, H is G + 1, I is 10^30,
    assertz(fr(A)), assertz(fr(G)), assertz((rl(A, k) :- true)), assertz((rl(G, k) :- true)), assertz(pr(a, A)),
    t(rational_other, fr(B)), t(rational_same, fr(A)), t(rational_same_value_other_form, fr(C)), t(rational_vs_integer, fr(1)),
    t(bigint_plus_one, fr(H)), t(bigint_same_value, fr(I)), t(bigint_vs_integer, fr(5)),
    t(rule_rational_other, rl(B, _)), t(rule_rational_same, rl(A, _)), t(rule_bigint_other, rl(H, _)), t(rule_bigint_same, rl(I, _)),
    t(second_argument_rational_other, pr(a, B)), t(second_argument_rational_same, pr(a, A)),
    t(lookup_count_rational_other, (findall(X, fr(X), L), L = [_, _])).
main :- run, set_prolog_flag(occurs_check, true), write(occurs_check), nl, retractall(fr(_)), retractall(rl(_, _)), retractall(pr(_, _)), run, halt.
PL
cat > "$D/g.ref" <<'REF'
rational_other no
rational_same yes
rational_same_value_other_form yes
rational_vs_integer no
bigint_plus_one no
bigint_same_value yes
bigint_vs_integer no
rule_rational_other no
rule_rational_same yes
rule_bigint_other no
rule_bigint_same yes
second_argument_rational_other no
second_argument_rational_same yes
lookup_count_rational_other yes
occurs_check
rational_other no
rational_same yes
rational_same_value_other_form yes
rational_vs_integer no
bigint_plus_one no
bigint_same_value yes
bigint_vs_integer no
rule_rational_other no
rule_rational_same yes
rule_bigint_other no
rule_bigint_same yes
second_argument_rational_other no
second_argument_rational_same yes
lookup_count_rational_other yes
REF
( cd "$D" && timeout -k 5 60 "$B/scrip" g.pl < /dev/null > g.m3 2>g.m3.err )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=g.s g.pl < /dev/null > /dev/null 2>&1 && gcc g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 60 ./g.bin < /dev/null > g.m4 2>g.m4.err )
red=0; ok=0
for m in m3 m4; do
    if cmp -s "$D/g.ref" "$D/g.$m"; then echo "  ok   $m: 29 of 29 lines answer as swipl"; ok=$((ok + 1))
    else echo "  FAIL $m: diverges from swipl:"; diff "$D/g.ref" "$D/g.$m" | head -8; head -2 "$D/g.$m.err" 2>/dev/null; red=$((red + 1)); fi
done
echo "PL_UNIFY_RATIONAL_BIGNUM_BOARD lang=prolog modes_ok=$ok modes_red=$red lines=29 (tree $(git -C "$B" rev-parse --short HEAD 2>/dev/null))"
if [ $red -eq 0 ]; then echo "GATE OK [$NAME]: both modes answer as swipl"; exit 0; fi
echo "GATE FAIL [$NAME]: $red of 2 mode(s) diverge"; exit 1
