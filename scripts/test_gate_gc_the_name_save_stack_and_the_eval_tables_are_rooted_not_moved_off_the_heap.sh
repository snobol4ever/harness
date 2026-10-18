#!/usr/bin/env bash
# test_gate_gc_the_name_save_stack_and_the_eval_tables_are_rooted_not_moved_off_the_heap.sh -- THREE HOLDERS OF THE
# UNROOTED-STATIC-HOLDER CLASS ARE ROOTED, AND THE GATE REFUSES THE OTHER CURE (cfo 2026-09-17, under Lon's FACT RULE
# CEO-832 and the ceo's CEO-836 ordering: REMOVING malloc AND ROOTING THE HOLDERS ARE THE SAME JOB AND THE ROOTING
# COMES FIRST).
#
# THE CLASS: a C file-scope static holds a pointer into the COLLECTED heap, no root walk visits it, a compaction
# relocates or reclaims what it points at, and the static then reads or WRITES through the stale pointer.
#
# THE THREE HOLDERS, each measured on this witness and not inferred:
#   (1) g_name_save (rt.c) -- the SNOBOL4 name-save stack. rt_gc_ws_roots visited every entry's .old DESCR but NEVER
#       the ARRAY BLOCK ITSELF, nor .name, nor .cell. Visiting a descriptor inside a block does not mark the block:
#       the array was unmarked at every collection, reclaimed under a live call, and re-carved as a string. The
#       signature is unmistakable and is the reason this is not a theory -- rt_name_restore read a name pointer whose
#       VALUE was 0x54555054554f5f, which is the ASCII bytes of _OUTPUT: the slot that held a pointer now holds the
#       neighbouring string's characters.
#   (2) g_lbl_tab + its keys and (3) g_eval_cache + its keys (runtime_eval.c) -- the runtime label table and the EVAL
#       chain cache, both on the collected heap with no root; rt_label_set_fn then did strcmp on a moved name.
#
# ⛔ WHY ARM 3 EXISTS AND IS THE POINT OF THE GATE. These three were briefly "cured" by moving them OFF the collected
# heap to malloc/calloc/realloc/strdup (SCRIP f62a33aed). That passes every behavioural arm below and is FORBIDDEN:
# Lon's rule is that we have a collector and the collector is the allocator, and the ceo measured what a whole-tree
# sweep in that shape costs -- 8 of 15 collector gates red, because malloc'd memory never moves, so an unrooted
# holder of it is only ACCIDENTALLY safe. THE CURE FOR AN UNROOTED HOLDER IS A ROOT, NEVER A DIFFERENT ALLOCATOR.
# Arm 3 therefore requires the three allocation sites to still read rt_ws_alloc / rt_ws_realloc / rt_heap_strdup_c,
# so a future seat cannot make this gate green by taking the holders out of the collector's sight.
#
# ⛔ WHY THE STRESS BAND AND NOT TWO VALUES. The row's own DONE-WHEN samples SCRIP_GC_STRESS=30 and =200 only. On
# origin this witness is GREEN at 30 and at 200 and RED at 5 and 10 -- the crashing band is ragged, so two sampled
# points are a lottery (CEO-807). This gate walks a BAND and any red in it is a red.
# FAIL-ONCE MEASURED, 2026-09-17, not asserted: on origin (SCRIP bdc486824) m3 SIGSEGVs rc=139 at stress 5 and 10 and
# passes at 15..500; with the eval tables back on the collected heap and NO roots, m3 and m4 SIGSEGV at 30 and m4 at
# 200 as well; with all three holders rooted, all 16 behavioural arms rc=0 byte-identical.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the ref is CUT FROM THE ORACLE at run time, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
M="$ROOT/../corpus/tests/snobol4"; W="$T/code_call_runtime_define_pending_entry.sno"   # a master entry, extracted by its origin (hq_snobol4 2026-10-17, the absorb row)
python3 "$HERE/corpus_suite_harness.py" extract "$M/ALL.sno" "$M/ALL.ref" --origin code_call_runtime_define_pending_entry "$W" >/dev/null 2>&1
[ -f "$W" ] || { echo "⛔ GATE REFUSE(2) [$G]: the witness (master origin code_call_runtime_define_pending_entry) could not be extracted from $M/ALL.{sno,ref,csv}, so nothing was measured"; exit 2; }
RC=0
cp "$W" "$T/w.sno"
n="$(python3 "$ROOT/../harness/scripts/util_c_function_body.py" "$ROOT/src/runtime/by_name_dispatch.c" bnd_gc_roots | grep -cF 'for (rk_cbh_t *h = g_rk_cbh_cur; h; h = h->prev)') $(grep -oF 'g_rk_cbh_cur = &H;' "$ROOT/src/runtime/by_name_dispatch.c" | wc -l) $(grep -oF 'g_rk_cbh_cur = H.prev;' "$ROOT/src/runtime/by_name_dispatch.c" | wc -l)"
seq=$(grep -oE 'g_rk_cbh_cur = (&H|H\.prev);' "$ROOT/src/runtime/by_name_dispatch.c" | sed -e 's/.*&H;/L/' -e 's/.*H\.prev;/U/' | tr -d '\n')
paired=$(printf '%s' "$seq" | awk '{ok = ($0 ~ /^(LU+)+$/) ? 1 : 0; print ok}')
nl=$(printf '%s' "$seq" | tr -cd L | wc -c)
if [ "${n%% *}" = 1 ] && [ "${paired:-0}" = 1 ] && [ "$nl" -ge 4 ]; then echo "  structural holds PASS (bnd_gc_roots walks the rk_cbh_t chain from g_rk_cbh_cur, every Raku block-callback builtin links its frame record and unlinks it before the next link in source order ($nl links, order $seq) -- the holder g_rk_cb_hold is gone, CEO-1560; visiting a descriptor inside a block does not mark the block)"
else echo "  structural holds FAIL (bnd_gc_roots chain walk, site links, site unlinks = [$n], link/unlink order [$seq], want the walk present, at least 4 links, and in source order every link followed by its unlink before the next link: a held array is reclaimed under a live callback and re-carved as a string)"; RC=1; fi
if python3 "$ROOT/../harness/scripts/util_c_function_body.py" "$ROOT/src/runtime/runtime_eval.c" eval_gc_roots 2>/dev/null | head -1 | grep -q '^void eval_gc_roots(void) {$' && grep -q 'eval_gc_roots();' "$ROOT/src/runtime/rt/gc_heap.c"; then
    echo "  structural eval PASS (eval_gc_roots is defined in runtime_eval.c AND called from the collector's root phase -- a root walk nothing calls is not a root)"
