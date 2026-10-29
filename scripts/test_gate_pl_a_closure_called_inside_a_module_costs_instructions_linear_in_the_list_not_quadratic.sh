#!/bin/bash
# test_gate_pl_a_closure_called_inside_a_module_costs_instructions_linear_in_the_list_not_quadratic.sh -- THE MODULE CLOSURE ROAD IS LINEAR
# (hq_zetas, the regression of d748bc145: a closure of a module predicate became Module:Closure and every call went through the Prolog clauses of ':'/N, whose
# cut walked the whole trail, 18.7 billion instructions for maplist over 20,000 elements against 147 million for the same program outside a module; the cure is
# the direct leaf '$mod_ext' under one clause per arity, 263 million). The instrument is callgrind (instructions, not time, immune to load) over the compiled
# program in mode 4: the module program's instructions must stay under four times the plain program's, and the same module program over a quarter of the list
# must cost between 0.15 and 0.4 of the full one (measured 0.20; a quadratic road costs 0.10). rc 0 both readings hold; rc 1 a reading fails; rc 2 refused (no valgrind, a stale build).
HERE="$(cd "$(dirname "$0")" && pwd)"
S="$HERE/../../SCRIP"
refuse() { echo "REFUSE(2): $*"; exit 2; }
command -v valgrind >/dev/null 2>&1 || refuse "valgrind missing -- the budget is an instruction count"
[ -x "$S/scrip" ] || refuse "no $S/scrip"
D="$HERE/../../.scratch/mcl-$$"; mkdir -p "$D"; trap 'rm -rf "$D"' EXIT
mk() {
    printf '%s\n' ":- module(cm, [])." ":- initialization(main)." "inc(X, Y) :- Y is X + 1." "main :- numlist(1, $1, L), maplist(inc, L, L2), sum_list(L2, S), write(S), nl." > "$D/m$1.pl"
    printf '%s\n' ":- initialization(main)." "inc(X, Y) :- Y is X + 1." "main :- numlist(1, $1, L), maplist(inc, L, L2), sum_list(L2, S), write(S), nl." > "$D/p$1.pl"
}
ir() {
    ( cd "$S" && ./scrip --compile --out="$D/$1.s" "$D/$1.pl" < /dev/null > /dev/null 2>&1 ) || refuse "scrip --compile $1.pl failed"
    gcc -no-pie "$D/$1.s" -L"$S/out" -lscrip_rt -lm -Wl,-rpath,"$S/out" -o "$D/$1.bin" > /dev/null 2>&1 || refuse "link $1 failed"
    ( cd "$D" && valgrind --tool=callgrind --callgrind-out-file="$D/cg.$1" "./$1.bin" < /dev/null > /dev/null 2> "$D/vg.$1" ) || refuse "callgrind $1 failed"
    grep -o "Collected : [0-9]*" "$D/vg.$1" | grep -o "[0-9]*$"
}
mk 20000; mk 5000
M20="$(ir m20000)"; P20="$(ir p20000)"; M5="$(ir m5000)"
[ -n "$M20" ] && [ -n "$P20" ] && [ -n "$M5" ] || refuse "a reading came back empty"
echo "module 20000: $M20 Ir; plain 20000: $P20 Ir; module 5000: $M5 Ir"
rc=0
[ "$M20" -lt $((P20 * 4)) ] || { echo "GATE FAIL -- the module program costs $M20 instructions, not under four times the plain program's $P20"; rc=1; }
[ $((M5 * 20)) -gt $((M20 * 3)) ] && [ $((M5 * 10)) -lt $((M20 * 4)) ] || { echo "GATE FAIL -- a quarter of the list costs $M5 against $M20 for the whole: not linear (the fix reads 0.20, a quadratic road 0.10)"; rc=1; }
[ $rc -eq 0 ] && echo "GATE OK -- a closure called inside a module costs instructions linear in the list, within four times the plain program"
exit $rc
