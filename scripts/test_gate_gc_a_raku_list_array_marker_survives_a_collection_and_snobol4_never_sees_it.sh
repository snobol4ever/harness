#!/usr/bin/env bash
# test_gate_gc_a_raku_list_array_marker_survives_a_collection_and_snobol4_never_sees_it.sh -- THE LIST / ARRAY / SLIP / PAIR / JUNCTION MARKER IN ARBLK.proto,
# BOTH HALVES THE CTO NAMED (cto 2026-10-03, q-raku-list-array-marker-on-arblk-proto: "A gate holds the collector half you measured -- a static address in
# ARBLK.proto survives a forced collection untouched and unvisited ... a Raku list and an array side by side, both printed after the collection -- plus your
# List-versus-Array oracle probes, both modes"; and "a polyglot hands a Raku list to SNOBOL4 code and PROTOTYPE() must not print your marker").
# Row raku-arrays-lists-and-hashes-are-typed-storage-no-delimiter-joined-strings-lon-2026-09-28 (ceo CEO-1349, CEO-1479).
#
# THE DESIGN THIS HOLDS. A Raku aggregate is a typed DT_A whose ARBLK.proto is NULL (an Array) or the ADDRESS of one of six static const char arrays in
# by_name_dispatch.c (List, Slip, Pair, and the four junction flavours), compared by address and never by text. rt_gc_visit_raw returns at once when
# gc_blk_of() finds no heap block (gc_heap.c rt_gc_visit_raw), so the collector neither marks nor relocates a static address; this gate proves the marker
# is STILL the marker after collections, by printing .WHAT of a List and an Array side by side, nested, after 600 allocations between the writes.
# SNOBOL4's two readers of proto -- agg_prototype in aggregates.c (PROTOTYPE) and dump_arr_proto in core.c (DUMP) -- take a proto only when it begins with a
# digit or a minus, which is SNOBOL4's own prototype format ("3", "1:3", "3,2", "-1:1"); pattern_match.c's sort_is_rowarr and sort_proto_dims look for a
# comma and the markers hold none. The polyglot arm runs a SNOBOL4 program over a Raku Array and a Raku List and its refs are cut by sbl -bf on
# same-shaped ARRAY('0:2') and ARRAY('0:1').
# The .ref of the witness is cut by Rakudo (/usr/bin/raku), never from ./scrip. A stale binary, a missing witness or no gcc REFUSES rc=2.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=gc_a_raku_list_array_marker_survives_a_collection_and_snobol4_never_sees_it
D="$HERE/gc_witnesses"
WIT="$D/rk_list_array_marker.raku"; REF="$D/rk_list_array_marker.ref"; PA="$D/rk_marker_poly_a.raku"; PB="$D/rk_marker_poly_b.sno"; PREF="$D/rk_marker_poly.ref"
for f in "$WIT" "$REF" "$PA" "$PB" "$PREF"; do [ -f "$f" ] || { echo "GATE UNPROVEN(2) [$G]: witness or ref missing ($f)"; exit 2; }; done
bash "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$G]: gcc not found -- mode 4 cannot be linked"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gc_rkmark.XXXXXX")" || exit 2
trap 'rm -rf "$W"' EXIT
BAND="${GC_RKMARK_BAND:-0 1 3 5}"
unset SCRIP_HEAP_MB; export SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-128}" SCRIP_HEAP_MAX_MB="${SCRIP_HEAP_MAX_MB:-512}"
( cd "$W" && timeout -k 5 180 "$ROOT/scrip" --compile -o rk.s "$WIT" < /dev/null 2>c.err && gcc rk.s -L "$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o rk 2>l.err ) || { echo "GATE UNPROVEN(2) [$G]: mode-4 compile or link of the witness failed: $(head -2 "$W/c.err" "$W/l.err" 2>/dev/null | tr '\n' ' ' | cut -c1-200)"; exit 2; }
( cd "$W" && timeout -k 5 180 "$ROOT/scrip" --compile -o pm.s "$PB" "$PA" < /dev/null 2>pc.err && gcc pm.s -L "$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o pm 2>pl.err ) || { echo "GATE UNPROVEN(2) [$G]: mode-4 compile or link of the polyglot failed: $(head -2 "$W/pc.err" "$W/pl.err" 2>/dev/null | tr '\n' ' ' | cut -c1-200)"; exit 2; }
echo "arena: SCRIP_HEAP_KB=$SCRIP_HEAP_KB SCRIP_HEAP_MAX_MB=$SCRIP_HEAP_MAX_MB (a collector window shrunk so the stress band collects; the heap itself is the shipped one)"
want="$(cat "$REF")"; pwant="$(cat "$PREF")"; bad=0; runs=0
for mode in m3 m4; do line="  witness $mode"
  for s in $BAND; do runs=$((runs+1))
    if [ "$mode" = m3 ]; then got="$(SCRIP_GC_STRESS=$s timeout -k 5 180 "$ROOT/scrip" "$WIT" < /dev/null 2>/dev/null)"; else got="$(SCRIP_GC_STRESS=$s timeout -k 5 180 "$W/rk" < /dev/null 2>/dev/null)"; fi
    if [ "$got" = "$want" ]; then line="$line stress=$s:ok"; else line="$line stress=$s:RED"; bad=$((bad+1)); fi
  done; echo "$line"; done
for mode in m3 m4; do runs=$((runs+1))
  if [ "$mode" = m3 ]; then pgot="$(timeout -k 5 60 "$ROOT/scrip" "$PB" "$PA" < /dev/null 2>/dev/null)"; else pgot="$(timeout -k 5 60 "$W/pm" < /dev/null 2>/dev/null)"; fi
  if [ "$pgot" = "$pwant" ]; then echo "  polyglot $mode: ok (SNOBOL4 PROTOTYPE of a Raku Array and a Raku List: $(printf '%s' "$pgot" | tr '\n' ' '))"; else echo "  polyglot $mode: RED got [$(printf '%s' "$pgot" | tr '\n' ' ')] want [$(printf '%s' "$pwant" | tr '\n' ' ')]"; bad=$((bad+1)); fi
done
echo "population: the witness (2 modes x $(echo $BAND | wc -w) stress levels, a List, an Array and a nested List side by side, .WHAT printed after 600 allocations) and the polyglot (2 modes), $runs runs against Rakudo and sbl refs"
if [ "$bad" -ne 0 ]; then echo "GATE FAIL(1) [$G]: $bad of $runs runs lost a List/Array marker across a collection, or let SNOBOL4 read a Raku marker as a prototype"; exit 1; fi
echo "GATE PASS(0) [$G]: a static marker in ARBLK.proto survives the stress band untouched in both modes, and SNOBOL4 reads a Raku Array and List as 0:2 and 0:1 ($runs runs, 0 red)"
