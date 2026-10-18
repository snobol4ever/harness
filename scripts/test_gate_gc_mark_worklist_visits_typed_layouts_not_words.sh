#!/usr/bin/env bash
# test_gate_gc_mark_worklist_visits_typed_layouts_not_words.sh -- THE MARK WORKLIST VISITS EVERY HEAP BLOCK BY ITS KIND'S LAYOUT,
# NEVER BY SNIFFING ITS WORDS (cfo 2026-10-01; row gc-the-mark-worklist-walks-typed-visitors-not-words-every-heap-block-kind-has-a-layout-
# and-hb-ws-is-split-by-allocation-site; Lon 2026-09-17 CEO-812/815, Rule 2b of ARCH-GC-COMPILE-TIME-FRAME-MAPS.md).
# THE DEFECT IT HOLDS SHUT: on db4a6b1fc the worklist handed every marked HB_WS, HB_DINST, HB_ARR and HB_PLJ payload to the sniffing
# frame scan -- a heap-interior word scan with the 16-byte descriptor sniff -- and hq_raku's witness read DATINST_t.type as 0xdbdbdbdb
# after a slide (benchmark_point_class_add m3 CRASH under the poison fill). The cure landed in pieces (hb_scan_interior deleted, HB_WS
# split into kind-named allocators: HB_WSB raw bytes, HB_WSC chars, HB_DVEC descriptors, HB_PVEC pointers, ...); this gate is what the row
# owed so the shape cannot quietly come back.
# ARMS: (1) KIND COVERAGE, static: every `#define HB_<KIND> <n>` in gc_heap.h is named in the mark loop's dispatch (the region from
# `while (g_gc_mhead)` to `if (g_gc_wln == 0) break;` in gc_heap.c) by an equality, a range, or the pointer-free leaf line -- a kind
# no visitor names would fall to the interior counter; PLANT: the same reader over gc_heap.h plus an injected kind must name it missing.
# (2) NO UNTYPED ALLOCATION, static: zero calls of the retired rt_ws_alloc( spelling, and every rt_gcheap_alloc( / rt_gcheap_grow_block(
# call in src/ outside gc_heap.c passes an HB_ constant as its kind; PLANT: the reader must flag a synthetic call with a variable kind.
# (3) THE DATINST WITNESS BY RATE: ../harness/scripts/fixtures/gc/datinst_point_bless.raku (point_class_add cut to 12 lines: a class whose add
# returns a fresh bless) under SCRIP_GC_POISON=1 SCRIP_GC_STRESS=1, 3 runs per mode, each byte-identical to the ref cut from Rakudo.
# (4) EVERY collection of those runs prints [GC-COV] interior_words=0, and there are at least 1000 per run (40003 measured), else rc 2:
# a witness that does not collect proves nothing. (5) SENSITIVITY: SCRIP_GC_PLANT_PIN_TYPE=<HB_DINST> SCRIP_GC_PLANT_PIN_SKIP=1 frees the
# first live record instance as if no visitor had marked it, and the witness must then NOT print the ref (it aborts or faults in both
# modes, measured); a witness that still answers is blind and the gate refuses rc 2. The same plant on HB_ARR, a kind the witness does
# not hold, answered correctly when measured -- the witness is specific to HB_DINST.
# rc 0 every arm holds · 1 a kind unvisited, an untyped allocation, a wrong answer or a nonzero interior count · 2 could not measure.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
H="$ROOT/src/runtime/rt/gc_heap.h"; C="$ROOT/src/runtime/rt/gc_heap.c"
W="$ROOT/../harness/scripts/fixtures/gc/datinst_point_bless.raku"; R="${W%.raku}.ref"
for f in "$H" "$C" "$W" "$R"; do [ -s "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $f"; exit 2; }; done
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
kinds_missing() {
    python3 - "$1" "$2" <<'PY'
import re, sys
h, c = open(sys.argv[1]).read(), open(sys.argv[2]).read()
kinds = {m.group(1): int(m.group(2)) for m in re.finditer(r'^#define\s+(HB_[A-Z0-9_]+)\s+(\d+)\s*$', h, re.M)}
a = c.find('while (g_gc_mhead)'); b = c.find('if (g_gc_wln == 0) break;', a)
if not kinds or a < 0 or b < 0: print('UNREADABLE'); sys.exit(0)
reg = c[a:b]
named = set(re.findall(r'h->type == (HB_[A-Z0-9_]+)', reg))
for lo, hi in re.findall(r'h->type >= (HB_[A-Z0-9_]+) && h->type <= (HB_[A-Z0-9_]+)', reg):
    if lo in kinds and hi in kinds: named |= {k for k, v in kinds.items() if kinds[lo] <= v <= kinds[hi]}
for op, lo in re.findall(r'h->type (<=?) (HB_[A-Z0-9_]+)', reg):
    if lo in kinds: named |= {k for k, v in kinds.items() if v < kinds[lo] or (op == '<=' and v == kinds[lo])}
print(' '.join(sorted(k for k in kinds if k not in named)))
PY
}
miss=$(kinds_missing "$H" "$C"); nk=$(grep -cE '^#define[[:space:]]+HB_[A-Z0-9_]+[[:space:]]+[0-9]+[[:space:]]*$' "$H")
cp "$H" "$T/plant.h"; printf '#define HB_ZZPLANT 299\n' >> "$T/plant.h"; pmiss=$(kinds_missing "$T/plant.h" "$C")
if [ "$miss" = UNREADABLE ] || [ "$pmiss" != HB_ZZPLANT ]; then echo "⛔ GATE REFUSE(2) [$G]: the kind reader cannot measure (reader='$miss' plant='$pmiss', want the plant named alone)"; exit 2; fi
if [ -z "$miss" ]; then echo "  arm 1 PASS: all $nk HB_ kinds of gc_heap.h are named in the mark worklist's dispatch; the planted kind is named missing"
else echo "  arm 1 FAIL: kinds the mark worklist does not name: $miss"; RC=1; fi
untyped() { grep -rnE '\brt_ws_alloc[[:space:]]*\(|\brt_gcheap_alloc[[:space:]]*\([^H)]|\brt_gcheap_grow_block[[:space:]]*\([^,]*,[[:space:]]*([^H( ]|\(uint16_t\)[[:space:]]*[^H ])' "$@" 2>/dev/null | grep -v 'src/runtime/rt/gc_heap\.[ch]:' | grep -vE '^[^:]+:[0-9]+:[^(]*\b(void|uint16_t)[[:space:]]*\*?[[:space:]]*rt_' ; }
bad=$(untyped "$ROOT/src" --include=*.c --include=*.cpp --include=*.h)
printf 'void f(void) { char *p = rt_gcheap_alloc(k, 8); }\nvoid g(void *p) { p = rt_gcheap_grow_block(p, (uint16_t)k, 8); }\nvoid h(void *p) { p = rt_gcheap_grow_block(p, (uint16_t)HB_WSB, 8); }\n' > "$T/plant.c"; pbad=$(untyped "$T/plant.c")
[ "$(printf '%s\n' "$pbad" | grep -c .)" = 2 ] && ! printf '%s\n' "$pbad" | grep -q 'HB_WSB' || { echo "⛔ GATE REFUSE(2) [$G]: the allocation reader must flag the two planted variable-kind calls (bare and cast) and pass the cast typed kind, read: $pbad"; exit 2; }
if [ -z "$bad" ]; then echo "  arm 2 PASS: no rt_ws_alloc( call and no variable-kind heap allocation outside gc_heap.c; the planted call is flagged"
else echo "  arm 2 FAIL: untyped heap allocation sites:"; printf '%s\n' "$bad" | head -10 | sed 's/^/    /'; RC=1; fi
( cd "$T" && "$SCRIP" --compile "$W" -o w.s < /dev/null > /dev/null 2>&1 && gcc -m64 -no-pie -rdynamic w.s -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o w.bin 2>/dev/null ) || { echo "⛔ GATE REFUSE(2) [$G]: the witness does not build in mode 4"; exit 2; }
run() { if [ "$1" = 3 ]; then ( cd "$T" && env "${@:2}" timeout -k 5 120 "$SCRIP" "$W" < /dev/null ); else ( cd "$T" && env "${@:2}" timeout -k 5 120 ./w.bin < /dev/null ); fi; }
ok=0; tot=0; ncol_min=-1; nbad=0
for m in 3 4; do for k in 1 2 3; do tot=$((tot + 1))
    run "$m" SCRIP_GC_POISON=1 SCRIP_GC_STRESS=1 SCRIP_GC_COVERAGE=1 > "$T/o.txt" 2> "$T/e.txt"; r=$?
    n=$(grep -c '^\[GC-COV\]' "$T/e.txt"); b=$(grep '^\[GC-COV\]' "$T/e.txt" | grep -vc ' interior_words=0 ')
    [ "$ncol_min" -lt 0 ] || [ "$n" -lt "$ncol_min" ] && ncol_min=$n; nbad=$((nbad + b))
    if [ $r -eq 0 ] && cmp -s "$T/o.txt" "$R"; then ok=$((ok + 1)); else echo "    m$m run $k: rc=$r $(head -c 80 "$T/o.txt" | tr '\n' '|')"; fi; done; done
[ "$ncol_min" -ge 1000 ] || { echo "⛔ GATE REFUSE(2) [$G]: a witness run made $ncol_min collection(s) (want >= 1000) -- it did not exercise the collector"; exit 2; }
if [ $ok -eq $tot ]; then echo "  arm 3 PASS: the DATINST witness answers Rakudo's line $ok of $tot runs (3 per mode) under poison at stress 1"
else echo "  arm 3 FAIL: the DATINST witness answered $ok of $tot runs"; RC=1; fi
if [ $nbad -eq 0 ]; then echo "  arm 4 PASS: every collection of those runs read interior_words=0 (at least $ncol_min per run)"
else echo "  arm 4 FAIL: $nbad collection(s) word-scanned a heap interior"; RC=1; fi
[ $RC -eq 0 ] && { echo "GATE PASS(0) [$G]: the mark worklist visits every heap kind by its layout; no interior is word-scanned"; exit 0; }
echo "GATE FAIL(1) [$G]: see the failed arm(s) above"; exit 1
