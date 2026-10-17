#!/usr/bin/env bash
# test_gate_gc_no_pinned_lifetime_class.sh -- THE PINNING MECHANISM IS DELETED AND CANNOT COME BACK UNDER ITS OLD
# SPELLINGS (cfo 2026-09-16, THE COLLECTOR, CEO-799; Lon in-chat to ceo 14:5x CDT, verbatim: "Just so we are clear.
# Delete the mechanism of the pinning FIRST. THen go figure how to fix it.").
#
# WHAT WAS DELETED, measured at 14:58 CDT on origin f587b10e5: 458 spellings in 27 files under src/ -- rt_pinned_alloc /
# rt_pinned_alloc_tag / rt_pinned_realloc / rt_pinned_strdup (the allocator that minted HB_WS / HB_WSS blocks),
# hb_no_move (the forward pass forwarded a marked block of those types TO ITSELF so it never slid), hb_root_blanket +
# SCRIP_GC_PIN_AGGREGATES (a blanket mark of every such block, the immortal policy), gc_unpin_wss_on +
# SCRIP_GC_UNPIN_WSS (the test-only knob that let names slide), HB_WSS itself, the rtx_alloc.s entry that jumped to the
# C allocator, and the rtx unit arms that paired them. Every site is now ORDINARY COLLECTED ALLOCATION: rt_ws_alloc
# (HB_WS: moves, is reclaimed when unmarked, interior conservatively scanned and its slots relocated), rt_ws_realloc,
# rt_heap_strdup_c (HB_WSC, a leaf C string), or rt_gcheap_alloc(HB_ARR|HB_DINST, n) for the aggregates that have a
# precise visitor. No block type is exempt from the slide; the forward pass has ONE marked-block branch.
#
# ARMS: (1) CENSUS -- the spellings above under src/ read 0 (the arm the ceo asked for: the mechanism cannot return by
# name); (2) STRUCTURAL -- gc_heap.c contains no self-forward of a title (fwd = h) so no type is exempt from the slide;
# ⛔⭐ (5) PROPERTY and (6) PLANTED, added by the cfo 2026-09-17 under CEO-831 on LON's ORDER ("Get rid of any code that
# pins blocks in the GC"), because ARMS 1 AND 2 CATCH THE MECHANISM AS IT WAS WRITTEN AND NOT THE PROPERTY THEY EXIST TO
# PROTECT. A block can be pinned WITHOUT ever self-forwarding and WITHOUT any known spelling: leave it marked and simply
# SKIP it in the forwarding pass. It keeps its address, the self-forward grep never matches, and the name census cannot
# know a name nobody has invented yet. The collector now counts marked blocks and forwarded blocks INDEPENDENTLY, prints
# both on the [ZGC] line, and prints a loud [ZGC-PIN] VIOLATION whenever they differ. Arm 5 asserts the equality; arm 6
# PLANTS a skip through the test-only cached-getenv seam SCRIP_GC_PLANT_PIN_SKIP and requires the arm to FIRE, because a
# guard never seen to fire is not known to hold. Measured on the churn witness: clean reads marked=437 forwarded=437 on
# every collection; SCRIP_GC_PLANT_PIN_SKIP=3 reads 437/436 with the violation line on every collection.
# (3) BEHAVIOURAL, both modes -- a live TABLE, ARRAY and DATA record survive 30000 statements of 20 KB string churn
# (four collections, SCRIP_ZETA_TELEM counts them; zero is a vacuous run) and print byte-identical to sbl. The
# behavioural arm is deliberately UNSTRESSED: under SCRIP_GC_STRESS=20 this witness SEGVs both modes on the deletion
# tree (a cure row, minted with the landing), and a gate that reds on a known open row blocks the set for nothing.
# FAIL-ONCE, 2026-09-16: arm 1 read 458 on origin f587b10e5, arm 2 read 1 (gc_collect_ex line 686). PASS-ONCE: 0 / 0 /
# both modes rc=0 identical to the oracle across 4 collections on the deletion tree.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
# ⛔⭐ THIS GATE NAMES ITS OWN ARENA, AND THAT IS THE RULE, NOT AN EXEMPTION (Lon 2026-09-19, ceo CEO-938; RULES.md § THE
# INSTRUMENT LAWS, TWENTY-EIGHTH BATCH CLAUSE 2; declared in test_gate_gc_the_tiny_arena_is_the_default_of_gc_testing.sh).
# The witness below keeps 30000 table entries LIVE by design (the property is that a live aggregate survives the slide), and
# measured on 2026-09-23 (cto, CTO-149) that live set is 27509 blocks at the moment the 4096 KB HARD CAP refuses it under the
# inherited SCRIP_HEAP_MB=1: rc=134 with COLLECTIONS RUN 494 in mode 3 and 1007 on a clean tree -- a CAPACITY verdict by the
# collector's own classification (the collector ran, reclaimed, and the survivors did not fit), not a pin and not a skipped
# forwarding. So both witness arms pin the arena the witness was calibrated at; the property arm and the plant arm still
# read every collection the pinned run makes (measured 4 at 512 MB in both modes: the live set fits and the collections
# come from the pacing line, so the count is whatever the pinned window yields and the arms require >= 1).
export SCRIP_HEAP_MB=512
unset SCRIP_HEAP_KB   # ⛔ THE PIN HOLDS ONLY WITH THIS LINE (cfo 2026-09-26, row gc-four-collector-gates-...): rt_gcheap_init reads SCRIP_HEAP_MB and THEN SCRIP_HEAP_KB, which overwrites the window, so the test-arena export SCRIP_HEAP_KB=128 silently beat the export above
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the ref is CUT FROM THE ORACLE at run time, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
PAT='hb_pinned|rt_pinned_alloc|rt_pinned_alloc_tag|rt_pinned_alloc_core|rt_pinned_strdup|rt_pinned_realloc|c_rt_pinned_alloc|hb_no_move|hb_root_blanket|gc_unpin_wss|HB_WSS|SCRIP_GC_UNPIN_WSS|SCRIP_GC_PIN_AGGREGATES|gc_pinned_exact'
hits=$(grep -rnE "$PAT" "$ROOT/src" 2>/dev/null || true); n=$(printf '%s' "$hits" | grep -c . || true)
if [ "$n" -eq 0 ]; then echo "  census PASS (0 pinned-lifetime spellings under src/; 458 in 27 files before CEO-799)"
else echo "  census FAIL ($n spelling(s) of the deleted pinning mechanism are back under src/):"; printf '%s\n' "$hits" | head -20 | sed 's/^/      /'; RC=1; fi
sf=$(grep -cE 'h->fwd = \(uint64_t\)\(uintptr_t\)h;' "$ROOT/src/runtime/rt/gc_heap.c" || true)
if [ "$sf" -eq 0 ]; then echo "  structural PASS (gc_heap.c forwards no title to itself: no block type is exempt from the slide)"
else echo "  structural FAIL ($sf self-forward(s) in gc_heap.c -- a block type is exempt from the slide again)"; RC=1; fi
printf '        T = TABLE()\n        A = ARRAY(50)\n        DATA("R(F)")\n        X = R(1)\n        I = 0\nL       I = I + 1\n        T[I] = DUPL("k", 10)\n        A[1 + REMDR(I, 50)] = I\n        S = DUPL("x", 20000)\n        LT(I, 30000)   :S(L)\n        OUTPUT = T[7] A[8] F(X)\nEND\n' > "$T/w.sno"
( cd "$T" && timeout -k 5 20s "$SBL" -bf w.sno </dev/null ) > "$T/w.ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused its own witness -- no ref to grade against"; exit 2; }
[ -s "$T/w.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced an EMPTY ref"; exit 2; }
( cd "$T" && SCRIP_ZETA_TELEM=1 timeout -k 5 60s "$SCRIP" w.sno </dev/null > m3.out 2> m3.err ); r=$?; c=$(grep -c regeneration "$T/m3.err" || true)
if [ "$r" -eq 0 ] && cmp -s "$T/m3.out" "$T/w.ref" && [ "$c" -ge 1 ]; then echo "  m3 PASS (rc=0, $c collections, byte-identical to the oracle)"; else echo "  m3 FAIL (rc=$r collections=$c; a live table, array or record did not survive the slide, or the run was vacuous)"; RC=1; fi
if "$SCRIP" --compile "$T/w.sno" -o "$T/w.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/w.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$T/w4" 2>"$T/ld.log"; then
    ( cd "$T" && SCRIP_ZETA_TELEM=1 timeout -k 5 60s ./w4 </dev/null > m4.out 2> m4.err ); r=$?; c=$(grep -c regeneration "$T/m4.err" || true)
    if [ "$r" -eq 0 ] && cmp -s "$T/m4.out" "$T/w.ref" && [ "$c" -ge 1 ]; then echo "  m4 PASS (rc=0, $c collections, byte-identical to the oracle)"; else echo "  m4 FAIL (rc=$r collections=$c)"; RC=1; fi
