#!/usr/bin/env bash
# check_sbl_trace_and_folding.sh [sbl]  -- ceo 2026-09-05 (CEO-282): the SPITBOL oracle's OWN self-test for row
# snobol4-oracle-sbl-trace-dispatch-constants-fixed-in-the-fork-and-swapped (hq_B's four acceptance tests, the two computable here).
# rc 0 = the binary traces TRACE(X,'VALUE') AND TRACE(Y,'value') under -bf AND still folds names under -b (abc==ABC prints 5);
# rc 1 = one arm red (today: the x64 fork refuses every trace type with ERROR 199); rc 2 = cannot measure. ⛔ The -b arm is the oracle's
# folding self-test on the oracle itself, never a grading arm for SCRIP (RULES.md: programs are graded under -bf, always).
#
# MERGED 2026-09-05 by hq_B (the ceo and hq_B wrote this file concurrently; both versions kept their best half).
# ⭐ KEPT FROM THE ceo: all three arms are REPORTED, and rc accumulates -- the script never exits on the first red.
# That matters more than it looks: the two halves of this check fail INDEPENDENTLY, and "which arms are red" is the
# whole diagnosis. Exiting early would hide the folding arm behind the trace arm and vice versa.
#
# ⛔⭐ ADDED BY hq_B, TWO MEASURED TRAPS THAT BOTH LIVE IN THE OBVIOUS SPELLING OF THIS CHECK:
# (1) NO BARE `grep` ON A STDIN PIPE. Claude Code's shell injects a `grep` FUNCTION that silently misreads
#     `cmd | grep pattern` when there is no file argument -- empty/wrong instead of an error (seat01, 2026-09-05,
#     after it false-REFUSED a DONE-WHEN twice). Every match here is `command grep` against a FILE.
# (2) `&TRACE` MUST BE NONZERO OR NOTHING TRACES, on any binary, fixed or broken (manual v3.7 p.244). A witness
#     that omits it is SILENT and reads as "still broken" -- reporting RED at the exact moment the repair
#     succeeded. The version inlined in this row's DONE-WHEN omitted it; measured on the fixed build, without
#     `&TRACE` the program prints nothing and with it prints `****4*******  X = 1`. Fix the DONE-WHEN too.
#
# ⭐ WHY ALL THREE ARMS BELONG IN ONE SCRIPT: no build on this box passed both halves before the repair -- x64
# folded names and refused every trace type; stock traced and its &CASE folding was a silent no-op. Checking
# either half alone PASSES a binary that is broken in the other, which is exactly how this went unnoticed.
set -u
O="${1:-/home/resources/x64/bin/sbl}"
[ -n "$O" ] || { echo "REFUSED rc=2: no binary given"; exit 2; }
[ -f "$O" ] || { echo "REFUSED rc=2: no oracle at $O -- a check that cannot see its subject must never print a verdict"; exit 2; }
[ -x "$O" ] || { echo "REFUSED rc=2: not executable: $O"; exit 2; }
W=$(mktemp -d) || { echo "REFUSED rc=2: cannot make a work dir"; exit 2; }
trap 'rm -rf "$W"' EXIT
printf '\t&TRACE = 5\n\tTRACE("X", "VALUE")\n\tTRACE("Y", "value")\n\tX = 1\n\tY = 2\nEND\n' > "$W/t.sno"
printf '\tabc = 5\n\tOUTPUT = ABC\nEND\n' > "$W/f.sno"
timeout 8s "$O" -bf "$W/t.sno" </dev/null > "$W/t.out" 2>&1; trc=$?
timeout 8s "$O" -b  "$W/f.sno" </dev/null > "$W/f.out" 2>&1; frc=$?
{ [ "$trc" = 124 ] || [ "$trc" = 137 ] || [ "$frc" = 124 ] || [ "$frc" = 137 ]; } && { echo "REFUSED rc=2: $O timed out -- cannot measure"; exit 2; }
rc=0
if command grep -q 'X = 1' "$W/t.out"; then echo "PASS: TRACE(X,'VALUE') traces"
else
    e=$(command grep -m1 'ERROR [0-9]*' "$W/t.out" | tr -d '\n')
    echo "RED: $O does not trace TRACE(X,'VALUE'): ${e:-no diagnostic, output was empty}"
    case "$e" in *"ERROR 199"*) echo "     ^ the TRACE second-argument dispatch still compares against the lowercase ch_l* constants after folding to upper case; apply the eleven ch_u* (see ../harness/scripts/fix_sbl_trace_dispatch.sh)";; esac
    rc=1
fi
if command grep -q 'Y = 2' "$W/t.out"; then echo "PASS: TRACE(Y,'value') traces"
else echo "RED: lowercase type 'value' not traced -- the dispatch may work while the fold feeding it does not"; rc=1; fi
if [ "$(cat "$W/f.out")" = "5" ]; then echo "PASS: abc==ABC under -b folding prints 5"
else
    echo "RED: folding broke: abc==ABC under -b must print 5, got [$(tr '\n' ' ' < "$W/f.out")]"
    echo "     ^ if this is the ONLY red arm, flc was reverted to fold upper->lower and the trace defect was merely TRADED for the &CASE defect"
    rc=1
fi
echo "oracle=$O md5=$(md5sum "$O" | cut -d' ' -f1) rc=$rc"; exit $rc
