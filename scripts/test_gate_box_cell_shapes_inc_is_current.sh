#!/usr/bin/env bash
# test_gate_box_cell_shapes_inc_is_current.sh -- THE CELL-SHAPE TABLE AND THE PLANNER AGREE (ARCH-ZETA-ONE-COORDINATE 3.5 (iii); ARCH-THREE-ZETAS-EMISSION
# 10 (3); the cto, CEO-1923). harness/scripts/box_cell_shapes.tsv is the one statement of what each box kind carves at its alpha; the planner's zd_k_own
# reads SCRIP/src/planner/box_cell_shapes.inc, which util_gen_box_cell_shapes.py writes from it. A table edited without regenerating, or an .inc edited
# by hand, is the drift this gate names; and the planner must read the table, never a hand list of kinds beside it.
# rc 0 current · rc 1 stale, or zd_k_own decides a carve without the table · rc 2 cannot read the table, the .inc or the planner.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../../SCRIP/src/planner"
[ -r "$SRC/zeta_plan.cpp" ] || { echo "REFUSE(2): cannot read $SRC/zeta_plan.cpp"; exit 2; }
python3 "$HERE/util_gen_box_cell_shapes.py" --check; rc=$?
[ "$rc" = 2 ] && exit 2
body=$(awk '/^int zd_k_own\(IR_t \* nd\) \{/{f=1} f{print} f&&/^}/{exit}' "$SRC/zeta_plan.cpp")
[ -n "$body" ] || { echo "REFUSE(2): zeta_plan.cpp defines no zd_k_own"; exit 2; }
if ! printf '%s\n' "$body" | grep -q 'box_cell_shapes\['; then echo "RED: zd_k_own does not read box_cell_shapes[]"; rc=1; fi
if printf '%s\n' "$body" | grep -q 'IR_[A-Z_]* *=='; then echo "RED: zd_k_own compares IR kinds itself (a hand list beside the table)"; rc=1; fi
[ "$rc" = 0 ] && echo "GATE OK [box_cell_shapes_inc_is_current]: the planner's carves come from the cell-shape table" && exit 0
echo "GATE RED [box_cell_shapes_inc_is_current]"; exit 1
