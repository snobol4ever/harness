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
# (4) THE TRANSIENT ROWS' CLAIM (ceo-2079): the eleven TRANSIENT rows say the regex graph lives inside one rx_compile or rx_exec call and the machine collects only at an emitted poll after an
# allocating runtime call returns, so no collection finds it live. util_wsb_transient_reach.py reads that off the built libscrip_rt.so with util_gc_census's reverse-reach derivation: no
# function the symbol table places in rx.c and no RxEnv callback the source assigns (rk_rx_rule) may reach a collection entry (gc_point_arr_run, the poll, gc_collect_ex, rt_gc_collect) or a
# dispatcher (try_call_builtin_by_name, rt_call_arr_impl), across any edge but the allocator's out-of-memory exit rt_heap_out_of_memory, the one declared no-return cut (its call site is
# followed by abort(), checked in the source). (4a) a fixture disassembly where a regex root reaches a collector reads RED rc 1; (4b) one where only the cut does reads clean rc 0, and the
# same one with no cut reads RED rc 1; (4c) a blind instrument (too few roots, a root that is not defined) reads rc 2, not green; (4d) a cut call site not followed by abort() reads RED.
# THE DAY (4) TURNS RED: rx.c or an RxEnv callback gains a call whose graph reaches a collection (a rule callback that evaluates through the dispatcher, a hook that allocates and polls); from
# then a collection can find the regex graph mid-build with no root, and the TRANSIENT rows must become typed rows with a validator row (the rows are removed in the same landing).
# WHAT IT DOES NOT CLAIM. The census reads the destination type a producer names; it cannot see a pointer a program stores into a char buffer by a cast. The measure of arm (3) and the
# validator's typed rows are what catch a typed block; a byte block that holds a heap word is the case the audit rules out by reading the producers, and a one-off probe over the 152
# gc witnesses at stress 3 found no WSB or WSC block holding an arena word at the last collection (ceo-2030 ledger). The TRANSIENT rows are a declared limit. Arm (4) has its own: a call graph
# sees direct calls, tail jumps and GOT slots, so an indirect call is followed only through the roots it names (every rx.c symbol, the one RxEnv callback); a function pointer stored into an
# RxEnv by a form the scan does not read is REFUSED (an initializer), and one stored anywhere else and called from outside rx.c is invisible. The arm reads the built runtime, so it is only as
# current as out/libscrip_rt.so (util_require_fresh below).
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
RX="$HERE/util_wsb_transient_reach.py"
[ -f "$RX" ] || refuse "the regex reach instrument $RX is missing"
out="$(python3 -I "$RX" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then echo "  ok   (4) no regex road reaches a safe point: $(printf '%s' "$out" | head -1 | cut -c1-240)"
elif [ "$rc" = 2 ]; then refuse "(4) the regex reach instrument could not measure: $(printf '%s' "$out" | head -2 | tr '\n' ' ' | cut -c1-300)"
else echo "  RED  (4) a regex road reaches a safe point: $(printf '%s' "$out" | head -2 | tr '\n' ' ' | cut -c1-300)"; bad=1; fi
fx() { printf '0000000000%06x <%s>:\n' "$1" "$2"; shift 2; for l in "$@"; do printf '    0:\t%s\n' "$l"; done; printf '\n'; }
{ fx 4096 rx_compile 'call   8192 <rx_helper>' ret; fx 4352 rx_exec ret; fx 8192 rx_helper 'call   12288 <gc_collect_ex>' ret; fx 12288 gc_collect_ex ret
  fx 12544 try_call_builtin_by_name ret; fx 16384 rt_heap_out_of_memory ret; } > "$T/reach.dis"
{ fx 4096 rx_compile 'call   16384 <rt_heap_out_of_memory>' ret; fx 4352 rx_exec ret; fx 12288 gc_collect_ex ret; fx 12544 try_call_builtin_by_name ret
  fx 16384 rt_heap_out_of_memory 'jmp    20480 <rt_heap_out_of_memory.cold>'; fx 20480 rt_heap_out_of_memory.cold 'call   12288 <gc_collect_ex>' 'call   12544 <try_call_builtin_by_name>' ret; } > "$T/cut.dis"
FXA="--roots rx_compile,rx_exec --safe gc_collect_ex,try_call_builtin_by_name --min-roots 2"
out="$(python3 -I "$RX" --disasm "$T/reach.dis" $FXA 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'rx_compile reaches gc_collect_ex'; then echo "  ok   (4a) a fixture where a regex root reaches a collector reads RED and rc 1"
else echo "  RED  (4a) the reaching fixture was not refused: rc=$rc: $(printf '%s' "$out" | head -2 | tr '\n' ' ' | cut -c1-300)"; bad=1; fi
out="$(python3 -I "$RX" --disasm "$T/cut.dis" $FXA 2>&1)"; rc=$?
out2="$(python3 -I "$RX" --disasm "$T/cut.dis" $FXA --cut '' 2>&1)"; rc2=$?
if [ "$rc" = 0 ] && [ "$rc2" = 1 ] && printf '%s' "$out2" | grep -q 'rx_compile reaches'; then echo "  ok   (4b) a fixture reaching a collector only across the cut (its .cold part too) reads clean, and RED with no cut"
else echo "  RED  (4b) the cut fixture: with the cut rc=$rc ($(printf '%s' "$out" | head -1 | cut -c1-160)), without rc=$rc2"; bad=1; fi
out="$(python3 -I "$RX" --disasm "$T/cut.dis" --roots rx_compile --safe gc_collect_ex --min-roots 2 2>&1)"; rc=$?
out2="$(python3 -I "$RX" --disasm "$T/cut.dis" --roots rx_compile,ghost_root --safe gc_collect_ex --min-roots 2 2>&1)"; rc2=$?
if [ "$rc" = 2 ] && [ "$rc2" = 2 ]; then echo "  ok   (4c) too few roots and a root that is not defined both REFUSE rc 2 (a blind instrument is not green)"
else echo "  RED  (4c) the blind fixtures: rc=$rc and rc=$rc2, wanted 2 and 2"; bad=1; fi
mkdir -p "$T/src2/runtime"
printf 'void f(void) { rt_heap_out_of_memory(1, 2, 3, 4); return; }\n' > "$T/src2/runtime/oom_bad.c"
out="$(python3 -I "$RX" --disasm "$T/cut.dis" $FXA --src "$T/src2" 2>&1)"; rc=$?
printf 'void f(void) {\n    rt_heap_out_of_memory(1, 2, 3, 4);\n    abort();\n}\n' > "$T/src2/runtime/oom_bad.c"
out2="$(python3 -I "$RX" --disasm "$T/cut.dis" $FXA --src "$T/src2" 2>&1)"; rc2=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'abort()' && [ "$rc2" = 0 ]; then echo "  ok   (4d) a cut call site not followed by abort() reads RED, and one that is reads clean"
else echo "  RED  (4d) the cut call-site fixtures: rc=$rc and rc=$rc2, wanted 1 and 0: $(printf '%s' "$out" | head -1 | cut -c1-160)"; bad=1; fi
if [ "$bad" = 0 ]; then echo "GATE PASS(0) [$G]: 6 arm(s)"; exit 0; fi
echo "GATE RED(1) [$G]: see the RED arms above"; exit 1
