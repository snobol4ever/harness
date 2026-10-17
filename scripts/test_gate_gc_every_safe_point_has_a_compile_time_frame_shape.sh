#!/usr/bin/env bash
# test_gate_gc_every_safe_point_has_a_compile_time_frame_shape.sh -- EVERY ACTIVATION FRAME NAMES ITS COMPILE-TIME MAP IN BOTH MEDIA, AND NO FRAME CARRIES A MARKER
# (cto 2026-09-17, CTO-65; re-cut at ARCH-GC section 13 STEP B by hq_collector 2026-10-11: the map cell the frames used to store is gone, the chain finds a frame by its
# return PC through the per-site table; law RULES.md FACT RULE THE COLLECTOR GUESSES NOTHING, CEO-812).
#
# WHAT IT HOLDS. (1) TAGS: descr.h and descr_tags.inc carry DT_RAW, carry NO frame-marker tag, and the tag-layout verifier agrees.
# (2) STATIC, MODE 4: for every benchmark program that compiles, the .s carries one .Lgcmap_<graph> map per frame graph, one prologue anchor note (`# GCANCHOR <map label> <the
# frame's reserved cell>`, text-only, zero bytes: the census anchors a frame's base with it, the machine code stores nothing there) per map, NO store of a map-cell tag, and a
# counted __gc_frame_maps table whose count equals the number of maps. (3) COST: util_gc_descr_cell_census.py runs and its frame growth reads under the 25 percent ceiling of
# section 7 F2. (4) EVERY STORED-PATTERN BLOB prologue (push rbp; mov rbp, rsp; sub rsp, N) names its map on the line after the carve, at or under the declared ceiling.
# The live arms of the old gate (seven frontends under SCRIP_GC_MAPS_CHECK, the planted wrong cell) went with the cell; the chain over the maps is read live, per front end and per
# mode, by test_gate_gc_the_chain_over_the_maps_finds_every_frame_by_return_pc.sh.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
CORPUS="$ROOT/../corpus/benchmarks"; [ -d "$CORPUS" ] || { echo "REFUSE(2): corpus/benchmarks not beside SCRIP"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
bad=0
n1=$(grep -cE 'DT_MAP' src/ir/descr.h src/ir/descr_tags.inc | awk -F: '{s+=$2} END{print s+0}'); n2=$(grep -c '^#define DT_RAW *0x98' src/ir/descr_tags.inc); n3=$(grep -oE 'DT_RAW *= *0x98' src/ir/descr.h | wc -l)
if [ "$n1" -eq 0 ] && [ "$n2" -eq 1 ] && [ "$n3" -eq 1 ] && python3 ../harness/scripts/util_tag_layout_verify.py >/dev/null 2>&1; then echo "  arm 1 PASS: DT_RAW in both tag sources, no frame-marker tag, layout verifier green"; else echo "  arm 1 RED: tag sources read marker=$n1 raw_inc=$n2 raw_h=$n3, or the layout verifier is red"; bad=1; fi
maps=0; cells=0; tabs=0; progs=0; skipped=0
for f in "$CORPUS"/*/*.sno "$CORPUS"/*/*.sc "$CORPUS"/*/*.icn "$CORPUS"/*/*.pl "$CORPUS"/*/*.reb "$CORPUS"/*/*.raku "$CORPUS"/*/*.pas; do
    [ -f "$f" ] || continue
    if ! timeout -k 5 120 ./scrip --compile "$f" > "$W/p.s" 2>/dev/null; then skipped=$((skipped+1)); continue; fi
    progs=$((progs+1))
    m=$(grep -c '^\.Lgcmap_[^ ]*:$' "$W/p.s"); c=$(grep -c '# GCANCHOR \.Lgcmap_' "$W/p.s"); t=$(awk '/^__gc_frame_maps:/{print $NF; exit}' "$W/p.s")
    maps=$((maps+m)); cells=$((cells+c)); tabs=$((tabs+${t:-0}))
    if { [ "$m" -lt 1 ] && grep -q '^main_α:\|^main_\xce\xb1:' "$W/p.s"; } || [ "$m" -ne "$c" ] || [ "${t:-0}" -ne "$m" ]; then echo "  arm 2 RED: $(basename "$f") maps=$m anchors=$c table_count=${t:-0}"; bad=1; fi
done
if [ "$progs" -ge 60 ]; then echo "  arm 2 PASS: $progs programs compiled ($skipped refused by the frontend), maps=$maps anchors=$cells table_entries=$tabs, equal per program"; else echo "  arm 2 RED: only $progs programs compiled"; bad=1; fi
if python3 ../harness/scripts/util_gc_descr_cell_census.py > "$W/census.txt" 2>/dev/null; then g=$(tail -1 "$W/census.txt" | grep -o 'growth_pct=[0-9.]*' | cut -d= -f2); if awk -v g="${g:-100}" 'BEGIN{exit !(g < 25)}'; then echo "  arm 3 PASS: $(tail -1 "$W/census.txt")"; else echo "  arm 3 RED: frame growth ${g:-?} percent is at or above the 25 percent ceiling"; bad=1; fi; else echo "  arm 3 RED: the cell census did not run"; bad=1; fi
BLOB_CEILING=0
blobcnt() { awk '{ if (want) { if ($0 !~ /GCANCHOR \.Lgcmap_/) c++; want = 0 } if (p2 && $1=="sub" && $2=="rsp,") want = 1; p2 = (p1 && $1=="mov" && $2=="rbp," && $3=="rsp"); p1 = ($1=="push" && $2=="rbp"); } END{print c+0}' "$1"; }
blobs=0
for f in "$CORPUS"/*/*.sno "$CORPUS"/*/*.sc "$CORPUS"/*/*.icn "$CORPUS"/*/*.pl "$CORPUS"/*/*.reb "$CORPUS"/*/*.raku "$CORPUS"/*/*.pas "$ROOT/../harness/scripts/fixtures/gc_roots_witness.sno"; do
    [ -f "$f" ] || continue
    timeout -k 5 120 ./scrip --compile "$f" > "$W/b.s" 2>/dev/null || continue
    blobs=$((blobs + $(blobcnt "$W/b.s")))
done
if [ "$blobs" -le "$BLOB_CEILING" ]; then
    echo "  arm 4 PASS: $blobs stored-pattern BLOB activation frame(s) name no map on the line after the carve, at or under the declared ceiling $BLOB_CEILING (every blob prologue carries its anchor note there)"
    [ "$blobs" -lt "$BLOB_CEILING" ] && echo "         ⭐ IT FELL: lower BLOB_CEILING to $blobs in this file, in the landing that paid for it"
else
    echo "  arm 4 RED: $blobs blob activation frames without an anchor note, ABOVE the ceiling $BLOB_CEILING -- a NEW frame regime is emitting a frame the census cannot anchor"; bad=1
fi
if [ "$bad" -ne 0 ]; then echo "GATE FAIL(1) [gc_every_safe_point_has_a_compile_time_frame_shape]: an activation frame does not name its map, or a marker tag is back"; exit 1; fi
echo "GATE PASS(0) [gc_every_safe_point_has_a_compile_time_frame_shape]: every graph names its static map in both media through its anchor note and the counted table, no frame-marker tag exists, the cost is under the ceiling, every blob prologue is anchored"; exit 0
