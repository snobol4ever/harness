#!/usr/bin/env bash
# test_gate_gc_every_live_slot_is_validated_after_each_collection.sh -- THE INDEPENDENT ENUMERATION, ROAD (c) OF THE VALIDATOR ROW, FINISH LINE
# of icon-gc-the-per-collection-heap-validator-every-live-typed-slot-is-checked-against-the-vacancy-table-... (ceo's 2026-10-17 ruling: "(c) is the
# row's FINISH LINE, the independent enumeration (a linear heap walk over the START bitmap with each type's slots, and for the stack the per-site
# cell map)"; the DONE-WHEN of that row IS this gate's exit code). THE DESIGN IS THE cto's RULING OF 2026-10-30, ARCH-GC-COMPILE-TIME-FRAME-MAPS 13.14.
#
# WHAT IT CLAIMS. Under SCRIP_GC_VALIDATE=1, after every collection's fix and slide, gc_validate_heap (gc_heap.c) walks the heap LINEARLY from the arena
# to the new top by block size and, for every block, looks its type up in gc_slot_table.c, one row per type, each row naming the C struct its payload is
# declared by and listing the pointer-bearing fields BY NAME through offsetof (a _Static_assert on sizeof per row, so a struct that grows breaks the
# build). A pointer-bearing word outside the arena passes; one inside it must lie in the interior of a live, non-FILL block, else it is EXPIRED and is
# named with its holder block's kind and slot offset, the pointee and the vacancy record. THE TABLE IS CUT FROM THE STRUCT DECLARATIONS, NOT FROM THE
# ASM MARK HANDLERS (13.14 (1): a table read from the handlers would validate the handlers against themselves and is refused), and it is never the
# mark's own table, file or generator (13.14 (4)). The summary line proves the walk's own premises: the heap parses end to end (badhead) and every
# block start has its START bit (nostart).
# AN UNROWED TYPE IS A REFUSAL, NEVER A PASS (13.14 (3)): a block whose type has no row is named in the summary (unrowed=<type>:<n>) and arm (1) is RED
# while any type seen in the arena is unrowed; arm (4) is RED while any HB_* type has no row. All the types are rowed as of SCRIP 7a432a57e (the eight
# private structs live in pattern_blocks.h and prolog_db_blocks.h); the one arm left red is (5), the stack half, and the gate cannot read green until it exists.
#
# THE UNTYPED CLASS (13.14, second sitting (3a)): HB_WSB and HB_WSC are rows of a distinct UNTYPED kind, counted untyped=<n> in the summary and never a
# zero-slot row; THE CLAIM'S LIMIT IS "every live TYPED slot": a workspace payload carries none by definition (its pointers are described by its owner's
# root visitor), the producer audit that types the pointer-bearing producers is hq_runtime's own row, and no word of such a block is sniffed.
# A type with no producer (HB_ZBLK) is a REFUSE row: a block of it seen is a finding (refused=<n>). The run form (13.14): HB_AGGP, HB_AGGB, HB_DINST, HB_DVEC
# and HB_PVEC are rows with a run of elements (offset, stride, count by size or by a 32-bit field), HB_AGGT, HB_ARR and HB_AGGV rows of header slots.
# THE LIMIT, VERBATIM FROM 13.14: sound always; complete only against vacated ground, a pointer into ground a survivor now reoccupies reads as live.
# WHAT ELSE IT DOES NOT CLAIM. (a) Road (a) (test_gate_gc_the_record_check_after_each_collection_names_a_misfixed_slot.sh) still checks only the slots
# the mark REGISTERED; this walk is the one that sees a slot the mark never registered. (b) ARBLK_t elements reached through an off-heap data pointer
# are not walked. (c) Arm (5) is RED until the stack half (the chain's frames' cells by the site's word-kind mask, behind zeta-layout 4a and 4b) exists.
#
# ARMS. (1) SILENT ON THE CURED TREE, WITH REACH AND NO UNROWED TYPE: six witnesses, stress 1 and 3, mode 3 and mode 4, 64 KB: every collection prints its
# [ZGC-VALIDATE-HEAP] summary, every summary reads unrowed=none and findings=0, stdout equals the expected output, and the witnesses that allocate DVEC,
# ARR or AGGV reach a laid block and validate a heap pointer (a run that reaches none is not a reading). (2) FAIL-ONCE, by a seam inside THIS instrument
# (CEO-1680: a seam only in an instrument, never in SCRIP): an LD_PRELOAD shim over out/interposable/libscrip_rt.so overwrites one heap-resident registry
# entry of rt_gc_fix_run with a copy of another, so the slot is never registered, never fixed, and invisible to road (a); on a program whose array sits
# above garbage that dies, the walk must name it AT the collection that moved the pointee, and road (a) must read zero on the same run. This arm needs
# only the rows of the blocks it plants through and so reads while arm (1) is still RED. (3) INERT WHEN OFF: no [ZGC-VALIDATE-HEAP] line without the knob
# and stdout equal to the knob-on run's. (4) COVERAGE: every HB_* type in gc_heap.h has a row in gc_slot_table.c; there is no leaf list, a string type
# and FILL are rows with zero slots. (5) THE STACK HALF exists.
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
cat > "$T/abovet.sno" <<'EOF'
*  a TABLE allocated above garbage that dies, so the first collection slides its table block, bucket vector and buckets down over dead ground
          G = DUPL('g',3000)
          G = DUPL('h',3000)
          T = TABLE()
          T['a'] = 'ALPHA'
          T['b'] = 'OMEGA'
          G = ''
          I = 0
