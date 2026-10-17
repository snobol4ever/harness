#!/usr/bin/env bash
# test_gate_sn4_call_scope_rides_the_strict_field_not_an_opcode_flip.sh -- A SNOBOL4 BY-NAME CALL'S RUNTIME RESOLVER SCOPE IS
# CARRIED BY THE CALL NODE'S strict FIELD (value 2), NEVER BY RE-STAMPING THE CALL AS IR_CALL_SNOBOL4 (cfo 2026-09-16, officer
# ruling on hq_snobol4's ask "sn4-opcode-flip-breaks-26-entries-shared-node-filters-need-the-opcode"; row
# shared-node-filters-test-op-eq-ir-call-directly-and-miss-ir-call-snobol4-after-the-opcode-flip).
#
# WHY: the entry point hq_snobol4 was granted (rt_call_arr_bl_sn4 beside rt_call_arr_bl / rt_call_arr_bl_strict) is selected in
# bb_call.cpp and bb_call_fn.cpp exactly where _.op_strict already selects the strict variant, and op_strict is NOT an opcode:
# emit.cpp copies it from the node field IR_t.strict (lower_icon.c:45 sets 1 for Icon's strict calls). Their branch 6835dec48
# instead re-stamped sx_call_named's node as IR_CALL_SNOBOL4 and lost 26 SnoRungs entries (base 319e8e7ad 1961/1972 -> head
# 1936/1972): the tree carries ~110 bare IR_CALL tokens, 35 of them in the shared nodes off the helper lines (emit.cpp 35, lower_snobol4.c 31, scrip.c 18,
# frame_layout.c 7, bb templates 10, scrip_ir.c 4, gva_collect.c 2, proc_collect.c 2), and the ones a SNOBOL4 graph reaches --
# gva_collect.c:31 (INPUT/OUTPUT refuse GVA) and :87 (TRACE demote), proc_collect.c:39/:52 (proc census, OPSYN taint),
# emit.cpp:95/:96/:3314 (SNO$NRET floaters), :2275 (zd proc route), :2315 (zd_nops), the fence-family lists, frame_layout.c:380/
# :388/:851/:1038 (and :1030 already files IR_CALL_SNOBOL4 under the STATEMENT regime, the opposite tier from :1038's callee
# arm), bb_binop_gvar_arith_slot.cpp:56/:64 and bb_unop_gvar_slot.cpp:23 (a +8 slot offset keyed on bb_lk == IR_CALL) -- each
# silently stop matching. Converting them is a ~40-site language-blind change to shared nodes for a property one field already
# carries. Measured on the probe origin/cfo/sn4-scope-on-strict-field-probe (f9209478d: their diff with the flip replaced by
# call->strict = 2 and g_emit.op_sn4 = (nd->strict == 2)): simple_output_55, user_function_opsyn_1 and the rung22 witness PASS
# both modes, `OUTPUT = sqrt(4.0)` raises ERROR 22 like sbl, and the 94-entry simple_output_5x-9x / rung22 / opsyn family reads
# 87/94 in m3 on probe AND on base (the 7 are extraction artifacts, red on both).
#
# ARMS: (1) CENSUS -- no producer of IR_CALL_SNOBOL4 under src/ (a node built with it or an op assigned to it); consumers
# (ir_is_call_kind, case lists, the name table) are allowed to stay; (2) STRUCTURAL -- the emitter still reads the per-call
# entry choice from the node field (g_emit.op_strict = nd->strict), the channel the ruling names; (3) INFORMATION, not
# graded -- the count of bare IR_CALL tokens in the shared nodes, printed so a future reader sees the blast radius a flip
# would carry. SN4_SCOPE_GATE_TREE=<dir> points the census at another checkout (fail-once).
# FAIL-ONCE, 2026-09-16: arm 1 read 1 (lower_snobol4.c:247 lc_build(cx->g, IR_CALL_SNOBOL4, ...)) on a copy of 6835dec48's
# six files. PASS-ONCE: 0 on origin 8e3d82c2a and on the probe f9209478d.
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
TREE="${SN4_SCOPE_GATE_TREE:-$ROOT}"
[ -d "$TREE/src" ] || { echo "⛔ GATE REFUSE(2) [$G]: no src/ under $TREE"; exit 2; }
rc=0
prod="$(grep -rnE '((->|\.)op *= *IR_CALL_SNOBOL4\b)|(\( *[^()]*, *IR_CALL_SNOBOL4 *,)' "$TREE/src" 2>/dev/null || true)"
np="$(printf '%s' "$prod" | grep -c . || true)"
if [ "$np" -eq 0 ]; then echo "✅ [$G] arm 1: producers of IR_CALL_SNOBOL4 under src/ = 0"; else echo "❌ [$G] arm 1: $np producer(s) of IR_CALL_SNOBOL4 under src/ -- the scope rides IR_t.strict == 2, not an opcode:"; printf '%s\n' "$prod" | cut -c1-200; rc=1; fi
ch="$(grep -cE 'g_emit\.op_strict *= *nd->strict' "$TREE/src/emitter/emit.cpp" 2>/dev/null || true)"
if [ "${ch:-0}" -ge 1 ]; then echo "✅ [$G] arm 2: emit.cpp reads the per-call entry choice from IR_t.strict ($ch site)"; else echo "❌ [$G] arm 2: emit.cpp no longer copies nd->strict into g_emit.op_strict -- the field channel the ruling names is gone"; rc=1; fi
bare="$(grep -rnE '\bIR_CALL\b' "$TREE/src/optimizer" "$TREE/src/emitter" "$TREE/src/templates" "$TREE/src/ir" "$TREE/src/driver" 2>/dev/null | grep -vE 'IR_CALL_|ir_is_call_kind|ir_norm_call_kind' | wc -l)"
echo "ℹ️  [$G] arm 3 (information): bare IR_CALL tokens in the shared nodes not routed through the helpers = $bare"
[ $rc -eq 0 ] && echo "✅ [$G] PASS" || echo "❌ [$G] FAIL"
exit $rc
