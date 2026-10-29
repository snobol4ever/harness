#!/usr/bin/env bash
# test_gate_gc_the_scan_subject_base_is_reloaded_after_a_call_inside_a_scan.sh -- A CALL MADE INSIDE A SCAN BODY HANDS
# THE SUBJECT BASE BACK FROM THE COLLECTOR'S OWN ROOT, NOT FROM THE REGISTER THE CALLEE LEFT ALONE (cto 2026-09-24,
# CTO-165; row icon-gc-procedure-record-scan-replace-2-goes-crash-to-diff-across-fa1dc84a5-...; law RULES.md FACT RULE
# THE COLLECTOR GUESSES NOTHING, CEO-812; hq_icon's 15-line witness, FINDING-2026-09-24-hq_icon-htprep-stale-scan-subject).
#
# MEASURED 2026-09-24 on SCRIP 8b6cb3607: the Icon rungs entry procedure_record_scan_replace_2 (htprep) reads its ref at
# stress 0 and prints NUL-filled garbage where scanned text belongs at stress 5 under forced relocation, differently on
# every run.  Under the flip plant the fault is located: the inline cset test of upto in braces (movzx esi, byte ptr
# [r13+rcx]) reads a 64-byte HB_WSB string block (the line trim(read()) returned, the scan subject) 20 bytes in, at the
# address it had BEFORE the collection newtag's tab(many(&letters)) caused MOVED it.  The emitted call successor inside a
# scan body carried the POSITION back through rt_scan_sync_in (scan_pos is runtime state the collector roots) but left
# r13, the subject base, to the callee-saved convention: the callee never touched r13, no frame slot held it during the
# collection, and the collector guesses nothing about a C-saved register -- so the caller resumed on the old ground.
#
# THE CURE (x86_asm.h, x86_scan_sigma_reload, emitted by both scan sync-in helpers when the scan registers are live):
# after the position, r13 is reloaded from rt_scan_live_subj, the runtime's scan_subj, which gen_gc_roots roots and the
# collector relocates -- the same road the position already travelled.  The emitter carries NO switch that leaves the reload
# out: SCRIP_GC_PLANT_STALE_SIGMA was deleted under CEO-1680 (Lon: "Do not add broken code just to enable a test ... Just
# create a proper test instead."; hq_templates 2026-10-15, row templates-the-stale-sigma-plant-seam-leaves-the-emitter-...).
#
# ARMS: (a) THE PROPERTY: the witness answers its iconx-cut ref at the shipped 128 KB window in mode 3 at stress 3 and 11
# and in mode 4 at stress 4, 8 and 16 (the levels hq_icon measured as the diverging ones), and under the flip plant at
# stress 3 (mode 3) and 4 (mode 4), stdin fed from its .in; (b) FORCED DISPLACEMENT: under SCRIP_GC_PLANT_FLIP=1 (the
# collector's own instrument, which moves every survivor by construction) the witness answers its ref at mode-3 stress 1..8,
# so the subject the callee's collection moved is read from where it went; (c) the source carries the reload in both sync-in
# helpers and the emitter reads no SCRIP_GC_PLANT_STALE_SIGMA. FAIL_ONCE=1 grades arms (a) and (b) against a CORRUPTED copy of
# the iconx-cut ref and requires both to red -- the proper test CEO-1680 names: the comparison that carries the claim is seen
# to say no.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
WD="$ROOT/../harness/scripts/gc_witnesses"; W="$WD/hb_scan_subject_across_a_failing_callee"
[ -s "$W.icn" ] && [ -s "$W.in" ] && [ -s "$W.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: witness, .in or .ref missing under gc_witnesses"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; REF="$W.ref"
if [ "${FAIL_ONCE:-0}" = 1 ]; then REF="$T/corrupted.ref"; { cat "$W.ref"; echo "FAIL_ONCE: a line iconx never printed"; } > "$REF"; echo "  FAIL_ONCE: arms (a) and (b) grade against a corrupted ref"; fi
band=""; bad=0
flipped() { local err="$1" fl="$2"; [ -z "$fl" ] && return 0; grep -q "^\[GC-FLIP\] plant:" "$err"; }
run3() { local st="$1" fl="$2" tag="$3"; ( cd "$T" && env -u SCRIP_HEAP_MB $fl SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=$st timeout -k 5 60s "$SCRIP" --run "$W.icn" < "$W.in" > "$tag.out" 2> "$tag.err" ); local r=$?
  if [ $r = 0 ] && cmp -s "$T/$tag.out" "$REF" && flipped "$T/$tag.err" "$fl"; then band="$band $tag:ref"; else band="$band $tag:rc=$r"; bad=1; fi; }
for st in 3 11; do run3 $st "" "m3_s$st"; done
run3 3 "SCRIP_GC_PLANT_FLIP=1" "m3_f3"
if ( cd "$T" && "$SCRIP" --compile "$W.icn" --out=w.s </dev/null >/dev/null 2>w4.err && gcc -m64 -no-pie -rdynamic w.s -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o w4 2>/dev/null ); then
  run4() { local st="$1" fl="$2" tag="$3"; ( cd "$T" && env -u SCRIP_HEAP_MB $fl SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=$st timeout -k 5 60s ./w4 < "$W.in" > "$tag.out" 2> "$tag.err" ); local r=$?
    if [ $r = 0 ] && cmp -s "$T/$tag.out" "$REF" && flipped "$T/$tag.err" "$fl"; then band="$band $tag:ref"; else band="$band $tag:rc=$r"; bad=1; fi; }
  for st in 4 8 16; do run4 $st "" "m4_s$st"; done
  run4 4 "SCRIP_GC_PLANT_FLIP=1" "m4_f4"
else echo "  FAIL (a) the mode-4 witness did not build"; RC=1; fi
if [ "$bad" = 0 ]; then echo "  ok   (a) THE PROPERTY: the scan witness answers its iconx ref after a failing callee's collection at the shipped window, both modes, and under the flip plant --$band"
else echo "  FAIL (a) the subject base read after a call inside a scan is stale --$band"; RC=1; fi
cband=""; chit=0; cdecl=0
for pst in 1 2 3 4 5 6 7 8; do
  ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_GC_PLANT_FLIP=1 SCRIP_HEAP_KB=512 SCRIP_GC_STRESS=$pst timeout -k 5 60s "$SCRIP" --run "$W.icn" < "$W.in" > c$pst.out 2> c$pst.err ); cr=$?
  grep -q "^\[GC-SHIFT\] plant DECLINED" "$T/c$pst.err" && cdecl=$((cdecl+1))
  if [ $cr != 0 ] || ! cmp -s "$T/c$pst.out" "$REF"; then cband="$cband s$pst:LOSS"; chit=$((chit+1)); else cband="$cband s$pst:ref"; fi
