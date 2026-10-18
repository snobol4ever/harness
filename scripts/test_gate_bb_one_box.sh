#!/usr/bin/env bash
# test_gate_bb_one_box.sh — PL-HY-FENCE + ICN-HY-FENCE gate (GOAL-PROLOG-BB.md, GOAL-ICON-BB.md).
#
# ONE BOX PER TEMPLATE FILE. Each language-OWNED box file in src/templates/ must define
# EXACTLY ONE box entry (comments stripped). Helper files define zero.
#
# WHAT A BOX ENTRY IS (repaired 2026-08-23 s269, hq_C — see the STALE MATCHER note below):
#   a top-level DEFINITION returning std::string, named bb_<name>, whose name does NOT end
#   in _str.  Both argument shapes are boxes: bb_every() and bb_call(IR_t * pBB).
# WHAT A HELPER IS: bb_<name>_str(...) — the _str suffix is the discriminator, and always was
#   (this file's own header said so while its matcher tested something else entirely).
# NOT A BOX: `static` file-local helpers; `extern`-only declarations; extern "C" void bb_*()
#   runtime-state helpers (bb_scc_handoff_* in bb_call_proc_staged.cpp are these).
#
# ⛔ WHY THIS GATE WAS 100% RED AND HID EVERY REGRESSION IT EXISTS TO CATCH (hq_C s269):
#   the matcher was `extern "C" void bb_[a-z_]+\(` — a signature the template architecture
#   left behind. Every box now returns std::string (144 of them), so the matcher scored 0 on
#   EVERY box file and 36/36 checks FAILed. Its only nonzero hit was the one place it should
#   have scored zero: the three extern "C" void bb_scc_handoff_* helpers, reported as a
#   helper-file violation. A gate that is red on everything is a gate nobody reads.
#   ⭐ Transferable: this gate never asserted the SHAPE of the thing it measured — same class
#   as the M1 probe that read 0 bytes where the real symptom was 278.
#
# PROLOG box files: bb_arith, bb_cut, bb_fail. (The old resolve-family boxes — bb_atom,
#   bb_resolve, bb_catch, bb_choice, bb_conj, bb_disj, bb_goal, bb_ite, bb_logicvar,
#   bb_unify — and the bb_det_*/bb_cell_* families were deleted 2026-07-11: superseded by
#   the reduced-IR spine + $name runtime dispatch. Git holds them.)
#
# ICON box files: listed below. FIVE names left this list 2026-08-23 s269 — every one of them
#   deliberately deleted by a named commit, none a regression, all verified before removal:
#     bb_alt.cpp                b00a0afb  icon: delete IR_ALT — not a valid IR code
#     bb_assign_frame.cpp       3d0a0d57  dead-code sweep (92nd attended run)
#     bb_assign_frame_ref.cpp   3d0a0d57  dead-code sweep (92nd attended run)
#     bb_binop_gvar_relop.cpp   3d0a0d57  dead-code sweep (92nd attended run)
#     bb_keyword.cpp            2d46be9c  IR_KEYWORD split (ICON/SNOBOL4)
#   bb_binop_relop_val JOINED it s269: it was a second box living inside bb_binop_relop.cpp
#   (the one genuine one-box violation this gate found once it could see), split out to its
#   own file rather than granted an exception — RULES.md forbids per-op exception lists.
# ICON helper files (exempt): bb_call_fn, bb_call_proc_staged.
#
# Usage: bash ../harness/scripts/test_gate_bb_one_box.sh
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
fail=0
PL_BOX_FILES="
src/templates/bb/bb_cut.cpp
src/templates/bb/bb_fail.cpp
"
PL_HELPER_FILES="
"
ICN_BOX_FILES="
src/templates/bb/bb_to.cpp
src/templates/bb/bb_iterate.cpp
src/templates/bb/bb_scan_pos.cpp
src/templates/bb/bb_scan_any.cpp
src/templates/bb/bb_scan_match.cpp
src/templates/bb/bb_scan_many.cpp
src/templates/bb/bb_scan_tab.cpp
src/templates/bb/bb_scan_move.cpp
src/templates/bb/bb_scan_upto.cpp
src/templates/bb/bb_scan_find.cpp
src/templates/bb/bb_scan_bal.cpp
src/templates/bb/bb_lit_scalar.cpp
src/templates/bb/bb_var.cpp
src/templates/bb/bb_var_global.cpp
src/templates/bb/bb_var_frame.cpp
src/templates/bb/bb_assign_local.cpp
src/templates/bb/bb_unop.cpp
src/templates/bb/bb_succeed.cpp
src/templates/bb/bb_return.cpp
src/templates/bb/bb_call.cpp
src/templates/bb/bb_binop_arith.cpp
src/templates/bb/bb_binop_relop.cpp
src/templates/bb/bb_binop_relop_val.cpp
src/templates/bb/bb_binop_concat_slot.cpp
"
ICN_HELPER_FILES="
src/templates/bb/bb_call_fn.cpp
src/templates/bb/bb_call_proc_staged.cpp
"
strip_comments() { perl -0777 -pe 's{/\*.*?\*/}{}gs; s{//[^\n]*}{}g' "$1"; }
box_entries() { strip_comments "$1" | grep -E '^(extern "C"[[:space:]]+)?std::string[[:space:]]+bb_[a-z0-9_]+[[:space:]]*\([^;]*$' | grep -cvE 'bb_[a-z0-9_]*_str[[:space:]]*\('; }
check_group() {
    want="$1"; label="$2"; shift 2
    for f in $*; do
        [ -f "$f" ] || { echo "FAIL: expected $label file missing: $f"; fail=1; continue; }
        n=$(box_entries "$f")
        if [ "$n" -ne "$want" ]; then
            echo "FAIL: $label file $f defines $n box entries (expected exactly $want)"
            fail=1
        fi
    done
}
check_group 1 "Prolog box"  "$PL_BOX_FILES"
check_group 0 "Prolog helper" "$PL_HELPER_FILES"
check_group 1 "Icon box"    "$ICN_BOX_FILES"
check_group 0 "Icon helper" "$ICN_HELPER_FILES"
if [ "$fail" -eq 0 ]; then
    echo "PASS: every Prolog+Icon box file defines exactly 1 std::string bb_* box entry; all helpers define 0."
fi
exit $fail
