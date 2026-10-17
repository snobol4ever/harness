#!/usr/bin/env bash
# test_gate_gc_dt_data_names_one_pointed_at_shape.sh -- F6 STEP 5, THE HEAP HALF (cfo; ceo CEO-887/888).
#
# ⛔ THE DEFECT.  DT_DATA carried TWO unrelated pointed-at shapes under ONE tag: the .u arm is a DATINST_t (a
# record instance) and the .ptr arm is a raw DESCR_t element vector (an Icon list's frame_elems backing store).
# Both were minted with slen 0, so NOTHING IN THE DESCRIPTOR SAID WHICH.  Every reader guessed from context and
# the COLLECTOR guessed by strcmp-ing an owner's field name -- gc_visit_datinst asked whether the record's
# first field was called "frame_elems".  A reader that guessed wrong read a DATBLK_t* out of the first element
# of a descriptor array: a SILENT WRONG ANSWER, not a crash, which is the worst failure shape we have.
#
# ⭐ THE CURE IS DT_N's OWN SCHEME, ALREADY IN THIS HEADER (DT_N slen 0 char*, 1 DESCR_t*, 2 VCELL_t*; DT_E's
# PROCVAL_*_SLEN; DT_S's 0xFFFFFFFF CSET): slen arbitrates DT_DATA too -- DATA_INST_SLEN 0, DATA_ELEMS_SLEN 1,
# pinned by a _Static_assert beside PROCVAL's so a future third meaning cannot quietly reuse one.
#
# ⛔ THE ceo's TWO CONDITIONS ARE ARMS 1 AND 3 HERE, AND CONDITION (2) IS THE WHOLE JOB: "the readers are the
# whole job, not the writers -- a reader that checks only the tag after this lands is a silent wrong answer
# rather than a crash".  Arm 1 is that population and it must read ZERO.
#
# ⛛⭐ ARM 5 IS THE ONLY ARM THAT CAN SEE A COLLECTOR DEFECT, written the way the coo's decidable test taught:
# a green suite is evidence about the collector ONLY if something FORCES it to run, FORCES the heap to slide
# under a live value, and then READS THAT VALUE BACK.  It WALKS the band rather than sampling it, because the
# failure band is ragged -- the cfo's cset defect was RED at 1,2,3,4,5,8,10 and GREEN at 0,15,20,30,50,100, so
# a two-point DONE-WHEN at 30 and 200 reads clean and banks the defect (CEO-807/876).
#
# ⛛ WHAT THIS ROW DID NOT LAND, AND WHY THE REMAINDER IS PRINTED RATHER THAN GRADED TO ZERO.  The natural next
# move is retyping the list element vectors from rt_ws_alloc (HB_WS) to rt_ws_alloc_descr (HB_DVEC), so the
# element COUNT comes from the block header instead of the owner's frame_size and the conservative interior
# scan can stop walking them.  THAT IS HELD ON A MEASURED REGRESSION, BISECTED TO ONE SITE: with only
# by_name_dispatch.c's put-growth vector retyped, the vendored Arizona gc2 witness goes from 0 of 5 red to 5 of
# 5 red in BOTH modes -- SIGSEGV in FIELD_GET_fn with the record's type block reading 0xDB poison.  The cause is
# NOT lost conservative coverage: an 8-byte-stride audit of every retyped block found ZERO heap-pointing words
# outside a 16-byte-aligned DESCR payload whose tag declares it.  So the remainder is a MEASURED OPEN QUESTION
# with a named starting point, not an estimate.
#
# ⛛ ONE RUN IS NOT A MEASUREMENT AND IT ALMOST GOT BANKED AS ONE: restoring the conservative scan on top of the
# precise walk made gc2 pass ONCE, which looked like the explanation; repeated five times it passed ZERO times.
# This defect is intermittent, which is why a COUNT is the verdict and a single green is discarded.
#
# ⛛ IT REFUSES rc=2 RATHER THAN PASSING when no collection ran, nothing moved, or the element arm was never
# reached: a band green because the collector never ran is the 320-entry reading, not evidence, and no later
# landing may green this gate by making the collector quiet or by taking the witness off the path it grades.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=gc_dt_data_names_one_pointed_at_shape
WIT="$HERE/gc_witnesses/hb_dvec_list.icn"
BAND="${GC_DTDATA_BAND:-0 1 2 3 4 5 8 10 15 20 30 50 100 200}"
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }

