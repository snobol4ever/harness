#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_the_spine_walk_is_told_its_cells.sh -- STEP 4b OF THE ZETA-LAYOUT PLAN (ARCH-GC-COMPILE-TIME-FRAME-MAPS 16 step (3); STEPS.tsv row 4b; the cto's R3), the finish line of
# the row zeta-layout-step-4b-the-walk-reads-the-mask-the-search-deleted-ceo-2019: THE SPINE GAP WALK VISITS EXACTLY THE CELLS THE SITE'S MASK NAMES, AND THE SEARCH IS GONE.
#
# WHAT IT MEASURES. Under SCRIP_GC_CHAIN_CHECK=3 the C spine walk (gc_sw_frame, the slow path) runs a dry copy of the old search over each frame's gap window [s->p, slo) beside the
# site's third-quad mask and prints one [GC-TOLD] SUMMARY per walk: frames; masked (a rule 0 or 4 site, the only rules that carry a mask); agree (a cell both name); search_only (a cell the
# search accepts that the mask does not name -- the cells a told walk would FAIL TO VISIT); so_unmasked (those on sites of any other rule); mask_only (a pointer-bearing cell the mask names and the
# search rejects) and mask_scalar (a scalar cell the mask names, harmless); outside (a mask bit beyond its window); nosite_cells (cells the search accepts in a gap with no site of its own);
# hdr_cells, blob_cells and tail_cells (cells the search accepts in the frame HEADER, the blob gap and the tail, where section 16 gives no mask). BIT q OF THE MASK NAMES THE WORD AT r + 8q,
# r the address just above the return slot, q below depth/8: measured, and the gate's neighbour test_gate_gc_site_table_entries_are_three_quads_and_carry_their_word_kind_mask says [r+8, r+depth).
#
# ARMS. (1) THE CENSUS: over the eight zeta-layout witnesses (mode 3, stress 3, 128 KB, one at a time through the run slot) every walk's search_only and mask_only read 0 and every
# witness's output equals its ref; RED while any cell is named by one side only. (2) REACH: the SNOBOL4 and Pascal witnesses have masked frames and agreeing cells (a run that reaches no masked
# site is not a reading). (3) NO SEARCH: rtx_gc.s carries no .Lsw_reject label and no use of it (the STEPS.tsv grepmax bar, 0). (4) NO UNMASKED GAP CELLS: so_unmasked, nosite_cells,
# hdr_cells, blob_cells and tail_cells read 0 (the other languages' gaps are told or hold nothing the search accepts).
# As of its first landing (SCRIP gc_heap.c census, hq_collector 2026-10-30) arms 1, 3 and 4 read RED BY MEASUREMENT: the mask names about a fifth of the cells the search accepts at the SNOBOL4
# sites and no cell at the Prolog, Raku and Icon sites (rule 1 and 2 carry no mask), and .Lsw_reject stands 24 times. The gate is the measurement, not a bar met.
# --one WITNESS-STEM runs one witness; rc 0 every arm holds; rc 1 an arm failed; rc 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; CORPUS="$(cd "$HERE/../../corpus" && pwd)"; G="$(basename "${BASH_SOURCE[0]}" .sh)"
refuse() { echo "GATE REFUSE(2) [$G]: $*"; exit 2; }
[ -x "$ROOT/scrip" ] || refuse "no $ROOT/scrip -- run make"
"$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
RUN="$HERE/util_run_slot.sh"; [ -x "$RUN" ] || [ -f "$RUN" ] || refuse "no $RUN"
Z="$CORPUS/tests/shared/zeta_layout"; [ -d "$Z" ] || refuse "no zeta_layout witnesses at $Z"
ST="${GATE_TOLD_STRESS:-3}"
ONE=""; [ "${1:-}" = "--one" ] && ONE="${2:-}"
T="$(mktemp -d)" || refuse "no scratch dir"; trap 'rm -rf "$T"' EXIT
bad=0; reach_sno=0; reach_pas=0
tot_so=0; tot_mo=0; tot_un=0; tot_ns=0; tot_hd=0; tot_bl=0; tot_tl=0
for w in "$Z"/zl0[1-8]_*; do
    case "$w" in *.ref) continue;; esac
    b="$(basename "${w%.*}")"
    [ -n "$ONE" ] && [ "$b" != "$ONE" ] && continue
    ref="${w%.*}.ref"; [ -s "$ref" ] || refuse "no ref for $b"
    ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=$ST SCRIP_GC_CHAIN_CHECK=3 timeout -k 5 900 bash "$RUN" "$ROOT/scrip" "$w" < /dev/null > "$T/o" 2> "$T/e" ); rc=$?
    same=0; cmp -s "$T/o" "$ref" && same=1
    read -r walks masked agree so un mo ms ns hd bl tl < <(grep '^\[GC-TOLD\] SUMMARY' "$T/e" | awk '{for(i=3;i<=NF;i++){split($i,a,"=");t[a[1]]+=a[2]}; n++} END{printf "%d %d %d %d %d %d %d %d %d %d %d\n", n, t["masked"], t["agree"], t["search_only"], t["so_unmasked"], t["mask_only"], t["mask_scalar"], t["nosite_cells"], t["hdr_cells"], t["blob_cells"], t["tail_cells"]}')
    tot_so=$((tot_so + so)); tot_mo=$((tot_mo + mo)); tot_un=$((tot_un + un)); tot_ns=$((tot_ns + ns)); tot_hd=$((tot_hd + hd)); tot_bl=$((tot_bl + bl)); tot_tl=$((tot_tl + tl))
    case "$b" in zl01*|zl02*) [ "$masked" -gt 0 ] && [ "$agree" -gt 0 ] && reach_sno=$((reach_sno + 1));; zl07*) [ "$masked" -gt 0 ] && [ "$agree" -gt 0 ] && reach_pas=1;; esac
    echo "  READ $b stress=$ST rc=$rc output=$([ $same = 1 ] && echo ref || echo DIFFERS) walks=$walks masked=$masked agree=$agree search_only=$so so_unmasked=$un mask_only=$mo mask_scalar=$ms nosite_cells=$ns hdr_cells=$hd blob_cells=$bl tail_cells=$tl"
    [ "$rc" = 0 ] && [ "$same" = 1 ] || { echo "  RED  (1) $b: rc=$rc or output differs from the ref"; bad=1; }
