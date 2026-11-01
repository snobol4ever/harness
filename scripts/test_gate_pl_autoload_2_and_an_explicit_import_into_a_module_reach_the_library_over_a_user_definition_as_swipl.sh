#!/usr/bin/env bash
# test_gate_pl_autoload_2_and_an_explicit_import_into_a_module_reach_the_library_over_a_user_definition_as_swipl.sh
#
# THE RULE (ARCH-PROLOG-DATABASE section 2, swipl's module rule at compile time; SWI compile/test_autoload not_from_user, the cqo 2026-11-01):
# autoload/1,2 is a directive with use_module/1,2's meaning, never a goal (it raised existence_error(procedure, autoload/2)); a module other
# than user that imports Name/Arity from library(L) by an explicit list resolves its own calls to Name/Arity against the library's private key
# (L:Name, or system:Name when the base prelude holds that export), so a user:Name definition elsewhere in the program does not capture them;
# a compiled L:Goal call reaches the same private key; user's own calls still reach user's definition.
#
# THE ARMS: 4 lines vs swipl 9.0.4, cut twice and compared -- an autoload/2 import of a vendored library (date) beside user:day_of_the_year/2,
# a use_module/2 import of a base-prelude export (lists:last/2) beside user:last/2, the lists:last/2 qualified call, and user:last/2 itself (the
# control, which answers user_fact on every tree), in both modes. A call(G) meta-call inside the importing module is NOT an arm: it resolves at
# run time, outside section 2's compile-time rule (asked of the cto 2026-11-01). rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- module(m, []).
:- initialization(main).
user:day_of_the_year(_, user_fact).
user:last(_, user_fact).
:- autoload(library(date), [day_of_the_year/2]).
:- use_module(library(lists), [last/2]).
plain(D) :- day_of_the_year(date(1952, 3, 11), D).
imported(L) :- last([1, 2, 3], L).
qualified(L) :- lists:last([4, 5], L).
main :- plain(A), writeq(A), nl, imported(C), writeq(C), nl, qualified(E), writeq(E), nl, user:last([1], U), writeq(U), nl, halt.
PL
cat > "$D/g.ref" <<'REF'
71
3
5
user_fact
REF
( cd "$D" && timeout -k 5 60 "$B/scrip" g.pl < /dev/null > g.m3 2>g.m3.err )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=g.s g.pl < /dev/null > /dev/null 2>&1 && gcc g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 60 ./g.bin < /dev/null > g.m4 2>g.m4.err )
red=0; ok=0
for m in m3 m4; do
    if cmp -s "$D/g.ref" "$D/g.$m"; then echo "  ok   $m: 4 of 4 lines answer as swipl"; ok=$((ok + 1))
    else echo "  FAIL $m: diverges from swipl:"; diff "$D/g.ref" "$D/g.$m" | head -8; head -2 "$D/g.$m.err" 2>/dev/null; red=$((red + 1)); fi
done
echo "PL_MODULE_IMPORT_BOARD lang=prolog modes_ok=$ok modes_red=$red arms=4 (tree $(git -C "$B" rev-parse --short HEAD 2>/dev/null))"
if [ $red -eq 0 ]; then echo "GATE OK [test_gate_pl_autoload_2_and_an_explicit_import_into_a_module_reach_the_library_over_a_user_definition_as_swipl]: both modes answer as swipl"; exit 0; fi
echo "GATE FAIL [test_gate_pl_autoload_2_and_an_explicit_import_into_a_module_reach_the_library_over_a_user_definition_as_swipl]: $red of 2 mode(s) diverge"; exit 1
