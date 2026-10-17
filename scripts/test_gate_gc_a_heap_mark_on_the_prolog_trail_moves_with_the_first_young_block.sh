#!/usr/bin/env bash
# test_gate_gc_a_heap_mark_on_the_prolog_trail_moves_with_the_first_young_block.sh
#
# THE ROW: the cto's conditional trail (prolog-spine-a-binding-of-a-variable-younger-than-the-newest-choice-point-
# is-trailed-and-undone-under-nb-linkarg). A choice point keeps HB, the heap frontier at its creation, as the pad of
# a SENTINEL trail entry {cell 0, pad HB, old the null DESCR}; a heap cell at or above HB is younger than the choice
# and its binding is not trailed. The collector moves blocks, so it must move HB with them, EXACTLY: the new HB is
# the new address of the first live block whose old address is at or above the old HB, else the new frontier
# (hq_collector to the cto, agreed 2026-10-14). A stale HB is not safe: SCRIP_GC_RELOC, SCRIP_GC_PLANT_SHIFT and
# SCRIP_GC_PLANT_FLIP move live blocks UP, so an old cell could land above a stale mark and lose its trail entry.
#
# THE FIXTURE builds its own trail with rt_pl_tr_init and grades the mark against the collector's own answer for the
# young block: a live block is rooted by an ordinary trail entry whose cell word the collector rewrites, so the
# expected mark is that rewritten cell minus the 16-byte block header. No plant, no seam in SCRIP (CEO-1680): the
# arms read RED on the tree before the cure (the mark never moved) and GREEN after it.
#   (a) a dead old block, a live old block K, the mark, a dead young block, a live young block Y: the mark is Y's
#       new header, K's cell lies below it, Y's cell at or above it
#   (b) a second mark with no live block above it reads the new frontier
#   (c) (a) and (b) under SCRIP_GC_RELOC=1, SCRIP_GC_PLANT_SHIFT=4096 and SCRIP_GC_PLANT_FLIP=1
# FAIL_ONCE=1 grades every mark arm against the UNMOVED mark (a corrupted ref): the mark arms of (a), (b) and (c) must
# red; the order arms grade the cure itself and stay green.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT="$PWD"; G="gc_a_heap_mark_on_the_prolog_trail_moves_with_the_first_young_block"
unset SCRIP_HEAP_MB SCRIP_HEAP_KB SCRIP_GC_PLANT_FLIP SCRIP_GC_STRESS
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
refuse() { echo "⛔ GATE REFUSED(2) [$G]: $1"; exit 2; }
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no out/libscrip_rt.so -- the fixture links the runtime under test"
command -v gcc >/dev/null 2>&1 || refuse "no gcc -- the fixture cannot be built"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ulimit -c 0 2>/dev/null || true
cat > "$T/hb.c" <<'FIXTUREC'
#include <stdio.h>
#include <stdint.h>
#include <string.h>
void *rt_gcheap_alloc(uint16_t type, uint64_t payload_bytes);
long rt_gc_collect(void);
void *rt_pl_tr_init(void);
typedef struct { char *top; char *end; } fr_t;
extern fr_t g_hp_fr;
typedef struct { void *cell; uint64_t pad; uint64_t o0, o1; } ent_t;
static char *tr;
static ent_t *push(void *cell, uint64_t pad) {
    ent_t *e = (ent_t *)tr;
    e->cell = cell;
    e->pad = pad;
    e->o0 = 0;
    e->o1 = 0;
    tr += 32;
    *(char **)((uintptr_t)tr & ~(((uintptr_t)1 << 27) - 1)) = tr;
    return e;
}
static char *dvec(uint64_t n) { char *p = (char *)rt_gcheap_alloc(214, n); memset(p, 0, n); return p; }
int main(void) {
    tr = (char *)rt_pl_tr_init();
    (void)dvec(4096);
    ent_t *k = push(dvec(32), 0);
    char *hb1 = g_hp_fr.top;
    ent_t *s1 = push((void *)0, (uint64_t)(uintptr_t)hb1);
    (void)dvec(4096);
    ent_t *y = push(dvec(32), 0);
    char *hb2 = g_hp_fr.top;
    ent_t *s2 = push((void *)0, (uint64_t)(uintptr_t)hb2);
    (void)dvec(4096);
    long r = rt_gc_collect();
    printf("HB reclaimed=%ld\n", r);
    printf("HB a_mark=%p a_expect=%p a_unmoved=%p\n", (void *)(uintptr_t)s1->pad, (void *)((char *)y->cell - 16), (void *)hb1);
    printf("HB a_kbelow=%d a_yabove=%d\n", (char *)k->cell < (char *)(uintptr_t)s1->pad, (char *)y->cell >= (char *)(uintptr_t)s1->pad);
    printf("HB b_mark=%p b_expect=%p b_unmoved=%p\n", (void *)(uintptr_t)s2->pad, (void *)g_hp_fr.top, (void *)hb2);
    return 0;
}
FIXTUREC
gcc -O0 -g -o "$T/hb" "$T/hb.c" -L "$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" 2>"$T/cc.err" || { sed -n 1,5p "$T/cc.err"; refuse "the fixture did not build"; }
grade() {
    local tag="$1" out="$2" am ae au bm be bu kb ya
    am="$(sed -n 's/^HB a_mark=\([^ ]*\) .*/\1/p' "$out")"; ae="$(sed -n 's/.* a_expect=\([^ ]*\) .*/\1/p' "$out")"; au="$(sed -n 's/.* a_unmoved=\([^ ]*\)$/\1/p' "$out")"
    bm="$(sed -n 's/^HB b_mark=\([^ ]*\) .*/\1/p' "$out")"; be="$(sed -n 's/.* b_expect=\([^ ]*\) .*/\1/p' "$out")"; bu="$(sed -n 's/.* b_unmoved=\([^ ]*\)$/\1/p' "$out")"
    kb="$(sed -n 's/^HB a_kbelow=\([01]\) .*/\1/p' "$out")"; ya="$(sed -n 's/.* a_yabove=\([01]\)$/\1/p' "$out")"
    [ -n "$am" ] && [ -n "$ae" ] && [ -n "$bm" ] && [ -n "$be" ] || { ck FAIL "$tag the fixture printed no marks (rc or crash; see below)"; sed -n 1,5p "$out"; return; }
    grep -q '^HB reclaimed=0$' "$out" && ck FAIL "$tag the collection reclaimed nothing, so nothing moved and the arm measures nothing" && return
    [ "${FAIL_ONCE:-0}" = 1 ] && { ae="$au"; be="$bu"; }
    [ "$am" = "$ae" ] && ck ok "$tag (a) the mark is the young live block's new header ($am)" || ck FAIL "$tag (a) the mark reads $am, the young live block's new header is $ae (the unmoved mark was $au)"
    [ "$kb" = 1 ] && [ "$ya" = 1 ] && ck ok "$tag (a) the old live block lies below the mark and the young one at or above it" || ck FAIL "$tag (a) order broken: old-below=$kb young-at-or-above=$ya"
    [ "$bm" = "$be" ] && ck ok "$tag (b) a mark with no live block above it reads the new frontier ($bm)" || ck FAIL "$tag (b) the mark reads $bm, the new frontier is $be (the unmoved mark was $bu)"
}
"$T/hb" >"$T/plain.out" 2>"$T/plain.err"; echo "  plain: rc=$?"
grade "plain:" "$T/plain.out"
SCRIP_GC_PLANT_FLIP=1 "$T/hb" >"$T/flip.out" 2>"$T/flip.err"; frc=$?; nflip="$(grep -c '^\[GC-FLIP\] plant:' "$T/flip.err")"; echo "  flip: rc=$frc $nflip flip line(s)"
if [ "${nflip:-0}" -ge 1 ]; then grade "(c) SCRIP_GC_PLANT_FLIP=1:" "$T/flip.out"; else ck FAIL "(c) SCRIP_GC_PLANT_FLIP=1: the GC-FLIP banner never printed, so the flip plant did not apply and its arms grade an unplanted run"; fi
echo "[$G] $((checks - fails))/$checks"
[ "$fails" -eq 0 ] && echo "PASS $G" && exit 0
echo "FAIL $G"; exit 1
