#!/usr/bin/env bash
# stale-binary preflight
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_rbx_is_the_frontier.sh -- row gc-rbx-is-the-bump-frontier-every-scratch-use-is-retargeted-and-every-save-
# becomes-a-reload (cto 2026-09-20; ceo CEO-959/974; Lon 2026-09-19, in-chat to the ceo: "RBX was always meant to be the
# GC bump frontier. If it is not so, make it so.").
#
# WHAT DRIFTED, AND WHY NO INSTRUMENT NOTICED.  ARCH-SNOBOL4-RTX.md section 2, which ARCH-ICON-RTX.md names as THE single
# source for the blob pins, reads rbx = arena heap top, DESCR mint pointer, under a heading requiring RTX to preserve
# every pin across every entry and exit.  The frontier lived in the HEAP arm of the ZC_PORT_* selector; FORTH was the
# live protocol and HEAP was kept granted-but-broken; when the no-modes law deleted the ZC_* arms the HEAP arm's register
# plane went with them, and rbx -- preserved by SysV and therefore free-looking -- was picked up as scratch by four
# emitted sites.  Nobody decided that.  NOTHING COULD FAIL, because a register plane written in a table and enforced
# nowhere has no failure mode.  r9 held the same years without drifting, and the only mechanical difference is the
# RTCC_GVA_REG _Static_assert in x86_asm.h.  This gate is that difference, for the six pins.
#
# ⛔ WHAT THIS GATE WILL NEVER GRADE, AND THE WORD THAT SETTLED IT.  The row's step 2 flipped rbx to a CACHE of
# g_hp_fr.top -- written back before a call that can allocate, reloaded after, never restored from a save -- and the two
# arms that would grade THAT design are not here: the emitted .s advancing rbx with no per-allocation GOT load, and the
# round trip (allocate, collect inside a C-to-BB entry, allocate again) with a planted RESTORE-instead-of-RELOAD seam
# proven red.  THE FIRST REASON IS A MEASUREMENT, not an omission: emitted code never calls the allocator.  Zero mentions
# of rt_gcheap_alloc, rt_ws_alloc, rt_heap_alloc, rt_pm_struct_alloc or rt_agg_alloc in src/templates or src/emitter; the
# safe-point census reads 244 allocating call sites in emitted code and every one is a call into a runtime entry that
# allocates internally (1655 of 8645 runtime functions reach rt_gcheap_alloc), and the GOT load the row wants gone lives
# in rtx_alloc.s 7/46/60 and rtx_str.s 100 -- inside the runtime.  So a cache with no consumer cannot be graded by reading
# the emitted .s, and the flip needed a new emitted allocation shape first.
#
# ⛔ THE SECOND REASON IS LON'S WORD, AND IT IS WHY THESE TWO ARMS ARE RETIRED RATHER THAN PENDING.  That allocation
# shape was cut on a branch, disassembled, and RETIRED IN CHAT 2026-09-20 (CEO-1007, CTO-98), verbatim: "So forget the
# inline GC bump.  It is just too long."  The measurement he ruled on, one concat site of bench_icnstr_concat_table.icn
# in mode 4: 15 -> 86 emitted instructions, +302 object text bytes per site, THE BUMP ALONE 27 against a ceiling of 6 --
# 13 after every fold that actually exists, and 8 irreducible (header write, top commit, block count, bound check) before
# any guard.  4-6 needs pre-formatted size-class runs, which is a different collector.  The code is on tag
# retired/cto-rbx-rung1-2026-09-20 (SCRIP 1815dc8b8) and NOTHING of it is on main.  THIS GATE'S POPULATION IS THEREFORE
# FINAL AT FOUR ARMS: whoever revives an advancing rbx must first revive an emitted allocation shape and argue against
# that arithmetic, and the two arms land with THAT, not with this row.
#
# THE ARMS.  (1) THE SCRATCH CENSUS, which is what step 1 earned and what this gate keeps: every spelling of rbx in
# src/templates and src/emitter is in the DECLARED set below, each entry named with its reason.  A sixth occurrence --
# the exact shape of the drift -- reds.  (2) THE PLANE IS DECLARED IN CODE: one _Static_assert per pin in x86_asm.h,
# in the RTCC_GVA_REG shape, naming the register the encoders use.  (3) the aligned-call saver uses no callee-saved
# register at all: the shared helpers park the caller's rsp on the aligned stack, and no template spells the old
# push-rbx form.  (4) FAIL_ONCE=1 plants a sixth rbx spelling into arm 1's population and requires this gate to red.
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
RC=0; examined=0
echo "  HOLDS: rbx carries no scratch in any emitted template, the six blob pins are declared in code rather than only on a page, and the aligned-call saver needs no callee-saved register"
examined=$((examined + 1))
DECLARED="src/templates/bb/bb_glue_flat.cpp:x86_rsp_store64(48, \"rbx\")
src/templates/bb/bb_glue_flat.cpp:x86_rsp_load64(\"rbx\", 48)
src/templates/bb/bb_create.cpp:CR_REG"
found=$( { grep -rn '"rbx"' "$ROOT/src/templates" "$ROOT/src/emitter" --include=*.cpp --include=*.h 2>/dev/null | grep -v 'x86("comment"' | grep -v 'PIN_FRONTIER_REG' | grep -v 'x86_rtcc_streq' | grep -v '"ebx"' | grep -v 'static const char \* regs\[\]' | grep -v '!strcmp(r, "rbx")'; } | sed "s|$ROOT/||")
[ "${FAIL_ONCE:-0}" = 1 ] && found="$found
src/templates/bb/bb_planted_by_fail_once.cpp:42:         + x86(\"mov\", \"rbx\", \"rax\")"
n_found=$(printf '%s\n' "$found" | grep -c . )
ok=1
while IFS= read -r ln; do
    [ -n "$ln" ] || continue
    f=${ln%%:*}; rest=${ln#*:}; rest=${rest#*:}
    hit=0
    while IFS= read -r d; do
        [ -n "$d" ] || continue
        df=${d%%:*}; dt=${d#*:}
        case "$f" in "$df") case "$rest" in *"$dt"*) hit=1 ;; esac ;; esac
        [ "$f" = "$df" ] && [ "$dt" = "CR_REG" ] && case "$rest" in *"#define CR_REG"*) hit=1 ;; esac
    done <<< "$DECLARED"
    [ "$hit" = 1 ] || { echo "  arm 1 RED: an rbx spelling outside the declared set -- $ln"; ok=0; }
done <<< "$found"
if [ "$ok" = 1 ] && [ "$n_found" -le 3 ]; then echo "  arm 1 PASS: $n_found rbx spelling(s) in src/templates and src/emitter, every one in the declared set (the glue's save and restore, which the flip converts to a reload, and the box contract set, whose slot a coexpression keeps) -- zero scratch uses, where step 1 found four sites and a fifth that was dead code"
else echo "  arm 1 FAIL: $n_found spelling(s), declared set is 3"; RC=1; fi
examined=$((examined + 1))
H="$ROOT/src/templates/x86/x86_asm.h"; miss=""
for pr in 'PIN_FRONTIER_REG:rbx' 'PIN_CAS_TOP_REG:r12' 'PIN_SIGMA_REG:r13' 'PIN_CURSOR_REG:r14' 'PIN_SUBJLEN_REG:r15' 'RTCC_GVA_REG:r9'; do
    c=${pr%%:*}; r=${pr#*:}
    grep -q "static_assert(x86_rtcc_streq($c, \"$r\")" "$H" || miss="$miss $c"
done
if [ -z "$miss" ]; then echo "  arm 2 PASS: all six pinned registers carry a _Static_assert naming them in x86_asm.h (rbx r12 r13 r14 r15 r9) -- a rename now fails a build instead of a page"
else echo "  arm 2 FAIL: no assert for:$miss"; RC=1; fi
examined=$((examined + 1))
oldform=$(grep -rn 'x86("push", "rbx")' "$ROOT/src/templates" "$ROOT/src/emitter" --include=*.cpp 2>/dev/null | wc -l)
helpers=$(grep -c 'x86_align_call_enter()\|x86_align_call_leave()' "$H")
users=$(grep -rn 'x86_align_call_enter()' "$ROOT/src/templates" "$ROOT/src/emitter" --include=*.cpp 2>/dev/null | wc -l)
if [ "$oldform" = 0 ] && [ "$helpers" -ge 2 ] && [ "$users" -ge 4 ]; then echo "  arm 3 PASS: no template spells the push-rbx saver ($oldform), and $users site(s) take the shared helpers that park the caller's rsp on the aligned stack instead"
else echo "  arm 3 FAIL: push-rbx spellings=$oldform helper definitions=$helpers users=$users"; RC=1; fi
examined=$((examined + 1))
if [ "${FAIL_ONCE:-0}" = 1 ]; then
    if [ "$RC" = 1 ]; then echo "  arm 4 PASS: FAIL_ONCE=1 planted a sixth rbx spelling and this gate reads red"; else echo "  arm 4 FAIL: the plant went unseen"; RC=1; fi
else echo "  arm 4 PASS: FAIL_ONCE=1 plants a scratch rbx spelling into arm 1's population (run with FAIL_ONCE=1 to see it trip)"; fi
if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: rbx carries no scratch, the six pins are declared in code, and the aligned-call saver needs no callee-saved register (examined $examined arms; the two flip arms are RETIRED with the emitted allocation shape Lon killed in chat 2026-09-20, so this population is final)"
else echo "GATE FAIL(1) [$G]: the register plane is not held (examined $examined arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
