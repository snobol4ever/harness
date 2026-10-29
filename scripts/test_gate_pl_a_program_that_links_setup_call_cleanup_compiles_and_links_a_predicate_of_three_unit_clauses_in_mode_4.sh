#!/usr/bin/env bash
# test_gate_pl_a_program_that_links_setup_call_cleanup_compiles_and_links_a_predicate_of_three_unit_clauses_in_mode_4.sh -- a program that links
# setup_call_cleanup/3 and holds a predicate of three unit clauses (v1(_). v1(_). v1(_).) assembles and links in mode 4 and prints as swipl does
# (row prolog-logtalk-eight-bagof-and-setof-cases-pass-in-mode-3-and-do-not-link-in-mode-4-ceo-1887, hq_prolog 2026-10-22: eight Logtalk bagof_3 and
# setof_3 cases passed in mode 3 and died in mode 4 at the assembler, "symbol .Lv1$2F1_a_10384_246 is already defined").
# THE DEFECT: the release check the setup_call_cleanup road adds to a flat procedure's omega (x86_pl_scc_release_check, xa_flat.cpp) took local label
# 246 for its skip target, and the same procedure's inline choice mark (x86_pl_choice_mark, emitted when the predicate has more than one clause)
# owns 245 through 249 in the same node: one label defined twice, so the .s did not assemble.
# WHAT IS GRADED: v1/1 and v2/2 of three unit clauses each, in a program that links setup_call_cleanup (a clause nothing calls names it), counted through
# findall/3: the program compiles, assembles and links in mode 4 and both modes print 3 and 3, the oracle's answer.
# THE REF IS CUT FROM THE ORACLE, NEVER FROM SCRIP: the expectation below was cut 2026-10-22 from /usr/bin/swipl by absolute path, and every run
# re-cuts it from the live swipl and REFUSES rc=2 when the oracle and the table disagree or swipl is absent.
# FAIL-ONCE: on origin 37138a1dd mode 3 printed 3 and 3 and mode 4 stopped at the assembler (the label named above).
# Usage: bash ../harness/scripts/test_gate_pl_a_program_that_links_setup_call_cleanup_compiles_and_links_a_predicate_of_three_unit_clauses_in_mode_4.sh
set -uo pipefail
GATE_NAME=test_gate_pl_a_program_that_links_setup_call_cleanup_compiles_and_links_a_predicate_of_three_unit_clauses_in_mode_4
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/scc.pl" <<'PL'
v1(_).
v1(_).
v1(_).
v2(_, _).
v2(_, _).
v2(_, _).
unused :- setup_call_cleanup(true, true, true).
:- initialization(main).
main :-
    findall(x, v1(_), L1), length(L1, N1), write(N1), nl,
    findall(x, v2(_, _), L2), length(L2, N2), write(N2), nl,
    halt.
PL
cat > "$d/scc.want" <<'WANT'
3
3
WANT
fails=0; graded=0
"$SWIPL" -q -g main -t halt "$d/scc.pl" </dev/null > "$d/scc.oracle" 2>/dev/null
cmp -s "$d/scc.want" "$d/scc.oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not what $SWIPL prints now"; diff "$d/scc.want" "$d/scc.oracle" | head -5; exit 2; }
timeout -k 5 20 "$SCRIP" "$d/scc.pl" </dev/null 2>/dev/null > "$d/scc.m3"; rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/scc.want" "$d/scc.m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/scc.want" "$d/scc.m3" | head -10; fi
graded=$((graded + 1))
if timeout -k 5 60 "$SCRIP" --compile --out="$d/scc.s" "$d/scc.pl" </dev/null >/dev/null 2>&1; then
    if as --64 -o "$d/scc.o" "$d/scc.s" 2> "$d/scc.aserr" && gcc -no-pie -o "$d/scc.bin" "$d/scc.o" "$OUT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$OUT" 2>/dev/null; then
        timeout -k 5 20 "$d/scc.bin" </dev/null 2>/dev/null > "$d/scc.m4"; rc=$?
        if [ $rc -ne 0 ] || ! cmp -s "$d/scc.want" "$d/scc.m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/scc.want" "$d/scc.m4" | head -10; fi
    else fails=$((fails + 1)); echo "  m4 did not assemble or link:"; head -3 "$d/scc.aserr" | cut -c1-200; fi
else fails=$((fails + 1)); echo "  m4 did not compile"; fi
echo "PLSCCLBL_BOARD programs=1 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
