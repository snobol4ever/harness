#!/usr/bin/env bash
# test_gate_gc_every_live_slot_is_validated_after_each_collection.sh -- THE INDEPENDENT ENUMERATION, ROAD (c) OF THE VALIDATOR ROW, FINISH LINE
# of icon-gc-the-per-collection-heap-validator-every-live-typed-slot-is-checked-against-the-vacancy-table-... (ceo's 2026-10-17 ruling: "(c) is the
# row's FINISH LINE, the independent enumeration (a linear heap walk over the START bitmap with each type's slots, and for the stack the per-site
# cell map)"; the DONE-WHEN of that row IS this gate's exit code).
#
# WHAT IT CLAIMS. Under SCRIP_GC_VALIDATE=1, after every collection's fix and slide, gc_validate_heap (gc_heap.c) walks the heap LINEARLY from the arena
# to the new top by block size, and for every block whose type has a row in gc_layout.c reads that type's slots from the ROW and checks each
# pointer-bearing word: a word outside the arena passes; a word inside it must lie in the interior of a live, non-FILL block, else it is EXPIRED and is
# named with its holder block's kind and slot offset, the pointee and the vacancy record. THE ROWS ARE CUT FROM THE C PAYLOAD STRUCTS (offsetof, a
# _Static_assert per type), NOT FROM THE ASM MARK HANDLERS, so a handler that skips a field its struct declares is named; arm (4) cross-reads the two.
# The summary line also proves the walk's own premises: the heap parses end to end (badhead) and every block start has its START bit (nostart).
#
# WHAT IT DOES NOT CLAIM, AND THE GATE SAYS SO BY GOING RED. (a) Road (a) (test_gate_gc_the_record_check_after_each_collection_names_a_misfixed_slot.sh)
# still checks only the slots the mark REGISTERED; this walk is the one that sees a slot the mark never registered. (b) SOUND ALWAYS, COMPLETE ONLY
# AGAINST VACATED GROUND: a stale pointer into ground a survivor now reoccupies reads like a live one and is NOT named. (c) ARBLK_t elements reached
# through an off-heap data pointer are not walked. (d) Arm (4) is RED until every pointer-bearing block type has a row; arm (5) is RED until the stack
# half (the chain's frames' word-kind-mask cells) exists. A green gate therefore means the row is finished, and nothing short of that.
#
# ARMS. (1) SILENT ON THE CURED TREE, with reach: six witnesses, stress 1 and 3, mode 3 and mode 4, 64 KB: every collection prints its
# [ZGC-VALIDATE-HEAP] summary, every summary reads expired=0 badhead=0 nostart=0 shortblk=0, stdout equals the expected output, and the witnesses that
# allocate DVEC, ARR or AGGV reach a laid block and validate a heap pointer (a run that reaches none is not a reading). (2) FAIL-ONCE, by a seam inside THIS
# instrument (CEO-1680: a seam only in an instrument, never in SCRIP): an LD_PRELOAD shim over out/interposable/libscrip_rt.so overwrites one heap-resident
# registry entry of rt_gc_fix_run with a copy of another, so the slot is never registered, never fixed, and invisible to road (a); on a program whose array
# sits above garbage that dies, the walk must name it AT the collection that moved the pointee, and road (a) must read zero on the same run. (3) INERT WHEN
# OFF: no [ZGC-VALIDATE-HEAP] line without the knob and stdout equal to the knob-on run's. (4) COVERAGE: every HB_* type in gc_heap.h is a LEAF (no handler in
# rtx_gc.s's mark dispatch) or has a row. (5) THE STACK HALF exists.
# rc=0 every arm holds; rc=1 an arm failed; rc=2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; G="$(basename "${BASH_SOURCE[0]}" .sh)"
refuse() { echo "GATE REFUSE(2) [$G]: $*"; exit 2; }
[ -x "$ROOT/scrip" ] || refuse "no $ROOT/scrip -- run make"
"$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc > /dev/null || refuse "gcc absent"
T="$(mktemp -d)" || refuse "no scratch dir"; trap 'rm -rf "$T"' EXIT
W="$HERE/gc_witnesses"; K=64
cat > "$T/above.sno" <<'EOF'
*  an ARRAY allocated above garbage that dies, so the first collection slides its blocks down over dead ground
          G = DUPL('g',3000)
          G = DUPL('h',3000)
          A = ARRAY(8)
          A[1] = 'ALPHA'
          A[8] = 'OMEGA'
          G = ''
          I = 0
LOOP      I = I + 1
          S = DUPL('z',100)
          GT(300,I) :S(LOOP)
          OUTPUT = A[1] A[8]
