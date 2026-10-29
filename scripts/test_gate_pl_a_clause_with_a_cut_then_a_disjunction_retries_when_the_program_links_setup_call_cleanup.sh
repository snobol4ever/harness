#!/usr/bin/env bash
# test_gate_pl_a_clause_with_a_cut_then_a_disjunction_retries_when_the_program_links_setup_call_cleanup.sh -- a clause  mm(X) :- !, (X = g ; X = i).  answers g, then i on
# backtracking, as swipl 9.0.4 does, in a program that links setup_call_cleanup (hq_packages 2026-10-21, found by SWI xsb/table_tests expand: the run died SIGSEGV
# before scrip reported the case and every case after it read "no verdict" -- 17 of the file's 32).
# THE WITNESS IS FOUR LINES AND NO TABLING, NO LOADER: arm 1 is the clause plus any clause that names setup_call_cleanup (never called); arm 2 is the clause under
# with_output_to/2, whose lowering links the same cleanup machinery. Without the cleanup link the same clause is right in both modes (arm 0, a control).
# CAUSE (measured on the emitted .s, SCRIP b444ca747): with cleanup linked the cut is preceded by the cleanup probe and a staged call to $scc_cut/0, so the cut leaves 16 bytes
# live (lea rsp, [rbp - 16]) and the disjunction's frame sits at rbp - 48; each arm's gamma then leaves with  add rsp, 48; jmp mm/1_ret0  -- it releases the disjunction's own
# 32-byte state although an alternative is pending, the caller's next frames overwrite the trail mark at [rsp + 24], and the redo enters the disjunction's beta with that
# slot reading 0: pl_tr_unwind pops the r12 trail down past its slab and the first entry it reads is the text "CTBLOCK2" -> SIGSEGV (general-protection fault, mov [rdi], rax).
# Without the cleanup link the cut is  lea rsp, [rbp + 0]  and the gamma is a bare  jmp ret0  (the state stays on the spine). The pair rsp comes from emit.cpp's
# flat_drive_match_alt (zd_edge_retains / zd_pl_dj_arm_holds); the pre-spine build (SCRIP de14c4404 + the loader commits) answers all arms.
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: every run re-cuts them from the live /usr/bin/swipl and REFUSES rc=2 when oracle and table disagree.
# Usage: bash ../harness/scripts/test_gate_pl_a_clause_with_a_cut_then_a_disjunction_retries_when_the_program_links_setup_call_cleanup.sh
set -uo pipefail
GATE_NAME=test_gate_pl_a_clause_with_a_cut_then_a_disjunction_retries_when_the_program_links_setup_call_cleanup
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
printf '%s\n' 'mm(X) :- !, (X = g ; X = i).' ':- initialization(((mm(X), write(X), nl, fail ; true), write(done), nl, halt)).' > "$d/a0.pl"
printf '%s\n' 'mm(X) :- !, (X = g ; X = i).' 'unused :- setup_call_cleanup(true, true, true).' ':- initialization(((mm(X), write(X), nl, fail ; true), write(done), nl, halt)).' > "$d/a1.pl"
printf '%s\n' 'mm(X) :- !, (X = g ; X = i).' ':- initialization((with_output_to(string(S), forall(mm(X), write(X))), write(S), nl, halt)).' > "$d/a2.pl"
printf 'g\ni\ndone\n' > "$d/a0.want"; cp "$d/a0.want" "$d/a1.want"; printf 'gi\n' > "$d/a2.want"
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
    if (cd "$d" && timeout -k 5 60 "$SCRIP" --compile --out="$a.s" "$a.pl" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "$a.bin" "$a.s" "$OUT/libscrip_rt.so" -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
        (cd "$d" && timeout -k 5 30 "./$a.bin" </dev/null 2>/dev/null > "$d/$a.m4"); rc=$?
        if [ $rc -ne 0 ] || ! cmp -s "$d/$a.want" "$d/$a.m4"; then fails=$((fails + 1)); echo "  $a m4 rc=$rc differs:"; diff "$d/$a.want" "$d/$a.m4" | head -6; fi
    else fails=$((fails + 1)); echo "  $a m4 did not compile or link"; fi
done
echo "PLCUTDISJ_BOARD programs=3 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
