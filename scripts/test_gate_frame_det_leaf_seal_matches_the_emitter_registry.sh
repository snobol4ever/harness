#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ RUNG 2 STEP 1 of frame-slot-reuse-a-live-range-in-a-byrd-graph-extends-to-every-point-reachable-by-recession
# (cto, CEO-684 slice 2): THE DET-LEAF FACT TRAVELS ON THE IR NODE.  A CALL is beta-capable until proven otherwise;
# the proof for a $-leaf is per callee: the emitter's registry (dop_direct_fp, bb_call.cpp) names the C functions a
# call reaches directly, every such box returns once and its beta is a jump to omega (bb_call_fn.cpp, both arms),
# and its argv block is read only by that one call.  The LOWERER asks the registry at graph finish (pl_graph_stamp)
# and seals the node (IR_t.seal = IR_SEAL_CALL_DET_LEAF, the call's existing lowerer-fact field, language-blind
# name in IR.h); the EMITTER refuses (x86_bomb) any sealed call its registry does not know; the reuse relation
# reads only the seal and stops calling a sealed call a choice point (PINNED det leaf <name>: no beta, argv dead
# at gamma), so a straight temp that merely spans a det leaf is no longer PINNED guard.  Result and argv slots
# do not move in this step (the argv rung is next); this step lands the CLAIM, printed, and the check that holds it.
# THE CLAIM SPANS TWO SITES (the lowerer's seal, the emitter's registry), so util_frame_det_leaf_bit_vs_registry.py
# grades every graph of the Prolog witness: sealed calls in --dump-zeta == IR_CALL boxes whose first call
# instruction targets a registry symbol rather than rt_call_arr_bl (by-name dispatch), both directions.
# PINS: (1) every graph graded and every graph agrees; (2) r/1 seals exactly its five $-leaves and its guard pin
# is gone (guard=0 in the summary; rung 1 read guard=1 across $ax_sub); (3) the Icon silent-failure witness
# (every write(1, 1 to 3)) still reads PINNED guard naming IR_TO -- a generator is not a det leaf; (4) the
# MEASURES line.  RED-BEFORE (5538c5a5e): no det-leaf line anywhere (sealed=0 on 161 graphs against 486 direct
# boxes), r/1 guard=1.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
cd "$ROOT" || exit 2
[ -f ../harness/scripts/util_frame_det_leaf_bit_vs_registry.py ] || { echo "⛔ REFUSE(2): the checker is absent -- nothing measured"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
python3 ../harness/scripts/util_frame_det_leaf_bit_vs_registry.py ../harness/scripts/fixtures/frame_r1_witness.pl > "$T/dl.txt" 2>&1; rc=$?
[ "$rc" -ne 2 ] || { echo "⛔ REFUSE(2): the checker graded nothing"; sed -n 1,5p "$T/dl.txt"; exit 2; }
bad=0
tot="$(grep -E '^; detleaf TOTAL' "$T/dl.txt")"; [ -n "$tot" ] || { echo "⛔ REFUSE(2): no TOTAL line"; exit 2; }
g="$(printf '%s' "$tot" | sed -n 's/.*graphs=\([0-9]*\).*/\1/p')"; gr="$(printf '%s' "$tot" | sed -n 's/.*graded=\([0-9]*\).*/\1/p')"; d="$(printf '%s' "$tot" | sed -n 's/.*disagree=\([0-9]*\).*/\1/p')"; sl="$(printf '%s' "$tot" | sed -n 's/.*sealed=\([0-9]*\).*/\1/p')"
echo "prolog witness: $tot"
[ "$g" -gt 100 ] && [ "$g" = "$gr" ] || { echo "  ⛔ not every graph graded ($gr of $g)"; grep 'NOT GRADED' "$T/dl.txt" | head -3; bad=$((bad+1)); }
[ "$d" = "0" ] || { echo "  ⛔ $d graph(s) where the seal and the registry disagree"; grep DISAGREE "$T/dl.txt" | head -5 | cut -c1-160; bad=$((bad+1)); }
[ "$sl" -gt 100 ] || { echo "  ⛔ only $sl sealed calls on the whole prelude -- the seal is not travelling"; bad=$((bad+1)); }
grep -qE "^; detleaf 'r/1' sealed=3 emitted_direct=3 " "$T/dl.txt" || { echo "  ⛔ r/1 does not seal exactly its three \$-leaves \$is_v \$ax_sub \$cmp_gt (five before rung 3(f) removed the head unify, four before R4.1 734797863 made r(0)'s head constant an IR_UNIFY_CONST box)"; grep "'r/1'" "$T/dl.txt"; bad=$((bad+1)); }
r1="$(timeout -k 5 20s ./scrip --dump-zeta ../harness/scripts/fixtures/frame_r1_witness.pl </dev/null 2>/dev/null | grep -E "^;   reuse 'r/1' ")"
printf '%s' "$r1" | grep -q ' guard=0 ' || { echo "  ⛔ r/1 still carries a guard pin: $r1"; bad=$((bad+1)); }
printf '%s' "$r1" | grep -q ' detleaf=3)' || { echo "  ⛔ r/1 summary does not count 3 det leaves: $r1"; bad=$((bad+1)); }
printf 'procedure main()\n   every write(1, 1 to 3);\nend\n' > "$T/w.icn"
timeout -k 5 20s ./scrip --dump-zeta "$T/w.icn" </dev/null 2>/dev/null | grep -q 'PINNED guard: box @[0-9]* IR_TO' || { echo "  ⛔ the Icon generator witness lost its guard pin -- a generator was treated as a det leaf"; bad=$((bad+1)); }
grep -q '^; detleaf MEASURES' "$T/dl.txt" || { echo "  ⛔ the MEASURES line is missing"; bad=$((bad+1)); }
if [ "$bad" -gt 0 ]; then echo "⛔ GATE FAIL: $bad finding(s) -- the det-leaf seal does not match the emitter's registry"; exit 1; fi
echo "GATE OK: $gr of $g graphs agree ($sl sealed calls == direct boxes), r/1 seals its three leaves with no guard pin, the Icon generator stays pinned, and the instrument states what it measures"