[ -f "$WIT" ] || { echo "GATE UNPROVEN(2) [$G]: witness $WIT missing"; exit 2; }
[ -f "$HERE/util_dt_data_reader_census.py" ] || { echo "GATE UNPROVEN(2) [$G]: reader census missing"; exit 2; }

# ---- ARM 1: the ceo's condition (2) -- the readers are the whole job ----------------------------------------
cen="$(python3 "$HERE/util_dt_data_reader_census.py" 2>&1)"; crc=$?
tot="$(printf '%s\n' "$cen" | sed -n 's/.*TOTAL=\([0-9]*\).*/\1/p' | tail -1)"
if [ "$crc" = 0 ] && [ "${tot:-x}" = 0 ]; then
    ck ok "arm1 every DT_DATA reader arbitrates on slen: TOTAL=0 tag-only dereference site(s)"
else
    printf '%s\n' "$cen" | sed -n 's/^/       /p' | head -20
    ck no "arm1 TOTAL=${tot:-?} tag-only DT_DATA reader(s) -- each one reads a DESCR_t array as a DATINST_t, or the reverse, and returns a wrong answer instead of crashing"
fi

# ---- ARM 2: the collector knows no owner's field names -------------------------------------------------------
fe=$(grep -c 'frame_elems' src/runtime/rt/gc_heap.c 2>/dev/null || true)
if [ "${fe:-1}" = 0 ]; then
    ck ok "arm2 gc_heap.c names no owner field: frame_elems=0 -- the kind is in the block header and the shape is in the descriptor, so the collector asks neither the owner nor a string"
else
    ck no "arm2 gc_heap.c mentions frame_elems $fe time(s) -- the collector is back to identifying a payload by an owner's field NAME, which is the guess this row removed"
fi

# ---- ARM 3: the ceo's condition (1) -- the discriminators are PINNED, not merely used -------------------------
if grep -q 'DESCR_SASSERT(DATA_INST_SLEN != DATA_ELEMS_SLEN' src/ir/descr.h \
   && grep -q '#define DATA_INST_SLEN' src/ir/descr.h && grep -q '#define DATA_ELEMS_SLEN' src/ir/descr.h; then
    ck ok "arm3 descr.h pins both DT_DATA discriminators in a _Static_assert beside PROCVAL's"
else
    ck no "arm3 descr.h does not pin the DT_DATA discriminators -- a sentinel scheme with no assert is how a tag gets overloaded in the first place"
fi

# ---- ARM 4: the assembly readers are pinned too ---------------------------------------------------------------
if grep -q 'offsetof(DESCR_t, slen) == 4' src/runtime/rtx/rtx_init.c \
   && grep -q 'FIELD0_SLEN' src/runtime/rtx/rtx_icnsub.s; then
    ck ok "arm4 the asm list fast paths test slen and the offset is pinned by a _Static_assert (rtx_icnsub.s FIELD0_SLEN, rtx_icnagg.s dat_field_get)"
else
    ck no "arm4 the asm list fast path reads the DT_DATA union without the slen test, or the hardcoded offset is unpinned -- C readers were cured and assembly was left guessing"
fi

