#!/usr/bin/env bash
# test_gate_rtcc_block_coverage.sh — RTCC DoD coverage gate (GOAL-RTCC.md, s16).
#
# WHY: s14 established the coverage census BY HAND ("3 of 17 claimed registers round-trip at HEAD").
# A hand census is re-derived every session and rots silently between them.  RC-7's DoD line 1 cannot
# be certified against a veneer whose coverage nobody can recompute in one command.  This is that command.
#
# THE INVARIANT: for every register the VM claims as a global, the veneer must
#   (a) WRITE IT BACK at generated->C crossings,
#   (b) RELOAD IT at C->generated crossings, in BOTH mediums identically, and
#   (c) leave its block slot visible to the GC.
# A register failing (a) or (b) is not a global, it is a wish.  A register failing (c) is a
# use-after-free waiting for the first claimed register that holds a heap DESCR.
#
# ⛔ s11 LAW OBSERVED: no `cmd | grep -q` under pipefail anywhere below — the reader's early exit
# SIGPIPEs the upstream and a MATCH READS AS A MISS.  Every test is `grep -c` + a count comparison.
# ⛔ s15h LAW OBSERVED: the tree is located with `git rev-parse --show-toplevel`, never a hardcoded
# /home/claude path, so this gate grades the tree it lives in and not a peer seat's worktree.
# ⛔ POSITIVE CONTROL (test_gate_omega_own_k.sh exemplar): if the encoders cannot be found at all the
# gate EXITS 1 rather than passing over nothing.
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || { echo "GATE: FAIL — not inside a git worktree; refusing to grade an unknown tree"; exit 1; }
ASM="$ROOT/src/templates/x86/x86_asm.h"
INIT="$ROOT/src/runtime/rtx/rtcc_init.c"
RTCC="$ROOT/src/runtime/rtx/rtcc.h"
for f in "$ASM" "$INIT" "$RTCC"; do [ -r "$f" ] || { echo "GATE: FAIL — missing $f"; exit 1; }; done
echo "=== RTCC BLOCK COVERAGE GATE ==="
echo "tree: $ROOT"
echo
WBT="$(awk '/^static inline std::string x86_rtcc_wb_text/,/^}/' "$ASM")"
RLB="$(awk '/^static inline std::string x86_rtcc_rl_bin/,/^}/' "$ASM")"
RLT="$(awk '/^static inline std::string x86_rtcc_rl_text/,/^}/' "$ASM")"
WBB="$(awk '/^static inline std::string x86_rtcc_wb_bin/,/^}/' "$ASM")"
[ -n "$WBT" ] && [ -n "$RLB" ] && [ -n "$RLT" ] && [ -n "$WBB" ] || { echo "GATE: FAIL — POSITIVE CONTROL: veneer encoders not found in $ASM (renamed? moved?); refusing to grade nothing"; exit 1; }
# Parse the TEXT encoders: they carry REAL assembly strings.  The BINARY encoders emit raw bytes whose
# register identity survives only in comments -- grading those comments would measure documentation, not
# code (s13b: "a census over assembly must expand the project's own macros or it measures their absence").
# So: registers come from TEXT, and BINARY is cross-checked STRUCTURALLY by instruction count below.
# A store guarded by `if (!RTCC_GLOBAL_R9_GVA)` is NOT emitted at HEAD (the killswitch is 1) -- such lines
# are excluded, or the gate credits a register the veneer demonstrably skips.
wb_lines="$(printf '%s\n' "$WBT" | grep -v 'if (!RTCC_GLOBAL_R9_GVA)' | grep 'wb += " mov')"
rlt_lines="$(printf '%s\n' "$RLT" | grep 'rl += " mov')"
REGS="rax rcx rdx rsi rdi r8 r9 r10 r11"
wb_set=""; rlt_set=""; rlb_set=""
for r in $REGS; do
    n=$(printf '%s\n' "$wb_lines"  | grep -c "\], *$r\\\\n"); [ "$n" -gt 0 ] && wb_set="$wb_set $r"
    n=$(printf '%s\n' "$rlt_lines" | grep -c "mov $r, *qword"); [ "$n" -gt 0 ] && rlt_set="$rlt_set $r"
    n=$(printf '%s\n' "$RLB" | grep -c "mov $r, *\[r11+[0-9]\+\]"); [ "$n" -gt 0 ] && rlb_set="$rlb_set $r"
done
nwb_t=$(printf '%s\n' "$wb_lines" | grep -c 'mov')
nwb_b=$(printf '%s\n' "$WBB" | grep -v 'RTCC_GLOBAL_R9_GVA' | grep -c 'wb += (char)0x4[89C];')
nrl_t=$(printf '%s\n' "$rlt_lines" | grep -c 'mov')
nrl_b=$(printf '%s\n' "$RLB" | grep -c 'rl += (char)0x4[9D];')
echo "VENEER SIZE      : writeback text=$nwb_t bin=$nwb_b   reload text=$nrl_t bin=$nrl_b   TOTAL=$((nwb_t+nrl_t)) instructions/crossing"
echo "WRITEBACK (gen->C) :${wb_set:- NONE}"
echo "RELOAD  bin (C->gen):${rlb_set:- NONE}"
echo "RELOAD text (C->gen):${rlt_set:- NONE}"
echo
FAIL=0
if [ "$rlb_set" != "$rlt_set" ] || [ "$nwb_t" -ne "$nwb_b" ] || [ "$nrl_t" -ne "$nrl_b" ]; then
    echo "⛔ BOTH-MEDIUM VIOLATION: binary reload set != text reload set (RULES.md BOTH-MEDIUM MANDATORY)"; FAIL=1
