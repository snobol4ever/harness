#!/usr/bin/env bash
# test_gate_pl_trail_mechanism.sh -- THE TRAIL (ARCH-PROLOG-BYRD-BOX-TRANSLATION.md § B.11; rung 1, hq_C 2026-09-02): r12 is TR, the
# conditional-binding log in Prolog's own rt_slab_region arena; every binder reachable from a Prolog graph enters through an rtx gate
# (rtx_plunify.s) that hands {r12, r13} to the C body as a pl_tr_ctx_t. Rung 1 opens no choice (r13 = 0 for the whole run), so the
# ladder witnesses cannot observe the log; this gate exercises the mechanism DIRECTLY through the exported C bodies, in a C harness
# compiled here against out/libscrip_rt.so:
#   (1) B = 0 (no choice): a binding is made and NOTHING is logged.
#   (2) B set, cell older than the youngest choice's frame: exactly one 32-byte entry {cell, pad, old} is pushed; the arena's top word
#       (its header, read by the GC root-range scan) tracks the live top.
#   (3) rt_pl_tr_unwind_to restores the cell and pops the entry.
#   (4) a cell YOUNGER than the youngest choice is bound but not logged (it dies with the choice).
#   (5) f(X,1) = f(2,3): the partial binding of X is undone by the failing unify itself (B.11 atomicity), tr back to its entry mark.
#   (6) the arena limit REFUSES rc=2 with a named limit -- never an abort, never a wrap into the next arena.
# EXIT: 0 every check passes · 1 a check fails · 2 UNPROVEN (no runtime library / no compiler / harness will not build).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
RT="${RT_DIR:-$ROOT/out}"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require "$ROOT/src/runtime/rt/rt_pl_trail.h" "trail header"
command -v gcc >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no gcc to build the harness"; gate_stamp; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/h.c" <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include "descr.h"
#include "rt/rt_pl_trail.h"
extern DESCR_t rt_pl_dop_unify_c(DESCR_t *args, int nargs, pl_tr_ctx_t *cx);
extern void *rt_ws_alloc_descr(size_t n);
extern int prolog_functor_arity(int);
/* a fresh f/N skeleton as a clause head's write mode builds it since 405215caf (ARCH-PROLOG-C-OUT-OF-THE-BOX 10: the box allocates the argument block and makes
   every argument cell a self-reference; the C value service rt_pl_unify_struct_fresh it replaced is deleted) -- built here the same way for the harness. */
static DESCR_t fresh_struct(int fid) { int ar = prolog_functor_arity(fid); DESCR_t *k = (DESCR_t *)rt_ws_alloc_descr((size_t)(ar > 0 ? ar : 1)); DESCR_t c; memset(&c, 0, sizeof c);
    for (int i = 0; i < ar; i++) { k[i].v = (DTYPE_t)DT_PLVAR; k[i].slen = 0; k[i].p = (void *)&k[i]; } c.v = (DTYPE_t)DT_PLREF; c.slen = (uint32_t)fid; c.p = (void *)k; return c; }
extern int prolog_atom_intern(const char *);
extern int prolog_functor_intern(int, int);
extern DESCR_t rt_pl_deref_val(DESCR_t v);
extern void core_lib_init(void);
static DESCR_t nametrap(DESCR_t *cell) { DESCR_t d; memset(&d, 0, sizeof d); d.v = DT_N; d.slen = 1; d.p = (void *)cell; return d; }
static DESCR_t ival(long long i) { DESCR_t d; memset(&d, 0, sizeof d); d.v = DT_I; d.i = i; return d; }
static DESCR_t sval(const char *s) { DESCR_t d; memset(&d, 0, sizeof d); d.v = DT_S; d.slen = (uint32_t)strlen(s); d.s = (char *)s; return d; }
static char hdr_older[64], hdr_young[64];
/* RUNG 3: B no longer implies its own threshold. A binder logs a cell at or above F.HI, the WORD at [B+32] that the
   pinned prologue seeds to the frame top and a disjunction lowers while a branch is untried, stored packed as
   (bound << 8) | DT_RAW (pl_tr_frame_hi_set) -- so a synthetic B here must carry a synthetic header, exactly as a real frame does. */
