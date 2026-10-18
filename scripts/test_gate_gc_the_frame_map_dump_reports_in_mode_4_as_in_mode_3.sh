#!/usr/bin/env bash
# test_gate_gc_the_frame_map_dump_reports_in_mode_4_as_in_mode_3.sh -- SCRIP_GC_MAPS_DUMP=1 is armed by the FIRST frame-map
# install in both modes (cfo 2026-10-04, review of hq_prolog's ec631d327).
#
# MEASURED 2026-10-04 on SCRIP 520d2794e: ec631d327 gave rt_gc_frame_maps_install_counted a fast first install (pre-sized, no
# duplicate scan) that never called rt_gc_frame_maps_add -- and rt_gc_frame_maps_add is where the RT_DIAG build arms the
# SCRIP_GC_MAPS_DUMP atexit report. Mode 4 installs every map through that first counted table, so the dump went SILENT in
# mode 4 for every language (a Prolog hello 359 lines -> 0, a SNOBOL4 hello 3 -> 0) while mode 3 still printed. No gate saw
# it: the two gates that read the dump run mode 3 only. CURE: the first counted install calls rt_gc_frame_maps_add with NULL,
# which arms the report and adds nothing (line-neutral; gc_kind_witnesses.tsv keys gc_heap.c by line).
# Arms, on a Prolog and a SNOBOL4 witness: A the mode-4 binary's dump is non-empty; B it prints exactly as many dump lines as
# mode 3; C the program's own output is unchanged by the knob in mode 4. FAIL_ONCE=1 empties arm A's mode-4 count.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
printf ':- initialization(main).\nmain :- X = f(a, [b, c]), write(X), nl.\n' > "$T/w.pl"
printf "        X = 'map' 'dump'\n        OUTPUT = X\nEND\n" > "$T/w.sno"
RC=0
for W in w.pl w.sno; do
  ( cd "$T" && "$SCRIP" --compile -o "$W.s" "$W" </dev/null && gcc "$W.s" -o "$W.bin" -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness $W did not build"; exit 2; }
  m3=$( cd "$T" && SCRIP_GC_MAPS_DUMP=1 timeout -k 5 30 "$SCRIP" "$W" </dev/null 2>&1 >/dev/null | grep -ciE 'GC-MAP|frame map' )
  m4=$( cd "$T" && SCRIP_GC_MAPS_DUMP=1 LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 30 "./$W.bin" </dev/null 2>&1 >/dev/null | grep -ciE 'GC-MAP|frame map' )
  o0=$( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 30 "./$W.bin" </dev/null 2>/dev/null )
  o1=$( cd "$T" && SCRIP_GC_MAPS_DUMP=1 LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 30 "./$W.bin" </dev/null 2>/dev/null )
  [ -n "${FAIL_ONCE:-}" ] && m4=0
  [ "$m3" -gt 0 ] || { echo "⛔ REFUSE(2): $W prints no dump in mode 3 either ($m3) -- this build has no RT_DIAG report to compare"; exit 2; }
  if [ "$m4" -gt 0 ]; then echo "  $W arm A PASS (mode 4 dump lines $m4)"; else echo "  $W arm A FAIL (mode 4 prints no dump; mode 3 prints $m3)"; RC=1; fi
  if [ "$m4" = "$m3" ]; then echo "  $W arm B PASS (mode 3 $m3 = mode 4 $m4)"; else echo "  $W arm B FAIL (mode 3 $m3, mode 4 $m4)"; RC=1; fi
  if [ -n "$o0" ] && [ "$o0" = "$o1" ]; then echo "  $W arm C PASS (output unchanged by the knob: $(echo "$o0" | head -1))"; else echo "  $W arm C FAIL (output '$o0' vs '$o1' under the knob)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: SCRIP_GC_MAPS_DUMP reports in mode 4 exactly as in mode 3 (3 arms x 2 languages)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: the frame-map dump is not armed in mode 4 as in mode 3 (examined 3 arms x 2 languages)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
