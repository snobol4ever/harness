#!/usr/bin/env bash
# test_gate_pl_a_tabled_subgoal_deeper_than_max_table_subgoal_size_raises_the_tripwire_as_swipl.sh -- with the flag max_table_subgoal_size set and
# max_table_subgoal_size_action error, a tabled call whose subgoal nests compounds deeper than swipl 9.0.4 allows raises
# error(resource_error(tripwire(max_table_subgoal_size, Module:MostGeneralGoal)), _) instead of recursing until the stack is gone; a subgoal within the limit
# tables as usual, m3 and m4 (hq_packages 2026-10-22, SWI xsb/table_tests test_calldepth: p(X) :- p(f(X)) died ERROR 246 stack overflow and the run's later cases read no verdict).
# THE RULE (swipl's pl-trie.c trie_lookup_abstract, size_abstract from_depth 2): the compound at depth N+3 of the goal (the goal itself is depth 1) is the first abstracted,
# so a chain of compounds in an argument trips when it is N+2 deep; the check runs where a NEW table is created ('$tbl_restrain' in prolog_parse.c's '$tbl_get').
# ARMS: (1) p(X) :- p(f(X)) at N=4 trips with the flag name and user:p(_); (2) the same program with a goal 2 deep (N=4) tables and answers; (3) the flag unset: no check.
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: every run re-cuts them from the live /usr/bin/swipl and REFUSES rc=2 when oracle and table disagree.
# The program names library(lists) because a SCRIP program creates an unknown flag (set_prolog_flag) only under the SWI dialect that a library load selects.
# Usage: bash ../harness/scripts/test_gate_pl_a_tabled_subgoal_deeper_than_max_table_subgoal_size_raises_the_tripwire_as_swipl.sh
set -uo pipefail
GATE_NAME=test_gate_pl_a_tabled_subgoal_deeper_than_max_table_subgoal_size_raises_the_tripwire_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/w.pl" <<'PL'
:- use_module(library(lists)).
:- table p/1, r/1.
p(X) :- p(f(X)).
r(X) :- member(X, [a, f(a), f(f(a))]).
show(G) :- copy_term(G, G2), numbervars(G2, 0, _), writeq(G2).
t1 :- set_prolog_flag(max_table_subgoal_size, 4), set_prolog_flag(max_table_subgoal_size_action, error),
      catch(p(_), error(resource_error(tripwire(F, M:G)), _), (write(caught(F, M)), write(' '), show(G), nl)).
t2 :- abolish_all_tables, findall(X, r(X), L), msort(L, S), write(within(S)), nl.
t3 :- abolish_all_tables, set_prolog_flag(max_table_subgoal_size, infinite), findall(X, r(X), L), msort(L, S), write(unset(S)), nl.
:- initialization((t1, t2, t3, halt)).
PL
(cd "$d" && timeout -k 5 60 "$SWIPL" -q w.pl </dev/null > "$d/want" 2>/dev/null)
[ "$(wc -l < "$d/want")" -eq 3 ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: the oracle did not print three lines"; head -3 "$d/want"; exit 2; }
grep -q '^caught(max_table_subgoal_size,user) p(A)$' "$d/want" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the oracle's first line is not the tripwire: $(head -1 "$d/want")"; exit 2; }
fails=0; graded=0
(cd "$d" && timeout -k 5 60 "$SCRIP" w.pl </dev/null 2>/dev/null > "$d/m3"); rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/want" "$d/m3" | head -8; fi
graded=$((graded + 1))
if (cd "$d" && timeout -k 5 120 "$SCRIP" --compile -o w.s w.pl </dev/null >/dev/null 2>&1 && gcc -no-pie -o w.bin w.s "$OUT/libscrip_rt.so" -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
    (cd "$d" && timeout -k 5 60 ./w.bin </dev/null 2>/dev/null > "$d/m4"); rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/want" "$d/m4" | head -8; fi
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLTBLTRIP_BOARD arms=3 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