static char *synth_b(char *hdr, void *hi) { memset(hdr, 0, 64); pl_tr_frame_hi_set(hdr, hi); return hdr; }
static int fails = 0;
#define CHECK(c, msg) do { if (c) printf("  ok   %s\n", msg); else { printf("  FAIL %s\n", msg); fails++; } } while (0)
int main(void) {
    core_lib_init();
    char *tr0 = (char *)rt_pl_tr_init();
    pl_tr_ctx_t cx; cx.tr = tr0; cx.b = 0;
    DESCR_t cells[4]; memset(cells, 0, sizeof cells);
    printf("arena base=%p tr0=%p (offset %lu)\n", (void *)pl_tr_base_of(tr0), (void *)tr0, (unsigned long)(tr0 - pl_tr_base_of(tr0)));
    { DESCR_t a[2]; a[0] = nametrap(&cells[0]); a[1] = ival(5); DESCR_t r = rt_pl_dop_unify_c(a, 2, &cx);
      CHECK(r.v == DT_I && r.i == 5 && cells[0].v == DT_I && cells[0].i == 5, "B=0: unify binds the stack cell");
      CHECK(cx.tr == tr0, "B=0: nothing is logged (no choice)"); }
    memset(cells, 0, sizeof cells);
    cx.b = synth_b(hdr_older, (char *)cells);
    { DESCR_t a[2]; a[0] = nametrap(&cells[1]); a[1] = sval("bound"); char *before = cx.tr; DESCR_t r = rt_pl_dop_unify_c(a, 2, &cx);
      CHECK(r.v == DT_S && cells[1].v == DT_S, "B set, cell older than B: unify binds");
      CHECK(cx.tr == before + PL_TR_ENTRY_BYTES, "B set, cell older than B: exactly one entry logged");
      { pl_tr_entry_t *e = (pl_tr_entry_t *)before; CHECK(e->cell == &cells[1] && e->old.v == DT_SNUL, "the entry records the cell address and its old (unbound) value"); }
      CHECK(*(char **)pl_tr_base_of(cx.tr) == cx.tr, "the arena top word tracks the live top for the GC");
      cx.tr = rt_pl_tr_unwind_to(cx.tr, before);
      CHECK(cx.tr == before && cells[1].v == DT_SNUL, "unwind restores the cell to unbound and pops the entry"); }
    { DESCR_t young; memset(&young, 0, sizeof young); cx.b = synth_b(hdr_young, (char *)&young + 16); DESCR_t a[2]; a[0] = nametrap(&young); a[1] = ival(9); char *before = cx.tr; rt_pl_dop_unify_c(a, 2, &cx);
      CHECK(young.v == DT_I && cx.tr == before, "a cell younger than the youngest choice is bound but NOT logged");
      memset(&young, 0, sizeof young); pl_tr_frame_hi_set(hdr_young, &young);
      { DESCR_t b2[2]; b2[0] = nametrap(&young); b2[1] = ival(9); char *bf2 = cx.tr; rt_pl_dop_unify_c(b2, 2, &cx);
        CHECK(young.v == DT_I && cx.tr == bf2 + PL_TR_ENTRY_BYTES, "rung 3: the SAME cell IS logged once F.HI at [B+32] is lowered onto it (a disjunction opening a choice inside the frame)");
        cx.tr = rt_pl_tr_unwind_to(cx.tr, bf2); }
      cx.b = synth_b(hdr_older, (char *)cells); }
    /* f(X,1) and f(2,3): rt_pl_dop_mkc_c left the runtime with the body-term landing (c89f9447b: the emitted $mkc box builds compound terms), so the harness
       builds them the way a clause head does -- a fresh f/2 skeleton, its kids bound through the unifier (each binding trailed and kept below `before`). */
    { int f2 = prolog_functor_intern(prolog_atom_intern("f"), 2);
      DESCR_t t1 = fresh_struct(f2); DESCR_t t2 = fresh_struct(f2);
      { DESCR_t u[2]; u[0] = ((DESCR_t *)t1.p)[0]; u[1] = nametrap(&cells[2]); rt_pl_dop_unify_c(u, 2, &cx); u[0] = ((DESCR_t *)t1.p)[1]; u[1] = ival(1); rt_pl_dop_unify_c(u, 2, &cx);
        u[0] = ((DESCR_t *)t2.p)[0]; u[1] = ival(2); rt_pl_dop_unify_c(u, 2, &cx); u[0] = ((DESCR_t *)t2.p)[1]; u[1] = ival(3); rt_pl_dop_unify_c(u, 2, &cx); }
      char *before = cx.tr; DESCR_t a[2]; a[0] = t1; a[1] = t2; DESCR_t r = rt_pl_dop_unify_c(a, 2, &cx);
      CHECK(r.v == DT_FAIL, "f(X,1) = f(2,3) fails");
      CHECK(cx.tr == before, "the failing unify unwound its own suffix (B.11 atomicity)");
      { DESCR_t xv = rt_pl_deref_val(nametrap(&cells[2])); CHECK(xv.v != DT_I, "X is unbound again after the partial binding was undone"); } }
    fflush(stdout); fflush(stderr);
    { pid_t pid = fork(); if (pid == 0) { pl_tr_ctx_t c2 = cx; c2.tr = pl_tr_base_of(cx.tr) + PL_TR_ARENA_BYTES - 2 * PL_TR_ENTRY_BYTES; DESCR_t junk; memset(&junk, 0, sizeof junk); pl_tr_push(&c2, &junk); fprintf(stderr, "first push at the last slot: ok\n"); pl_tr_push(&c2, &junk); _exit(99); }
      int st = 0; waitpid(pid, &st, 0); CHECK(WIFEXITED(st) && WEXITSTATUS(st) == 2, "the arena limit REFUSES with rc=2 (never aborts, never wraps)"); }
    printf("%s (%d failures)\n", fails ? "TRAIL HARNESS FAIL" : "TRAIL HARNESS PASS", fails);
    return fails ? 1 : 0;
}
CEOF
gcc -O0 -g -I "$ROOT/src/ir" -I "$ROOT/src/runtime" -o "$W/h" "$W/h.c" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" >"$W/build.log" 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: harness does not build"; sed 's/^/    /' "$W/build.log" | head -20; gate_stamp; exit 2; }
"$W/h" > "$W/out.txt" 2>"$W/err.txt"; rc=$?
grep -E '^  (ok|FAIL) ' "$W/out.txt" | sort -u
n_ok=$(grep -c '^  ok ' "$W/out.txt"); n_fail=$(grep -c '^  FAIL ' "$W/out.txt")
GATE_EXAMINED="$((n_ok + n_fail)) checks (harness rc=$rc)"
gate_verdict "$n_fail" "trail-mechanism checks failing"
