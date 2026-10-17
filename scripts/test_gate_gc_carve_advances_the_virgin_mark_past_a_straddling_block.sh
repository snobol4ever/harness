#!/usr/bin/env bash
# test_gate_gc_carve_advances_the_virgin_mark_past_a_straddling_block.sh -- A BLOCK CARVED BELOW THE VIRGIN MARK THAT ENDS
# ABOVE IT DIRTIES GROUND THE ARENA STILL CALLS UNTOUCHED (cfo 2026-09-16, THE COLLECTOR, the rehash row taken back from
# hq_snobol4 under CEO-802).
#
# MECHANISM, measured with gdb on the row's own witness and not inferred: rt_gcheap_carve (gc_heap.c) skips the payload
# memset when `at >= g_hp_virgin` -- the virgin-zero elision of 963c0390b (HP-2), correct only while EVERY byte above the
# mark is still the kernel's zero page. The advance was guarded by the same test: `if (at >= g_hp_virgin && at + total >
# g_hp_virgin) g_hp_virgin = at + total`. After a compaction lowers g_hp_top below the mark, a 20 KB DUPL string carved
# just under the mark ENDS ABOVE IT, the caller writes its bytes over that ground, and the mark does not move. The next
# compaction lowers the top again, a fresh HB_AGGB bucket is carved on the dirty ground as "virgin", its memset is skipped,
# and _tbl_grow hands _tbl_rehash a cap-1 bucket whose len reads 0x78787878 ("xxxx"): _tbl_lower(n=2021161080) walks off
# the block. gdb at the fault: the bucket's title is VALID (size 80, type 211, HBF_TTL) and its words are 'x' bytes --
# the block is not moved, not reclaimed, not unrooted; it was never zeroed. hq_snobol4's two rehash cures (an own heap
# type for the old vector; re-reading every slot through the table) could not move it because the rehash is where the
# garbage is READ, not where it is MADE. The rtx carve (rtx_alloc.s) carves only at/above the mark and sets it to the
# new top, so it never straddles; only the C carve did.
# CURE: one line -- the mark advances whenever a block's END passes it, whatever its start: `if (at + total >
# g_hp_virgin) g_hp_virgin = at + total`.
#
# ARMS: (1) STRUCTURAL: the carve's advance line carries no `at >= g_hp_virgin` guard; (2..5) the row's witness cut to
# 3000 statements -- a TABLE, an ARRAY and a DATA record live across 3000 statements of 20 KB string churn (the origin
# SIGSEGV lands at the 256->512 rehash near statement 1025, so 3000 keeps the red and drops the 30000-statement form's
# quadratic 46 s mode-3 run under stress, measured on the cure at load 7-9) -- in mode 3 and mode 4 at SCRIP_GC_STRESS=20
# and =200, each rc=0 and byte-identical to `sbl -bf`. Stress 20 is THE discriminator (deterministic SIGSEGV on origin,
# 3 of 3 both modes); stress 200 is green on origin by layout luck and is kept as the second shape. Cost on the cure 9 s
# at load 10 (7 s red on origin) -- test-sequential beside the collector gates, not preflight (5 s ceiling).
# FAIL-ONCE / PASS-ONCE 2026-09-16 on one tree, `git stash` around the one-line diff, runtime rebuilt each side (1.4 s),
# libraries distinct by the freshness probe's so-hash (origin b2ae6d702148, cure f8eb24499e14): origin 163ae51c8: structural
# FAIL, m3 stress=20 rc=139, m4 stress=20 rc=139, stress=200 both PASS -> rc=1. cure: five arms PASS -> rc=0. The 30000-
# statement form is the row's own DONE-WHEN and passed on the cure in both modes (m3 46 s, m4 29 s at load 7-9).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the ref is CUT FROM THE ORACLE at run time, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
if grep -qE '^\s*if \(at \+ total > g_hp_virgin\) g_hp_virgin = at \+ total;' "$ROOT/src/runtime/rt/gc_heap.c" && ! grep -qE 'if \(at >= g_hp_virgin && at \+ total > g_hp_virgin\)' "$ROOT/src/runtime/rt/gc_heap.c"; then
    echo "  structural PASS (rt_gcheap_carve advances g_hp_virgin whenever a block's end passes it)"
else echo "  structural FAIL (rt_gcheap_carve advances g_hp_virgin only for a block that STARTS at or above it -- a straddling block dirties ground the next carve will not zero)"; RC=1; fi
printf '        T = TABLE()\n        A = ARRAY(50)\n        DATA("R(F)")\n        X = R(1)\n        I = 0\nL       I = I + 1\n        T[I] = DUPL("k", 10)\n        A[1 + REMDR(I, 50)] = I\n        S = DUPL("x", 20000)\n        LT(I, 3000)   :S(L)\n        OUTPUT = T[7] A[8] F(X)\nEND\n' > "$T/w.sno"
( cd "$T" && timeout -k 5 20s "$SBL" -bf w.sno </dev/null ) > "$T/w.ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused its own witness -- no ref to grade against"; exit 2; }
[ -s "$T/w.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced an EMPTY ref"; exit 2; }
if "$SCRIP" --compile "$T/w.sno" -o "$T/w.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/w.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$T/w4" 2>"$T/ld.log"; then :; else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link refused ($(head -c 200 "$T/ld.log"))"; exit 2; fi
for st in 20 200; do
    ( cd "$T" && SCRIP_GC_STRESS=$st timeout -k 5 40s "$SCRIP" w.sno </dev/null > m3.out 2>/dev/null ); r=$?
    if [ "$r" -eq 0 ] && cmp -s "$T/m3.out" "$T/w.ref"; then echo "  m3 stress=$st PASS (rc=0, byte-identical to the oracle)"; else echo "  m3 stress=$st FAIL (rc=$r; 139 is the unzeroed-bucket SIGSEGV in _tbl_lower)"; RC=1; fi
    ( cd "$T" && SCRIP_GC_STRESS=$st timeout -k 5 40s ./w4 </dev/null > m4.out 2>/dev/null ); r=$?
    if [ "$r" -eq 0 ] && cmp -s "$T/m4.out" "$T/w.ref"; then echo "  m4 stress=$st PASS (rc=0, byte-identical to the oracle)"; else echo "  m4 stress=$st FAIL (rc=$r)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: the virgin mark tracks every carve's end; a table, an array and a record survive 3000 statements of 20 KB churn under stress collections byte-identical to the oracle in both modes (5 arms)"
else echo "⛔ GATE FAIL(1) [$G]: a block carved across the virgin mark leaves dirty ground the next carve treats as zero (examined 5 arms)"; fi
exit $RC
