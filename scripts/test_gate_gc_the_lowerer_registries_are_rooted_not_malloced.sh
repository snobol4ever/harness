#!/usr/bin/env bash
# test_gate_gc_the_lowerer_registries_are_rooted_not_malloced.sh -- THE LOWERER'S TWO FILE-SCOPE REGISTRIES LIVE ON THE
# COLLECTED HEAP AND ARE ROOTED (cfo 2026-09-18, reverting SCRIP f62a33aed in pieces under CEO-840).
#
# The lowerers run at RUN TIME whenever a program compiles with CODE or EVAL, so sno_build_graph executes with
# collections live and every lowerer static is a holder of the unrooted-static-holder class.
#   g_bb_labels (the Byrd-box label registry, an lc_vec) is the holder that made the class visible: a collection
#   compacted the generator procedure table DOWN and rewrote that rooted slot correctly, g_bb_labels.data was NOT
#   relocated because nothing rooted it, and the next lc_vec_push wrote a label entry through the stale pointer INTO
#   the relocated proc table; rt_gc_root_args then read a label-name rodata pointer as nparams and walked 90136
#   entries off the end.
#   g_bb_src (three parallel arrays behind bb_src_note) is the same shape one file down and had never been named.
#
# ⛔⭐ RE-PINNED 2026-09-25 by the cfo on the ceo's CEO-1272 (.github 639a475b): Lon's word of 2026-09-24 (CEO-1244, "Use the
# special compile-time heap, and use alloc/copy/abandon at geometric growth for dynamic arrays and buffers.") supersedes
# CEO-840's reading of these two registries as it did the cv_t bullet. g_bb_labels' lc_vec and g_bb_src's three arrays now
# grow through ct_grow in the compile-time arena, which never moves, so the collector neither owns nor visits their blocks.
# What stays required is the ROOT OF EVERY HEAP POINTER THEY HOLD: arms 1 and 2 now demand the element visits (each label's
# name and landing, each source record's node and text) and REFUSE a visit of the arena block; arm 3 demands ct_grow and
# refuses the collected heap and every C allocator; arm 4 is unchanged. The history below is the record of the old rule.
# ⛔ THE ARM THAT MATTERS IS ARM 3. Both were briefly "cured" by moving them to malloc/calloc/realloc (f62a33aed).
# That is what Lon's FACT RULE forbids and what the ceo's whole-tree sweep measured the cost of -- 8 of 15 collector
# gates red -- because malloc'd memory never moves, so an unrooted holder of it is only ACCIDENTALLY safe. THE CURE
# FOR AN UNROOTED HOLDER IS A ROOT, NEVER A DIFFERENT ALLOCATOR. Arm 3 requires lc_vec_push and bb_src_note to still
# allocate from the collected heap, so this gate cannot be made green by taking the holders out of the collector's
# sight again.
#
# ⛔ WHAT THIS GATE DOES NOT COVER, SAID HERE SO A GREEN IS NOT READ AS MORE THAN IT IS: lp_strdup (lower_common.c)
# is still a C malloc, deliberately. It is a CHOKE POINT -- its results are stored in IR_LIT().sval and in a dozen
# file-scope registries across lower_snobol4.c, none of them rooted -- so converting it before those holders are
# rooted would manufacture the corruption this gate exists to catch, in dozens of places at once. It is the next
# row, not an oversight. The lc_vec instances that are STACK LOCALS in the lowerers are likewise on the collected
# heap with no root; they need F5's HB_WS kind split, because a registry of live vecs would hold dead frame
# addresses and reading one is a conservative root, which the frozen design forbids.
# FAIL-ONCE MEASURED 2026-09-18 on SCRIP b21de13c4 (before the g_bb_src half landed): arm 2 red (bb_src_gc_roots absent)
# and arm 3 red (bb_src_note allocating with realloc), with arms 1 and 4 green -- so the two halves are independently
# measured and neither rides the other's green.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# RE-CUT 2026-10-09 cfo (CEO-1575, the g_lower stage): the two registries live in g_lower.lc (g_bb_labels -> g_lower.lc.bb_labels,
# g_bb_src -> g_lower.lc.bb_src), so the structural arms read the new spelling; what they count is unchanged.
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the ref is CUT FROM THE ORACLE at run time, never typed"; exit 2; }
LC="$ROOT/src/lower/lower_common.c"; [ -f "$LC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no $LC"; exit 2; }
W="$ROOT/../corpus/tests/snobol4/code_call_runtime_define_pending_entry.sno"
[ -f "$W" ] || { echo "⛔ GATE REFUSE(2) [$G]: the witness $W is not there, so nothing was measured"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
n=$(python3 "$ROOT/../harness/scripts/util_c_function_body.py" "$LC" lower_gc_roots | awk '/&e->name\)/{a++} /&e->landing\)/{c++} /&g_lower\.lc\.bb_labels\.data\)/{d++} /^bb_src_gc_roots\(\);/{b++} END{printf "%d %d %d %d", a+0, c+0, b+0, d+0}')
if [ "$n" = "1 1 1 0" ] && grep -q 'lower_gc_roots();' "$ROOT/src/runtime/rt/gc_heap.c"; then
    echo "  structural labels PASS (lower_gc_roots visits every g_lower.lc.bb_labels entry's name and landing and calls bb_src_gc_roots, and the collector calls lower_gc_roots; the label block itself is arena memory and is not visited -- CEO-1272)"
else echo "  structural labels FAIL (lower_gc_roots visits [e->name e->landing bb_src_gc_roots &g_lower.lc.bb_labels.data] = [$n], want [1 1 1 0], or gc_heap.c never calls lower_gc_roots)"; RC=1; fi
n=$(python3 "$ROOT/../harness/scripts/util_c_function_body.py" "$LC" bb_src_gc_roots | awk '/&g_lower\.lc\.bb_src\.nd\[i\]\)/{a++} /&g_lower\.lc\.bb_src\.src\[i\]\)/{b++} /&g_lower\.lc\.bb_src\.(nd|src|line)\)/{c++} END{printf "%d %d %d", a+0, b+0, c+0}')
if [ "$n" = "1 1 0" ]; then echo "  structural bb_src PASS (bb_src_gc_roots visits every entry's node and source text; the three parallel arrays are arena memory and are not visited -- CEO-1272)"
else echo "  structural bb_src FAIL (bb_src_gc_roots visits [nd[i] src[i] block] = [$n], want [1 1 0]: an element a registry holds is not rooted, or an arena block is being visited as if the collector owned it)"; RC=1; fi
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
for fn in lc_vec_push bb_src_note; do
    body=$(python3 "$ROOT/../harness/scripts/util_c_function_body.py" "$LC" "$fn")
    [ -n "$body" ] || { echo "  fact-rule FAIL ($fn not found in lower_common.c, so this arm measured nothing)"; bad=1; continue; }
    printf '%s' "$body" | grep -qE '\b(malloc|calloc|realloc|free)[[:space:]]*\(' && { echo "  fact-rule FAIL ($fn grows with a C allocator)"; bad=1; }
    printf '%s' "$body" | grep -qE "$ROOTED_RX" && { echo "  fact-rule FAIL ($fn grows on the COLLECTED heap -- CEO-1244/1272 put every compile-time population in the compile-time arena)"; bad=1; }
    printf '%s' "$body" | grep -qE '\bct_grow[[:space:]]*\(' || { echo "  fact-rule FAIL ($fn does not grow through ct_grow, the compile-time arena's alloc/copy/abandon)"; bad=1; }
done
if [ "$bad" -eq 0 ]; then echo "  fact-rule PASS (lc_vec_push and bb_src_note grow through ct_grow in the compile-time arena -- never the collected heap, never a C allocator)"; else RC=1; fi
cp "$W" "$T/w.sno"
( cd "$T" && timeout -k 5 20s "$SBL" -bf w.sno </dev/null ) > "$T/w.ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused its own witness -- no ref to grade against"; exit 2; }
[ -s "$T/w.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced an EMPTY ref"; exit 2; }
red=0; ran=0
for st in 5 30 200; do
    ( cd "$T" && SCRIP_ZETA_TELEM=1 SCRIP_GC_STRESS=$st timeout -k 5 20s "$SCRIP" w.sno </dev/null > m3.out 2> m3.err ); r=$?; ran=$((ran+1))
    c=$(grep -c regeneration "$T/m3.err" || true)
    if [ "$r" -eq 0 ] && cmp -s "$T/m3.out" "$T/w.ref" && [ "$c" -ge 1 ]; then :
    else echo "  m3 stress=$st FAIL (rc=$r collections=$c -- zero collections is a VACUOUS run and counts as red, because this witness exists to lower a program while the heap slides under it)"; red=$((red+1)); fi
done
if [ "$red" -eq 0 ]; then echo "  behavioural PASS (the DEXP witness compiles a program at RUN TIME through the lowerer and prints byte-identical to the oracle at all $ran stress values, each with at least one collection -- the lowerer registries are live while the heap slides)"
else echo "  behavioural FAIL ($red of $ran runs red)"; RC=1; fi
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: the Byrd-box label registry and the bb-source registry grow in the compile-time arena, every heap pointer they hold is ROOTED, and a program lowered at run time survives collections (examined 4 arms, $ran runs)"
else echo "⛔ GATE FAIL(1) [$G]: a lowerer registry holds a heap pointer nothing roots, grows outside the compile-time arena, or a run-time lowering does not survive collections (examined 4 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
