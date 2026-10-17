#!/usr/bin/env bash
# ../harness/scripts/test_gate_no_c_to_bb_ratchet.sh — THE PER-SITE RATCHET UNDER test_gate_no_c_to_bb.sh (cfo 2026-09-20).
#
# LON, 2026-09-20 07:3x CDT, in-chat to the cfo, verbatim: "Ensure that BB's are never called from C except
# the first time at initial start."  This gate is the ENSURE.  The convention itself is stated and measured by
# test_gate_no_c_to_bb.sh; that gate finds every transfer and names it.  What it could not do is stop a NEW one.
#
# ⛔ THE SEAM THIS CLOSES, AND IT IS IN THE OTHER GATE'S OWN ARITHMETIC — READ THIS BEFORE TOUCHING EITHER FILE.
# test_gate_no_c_to_bb.sh computes its verdict as N=$(echo $VGRPS | wc -w): the number of LEDGER GROUPS still
# populated, which is 3 today (V4, V6, V7) while TWELVE transfer sites exist.  A thirteenth transfer added to an
# already-populated group therefore moves NOTHING that gate reports as its verdict -- N stays 3, the STRICT line
# reads the same, and the regression is invisible.  Only an UNLEDGERED transfer (one no ledger arm classifies)
# raises its own flag.  So the existing gate answers "are there groups left", and this one answers "did the
# population grow", which is the question "ensure" actually asks.  Neither is a substitute for the other.
#
# ⛔ AND IT IS UNWIRED, WHICH IS THE OTHER HALF.  test_gate_no_c_to_bb.sh sits in gate_wiring.tsv as TASK -- a
# row's DONE-WHEN instrument, reachable from no blocking set -- so on 2026-09-20 NOTHING in `make test` would
# have reddened for a new C-to-BB entry.  This gate is wired into the blocking set in the same landing.  It is
# GREEN at its pins today, so it adds an arm and not a red: it goes red the moment the population rises.
#
# ⭐ WHY A RATCHET IS LEGITIMATE HERE.  test_gate_term_wordref_ratchet.sh's header states the one question that
# makes this shape honest rather than a tripwire on legitimate work -- CAN THIS COUNT REACH ZERO BY DESIGN? --
# and names test_gate_rbp_census_ratchet.sh, which retired its own ratchet because its count could not.  Here
# the answer is Lon's sentence above: every C-to-BB transfer outside the sanctioned initial start is debt the
# fleet is actively deleting, and 0 is the intended terminal value.  The sanctioned sites are NOT in this count
# at all (the underlying gate excludes them before printing), so a legitimate MAIN entry can never trip this.
#
# THE COUNTING METHOD IS NOT A CHOICE -- IT IS THE OTHER GATE'S OWN OUTPUT, PARSED.  Re-deriving the transfer
# set here with a second grep would fork the definition: two gates would drift on what a transfer IS, and the
# ratchet would eventually hold a population the gate does not name.  So this runs the gate (--informational, so
# its own STRICT exit cannot mask this verdict) and counts the site lines it prints, keyed by file.
#
# ⛔ UNPINNED FILE WITH ANY TRANSFER == FAIL.  Without it the ratchet is dodged by moving an entry into a new
# file, which is exactly the motion a conversion produces.  A new file is not a fresh budget.
#
# HOW TO RE-PIN: lower a pin ONLY in the same commit as the landing that earned it, and never above measured --
# slack is the only failure mode that matters in a ratchet.  Run the ONE_LINER at the foot of this file.
GATE_NAME="test_gate_no_c_to_bb_ratchet"
. "$(dirname "$0")/lib_gate.sh"
gate_parse_args "$@"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
NCB="$REPO/../harness/scripts/test_gate_no_c_to_bb.sh"
if [ ! -x "$NCB" ] && [ ! -f "$NCB" ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: ../harness/scripts/test_gate_no_c_to_bb.sh is absent -- this gate measures ITS output and invents no census of its own"
    gate_stamp
    exit 2
fi
OUT="$(bash "$NCB" --informational 2>&1)"
# ⛔ THE UNDERLYING GATE'S OWN REFUSAL IS INHERITED, NOT SWALLOWED.  It prints a population line and refuses
# below a floor of 100 source files; if that line is missing the sweep did not happen and a 0 here would be the
# zero-work-examined false green this whole family exists to refuse.
POP=$(printf '%s\n' "$OUT" | sed -n 's/^population: examined \([0-9][0-9]*\) source files.*/\1/p' | head -1)
if [ -z "$POP" ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: test_gate_no_c_to_bb.sh printed no population line -- it did not measure, so neither did this"
    printf '%s\n' "$OUT" | head -20
    gate_stamp
    exit 2
fi
# ── PINS ── measured at SCRIP c6bf8e789, 2026-09-20, by the ONE_LINER below.  Umbrella total 10.
# ⛔ EDIT ONLY DOWNWARD.  rt.c is the cfo's (row gc-rt-c-c-to-bb-entries-...): 4 asm shims + rt_proc_call_gen_h's
# member-fnptr, all five blocked on the 19 foreign callers in the ceo's files.
# ⭐ 7 -> 5 ON 2026-09-20, AND IT IS A SANCTION PLUS A MOVE, NOT A CONVERSION (cto, CEO-970): the two generator
# spines rt_genp_spine_enter and rt_genp_spine_enter_n2 were held here pending the ceo's ruling on whether a
# fresh coroutine stack's first frame is the sanctioned initial-start class.  The ceo ruled it IS -- both are
# reached only from rt_genp_entry_c, which rt_genp_thread_entry jumps to, which scrip_co_ctx_init installs as
# the entry on a fresh coroutine stack with no emitted code beneath it, structurally identical to
# scrip_coexpr_trampoline_entry -- so they moved beside that twin in rt_coexpr.c and test_gate_no_c_to_bb.sh
# sanctions them by name.  ⛔ THE cfo's ROW DID NOT ADVANCE BY THIS: rt.c reads 5 because two entries left the
# file sanctioned, not because two conversions landed.  If Lon's INITIAL START is per-run rather than per-stack,
# the sanction is withdrawn, the two return as conversions on the cfo's row, and this pin goes back to 7.
# runtime_eval.c and by_name_dispatch.c are the ceo's row gc-the-five-c-to-bb-entries-outside-rt-c-....
# ⭐ 10 -> 0 ON 2026-10-14 (cto, CEO-1749): the sweep on SCRIP 0bd04f618 reads no transfer left in rt.c, by_name_dispatch.c
# or runtime_eval.c, so all three pins drop; the one transfer the sweep sees is rt_sc_module.c's, whose pin or cure is
# hq_snocone's rank-0 row under CEO-1749.
# ⭐ rt_sc_module.c pinned at 1 on 2026-10-14 (hq_snocone, CEO-1749): rt_sc_outer_call, the COMPILE-TIME entry of the linked parse-stage module
# (no program live) -- a whole-program entry sanctioned as CEO-1735 reads it. The run-time arm (CODE/EVAL with a program live) takes the C
# parser and has no pin; a run-time parse through the module returns later as a BOX ROAD (CEO-1576), its own row.
PINS="
1 src/runtime/rt/rt_sc_module.c
"
PIN_TOTAL=$(echo "$PINS" | awk 'NF{t+=$1} END{print t+0}')
# The site lines the gate prints are indented and shaped `    <file>:<line>  (<fn>, <shape>)`; the ledger-group
# headers (`V4:`) and the banner lines carry no such pair, so this matches transfers and nothing else.
SITES="$(printf '%s\n' "$OUT" | sed -n 's/^[[:space:]][[:space:]]*\(src\/[A-Za-z0-9_./-]*\):[0-9][0-9]*[[:space:]][[:space:]]*(.*/\1/p')"
TOTAL=$(printf '%s\n' "$SITES" | grep -c .)
FILES=$(printf '%s\n' "$SITES" | grep . | sort -u)
gate_floor "$POP" 100 "source files swept by test_gate_no_c_to_bb.sh for C-to-BB transfers"
# ⭐ THE FINISH LINE.  A ratchet that could only refuse at zero could never say YES to its own goal (the
# criterion-that-cannot-say-YES defect, INSTRUMENT LAWS).  The sweep ran -- the population line above proves it
# -- so zero transfers is the convention SEALED, which is Lon's sentence satisfied, not "nothing examined".
if [ "$TOTAL" -eq 0 ]; then
    echo "✅ GATE OK [$GATE_NAME]: 0 C-to-BB transfers outside the sanctioned initial start, across $POP source files -- THE RATCHET REACHED ZERO (pin total was $PIN_TOTAL). Lon 2026-09-20: \"Ensure that BB's are never called from C except the first time at initial start.\" A file that reintroduces one fails the unpinned-file rule."
    gate_stamp
    exit 0
fi
VIOL=0; TIGHTEN=""
echo "── per-file C-to-BB transfers (method: the site lines test_gate_no_c_to_bb.sh itself prints) ──"
for f in $FILES; do
    n=$(printf '%s\n' "$SITES" | grep -cx "$f")
    pin=$(echo "$PINS" | awk -v p="$f" 'NF && $2==p {print $1; found=1} END{if(!found) print "UNPINNED"}')
    if [ "$pin" = "UNPINNED" ]; then
        printf '  ⛔ %6d  (unpinned)  %s\n' "$n" "$f"
        echo "        A file carrying a C-to-BB transfer with no pin is a RISE from an implicit 0 -- a new file is not a fresh budget."
        VIOL=$((VIOL + 1))
    elif [ "$n" -gt "$pin" ]; then
        printf '  ⛔ %6d  > pin %-4d %s   ROSE by %d\n' "$n" "$pin" "$f" "$((n - pin))"
        VIOL=$((VIOL + 1))
    elif [ "$n" -lt "$pin" ]; then
        printf '  ⭐ %6d  < pin %-4d %s   TIGHTEN by %d\n' "$n" "$pin" "$f" "$((pin - n))"
        TIGHTEN="$TIGHTEN $f:$pin->$n"
    else
        printf '     %6d  = pin %-4d %s\n' "$n" "$pin" "$f"
    fi
done
# ⭐ A PINNED FILE THAT VANISHED FROM THE REPORT IS PROGRESS, AND IT MUST STILL BE REPORTED -- otherwise the pin
# lingers as dead slack that a later transfer into the same file would silently inherit.
while read -r pin f; do
    [ -z "$f" ] && continue
    printf '%s\n' "$FILES" | grep -qx "$f" && continue
    printf '  ⭐ %6d  < pin %-4d %s   NO TRANSFER LEFT -- drop this pin\n' 0 "$pin" "$f"
    TIGHTEN="$TIGHTEN $f:$pin->0"
done <<< "$(echo "$PINS" | awk 'NF')"
echo "── umbrella total: $TOTAL transfer(s) across $(printf '%s\n' "$FILES" | grep -c .) file(s) (pin total $PIN_TOTAL) ──"
if [ -n "$TIGHTEN" ]; then
    echo "  ⭐ TIGHTEN AVAILABLE (the tree is better than its pins -- lower them in the commit that earned it):"
    for t in $TIGHTEN; do echo "        $t"; done
fi
# ONE_LINER -- regenerate the PINS block; never retype a number you did not produce (RULES.md § TRANSCRIPTION).
#   cd "$S4E_HOME/SCRIP" && bash ../harness/scripts/test_gate_no_c_to_bb.sh --informational 2>&1 \
#     | sed -n 's/^[[:space:]][[:space:]]*\(src\/[A-Za-z0-9_./-]*\):[0-9][0-9]*[[:space:]][[:space:]]*(.*/\1/p' | sort | uniq -c
gate_verdict "$VIOL" "file(s) ROSE above their C-to-BB transfer pin (or carry a transfer with no pin)"