else echo "  structural eval FAIL (eval_gc_roots is missing, or gc_heap.c never calls it: the label table and the eval cache have no root)"; RC=1; fi
# ⛔⭐ THE COLLECTED-HEAP ALLOCATOR FAMILY COMES FROM ITS ONE AUTHORITY, NOT FROM A SPELLING TYPED HERE (ceo CEO-946).
# THIS ARM WAS RED ON ORIGIN FOR DAYS AND THE HOLDERS WERE FINE: it grepped for rt_ws_alloc / rt_ws_realloc, and the
# HB_WS kind with both of those names was DELETED at place D (the cfo, CEO-925) when its sites took typed kinds. The
# three holders moved to the ATOMIC sibling rt_wsb_alloc / rt_wsb_realloc, which is still the COLLECTED heap -- marked,
# relocated, interior never scanned -- and is on util_c_allocator_census.py's ROOTED-HEAP list, the tree's one record of
# which allocators the collector owns. So the gate said "moved off the heap instead of rooted" about a holder that had
# been rooted all along, and every seat's `make test` carried the red. A gate that names an allocator by spelling dies
# at the next retype; this one reads the family and survives it, because the standing rule already makes a landing that
# adds an allocator update that list.
rooted_family() {
    python3 - "$ROOT/../harness/scripts/util_c_allocator_census.py" <<'PYEOF'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'"ROOTED-HEAP":\s*\(([^)]*)\)', s)
