#!/usr/bin/env bash
# test_gate_gc_the_stack_walk_stops_at_the_outermost_emitted_frame.sh -- the emitted-stack walk is bounded ABOVE
# by the outermost emitted frame, not by the [stack] VMA end. Row
# gc-the-emitted-stack-walk-takes-a-ceiling-at-the-rt-outer-call-entry-rsp (ceo, 2026-09-21);
# ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 10.
#
# WHAT WAS WRONG. gc_seg_next stage 2 took its upper bound from gc_stack_top() -- the [stack] VMA end read out of
# /proc/self/maps -- and mode 3 enters emitted code through rt_outer_call, which carves sub $4194304,%rsp
# (src/driver/scrip.c:122). So every collection walked a 4 MB hole of dead stack. Measured on SCRIP acf601bdd at
# SCRIP_HEAP_MB=1, first collection, one segment: mode 3 read 4218328 bytes and the SAME program in mode 4 read
# 67992 -- 62.0x, of which the carve is 99.4 percent. Cost: bench_icnstr_concat_table.icn read 1614 collections /
# 5.72 s at 1 MB against 6 / 0.13 s at the default, i.e. 3.47 ms per collection to trace 88448 live bytes.
#
# WHAT HOLDS NOW (re-cut at ARCH-GC section 13 STEP B, hq_collector 2026-10-11). The chain ends at the ROOT frame by construction, and the program top is recorded at entry:
# rt_outer_call hands rt_program_top_adopt the rsp it enters emitted code at, the runtime resolves the top through the ROOT map (entry rsp + value_bytes + 16 + header_bytes) and
# every collection that walks the chain to its ROOT frame re-derives the same value from the frame the chain found. gc_seg_next bounds the running main segment there, so the
# segment the collector and the reporter see ends at the outermost emitted frame in mode 3 as it does in mode 4, and a wrong record can only make the chain stop short, which
# the walker refuses by name (never skips). The ceiling the marker scan needed (rt_gc_emit_ceiling_adopt, the learned bound, SCRIP_GC_CEILING=0) is gone; its planted arms went
# with it. The property is read from the reporter's per-collection stack bytes, and its proof that it can fail is the commit before this one: mode 3 read 4208208 bytes on the
# first collection and 4213168 steady-state (the 4 MB rt_outer_call carve) against 65616 / 65679 in mode 4.
#
# ARMS. (1) m3 and m4 agree on the STEADY-STATE bytes per collection within 2x and under 64 KB each. (2) the witness's output is byte-identical across both arenas and both modes.
# (3) the bound is REPORTED: [GC-COV] carries a program_top address. (4) the FIRST collection's segment is bounded in both modes: both under 131072 bytes (mode 4's residue is
# libc's frames above main, ~64 KB).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
export SNO_LIB="${SNO_LIB:-$S4E/corpus/include}"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
W="$ROOT/../harness/scripts/gc_witnesses/hb_arr.sno"
[ -f "$W" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $W"; exit 2; }
echo "  HOLDS: the emitted-stack walk stops at the outermost emitted frame, so mode 3's rt_outer_call carve is never scanned and the two modes read the same bytes per collection (ARCH-GC section 10)"
"$SCRIP" --compile "$W" > "$T/w.s" 2>/dev/null && gcc "$T/w.s" -o "$T/w" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: the witness will not build in mode 4"; exit 2; }
# steady-state bytes per collection = (last cumulative bytes - first) / (last ranges - 1)
steady() {
    "$@" 2>&1 | awk '/^\[GC-MAPS\] pop=cstack/ { for (i=1;i<=NF;i++) { if ($i ~ /^ranges=/) { split($i,a,"="); r=a[2] } if ($i ~ /^bytes=/) { split($i,b,"="); by=b[2] } }
        if (n++ == 0) { fb=by } lb=by; lr=r }
        END { if (n < 3 || lr < 2) { print "REFUSE" } else { printf "%d\n", (lb-fb)/(lr-1) } }'
}
M3=$(steady env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=3 SCRIP_GC_MAPS=1 "$SCRIP" "$W" < /dev/null)
M4=$(steady env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=3 SCRIP_GC_MAPS=1 "$T/w" < /dev/null)
for v in "$M3" "$M4"; do [ "$v" = "REFUSE" ] && { echo "⛔ GATE REFUSE(2) [$G]: fewer than 3 collections seen -- the witness did not exercise the walker"; exit 2; }; done
echo "  steady-state stack bytes per collection: m3=$M3 m4=$M4"
if [ "$M3" -lt 65536 ] && [ "$M4" -lt 65536 ] && [ "$M3" -lt $((M4 * 2 + 64)) ] && [ "$M4" -lt $((M3 * 2 + 64)) ]; then echo "  arm 1 PASS (the two modes read the same bounded region)"; else echo "  arm 1 FAIL (m3=$M3 m4=$M4; want both under 65536 and within 2x)"; RC=1; fi
h1=$(env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=3 "$SCRIP" "$W" < /dev/null 2>/dev/null | md5sum | cut -d' ' -f1)
h3=$("$SCRIP" "$W" < /dev/null 2>/dev/null | md5sum | cut -d' ' -f1)
h4=$(env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=3 "$T/w" < /dev/null 2>/dev/null | md5sum | cut -d' ' -f1)
if [ "$h1" = "$h3" ] && [ "$h1" = "$h4" ]; then echo "  arm 2 PASS (output byte-identical across both arenas and both modes)"; else echo "  arm 2 FAIL (small-arena=$h1 default-arena=$h3 m4=$h4)"; RC=1; fi
cov=$(env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=3 SCRIP_GC_COVERAGE=1 "$SCRIP" "$W" < /dev/null 2>&1 | grep -m1 '^\[GC-COV\]' | sed -n 's/.*program_top=\(0x[0-9a-f]*\).*/\1/p')
if [ -n "$cov" ] && [ "$cov" != "0x0" ] && [ "$cov" != "(nil)" ]; then echo "  arm 3 PASS (the bound is reported: program_top=$cov)"; else echo "  arm 3 FAIL (no program_top on the coverage line -- a bound nobody can read is dark)"; RC=1; fi
first() { "$@" 2>&1 | grep -m1 '^\[GC-MAPS\] pop=cstack' | sed -n 's/.*bytes=\([0-9]*\).*/\1/p'; }
F3=$(first env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=3 SCRIP_GC_MAPS=1 "$SCRIP" "$W" < /dev/null)
F4=$(first env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=3 SCRIP_GC_MAPS=1 "$T/w" < /dev/null)
for v in "$F3" "$F4"; do [ -n "$v" ] || { echo "⛔ GATE REFUSE(2) [$G]: no first-collection [GC-MAPS] pop=cstack line -- the witness did not reach a collection"; exit 2; }; done
echo "  first-collection stack bytes: m3=$F3 m4=$F4"
if [ "$F3" -lt 131072 ] && [ "$F4" -lt 131072 ]; then echo "  arm 4 PASS (the first collection is bounded in both modes: the top is recorded at entry, not learned by the first walk)"; else echo "  arm 4 FAIL (m3=$F3 m4=$F4; want both under 131072 -- a first collection that walks the 4 MB reserve is the defect this row names)"; RC=1; fi
[ $RC -eq 0 ] && echo "GATE PASS [$G]" || echo "GATE FAIL [$G]"
exit $RC
