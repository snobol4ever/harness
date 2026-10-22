#!/usr/bin/env bash
# test_gate_one_retains_table.sh -- ONE RETAINS TABLE IN THE PLANNER (ARCH-ZETA-ONE-COORDINATE 3.4 finding 2; Lon 2026-10-22: finish the memory model
# re-write and complete the PLANNER stage). The fact "this box's gamma may return with its callee's frame still live, so the boxes after it are
# indefinite and a cell read across it is frame-homed" is decided in ONE function, planner_retains in src/planner/, with a reason code per row; every
# other reader is a named VIEW of that table (the layout's home pass through planner_home_dyn, the depth plan through zd_edge_retains, the emitter's
# retaining kinds through planner_retains_emitter_view). A second table -- a kind list or a switch over IR kinds deciding retention outside src/planner
# -- is the defect this gate names.
#   test_gate_one_retains_table.sh [--root DIR]      (--root: grade another root's SCRIP, for a two-tree reading)
# rc 0 one table · rc 1 a second table remains (each named) · rc 2 could not read the sources.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
[ "${1:-}" = "--root" ] && ROOT="$2"
SRC="$ROOT/SCRIP/src"
for f in planner/zeta_plan.cpp planner/planner.h ir/frame_layout.c emitter/emit.cpp; do [ -r "$SRC/$f" ] || { echo "REFUSE(2): cannot read $SRC/$f"; exit 2; }; done
bad=0
grep -q '^int planner_retains(const IR_t \* nd) {' "$SRC/planner/zeta_plan.cpp" || { echo "RED: src/planner/zeta_plan.cpp defines no planner_retains"; bad=1; }
grep -q 'int planner_retains(const IR_t \* nd);' "$SRC/planner/planner.h" || { echo "RED: planner.h declares no planner_retains"; bad=1; }
# the layout's home pass: its dynamic-box test must be the planner's view, not a switch over kinds
if awk '/^static int zls_home_dyn\(/{f=1} f&&/case IR_/{print; exit} f&&/^}/{exit}' "$SRC/ir/frame_layout.c" | grep -q 'case IR_'; then echo "RED: frame_layout.c zls_home_dyn switches over IR kinds (a second retains table)"; bad=1; fi
grep -q 'planner_home_dyn' "$SRC/ir/frame_layout.c" || { echo "RED: frame_layout.c does not read planner_home_dyn"; bad=1; }
# the emitter's retaining kinds must be the planner's view
if grep -q 'static int icn_retaining_kind(int op) { return op == IR_' "$SRC/emitter/emit.cpp"; then echo "RED: emit.cpp icn_retaining_kind lists kinds itself (a second retains table)"; bad=1; fi
grep -q 'planner_retains_emitter_view' "$SRC/emitter/emit.cpp" || { echo "RED: emit.cpp does not read planner_retains_emitter_view"; bad=1; }
n_outside=$(grep -l 'IR_PROC_GEN || op == IR_CALL_VALUE\|case IR_CALL_GEN:' "$SRC"/emitter/*.cpp "$SRC"/ir/*.c "$SRC"/templates/bb/*.cpp 2>/dev/null | wc -l)
echo "ONE_RETAINS_TABLE root=$ROOT planner_retains=$(grep -c '^int planner_retains(const IR_t \* nd) {' "$SRC/planner/zeta_plan.cpp") kind_lists_outside_planner=$n_outside verdict=$([ $bad = 0 ] && echo GREEN || echo RED)"
[ $bad = 0 ]
