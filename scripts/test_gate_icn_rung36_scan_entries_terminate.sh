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
SRC="$ROOT/../corpus/tests/icon/rung36_all.icn"; REF="$ROOT/../corpus/tests/icon/rung36_all.ref"
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
[ -f "$SRC" ] && [ -f "$REF" ] || { echo "⛔ GATE REFUSES (rc=2): rung36_all.icn/.ref missing -- cannot measure"; exit 2; }
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
cut_seg() { awk -v a="$2" -v b="$3" 'index($0,a)==1{f=1} index($0,b)==1{f=0} f' "$1"; }
awk '/^#-+ 41 rung36_jcon_scan$/{f=1} /^#-+ 42 rung36_jcon_scan2$/{f=0} f' "$SRC" > "$d/e41.icn"
awk '/^#-+ 42 rung36_jcon_scan2$/{f=1} /^#-+ 43 /{f=0} f'                   "$SRC" > "$d/e42.icn"
awk '/^#-+ 41 rung36_jcon_scan$/{f=1;next} /^#-+ 42 /{f=0} f'               "$REF" > "$d/e41.ref"
awk '/^#-+ 42 rung36_jcon_scan2$/{f=1;next} /^#-+ 43 /{f=0} f'              "$REF" > "$d/e42.ref"
for e in e41 e42; do
    [ -s "$d/$e.icn" ] && [ -s "$d/$e.ref" ] || { echo "⛔ GATE REFUSES (rc=2): $e extracted empty from rung36_all -- the entry separators moved"; exit 2; }
done
graded=0; bad=0
for e in e41 e42; do
    o=$(timeout -k 5 60 ./scrip "$d/$e.icn" </dev/null 2>&1); r=$?; graded=$((graded+1))
    if [ "$r" = 124 ]; then echo "  ⛔ RED m3 $e: STILL HANGS (SIGTERM at 60s, $(printf '%s' "$o" | wc -l) lines)"; bad=1
    elif [ "$r" != 0 ] || ! printf '%s\n' "$o" | diff -q - "$d/$e.ref" >/dev/null; then
        echo "  ⛔ RED m3 $e: rc=$r, output differs from its rung36_all.ref segment: $(printf '%s\n' "$o" | diff - "$d/$e.ref" | head -2 | tr '\n' ' ' | cut -c1-100)"; bad=1
    fi
    if timeout -k 5 120 ./scrip --compile --out="$d/$e.s" "$d/$e.icn" </dev/null >/dev/null 2>&1 \
       && gcc -m64 -no-pie "$d/$e.s" -o "$d/$e.m4" -L./out -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then
        o=$(timeout -k 5 60 "$d/$e.m4" </dev/null 2>&1); r=$?; graded=$((graded+1))
        if [ "$r" = 124 ]; then echo "  ⛔ RED m4 $e: STILL HANGS (SIGTERM at 60s, $(printf '%s' "$o" | wc -l) lines)"; bad=1
        elif [ "$r" != 0 ] || ! printf '%s\n' "$o" | diff -q - "$d/$e.ref" >/dev/null; then
            echo "  ⛔ RED m4 $e: rc=$r, output differs from its rung36_all.ref segment: $(printf '%s\n' "$o" | diff - "$d/$e.ref" | head -2 | tr '\n' ' ' | cut -c1-100)"; bad=1
        fi
    else
        graded=$((graded+1)); echo "  ⛔ RED m4 $e: does not compile/link"; bad=1
    fi
done
[ "$graded" = 4 ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the 4 required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [icn_rung36_scan_entries_terminate]: a scan entry still hangs or still prints the wrong stream"; exit 1; }
echo "✅ GATE OK [icn_rung36_scan_entries_terminate]: both scan entries terminate and match their rung36_all.ref segments, BOTH modes"