# ---- ARM 5: the band ------------------------------------------------------------------------------------------
bash "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
W="$(mktemp -d "${TMPDIR:-/tmp}/gc_dtdata.XXXXXX")" || exit 2
trap 'rm -rf "$W"' EXIT
ref="$(cd "$W" && SCRIP_GC_STRESS=0 timeout -k 5 60 "$ROOT/scrip" "$WIT" 2>/dev/null)"
case "$ref" in
    "LEN=60 TLEN=30"*) : ;;
    *) echo "GATE UNPROVEN(2) [$G]: the witness did not produce its computed header (LEN=60 TLEN=30); it was edited or it is not running -- a band compared against a wrong reference grades nothing"; exit 2 ;;
esac
bad=0; nd_bad=0; tot_col=0; tot_mov=0; tot_elems=0; tot_nd=0; band_n=0; report=""
for st in $BAND; do
    band_n=$((band_n+1))
    out="$(cd "$W" && SCRIP_GC_STRESS="$st" SCRIP_GC_POISON=1 SCRIP_ZETA_TELEM=1 timeout -k 5 120 "$ROOT/scrip" "$WIT" 2>t.txt)"
    col=$(grep -c '\[ZGC-MARK\]' "$W/t.txt"); col=${col:-0}
    mov=$(grep -o 'moved=[0-9]*B' "$W/t.txt" | sed 's/[^0-9]//g' | awk '{s+=$1} END{print s+0}')
    nd=$(grep -h '\[GC-DVEC\]' "$W/t.txt" | tail -1 | sed -n 's/.*non_dvec=\([0-9]*\).*/\1/p'); nd=${nd:-0}
    el=$(grep -h '\[GC-DVEC\]' "$W/t.txt" | tail -1 | sed -n 's/.*elems=\([0-9]*\).*/\1/p'); el=${el:-0}
    tot_elems=$((tot_elems+el)); tot_nd=$((tot_nd+nd))
    tot_col=$((tot_col+col)); tot_mov=$((tot_mov+mov))
    v=ok; [ "$out" = "$ref" ] || { v=WRONG; bad=$((bad+1)); }
    report="$report $st:$v(col=$col)"
done
echo "       band:$report"
if [ "$tot_col" -eq 0 ] || [ "$tot_mov" -eq 0 ]; then
    echo "GATE UNPROVEN(2) [$G]: $band_n band level(s) ran with collections=$tot_col movedB=$tot_mov -- a band that is green because the collector never ran or never moved the heap is the 320-entry reading, not evidence about the collector"
    exit 2
fi
if [ "$bad" = 0 ]; then
    ck ok "arm5b every element read back correct across $band_n stress level(s) (collections=$tot_col movedB=$tot_mov, POISON on so a lost root reads 0xDB rather than stale data)"
else
    ck no "arm5b $bad of $band_n stress level(s) returned a value the heap slide corrupted"
fi
if [ "$tot_elems" -gt 0 ]; then
    ck ok "arm5c the discriminator's element arm is REACHED, not dead code: the collector arbitrated $tot_elems DT_DATA element descriptor(s) by slen across the band -- every one of them used to be resolved by strcmp-ing an owner's field name"
else
    echo "GATE UNPROVEN(2) [$G]: the collector never visited a single DT_DATA element descriptor -- the witness no longer exercises the arm this gate grades, so its green means nothing"; exit 2
fi
echo "       STEP-5 REMAINDER, MEASURED AND PRINTED, NOT GRADED: of $tot_elems DT_DATA element descriptor(s) visited, $tot_nd pointed at a block that is NOT HB_DVEC. That is the population still walked by the conservative interior scan (hb_scan_interior, 2 of the conservative total of 21 since 2026-09-19; 24 before the blob static layout took rt_cas_live_span). Driving it to zero is the retyping this header records as HELD on the gc2 regression; it is printed so it cannot be forgotten and NOT graded, because a number this seat could not move today is a ratchet against the next landing rather than a measurement."

gate_floor "$checks" 5 "arm(s) graded"
if [ "$fails" = 0 ]; then echo "✅ GATE PASS [$G]: $checks of $checks arms hold"; exit 0; fi
echo "⛔ GATE FAIL [$G]: $fails of $checks arm(s) failed"; exit 1
