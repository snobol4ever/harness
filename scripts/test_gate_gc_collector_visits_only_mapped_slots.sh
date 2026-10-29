#!/usr/bin/env bash
# test_gate_gc_collector_visits_only_mapped_slots.sh -- THE E SWITCH: row
# gc-the-collector-walks-the-rbp-chain-keyed-by-return-pc-visits-only-mapped-slots-and-coexpression-stacks-are-mapped-frames
# (cto, 2026-09-19, MODE QUARTET, CTO-90; ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 0 items 1, 2 and 7, section 2b;
# law RULES.md FACT RULE THE COLLECTOR GUESSES NOTHING, CEO-812; Lon 2026-09-19 in-chat: "Get those 10 down to zero in
# two turns").
#
# WHAT WAS THERE. gc_collect_ex swept every stack segment word by word with gc_zeta_frame: a raw arm that rewrote any
# word pointing into a heap block, a descriptor sniff, cons_stack, the pz seam sweep, and rt_cas_live_span's byte scan
# over the match span -- ten conservative sites at ba216c34f, counted by util_gc_census.py as `conservative total`.
# Every holder the collector could not name by type was found by value, which is exactly the guess the design forbids
# and the reason no instrument could tell a rooted program from a lucky one.
#
# WHAT IS HERE. gc_visit_segment walks every segment (the running thread from the poll's floor, the parked main thread,
# every parked co-expression) FRAME BY FRAME through the DT_MAP cells the emitter plants: each frame's interior is read
# by its sealed kind table (DESCR -> rt_gc_visit_descr, PTR_GC -> rt_gc_visit_raw, RAW and PTR_CODE never), the words
# between frames are read as DESCR cells BY THEIR TAG BYTE with the per-kind block checks the sniff carried (a
# C-built descriptor sets only the byte; emitted stores write 32 bits), a ROOT cell ends a segment only when no frame
# follows it (a co-expression thread carries the creator's frame image twice), and the registered ranges are typed
# (the Prolog trail by its entry layout, g_rtccb by a meter). The raw arm, the sniff, cons_stack, pz, the seam sweep and
# rt_cas_live_span are DELETED, not gated: conservative total 10 -> 0, coverage words_scanned 0.
#
# THE HOLDERS THE SWEEP HID, cured with the switch and each held by a witness below: the Prolog standing cells sat
# ABOVE the ROOT map cell (moved under it as tabled PTR_GC words); the findall accumulator handle was INTVAL(pointer);
# the spine cell reader refused C-built tags; rk_write and two multi-method roads handed heap-allocated argument
# arrays to by-name entries; g_redisp was unrooted; the DT_N arms dereferenced unchecked targets.
#
# ARMS. (1) CENSUS AND STRUCTURE: util_gc_census.py reads conservative total 0 and none of gc_zeta_frame, cons_stack,
# rt_cas_live_span, hb_scan_interior is named in gc_heap.c. (2) COVERAGE: a SNOBOL4 witness at SCRIP_GC_STRESS=1 under
# SCRIP_GC_COVERAGE=1 prints words_scanned=0 cas_scanned_bytes=0 interior_words=0 on EVERY collection, at least 50 of
# them. (3) THE WITNESS BATTERY, MODE 3: every ../harness/scripts/gc_witnesses/*.ref witness matches its oracle-cut ref at
# SCRIP_GC_STRESS=1 and 5 under SCRIP_HEAP_MB=1 SCRIP_HEAP_MAX_MB=512 SCRIP_GC_POISON=1 (band printed).
# (4) THE SAME IN MODE 4 at SCRIP_GC_STRESS=5. A witness that misses its ref at the SHIPPED arena with SCRIP_GC_STRESS=0
# is not a collector reading -- nothing forced a collection -- and is NAMED and REPORTED, never graded and never
# excluded in silence (today: hb_pl_root_cells, the second-findall enumeration defect, red on origin at stress 0).
# (5) gc2 (the vendored Arizona witness, prints &collections) byte-identical to its .ref 5 of 5 in both media at the
# shipped arena, named inline because &collections is arena-dependent by construction (this gate does not pin).
# (6) FAIL_ONCE=1 plants a nonzero conservative reading into arm 1 and requires the gate to red.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; examined=0
WD="$ROOT/../harness/scripts/gc_witnesses"; [ -d "$WD" ] || { echo "⛔ GATE REFUSE(2) [$G]: no $WD"; exit 2; }
GC2="$ROOT/../corpus/packages/icon/arizona_tests/general/gc2.icn"; [ -f "$GC2" ] && [ -f "${GC2%.icn}.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: gc2.icn or gc2.ref missing beside SCRIP"; exit 2; }
echo "  HOLDS: the collector visits mapped slots by table and spine cells by tag, sweeps nothing, and every GC witness reads its oracle ref under forced motion in both media"
examined=$((examined + 1))
tot=$(python3 "$HERE/util_gc_census.py" conservative 2>/dev/null | grep -oE 'conservative total=[0-9]+' | grep -oE '[0-9]+$' | head -1)
[ "${FAIL_ONCE:-0}" = 1 ] && tot=1
names=0; for nm in gc_zeta_frame cons_stack rt_cas_live_span hb_scan_interior; do c=$(grep -c "$nm" "$ROOT/src/runtime/rt/gc_heap.c"); names=$((names + c)); done
if [ "${tot:-x}" = 0 ] && [ "$names" = 0 ]; then echo "  arm 1 PASS: conservative total=0 (10 at ba216c34f) and none of the four deleted constructs is named in gc_heap.c"
else echo "  arm 1 FAIL: conservative total=${tot:-unread} deleted-construct mentions=$names"; RC=1; fi
examined=$((examined + 1))
cov=$( ( cd "$T" && SCRIP_GC_COVERAGE=1 SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-64}" SCRIP_HEAP_MAX_MB=512 SCRIP_GC_STRESS=1 timeout -k 5 120 "$SCRIP" "$WD/hb_nv.sno" 2>&1 >/dev/null </dev/null ) | grep '^\[GC-COV\]' )
ncov=$(printf '%s\n' "$cov" | grep -c 'GC-COV'); nbad=$(printf '%s\n' "$cov" | grep -vc 'cas_scanned_bytes=0 words_scanned=0 interior_words=0')
if [ "$ncov" -ge 50 ] && [ "$nbad" = 0 ]; then echo "  arm 2 PASS: $ncov collection(s) on hb_nv.sno at stress 1, every one words_scanned=0 cas_scanned_bytes=0 interior_words=0"
else echo "  arm 2 FAIL: collections=$ncov lines_with_a_nonzero_scan=$nbad"; RC=1; fi
run_w() { local mode="$1" st="$2" src="$3" n="$4" in=/dev/null out; [ -f "$WD/$n.in" ] && in="$WD/$n.in"
    if [ "$mode" = 3 ]; then ( cd "$T" && SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-64}" SCRIP_HEAP_MAX_MB=512 SCRIP_GC_POISON=1 SCRIP_GC_STRESS="$st" timeout -k 5 120 "$SCRIP" "$src" < "$in" 2>/dev/null | tr -d '\0' > "$T/o.txt" ); else ( cd "$T" && SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-64}" SCRIP_HEAP_MAX_MB=512 SCRIP_GC_POISON=1 SCRIP_GC_STRESS="$st" timeout -k 5 120 "$T/$n.m4" < "$in" 2>/dev/null | tr -d '\0' > "$T/o.txt" ); fi
    cmp -s "$T/o.txt" "$WD/$n.ref"; }
