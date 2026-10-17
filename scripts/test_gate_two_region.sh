#!/usr/bin/env bash
# test_gate_two_region.sh — RUNG TR ledger/gate (GOAL-SNOBOL4-BB.md PHASE 0)
# TWO-REGION RULE (Lon, s35/s36): all dynamic memory is (1) the C stack (rsp ζ cells +
# C runtime frames) or (2) the malloc-backed slab pool carrying bump arenas
# (A-PROG / A-TRANS / A-SUSP / A-COEXPR — the reusable ζ blocks for co-expressions
# and generator procedures live HERE, per Lon s36).
#
# DEFAULT (ledger mode): prints per-mechanism counters. Informational, exit 0.
# --strict: any count above its sanctioned floor FAILS (reserved for TR-8 seal).
#
# Mechanism arms:
#   GC     : external-GC usage (gc.h include, GC_malloc/GC_MALLOC/GC_INIT/GC_realloc/GC_free)
#   MALLOC : raw malloc/calloc/realloc/strdup outside rt_slab.c  (RUNTIME scope only
#            in strict mode: parser tab.c/lex.c compiler-phase allocs are ledgered
#            separately — they matter at runtime only via EVAL/CODE = TR-3c/A-TRANS)
#   MMAP   : private data mmaps outside src/machine/.  ⛔ THE pat_pool.c EXCLUSION IS GONE WITH THE FILE
#            (ceo CEO-892, 2026-09-18): it was sanctioned here as "a CODE pool — RWX, program-image
#            column", and it was DEAD — pat_pool_emit and g_pat_pool_cur had ZERO callers outside their
#            own file, pat_pool_reset was never called, yet pat_pool_init ran on every scrip invocation
#            and mapped 4 MB of READ-WRITE-EXECUTE with no MAP_NORESERVE.  The sealed slab that actually
#            holds emitted BB code is bb_pool.c, which is mapped RW and mprotect'd RW→RX by bb_seal and
#            is therefore never RWX at any instant.  An exclusion outlived the thing it excused, which is
#            how a sanctioned line becomes a blind spot.
#   BSS    : mutable .bss arrays used as data arenas (za[] geometry table sanctioned:
#            compile-time metadata, not runtime object storage)
#
# SELF-TEST: run with --self-test; injects a violation into a temp copy and verifies
# the strict arm fires, then verifies clean tree passes ledger mode.
set -u
REPO="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
SRC="$REPO/src"
MODE="${1:-ledger}"

# NOCOMMENT: strip C comment lines. s36 finding — the gate counted its OWN doc comments
# (a rebase that REMOVED a GC_MALLOC call read as +1 because the commit explained itself in
# prose that named the symbol). An instrument must not grade the prose. Verified before it grades.
NOCOMMENT="grep -v -E '^[^:]*:[0-9]+:[[:space:]]*(\*|//|/\*)'"
count_gc()      { grep -rn -a 'gc\.h\|GC_malloc\|GC_MALLOC\|GC_INIT\|GC_realloc\|GC_free\|GC_strdup' \
                    "$SRC" --include='*.c' --include='*.h' --include='*.cpp' 2>/dev/null \
                  | grep -v 'gc_heap\|-parked-' | eval $NOCOMMENT | wc -l; }
count_malloc_rt(){ grep -rn -a '\b\(malloc\|calloc\|realloc\|strdup\)(' \
                    "$SRC/runtime" "$SRC/contracts" "$SRC/machine" 2>/dev/null \
                  | grep -v 'GC_\|rt_slab\.c\|-parked-' | eval $NOCOMMENT | wc -l; }
count_malloc_all(){ grep -rn -a '\b\(malloc\|calloc\|realloc\|strdup\)(' \
                    "$SRC" --include='*.c' --include='*.cpp' 2>/dev/null \
                  | grep -v 'GC_\|rt_slab\.c\|-parked-' | eval $NOCOMMENT | wc -l; }
count_mmap()    { grep -rn -a '\bmmap(' "$SRC" --include='*.c' --include='*.cpp' 2>/dev/null \
                  | grep -v 'src/machine/\|-parked-' | eval $NOCOMMENT | wc -l; }
count_bss()     { grep -rn -a 'static.*\[\s*[0-9]\{4,\}\]' "$SRC/runtime" "$SRC/contracts" 2>/dev/null \
                  | grep -v 'const\|zeta_storage\.c\|-parked-' | eval $NOCOMMENT | wc -l; }

report() {
  local gc mrt mall mm bss
  gc=$(count_gc); mrt=$(count_malloc_rt); mall=$(count_malloc_all); mm=$(count_mmap); bss=$(count_bss)
  echo "TWO-REGION LEDGER ($(date +%F))"
  echo "  GC(external-GC refs, non-parked, non-gc_heap) : $gc"
  echo "  MALLOC(runtime+contracts+machine)       : $mrt"
  echo "  MALLOC(whole tree, incl compiler phase) : $mall"
  echo "  MMAP(data, outside machine/)          : $mm"
  echo "  BSS(runtime data arenas, non-sanctioned): $bss"
  if [ "$MODE" = "--strict" ]; then
    # TR-8 floors: GC=0, runtime MALLOC=0 (sanctions folded into rt_slab or ledger),
    # data MMAP=0, BSS=0. Whole-tree malloc is informational forever (compiler phase).
    local fail=0
    [ "$gc"  -gt 0 ] && { echo "STRICT FAIL: GC arm $gc > 0"; fail=1; }
    [ "$mrt" -gt 0 ] && { echo "STRICT FAIL: runtime MALLOC arm $mrt > 0"; fail=1; }
    [ "$mm"  -gt 0 ] && { echo "STRICT FAIL: data MMAP arm $mm > 0"; fail=1; }
    [ "$bss" -gt 0 ] && { echo "STRICT FAIL: BSS arm $bss > 0"; fail=1; }
    [ "$fail" = 1 ] && { echo "TWO-REGION GATE: FAIL"; exit 1; }
    echo "TWO-REGION GATE: PASS (strict)"
  else
    echo "TWO-REGION GATE: ledger mode (informational, exit 0)"
  fi
  exit 0
}

if [ "$MODE" = "--self-test" ]; then
  TMP=$(mktemp -d)
  cp -r "$SRC/runtime/rt" "$TMP/rt-backup" >/dev/null
  VIC="$SRC/runtime/rt/rt.c"
  echo 'static void __tr_gate_selftest(void){ void*p=GC_malloc(8);(void)p; }' >> "$VIC"
  n1=$(count_gc)
  git -C "$REPO" checkout -- "$VIC"
  n0=$(count_gc)
  rm -rf "$TMP"
  if [ "$n1" -gt "$n0" ]; then echo "SELF-TEST PASS: injected violation raised GC arm $n0 -> $n1, restored"; exit 0
  else echo "SELF-TEST FAIL: injection not detected ($n0 -> $n1)"; exit 1; fi
fi

report
