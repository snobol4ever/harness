/* PB-RB-3 mode-3 NEGATIVE/EDGE probe — the two control-flow edges the happy-path
   probe_pb_rb_3_match.c does NOT exercise in the BB_MATCH BINARY arm (bb_match.cpp):
     (A) WHOLE-MATCH FAIL: a literal NOT present in the subject. The SPITBOL Manual
         ch.18 step-6 outer start-loop must advance the start cursor across the whole
         subject, exhaust (start > Σlen), and `jmp lbl_ω` -> the statement FAIL port.
         Builds SUBJECT('abc') -> MATCH(element='z') -> {γ:SUCCEED, ω:FAIL}; expects FAIL.
         Runtime contract (xa_flat_epilogue): result.v == 1 on SUCCEED, == 99 on FAIL.
     (B) ANCHORED MISMATCH: &ANCHOR != 0 with a literal that is present but NOT at
         cursor 0. ch.18 step-6 with &ANCHOR set must NOT slide the start cursor — the
         whole match fails immediately. Builds SUBJECT('abc') -> MATCH(element='b'); with
         kw_anchor=1, 'b' (at cursor 1) is unreachable -> FAIL. With kw_anchor=0 the same
         chain SUCCEEDS (proving the anchor flag is what changed the outcome, not the data).
   Confirms the ζ=r12 stackless model + no value stack hold on the failure edges too;
   the element is still reached only by JUMP (jmp elem_entry / element ω -> match_advance). */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "IR.h"
#include "bb_box.h"

extern bb_box_fn gvar_flat_chain_build(IR_graph_t * g);
extern void *rt_frame(void);
extern int g_frame_active;
extern void bb_pool_init(void);
extern int64_t kw_anchor;

/* Build SUBJECT(subj_s) -> MATCH(elem=lit_s) -> {γ:SUCCEED, ω:FAIL}, JIT, run, return result.v. */
static int run_match(const char *subj_s, const char *lit_s) {
    IR_graph_t *g = IR_alloc(16, IR_LANG_SNO);
    if (!g) { fprintf(stderr, "IR_alloc failed\n"); return -2; }
    IR_t *succ = IR_node_alloc(g, IR_SUCCEED);
    IR_t *fail = IR_node_alloc(g, IR_FAIL);
    IR_t *subj = IR_node_alloc(g, IR_SUBJECT);
    IR_t *subj_lit = IR_node_alloc(g, IR_LIT_STRING);
    subj_lit->sval = subj_s;
    subj->α = subj_lit;
    IR_t *elem = IR_node_alloc(g, IR_MATCH_LIT);
    elem->sval = lit_s;
    IR_t *match = IR_node_alloc(g, IR_MATCH);
    IR_t *aux[1] = { elem };
    bb_operand_aux_set(g, match, aux, 1);
    subj->γ  = match; subj->ω  = fail;
    match->γ = succ;  match->ω = fail;
    g->entry = subj;
    g_frame_active = 1;
    bb_box_fn fn = gvar_flat_chain_build(g);
    g_frame_active = 0;
    if (!fn) { fprintf(stderr, "gvar_flat_chain_build returned NULL\n"); return -3; }
    DESCR_t r = fn(rt_frame(), 0);
    return (int)r.v;
}

int main(void) {
    bb_pool_init();
    int rc = 0;

    /* (A) WHOLE-MATCH FAIL — 'z' is not in 'abc'; ch.18 outer loop must exhaust -> FAIL port. */
    kw_anchor = 0;
    int a = run_match("abc", "z");
    printf("PROBE A (unanchored, 'z' in 'abc'): result.v=%d\n", a);
    if (a == 99) printf("PROBE A: WHOLE-MATCH FAILED correctly — ch.18 start-loop exhausted, jmp lbl_omega\n");
    else { printf("PROBE A: UNEXPECTED — expected FAIL (99), got %d\n", a); rc = 1; }

    /* (B1) ANCHORED MISMATCH — 'b' present at cursor 1, but &ANCHOR=1 forbids the slide -> FAIL. */
    kw_anchor = 1;
    int b1 = run_match("abc", "b");
    printf("PROBE B1 (anchored, 'b' in 'abc'): result.v=%d\n", b1);
    if (b1 == 99) printf("PROBE B1: ANCHORED MATCH FAILED correctly — no start-cursor slide under &ANCHOR\n");
    else { printf("PROBE B1: UNEXPECTED — expected FAIL (99) under &ANCHOR, got %d\n", b1); rc = 1; }

    /* (B2) CONTROL — same chain, &ANCHOR=0, 'b' reachable by the slide -> SUCCEED.
       Proves B1's failure is caused by the anchor flag, not by the data/wiring. */
    kw_anchor = 0;
    int b2 = run_match("abc", "b");
    printf("PROBE B2 (unanchored control, 'b' in 'abc'): result.v=%d\n", b2);
    if (b2 == 1) printf("PROBE B2: SUCCEEDED — anchor flag is the only difference vs B1\n");
    else { printf("PROBE B2: UNEXPECTED — expected SUCCEED (1), got %d\n", b2); rc = 1; }

    if (rc == 0) printf("PB-RB-3 EDGES OK — whole-match-fail + anchored-fail + control all correct\n");
    else         printf("PB-RB-3 EDGES FAILED\n");
    kw_anchor = 0;
    return rc;
}