done
if [ -z "$ONE" ]; then
    if [ "$tot_so" = 0 ] && [ "$tot_mo" = 0 ]; then echo "  ok   (1) the mask and the search name the same cells over the eight witnesses"
    else echo "  RED  (1) $tot_so cells the search accepts and the mask does not name; $tot_mo pointer-bearing cells the mask names and the search rejects"; bad=1; fi
    if [ "$reach_sno" -ge 1 ] && [ "$reach_pas" = 1 ]; then echo "  ok   (2) masked sites reached: $reach_sno SNOBOL4 witness(es) and the Pascal witness have agreeing cells"
    else echo "  RED  (2) no masked site reached (snobol4 witnesses with agreement: $reach_sno, pascal: $reach_pas) -- not a reading"; bad=1; fi
fi
nrej="$(grep -c 'Lsw_reject' "$ROOT/src/runtime/rtx/rtx_gc.s")"
if [ "$nrej" = 0 ]; then echo "  ok   (3) rtx_gc.s has no .Lsw_reject"; else echo "  RED  (3) rtx_gc.s still carries .Lsw_reject $nrej times (the bar is 0)"; bad=1; fi
if [ -z "$ONE" ]; then
    if [ "$tot_un" = 0 ] && [ "$tot_ns" = 0 ] && [ "$tot_hd" = 0 ] && [ "$tot_bl" = 0 ] && [ "$tot_tl" = 0 ]; then echo "  ok   (4) no cell is accepted by the search where the mask is absent"
    else echo "  RED  (4) cells the search accepts where no mask exists: unmasked-rule sites $tot_un, gap frames with no site $tot_ns, headers $tot_hd, blob gaps $tot_bl, tails $tot_tl"; bad=1; fi
fi
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
[ "$bad" = 0 ] && { echo "GATE PASS(0) [$G]: the spine walk visits exactly the cells the sites' masks name and the search is gone (tree SCRIP=$TREE)"; exit 0; }
echo "GATE RED(1) [$G]: see the RED arms above (tree SCRIP=$TREE)"; exit 1
