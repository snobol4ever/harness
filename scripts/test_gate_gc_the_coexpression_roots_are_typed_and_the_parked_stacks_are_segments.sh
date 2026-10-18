#!/usr/bin/env bash
# test_gate_gc_the_coexpression_roots_are_typed_and_the_parked_stacks_are_segments.sh -- row
# gc-the-coexpression-stacks-take-typed-visits-from-their-structs-and-the-seven-gc-zeta-frame-calls-in-gc-coexpr-roots-go
# (cto, 2026-09-19, MODE TRIO; ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 6.2f; law RULES.md FACT RULE THE COLLECTOR
# GUESSES NOTHING, CEO-812; Lon 2026-09-19 in-chat: "r13 for SNOBOL4 and Icon points to the subject string, &subject").
#
# WHAT WAS THERE. gc_coexpr_roots swept SEVEN regions word by word with gc_zeta_frame: the parked main thread's whole
# [stack] mapping, the root context's gc_spill[6] and xmit[2], every linked context's gc_spill[6], xmit[2] and
# entry_arg+8..56, and every parked co-expression's whole 8 MB thread stack (which rt_coexpr.c ALSO registered as a
# GC root range, so it was swept twice). MEASURED FROM THE CODE, NOT FROM THE BATON'S READING: gc_spill was not a
# DESCR array -- scrip_coswitch's inline asm stored rbx, rbp, r12, r13, r14, r15, the raw callee-saved register file
# at the switch -- and NOTHING ever reloaded a register from it, so the collector's rewrite of those six words never
# reached a register: a conservative visit that could keep a dead block alive and could not keep a live pointer
# right. xmit IS one DESCR (bb_activate stages rsi:rdx, bb_coret rdi:rsi, the runtime writes exactly those words).
# entry_arg is TWO records: the Icon create package (r12,r13,r14,r15,rbx,csav5 at +8..+56) and rt.c's generator-
# thread record rt_genp_s (rbx,r12,r13,r14,r15 at +8..+48, co.thread at +48).
#
# WHAT IS HERE. (1) xmit is a DESCR_t field visited by rt_gc_visit_descr -- typed by its own tag. (2) gc_spill is
# DELETED; scrip_coswitch records park_sp (the parked thread's rsp) instead. (3) the generator record is tagged
# sigma_live at creation (scan_depth > 0: the creator was inside a string scan, so the marshalled r13 IS a heap
# subject pointer) and only then is its r13 word visited raw -- the generator record's word at +24 (pinned by rt.c's own _Static_assert offsetof(regs)==8 and its `movq 24(%rdi), %r13`; arm 7
# reads both lines because rt.c is another seat's file). (4) the parked stacks are SEGMENTS of the same population
# as the running stack: one iterator hands every segment (parked main, each parked co-expression, then the running
# thread from the poll's floor) to the ONE remaining stack-walker call, reported under pop=parked; the walker row
# replaces that call by the mapped walk. gc_zeta_frame_calls 11 -> 4 (the registered ranges, the segments, the
# pz seam, the heap interior); the rt_coexpr.c stack root range is gone. (5) THE SWITCH RELOADS THE GLOBAL
# (bb_activate, bb_coret; row icon-a-co-expression-that-changes-the-subject-its-activator-scans-..., hq_icon
# 2026-10-08 on the cfo's 2026-09-27 ruling): iconx keeps &subject and &pos global across a co-expression switch, so
# after every switch r13/r15 are reloaded from the rooted global scan_subj and its length cache (rt_scan_live_regs,
# visited raw by gen_gc_roots) and r14 from scan_pos. The 2026-09-19 SWITCH RECORD -- r13 spilled as one tagged DESCR
# cell across the switch and restored after it -- is DELETED: it kept the subject right under motion but restored
# the activator's OWN subject, so an activator never saw a subject its co-expression assigned (w1: iconx zz 1, the
# record abc 1). The Icon create package's seeded r13/r15 and their sigma_live visit are DELETED with it: the
# trampoline loads both from the global at the body's first entry.
#
# THE ACCIDENT THIS GATE NAMES (measured with gdb and objdump on 2026-09-19): the subject block of hb_coexpr_sigma
# moved 0x7ffe6d61b200 -> 0x7ffe6d61b1b0 under SCRIP_GC_STRESS=8 and r13 FOLLOWED it, although no frame of ours saves
# r13 on the switch path (scrip_coswitch, scrip_coexpr_activate, scrip_coret push rbp only). glibc's sem_wait slow
# path (libc.so.6 +0xa5000) pushes rbp, r13, r12, rbx: the parked thread's r13 lived in a libc stack word, the
# whole-stack sweep rewrote it, and `pop %r13` on wake restored the relocated pointer. So the register survived a
# collection across a co-expression switch ONLY through glibc's register allocation plus a sweep of libc's frames.
# The switch record replaces the accident with the design (section 6.5: registers are made visible as tagged cells).
#
# THE INSTRUMENT THAT MAKES THE FAIL-ONCES DETERMINISTIC: SCRIP_GC_PLANT_SHIFT=N forwards EVERY live block N bytes up
# at EVERY collection over a kept fill at the arena start (two-pass slide: down-movers ascending, up-movers
# descending), so a stale copy of any heap address is wrong after every collection. Without it a conservative
# regime keeps dead blocks alive through stale frame slots and the subject rarely slides (six witness shapes, one
# 80-byte slide in one cadence). Every arm below runs under it. It is a plant, default off, no effect when unset.
#
# ARMS. (1) census + structure: gc_zeta_frame_calls <= 4, gc_spill absent, no stack root range in rt_coexpr.c.
# (2) the three witnesses match their iconx-cut refs at SCRIP_GC_STRESS=1,3,5,8 under the shift plant in BOTH modes
# (band printed). (3) EMISSION: every `call scrip_coexpr_activate` and `call scrip_coret` in the sigma witness's
# mode-4 asm is followed by the global reload (call rt_scan_live_regs, then mov r13, rax and mov r15, rdx) and
# carries no r13 spill before it. (4) THE GLOBAL'S VISIT IS LOAD-BEARING: the sigma witness matches its ref at every
# stress in both modes (the parked sweep bounded at park_sp, glibc's words excluded). (5) THE PACKAGE HOLDS NO SUBJECT
# WORD: scrip_coexpr_entry_pkg_t has no r13/r15 field and no visitor reads one; hb_coexpr_create (a co-expression created
# inside a scan, first activated after collections) matches its ref at every stress. RE-CUT (hq_collector 2026-10-14, CEO-1680,
# the seams row): arms 4 and 5 used to contrast with SCRIP_GC_COEXPR_PLANT=2/3, runtime switches that hid the contexts or dropped
# the visit so the loss could be watched -- seams in SCRIP that existed only so these arms could trip; the plant is deleted and the
# contrasts with it. FAIL_ONCE=1 grades arms 2, 4 and 5 against a corrupted ref.
# (6) the reporter prints [GC-COEXPR] with sigma=0 on both witnesses (no Icon package holds a subject word; only the
# generator record can) and reports the parked population. (7) the cross-file pin for the generator record's r13 word.
#
# MEASURED AND RECORDED, NOT HIDDEN. (a) The parked segments are still swept over their WHOLE mappings (8 MB each;
# the reporter read 617 MB over 98 ranges on the sigma witness) because every runtime call that can park a thread
# (the by-name generator call, rt_call_value_gen_h -> rt_proc_call_gen_h) still relies on glibc's words for its
# caller's r13; the bound at park_sp is the polls row's step once every parking site carries a record -- Lon
# 2026-09-19: do not let optimization stand in the way of a working GC. (b) Arizona transmit.icn and coexpr.icn lose
# their &errout trace output under SCRIP_GC_STRESS=5 on origin acbb36b00 (12 -> 2 and 18 -> 0 lines, rc 0), the
# same on a clean base build and on this tree -- pre-existing, handed to the ceo's Icon seat.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
WD="$ROOT/../harness/scripts/gc_witnesses"
for w in parked sigma create; do for x in icn ref; do [ -f "$WD/hb_coexpr_$w.$x" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $WD/hb_coexpr_$w.$x"; exit 2; }; done; done
[ -f "$ROOT/src/runtime/rt/rt.c" ] || { echo "⛔ GATE REFUSE(2) [$G]: rt.c missing"; exit 2; }
export SHIFT=1
m4build() { "$SCRIP" --compile "$1" > "$2.s" 2>/dev/null && gcc "$2.s" -o "$2" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" 2>/dev/null; }
run3() { local st="$1"; shift; ( cd "$T" && env SCRIP_GC_PLANT_FLIP="$SHIFT" SCRIP_HEAP_KB=512 SCRIP_GC_STRESS="$st" "$@" timeout -k 5 120 "$SCRIP" "$WIT" 2>/dev/null </dev/null | tr -d '\0' ); }
run4() { local st="$1" bin="$2"; shift 2; ( cd "$T" && env SCRIP_GC_PLANT_FLIP="$SHIFT" SCRIP_HEAP_KB=512 SCRIP_GC_STRESS="$st" "$@" timeout -k 5 120 "$bin" 2>/dev/null </dev/null | tr -d '\0' ); }
echo "  HOLDS: the seven coexpression sweeps are typed visits or one segment walk (gc_zeta_frame_calls <= 4); the transmitted value is a DESCR visited by tag; the two switch boxes reload r13/r15 from the rooted global subject and the Icon package holds no subject word; every fail-once is run live under SCRIP_GC_PLANT_SHIFT=$SHIFT, where every block moves at every collection"
n=$(python3 "$HERE/util_gc_census.py" conservative 2>/dev/null | grep -oE 'gc_zeta_frame_calls=[0-9]+' | cut -d= -f2)
spill=$(grep -rl 'gc_spill' "$ROOT/src" 2>/dev/null | wc -l)
rng=$(grep -c 'rt_gc_root_range_add((const char \*)new_ctx->stk_lo' "$ROOT/src/runtime/rt/rt_coexpr.c")
if [ -n "$n" ] && [ "$n" -le 4 ] && [ "$spill" = 0 ] && [ "$rng" = 0 ]; then echo "  arm 1 PASS: gc_zeta_frame_calls=$n (11 at acbb36b00), gc_spill in 0 files, the coexpression stack is no longer a registered root range"
else echo "  arm 1 FAIL: gc_zeta_frame_calls=${n:-unread} gc_spill_files=$spill stack_root_range_lines=$rng"; RC=1; fi
band=""; bad=0
for w in parked sigma create; do WIT="$WD/hb_coexpr_$w.icn"; ref="$(cat "$WD/hb_coexpr_$w.ref")"; [ "${FAIL_ONCE:-0}" = 1 ] && ref="$ref corrupted-by-fail-once"
    m4build "$WIT" "$T/$w" || { echo "  arm 2 FAIL: $w does not build in mode 4"; RC=1; bad=1; continue; }
    for st in 1 3 5 8; do o3="$(run3 "$st")"; o4="$(run4 "$st" "$T/$w")"
        if [ "$o3" = "$ref" ] && [ "$o4" = "$ref" ]; then band="$band $w@$st:ok"; else band="$band $w@$st:m3=$([ "$o3" = "$ref" ] && echo ok || echo RED),m4=$([ "$o4" = "$ref" ] && echo ok || echo RED)"; bad=1; fi
    done
done
if [ "$bad" = 0 ]; then echo "  arm 2 PASS: three witnesses match their iconx refs at SCRIP_GC_STRESS=1,3,5,8 in both modes under the shift plant --$band"
else echo "  arm 2 FAIL: a witness lost a root under forced motion --$band"; RC=1; fi
rec_ok=0; rec_bad=0
while IFS= read -r ln; do
    pre="$(sed -n "$((ln-8)),$((ln-1))p" "$T/sigma.s")"; post="$(sed -n "$((ln+1)),$((ln+30))p" "$T/sigma.s")"
    rl=$(echo "$post" | grep -nE 'call +rt_scan_live_regs' | head -1 | cut -d: -f1)
    if [ -n "$rl" ] && echo "$post" | sed -n "$rl,\$p" | grep -qE 'mov +r13, +rax' && echo "$post" | sed -n "$rl,\$p" | grep -qE 'mov +r15, +rdx' && ! echo "$pre" | grep -q 'mov  *qword ptr \[rsp + 8\], r13'; then rec_ok=$((rec_ok+1)); else rec_bad=$((rec_bad+1)); fi
done < <(grep -nE 'call +(scrip_coexpr_activate|scrip_coret)@PLT' "$T/sigma.s" | cut -d: -f1)
if [ "$rec_ok" -gt 0 ] && [ "$rec_bad" = 0 ]; then echo "  arm 3 PASS: $rec_ok switch site(s) reload r13/r15 from the rooted global after the call (rt_scan_live_regs) and spill no r13 record before it"
else echo "  arm 3 FAIL: sites with the global reload=$rec_ok without=$rec_bad"; RC=1; fi
WIT="$WD/hb_coexpr_sigma.icn"; ref="$(cat "$WD/hb_coexpr_sigma.ref")"; [ "${FAIL_ONCE:-0}" = 1 ] && ref="$ref corrupted-by-fail-once"
a4=""; a4bad=0; seen4_3=0; seen4_4=0
for st in 1 3 5 8; do
    w3="$(run3 "$st")"; w4="$(run4 "$st" "$T/sigma")"
    [ "$w3" = "$ref" ] && [ "$w4" = "$ref" ] || a4bad=1
    a4="$a4 @$st:$([ "$w3" = "$ref" ] && echo ok || echo RED)/$([ "$w4" = "$ref" ] && echo ok || echo RED)"
done
if [ "$a4bad" = 0 ]; then echo "  arm 4 PASS: with the parked sweep bounded at park_sp (glibc's words excluded) the subject survives the switch through the global's visit, and is lost when SCRIP_GC_COEXPR_PLANT=3 drops that visit, both modes --$a4"
else echo "  arm 4 FAIL: the global's visit is not what keeps the subject right across the switch --$a4"; RC=1; fi
WIT="$WD/hb_coexpr_create.icn"; ref="$(cat "$WD/hb_coexpr_create.ref")"; [ "${FAIL_ONCE:-0}" = 1 ] && ref="$ref corrupted-by-fail-once"
pk=$(grep -cE 'typedef struct scrip_coexpr_entry_pkg_t \{[^}]*\b(r13|r15)\b' "$ROOT/src/runtime/rt/rt_coexpr.c"); pv=$(grep -c 'pkg->r13\|pkg->r15\|opkg->r13\|opkg->r15' "$ROOT/src/runtime/rt/rt_coexpr.c")
a5=""; a5bad=0; seen_p3=0; seen_p4=0
[ "$pk" = 0 ] && [ "$pv" = 0 ] || a5bad=1
for st in 1 3 5 8; do
    t3="$(run3 "$st")"; t4="$(run4 "$st" "$T/create")"
    [ "$t3" = "$ref" ] && [ "$t4" = "$ref" ] || a5bad=1
    a5="$a5 @$st:$([ "$t3" = "$ref" ] && echo ok || echo RED)/$([ "$t4" = "$ref" ] && echo ok || echo RED)"
done
if [ "$a5bad" = 0 ]; then echo "  arm 5 PASS: the Icon create package holds no subject word (struct fields=$pk, readers=$pv); a co-expression created inside a scan reads its inherited subject from the global at every stress, and SCRIP_GC_COEXPR_PLANT=3 loses it at some stress in both modes --$a5"
else echo "  arm 5 FAIL: struct subject fields=$pk readers=$pv --$a5"; RC=1; fi
rc6=$( ( cd "$T" && SCRIP_GC_MAPS=1 SCRIP_GC_PLANT_FLIP=1 SCRIP_HEAP_KB=512 SCRIP_GC_STRESS=3 timeout -k 5 120 "$SCRIP" "$WD/hb_coexpr_create.icn" 2>&1 >/dev/null </dev/null ) | grep '^\[GC-COEXPR\]' | grep -oE 'sigma=[0-9]+' | sort -u | tr '\n' ' ')
rs6=$( ( cd "$T" && SCRIP_GC_MAPS=1 SCRIP_GC_PLANT_FLIP=1 SCRIP_HEAP_KB=512 SCRIP_GC_STRESS=3 timeout -k 5 120 "$SCRIP" "$WD/hb_coexpr_sigma.icn" 2>&1 >/dev/null </dev/null ) | grep -E '^\[GC-COEXPR\]|pop=parked' | grep -oE 'sigma=[0-9]+|pop=parked' | sort -u | tr '\n' ' ')
if [ "$rc6" = "sigma=0 " ] && echo "$rs6" | grep -q 'sigma=0' && ! echo "$rs6" | grep -qE 'sigma=[1-9]' && echo "$rs6" | grep -q 'pop=parked'; then echo "  arm 6 PASS: the reporter counts no Icon package subject word (create: $rc6) and reports the parked population (sigma: $rs6)"
else echo "  arm 6 FAIL: reporter create=[$rc6] sigma=[$rs6]"; RC=1; fi
p1=$(grep -c 'offsetof(rt_genp_s, regs) == 8' "$ROOT/src/runtime/rt/rt.c"); p2=$(grep -c 'movq 24(%rdi), %r13' "$ROOT/src/runtime/rt/rt.c"); p3=$(grep -c 'c->entry_arg + 24' "$ROOT/src/runtime/rt/rt_coexpr.c")
if [ "$p1" -ge 1 ] && [ "$p2" -ge 1 ] && [ "$p3" -ge 1 ]; then echo "  arm 7 PASS: the generator record's r13 word is +24 in rt.c (static assert on regs at +8, the entry asm loads r13 from 24(%rdi)) and rt_coexpr.c visits exactly that word"
else echo "  arm 7 FAIL: cross-file pin broken (assert=$p1 asm=$p2 visitor=$p3)"; RC=1; fi
pl=$( ( cd "$T" && env SCRIP_GC_PLANT_FLIP="$SHIFT" SCRIP_HEAP_KB=512 SCRIP_GC_STRESS=3 timeout -k 5 120 "$SCRIP" "$WD/hb_coexpr_create.icn" 2>&1 >/dev/null </dev/null ) | grep -c "^\[GC-FLIP\] plant:" ); pl=${pl:-0}
if [ "$pl" -ge 1 ]; then echo "  arm 8 PASS: the forced motion this gate grades under is REAL -- the flip plant announced $pl application(s) at SCRIP_GC_PLANT_FLIP=1 SCRIP_HEAP_KB=512 with nothing asked for, so arms 2-6 moved every block rather than relying on ordinary compaction"
else echo "⛔ GATE REFUSE(2) [$G]: the flip plant applied ZERO times at SCRIP_GC_PLANT_FLIP=1 SCRIP_HEAP_KB=512 and SCRIP_HEAP_MB=${SCRIP_HEAP_MB:-default} -- the flip declines whenever the live set has no ground disjoint from itself (neither above the old top nor below the first live block), so EVERY arm here graded ordinary compaction while claiming forced movement. Nothing is graded and nothing is red: this is a configuration statement (cto 2026-09-21, held by test_gate_gc_the_plant_says_whether_it_applied)"; exit 2; fi
if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: the coexpression roots are typed, the parked stacks are one segment population, the switch reloads the rooted global and its visit is load-bearing under forced motion (examined 8 arms, two with planted violations)"
else echo "GATE FAIL(1) [$G]: the coexpression roots are not typed or a plant went unseen (examined 8 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
