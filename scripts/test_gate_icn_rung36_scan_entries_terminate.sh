#!/bin/bash
# rung36_jcon_scan (entry 41) and rung36_jcon_scan2 (entry 42) of corpus/tests/icon/rung36_all.icn HANG:
# a genuine infinite regeneration, not a load or timeout artifact. Row
# icon-rung-scan-alternation-infinite-regeneration-hang (seat04 2026-09-04, re-measured hq_B 2026-09-05:
# still live, 13.3M and 13.5M lines of output before SIGTERM at 20s).
#
# ⛔ TERMINATION IS NOT THE CRITERION -- a cure that stops the loop and prints the wrong stream is not a
# cure, it is a quieter defect. Each entry is graded BY VALUE against its own segment of rung36_all.ref,
# which is oracle-cut: entry 42's ref is byte-identical to iconx on this box (verified 2026-09-05). Entry
# 41 cannot be graded against icont directly at all -- icont REJECTS it ("`;`: invalid declaration", our
# own semicolon conversion after a record declaration), which is why the suite ref, not the oracle, is the
# comparison here and why that ref must never be re-cut from SCRIP's own output.
#
# ⛔ REFUSES rc=2 unless all 4 runs (2 entries x 2 modes) are graded, and rc=2 if either segment extracts
# empty -- an extraction that silently yields nothing would grade an empty program against an empty ref
# and print the success shape over the gap.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
# The two programs are entries of the icon master since 2026-11-12 (origin rung36_all__rung36_jcon_scan and __rung36_jcon_scan2,
# their answers cut from Arizona icon and equal to their old rung36_all.ref segments), extracted by origin.
RUNGS_DIR="$ROOT/../corpus/tests/icon" RUNGS_EXT=.icn . "$HERE/lib_rungs_extract.sh" || { echo "⛔ GATE REFUSES (rc=2): cannot load lib_rungs_extract.sh"; exit 2; }
rungs_extract_origin rung36_all__rung36_jcon_scan "$d/e41.icn" "$d/e41.ref" && rungs_extract_origin rung36_all__rung36_jcon_scan2 "$d/e42.icn" "$d/e42.ref" \
  || { echo "⛔ GATE REFUSES (rc=2): the entries rung36_all__rung36_jcon_scan and __rung36_jcon_scan2 did not extract from the icon master -- cannot measure"; exit 2; }
for e in e41 e42; do
    [ -s "$d/$e.icn" ] && [ -s "$d/$e.ref" ] || { echo "⛔ GATE REFUSES (rc=2): $e extracted empty from the icon master"; exit 2; }
done
graded=0; bad=0
for e in e41 e42; do
    o=$(timeout -k 5 60 ./scrip "$d/$e.icn" </dev/null 2>&1); r=$?; graded=$((graded+1))
    if [ "$r" = 124 ]; then echo "  ⛔ RED m3 $e: STILL HANGS (SIGTERM at 60s, $(printf '%s' "$o" | wc -l) lines)"; bad=1
    elif [ "$r" != 0 ] || ! printf '%s\n' "$o" | diff -q - "$d/$e.ref" >/dev/null; then
        echo "  ⛔ RED m3 $e: rc=$r, output differs from its ref: $(printf '%s\n' "$o" | diff - "$d/$e.ref" | head -2 | tr '\n' ' ' | cut -c1-100)"; bad=1
    fi
    if timeout -k 5 120 ./scrip --compile --out="$d/$e.s" "$d/$e.icn" </dev/null >/dev/null 2>&1 \
       && gcc -m64 -no-pie "$d/$e.s" -o "$d/$e.m4" -L./out -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then
        o=$(timeout -k 5 60 "$d/$e.m4" </dev/null 2>&1); r=$?; graded=$((graded+1))
        if [ "$r" = 124 ]; then echo "  ⛔ RED m4 $e: STILL HANGS (SIGTERM at 60s, $(printf '%s' "$o" | wc -l) lines)"; bad=1
        elif [ "$r" != 0 ] || ! printf '%s\n' "$o" | diff -q - "$d/$e.ref" >/dev/null; then
            echo "  ⛔ RED m4 $e: rc=$r, output differs from its ref: $(printf '%s\n' "$o" | diff - "$d/$e.ref" | head -2 | tr '\n' ' ' | cut -c1-100)"; bad=1
        fi
    else
        graded=$((graded+1)); echo "  ⛔ RED m4 $e: does not compile/link"; bad=1
    fi
done
[ "$graded" = 4 ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the 4 required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [icn_rung36_scan_entries_terminate]: a scan entry still hangs or still prints the wrong stream"; exit 1; }
echo "✅ GATE OK [icn_rung36_scan_entries_terminate]: both scan entries terminate and match their oracle-cut refs, BOTH modes"