END
EOF
WITS="$W/hb_arr.sno $W/hb_aggv.icn $T/above.sno $W/hb_datblk.sno $W/hb_blob_span_defer.sno $W/hb_pl_two_hundred_choice_points_retained_in_one_gap.pl"
REACH="hb_arr hb_aggv above"
printf 'ALPHAOMEGA\n' > "$T/hb_arr.exp"; printf '66\n' > "$T/hb_aggv.exp"; printf 'ALPHAOMEGA\n' > "$T/above.exp"
for w in $WITS; do
    [ -s "$w" ] || refuse "witness $w is missing"
    b="$(basename "${w%.*}")"
    [ -s "$T/$b.exp" ] || { [ -s "${w%.*}.ref" ] && cp "${w%.*}.ref" "$T/$b.exp"; } || refuse "no expected output for $b"
done
totals() { grep '^\[ZGC-VALIDATE-HEAP\] collection=' "$1" | awk '{for(i=3;i<=NF;i++){split($i,a,"=");t[a[1]]+=a[2]}; n++} END{printf "%d %d %d %d\n", n, t["laid"], t["heap"], t["expired"]+t["badhead"]+t["nostart"]+t["shortblk"]}'; }
bad=0
for w in $WITS; do
    b="$(basename "${w%.*}")"
    ( cd "$T" && "$ROOT/scrip" --compile --out="$T/$b.s" "$w" < /dev/null > /dev/null 2>&1 ) && gcc "$T/$b.s" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$T/$b.bin" 2> /dev/null || refuse "$b did not compile and link in mode 4"
    for s in 1 3; do
        for m in m3 m4; do
            if [ $m = m3 ]; then ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=$K SCRIP_GC_STRESS=$s SCRIP_GC_VALIDATE=1 timeout -k 5 300 "$ROOT/scrip" "$w" < /dev/null > "$T/o" 2> "$T/e" )
            else ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=$K SCRIP_GC_STRESS=$s SCRIP_GC_VALIDATE=1 timeout -k 5 300 "$T/$b.bin" < /dev/null > "$T/o" 2> "$T/e" ); fi
            rc=$?
            read -r n laid heap nb < <(totals "$T/e")
            want=1; case " $REACH " in *" $b "*) [ "$laid" -gt 0 ] && [ "$heap" -gt 0 ] || want=0;; esac
            if [ "$rc" = 0 ] && [ "$n" -gt 0 ] && [ "$nb" = 0 ] && [ "$want" = 1 ] && cmp -s <(grep -v '^\[GC-' "$T/o") "$T/$b.exp"; then
                echo "  ok   (1) $m stress=$s $b: $n collections walked, $laid laid blocks, $heap heap pointers validated, no finding, stdout as expected"
            else echo "  RED  (1) $m stress=$s $b: rc=$rc, $n summaries, laid=$laid heap=$heap, $nb findings, reach=$want; $(grep -m1 'EXPIRED\|BADHEAD' "$T/e" | cut -c1-200)"; bad=1; fi
            if [ $m = m3 ] && [ $s = 1 ]; then cp "$T/o" "$T/$b.on"; fi
        done
    done
