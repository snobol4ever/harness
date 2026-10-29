#!/usr/bin/env bash
# test_gate_pl_a_fresh_variable_after_a_findall_over_a_multi_clause_predicate_keeps_its_cell_when_main_called_setup_call_cleanup.sh -- a fresh variable after a findall over a predicate of two clauses keeps its cell when the
# clause called setup_call_cleanup first (row prolog-mode-3-a-fresh-variable-after-findall-over-a-multi-clause-predicate-fails-when-main-called-setup-call-cleanup,
# hq_prolog 2026-10-22, found while curing the Logtalk nolink class): in mode 3 length(L, N), N = foo and copy_term(L, M) after the findall raised
# type_error(integer, [x,x]) or failed, and the clause printed nothing.
# THE DEFECT: zst_finish (emit.cpp) gave a sticky local its rbp-relative home from the run-relative zout with base 0 when the run's base was UNKNOWN
# (the bases pass marks a run entered after a retaining call INDEF, no base: here the run after the restoring UNMARK of the scc/findall BOUND), so the
# variable's pointer named [rbp-48] while its cell was zeroed at [rsp+16] eighty bytes lower; mode 4 read a dead cell that happened to be zero, mode 3 read stack garbage.
# THE CURE: a sticky local whose run base is unknown is not homed (the entry is dropped, the variable keeps its frame slot).
# WHAT IS GRADED: three clauses, each setup_call_cleanup(true,true,true) then findall(x, v1(_), L) over two unit clauses, then length(L, N) / N = foo /
# copy_term(L, M), printed; both modes print what swipl prints.
# THE REF IS CUT FROM THE ORACLE, NEVER FROM SCRIP: the expectation below was cut 2026-10-22 from /usr/bin/swipl by absolute path, and every run
# re-cuts it from the live swipl and REFUSES rc=2 when the oracle and the table disagree or swipl is absent.
# FAIL-ONCE: on origin 37138a1dd 0 of 2: mode 3 printed nothing, mode 4 stopped at the assembler (the label defect cured at 848d9f439); on 848d9f439 mode 3 alone reads red.
# Usage: bash ../harness/scripts/test_gate_pl_a_fresh_variable_after_a_findall_over_a_multi_clause_predicate_keeps_its_cell_when_main_called_setup_call_cleanup.sh
set -uo pipefail
GATE_NAME=test_gate_pl_a_fresh_variable_after_a_findall_over_a_multi_clause_predicate_keeps_its_cell_when_main_called_setup_call_cleanup
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
t1 :- setup_call_cleanup(true, true, true), findall(x, v1(_), L), length(L, N), write(N), nl.
t2 :- setup_call_cleanup(true, true, true), findall(x, v1(_), L), N = foo, write(L-N), nl.
t3 :- setup_call_cleanup(true, true, true), findall(x, v1(_), L), copy_term(L, M), write(M), nl.
:- initialization(main).
main :- t1, t2, t3, halt.
PL
cat > "$d/scc.want" <<'WANT'
2
[x,x]-foo
[x,x]
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
echo "PLSCCVAR_BOARD programs=1 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