base_w() { local src="$1" n="$2" in=/dev/null; [ -f "$WD/$n.in" ] && in="$WD/$n.in"; ( cd "$T" && env -u SCRIP_HEAP_KB SCRIP_HEAP_MB=512 SCRIP_GC_STRESS=0 timeout -k 5 120 "$SCRIP" "$src" < "$in" 2>/dev/null | tr -d '\0' > "$T/b.txt" ); cmp -s "$T/b.txt" "$WD/$n.ref"; }
# ⛔⭐ DECLARED-OPEN WITNESSES (cto CTO-160, 2026-09-20, hq_icon declaring its own). THIS GATE'S POPULATION IS A DIRECTORY GLOB OVER A DIRECTORY FIVE SEATS LAND INTO, AND IT CARRIES A BLOCKING VERDICT: the moment any seat
# commits a witness for an OPEN defect, `make test` goes red for all ten seats and names a cause nobody intended. That is what happened here -- hb_file_name_unrooted is doing exactly what it was cut to do (hq_icon
# edf3bddf7: an open file's NAME is a collected-heap block held only by the C global g_fh, which is named in ZERO visit or root calls, proven A/B/A) and a witness for an open defect is SUPPOSED to be red until its cure lands.
# ⛔ A DECLARATION IS NOT AN EXEMPTION AND THIS ONE CANNOT ROT: a declared witness is STILL RUN, is COUNTED INSIDE the denominator, prints its every arm with its row, and ⭐ IF IT EVER READS ok ON EVERY GRADED ARM THE GATE
# REDS -- because that means the cure landed and the declaration is stale, and a stale declaration is how an exemption list quietly becomes the new floor. Each entry is signed by the seat whose witness it is; declaring
# ANOTHER seat's witness signs their reason for them (hq_prolog's phrase) and is not done here. Format: <witness> <owning seat> <row the cure lands under>.
# ⭐ RETIRED BY ITS OWN CURE, 2026-09-21, cfo (ICON is the cfo's cell under QUARTET, CEO-1089, and hq_icon is stood down).  The single entry was
# hb_file_name_unrooted, hq_icon's, and THIS GATE REDDED THE MOMENT THE CURE LANDED -- arm 3/4 fired "now reads ok on EVERY graded arm", which is
# exactly what the paragraph above promised it would do.  The cure is drv_gc_roots() in src/driver/driver_globals.c, which visits .name .alias .enc
# of all 64 FH slots through rt_gc_visit_raw; the witness matches its .ref at SCRIP_HEAP_MB=1 at stress 0, 1, 3 and 5.  A/B ON ONE TREE: this gate
# reads rc=0 on origin and rc=1 with the cure and the stale entry, which is the attribution and not an argument.  Deleting a stale declaration is
# not signing another seat's reason -- it is the instruction this gate prints -- and the witness is now graded like every other.  THE LIST IS EMPTY
# AND THAT IS A STATE, NOT A GAP: the next seat to cut a witness for an open defect adds a line here and signs it.
DECLARED_OPEN=""
declared_of() { printf '%s\n' "$DECLARED_OPEN" | awk -v n="$1" '$1==n{print $2" row="$3}'; }
examined=$((examined + 2)); band3=""; band4=""; bad3=0; bad4=0; nw=0; reported=""; declared=""; dec_all_ok=""
for ref in "$WD"/*.ref; do n=$(basename "$ref" .ref); src=""; for x in sno icn pl raku; do [ -f "$WD/$n.$x" ] && src="$WD/$n.$x"; done; [ -n "$src" ] || continue
    if ! base_w "$src" "$n"; then reported="$reported $n"; continue; fi
    nw=$((nw + 1)); dec="$(declared_of "$n")"; [ -n "$dec" ] && { declared="$declared $n($dec)"; dec_ok=1; }
    for st in 1 5; do if run_w 3 "$st" "$src" "$n"; then band3="$band3 $n@$st:ok"; else band3="$band3 $n@$st:RED"; [ -n "$dec" ] && { band3="$band3(DECLARED-OPEN)"; dec_ok=0; } || bad3=$((bad3 + 1)); fi; done
    if ( cd "$T" && "$SCRIP" --compile --out="$T/$n.s" "$src" </dev/null 2>/dev/null && gcc "$T/$n.s" -L "$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$T/$n.m4" 2>/dev/null ); then
        if run_w 4 5 "$src" "$n"; then band4="$band4 $n@5:ok"; else band4="$band4 $n@5:RED"; [ -n "$dec" ] && { band4="$band4(DECLARED-OPEN)"; dec_ok=0; } || bad4=$((bad4 + 1)); fi
    else band4="$band4 $n:NOBUILD"; [ -n "$dec" ] && { band4="$band4(DECLARED-OPEN)"; dec_ok=0; } || bad4=$((bad4 + 1)); fi
    [ -n "$dec" ] && [ "${dec_ok:-0}" = 1 ] && dec_all_ok="$dec_all_ok $n"
done
[ -n "$reported" ] && echo "  REPORTED, NOT GRADED (misses its ref at the shipped arena with SCRIP_GC_STRESS=0, so no collection is in the reading):$reported"
[ -n "$declared" ] && echo "  DECLARED OPEN, RUN AND COUNTED IN THE DENOMINATOR, NOT FAILING THIS GATE (a witness for an open defect is supposed to be red until its cure lands; every arm is printed above with its row):$declared"
if [ -n "$dec_all_ok" ]; then echo "  arm 3/4 FAIL: DECLARED-OPEN witness(es) now read ok on EVERY graded arm --$dec_all_ok. The cure landed, so the declaration is STALE: delete it from DECLARED_OPEN and let the witness be graded like every other. A declaration that outlives its cure is how an exemption list becomes the new floor."; RC=1; fi
if [ "$nw" -ge 20 ] && [ "$bad3" = 0 ]; then echo "  arm 3 PASS: $nw witnesses match their refs in mode 3 at SCRIP_GC_STRESS=1,5 under SCRIP_HEAP_KB=${SCRIP_HEAP_KB:-64} SCRIP_GC_POISON=1 --$band3"
else echo "  arm 3 FAIL: witnesses=$nw red_arms=$bad3 --$band3"; RC=1; fi
if [ "$nw" -ge 20 ] && [ "$bad4" = 0 ]; then echo "  arm 4 PASS: $nw witnesses match their refs in mode 4 at SCRIP_GC_STRESS=5 under SCRIP_HEAP_KB=${SCRIP_HEAP_KB:-64} SCRIP_GC_POISON=1 --$band4"
else echo "  arm 4 FAIL: witnesses=$nw red_arms=$bad4 --$band4"; RC=1; fi
examined=$((examined + 1)); ok3=0; ok4=0
( cd "$T" && "$SCRIP" --compile --out=gc2.s "$GC2" </dev/null 2>/dev/null && gcc gc2.s -L "$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o gc2.m4 2>/dev/null ) || echo "  arm 5 note: gc2 did not build in mode 4"
for i in 1 2 3 4 5; do ( cd "$T" && env -u SCRIP_HEAP_KB SCRIP_HEAP_MB=512 timeout -k 5 120 "$SCRIP" "$GC2" </dev/null > g3.txt 2>/dev/null ) && cmp -s "$T/g3.txt" "${GC2%.icn}.ref" && ok3=$((ok3 + 1)); [ -x "$T/gc2.m4" ] && ( cd "$T" && env -u SCRIP_HEAP_KB SCRIP_HEAP_MB=512 timeout -k 5 120 ./gc2.m4 </dev/null > g4.txt 2>/dev/null ) && cmp -s "$T/g4.txt" "${GC2%.icn}.ref" && ok4=$((ok4 + 1)); done
if [ "$ok3" = 5 ] && [ "$ok4" = 5 ]; then echo "  arm 5 PASS: gc2 byte-identical to its .ref 5 of 5 in both media at the shipped arena (the arena is named here because &collections is what it prints)"
else echo "  arm 5 FAIL: gc2 m3 $ok3 of 5, m4 $ok4 of 5 at the shipped arena"; RC=1; fi
examined=$((examined + 1))
if [ "${FAIL_ONCE:-0}" = 1 ]; then if [ "$RC" = 1 ]; then echo "  arm 6 PASS: FAIL_ONCE=1 planted a nonzero conservative reading and the gate reads red"; else echo "  arm 6 FAIL: the plant went unseen"; RC=1; fi
else echo "  arm 6 PASS: FAIL_ONCE=1 plants a nonzero conservative reading into arm 1 (run with FAIL_ONCE=1 to see it trip)"; fi
if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: the collector visits only mapped slots and tagged cells, sweeps nothing, and every graded GC witness reads its ref under forced motion in both media (examined $examined arms)"
else echo "GATE FAIL(1) [$G]: the collector still guesses, or a witness lost a root under the switch (examined $examined arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
