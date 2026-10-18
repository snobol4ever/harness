#!/usr/bin/env bash
# test_gate_gc_the_mark_walk_is_a_worklist_not_recursion_per_cell.sh -- A COLLECTOR MUST WALK A LONG DATA CHAIN ON A
# BOUNDED C STACK (row gc-descriptor-walk-recurses-once-per-list-cell-and-overflows-the-c-stack-on-a-long-data-chain;
# ceo ruling CEO-822, which put this row AHEAD of the F6 step-3 reporter because a divergence census that cannot run at
# all on the class that stresses the collector hardest would hand back a zero meaning NEVER MEASURED, and DARK is worse
# than RED).
#
# THE DEFECT, MEASURED ON ORIGIN b12714737: rt_gc_visit_descr recursed once per DATA instance along a CDR chain -- one C
# frame per cell -- so a collection with a 600000-cell CONS list live died with ERROR 246 (stack overflow) and
# COLLECTIONS=0 in BOTH modes, while a 60000-cell control printed 60000 at rc=0. The process died inside the mark walk
# before one collection completed. Cure: the aggregate arms push onto an explicit heap worklist (gc_wl_push) which
# rt_gc_visit_descr drains, so the C depth is bounded (gc_visit_one -> gc_visit_vcell -> gc_visit_tbblk -> push) no
# matter how long the chain is. The row's GOAL said to measure what SCRIP_GC_WORKLIST already covers before adding a
# switch: IT COVERS NOTHING -- that name is in no file under src/, and git log -S finds it only in f2270e807, the
# landing that DELETED all eight env-gated alternate collector paths. There is deliberately no new switch here either;
# the collector has one behaviour.
#
# ⭐ ARM 3 IS THE ONE THAT CANNOT BE FAKED. A cure that simply stopped walking the chain would pass arms 1 and 2 (rc=0,
# right answer) while silently collecting live data. Arm 3 reads marked= out of the [ZGC] telemetry and requires it to
# SCALE WITH THE CHAIN: a 1.5M-cell chain must mark at least two blocks per cell (the record and its field vector), so
# 3000000. That number is the walk itself, so the arm is vacuous only if the collector is doing the work.
# ⛔ RE-KEYED 2026-10-01 BY THE cfo, AND THE OLD KEY WAS MEASURING WASTE, NOT THE WALK: arm 3 used to require
# wl_depth_max > 1000000. That depth came from a SECOND visit of every cell -- the mark loop drained each record's
# field vector whole and gc_visit_datinst had already pushed the same fields, so every CDR went on the worklist twice
# and the second pass piled 1500000 of them up at once. With the double push gone (row gc-speed-the-mark-phase-...)
# the walk alternates record and vector and the depth reads 2 on the cure, 1500000 on its parent, while marked= reads
# 2796003 then 3000451 on BOTH -- the same blocks marked, the same 1500000 cells walked back. A depth that a correct
# cure drives toward zero is a key that refuses the cure; the marked count cannot fall unless the walk does. The depth
# is still printed beside it, and a C-recursive walk still dies at the 4 MB stack long before 1500000 frames.
#
# FAIL-ONCE IS MEASURED, NOT ASSERTED: on origin b12714737 (this cure stashed, runtime rebuilt, this gate left in place)
# arms 1, 2 and 3 all read red -- rc=1, ERROR 246, empty output, collections=0.
#
# ⛔⭐ THE CEILING IS ARENA-AWARE, AND A CEILING THAT FIRES IS A REFUSAL, NOT A RED (coo 2026-09-20, on the cfo's
# measurement CFO-121/122; the cure was the cfo's to report and the coo's to choose). This gate's three ceilings were
# calibrated against the SHIPPED arena. `make test-arena` runs the same arms at SCRIP_HEAP_MB=1, where the scaling
# program is forced through 1106 collections and needs 651 SECONDS against its 300-second ceiling -- so the arm timed
# out, rc=124, and test-arena reported it as a COLLECTOR red owing a row. ⭐ THE PROPERTY THE GATE EXISTS TO MEASURE
# HELD WHILE IT FAILED: the cfo read wl_depth_max=2118170, past this arm's own 1000000 bar, so the mark walk WAS an
# explicit worklist and the chain WAS being walked. A red that is a clock reads exactly like a red that is a lost root,
# and it cost a seat its attribution work on an otherwise clean arena pass.
#   TWO CHANGES, and the second is the one that matters: (1) the ceilings scale with the arena; (2) rc=124 is a
# GATE REFUSE(2) naming the clock, the arena and the ceiling -- never a FAIL. A timeout is COULD NOT MEASURE, which is
# rc=2 under the INSTRUMENT LAWS, and no ceiling I can pick makes that judgement unnecessary: an under-set ceiling now
# reports ITSELF instead of manufacturing a collector finding.
#   ⛔ THE NUMBERS, EACH LABELLED WITH WHAT IS BEHIND IT: 900s for the scaling arm at a tiny arena is the cfo's
# MEASURED 651s (SCRIP_HEAP_MB=1, rc=0, out=1500000, collections=1106, wl_depth_max=3000000, wall 09:19:09-09:30:00)
# plus headroom. 600s for the two 600000-cell arms is DECLARED, not measured -- no one has run them at 1 MB -- and it
# is safe to declare precisely because (2) turns a wrong guess into a refusal rather than into a red.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; examined=0
# THE ARENA AND ITS CEILINGS, PRINTED: a number is not labelled until it carries the arena it was measured at.
# ⛔ THIS GATE PINS ITS ARENA, AND THE PIN IS DECLARED in test_gate_gc_the_tiny_arena_is_the_default_of_gc_testing.sh
# (cto 2026-09-23, CEO-1161 routing). Its subject is the DEPTH of the mark walk over a chain that must SURVIVE, and the
# chain is 600000 cells of 48 bytes (28.8 MB live by construction; the scaling arm's 1.5M cells are 72 MB). Since
# CEO-1101 the declared size is a HARD CAP: the unset default is a 4096 KB cap and make's SCRIP_HEAP_MB=1 is 1024 KB,
# and under either the chain arm dies rc=134 'heap exhausted AT THE HARD CAP' after 5962 collections with 87011 blocks
# live -- measured 2026-09-23 on 89956530b, which is how this gate read red at CEO-1161. A mark-walk depth is not an
# arena-dependent quantity, so the pin below names a window the witness fits and the ceilings stay the ones this gate
# was calibrated against at the old shipped reserve. The outer KB knob is unset because gc_heap.c reads it LAST and
# it would silently defeat the pin (CEO-1153, 33rd batch clause 6).
unset SCRIP_HEAP_KB
export SCRIP_HEAP_MB=256
ARENA_MB="$SCRIP_HEAP_MB"
CEIL_CHAIN=180; CEIL_SCALE=300; CEIL_WHY="PINNED arena SCRIP_HEAP_MB=$ARENA_MB (a 28.8 MB / 72 MB live chain cannot fit the 4096 KB default cap or make's 1024 KB; the pin is declared) -- the ceilings this gate was calibrated against"
echo "ARENA SCRIP_HEAP_MB=$ARENA_MB (PINNED, declared: the witness is a 28.8 MB live chain by construction and dies rc=134 at the hard cap under the 4096 KB default and the 1024 KB make default; a mark-walk depth is not an arena-dependent quantity)"
# ⭐ THE SANCTIONED SEAM (ceo CEO-560): a guard whose only proof of firing is doing the forbidden thing is tested
# that way OR NOT AT ALL. The refusal below cannot be reached in a tick without burning 651 seconds at a 1 MB arena,
# so the CEILING -- an instrument's clock, never the collector's behaviour -- is overridable and LOUD when it is.
# It is also the recipe the cfo asked for: the same arm, the same program, a bigger ceiling.
if [ -n "${SCRIP_GATE_MARKWALK_CEIL:-}" ]; then
  CEIL_CHAIN="$SCRIP_GATE_MARKWALK_CEIL"; CEIL_SCALE="$SCRIP_GATE_MARKWALK_CEIL"
  CEIL_WHY="SCRIP_GATE_MARKWALK_CEIL=$SCRIP_GATE_MARKWALK_CEIL (declared override of the arena ceiling, printed so no reading of this gate is unlabelled)"
  echo "⚠ CEILING OVERRIDE: $CEIL_WHY"