LOOP      I = I + 1
          S = DUPL('z',100)
          GT(300,I) :S(LOOP)
          OUTPUT = T['a'] T['b']
END
EOF
WITS="$W/hb_arr.sno $W/hb_aggv.icn $T/above.sno $T/abovet.sno $W/hb_datblk.sno $W/hb_blob_span_defer.sno $W/hb_pl_two_hundred_choice_points_retained_in_one_gap.pl"
REACH="hb_arr hb_aggv above abovet"
printf 'ALPHAOMEGA\n' > "$T/hb_arr.exp"; printf '66\n' > "$T/hb_aggv.exp"; printf 'ALPHAOMEGA\n' > "$T/above.exp"; printf 'ALPHAOMEGA\n' > "$T/abovet.exp"
for w in $WITS; do
    [ -s "$w" ] || refuse "witness $w is missing"
    b="$(basename "${w%.*}")"
    [ -s "$T/$b.exp" ] || { [ -s "${w%.*}.ref" ] && cp "${w%.*}.ref" "$T/$b.exp"; } || refuse "no expected output for $b"
done
totals() { grep '^\[ZGC-VALIDATE-HEAP\] collection=' "$1" | awk '{u=0; for(i=3;i<=NF;i++){split($i,a,"="); if(a[1]=="unrowed"){ if(a[2]!="none"){u++; if(!first) first=a[2]} } else t[a[1]]+=a[2]}; n++; nu+=u} END{printf "%d %d %d %d %d %s\n", n, t["laid"], t["heap"], t["findings"], nu, (first ? first : "none")}'; }
bad=0
for w in $WITS; do
    b="$(basename "${w%.*}")"
    ( cd "$T" && "$ROOT/scrip" --compile --out="$T/$b.s" "$w" < /dev/null > /dev/null 2>&1 ) && gcc "$T/$b.s" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$T/$b.bin" 2> /dev/null || refuse "$b did not compile and link in mode 4"
    for s in 1 3; do
        for m in m3 m4; do
            if [ $m = m3 ]; then ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=$K SCRIP_GC_STRESS=$s SCRIP_GC_VALIDATE=1 timeout -k 5 300 "$ROOT/scrip" "$w" < /dev/null > "$T/o" 2> "$T/e" )
            else ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=$K SCRIP_GC_STRESS=$s SCRIP_GC_VALIDATE=1 timeout -k 5 300 "$T/$b.bin" < /dev/null > "$T/o" 2> "$T/e" ); fi
            rc=$?
            read -r n laid heap nf nu first < <(totals "$T/e")
            want=1; case " $REACH " in *" $b "*) [ "$laid" -gt 0 ] && [ "$heap" -gt 0 ] || want=0;; esac
            if [ "$rc" = 0 ] && [ "$n" -gt 0 ] && [ "$nf" = 0 ] && [ "$nu" = 0 ] && [ "$want" = 1 ] && cmp -s <(grep -v '^\[GC-' "$T/o") "$T/$b.exp"; then
                echo "  ok   (1) $m stress=$s $b: $n collections walked, $laid laid blocks, $heap heap pointers validated, no unrowed type, no finding, stdout as expected"
            else echo "  RED  (1) $m stress=$s $b: rc=$rc, $n summaries, laid=$laid heap=$heap, $nf findings, $nu summaries with an unrowed type (first: $first), reach=$want; $(grep -m1 'EXPIRED\|BADHEAD' "$T/e" | cut -c1-200)"; bad=1; fi
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
for fo in above:HB_ARR:HB_DVEC:HB_AGGV abovet:HB_AGGT:HB_AGGP:HB_AGGB; do
IFS=: read -r fb k1 k2 k3 <<< "$fo"
( cd "$T" && env -u SCRIP_HEAP_MB LD_LIBRARY_PATH="$T/lib" LD_PRELOAD="$T/shim.so" SCRIP_HEAP_KB=$K SCRIP_GC_STRESS=1 SCRIP_GC_VALIDATE=1 timeout -k 5 300 "$ROOT/scrip" "$T/$fb.sno" < /dev/null > "$T/fo" 2> "$T/fe" ) 2> /dev/null
nshim=$(grep -c '^\[SHIM\]' "$T/fe"); [ "$nshim" -gt 0 ] || refuse "the shim never found a heap-resident slot to leave unregistered in $fb ($(grep -c '^\[ZGC-VALIDATE-HEAP\] collection=' "$T/fe") summaries)"
nf=$(grep -c '^\[ZGC-VALIDATE-HEAP\] EXPIRED' "$T/fe"); na=$(grep -c '^\[ZGC-VALIDATE\] \(MISFIXED\|EXPIRED\)' "$T/fe")
first=$(grep -m1 '^\[ZGC-VALIDATE-HEAP\] EXPIRED' "$T/fe")
fc=$(echo "$first" | sed -n 's/.* collection=\([0-9]*\) .*/\1/p'); vc=$(echo "$first" | sed -n 's/.* by collection #\([0-9]*\).*/\1/p'); fk=$(echo "$first" | sed -n 's/.* kind=\(HB_[A-Z]*\) .*/\1/p')
if [ "$nf" -gt 0 ] && [ -n "$fc" ] && [ "$fc" = "$vc" ] && { [ "$fk" = $k1 ] || [ "$fk" = $k2 ] || [ "$fk" = $k3 ]; } && [ "$na" = 0 ]; then
    echo "  ok   (2) $fb: a slot left unregistered ($nshim collections) is named AT the collection that moved its pointee (#$fc, holder $fk), road (a) read $na findings on the same run: $(echo "$first" | cut -c1-210)"
