#!/usr/bin/env bash
# test_gate_pl_a_dynamic_clause_with_a_disjunction_then_an_if_then_else_then_fail_retries_the_disjunction.sh -- a clause
#   t :- (fail ; true), (true -> write(a) ; write(b)), fail.     followed by   t :- writeln(end).
# prints  aend  as swipl 9.0.4 does, whether the clauses are static (arm 0, the control), declared dynamic in the file (arm 1) or added by assertz (arm 2).
# (cfo 2026-10-21, bisected to SCRIP c8cdf6c4b; reproduced by hq_zetas on origin d048caea2: arms 1 and 2 die SIGSEGV in both modes, arm 0 is right.)
# CAUSE, measured by a gdb single-step of the packet from its entry and the ZD plan (SCRIP_ZD_MAP, SCRIP_ZD_DIAG): the packet graph t/0@0 plans IR_GATE_ARM with gpop=80 where the
# static graph plans 64. The then-branch's gate arm pops 80 in one add (rbp - rsp 112 to 32) and the gate's beta pops its own 16 again (to 16) before jumping to the disjunction's
# beta, so the beta reads its arm index and trail mark at rsp+16 and rsp+24 from rbp-16, the frame's zeroed return slot, and pl_tr_unwind unwinds the trail down its slab.
# The gpop is 0 after the bases pass and 80 from the cross-claim loop of zd_plan on; the packet graph carries an extra IR_GOTO tail node (claim 11, INDEF) the static graph does not.
# ZD-CHECK reads the packet graph with violations=0, so the checker does not see the edge. Before c8cdf6c4b the disjunction beta failed out without reading its cell, which hid the extra pop.
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: every run re-cuts them from the live /usr/bin/swipl and REFUSES rc=2 when oracle and table disagree.
# Usage: bash ../harness/scripts/test_gate_pl_a_dynamic_clause_with_a_disjunction_then_an_if_then_else_then_fail_retries_the_disjunction.sh
set -uo pipefail
GATE_NAME=test_gate_pl_a_dynamic_clause_with_a_disjunction_then_an_if_then_else_then_fail_retries_the_disjunction
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
printf '%s\n' 't :- (fail ; true), (true -> write(a) ; write(b)), fail.' 't :- writeln(end).' ':- initialization((t, halt)).' > "$d/a0.pl"
printf '%s\n' ':- dynamic t/0.' 't :- (fail ; true), (true -> write(a) ; write(b)), fail.' 't :- writeln(end).' ':- initialization((t, halt)).' > "$d/a1.pl"
printf '%s\n' ':- dynamic t/0.' ':- initialization(main).' 'main :- assertz((t :- (fail ; true), (true -> write(a) ; write(b)), fail)), assertz((t :- writeln(end))), t, halt.' > "$d/a2.pl"
printf 'aend\n' > "$d/a0.want"; cp "$d/a0.want" "$d/a1.want"; cp "$d/a0.want" "$d/a2.want"
for a in a0 a1 a2; do
    (cd "$d" && timeout -k 5 30 "$SWIPL" -q "$a.pl" </dev/null > "$d/$a.oracle" 2>/dev/null)
    cmp -s "$d/$a.want" "$d/$a.oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table for $a is not what $SWIPL prints now"; diff "$d/$a.want" "$d/$a.oracle" | head -5; exit 2; }
done
fails=0; graded=0
for a in a0 a1 a2; do
    graded=$((graded + 1))
    (cd "$d" && timeout -k 5 30 "$SCRIP" "$a.pl" </dev/null 2>/dev/null > "$d/$a.m3"); rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/$a.want" "$d/$a.m3"; then fails=$((fails + 1)); echo "  $a m3 rc=$rc differs:"; diff "$d/$a.want" "$d/$a.m3" | head -6; fi
    graded=$((graded + 1))
    if (cd "$d" && timeout -k 5 60 "$SCRIP" --compile -o "$a.s" "$a.pl" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "$a.bin" "$a.s" "$OUT/libscrip_rt.so" -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
        (cd "$d" && timeout -k 5 30 "./$a.bin" </dev/null 2>/dev/null > "$d/$a.m4"); rc=$?
        if [ $rc -ne 0 ] || ! cmp -s "$d/$a.want" "$d/$a.m4"; then fails=$((fails + 1)); echo "  $a m4 rc=$rc differs:"; diff "$d/$a.want" "$d/$a.m4" | head -6; fi
    else fails=$((fails + 1)); echo "  $a m4 did not compile or link"; fi
done
echo "PLDYNDISJITE_BOARD programs=3 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
