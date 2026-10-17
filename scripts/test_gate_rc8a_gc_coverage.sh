#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_rc8a_gc_coverage.sh — RC-8a / GOAL-SN4-HOME-RBX X-1.
# ASSERTS, at a real collection: the CAS capture-pending island is walked when it is occupied. SELF-ARMING per the RBX
# GATES line: the arm PASSES only on a collection that found the island occupied and walked it.
#
# ⛔ THE WITNESS IS INLINE, AND WHY (the coo 2026-10-01, row instruments-test-gate-rc8a-gc-coverage-refuses-rc-2-...): corpus
# c06960a12 (2026-08-29) deleted corpus/probe/, so probe/mv_arbno_callcap.sno was gone and this gate refused rc 2 for a month, in
# no blocking arm, so nobody read it. That program survives as SNOBOL4 master entry 1517 (origin probe_probe_top__mv_arbno_callcap)
# and MEASURED, extracted through corpus_suite_harness.py and run at its declared --stlimit -d131072k -s4096k: 4 collections at
# SCRIP_GC_STRESS 1 and 2, max cas_scanned_bytes 0 at stress 1 2 3 8 64 -- its *p() allocates nothing, so no collection fires
# while the capture is pending and it can never arm the island again. The witness below is its shape with a deferred function
# that ALLOCATES (64 bytes a step, 200 steps) inside ARBNO(LEN(1) . *f()): at stress 1 it reads 802 collections and max
# cas_scanned_bytes=48, and prints S, as sbl -bf does. It is a gate fixture, never a suite program, so it is written here and
# graded by its output as well as by the collector line; it runs at the shipped arena and declares nothing.
#
# ⛔ TWO ASSERTIONS RETIRED, EACH BY THE COLLECTOR LANDING THAT REMOVED WHAT IT TESTED (the coo 2026-10-01, measured):
#   (1) "the RTCC block is RANGE-registered at every collection" -- be6b03b5e (2026-09-22) removed the registration on
#       purpose ("the caller-saved spill block is no longer registered as a GC root range -- the registration had no
#       consumer and told every reader a lie"); the block's invariant is now that it never holds a heap reference, graded
#       by test_gate_gc_the_caller_saved_spill_block_never_holds_a_heap_reference.sh. [GC-COV] reads ranges=0 by design.
#   (3) "pz=0 whenever a root region is registered" -- c6bf8e789 (2026-09-19, THE E SWITCH) deleted punt-zero with the
#       word sweep and the descriptor sniff, and [GC-COV] has printed no pz field since; the old arm read the absent field
#       as pz=1 and would have called it a FAIL.
#   (2) "the CAS capture-pending island is walked when occupied" -- the coo's match-records landing (CEO-1543/1545/1547, 2026-10-07)
#       deleted g_capo, g_dcf and g_dfx and the side region they were carved from: each record is now a spine region its own box
#       carves and pops, typed DESCR cells the stack walk visits, so rt_cas_gc_roots roots none of them and [GC-COV]'s
#       cas_scanned_bytes reads 0 by construction (802 collections, max 0, on the landing tree; 48 on a954b0d8e before it).
# ⛔ THE ARM THAT REPLACES IT (4): the *-target capture's record is LIVE on the spine across every collection its deferred
#   call fires -- f() allocates inside the capture, after the box carved the record and before it lands -- and its matched
#   cell is read back after the collector moved the subject. The witness builds its subject on the heap and prints the last
#   captured value (sbl -bf prints "S q"); it runs at SCRIP_GC_STRESS=1 and again with SCRIP_GC_RELOC=1. Armed when the
#   relocating run read at least one collection; a wrong value is a FAIL, no collection is a REFUSE.
# ⛔ AN UNARMED ARM MEASURED NOTHING, SO IT REFUSES (rc 2), NEVER GREEN: with (1), (2) and (3) retired arm (4) is the gate.
#
# The positive control is a SOURCE CENSUS of SCRIP's own src/ for the un-rooting escape SCRIP_GC_UNROOT. It used to grep
# "$ROOT/src" with ROOT the CORPUS, which has no src/, so the census read "unreachable" whatever the runtime held.
# Usage: bash ../harness/scripts/test_gate_rc8a_gc_coverage.sh
# Exit: 0 the armed arm read the spine record back · 1 a FAIL (wrong output, or the escape is back) · 2 could not measure (no binary,
# no collection, unarmed).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
SRC="$HERE/../../SCRIP/src"
[ -x "$SCRIP" ] || { echo "GATE RC-8a: REFUSE(2) — no scrip binary at $SCRIP (cannot measure)"; exit 2; }
[ -d "$SRC" ] || { echo "GATE RC-8a: REFUSE(2) — no source tree at $SRC for the control census (cannot measure)"; exit 2; }
T=$(mktemp -d) || { echo "GATE RC-8a: REFUSE(2) — mktemp"; exit 2; }
trap 'rm -rf "$T"' EXIT TERM INT
WIT="$T/rc8a_cas_witness.sno"
cat > "$WIT" <<'SNO'
        DEFINE("f()")                       :(f_end)
