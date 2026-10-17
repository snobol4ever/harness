#!/usr/bin/env bash
# test_gate_a_frame_local_written_at_a_join_fix_depth_reaches_its_one_cell.sh -- ON THE RSP SPINE A FRAME LOCAL IS ONE CELL ON
# EVERY PATH (hq_zetas 2026-10-09, row a-false-relational-over-an-array-element-or-record-field-in-value-position-leaves-a-null-and-
# error-102, found by hq_pascal and routed by the cfo as a shared-node emission defect, never a Pascal lowering).
#
# THE DEFECT: in a graph emitted on the RSP spine (the ZD plan), a frame local's slot is an rsp-relative displacement, so every
# access to it must happen at the one spine depth its displacement was laid out for. The planner closes a join by popping the
# surplus inside the last node before it (gpop): b := (a[1] = 4) lowers the false edge of the compare into a run whose LIT 0
# enters at the join depth and whose ASSIGN __pbt0 pops the literal at gamma, so that ASSIGN stores 16 bytes deeper than the
# true edge's ASSIGN. Both stored to [rsp + 672]; measured under gdb, the true store ran at rsp ...ff00 and the false one at
# ...fef0, so the false value landed beside __pbt0, which stayed null, and the next numeric use died with error 102 (the
# `if b` test), in both modes. The branch form (if a[i] = key) never reaches that merge, which is why no suite saw it.
#
# THE CURE (src/emitter/emit.cpp drive_local_slot): the first planned access to a local in a graph records its entry depth
# (op_zrun) as that local's anchor; every later planned access adds its own entry depth minus the anchor to the displacement,
# a compile-time constant on each path (the BB FRAME-PLACEMENT CRITERION: a fixed compile-time offset on every path). Only
# planned spine nodes (op_zres) are corrected; an rbp-pinned frame and an Icon generator frame keep their fixed offsets.
# MEASURED: the false program's .s changes in exactly one store (672 -> 688); 286 corpus benchmark and gc_witness programs
# across every language emit byte-identical asm before and after.
#
# THE ARMS are hq_pascal's witness (util_witness_a_false_relational_over_a_fetch_is_a_boolean_value.sh, every expectation cut
# live from fpc -Miso, m3 and m4): an array element, a record field, both as a writeln argument, and the true cases.
#
# EXIT: 0 green. 1 an arm differs from fpc. 2 cannot measure (no scrip, runtime or fpc).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$HERE/util_witness_a_false_relational_over_a_fetch_is_a_boolean_value.sh"
[ -f "$W" ] || { echo "GATE UNPROVEN(2) [a-frame-local-written-at-a-join-fix-depth]: the witness $W is absent"; exit 2; }
bash "$W"; rc=$?
case $rc in
    0) echo "GATE GREEN(0) [a-frame-local-written-at-a-join-fix-depth]: a false relational over an array element or record field is a Boolean value in both modes"; exit 0;;
    1) echo "GATE RED(1) [a-frame-local-written-at-a-join-fix-depth]: a frame local written at a join-fix depth missed its cell"; exit 1;;
    *) echo "GATE UNPROVEN(2) [a-frame-local-written-at-a-join-fix-depth]: the witness could not measure (rc $rc)"; exit 2;;
esac