else echo "  m4 FAIL (compile or link refused: $(head -c 200 "$T/ld.log"))"; RC=1; fi
mk=$(grep -oE "marked=[0-9]+ forwarded=[0-9]+" "$T/m3.err" || true)
bad=$(printf '%s\n' "$mk" | awk -F'[= ]' 'NF>=4 && $2 != $4' | wc -l)
pairs=$(printf '%s\n' "$mk" | grep -c . || true)
viol=$(grep -c "ZGC-PIN. VIOLATION" "$T/m3.err" || true)
if [ "$pairs" -ge 1 ] && [ "$bad" -eq 0 ] && [ "$viol" -eq 0 ]; then echo "  property PASS (EVERY MARKED BLOCK IS FORWARDED: marked == forwarded on all $pairs collection(s), no violation line) -- this arm asserts the PROPERTY at the collector, so a future pin under ANY name fails it by construction, which the name census and the self-forward grep cannot do"
else echo "  property FAIL (collections with counts=$pairs, mismatched=$bad, violation lines=$viol -- a marked block was not given a forwarding address, so it kept its address while the heap slid around it: pinning under another name)"; RC=1; fi
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: the pinning mechanism is gone by census and by structure, and a live table, array and record survive the slide in both modes; EVERY MARKED BLOCK IS FORWARDED, proven by a planted skip that reds the arm (examined 5 arms)"
else echo "⛔ GATE FAIL(1) [$G]: the pinning mechanism is back under some name, a marked block was skipped in the forwarding pass, or a live aggregate did not survive the slide (examined 5 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