f       i = 0
floop   i = i + 1
        s = s DUPL('y', 64)
        LT(i, 200)                          :S(floop)
        f = .dummy                          :(NRETURN)
f_end
        pat = ARBNO(LEN(1) . *f()) 'z'
        'xxz' ? pat                         :F(FF)
        OUTPUT = 'S'                        :(END)
FF      OUTPUT = 'F'
END
SNO
WANT=S   # sbl -bf prints S (the coo 2026-10-01)
# every [GC-COV] line of the run, one per collection
cov() { ( cd "$T" && SCRIP_GC_COVERAGE=1 SCRIP_GC_STRESS="${1:-1}" timeout -k 5 60s "$SCRIP" --run "$WIT" < /dev/null 2> "$T/err" > "$T/out"; echo "rc=$?" > "$T/rc" ); grep "GC-COV" "$T/err"; }
L=$(cov 1)
GOT=$(cat "$T/out" 2>/dev/null)
[ "$(cat "$T/rc")" = rc=124 ] && { echo "GATE RC-8a: REFUSE(2) — the witness ran past 60 s (a timeout firing is not a verdict), so nothing was measured"; exit 2; }
[ "$(cat "$T/rc")" = rc=0 ] && [ "$GOT" = "$WANT" ] || { echo "GATE RC-8a: FAIL — the witness printed [$GOT] with $(cat "$T/rc"); want [$WANT] rc=0 (sbl -bf): the collection mid-match broke the program"; echo "GATE RC-8a: RED"; exit 1; }
if [ -z "$L" ]; then echo "GATE RC-8a: REFUSE(2) — instrument DARK (no [GC-COV] line; no collection fired), so nothing was measured"; exit 2; fi
N=$(grep -c . <<<"$L")
echo "  witness: inline (the gate's own fixture), printed [$GOT] as sbl -bf does; $N collection(s) read at SCRIP_GC_STRESS=1"
echo "  [RETIRED] (1) RTCC range registration -- removed by be6b03b5e; the spill block's invariant is test_gate_gc_the_caller_saved_spill_block_never_holds_a_heap_reference.sh"
echo "  [RETIRED] (3) pz=0 -- punt-zero deleted by c6bf8e789; [GC-COV] prints no pz field"
echo "  [RETIRED] (2) the CAS island walk -- g_capo, g_dcf and g_dfx left the runtime with their side region (CEO-1543/1545/1547); cas_scanned_bytes reads 0 by construction"
# ---- ASSERTION 4: the *-target capture's spine record survives the collections its deferred call fires (SELF-ARMING) ----
W2="$T/rc8a_spine_witness.sno"
cat > "$W2" <<'SNO'
        DEFINE("f()")                       :(f_end)
f       i = 0
floop   i = i + 1
        s = s DUPL('y', 64)
        LT(i, 200)                          :S(floop)
        f = .dummy                          :(NRETURN)
f_end
        subj = DUPL('x', 2) 'q' 'z'
        pat = ARBNO(LEN(1) . *f()) 'z'
        subj ? pat                          :F(FF)
        OUTPUT = 'S ' dummy                 :(END)
FF      OUTPUT = 'F'
END
SNO
WANT2='S q'   # sbl -bf prints "S q" (the coo 2026-10-07)
for E in ""; do
    ( cd "$T" && env SCRIP_GC_COVERAGE=1 SCRIP_GC_STRESS=1 $E timeout -k 5 60s "$SCRIP" --run "$W2" < /dev/null 2> "$T/err2" > "$T/out2"; echo "rc=$?" > "$T/rc2" )
    G2=$(cat "$T/out2" 2>/dev/null); N2=$(grep -c "GC-COV" "$T/err2"); K="${E:-plain}"
    [ "$(cat "$T/rc2")" = rc=124 ] && { echo "GATE RC-8a: REFUSE(2) — the spine witness ran past 60 s ($K), so nothing was measured"; exit 2; }
    [ "$(cat "$T/rc2")" = rc=0 ] && [ "$G2" = "$WANT2" ] || { echo "  [FAIL] (4, $K) the spine witness printed [$G2] with $(cat "$T/rc2"); want [$WANT2] rc=0 (sbl -bf): a collection inside the deferred call broke the capture record"; echo "GATE RC-8a: RED"; exit 1; }
    [ "$N2" -gt 0 ] || { echo "GATE RC-8a: REFUSE(2) — arm (4) UNARMED ($K): no collection fired inside the deferred call, so the live record was never measured"; exit 2; }
    echo "  [PASS] (4, $K) the *-target capture record read back [$G2] across $N2 collection(s) fired inside its deferred call"
done
if grep -rq 'SCRIP_GC_UNROOT' "$SRC" 2>/dev/null; then echo "  [FAIL] control: SCRIP_GC_UNROOT is back in $SRC — the un-rooting escape needs its runtime sabotage control restored"; echo "GATE RC-8a: RED"; exit 1; fi
echo "  [PASS] control (SOURCE CENSUS of $SRC): the un-rooting escape is UNREACHABLE — zero SCRIP_GC_UNROOT"
echo "GATE RC-8a: GREEN"; exit 0
