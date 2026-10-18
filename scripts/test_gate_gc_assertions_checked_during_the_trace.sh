#!/usr/bin/env bash
# test_gate_gc_assertions_checked_during_the_trace.sh -- GC ASSERTIONS ARE CHECKED DURING THE TRACE THE COLLECTOR ALREADY DOES
# (row gc-assertions-are-checked-during-the-trace-piggybacked-on-work-the-collector-already-does, the cfo, 2026-09-28; Aftandilian
# and Guyer, GC Assertions, PLDI 2009; Reichenbach et al. 2010 for which assertions are cheap in one traversal; hq_pascal read both
# papers and classified the candidates on 2026-09-21; the cto's ruling of 2026-09-22: an assertion REPORTS, it never aborts by
# default, because an aborting assertion turns every wrong-answer red in nine lanes into a crash and voids their evidence).
#
# THE MECHANISM (src/runtime/rt/gc_heap.c, gc_heap.h): an assertion is not checked when it is made; it conveys intent to the
# collector, which checks it right after its mark phase, when every live block carries HBF_MARK.  No new static: the intent rides
# the heap itself.
#   rt_gc_assert_dead(payload)          sets HBF_ASSERT_DEAD in the block's own header; a marked block carrying it is reported
#                                       "[ZGC-ASSERT] DEAD-ASSERTED ... is REACHABLE" at every collection that finds it live.
#   rt_gc_assert_instances(kind, n)     returns a two-DESCR vector {kind, n} flagged HBF_ASSERT_INST; the caller keeps it reachable,
#                                       and at each collection that marks it the collector counts the marked blocks of that kind
#                                       and reports "[ZGC-ASSERT] INSTANCES kind=... expected n live, the trace found m" on a mismatch.
# The check is one pass over the block index per collection (a flag test per block), a second pass only when an assertion is live.
# SCRIP_GC_ASSERT_FATAL=1 aborts after reporting; unset, the program runs on.  Root-set completeness is NOT here: it is not a
# one-traversal property (Reichenbach section 4) and stays with the conservative auditor.
#
# THE FIXTURE is a C program linked on libscrip_rt.so.  It roots blocks through the one C-reachable root form the collector walks,
# rt_gc_root_range_add_topword: a buffer whose word at +0 is its top, +8 is the Prolog trail's ball slot (kept zero), and each
# 32-byte entry from +32 holds a raw cell the collector visits and a DESCR it visits.
#
# ARMS: (1) DEAD, VIOLATED: a rooted block asserted dead is reported by kind at the next collection and the program exits 0;
# (2) DEAD, HONOURED: an unrooted block asserted dead draws no report; (3) INSTANCES, HOLDING: three rooted blocks of one kind and
# an assertion of three draw no report; (4) INSTANCES, VIOLATED: the same blocks and an assertion of four are reported with the
# count the trace found; (5) FATAL: arm (1) under SCRIP_GC_ASSERT_FATAL=1 reports and then aborts (rc 134).  Arms (1) and (2)
# together prove the fixture's root form works: the only difference between them is the root.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
cat > "$T/fx.c" <<'FXC'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
void *rt_gcheap_alloc(uint16_t type, uint64_t payload_bytes);
long rt_gc_collect(void);
void rt_gc_root_range_add_topword(const char *lo);
void rt_gc_assert_dead(const void *payload);
void *rt_gc_assert_instances(uint16_t type, long n);
static char g_root[HDR + 32 * 8] __attribute__((aligned(16)));
static void root_set(int k, void *p) { *(void **)(g_root + HDR + 32 * k) = p; }
int main(int argc, char **argv)
{
    int mode = argc > 1 ? atoi(argv[1]) : 0; char *p[3];
    memset(g_root, 0, sizeof g_root); *(char **)g_root = g_root + sizeof g_root; rt_gc_root_range_add_topword(g_root);
    for (int i = 0; i < 3; i++) { p[i] = (char *)rt_gcheap_alloc(205, 64); memset(p[i], 'Q', 64); }
    if (mode == 1) { root_set(0, p[0]); rt_gc_assert_dead(p[0]); }
    if (mode == 2) { rt_gc_assert_dead(p[0]); }
    if (mode == 3 || mode == 4) { for (int i = 0; i < 3; i++) root_set(i, p[i]); root_set(3, rt_gc_assert_instances(205, mode == 3 ? 3 : 4)); }
    long r = rt_gc_collect();
    printf("FX mode=%d reclaimed=%ld\n", mode, r); fflush(stdout);
    return 0;
}
FXC
HDR=$(awk '$1 == "#define" && $2 == "PL_TR_HEADER_BYTES" {print $3}' "$ROOT/src/runtime/rt/rt_pl_trail.h")
[ -n "$HDR" ] || { echo "⛔ GATE REFUSE(2) [$G]: no PL_TR_HEADER_BYTES in rt_pl_trail.h -- the fixture lays its root range out as the trail arena header does"; exit 2; }
gcc -O0 -g -DHDR="$HDR" -o "$T/fx" "$T/fx.c" -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" 2> "$T/cc.err" || { sed -n 1,5p "$T/cc.err"; echo "⛔ GATE REFUSE(2) [$G]: the fixture did not build"; exit 2; }
run() { env -u SCRIP_GC_ASSERT_FATAL "$@" > "$T/o.txt" 2> "$T/e.txt"; echo $?; }
r=$(run "$T/fx" 1); n=$(grep -c '^\[ZGC-ASSERT\] DEAD-ASSERTED block kind=205/' "$T/e.txt")
if [ "$r" = 0 ] && [ "$n" -ge 1 ] && grep -q '^FX mode=1' "$T/o.txt"; then echo "  arm 1 PASS: a rooted block asserted dead is reported by kind (205/HB_WSC) at the collection that finds it live, and the program runs on (rc 0)"
else echo "  arm 1 FAIL: rc=$r reports=$n -- the collector did not report a reachable block the program asserted dead"; head -3 "$T/e.txt" | sed 's/^/     /'; RC=1; fi
r=$(run "$T/fx" 2); n=$(grep -c '^\[ZGC-ASSERT\]' "$T/e.txt")
if [ "$r" = 0 ] && [ "$n" = 0 ] && grep -q '^FX mode=2' "$T/o.txt"; then echo "  arm 2 PASS: an unrooted block asserted dead draws no report -- the only difference from arm 1 is the root, so the fixture's root form works"
else echo "  arm 2 FAIL: rc=$r reports=$n -- an assertion that holds was reported"; RC=1; fi
r=$(run "$T/fx" 3); n=$(grep -c '^\[ZGC-ASSERT\]' "$T/e.txt")
if [ "$r" = 0 ] && [ "$n" = 0 ]; then echo "  arm 3 PASS: three rooted blocks of kind 205 and an assertion of three draw no report"
else echo "  arm 3 FAIL: rc=$r reports=$n"; head -3 "$T/e.txt" | sed 's/^/     /'; RC=1; fi
r=$(run "$T/fx" 4)
if [ "$r" = 0 ] && grep -q '^\[ZGC-ASSERT\] INSTANCES kind=205/HB_WSC expected 4 live, the trace found 3 ' "$T/e.txt"; then echo "  arm 4 PASS: an assertion of four against three live blocks is reported with the count the trace found"
else echo "  arm 4 FAIL: rc=$r -- $(grep -m1 'ZGC-ASSERT' "$T/e.txt" | cut -c1-140)"; RC=1; fi
( ulimit -c 0; exec env SCRIP_GC_ASSERT_FATAL=1 "$T/fx" 1 > "$T/o.txt" 2> "$T/e.txt" ) 2> /dev/null; r=$?
if [ "$r" = 134 ] && grep -q '^\[ZGC-ASSERT\] DEAD-ASSERTED' "$T/e.txt" && ! grep -q '^FX mode=1' "$T/o.txt"; then echo "  arm 5 PASS: under SCRIP_GC_ASSERT_FATAL=1 the violation is reported and then aborts (rc 134); unset, arm 1 ran on"
else echo "  arm 5 FAIL: rc=$r -- the fatal knob did not report-then-abort"; RC=1; fi
echo "population: 5 arm(s) graded"
[ $RC -eq 0 ] && echo "GATE PASS [$G]" || echo "GATE FAIL [$G]"
exit $RC
