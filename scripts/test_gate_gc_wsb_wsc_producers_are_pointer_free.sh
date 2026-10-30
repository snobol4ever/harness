#!/usr/bin/env bash
# test_gate_gc_wsb_wsc_producers_are_pointer_free.sh -- THE CENSUS THAT KEEPS HB_WSB AND HB_WSC A BYTE CLASS (hq_runtime, ceo-2030; ARCH-GC-COMPILE-TIME-FRAME-MAPS 13.14 second sitting (3)(c)).
#
# WHAT IT CLAIMS. The heap validator (gc_validate_heap, SCRIP_GC_VALIDATE=1) checks the typed slots of every row in gc_slot_table.c, and HB_WSB and HB_WSC are rows of zero slots, so a
# collected-heap pointer stored in one of them is invisible to it. That is safe only while no producer of either class puts such a pointer there. util_wsb_producer_audit.py reads every
# producer in SCRIP/src (rt_wsb_alloc, rt_wsb_realloc, rt_heap_alloc_c, RX_ALLOC, RX_REALLOC, and rt_gcheap_grow_block, gv_push and gv_reserve with a WSB or WSC kind) and classes it:
# BYTES when its destination is a one-level pointer to char, int, unsigned, size_t, long long or a fixed-width integer, else by a row of gc_wsb_producers.tsv (BYTES with its reason, or
# TRANSIENT, the regex tree that lives inside one runtime call). A payload that does carry a collected-heap pointer has a typed class instead (HB_NVAR, HB_FNCB, HB_DATB, HB_EVCH,
# HB_LBLT, HB_IOCH, HB_TRCE, HB_PROC, HB_DVEC, HB_PVEC) and a row with offsetof slots.
# ARMS. (1) THE CENSUS: every producer site is BYTES or has a row, and every row still matches a site (a stale row is red, so the table cannot outlive its audit). (2) FAIL-ONCE, proper
# tests on a scratch source tree (CEO-1680: nothing planted in SCRIP): a producer whose destination is a pointer-bearing struct reads UNAUDITED and rc 1; a char buffer reads BYTES and
# rc 0; a table row that matches no site reads STALE and rc 1. (3) THE MEASURE: the DONE-WHEN witness of the row, zl01_sno_captures_eval at stress 1 and a 128 KB window under
# SCRIP_GC_VALIDATE=1, ends with a summary that reads untyped=0 and findings=0, and the two rows are zero-slot typed rows (not the UNTYPED kind).
# WHAT IT DOES NOT CLAIM. The census reads the destination type a producer names; it cannot see a pointer a program stores into a char buffer by a cast. The measure of arm (3) and the
# validator's typed rows are what catch a typed block; a byte block that holds a heap word is the case the audit rules out by reading the producers, and a one-off probe over the 152
# gc witnesses at stress 3 found no WSB or WSC block holding an arena word at the last collection (ceo-2030 ledger). The TRANSIENT rows are a declared limit.
# rc=0 every arm holds; rc=1 an arm failed; rc=2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; G="$(basename "${BASH_SOURCE[0]}" .sh)"
refuse() { echo "GATE REFUSE(2) [$G]: $*"; exit 2; }
[ -x "$ROOT/scrip" ] || refuse "no $ROOT/scrip -- run make"
command -v python3 > /dev/null || refuse "python3 absent"
AUD="$HERE/util_wsb_producer_audit.py"; TAB="$HERE/gc_wsb_producers.tsv"
[ -f "$AUD" ] && [ -f "$TAB" ] || refuse "the audit script or its table is missing"
T="$(mktemp -d)" || refuse "no scratch dir"; trap 'rm -rf "$T"' EXIT
bad=0
out="$(python3 -I "$AUD" --check "$ROOT/src" "$TAB" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then echo "  ok   (1) $(printf '%s' "$out" | head -1)"
else echo "  RED  (1) the producer census: $(printf '%s' "$out" | head -4 | tr '\n' ' ' | cut -c1-400)"; bad=1; fi
mkdir -p "$T/src"
cat > "$T/src/fx_ptr.c" <<'EOF'
typedef struct fx_node { struct fx_node *next; char *name; } fx_node_t;
void fx_make(void) { fx_node_t *n = (fx_node_t *)rt_wsb_alloc(sizeof(fx_node_t)); (void)n; }
EOF
printf '' > "$T/empty.tsv"
out="$(python3 -I "$AUD" --check "$T/src" "$T/empty.tsv" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'UNAUDITED fx_ptr.c:2'; then echo "  ok   (2a) a pointer-bearing struct producer with no row reads UNAUDITED and rc 1"
else echo "  RED  (2a) the fixture producer was not refused: rc=$rc: $(printf '%s' "$out" | head -2 | tr '\n' ' ' | cut -c1-300)"; bad=1; fi
cat > "$T/src/fx_ptr.c" <<'EOF'
void fx_make(void) { char *b = (char *)rt_wsb_alloc(64); int *k = (int *)rt_heap_alloc_c(16); (void)b; (void)k; }
EOF
out="$(python3 -I "$AUD" --check "$T/src" "$T/empty.tsv" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'bytes=2 .*unaudited=0'; then echo "  ok   (2b) a char buffer and an int vector read BYTES and rc 0"
else echo "  RED  (2b) the scalar fixture was not clean: rc=$rc: $(printf '%s' "$out" | head -2 | tr '\n' ' ' | cut -c1-300)"; bad=1; fi
printf 'fx_ptr.c\tno such line\tBYTES\tmatches nothing\n' > "$T/stale.tsv"
out="$(python3 -I "$AUD" --check "$T/src" "$T/stale.tsv" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q '^STALE '; then echo "  ok   (2c) a table row that matches no site reads STALE and rc 1"
else echo "  RED  (2c) the stale row was not refused: rc=$rc: $(printf '%s' "$out" | head -2 | tr '\n' ' ' | cut -c1-300)"; bad=1; fi
W="$ROOT/../corpus/tests/shared/zeta_layout/zl01_sno_captures_eval.sno"
[ -f "$W" ] || refuse "the row's witness $W is missing"
bash "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
last="$( cd "$ROOT" && SCRIP_GC_VALIDATE=1 SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=128 timeout 60s bash "$HERE/util_run_slot.sh" ./scrip "$W" 2>&1 > /dev/null < /dev/null | grep 'ZGC-VALIDATE-HEAP' | tail -1 )"
if printf '%s' "$last" | grep -q 'untyped=0 ' && printf '%s' "$last" | grep -q 'findings=0 ' && printf '%s' "$last" | grep -q 'unrowed=none'; then echo "  ok   (3) the row's witness ends untyped=0, findings=0, unrowed=none: $(printf '%s' "$last" | cut -c1-200)"
else echo "  RED  (3) the row's witness summary: ${last:-none}"; bad=1; fi
if grep -q 'GR_UNTYPED, 0, (const gc_sfield_t \*)0, (const gc_run_t \*)0' "$ROOT/src/runtime/rt/gc_slot_table.c"; then echo "  RED  (3b) a zero-slot row of the UNTYPED kind is back in gc_slot_table.c"; bad=1; else echo "  ok   (3b) no zero-slot row of the UNTYPED kind in gc_slot_table.c"; fi
if [ "$bad" = 0 ]; then echo "GATE PASS(0) [$G]: 5 arm(s)"; exit 0; fi
echo "GATE RED(1) [$G]: see the RED arms above"; exit 1
