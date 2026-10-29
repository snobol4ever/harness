#!/usr/bin/env bash
# test_gate_gc_the_record_check_after_each_collection_names_a_misfixed_slot.sh -- THE RECORD CHECK, ROAD (a) OF THE VALIDATOR ROW
# (cto 2026-10-17; ceo's ruling on row icon-gc-the-per-collection-heap-validator-...: "(a) now ... (c) is the row's finish line ... (b) is dropped").
#
# WHAT IT CLAIMS, AND WHAT IT DOES NOT. Under SCRIP_GC_VALIDATE=1, after every collection's fix and slide (gc_heap.c gc_validate_record, run
# before the LIVE bitmap is cleared), every slot the mark registered -- its location translated to where its holder now lives when the holder
# is a heap block -- must hold EXACTLY the fix formula's destination of the value it held at registration (base + gc_rank(value)), and that
# value must lie inside a live block below the new top. A slot that holds anything else is named: MISFIXED (inside a live block but not where
# the fix sends it) or EXPIRED (in vacated ground or a FILL). So it names a fix or slide error and a slot changed after the fix. IT DOES NOT
# NAME A LOST ROOT: a holder the mark never visited is in no record. That claim needs an independent enumeration (a linear walk over START with
# each type's slots, and the per-site stack cell map), which is the row's finish line, test_gate_gc_every_live_slot_is_validated_after_each_collection.sh.
#
# ARMS. (1) THE PROPERTY: three gc witnesses, mode 3 and mode 4, at SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 with the check on: every collection
# prints its [ZGC-VALIDATE] summary, every summary reads expired=0 misfixed=0, and stdout equals the witness's ref. (2) THE FAIL-ONCE, by a
# seam inside THIS instrument (CEO-1680 allows a seam only in an instrument, never in SCRIP): an LD_PRELOAD shim over
# out/interposable/libscrip_rt.so calls the real rt_gc_fix_run and then puts one root's registered (pre-fix) value back; the check must name it.
# (3) INERT WHEN OFF: without the knob no [ZGC-VALIDATE] line is printed and stdout equals the knob-on run's.
# rc=0 every arm holds; rc=1 an arm failed; rc=2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; G="$(basename "${BASH_SOURCE[0]}" .sh)"
refuse() { echo "GATE REFUSE(2) [$G]: $*"; exit 2; }
[ -x "$ROOT/scrip" ] || refuse "no $ROOT/scrip -- run make"
"$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc > /dev/null || refuse "gcc absent"
T="$(mktemp -d)" || refuse "no scratch dir"; trap 'rm -rf "$T"' EXIT
W="$HERE/gc_witnesses"; WITS="hb_datblk.sno hb_blob_span_defer.sno hb_pl_two_hundred_choice_points_retained_in_one_gap.pl"
for w in $WITS; do [ -s "$W/$w" ] && [ -s "$W/${w%.*}.ref" ] || refuse "witness $w or its ref is missing"; done
bad=0
for w in $WITS; do
    b="${w%.*}"
    ( cd "$T" && "$ROOT/scrip" --compile --out="$T/$b.s" "$W/$w" < /dev/null > /dev/null 2>&1 ) && gcc "$T/$b.s" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$T/$b.bin" 2> /dev/null || refuse "$w did not build in mode 4"
    for m in m3 m4; do
        if [ $m = m3 ]; then ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_VALIDATE=1 timeout -k 5 300 "$ROOT/scrip" "$W/$w" < /dev/null > "$T/o" 2> "$T/e" )
        else ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_VALIDATE=1 timeout -k 5 300 "$T/$b.bin" < /dev/null > "$T/o" 2> "$T/e" ); fi
        rc=$?
        nc=$(grep -c '^\[ZGC-VALIDATE\] collection=' "$T/e"); nb=$(grep '^\[ZGC-VALIDATE\] collection=' "$T/e" | grep -vc 'expired=0 misfixed=0$')
        if [ "$rc" = 0 ] && [ "$nc" -gt 0 ] && [ "$nb" = 0 ] && cmp -s <(grep -v '^\[GC-' "$T/o") "$W/$b.ref"; then echo "  ok   (1) $m $w: $nc collections checked, every one expired=0 misfixed=0, stdout equals its ref"
        else echo "  RED  (1) $m $w: rc=$rc, $nc summaries, $nb with a finding; $(grep -m1 'MISFIXED\|EXPIRED' "$T/e" | cut -c1-160)"; bad=1; fi
        if [ $m = m3 ]; then cp "$T/o" "$T/$b.on"; fi
    done
done
make -s -C "$ROOT" out/interposable/libscrip_rt.so > "$T/mk.txt" 2>&1 || refuse "out/interposable/libscrip_rt.so did not build ($(tail -1 "$T/mk.txt"))"
cat > "$T/shim.c" <<'EOF'
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>
typedef struct { const char **loc; const char *val; } slot_t;
static void (*real_fix)(slot_t *, long, char *, size_t, const void *, const char *);
static long calls;
void rt_gc_fix_run(slot_t *s, long n, char *base, size_t lg, const void *fr, const char *arena) {
    if (!real_fix) real_fix = (void (*)(slot_t *, long, char *, size_t, const void *, const char *))dlsym(RTLD_NEXT, "rt_gc_fix_run");
    real_fix(s, n, base, lg, fr, arena);
    if (++calls < 3) return;
    for (long i = 0; i < n; i++) if ((const char *)s[i].loc < arena && *s[i].loc != s[i].val) { *s[i].loc = s[i].val; return; }
}
EOF
gcc -shared -fPIC -o "$T/shim.so" "$T/shim.c" -ldl 2> /dev/null || refuse "the fix shim did not build"
mkdir -p "$T/lib" && cp "$ROOT/out/interposable/libscrip_rt.so" "$T/lib/libscrip_rt.so"
( cd "$T" && env -u SCRIP_HEAP_MB LD_LIBRARY_PATH="$T/lib" LD_PRELOAD="$T/shim.so" SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_VALIDATE=1 timeout -k 5 300 "$ROOT/scrip" "$W/hb_datblk.sno" < /dev/null > /dev/null 2> "$T/fe" )
nf=$(grep -c '^\[ZGC-VALIDATE\] \(MISFIXED\|EXPIRED\)' "$T/fe")
if [ "$nf" -gt 0 ]; then echo "  ok   (2) the shim's re-staled root is named: $(grep -m1 '^\[ZGC-VALIDATE\] \(MISFIXED\|EXPIRED\)' "$T/fe" | cut -c1-150)"
else echo "  RED  (2) the shim put a root's pre-fix value back and the check named nothing ($(grep -c '^\[ZGC-VALIDATE\] collection=' "$T/fe") summaries)"; bad=1; fi
for w in $WITS; do
    b="${w%.*}"
    ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 timeout -k 5 300 "$ROOT/scrip" "$W/$w" < /dev/null > "$T/off" 2> "$T/offe" )
    if ! grep -q 'ZGC-VALIDATE' "$T/offe" && cmp -s "$T/off" "$T/$b.on"; then echo "  ok   (3) $w: no check line without the knob, stdout equal to the knob-on run"
    else echo "  RED  (3) $w: the knob-off run printed a check line or a different stdout"; bad=1; fi
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
[ "$bad" = 0 ] && { echo "GATE PASS(0) [$G]: every registered slot holds its fixed value inside a live block after each collection, a re-staled root is named, the check is inert when off (tree SCRIP=$TREE)"; exit 0; }
echo "GATE FAIL(1) [$G]: see the RED arms (tree SCRIP=$TREE)"; exit 1
