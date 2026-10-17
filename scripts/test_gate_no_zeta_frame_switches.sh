#!/usr/bin/env bash
# test_gate_no_zeta_frame_switches.sh — THE PRISON for RULES.md FACT RULE "THE ζ TIER IS DERIVED, NEVER ENUMERATED"
# (Lon 2026-09-09 09:2x CDT: "Get rid of enumerated shape class now!!!"; ceo CEO-447; landed by the cto).
#
# A box's tier (ζ-SPINE on RSP vs ζ-ACTIVATION-FRAME on RBP) is DERIVED per graph from the two frame-placement
# conditions in ONE selector. Every env switch that once chose a frame placement by hand -- the 2026-09-09 census
# under src/ was 29 names matching RBP|FRAME|PIN|ZFRAME|CARVE -- is a ζ mode, and ZETA HAS NO MODES. This gate is a
# pure SOURCE CENSUS, no build: it reads ZERO getenv("SCRIP_*") names matching that class under src/, and names every
# survivor. It is wired blocking in the same commit as the deletion (MASTER-PLAN: an instrument in no runner is not
# measuring). ~0.05s.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
[ -d "$ROOT/src" ] || { echo "⛔ REFUSE(2): no src/ under $ROOT -- a census over nothing"; exit 2; }
# ⛔ RULING 2026-09-16 (cfo as the collector's officer, cto concurring in writing; row engine-the-zeta-switch-census-counts-the-
# collectors-own-pin-control-arm-as-a-frame-placement-switch-...): THE SCRIP_GC_ NAMESPACE IS HEAP POLICY, NOT FRAME PLACEMENT, AND IS
# OUT OF THIS CENSUS. getenv("SCRIP_GC_PIN_AGGREGATES") (gc_heap.c, 24f1ec353, GC-5 rung 1) matched the PIN word here and kept this
# blocking arm red on the clean tree for three days; it is the live CONTROL ARM of test_gate_gc_aggregates_are_collectable_not_immortal.sh
# and gc_aggregate_interiors_are_marked_not_only_slotted (the pinned build must still die), and it attributed the gc2 regression in one
# run (SCRIP 5dafed741). Deleting it would blind two blocking gates to cure a census. PIN in this class meant PINNED FRAMES. The exclusion
# is exactly the SCRIP_GC_ prefix and nothing wider: the row's DONE-WHEN plants a getenv("SCRIP_PIN_FRAMES") in a scratch tree and proves
# this gate still reds on it.
# ⛔⭐ RULING 2026-09-19 (ceo CEO-948, the same shape as the SCRIP_GC_ ruling above and for the same measured reason):
# A PLANT SEAM THAT A BLOCKING GATE USES IS DECLARED HERE WITH ITS GATE, AND THE DECLARATION CHECKS ITSELF.
# The census went red on the clean tree again -- this time on getenv("SCRIP_BLOB_CARVE_PAD") (emit.cpp:2529, added by
# the GC landing 01aa9008c "the R-4(b) blob carve is a DEPTH CONTRACT, named and held by a gate that plants the
# perturbation"), and it was red on origin for every seat with no record anywhere. The tension is real and it is between
# two laws: CEO-554 says an instrument must be able to PLANT its trip through a cached-getenv seam, because a gate
# anchored on a found witness dies the day someone cures the witness; RULES.md's ζ TIER IS DERIVED says no env switch
# chooses a frame placement. A seam that PADS THE CARVE is not inert -- it changes emitted frame geometry -- so the
# census is right to see it, and deleting it would blind test_gate_gc_blob_carve_invariant_is_named_and_held.sh, which
# is exactly what the SCRIP_GC_ ruling refused to do three days earlier.
# THE RECONCILIATION KEEPS THE CENSUS'S FORCE: an exempt name is listed below WITH the gate that plants with it, and
# this gate REFUSES rc=2 unless that gate exists AND actually references the name. So the list cannot become a dumping
# ground, a seam whose gate is deleted stops being exempt the same day, and an UNDECLARED switch still reds. Same
# declared-set shape as the arena pin list in test_gate_gc_the_tiny_arena_is_the_default_of_gc_testing.sh and the
# ROOTED-HEAP family read in the two rooting gates.
SEAMS="SCRIP_BLOB_CARVE_PAD:test_gate_gc_blob_carve_invariant_is_named_and_held.sh"
SEAM_RX=""
for _sp in $SEAMS; do
    _nm=${_sp%%:*}; _gt=${_sp##*:}
    [ -f "$HERE/$_gt" ] || { echo "⛔ REFUSE(2): declared plant seam $_nm names gate $_gt, which does not exist. A seam is exempt only while the gate that plants with it does -- delete the declaration or restore the gate."; exit 2; }
    grep -q "$_nm" "$HERE/$_gt" || { echo "⛔ REFUSE(2): declared plant seam $_nm names gate $_gt, which does not reference it. An exemption whose gate never uses the seam is a dumping ground, and this census does not keep one."; exit 2; }
    SEAM_RX="${SEAM_RX:+$SEAM_RX|}getenv\(\"$_nm\"\)"
done
hits=$(grep -rnoE 'getenv\("SCRIP_[A-Z0-9_]*(RBP|FRAME|PIN|ZFRAME|CARVE)[A-Z0-9_]*"\)' "$ROOT/src" 2>/dev/null | grep -vE 'getenv\("SCRIP_GC_' | { [ -n "$SEAM_RX" ] && grep -vE "$SEAM_RX" || cat; } || true)
n=$(printf '%s' "$hits" | grep -c . || true)
if [ "$n" -ne 0 ]; then
  echo "⛔ FAIL: $n zeta frame switch(es) under src/ -- the tier is DERIVED, never enumerated (RULES.md, CEO-447):"
  printf '%s\n' "$hits" | sed "s#^$ROOT/##"
  exit 1
fi
# CEO-448 (Lon: "get rid of all that ZLS and ZETA #define's"): no ZC_/ZLS identifier, no rt_zls store symbol, no
# zeta_choices/zeta_alloc file may exist under src/ -- the frame layout is typed per activation, never a store.
zhits=$(grep -rnoE '\b(ZC_[A-Z0-9_]+|ZLS[A-Z0-9_]*|rt_zls2?_[a-z_]+)\b' "$ROOT/src" 2>/dev/null; ls "$ROOT/src/ir/zeta_choices.h" "$ROOT/src/runtime/rt/zeta_alloc.c" "$ROOT/src/runtime/rt/zeta_alloc.h" 2>/dev/null)
zn=$(printf '%s' "$zhits" | grep -c . || true)
if [ "$zn" -ne 0 ]; then
  echo "⛔ FAIL: $zn ZC_/ZLS identifier(s) or zeta store file(s) under src/ -- the ζ stores and defines died in CEO-448:"
  printf '%s\n' "$zhits" | sed "s#^$ROOT/##"
  exit 1
fi
echo "✅ PASS: 0 undeclared zeta frame switches (getenv SCRIP_*{RBP,FRAME,PIN,ZFRAME,CARVE}*, less the SCRIP_GC_ heap-policy namespace and the declared plant seams [$SEAMS], each verified against the gate that plants with it) and 0 ZC_/ZLS identifiers or zeta store files under src/ -- the tier is derived, the layout is typed"
exit 0
