#!/usr/bin/env bash
# test_gate_pl_clpfd_helpers_called_by_name_answer_as_swipl.sh -- THE CLPFD ROADS THAT REACH A HELPER BY ITS NAME AS DATA
# ANSWER AS SWIPL, IN BOTH MODES (cfo 2026-10-10, row prolog-clpfd-the-gnu-fd-spelling-...-ceo-1596; the vendoring scheme of
# CEO-1473, util_gen_prolog_prelude_libs.py's RENAME_AS_DATA).
#
# THE DEFECT.  The generator renames a vendored library's local helpers into '$clpfd_<name>' so they cannot collide with a
# program's predicates, by rewriting every REFERENCE SWI's reader reports.  Sixteen clpfd helpers are reached by their NAME
# AS DATA -- override(selection, ...) through call/2, maplist(unwrap_with(bare_integer), ...), scc(_, g0_successors),
# maplist(maplist(clear_parent), ...), foldl(conjunction, ...), include_args1(sink, ...) -- and the bare atom was never
# renamed, so labeling/2 with any option died on selection/1, sum/3 and scalar_product/4 on bare_integer/2, circuit/1 on
# circuit_successors/2, global_cardinality/2 on gcc_successors and g0_successors, all_distinct/1 on clear_parent and
# fd_variable.  RENAME_AS_DATA lists them and the generator renames the bare atom with the helper.
#
# THE ARM: one program over those roads -- labeling with selection, order and choice options, sum/3, scalar_product/4,
# circuit/1, global_cardinality/2, all_distinct/1 (which also needs the C unifier's attributed-variable rule, its own gate),
# a reification over a disjunction, tuples_in/2 -- cut against swipl -q in this run, diffed in mode 3 and mode 4.
# FAIL-ONCE, measured on 70f3505ed: labeling with options raised existence_error(selection/1) on the first line, so 9 of 9
# lines differ in both modes; with the rename 9 of 9 as swipl.  rc=0 both modes agree · rc=1 a divergence · rc=2 REFUSAL.
# COST: the mode-4 compile of a program naming clpfd emits the whole library (~140 MB of asm): ~30 s at load 10.
# STACK: the nine lines in one main/0 overflow SCRIP's 4 MB default (ERROR 246 at the circuit line; any single line, or any
# two, runs at 4 MB) and run whole at 8 MB, so the witness declares -s8192k in both modes (RULES.md hard-cap clause 8 (g)).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_clpfd_helpers_called_by_name_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- use_module(library(clpfd)).
:- initialization(main).
main :- Vs = [A,B,C], Vs ins 1..3, all_different(Vs), labeling([ff, down], Vs), writeq(Vs), nl,
    [P,Q] ins 1..3, P #< Q, labeling([min, up, bisect], [P,Q]), writeq(P-Q), nl,
    length(Ss, 3), Ss ins 0..5, sum(Ss, #=, 7), Ss = [S1,S2,S3], S1 #< S2, S2 #< S3, label(Ss), writeq(Ss), nl,
    scalar_product([2,3], [X,Y], #=, 12), [X,Y] ins 0..6, label([X,Y]), writeq(X-Y), nl,
    length(Cs, 4), circuit(Cs), Cs = [2|_], label(Cs), writeq(Cs), nl,
    Gs = [G1,G2,G3], Gs ins 1..2, global_cardinality(Gs, [1-2, 2-1]), G1 #= 2, label(Gs), writeq(Gs), nl,
    Ds = [D1,D2,D3,D4], Ds ins 1..4, all_distinct(Ds), D1 #= 1, D2 #= 2, label(Ds), writeq(Ds), nl,
    [R1,R2,R3] ins 0..1, R1 #\/ R2 #<==> R3, R1 #= 0, R3 #= 1, label([R1,R2,R3]), writeq([R1,R2,R3]), nl,
    tuples_in([[T1,T2]], [[1,2],[2,3],[3,1]]), T1 #= 2, writeq(T1-T2), nl, halt.
PL
( cd "$D" && timeout -k 5 60 swipl -q -t halt w.pl < /dev/null 2> /dev/null | sed -E 's/_[0-9]+/_V/g' > want )
[ -s "$D/want" ] || refuse "swipl printed nothing for the witness"
( cd "$D" && timeout -k 5 60 "$B/scrip" -s8192k --run w.pl < /dev/null 2> m3.err | sed -E 's/_G?[0-9]+/_V/g' > m3 )
( cd "$D" && timeout -k 5 300 "$B/scrip" --compile -o w.s w.pl < /dev/null 2> m4.err && gcc -no-pie w.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o w 2>> m4.err && timeout -k 5 60 ./w -s8192k < /dev/null 2>> m4.err | sed -E 's/_G?[0-9]+/_V/g' > m4 )
n=$(wc -l < "$D/want"); red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  $m GREEN: $n of $n lines as swipl"
    else echo "  $m RED: $(diff "$D/want" "$D/$m" 2>/dev/null | grep -c '^<') of $n lines differ from swipl"; diff "$D/want" "$D/$m" 2>/dev/null | head -8 | sed 's/^/    /'; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
