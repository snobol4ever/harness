#!/bin/bash
# test_gate_p7_prolog_setjmp_gone.sh -- the DONE-WHEN of P7 (PROLOG REDESIGN, ARCH-PROLOG-THREE-ZETAS.md § 4; hq_P).
#
# ⭐ WHAT P7 DELETES, and why it is a deletion rather than a fix: Prolog failure and cut are control, and control belongs on the PORTS. Failure is β and cut is ω -- wired jumps decided at compile
# time -- so the C machinery that implements them by unwinding the C stack has no job left. Section 4's row: the three live setjmp barriers, g_plw_unwind_floor, g_plw_floor_bypass,
# rt_plw_floor_bypass_on, dop_call_nothrow and its two wrappers, at by_name_dispatch.c:1486-1600, 4872-4875, 4911, 5064.
#
# ⛔ IT GRADES BOTH HALVES, BECAUSE EITHER ALONE IS PASSABLE BY A CHANGE THAT DID NOT HAPPEN: the symbol must be gone from src/ AND absent from `nm -D out/libscrip_rt.so`. A source deletion that
# leaves an exported symbol means something still links it; an unexported symbol still named in src/ means the deletion was cosmetic. The section 4 form is "absent from src/ AND from nm -D" for
# exactly this reason and it is followed here literally.
#
# ⛔⛔ AND IT GRADES "BOARDS NOT WORSE" WITH THE INSTRUMENT THAT CAN ACTUALLY SAY SO. Deleting a stack-unwinding barrier is precisely the change that converts a caught corruption into a crash, so
# the van Roy board is not decoration here -- it is the safety half of this row. ⛔ It is called through test_gate_vanroy_prolog_acceptance.sh, which grades REFUSE 0 **and** CRASH 0 **and** a pinned
# CLEAN floor over worst-of-N: a bare "REFUSE 0" would be SATISFIED by these very deletions turning refusals into crashes (.github FINDING 5c7d2254). Do not swap it for a cheaper check.
# ⭐ SEQUENCING: P7 lands AFTER PZ-4 → PZ-5 → C36 (§ 6). Before the frame exists, deleting the barrier removes the only thing catching the corruption -- the board would get worse and this gate
# would correctly say so. A red here BEFORE the frame lands is the sequence being violated, not the cure being wrong.
set -u
R="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the SEAT ROOT is derived from THIS script, never a hardcoded seat (hq_C measured 2026-09-02: the old /home/claude_P default graded hq_P's checkout from hq_C's seat)

cd "$R/SCRIP" 2>/dev/null || { echo "⛔ REFUSED (rc=2): no $R/SCRIP"; exit 2; }
SO=out/libscrip_rt.so
[ -f "$SO" ] || { echo "⛔ REFUSED (rc=2): $SO not built -- 'symbol absent' is unfalsifiable against a library that does not exist, and an unbuilt tree would PASS the nm half for free"; exit 2; }
[ -d src ] || { echo "⛔ REFUSED (rc=2): no src/ -- cannot grade a source deletion it cannot read"; exit 2; }
# ⛔ THE .so MUST BE CURRENT OR THIS VERDICT IS ABOUT A BUILD NOBODY SHIPS (row stale-binary-preflight-also-
# covers-out-libscrip_rt-so). A stale OLDER .so still exports what src/ deleted and cannot show what src/
# added, so a clean nm surface here is a FALSE GREEN. Shared authority -- sourced, never copied.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_build_currency.sh"
assert_so_current "$SO" "$R/SCRIP" || exit 2
F=0
# the symbol set, measured hq_P 2026-09-02 (SCRIP fa12d7cb): section 4 names "dop_call_nothrow and its two wrappers" -- the wrappers are rt_pl_dop_trail_unwind (:1598) and
# rt_pl_dop_unwind_nothrow (:1599), "dop_call_nothrow's only two callers" per by_name_dispatch.c:1514; dop_unwind_nothrow (:1405) is the body behind the second and is reached by the
# "$unwind_nothrow" by-name arm (:2727). Those two rt_pl_dop_* wrappers are P7's, not P6's, so P6's "22 wrappers" reads 20 once this lands.
for s in g_plw_unwind_floor g_plw_floor_bypass rt_plw_floor_bypass_on dop_call_nothrow dop_unwind_nothrow rt_pl_dop_trail_unwind rt_pl_dop_unwind_nothrow; do
    n=$(grep -rw "$s" src/ 2>/dev/null | wc -l)
    e=$(nm -D "$SO" 2>/dev/null | grep -cw "$s")
    [ "$n" -eq 0 ] || { echo "⛔ $s: still $n reference(s) in src/"; F=1; }
    [ "$e" -eq 0 ] || { echo "⛔ $s: still EXPORTED from $SO -- something links it"; F=1; }
