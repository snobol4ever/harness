#!/usr/bin/env bash
# test_gate_gc_a_pascal_interior_pointer_survives_a_moving_collection.sh -- A PASCAL POINTER (DT_PCELL: THE ADDRESS OF A BLOCK'S ELEMENT 0, THE ELEMENT INDEX)
# IS RELOCATED WITH ITS BLOCK WHEN THE COLLECTOR MOVES IT (row gc-a-pascal-pointer-descr-base-cell-plus-element-index-is-relocated-when-its-block-moves-the-visitor-and-its-gate-ceo-2073;
# ARCH-PASCAL-REDESIGN.md R5 AMENDED (1) to (4); hq_collector 2026-10-31).
#
# THE KIND. DT_PCELL = 0xC0 (src/ir/descr.h, src/ir/descr_tags.inc). A cell is {tag, slen = the element index (a signed 32-bit count, never relocated), word at +8 = the address of
# element 0 of the base object}. The visitor is the DT_S arm's road: if the word lies in the arena, gc_blk_of finds the block holding it from the interior address by the start bitmap,
# the block is marked and the slot is registered, and the word is rewritten to new block + (word - old block). A word outside the arena (a spine or frame cell, rodata), a nil word
# and the index are left alone (R5 amended 4). Under SCRIP_DIAG a word that no block holds aborts by name ("[GC-PCELL]"), never quietly.
#
# TWO LAYERS, because the producer (hq_pascal's @a[i], p^, inc(p), var-parameter pairs) is a different seat's landing:
#   ARMS 0 to 6 are the COLLECTOR HALF and need no Pascal. A C fixture linked on libscrip_rt.so roots a DT_PCELL cell through a trail-range entry (the one C-reachable root form the
#     collector walks, rt_gc_root_range_add_topword; the entry's DESCR is pushed on the mark worklist and dispatched through the asm class table). A 4096-byte block is allocated and
#     dies, a 160-byte block above it is the target, and one collection must slide the target down over the dead ground. The fixture holds NO raw heap pointer in a C frame: the first
#     cut did, the collector found it, and a fifth of the runs kept the garbage alive (measured, mode 0 included), so the live address is kept complemented.
#   ARM 7 is the PASCAL HALF: gc_witnesses/hb_pas_interior_pointer.pas builds a 4096-byte string by doubling (so the build-up leaves no garbage as large), allocates a SetLength array d
#     and a static array a above it, takes p := @d[3], q := @d[7], r := @a[4], and only THEN drops the string, so the next collection must slide d and a down over dead ground while the
#     pointers are live. It then churns strings between every use and reads and writes through p^, inc(p), dec(p) and inc(q), and allocates an array of 77777s to land on the vacated
#     ground. The output must equal fpc -Miso's (hb_pas_interior_pointer.ref, cut from the oracle) in mode 3 and mode 4 with no stress, SCRIP_GC_STRESS=3 and SCRIP_GC_STRESS=1, and under the
#     forced-motion setting SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_POISON=1 SCRIP_GC_STRESS=1 (hq_pascal's finding: every live block is copied to disjoint ground at EVERY collection, and plain stress
#     alone does not do that). Two more witnesses, hq_pascal's, run the same four settings: hb_pas_pointers_to_globals (pointers into a global array and a global record field) and
#     hb_pas_pointers_in_a_procedure_frame (a var-parameter pointer pair and a pointer into a local array, held in a procedure frame across 3000 allocations); refs cut from fpc -Miso.
#   ARM 8a reads the SCRIP_GC_EXERCISE receipt of each witness's forced-motion run and requires flips >= 1, so a run that moved nothing cannot pass.
#   ARM 8 is the NON-VACUITY proof of arm 7, from the collector's own telemetry (SCRIP_ZETA_TELEM=1, stress 1): exactly the collection that reclaims the dying string (4000 bytes or more) must
#     also have moved live bytes, i.e. the heap really slid under the live pointers. MEASURED on hq_pascal's commit 680428504 (tag DT_PCELL, same 0xC0): with its relocation support the
#     output equals fpc's at stress 0, 3 and 1; with the support REMOVED (the gc_visit_one case label, the .Lmk_class entry and the .Lsw_cells case deleted) the output equals fpc's only at stress 0
#     (no collection, nothing moves) and DIFFERS at stress 3 and 1. The first two cuts of this witness passed with the support removed, and so would have passed a broken collector:
#     SCRIP setlength(g, 0) does not free its block, and a block that is never freed below the array never makes the array slide.
#
# NOT COVERED, named: the frame roads reached through .Lmk_known (.Lfc_descr, the walk of a TOLD frame stretch) and gc_tag_known. hq_pascal's commit has no .Lmk_known entry for the tag and
# the witness passes without one, so a Pascal frame today does not reach that road; when zeta-layout step 4b tells Pascal frames, a cell skipped there would be neither marked nor relocated, and
# that arm of this gate is then the first thing to run. The asm marker does not assert block containment under SCRIP_DIAG; the validator (SCRIP_GC_VALIDATE=1) reads the slot through gc_type_says_ref.
#
# ARMS: (0) the tag is DT_PCELL = 0xC0 in descr_tags.inc and in descr.h; (1) the target block survives and MOVES, its bytes intact, its index and tag untouched, and it stays alive
# only because of the pointer; (2) the same fixture without the root cell reclaims the target (the only difference from arm 1 is the root); (3) a word outside the arena is untouched;
# (4) nil is untouched; (5) a negative index (0xFFFFFFFE) is untouched while the word follows; (6) two pointers into one block keep their offset; (6b) arm 1 gives one answer in five runs;
# (7) each of three Pascal witnesses equals fpc's output in both modes at four settings (no stress, stress 3, stress 1, forced motion); (8a) the forced-motion run flipped blocks;
# (8) the heap slid under the live pointers in the interior-pointer witness's stress run.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
ok() { N=$((N + 1)); echo "  ok   $*"; }
bad() { N=$((N + 1)); echo "  RED  $*"; RC=1; }
HDR=$(awk '$1 == "#define" && $2 == "PL_TR_HEADER_BYTES" {print $3}' "$ROOT/src/runtime/rt/rt_pl_trail.h")
[ -n "$HDR" ] || { echo "GATE REFUSE(2) [$G]: no PL_TR_HEADER_BYTES in rt_pl_trail.h -- the fixture lays its root range out as the trail arena header does"; exit 2; }
DTP=$(awk '$1 == "#define" && $2 == "DT_PCELL" {print $3}' "$ROOT/src/ir/descr_tags.inc")
DTH=$(grep -oE 'DT_PCELL *= *0x[0-9A-Fa-f]+' "$ROOT/src/ir/descr.h" | grep -oE '0x[0-9A-Fa-f]+' | head -1)
if [ "$DTP" = 0xC0 ] && [ "$DTH" = 0xC0 ]; then ok "(0) DT_PCELL is 0xC0 in descr_tags.inc and in descr.h"
else bad "(0) the tag is not registered: descr_tags.inc says '${DTP:-absent}', descr.h says '${DTH:-absent}' (want 0xC0 in both)"; fi
cat > "$T/fx.c" <<'FXC'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#define HB_WSB 215
void *rt_gcheap_alloc(uint16_t type, uint64_t payload_bytes);
long rt_gc_collect(void);
void rt_gc_root_range_add_topword(const char *lo);
typedef struct { uint8_t v, a, b, c; uint32_t slen; void *p; } descr_t;
typedef struct { void *cell; uint64_t pad; descr_t old; } entry_t;
static char g_root[HDR + 32 * 8] __attribute__((aligned(16)));
static char g_outside[256] __attribute__((aligned(16)));
static uintptr_t g_live_x;
static descr_t *root_cell(int k) { return &((entry_t *)(g_root + HDR + 32 * k))->old; }
static void root_pptr(int k, void *word, uint32_t idx) { descr_t *d = root_cell(k); memset(d, 0, sizeof *d); d->v = DT_PCELL; d->slen = idx; d->p = word; }
static void fill(char *p, long n) { for (long i = 0; i < n; i++) p[i] = (char)((i * 7 + 3) & 0xFF); }
static int intact(const char *p, long n) { for (long i = 0; i < n; i++) if (p[i] != (char)((i * 7 + 3) & 0xFF)) return 0; return 1; }
static __attribute__((noinline)) void *setup(void)
{
    char *garbage = (char *)rt_gcheap_alloc(HB_WSB, 4096), *live;
    memset(garbage, 'G', 4096);
    live = (char *)rt_gcheap_alloc(HB_WSB, 160); fill(live, 160);
    g_live_x = ~(uintptr_t)live;
    garbage = (char *)0;
    return live;
}
int main(int argc, char **argv)
{
    int mode = argc > 1 ? atoi(argv[1]) : 0;
    char *live;
    long r;
    memset(g_root, 0, sizeof g_root);
    *(char **)g_root = g_root + HDR + 32 * 4;
    rt_gc_root_range_add_topword(g_root);
    live = (char *)setup();
    if (mode == 1) root_pptr(0, live + 32, 3);
    if (mode == 3) root_pptr(0, g_outside + 8, 5);
    if (mode == 4) root_pptr(0, (void *)0, 0);
    if (mode == 5) root_pptr(0, live + 32, 0xFFFFFFFEu);
    if (mode == 6) { root_pptr(0, live + 32, 3); root_pptr(1, live + 96, 1); }
    live = (char *)0;
    r = rt_gc_collect();
    if (mode == 1 || mode == 5 || mode == 6) {
        descr_t *d = root_cell(0); char *nl = (char *)d->p - 32;
        printf("FX mode=%d reclaimed=%ld moved=%d delta=%ld intact=%d idx=%u tag=%02x\n", mode, r, nl != (char *)~g_live_x, (long)(nl - (char *)~g_live_x), intact(nl, 160), (unsigned)d->slen, d->v);
        if (mode == 6) { descr_t *e = root_cell(1); printf("FX mode=6 second word_offset_from_first=%ld idx=%u\n", (long)((char *)e->p - (char *)d->p), (unsigned)e->slen); }
    } else if (mode == 3) {
        descr_t *d = root_cell(0);
        printf("FX mode=3 reclaimed=%ld word_unchanged=%d idx=%u\n", r, d->p == (void *)(g_outside + 8), (unsigned)d->slen);
    } else if (mode == 4) {
        descr_t *d = root_cell(0);
        printf("FX mode=4 reclaimed=%ld word=%p idx=%u tag=%02x\n", r, d->p, (unsigned)d->slen, d->v);
    } else printf("FX mode=%d reclaimed=%ld\n", mode, r);
    fflush(stdout);
    return 0;
}
FXC
gcc -O0 -g -DHDR="$HDR" -DDT_PCELL=0xC0 -o "$T/fx" "$T/fx.c" -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" 2> "$T/cc.err" || { sed -n 1,5p "$T/cc.err"; echo "GATE REFUSE(2) [$G]: the fixture did not build"; exit 2; }
fx() { timeout 60 "$T/fx" "$@" 2> "$T/fx.err" | head -1; }
get() { sed -n "s/.* $2=\([^ ]*\).*/\1/p" <<< "$1" | head -1; }
O0=$(fx 0); R0=$(get "$O0" reclaimed)
O1=$(fx 1); R1=$(get "$O1" reclaimed); M1=$(get "$O1" moved); D1=$(get "$O1" delta); I1=$(get "$O1" intact); X1=$(get "$O1" idx); T1=$(get "$O1" tag)
if [ -z "$R0" ] || [ -z "$R1" ]; then echo "GATE REFUSE(2) [$G]: the fixture printed no reading (mode 0: '$O0', mode 1: '$O1'; stderr: $(head -c 200 "$T/fx.err"))"; exit 2; fi
if [ "$M1" = 1 ] && [ "$I1" = 1 ] && [ "$X1" = 3 ] && [ "$T1" = c0 ] && [ "${D1:-0}" -lt 0 ] && [ $((R0 - R1)) -eq 176 ]; then ok "(1) the target block survives on the pointer alone and moved by $D1 bytes, bytes intact, index 3 and tag c0 untouched (the dead 4096-byte block went: reclaimed $R1 of $R0)"
else bad "(1) moved=$M1 delta=$D1 intact=$I1 idx=$X1 tag=$T1 reclaimed=$R1 (unrooted twin $R0): the word was not carried with its block ($O1)"; fi
if [ "$R0" -ge 4288 ]; then ok "(2) without the root cell the same fixture reclaims the target too (reclaimed $R0): the pointer is what keeps it, so arm 1 is not vacuous"
else bad "(2) the unrooted twin reclaimed only $R0 (want at least 4288): the fixture holds the target some other way"; fi
O3=$(fx 3); if [ "$(get "$O3" word_unchanged)" = 1 ] && [ "$(get "$O3" idx)" = 5 ] && [ "$(get "$O3" reclaimed)" = "$R0" ]; then ok "(3) a word outside the arena is left alone (index 5 kept) and keeps nothing alive ($O3)"
else bad "(3) an out-of-arena word was touched or kept something alive: $O3"; fi
O4=$(fx 4); if [ "$(get "$O4" word)" = "(nil)" ] && [ "$(get "$O4" idx)" = 0 ] && [ "$(get "$O4" tag)" = c0 ] && [ "$(get "$O4" reclaimed)" = "$R0" ]; then ok "(4) nil (word 0, index 0) is untouched and keeps nothing alive ($O4)"
else bad "(4) nil was touched or kept something alive: $O4"; fi
O5=$(fx 5); if [ "$(get "$O5" moved)" = 1 ] && [ "$(get "$O5" intact)" = 1 ] && [ "$(get "$O5" idx)" = 4294967294 ]; then ok "(5) the index 0xFFFFFFFE (minus 2) is never relocated while the word follows its block ($O5)"
else bad "(5) the index was altered or the word did not follow: $O5"; fi
O6A=$(timeout 60 "$T/fx" 6 2> /dev/null | sed -n 1p); O6B=$(timeout 60 "$T/fx" 6 2> /dev/null | sed -n 2p)
if [ "$(get "$O6A" moved)" = 1 ] && [ "$(get "$O6A" intact)" = 1 ] && [ "$(get "$O6B" word_offset_from_first)" = 64 ] && [ "$(get "$O6B" idx)" = 1 ]; then ok "(6) two pointers into one block both follow it and keep their 64-byte offset ($O6B)"
else bad "(6) the two pointers diverged: $O6A / $O6B"; fi
S=$(for i in 1 2 3 4 5; do fx 1; done | sort -u | wc -l)
if [ "$S" = 1 ]; then ok "(6b) arm 1 gave one answer in five runs"; else bad "(6b) arm 1 gave $S different answers in five runs (a stack-held pointer in the fixture, or a collector that depends on the address layout)"; fi
WITS="hb_pas_interior_pointer hb_pas_pointers_to_globals hb_pas_pointers_in_a_procedure_frame"
SETS="none:SCRIP_GC_STRESS=0 s3:SCRIP_GC_STRESS=3 s1:SCRIP_GC_STRESS=1 flip:SCRIP_GC_PLANT_FLIP=1,SCRIP_GC_POISON=1,SCRIP_GC_STRESS=1"
for w in $WITS; do
  WIT="$HERE/gc_witnesses/$w.pas"; REF="${WIT%.pas}.ref"
  [ -f "$WIT" ] && [ -f "$REF" ] || { echo "GATE REFUSE(2) [$G]: the Pascal witness or its fpc ref is missing ($WIT)"; exit 2; }
  P="$T/$w"; mkdir -p "$P"
  ( cd "$P" && timeout -k 5 120 "$ROOT/scrip" --compile --out=w.s "$WIT" < /dev/null > c.out 2> c.err && gcc w.s -L "$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o w.bin 2> l.err ); BUILT4=$?
  for sp in $SETS; do
    lab=${sp%%:*}; envs=${sp#*:}; envs=${envs//,/ }
    for m in 3 4; do
      if [ "$m" = 3 ]; then ( cd "$P" && env $envs timeout -k 5 180 "$ROOT/scrip" "$WIT" < /dev/null > o.$m.$lab 2> e.$m.$lab ); rc=$?
      elif [ "$BUILT4" = 0 ]; then ( cd "$P" && env $envs timeout -k 5 180 ./w.bin < /dev/null > o.$m.$lab 2> e.$m.$lab ); rc=$?
      else : > "$P/o.$m.$lab"; cp "$P/c.err" "$P/e.$m.$lab" 2> /dev/null; rc=99; fi
      if [ "$rc" = 0 ] && cmp -s "$P/o.$m.$lab" "$REF"; then ok "(7) $w, mode $m, $lab: output equals fpc -Miso's"
      else bad "(7) $w, mode $m, $lab: rc=$rc; $(diff "$P/o.$m.$lab" "$REF" 2> /dev/null | head -1 | cut -c1-80); $(head -c 160 "$P/e.$m.$lab" 2> /dev/null | head -1)"; fi
    done
  done
  ( cd "$P" && SCRIP_GC_EXERCISE=1 SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_POISON=1 SCRIP_GC_STRESS=1 timeout -k 5 240 "$ROOT/scrip" "$WIT" < /dev/null > /dev/null 2> ex.txt )
  FL=$(sed -n 's/.*\[GC-EXERCISE\].* flips=\([0-9]*\).*/\1/p' "$P/ex.txt" | tail -1)
  if [ -n "$FL" ] && [ "$FL" -ge 1 ]; then ok "(8a) $w under SCRIP_GC_PLANT_FLIP: every live block was copied to disjoint ground $FL time(s), so the forced-motion run did move the pointer's target"
  else bad "(8a) $w under SCRIP_GC_PLANT_FLIP reported flips='${FL:-none}': the forced-motion run moved nothing, so its output proves nothing"; fi
done
P="$T/hb_pas_interior_pointer"; WIT="$HERE/gc_witnesses/hb_pas_interior_pointer.pas"
( cd "$P" && SCRIP_GC_STRESS=1 SCRIP_ZETA_TELEM=1 timeout -k 5 240 "$ROOT/scrip" "$WIT" < /dev/null > /dev/null 2> tel.txt )
grep -q '^\[ZGC\] regeneration' "$P/tel.txt" || { echo "GATE REFUSE(2) [$G]: SCRIP_ZETA_TELEM printed no regeneration line, so arm 8 cannot read whether the heap slid (the telemetry format moved?)"; exit 2; }
SLID=$(awk '/^\[ZGC-WALK\]/ { m = 0; if (match($0, /moved=[0-9]+B/)) m = substr($0, RSTART + 6, RLENGTH - 7) + 0 } /^\[ZGC\] regeneration/ { if (match($0, /reclaimed [0-9]+/)) { r = substr($0, RSTART + 10, RLENGTH - 10) + 0; if (r >= 4000 && m > 0) c++ } } END { print c + 0 }' "$P/tel.txt")
if [ "$SLID" -ge 1 ]; then ok "(8) the heap slid under the live pointers: $SLID collection(s) reclaimed the dying 4096-byte string and moved live bytes, so arm 7 is not vacuous"
else bad "(8) no collection reclaimed the 4096-byte string and moved live bytes after the pointers were taken: the witness no longer makes the array move, so arm 7 would pass a collector that never relocates the pointer"; fi
echo "population: $N arm(s) graded"
[ $RC -eq 0 ] && echo "GATE PASS [$G]" || echo "GATE RED(1) [$G]: see the RED arms above (tree SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2> /dev/null))"
exit $RC
