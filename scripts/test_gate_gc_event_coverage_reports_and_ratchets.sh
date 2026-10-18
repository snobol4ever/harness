#!/usr/bin/env bash
# test_gate_gc_event_coverage_reports_and_ratchets.sh -- row gc-event-coverage-is-the-criterion-not-collection-count
# (coo, 2026-09-21, MODE TENET, CEO-1029; RULES.md THE INSTRUMENT LAWS; CEO-997 batch 30 clause 2 -- a census NAMES
# and never only counts).
#
# WHY THE AXIS CHANGED. A stress setting only tests the gc-points where a collection ACTUALLY OCCURS, and that subset
# need not differ between executions, so COLLECTION COUNT is the wrong axis. bench_icnstr_concat_table.icn at
# SCRIP_HEAP_MB=1 gives 38781 collections at stress 1, 32015 at stress 5 and 10006 at stress 16 -- and hq_raku found
# 36 silently-wrong Raku programs at stress 16 that stress 1, 3 and 5 all called GREEN. FEWER COLLECTIONS FOUND MORE
# DEFECTS. GCFuzz names the right axis: EVENT COVERAGE. This gate makes that axis measurable and keeps it from falling.
#
# ⛔ THE DENOMINATOR IS THE WHOLE POINT, SO IT IS PRINTED THREE WAYS. This row exists because a green instrument was
# measuring the wrong axis; ratcheting a SUBSET and letting it read as "the event space" would be that same offence
# one level up. util_gc_event_coverage.py therefore prints OBSERVABLE (16, with telemetry the collector already emits),
# OWED (1, real events the collector cannot distinguish -- NAMED, never dropped) and ABSENT (1, named in the row's
# goal and nonexistent here). ⛔ THESE COUNTS ARE PROSE AND PROSE GOES STALE: the instrument's own OWED entry for
# slide_without_displacement outlived its truth by a day (the w_unm counter that cures it landed 2026-09-21 in
# 6489508ec while the entry still said the collector could not distinguish it), which is why that entry is now a
# LIVE PROBE in OBSERVABLE rather than a hardcoded string. Read the floor file and the report, never this comment.
# goal and nonexistent here). arena_shrink is ABSENT and not merely uncovered: g_hp_end is only ever advanced
# (gc_heap.c:160) or initialised (:179), and the one munmap (:502) is gcbk_drop over the collector's OWN bookkeeping,
# never the object arena. Carrying it as a bucket would read as permanent 0% coverage of a thing that cannot happen,
# so its absence is ASSERTED instead: the day a shrink path lands, arm 2 REDS and demands it be reclassified.
#
# ⛔⭐ THE MEASUREMENT THAT SHAPED THE PROBE SET, because it bounds what any coverage number here can mean. ONE binary,
# ONE tree, ONE witness, the ONLY difference the SPELLING OF THE PATH handed to ./scrip:
#     ../harness/scripts/gc_witnesses/hb_nv.sno   -> interior=1        ./scripts/gc_witnesses/hb_nv.sno -> interior=0
# Three runs each, no variation within a spelling. The source path is itself a heap block, so its length shifts every
# block after it and decides whether any reference lands INTERIOR to one. A COVERAGE READING IS A PROPERTY OF
# (program, stress, INVOCATION). Every probe in the set was therefore re-run under all three spellings and kept only
# if it reached its event at the SAME count every time -- a ratchet resting on a marginal event would red or green on
# whether a caller wrote `../harness/scripts/x` or `./scripts/x`. ⭐ And the same measurement is a finding for the fleet: two
# seats running the same witness at the same stress from roots of different name length ARE EXERCISING DIFFERENT GC
# EVENTS, and no board line says so.
#
# ⛔ A "NOT EXERCISED" VERDICT CARRIES ITS BOUND (hq_P's law: A NULL RESULT BOUNDS THE PROBE, NOT THE THING PROBED).
# The two uncovered events are not probe artifacts: the ENTIRE 96-witness gc_witnesses pool was swept at
# SCRIP_HEAP_MB=1 stress 1 and NOT ONE witness grows the arena or inserts a fill block. Both holes are printed with
# that sweep beside them, and an uncovered event with NO sweep evidence prints UNBOUNDED rather than reading as a hole.
#
# ARMS. (1) the instrument runs, reports the whole space, and the RATCHET HOLDS -- no floor event has stopped being
# exercised. (2) the ABSENT assertion still holds (no arena-shrink path appeared). (3) the report is DENOMINATOR-HONEST:
# it names OWED and ABSENT explicitly and prints the identity. (4) FAIL-ONCE PROOF: a floor carrying an event nothing
# exercises must RED -- a ratchet that cannot fail is not a ratchet. ⛔ This seat holds no cure lane (CEO-723): every
# observable event is read from telemetry already in the tree and every OWED event is an ask, not an edit.
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: cannot source lib_gate.sh"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
[ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
gate_require_fresh "$ROOT" src "$SCRIP" || exit 2
U="$HERE/util_gc_event_coverage.py"
[ -f "$U" ] || { echo "⛔ GATE REFUSE(2) [$G]: the instrument $U does not exist -- it IS half the deliverable"; exit 2; }
FLOOR="$HERE/gc_event_coverage.floor"
[ -f "$FLOOR" ] || { echo "⛔ GATE REFUSE(2) [$G]: no ratchet floor at $FLOOR -- create it with --raise-floor"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; examined=0

echo "  HOLDS: the GC event space is enumerated whole (OBSERVABLE + OWED + ABSENT), the corpus's coverage of it is"
echo "         reported by name, and coverage cannot fall below the recorded floor"

# ---- arm 1: the instrument runs and the ratchet holds -----------------------------------------------------------
examined=$((examined + 1))
python3 "$U" --floor "$FLOOR" > "$T/rep.txt" 2>&1; irc=$?
sed 's/^/    | /' "$T/rep.txt"
nfloor=$(grep -cve '^#' -e '^$' "$FLOOR")
if [ "$irc" = 0 ]; then
    echo "  arm 1 PASS: instrument rc=0, ratchet holds over $nfloor floor event(s)"
elif [ "$irc" = 2 ]; then
    echo "  ⛔ GATE REFUSE(2) [$G]: the instrument could not measure (rc=2) -- see its reason above"; exit 2
else
    echo "  arm 1 FAIL: instrument rc=$irc over $nfloor floor event(s)"; RC=1
fi

# ---- arm 2: the ABSENT assertion still holds --------------------------------------------------------------------
examined=$((examined + 1))
if grep -q 'ABSENT -- named in the row' "$T/rep.txt" && ! grep -q "was recorded ABSENT, but" "$T/rep.txt"; then
    echo "  arm 2 PASS: every ABSENT event is still absent (arena_shrink: no g_hp_end decrement in gc_heap.c)"
else
    echo "  arm 2 FAIL: an ABSENT event's assertion broke, or the ABSENT section is missing from the report"; RC=1
fi

# ---- arm 3: the report is denominator-honest --------------------------------------------------------------------
examined=$((examined + 1))
miss=""
grep -q 'OWED -- real events'        "$T/rep.txt" || miss="$miss OWED-section"
grep -q 'ABSENT -- named in the row' "$T/rep.txt" || miss="$miss ABSENT-section"
grep -q 'DENOMINATOR IDENTITY'       "$T/rep.txt" || miss="$miss identity-line"
grep -q 'slide_without_displacement' "$T/rep.txt" || miss="$miss slide_without_displacement-by-name"
if [ -z "$miss" ]; then
    nobs=$(grep -c '^    [✅❌] ' "$T/rep.txt")
    echo "  arm 3 PASS: the report names OWED and ABSENT and prints the identity over $nobs observable event(s)"
else
    echo "  arm 3 FAIL: the report is not denominator-honest, missing:$miss"; RC=1
fi

# ---- arm 4: FAIL-ONCE -- a ratchet that cannot fail is not a ratchet --------------------------------------------
examined=$((examined + 1))
cp "$FLOOR" "$T/floor.bogus"
echo "an_event_nothing_can_possibly_exercise" >> "$T/floor.bogus"
python3 "$U" --floor "$T/floor.bogus" --quiet > "$T/bogus.txt" 2>&1; brc=$?
if [ "$brc" = 1 ] && grep -q 'COVERAGE FELL' "$T/bogus.txt" \
   && grep -q 'an_event_nothing_can_possibly_exercise' "$T/bogus.txt"; then
    echo "  arm 4 PASS: a floor event nothing exercises REDS the instrument (rc=1) and is NAMED in the refusal"
else
    echo "  arm 4 FAIL: the ratchet did not fail on an unexerciseable floor event (rc=$brc) -- it cannot ratchet"; RC=1
fi

if [ "${FAIL_ONCE:-0}" = 1 ]; then echo "  FAIL_ONCE=1: forcing red to prove this gate can fail"; RC=1; fi
if [ "$RC" = 0 ]; then echo "✅ GATE PASS [$G]: $examined arm(s) examined, floor=$nfloor event(s), rc=0"
else echo "⛔ GATE FAIL [$G]: $examined arm(s) examined, floor=$nfloor event(s), rc=$RC"; fi
exit $RC