done
# the three setjmp barriers themselves, scoped to the file section 4 names
# ⛔⭐ ONLY dop_call's BARRIER IS PROLOG'S -- MEASURED hq_P 2026-09-02, correcting section 4's "three live setjmp barriers", which overcounts by two. rt_call_arr_bl's setjmp is SNOBOL4/Icon
# &ERROR-to-failure trapping (emitted from bb_call_fn.cpp:510/596, referenced from lower_snobol4.c; history 12dc1714 + aadd86c4 "GOAL-ICON-BB drive FAILs 14->9") -- only its two g_plw_unwind_floor
# lines are Prolog's. c_rt_jct_relop's veneer rt_jct_relop is called from bb_binop_relop*.cpp / bb_to*.cpp -- Icon/SNOBOL4 boxes; lower_prolog.c has ZERO relop/to references, so Prolog never
# reaches it. Both are SHARED NODES; deleting either is a shared-node change graded on the SNOBOL4 board and the Icon watermark for no Prolog gain. So this gate demands setjmp gone from
# dop_call's BODY, never from the whole file -- a whole-file count would order the deletion of two other languages' error trapping under a Prolog row.
# ⭐ And dop_call's barrier is DEAD for Prolog by construction: core_runtime_error longjmps only when g_error != 0, and g_error has zero references on the Prolog path (it exit(1)s instead).
j=$(awk '/^static DESCR_t dop_call\(/{f=1} f&&/^}/{exit} f' src/runtime/by_name_dispatch.c 2>/dev/null | grep -cE '^[^*/]*\bsetjmp[[:space:]]*\(')
d=$(grep -cE '^static DESCR_t dop_call\(' src/runtime/by_name_dispatch.c 2>/dev/null)
if [ "$d" -gt 0 ] && [ "$j" -ne 0 ]; then echo "⛔ dop_call still carries a setjmp barrier ($j) -- Prolog failure must be β, a wired jump, not C-stack unwinding (dop_call may also simply be gone: it exists only to wrap the barrier)"; F=1; fi
u=$(grep -cF '"$unwind_nothrow"' src/runtime/by_name_dispatch.c 2>/dev/null)
[ "$u" -eq 0 ] || { echo "⛔ the \$unwind_nothrow by-name arm is still dispatched ($u site(s)) -- the nothrow body it reaches is a P7 deletion"; F=1; }
[ $F -eq 0 ] || { echo "GATE FAIL(1) [p7_prolog_setjmp_gone]: the P7 symbols are not gone"; exit 1; }
echo "P7 symbols gone from src/ and from $SO. Now the safety half -- deleting a barrier must not convert a caught corruption into a crash:"
bash ../harness/scripts/test_gate_vanroy_prolog_acceptance.sh || { echo "GATE FAIL(1) [p7_prolog_setjmp_gone]: symbols gone but the van Roy board is WORSE -- the barrier was catching something the ports do not yet catch"; exit 1; }
echo "PASS: P7 -- Prolog failure/cut is wired jumps, the setjmp barriers and plw floor are gone, and the van Roy board did not degrade"