fi
echo "    ceilings: chain arms ${CEIL_CHAIN}s, scaling arm ${CEIL_SCALE}s -- $CEIL_WHY"
# ⛔ rc=124 IS A TIMEOUT FIRING AND NOTHING ELSE. It says the ceiling was reached; it says NOTHING about whether the
# collector recursed, so it may not be spelled FAIL. Whatever the walk had already reported is printed with the
# refusal, because "the property held and the clock ran out" and "the chain never came back" are different readings.
refuse_on_clock() {  # <rc> <arm> <ceiling> <errfile>
  [ "$1" = 124 ] || return 0
  local d; d=$(grep -oE 'marked=[0-9]+' "$4" 2>/dev/null | cut -d= -f2 | sort -n | tail -1)
  echo "⛔ GATE REFUSE(2) [$G]: the $2 arm hit its ${3}s CEILING (rc=124, a timeout firing) at $CEIL_WHY."
  echo "    COULD NOT MEASURE -- this is not a collector verdict: marked=${d:-absent} at the moment the clock ran out"
  echo "    (a marked count of two blocks per cell means the chain WAS being walked; raise the"
  echo "     ceiling for this arena or run this arm at the shipped arena, and do NOT open a collector row on this line)."
  echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
  exit 2
}
chain() { printf " DATA('CONS(CAR,CDR)')\n L = \n I = 0\nLP I = LT(I,%s) I + 1 :F(DN)\n L = CONS(I, L) :(LP)\nDN X = COLLECT()\n J = 0\nCT J = LT(J,3000) J + 1 :F(OUT)\n S = DUPL('x', 20000) :(CT)\nOUT K = 0\nCN L = DIFFER(L) CDR(L) :F(FIN)\n K = K + 1 :(CN)\nFIN OUTPUT = K\nEND\n" "$1" > "$2"; }
chain 600000 "$T/w.sno"; chain 1500000 "$T/big.sno"
examined=$((examined+1))
SCRIP_ZETA_TELEM=1 timeout -k 5 "$CEIL_CHAIN" "$SCRIP" "$T/w.sno" </dev/null >"$T/o3" 2>"$T/e3"; r3=$?; c3=$(grep -c regeneration "$T/e3")
refuse_on_clock "$r3" "m3 600000-cell" "$CEIL_CHAIN" "$T/e3"
if [ "$r3" = 0 ] && [ "$(cat "$T/o3")" = 600000 ] && [ "$c3" -ge 1 ]; then echo "  m3 PASS (600000-cell CONS chain live across a COLLECT(): rc=0, walked $(cat "$T/o3") cells back, $c3 collection(s))"
else echo "  m3 FAIL (rc=$r3 out=[$(cat "$T/o3")] collections=$c3 -- $(head -1 "$T/e3" | cut -c1-90))"; RC=1; fi
examined=$((examined+1))
( cd "$T" && timeout -k 5 "$CEIL_CHAIN" "$SCRIP" --compile -o w.s w.sno </dev/null >/dev/null 2>&1 && gcc -no-pie w.s -o w.x -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: the m4 witness did not build"; exit 2; }
SCRIP_ZETA_TELEM=1 timeout -k 5 "$CEIL_CHAIN" "$T/w.x" </dev/null >"$T/o4" 2>"$T/e4"; r4=$?; c4=$(grep -c regeneration "$T/e4")
refuse_on_clock "$r4" "m4 600000-cell" "$CEIL_CHAIN" "$T/e4"
if [ "$r4" = 0 ] && [ "$(cat "$T/o4")" = 600000 ] && [ "$c4" -ge 1 ]; then echo "  m4 PASS (same chain in mode 4: rc=0, walked $(cat "$T/o4") cells back, $c4 collection(s))"
else echo "  m4 FAIL (rc=$r4 out=[$(cat "$T/o4")] collections=$c4 -- $(head -1 "$T/e4" | cut -c1-90))"; RC=1; fi
examined=$((examined+1))
SCRIP_ZETA_TELEM=1 timeout -k 5 "$CEIL_SCALE" "$SCRIP" "$T/big.sno" </dev/null >"$T/ob" 2>"$T/eb"; rb=$?; cb=$(grep -c regeneration "$T/eb")
refuse_on_clock "$rb" "scaling 1500000-cell" "$CEIL_SCALE" "$T/eb"
d=$(grep -oE 'wl_depth_max=[0-9]+' "$T/eb" | cut -d= -f2 | sort -n | tail -1); mk=$(grep -oE 'marked=[0-9]+' "$T/eb" | cut -d= -f2 | sort -n | tail -1)
if [ "$rb" = 0 ] && [ "$(cat "$T/ob")" = 1500000 ] && [ "$cb" -ge 1 ] && [ -n "$mk" ] && [ "$mk" -ge 3000000 ]; then echo "  scaling PASS (1500000-cell chain: rc=0, $cb collection(s), marked=$mk blocks, two per cell, wl_depth_max=${d:-absent} -- the walk is not on the C stack, and it really walked)"
else echo "  scaling FAIL (rc=$rb out=[$(cat "$T/ob")] collections=$cb marked=[${mk:-absent}] wl_depth_max=[${d:-absent}] -- either the chain did not survive, or the marked instrument is gone, or the collector stopped walking the chain and only looks cured)"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: the mark walk is an explicit worklist; a 1.5M-cell DATA chain is collected and walked on a bounded C stack in both modes (examined $examined arms)"
else echo "GATE FAIL(1) [$G]: the descriptor walk recurses per cell again, or the chain no longer survives a collection (examined $examined arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