done
[ $cdecl -gt 0 ] && { echo "⛔ GATE REFUSE(2) [$G]: the shift plant DECLINED at $cdecl of 8 points (no arena headroom), so arm (b) could not force the displacement -- CANNOT MEASURE is not a red"; exit 2; }
if [ $chit -eq 0 ]; then echo "  ok   (b) FORCED DISPLACEMENT: under SCRIP_GC_PLANT_FLIP=1 the witness answers its ref at all 8 stress points --$cband -- the subject the callee's collection moved is read where it went"
else echo "  FAIL (b) under forced displacement the witness loses at $chit of 8 points ($cband) -- the subject base read after a call inside a scan is stale"; RC=1; fi
# RE-CUT 2026-10-25 (hq_icon, ARCH-ICON-RTX 10 R6, the cfo's small roll-out): the sync-in helpers and x86_scan_sigma_reload are deleted -- in a scan_regs
# graph EVERY poll spills {DT_S, r15d, r13} as one described cell and reloads r13 from it, so the source fact is that poll shape, gated on the graph fact.
n=$(grep -c 'x86_rsp_load64("r13", 8)' "$ROOT/src/templates/x86/x86_asm.h")
if [ "$n" -ge 2 ] && grep -q 'x86_scan_regs_graph() ? x86_rt_gc_poll_scan_regs()' "$ROOT/src/templates/x86/x86_asm.h" && ! grep -rq 'SCRIP_GC_PLANT_STALE_SIGMA' "$ROOT/src"; then echo "  ok   (c) every poll of a scan_regs graph spills the subject pair as a described cell and reloads r13 from it (x86_rt_gc_poll_scan_regs and the result poll)"
else echo "  FAIL (c) the scan_regs poll no longer reloads r13 from its described cell in x86_asm.h ($n reloads)"; RC=1; fi
echo "population: 3 arm(s) graded"
if [ $RC = 0 ]; then echo "✅ GATE PASS(0) [$G]: a call inside a scan body hands the subject base back from the collector's root, and forced displacement cannot make it read the old ground"; else echo "⛔ GATE FAIL(1) [$G]: the scan subject base is stale after a call inside a scan, or forced displacement loses it"; fi
exit $RC
