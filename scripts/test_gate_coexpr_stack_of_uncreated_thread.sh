#!/usr/bin/env bash
# ../harness/scripts/test_gate_coexpr_stack_of_uncreated_thread.sh -- row
# coexpr-stack-of-calls-pthread-getattr-np-on-an-uncreated-thread (hq_C 2026-09-01, corroborated by
# inspection at SCRIP bcb0ec1e; folded into coexpr-stack-leaves-the-compacting-gc-heap's landing per
# Lon's own ballot ruling: "fix its thread_id=0 defect on the way").
#
# scrip_co_stack_of (src/runtime/rt/rt_coexpr.c) used to guard only `!ctx->alive` before calling
# pthread_getattr_np(ctx->thread, ...). new_ctx->alive was set to 1 in scrip_coswitch BEFORE the
# co-expression's thread was ever created (pre-fix ~:62, well before pthread_create), so a co-expression
# reached by the GC's root-scan walk (gc_heap.c:572, unconditional over every entry in g_co_gc_head)
# during that window hit pthread_getattr_np on an uncreated thread -- undefined behaviour; on this
# glibc/Linux target it dereferences a struct pthread at the thread_id address (0 here), which reliably
# SIGSEGVs.
#
# THIS WITNESS FORCES THE EXACT STATE BY HAND rather than racing a real GC into that narrow window:
# create a real, properly-initialized scrip_coctx_t (so ctx->thread is genuinely whatever
# scrip_coexpr_create leaves it as -- proving the construction-time zero-init fix too), set ->alive = 1
# without ever creating a thread for it, and call scrip_co_stack_of directly. A fixed build must return 0
# (not-yet-created) without ever reaching pthread_getattr_np; a pre-fix build reaches
# pthread_getattr_np(0, ...) and crashes. Negative-tested both ways at mint (git-stash the fix, rebuild,
# confirm rc=139; restore, rebuild, confirm clean PASS) -- see this row's LEDGER, not asserted from
# reading the source alone.
#
# 2026-09-19 (cto, rung 2 of the coexpression rows, Lon's word that frame bytes never leave the stack): scrip_coexpr_create now
# creates the thread EAGERLY (the creator's frame image is copied onto the new thread's own stack at create time, no arena
# snapshot), so the alive-without-a-thread state exists only for rt.c's lazily started generator contexts (scrip_co_ctx_init);
# the harness checks BOTH contracts: the lazy one is refused by scrip_co_stack_of, the eager one already has its stack.
# Usage: bash ../harness/scripts/test_gate_coexpr_stack_of_uncreated_thread.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
cd "$ROOT" || exit 2
[ -r "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSE: out/libscrip_rt.so missing -- build first (make)"; exit 2; }
[ -r "$ROOT/src/runtime/rt/rt_coexpr.h" ] || { echo "REFUSE: rt_coexpr.h not where expected -- re-anchor"; exit 2; }
D="$(mktemp -d)" || { echo "REFUSE: no scratch dir"; exit 2; }
trap 'rm -rf "$D"' EXIT
SRC="$D/coexpr_stack_of_uncreated_thread_witness.c"
BIN="$D/coexpr_stack_of_uncreated_thread_witness"
cat > "$SRC" <<'EOF'
#include <stdio.h>
#include <stdint.h>
#include "rt_coexpr.h"
static void dummy_entry(void *arg) { (void)arg; }
int main(void) {
    scrip_coctx_t lazy;
    scrip_co_ctx_init(&lazy, dummy_entry, (void *)0);
    if (lazy.thread != 0) { fprintf(stderr, "FAIL: a ctx_init'd (lazy, rt.c generator-style) context has a thread before its first activation\n"); return 1; }
    lazy.alive = 1;   /* the exact pre-thread-creation state the original defect hit: alive but no thread created yet */
    { char *lo = (char *)0x1, *hi = (char *)0x1;
      int r = scrip_co_stack_of(&lazy, &lo, &hi);
      if (r != 0) { fprintf(stderr, "FAIL: scrip_co_stack_of claimed bounds (return %d) for an alive-but-uncreated lazy context\n", r); return 1; } }
    uint64_t regs[7] = {0,0,0,0,0,0,0};
    scrip_coctx_t *eager = scrip_coexpr_create((void *)0x1, regs, 0, 0, "main");
    if (eager->thread == 0 || eager->alive != 1) { fprintf(stderr, "FAIL: scrip_coexpr_create must create the co-expression's thread EAGERLY (Lon 2026-09-19: a frame image never leaves the RSP/RBP stack, so the creator's frame is copied onto the new thread's own stack at create time) -- thread=%lu alive=%d\n", (unsigned long)eager->thread, eager->alive); return 1; }
    { char *lo = (char *)0, *hi = (char *)0;
      int r = scrip_co_stack_of(eager, &lo, &hi);
      if (r != 1 || !(lo < hi)) { fprintf(stderr, "FAIL: scrip_co_stack_of must know the eagerly created thread's stack (return %d lo=%p hi=%p)\n", r, (void *)lo, (void *)hi); return 1; } }
    printf("PASS: a lazy context without a thread is refused by scrip_co_stack_of, and an eagerly created co-expression has its thread and stack before its first activation\n");
    return 0;
}
EOF
gcc -O0 -g -I "$ROOT/src/runtime/rt" -I "$ROOT/src/ir" -o "$BIN" "$SRC" "$ROOT/out/libscrip_rt.so" -Wl,-rpath,"$ROOT/out" -lpthread 2>"$D/build.log"
bc=$?
if [ "$bc" -ne 0 ]; then
    echo "REFUSE: witness failed to build"
    cat "$D/build.log"
    exit 2
fi
out=$("$BIN" 2>&1)
rc=$?
echo "$out"
if [ "$rc" -eq 139 ]; then
    echo "RED: witness SIGSEGV'd (rc=139) -- pthread_getattr_np reached on an uncreated thread"
    exit 1
fi
if [ "$rc" -eq 0 ] && echo "$out" | grep -q "^PASS:"; then
    echo "GREEN: uncreated-thread witness passed"
    exit 0
fi
echo "FAIL: witness exited rc=$rc without a clean PASS"
exit 1
