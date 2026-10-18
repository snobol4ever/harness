#!/usr/bin/env bash
# test_gate_gc_a_coexpression_frame_image_lives_on_its_own_stack.sh -- rung 2 of the coexpression rows (cto, 2026-09-19,
# MODE TRIO; row gc-the-collector-walks-the-rbp-chain-...-and-coexpression-stacks-are-mapped-frames, first cut; Lon
# 2026-09-19 in-chat: "When I say frame, I am referring to STANDING-ACTIVATION (root RBP frame), ACTIVATION frames (RBP
# frames nested under STANDING or other ACTIVATION frames), and the SPINE (RSP)." and "If frames are being allocated on
# the HEAP then delete that code, because we do not do that here.").
#
# WHAT WAS THERE. scrip_coexpr_create copied the creator's ACTIVATION frame image ([regs[5]-below, +frame_bytes+below))
# into a ct_alloc arena block (frame_copy), registered that block as a GC root range (word-swept every collection), and
# the trampoline copied it onto the co-expression's own thread stack at first activation; the arena block lived on only
# so that ^e (scrip_coexpr_refresh) could re-create the co-expression from its creation-time image. Frame bytes off the
# RSP/RBP stack, in a region the collector had to guess about.
#
# WHAT IS HERE. The co-expression's thread is created EAGERLY at `create`: the new thread reserves the image on ITS OWN
# stack (the pristine image), copies the creator's live frame into it while the creator blocks on a `created` semaphore,
# then waits for activation; the entry asm carves the working frame below and copies from that on-stack image exactly
# as it copied from the arena block; ^e reads the old co-expression's on-stack image (Icon co-expressions are never
# destroyed). frame_copy, its size and below fields, the rt_gc_root_range_add of the block and its ct_drop are gone. The
# lazily started generator contexts of rt.c (scrip_co_ctx_init) are untouched. The pristine image is a frame-shaped root
# on the thread's stack (it carries the creator's map cell): the segment walk reads it like any frame.
#
# ARMS. (1) STRUCTURE: no frame_copy, no arena copy of frame bytes, no root-range registration in rt_coexpr.c; the eager
# fields exist. (2) REFRESH: hb_coexpr_refresh.icn (two activations, then ^e restarts from the creation-time image while
# every block moves) matches its iconx-cut ref at SCRIP_GC_STRESS=1,3,5,8 under SCRIP_GC_PLANT_SHIFT=4096 in BOTH modes.
# (3) ARIZONA: coexpr.icn (image(^e), sixty co-expression operations) prints the same stdout as icont at stress 0 and 5
# (58 lines; its &errout trace is the ceo's rowed finding, not graded here). (4) MEASURED, NOT ASSERTED: the reporter's
# images_on_stack counts every context whose image address lies inside its own thread's stack mapping and
# images_off_stack reads 0 on the refresh witness. (5) the uncreated-thread gate holds both contracts (lazy refused,
# eager already has its stack). (6) hb_coexpr_genp_scan.icn -- a generator called by VALUE inside a scan (rt.c's lazily
# started generator thread) keeps the caller's scan environment across its first yield back to main, both modes, stress
# 0,1,3,5 under the shift plant: the fail-once of rung 2's first cut, whose `started` flag read main's context as never
# started and reset the scan environment on that yield (IcnRungs 825/826, procedure_suspend_scan_replace_1, both modes).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || exit 2
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
WD="$ROOT/../harness/scripts/gc_witnesses"; WIT="$WD/hb_coexpr_refresh.icn"; REF="$WD/hb_coexpr_refresh.ref"
AZ="$S4E/corpus/packages/icon/arizona_tests/general/coexpr.icn"
for f in "$WIT" "$REF" "$AZ" "$ROOT/src/runtime/rt/rt_coexpr.c" "$ROOT/src/runtime/rt/rt_coexpr.h"; do [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $f"; exit 2; }; done
echo "  HOLDS: a co-expression's frame image never leaves the RSP/RBP stack -- the creator's frame is copied onto the new thread's own stack at create time and ^e re-creates from that on-stack image; no arena snapshot, no registered range"
fc=$(grep -c 'frame_copy' "$ROOT/src/runtime/rt/rt_coexpr.c" "$ROOT/src/runtime/rt/rt_coexpr.h" | awk -F: '{s+=$2} END {print s+0}')
rr=$(grep -c 'rt_gc_root_range_add' "$ROOT/src/runtime/rt/rt_coexpr.c"); ca=$(grep -c 'ct_alloc(span)' "$ROOT/src/runtime/rt/rt_coexpr.c")
ef=$(grep -c 'image_span\|image_src' "$ROOT/src/runtime/rt/rt_coexpr.h"); eg=$(grep -c 'scrip_co_thread_start(ctx)' "$ROOT/src/runtime/rt/rt_coexpr.c")
if [ "$fc" = 0 ] && [ "$rr" = 0 ] && [ "$ca" = 0 ] && [ "$ef" -ge 1 ] && [ "$eg" -ge 1 ]; then echo "  arm 1 PASS: no frame_copy, no arena copy of frame bytes, no root-range registration; the eager fields and the eager thread start are present"
else echo "  arm 1 FAIL: frame_copy=$fc root_range=$rr ct_alloc_span=$ca eager_fields=$ef eager_start=$eg"; RC=1; fi
m4build() { "$SCRIP" --compile "$1" > "$2.s" 2>/dev/null && gcc "$2.s" -o "$2" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" 2>/dev/null; }
ref="$(cat "$REF")"; band=""; bad=0
m4build "$WIT" "$T/rf" || { echo "  arm 2 FAIL: the refresh witness does not build in mode 4"; RC=1; bad=1; }
for st in 1 3 5 8; do
    o3="$( cd "$T" && SCRIP_GC_PLANT_FLIP=1 SCRIP_HEAP_KB=512 SCRIP_GC_STRESS=$st timeout -k 5 120 "$SCRIP" "$WIT" 2>/dev/null </dev/null | tr -d '\0' )"
    o4="$( cd "$T" && SCRIP_GC_PLANT_FLIP=1 SCRIP_HEAP_KB=512 SCRIP_GC_STRESS=$st timeout -k 5 120 "$T/rf" 2>/dev/null </dev/null | tr -d '\0' )"
    if [ "$o3" = "$ref" ] && [ "$o4" = "$ref" ]; then band="$band @$st:ok"; else band="$band @$st:m3=$([ "$o3" = "$ref" ] && echo ok || echo RED),m4=$([ "$o4" = "$ref" ] && echo ok || echo RED)"; bad=1; fi
done
if [ "$bad" = 0 ]; then echo "  arm 2 PASS: ^e restarts from the on-stack image while every block moves; the refresh witness matches its iconx ref at stress 1,3,5,8 in both modes --$band"
else echo "  arm 2 FAIL: the refresh image did not survive --$band"; RC=1; fi
( cd "$T" && cp "$AZ" az.icn && "$ICONT" -s az.icn -x </dev/null > az.oref 2>/dev/null ) || { echo "⛔ GATE REFUSE(2) [$G]: icont could not run coexpr.icn"; exit 2; }
a3=""; a3bad=0
for st in 0 5; do o="$( cd "$T" && SCRIP_GC_STRESS=$st timeout -k 5 120 "$SCRIP" "$AZ" 2>/dev/null </dev/null | tr -d '\0' )"; if [ "$o" = "$(cat "$T/az.oref")" ]; then a3="$a3 @$st:ok"; else a3="$a3 @$st:RED"; a3bad=1; fi; done
n=$(wc -l < "$T/az.oref")
if [ "$a3bad" = 0 ] && [ "$n" -ge 50 ]; then echo "  arm 3 PASS: Arizona coexpr.icn (image(^e) among its $n stdout lines) prints exactly icont's stdout at stress 0 and 5 --$a3"
else echo "  arm 3 FAIL: Arizona coexpr.icn stdout differs from icont ($n oracle lines) --$a3"; RC=1; fi
line=$( ( cd "$T" && SCRIP_GC_MAPS=1 SCRIP_GC_STRESS=3 timeout -k 5 120 "$SCRIP" "$WIT" 2>&1 >/dev/null </dev/null ) | grep '^\[GC-COEXPR\]' | tail -1)
on=$(echo "$line" | grep -oE 'images_on_stack=[0-9]+' | cut -d= -f2); off=$(echo "$line" | grep -oE 'images_off_stack=[0-9]+' | cut -d= -f2)
if [ "${on:-0}" -ge 1 ] && [ "${off:-x}" = 0 ]; then echo "  arm 4 PASS: every co-expression image lies inside its own thread's stack mapping ($line)"
else echo "  arm 4 FAIL: reporter line [$line]"; RC=1; fi
GW="$WD/hb_coexpr_genp_scan.icn"; GR="$WD/hb_coexpr_genp_scan.ref"; [ -f "$GW" ] && [ -f "$GR" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $GW"; exit 2; }
gref="$(cat "$GR")"; a6=""; a6bad=0
m4build "$GW" "$T/gp" || { echo "  arm 6 FAIL: the generator-in-scan witness does not build in mode 4"; RC=1; a6bad=1; }
for st in 0 1 3 5; do
    g3="$( cd "$T" && SCRIP_GC_PLANT_FLIP=1 SCRIP_HEAP_KB=512 SCRIP_GC_STRESS=$st timeout -k 5 120 "$SCRIP" "$GW" 2>/dev/null </dev/null | tr -d '\0' )"; g4="$( cd "$T" && SCRIP_GC_PLANT_FLIP=1 SCRIP_HEAP_KB=512 SCRIP_GC_STRESS=$st timeout -k 5 120 "$T/gp" 2>/dev/null </dev/null | tr -d '\0' )"
    if [ "$g3" = "$gref" ] && [ "$g4" = "$gref" ]; then a6="$a6 @$st:ok"; else a6="$a6 @$st:m3=$([ "$g3" = "$gref" ] && echo ok || echo RED),m4=$([ "$g4" = "$gref" ] && echo ok || echo RED)"; a6bad=1; fi
done
if [ "$a6bad" = 0 ]; then echo "  arm 6 PASS: a generator called by value inside a scan (the lazily started generator thread) keeps the caller's scan environment across its first yield back to main, at stress 0,1,3,5 in both modes under the shift plant --$a6 (the fail-once: rung 2's first cut reset it and IcnRungs read 825/826)"
else echo "  arm 6 FAIL: the generator thread's first yield disturbed the caller's scan environment --$a6"; RC=1; fi
if bash "$HERE/test_gate_coexpr_stack_of_uncreated_thread.sh" >"$T/u.txt" 2>&1; then echo "  arm 5 PASS: $(grep '^PASS:' "$T/u.txt" | head -1 | cut -c1-150)"; else echo "  arm 5 FAIL: $(tail -2 "$T/u.txt" | tr '\n' ' ' | cut -c1-160)"; RC=1; fi
pl=$( ( cd "$T" && SCRIP_GC_PLANT_FLIP=1 SCRIP_HEAP_KB=512 SCRIP_GC_STRESS=3 timeout -k 5 120 "$SCRIP" "$WIT" 2>&1 >/dev/null </dev/null ) | grep -c "^\[GC-FLIP\] plant:" ); pl=${pl:-0}
if [ "$pl" -ge 1 ]; then echo "  arm 7 PASS: the forced motion this gate grades under is REAL -- the flip plant announced $pl application(s) at SCRIP_GC_PLANT_FLIP=1 with nothing asked for, so arms 2 and 6 moved every block rather than relying on ordinary compaction"
else echo "⛔ GATE REFUSE(2) [$G]: the flip plant applied ZERO times at SCRIP_GC_PLANT_FLIP=1 and SCRIP_HEAP_MB=${SCRIP_HEAP_MB:-default} -- gc_plant_shift_bytes() declines whenever arena headroom is not strictly greater than the shift, so arms 2 and 6 graded ordinary compaction while claiming every block moves. Nothing is graded and nothing is red: this is a configuration statement (cto 2026-09-21, held by test_gate_gc_the_plant_says_whether_it_applied)"; exit 2; fi
if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: no frame image leaves the stack -- the eager thread holds the creator's image on its own stack, refresh reads it back under forced motion in both modes, Arizona agrees with icont (examined 7 arms)"
else echo "GATE FAIL(1) [$G]: a frame image is off the stack, the refresh path lost it, or a generator's first yield disturbed the scan (examined 7 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
