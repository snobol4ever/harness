#!/usr/bin/env bash
# test_gate_gc_the_frame_map_anchor_is_the_frame_base_even_when_the_poll_floor_is_above_it.sh -- cto, 2026-09-23,
# MODE DECTET; row gc-a-site-that-refuses-every-poll-form-names-an-unrooted-holder-starting-with-the-concat-slot-capture
# (row 867, the ceo's kill-map lead) and hq_icon's mindfa/ilib mode-4 witnesses; CEO-1181/1183.
#
# WHAT WAS THERE. gc_walk_range found a frame's DT_MAP cell, computed the frame's base as cell - map_off, and then
# CLAMPED that base up to the poll's floor whenever the floor sat above it -- which is every poll taken while the
# spine is shallower than the map's declared extent. The clamped value was handed to gc_walk_interior as the ANCHOR,
# so every layout offset in the frame was applied from the return-address slot instead of the frame base: the first
# DESCR entry read the poll site's return address as a tag (the [GC-WALK-BADTAG] lines carried the site's low byte
# in v and the ZRES tag word in p), every cell in the frame was read eight bytes out of phase, and the fresh concat
# result sitting in the ZRES cell right above the return address was never visited and was reclaimed under the poll.
# Measured under gdb on hb_concat_slot_capture_across_a_collection.sc at stress 1: collections 4..12 walked the cell
# (base eight bytes above the floor), collections 13 onward did not (base clamped to the floor), and exactly those
# results came back as runs of 0xDB. That is why the site "refused every poll form": no poll form can root a cell the
# walk reads at the wrong address. The same defect segfaulted Arizona mindfa and ilib in mode 4 at the tiny arena.
#
# THE CURE (gc_heap.c). The anchor stays the true base; only the SPINE word walk starts at max(base, floor); and a
# layout entry clipped at the floor is clipped on its own 16-byte cell grid, never to the floor itself, because the
# floor is a return-address slot and always sits one word below the first live cell.
#
# ARMS. (1) BAND+PHASE: the concat witness matches its oracle-cut ref at stress 1 and 5 at the mandatory tiny arena
# with SCRIP_GC_MAPS=3, and every [GC-WALK] pop=cstack line reads i_phase=0 -- i_phase counts a bad-tag cell whose
# pointer word is itself a known tag, the signature of a cell read out of phase. (2) EXERCISE: at least one of those
# collections reads s_words=0, i.e. the poll's floor was at or above the frame's declared base -- the shape this gate
# exists for; a band that never reached it measured a configuration, not the defect. (3) MODE 4: the recursive
# marklists witness (Arizona mindfa, ref cut from the Icon distribution's .std) compiles, links and matches its ref
# at the tiny arena with collections>0 -- on origin 90392846a it dies rc=139 in the walk.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"; cd "$R" || exit 2
# THE WITNESS IS THE ONE THAT STILL PRODUCES THE SHAPE (cto 2026-09-24, the seventeen-red row): the Snocone concat
# witness this gate was cut on stopped producing a cstack walk with the poll floor above the frame base once the zd
# planner moved its assignments onto the recording poll form (CTO-159), so both stress points read exercised=0 and
# the gate was red for want of a shape, not for a phase.  A sweep of the witness set at stress 1 found hb_scan_nested
# producing it in 6021 of 12023 walks (1204 of 2405 at stress 5), phase 0 throughout, answering its iconx ref.
W=../harness/scripts/gc_witnesses/hb_scan_nested.icn
REF=../harness/scripts/gc_witnesses/hb_scan_nested.ref
M=../harness/scripts/gc_witnesses/hb_frame_map_anchor_recursive_marklists_mode4
[ -f "$W" ] && [ -f "$REF" ] && [ -f "$M.icn" ] && [ -f "$M.in" ] && [ -f "$M.ref" ] || { echo "REFUSE(2): a witness or ref is missing"; exit 2; }
TMP=$(mktemp -d) || exit 2; trap 'rm -rf "$TMP"' EXIT
fail=0; exercised=0
# ⛔ THE LAYOUT IS FIXED (setarch -R) BECAUSE THE PHASE COUNT IS LAYOUT-SENSITIVE BY CONSTRUCTION (cto 2026-09-24): a
# slot the map declares DESCR that holds a STACK ADDRESS (hb_scan_nested main+464, v=0xc0 slen=0x7ffd p=nil under one
# ASLR draw) reads as a bad tag only when that address's low byte is not a known tag, so the same tree read 12021 of
# 12023 walks out of phase in one run and 0 in the next; the slot is a map-declaration finding with its own row, and
# this gate grades the anchor's phase under one layout so its verdict is the tree's, not the draw's.
for st in 1 5; do
  env -u SCRIP_HEAP_MB SCRIP_GC_EXERCISE=1 SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=$st SCRIP_GC_MAPS=3 timeout -k 5 60 setarch -R ./scrip "$W" < /dev/null > "$TMP/o.$st" 2> "$TMP/e.$st"
  rc=$?
  col=$(grep -o 'collections=[0-9]*' "$TMP/e.$st" | tail -1); col=${col#collections=}; col=${col:-0}
  walks=$(grep -c 'GC-WALK\] pop=cstack' "$TMP/e.$st"); nofield=$(grep 'GC-WALK\] pop=cstack' "$TMP/e.$st" | grep -vc 'i_phase='); phased=$(grep 'GC-WALK\] pop=cstack' "$TMP/e.$st" | grep -vc 'i_phase=0 '); above=$(grep 'GC-WALK\] pop=cstack' "$TMP/e.$st" | grep -c ' s_words=0 ')
  [ "$above" -gt 0 ] && exercised=1
  if [ $rc -ne 0 ]; then echo "RED stress=$st rc=$rc collections=$col"; fail=1
  elif ! diff -q "$TMP/o.$st" "$REF" > /dev/null 2>&1; then echo "RED stress=$st WRONG ANSWER collections=$col ($(diff "$TMP/o.$st" "$REF" | grep -c '^<') line(s) differ)"; fail=1
  elif [ "$walks" = 0 ]; then echo "RED stress=$st the walk report printed no cstack line -- SCRIP_GC_MAPS=3 measured nothing"; fail=1
  elif [ "$nofield" -gt 0 ]; then echo "RED stress=$st $nofield of $walks walk line(s) carry no i_phase field -- the collector's report is older than this gate and the phase was not measured"; fail=1
  elif [ "$phased" -gt 0 ]; then echo "RED stress=$st $phased of $walks collection(s) read a cell out of phase (i_phase>0): the anchor is not the frame base"; fail=1
  else echo "ok  stress=$st PASS collections=$col walks=$walks phase=0 floor_above_base=$above"; fi
done
[ "$exercised" = 1 ] || { echo "RED no collection had its poll floor above the frame's declared base (s_words=0) -- the band never reached the shape this gate grades"; fail=1; }
if timeout -k 5 60 ./scrip --compile -o "$TMP/m.s" "$M.icn" < /dev/null 2>"$TMP/m.cerr" && gcc -c "$TMP/m.s" -o "$TMP/m.o" 2>/dev/null && gcc "$TMP/m.o" -Lout -lscrip_rt -lm -lpthread -Wl,-rpath,"$R/out" -o "$TMP/m" 2>/dev/null; then
  env -u SCRIP_HEAP_MB SCRIP_GC_EXERCISE=1 SCRIP_HEAP_KB=128 timeout -k 5 60 "$TMP/m" < "$M.in" > "$TMP/m.out" 2> "$TMP/m.err"; rc=$?
  col=$(grep -o 'collections=[0-9]*' "$TMP/m.err" | tail -1); col=${col#collections=}; col=${col:-0}
  if [ $rc -ne 0 ]; then echo "RED mode4 marklists rc=$rc collections=$col"; fail=1
  elif ! diff -q "$TMP/m.out" "$M.ref" > /dev/null 2>&1; then echo "RED mode4 marklists WRONG ANSWER collections=$col ($(diff "$TMP/m.out" "$M.ref" | grep -c '^[<>]') line(s) differ)"; fail=1
  elif [ "$col" = 0 ]; then echo "RED mode4 marklists collected zero times -- a configuration, not an exercise"; fail=1
  else echo "ok  mode4 marklists PASS collections=$col"; fi
else echo "RED could not compile or link the mode-4 marklists witness"; fail=1; fi
[ $fail = 0 ] && echo "GREEN the walk anchors every frame map at the frame base: phase 0 at every collection, the floor-above-base shape exercised, and the recursive marklists witness matches its ref in mode 4 at the tiny arena"
exit $fail