names = re.findall(r'"([A-Za-z_][A-Za-z_0-9]*)"', m.group(1)) if m else []
names += ["rt_heap_strdup_c", "rt_gcheap_alloc", "c_rt_str_alloc"]
print("|".join(sorted(set(names))))
PYEOF
}
ROOTED_RX=$(rooted_family)
case "$ROOTED_RX" in
    *rt_wsb_alloc*) : ;;
    *) echo "⛔ GATE REFUSE(2) [$G]: could not read the ROOTED-HEAP allocator family from ../harness/scripts/util_c_allocator_census.py (got [$ROOTED_RX]). A predicate that cannot be evaluated FAILS CLOSED -- this gate does not guess a spelling."; exit 2 ;;
esac
bad=0
for fn in eval_cache_put rt_label_set_fn; do
    body=$(python3 "$ROOT/../harness/scripts/util_c_function_body.py" "$ROOT/src/runtime/runtime_eval.c" "$fn")
    printf '%s' "$body" | grep -qE '\b(malloc|calloc|realloc|strdup)[[:space:]]*\(' && { echo "  fact-rule FAIL ($fn allocates with a C allocator -- moving a holder off the collected heap is the SAME EVASION as pinning it, one indirection further out; the cure for an unrooted holder is a ROOT)"; bad=1; }
    printf '%s' "$body" | grep -qE "$ROOTED_RX" || { echo "  fact-rule FAIL ($fn no longer allocates from the collected heap at all, so the roots below are guarding nothing)"; bad=1; }
done
grep -q 'rt_rk_cb_grow\|g_rk_cb_hold' "$ROOT/src/runtime/rt/rt.c" && { echo "  fact-rule FAIL (a grown Raku holder is back in rt.c: since CEO-1560 the Raku block-callback holds are rk_cbh_t cells on the builtin's own C frame, chained from g_rk_cbh_cur and visited by bnd_gc_roots, and allocate nothing)"; bad=1; }
if [ "$bad" -eq 0 ]; then echo "  fact-rule PASS (both eval holders still allocate from the COLLECTED heap and the Raku holds are frame cells, never a grown holder -- this gate cannot be made green by taking them out of the collector's sight)"; else RC=1; fi
( cd "$T" && timeout -k 5 20s "$SBL" -bf w.sno </dev/null ) > "$T/w.ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused its own witness -- no ref to grade against"; exit 2; }
[ -s "$T/w.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced an EMPTY ref"; exit 2; }
if "$SCRIP" --compile "$T/w.sno" -o "$T/w.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/w.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$T/w4" 2>"$T/ld.log"; then :; else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link failed, so every m4 arm measured nothing (see $T/ld.log)"; exit 2; fi
red=0; ran=0
for st in 0 5 10 15 20 30 40 200; do
    ( cd "$T" && SCRIP_GC_STRESS=$st timeout -k 5 20s "$SCRIP" w.sno </dev/null > m3.out 2>/dev/null ); r=$?; ran=$((ran+1))
    if [ "$r" -eq 0 ] && cmp -s "$T/m3.out" "$T/w.ref"; then :; else echo "  m3 stress=$st FAIL (rc=$r; 139 is the stale-holder SIGSEGV, 0-with-diff the silently wrong answer)"; red=$((red+1)); fi
    ( cd "$T" && SCRIP_GC_STRESS=$st timeout -k 5 20s ./w4 </dev/null > m4.out 2>/dev/null ); r=$?; ran=$((ran+1))
    if [ "$r" -eq 0 ] && cmp -s "$T/m4.out" "$T/w.ref"; then :; else echo "  m4 stress=$st FAIL (rc=$r)"; red=$((red+1)); fi
done
if [ "$red" -eq 0 ]; then echo "  band PASS (the DEXP witness is rc=0 and byte-identical to the oracle at every one of $ran runs across SCRIP_GC_STRESS 0 5 10 15 20 30 40 200 in BOTH modes -- a band, because origin is green at 30 and 200 and red at 5 and 10, so two sampled points are a lottery)"
else echo "  band FAIL ($red of $ran runs red across the stress band -- a holder of collected-heap memory is still unrooted)"; RC=1; fi
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: the name-save stack, the runtime label table and the eval chain cache are ROOTED while still living on the collected heap, and the DEXP witness survives the whole stress band in both modes (examined 4 arms, $ran runs)"
else echo "⛔ GATE FAIL(1) [$G]: an unrooted static holder of collected-heap memory is back, or a holder was moved off the heap instead of rooted (examined 4 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