done
make -s -C "$ROOT" out/interposable/libscrip_rt.so > "$T/mk.txt" 2>&1 || refuse "out/interposable/libscrip_rt.so did not build ($(tail -1 "$T/mk.txt"))"
cat > "$T/shim.c" <<'EOF'
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>
#include <stdio.h>
typedef struct { const char **loc; const char *val; } slot_t;
static void (*real_fix)(slot_t *, long, char *, size_t, const void *, const char *);
#define INHEAP(p, a) ((size_t)((const char *)(p) - (a)) < (1ul << 32))
void rt_gc_fix_run(slot_t *s, long n, char *base, size_t lg, const void *fr, const char *arena) {
    long v = -1, d = -1;
    if (!real_fix) real_fix = (void (*)(slot_t *, long, char *, size_t, const void *, const char *))dlsym(RTLD_NEXT, "rt_gc_fix_run");
    for (long i = 0; i < n; i++) {
        if (v < 0 && INHEAP(s[i].loc, arena) && INHEAP(s[i].val, arena)) v = i;
        if (d < 0 && !INHEAP(s[i].loc, arena)) d = i;
    }
    if (v >= 0 && d >= 0) { fprintf(stderr, "[SHIM] heap slot %p (value %p) made unregistered\n", (void *)s[v].loc, (const void *)s[v].val); s[v] = s[d]; }
    real_fix(s, n, base, lg, fr, arena);
}
EOF
gcc -shared -fPIC -o "$T/shim.so" "$T/shim.c" -ldl 2> /dev/null || refuse "the unregister shim did not build"
mkdir -p "$T/lib" && cp "$ROOT/out/interposable/libscrip_rt.so" "$T/lib/libscrip_rt.so"
( cd "$T" && env -u SCRIP_HEAP_MB LD_LIBRARY_PATH="$T/lib" LD_PRELOAD="$T/shim.so" SCRIP_HEAP_KB=$K SCRIP_GC_STRESS=1 SCRIP_GC_VALIDATE=1 timeout -k 5 300 "$ROOT/scrip" "$T/above.sno" < /dev/null > "$T/fo" 2> "$T/fe" )
nshim=$(grep -c '^\[SHIM\]' "$T/fe"); [ "$nshim" -gt 0 ] || refuse "the shim never found a heap-resident slot to leave unregistered ($(grep -c '^\[ZGC-VALIDATE-HEAP\] collection=' "$T/fe") summaries)"
nf=$(grep -c '^\[ZGC-VALIDATE-HEAP\] EXPIRED' "$T/fe"); na=$(grep -c '^\[ZGC-VALIDATE\] \(MISFIXED\|EXPIRED\)' "$T/fe")
first=$(grep -m1 '^\[ZGC-VALIDATE-HEAP\] EXPIRED' "$T/fe")
fc=$(echo "$first" | sed -n 's/.* collection=\([0-9]*\) .*/\1/p'); vc=$(echo "$first" | sed -n 's/.* by collection #\([0-9]*\).*/\1/p'); fk=$(echo "$first" | sed -n 's/.* kind=\(HB_[A-Z]*\) .*/\1/p')
if [ "$nf" -gt 0 ] && [ -n "$fc" ] && [ "$fc" = "$vc" ] && { [ "$fk" = HB_ARR ] || [ "$fk" = HB_DVEC ] || [ "$fk" = HB_AGGV ]; } && [ "$na" = 0 ]; then
    echo "  ok   (2) a slot left unregistered ($nshim collections) is named AT the collection that moved its pointee (#$fc, holder $fk), road (a) read $na findings on the same run: $(echo "$first" | cut -c1-210)"
else echo "  RED  (2) shim fired $nshim times; walk findings=$nf, first at collection '$fc' vs vacancy collection '$vc', holder '$fk'; road (a) findings=$na (must be 0)"; bad=1; fi
for w in $WITS; do
    b="$(basename "${w%.*}")"
    ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=$K SCRIP_GC_STRESS=1 timeout -k 5 300 "$ROOT/scrip" "$w" < /dev/null > "$T/off" 2> "$T/offe" )
    if ! grep -q 'ZGC-VALIDATE' "$T/offe" && cmp -s "$T/off" "$T/$b.on"; then echo "  ok   (3) $b: no validator line without the knob, stdout equal to the knob-on run"
    else echo "  RED  (3) $b: the knob-off run printed a validator line or a different stdout"; bad=1; fi
done
missing=""
for t in $(sed -n 's/^#define HB_\([A-Z0-9]*\) [0-9]*$/\1/p' "$ROOT/src/runtime/rt/gc_heap.h"); do
    case "$t" in ZCOL|FILL|ZBLK|WSC|WSB)
        if awk -v t="HB_$t" 'prev ~ ("cmp[ \t]+edx,[ \t]*" t "$") && $1 == "je" && $2 ~ /^\.Lmk_/ { f = 1 } { prev = $0 } END { exit !f }' "$ROOT/src/runtime/rtx/rtx_gc.s"; then missing="$missing HB_$t(declared a leaf but rtx_gc.s dispatches on it)"; fi;;
    *) grep -Eq "^static const gc_layout_t gl_[a-z0-9_]+ = \{ HB_$t," "$ROOT/src/runtime/rt/gc_layout.c" || missing="$missing HB_$t";; esac
done
if [ -z "$missing" ]; then echo "  ok   (4) every HB_* type is a declared leaf or has a layout row"
else echo "  RED  (4) block types with no layout row and not declared leaves:$missing"; bad=1; fi
if grep -q 'gc_validate_stack' "$ROOT/src/runtime/rt/gc_heap.c"; then echo "  ok   (5) the stack half exists (gc_validate_stack)"
else echo "  RED  (5) the stack half (the chain's frames' word-kind-mask cells, behind zeta-layout step 4b) is not built"; bad=1; fi
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
[ "$bad" = 0 ] && { echo "GATE PASS(0) [$G]: every live typed slot of every block type is validated after each collection, a never-registered slot is named at the collection that created it, the check is inert when off (tree SCRIP=$TREE)"; exit 0; }
echo "GATE RED(1) [$G]: see the RED arms above (tree SCRIP=$TREE)"; exit 1