else
    echo "BOTH-MEDIUM      : OK — same reload set AND same instruction count in both mediums"
fi
round=""; wbonly=""; rlonly=""
for r in $REGS; do
    inw=$(printf '%s' " $wb_set "  | grep -c " $r ")
    inr=$(printf '%s' " $rlt_set " | grep -c " $r ")
    if [ "$inw" -gt 0 ] && [ "$inr" -gt 0 ]; then round="$round $r"
    elif [ "$inw" -gt 0 ]; then wbonly="$wbonly $r"
    elif [ "$inr" -gt 0 ]; then rlonly="$rlonly $r"; fi
done
echo
echo "ROUND-TRIP       :${round:- NONE}      <- these are genuinely VM globals"
echo "WRITEBACK-ONLY   :${wbonly:- NONE}      <- stored every crossing, never reloaded: DEAD STORES"
echo "RELOAD-ONLY      :${rlonly:- NONE}      <- reload-only is CORRECT for a read-only cache of a constant (H2/r9)"
nround=$(printf '%s' "$round" | wc -w); nwbonly=$(printf '%s' "$wbonly" | wc -w)
echo
XMM=$(grep -c "xmm" "$INIT")
echo "XMM8-15 STAGED   : $XMM slot(s) touched in rtcc_init.c  <- charter claims XMM8-15 as VM globals"
[ "$XMM" -eq 0 ] && echo "                   (0 = never staged; no rung stands behind the charter's XMM claim)"
RNG=$(grep -c "rt_gc_root_range_add" "$INIT")
PIN=$(grep -c "rt_gc_root_pin_add" "$INIT")
echo "GC COVERAGE      : pin_add=$PIN range_add=$RNG"
# SELF-ARMING: the gap is LATENT while no claimed register can hold a heap DESCR (at HEAD: r8=&ANCHOR int,
# r9=mmap'd GVA island, r10/r11=code addresses).  It becomes a LIVE use-after-free the moment the ARG TIER
# is claimed, because RAX:RDX carry DESCR_t returns.  So: WARN now, FAIL automatically the instant a claim
# arrives -- the tripwire arms itself and no future session has to remember this analysis.
ARGCLAIM=0
for r in rax rcx rdx rsi rdi; do n=$(printf '%s' " $round " | grep -c " $r "); [ "$n" -gt 0 ] && ARGCLAIM=1; done
if [ "$RNG" -eq 0 ]; then
    echo "   pin_add(p) pins the POINTER VALUE p (gc_heap.c:625 rt_gc_pin_ptr); only range_add reaches gc_cons_scan."
    echo "   Every other block in the tree registers BOTH (zeta_heap.c:161, rt_coexpr.c:74).  The block's 32 slots"
    echo "   are therefore scanned by NOTHING, so rtcc_init.c's \"registering it is sufficient\" does not hold."
    if [ "$ARGCLAIM" -ne 0 ]; then
        echo "⛔ GC GAP IS LIVE: an ARG-TIER register is claimed and RAX:RDX carry DESCR_t returns — a heap object"
        echo "   reachable only from a claimed register is invisible to the collector.  USE-AFTER-FREE.  Fix"
        echo "   rtcc_gc_register with rt_gc_root_range_add over the claimed slots BEFORE landing this claim."
        FAIL=1
    else
        echo "⚠  LATENT ONLY: no claimed register can currently hold a heap DESCR, so this is not a live bug at HEAD."
        echo "   This gate ARMS ITSELF: it turns FAIL automatically the moment an arg-tier register joins ROUND-TRIP."
        echo "   ⛔ RC-7 must not certify DoD line 1 while this stands, and the arg-tier rung is BLOCKED behind it."
    fi
fi
echo
echo "SUMMARY: $nround of 9 GPRs round-trip; $nwbonly written-but-never-reloaded; XMM tier $( [ "$XMM" -eq 0 ] && echo ABSENT || echo present )."
if [ "$nwbonly" -gt 0 ]; then
    echo "NOTE: each writeback-only register costs ONE instruction on EVERY crossing and is read by nothing."
    echo "      rtcc_load_all() is NOT a per-crossing reload — its only two call sites (src/driver/scrip.c) are the"
    echo "      process-entry crossing, so it reads the block ONCE, before any generated code has run."
fi
if [ "$FAIL" -ne 0 ]; then echo; echo "GATE: FAIL"; exit 1; fi
echo; echo "GATE: PASS"
exit 0
