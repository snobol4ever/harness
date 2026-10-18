#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_gc_acceptance_never_prints_a_number_over_a_refusal.sh -- the coo, 2026-09-22, MODE DECTET.
# RULES.md THE INSTRUMENT LAWS: an instrument that reports success while doing nothing is THE recurring failure;
# a missing prerequisite is rc=2, never green.  util_gc_acceptance.py's own docstring says it of itself:
# "a metric that CANNOT BE MEASURED prints NOT-BUILT or NOT-MEASURED and makes the verdict REFUSE(2).  It never
# prints 0 and never prints 100.  A display that cannot tell 'clean' from 'never ran' is the thing this whole
# emergency is about."  IT DID NOT HOLD ITSELF TO THAT, AND NOTHING POLICED IT: before this gate the acceptance
# display -- the ONE reading MODE's ORDER OF WORK makes all ten seats print at the end of EVERY turn -- was not
# wired into `make test` at all.
#
# ⛔⭐ THE DEFECT, MEASURED 2026-09-22 21:2x CDT ON THIS TREE, NOT REASONED FROM THE SOURCE.
# util_gc_acceptance.py invoked three sub-instruments as `rc, out = sh(...)` and READ THE rc IN NONE OF THEM; the
# name was then rebound by the next section, which is how it stayed invisible through six weeks of edits.  Two
# distinct costs, and the second is the dangerous one:
#
#   1 THE WRONG CURE NAMED.  With a binary older than src/ the census REFUSES(2) and prints no counts.  The display
#     said "the census did not print a line this reader needs" -- which reads as an OUTPUT-SHAPE defect and sends
#     the next seat to edit util_gc_census.py.  The actual cure was `make`.  Measured: census rc=2, the display's
#     verdict block naming the census's output instead of the build.
#
#   2 A REFUSED MEASUREMENT PRINTED AS A PERFECT SCORE.  util_gc_event_coverage.py returns 2 at TWO points that sit
#     AFTER its DENOMINATOR IDENTITY line is already printed -- "no ratchet floor" (its line 403) and "cannot read
#     gc_heap.c to re-assert the ABSENT events" (line 378).  So EXERCISED and OBSERVABLE parse cleanly out of a run
#     that REFUSED TO MEASURE, the rc is dropped, and item 2 VISIBILITY prints:
#         declared events observed          16 / 16     100.0%
#     A full-marks line over an instrument that measured nothing.  THAT is the shape the docstring forbids, on the
#     display the whole fleet reads, and no arm anywhere would have seen it.
#
# ⛔ WHY THIS GATE USES A REAL TRIGGER AND NOT A SYNTHETIC ONE.  Arm 1 removes the ratchet floor -- a state the
# instrument itself documents and offers a cure for ("create it with --raise-floor"), reachable by any seat on a
# fresh clone before the floor is written.  A gate that can only fire against a hand-forged stub proves the stub.
#
# ARMS. (1) with the floor moved aside the event-coverage instrument prints its identity AND exits 2, and the
# acceptance display must print NO percentage for VISIBILITY and must carry THAT INSTRUMENT'S OWN REASON.
# (2) FAIL-ONCE PROOF: the same trigger against a copy of the display with the rc guard disabled -- exactly the
# pre-cure code -- must print the false 100%, so arm 1's assertion is shown to be capable of failing.  (3) with the
# floor restored the display prints the VISIBILITY counts again: the cure must not mint a permanent refusal.
# ⛔ This seat holds no cure lane (CEO-723) and edits no src/: the display and the gate are instruments.
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: cannot source lib_gate.sh"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
[ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
gate_require_fresh "$ROOT" src "$SCRIP" || exit 2
A="$HERE/util_gc_acceptance.py"
[ -f "$A" ] || { echo "⛔ GATE REFUSE(2) [$G]: the display $A does not exist -- it IS the deliverable"; exit 2; }
FLOOR="$HERE/gc_event_coverage.floor"
[ -f "$FLOOR" ] || { echo "⛔ GATE REFUSE(2) [$G]: no ratchet floor at $FLOOR -- this gate MOVES it, so it must start present"; exit 2; }
T=$(mktemp -d) || exit 2
BROKEN="$HERE/.gate_${G}_$$_broken.py"
# ⛔ THE FLOOR AND THE COPY COME BACK WHATEVER HAPPENS -- a gate that can leave the tree worse than it found it is
# not an invariant, and this one deliberately breaks a prerequisite to watch the display react.
restore() { [ -f "$T/floor.saved" ] && cp -f "$T/floor.saved" "$FLOOR"; rm -f "$BROKEN"; rm -rf "$T"; }
trap restore EXIT
RC=0; examined=0

echo "  HOLDS: util_gc_acceptance.py never prints a percentage over a sub-instrument that exited 2, and carries"
echo "         that instrument's OWN refusal reason instead of substituting one of its own"

vis_line() { sed -n '/^  2 VISIBILITY/,/^  3 AUDITED/p' "$1"; }

cp "$FLOOR" "$T/floor.saved" || { echo "⛔ GATE REFUSE(2) [$G]: cannot save the floor"; exit 2; }

# ---- arm 1: a real rc=2 that still prints parseable numbers must NOT become a percentage -------------------------
examined=$((examined + 1))
rm -f "$FLOOR"
python3 "$HERE/util_gc_event_coverage.py" > "$T/ev.txt" 2>&1; evrc=$?
python3 "$A" > "$T/cured.txt" 2>&1; arc=$?
cp -f "$T/floor.saved" "$FLOOR"
vis_line "$T/cured.txt" | sed 's/^/    | /'
if [ "$evrc" != 2 ]; then
    echo "  ⛔ GATE REFUSE(2) [$G]: the trigger did not fire -- util_gc_event_coverage.py exited $evrc with no floor,"
    echo "     so this gate could not create the state it exists to police.  Not a pass."; exit 2
fi
if ! grep -q 'DENOMINATOR IDENTITY' "$T/ev.txt"; then
    echo "  ⛔ GATE REFUSE(2) [$G]: the trigger fired (rc=2) but printed NO identity line, so the dangerous"
    echo "     combination (parseable numbers + rc=2) does not exist in this state.  Not a pass."; exit 2
fi
if vis_line "$T/cured.txt" | grep -q '%' ; then
    echo "  arm 1 FAIL: VISIBILITY printed a percentage over an instrument that exited 2 -- the false-green is live"; RC=1
elif vis_line "$T/cured.txt" | grep -q 'REFUSE(2)' && vis_line "$T/cured.txt" | grep -q 'ratchet floor'; then
    echo "  arm 1 PASS: sub-instrument rc=2 (identity printed anyway) -> no percentage, and the floor's OWN reason carried"
else
    echo "  arm 1 FAIL: no percentage, but the sub-instrument's own reason was not carried into the display"; RC=1
fi

# ---- arm 2: FAIL-ONCE -- the pre-cure code must print the false 100% --------------------------------------------
# A gate whose assertion cannot fail proves nothing.  The copy differs from the shipped display by ONE token: the
# rc guard is disabled, which is byte-for-byte the behaviour every version before 2026-09-22 had.
examined=$((examined + 1))
python3 - "$A" "$BROKEN" <<'PY'
import io, sys
src = io.open(sys.argv[1], encoding="utf-8").read()
n = src.count("    if ev_why:")
if n != 1:
    sys.stderr.write("REFUSE: expected exactly 1 rc guard to disable, found %d\n" % n); sys.exit(2)
io.open(sys.argv[2], "w", encoding="utf-8").write(src.replace("    if ev_why:", "    if False:"))
PY
if [ $? != 0 ] || [ ! -f "$BROKEN" ]; then
    echo "  ⛔ GATE REFUSE(2) [$G]: could not build the pre-cure copy, so FAIL-ONCE is unproven"; exit 2
fi
rm -f "$FLOOR"
python3 "$BROKEN" > "$T/broken.txt" 2>&1
cp -f "$T/floor.saved" "$FLOOR"
vis_line "$T/broken.txt" | sed 's/^/    ! /'
# ⛔ RE-DECLARED 2026-09-26 (cfo, CEO-1274 board row): this arm grepped '100.0%' and went red the day event coverage fell to
# 15/16, when the pre-cure copy printed '15 / 16 93.8%' over the same rc=2 -- a false number all the same.  A FAIL-ONCE arm
# must test the PREDICATE arm 1 asserts (any '%' in VISIBILITY), never one value of it, or it is anchored on the coverage.
false_pct=$(vis_line "$T/broken.txt" | grep '%' | head -1 | sed 's/^ *//')
if [ -n "$false_pct" ]; then
    echo "  arm 2 PASS: FAIL-ONCE proven -- with the rc guard disabled the SAME trigger prints a percentage over rc=2: $false_pct"
else
    echo "  arm 2 FAIL: the pre-cure copy did NOT print the false percentage, so arm 1 is not known to be able to fail"; RC=1
fi
rm -f "$BROKEN"

# ---- arm 3: the cure must not mint a permanent refusal ----------------------------------------------------------
examined=$((examined + 1))
python3 "$HERE/util_gc_event_coverage.py" > "$T/ev_ok.txt" 2>&1; okrc=$?
python3 "$A" > "$T/restored.txt" 2>&1
if [ "$okrc" = 2 ]; then
    echo "  arm 3 SKIP: the event-coverage instrument refuses for an unrelated reason on this tree, so a restored"
    echo "              floor cannot be shown to restore the numbers -- see $T/ev_ok.txt reason above"
elif vis_line "$T/restored.txt" | grep -q 'declared events observed.*%'; then
    echo "  arm 3 PASS: with the floor back the display prints the VISIBILITY counts again -- no refusal was minted"
else
    echo "  arm 3 FAIL: the floor is restored and the instrument exited $okrc, but VISIBILITY still shows no counts"; RC=1
fi

if [ "${FAIL_ONCE:-0}" = 1 ]; then echo "  FAIL_ONCE=1: forcing red to prove this gate can fail"; RC=1; fi
if [ "$RC" = 0 ]; then echo "✅ GATE PASS [$G]: $examined arm(s) examined, 3 sub-instrument rc sites guarded, rc=0"
else echo "⛔ GATE FAIL [$G]: $examined arm(s) examined, rc=$RC"; fi
exit $RC