else echo "  RED  (2) $fb: shim fired $nshim times; walk findings=$nf, first at collection '$fc' vs vacancy collection '$vc', holder '$fk' (want $k1, $k2 or $k3); road (a) findings=$na (must be 0)"; bad=1; fi
done
for w in $WITS; do
    b="$(basename "${w%.*}")"
    ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=$K SCRIP_GC_STRESS=1 timeout -k 5 300 "$ROOT/scrip" "$w" < /dev/null > "$T/off" 2> "$T/offe" )
    if ! grep -q 'ZGC-VALIDATE' "$T/offe" && cmp -s "$T/off" "$T/$b.on"; then echo "  ok   (3) $b: no validator line without the knob, stdout equal to the knob-on run"
    else echo "  RED  (3) $b: the knob-off run printed a validator line or a different stdout"; bad=1; fi
done
missing=""
for t in $(sed -n 's/^#define HB_\([A-Z0-9]*\) [0-9]*$/\1/p' "$ROOT/src/runtime/rt/gc_heap.h"); do
    grep -Eq "^static const gc_slot_row_t sr_[a-z0-9_]+ = \{ [A-Za-z0-9_]+, HB_$t," "$ROOT/src/runtime/rt/gc_slot_table.c" || missing="$missing HB_$t"
done
if [ -z "$missing" ]; then echo "  ok   (4) every HB_* type has a row in gc_slot_table.c"
else echo "  RED  (4) block types with no row in gc_slot_table.c:$missing"; bad=1; fi
if grep -q 'gc_validate_stack' "$ROOT/src/runtime/rt/gc_heap.c"; then echo "  ok   (5) the stack half exists (gc_validate_stack)"
else echo "  RED  (5) the stack half (the chain's frames' word-kind-mask cells, behind zeta-layout step 4b) is not built"; bad=1; fi
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
[ "$bad" = 0 ] && { echo "GATE PASS(0) [$G]: every live typed slot of every block type is validated after each collection, a never-registered slot is named at the collection that created it, the check is inert when off (tree SCRIP=$TREE)"; exit 0; }
echo "GATE RED(1) [$G]: see the RED arms above (tree SCRIP=$TREE)"; exit 1
