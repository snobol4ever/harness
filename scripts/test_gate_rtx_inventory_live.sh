#!/usr/bin/env bash
# test_gate_rtx_inventory_live.sh — audit ARCH-SNOBOL4-RTX.md section 5 against reality.
#
# WHY THIS EXISTS (RTX-2/RTX-3, s163): section 5's family table is hand-written and ROTS.
# RTX-2 was aimed at blk_alloc/blk_free, which have no definition in src/ and no live call
# site; the STR row then turned out to name rt_concat/rt_lcomp/rt_acomp, which do not exist
# either. A rung pointed at a ghost burns a session before anyone notices, so the check that
# would have caught it in two minutes is now mechanical and repeatable.
#
# For every symbol: does src/ define it, and does the LIVE compiler emit calls to it?
#   DEF+CALLED  defined in the runtime AND called by live blobs
#   DEF-ONLY    defined, reached only from inside the runtime (NOT a defect -- see below)
#   PHANTOM     absent from the linked runtime -> never put a rung on this
# DEF-ONLY is NOT a defect: rt_gcheap_alloc is DEF-ONLY and underlies every mint. A static
# blob->runtime count ranks the CALL BOUNDARY, not the hot path (RTX-2 finding, consequence a).
#
# ⚠ ADVISORY, NOT A HARD GATE (downgraded s163, the same session it was written). This script
# gave TWO false verdicts before it gave a true one: a src/ regex called rt_proc_call_epilogue_
# (178 call sites) a phantom, and after switching the oracle to nm the name STILL missed because
# the inventory was truncating Greek port suffixes. It now agrees with the linker on everything
# checked, but it has been wrong twice and its symbol list is hand-maintained, so it REPORTS and
# never blocks. Treat a PHANTOM row as "go verify this", not as proof. Exit is always 0.
# Usage: bash ../harness/scripts/test_gate_rtx_inventory_live.sh [corpus_root]
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
cd "$(dirname "$0")/../../SCRIP"
CORPUS="${1:-$S4E/corpus}"
[ -d "$CORPUS" ] || { echo "FAIL: corpus not found at $CORPUS"; exit 1; }
INV=$(bash ../harness/scripts/util_rtx_symbol_inventory.sh "$CORPUS" 2>/dev/null)
# THE DEFINITION ORACLE IS THE LINKER, NOT A GREP (corrected s163, same day it was written).
# The first cut regex-scanned src/ for a C-looking definition and reported rt_proc_call_epilogue_
# (178 LIVE CALL SITES) as a phantom -- macro-built, generated and extern "C" bodies all slip past
# any such pattern. A symbol the blob calls and that LINKS cannot be missing. nm on the built
# runtime is ground truth; if the .so is stale, rebuild before trusting this gate.
SO=out/libscrip_rt.so
[ -f "$SO" ] || { echo "FAIL: $SO not built — run make first (this gate reads the linker's symbol table)"; exit 1; }
NMSYMS=$(nm -g --defined-only "$SO" 2>/dev/null | awk '{print $3}')
SYMS="
ALLOC:rt_gcheap_alloc rt_str_alloc rt_str_dup rt_ws_alloc rt_ws_realloc rt_ws_strdup rt_ws_alloc_c rt_agg_alloc rt_pl_struct_alloc rt_pvec_alloc rt_wsb_realloc blk_alloc blk_free
STR:str_concat_d rt_concat rt_lcomp rt_acomp rt_coerce_str_d rt_substr
CALL:rt_proc_call_open rt_proc_call_epilogue_ rt_proc_open_fn rt_call_arr rt_call_named_proc rt_call rt_arg_stage rt_do_return rt_define rt_define_entry rt_proc_register rt_proc_reset rt_frame
AGG:rt_subscript_var rt_deref rt_field_var record_register
ARITH:rt_num_arith rt_arith rt_binop_overload rt_coerce_num2_d rt_coerce_num rt_num_pos rt_neg rt_incr rt_decr rt_exp rt_cmp_d
NV:NV_GET_fn NV_SET_fn rt_nv_get rt_nv_set rt_gvar_get_int rt_gvar_assign_str rt_gvar_assign_descr rt_gva_island gva_register rt_subject_load_nv
MATCH:rt_match_enter rt_match_variant rt_match_replace rt_defer_close rt_scan_splice_empty
MISC:rt_faildescr rt_is_truthy rt_last_ok rt_assign_var rt_goto_transfer rt_bomb execute_code_dyn comm_stno core_lib_init dtp_fn_of rt_write_any_nl rt_push_ rt_pop_void rt_halt_tos
"
PH=0; nd=0; nc=0; np=0
printf '%-12s %-30s %-9s %-7s %s\n' FAMILY SYMBOL DEFINED CALLS VERDICT
printf '%.0s-' {1..78}; echo
while IFS= read -r line; do
  [ -z "$line" ] && continue
  fam="${line%%:*}"; rest="${line#*:}"
  for s in $rest; do
    d=$(printf '%s\n' "$NMSYMS" | grep -cx "$s")
    c=$(printf '%s\n' "$INV" | awk -v k="$s" '$2==k {print $1}'); c="${c:-0}"
    if [ "$d" -eq 0 ]; then v="PHANTOM"; PH=$((PH+1)); np=$((np+1))
    elif [ "$c" -gt 0 ]; then v="DEF+CALLED"; nc=$((nc+1))
    else v="DEF-ONLY"; nd=$((nd+1)); fi
    printf '%-12s %-30s %-9s %-7s %s\n' "$fam" "$s" "$d" "$c" "$v"
  done
done <<< "$SYMS"
printf '%.0s-' {1..78}; echo
echo "DEF+CALLED=$nc  DEF-ONLY=$nd  PHANTOM=$np"
if [ "$PH" -gt 0 ]; then
  echo "ADVISORY: $PH symbol(s) named in ARCH-SNOBOL4-RTX.md section 5 are absent from the linked runtime."
  echo "VERIFY each before opening a rung on it — and verify this script too; it has been wrong before."
  exit 0
fi
echo "ADVISORY: every section-5 symbol resolves in the linked runtime."
