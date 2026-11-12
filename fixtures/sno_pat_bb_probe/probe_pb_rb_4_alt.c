/* PB-RB-4 mode-3 execution probe — BB_MATCH drives an IR_MATCH_ALT('q','b') graph over 'abc'.
   Exercises the WITHIN-POSITION second-alternative fall-through of flat_drive_alt under the
   restored 3-piece bb_match (PB-RB-3): at start 0, 'q' fails -> ci_omega0 falls into 'b',
   which fails vs 'a' -> ci_omega1 -> ALT exhausted -> match_advance; at start 1, 'q' fails,
   'b' matches -> SUCCEED (result.v==1). The SPITBOL ch.18 bead-diagram alternation order:
   every alternative tried at each cursor before the unanchored slide. */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "IR.h"
#include "bb_box.h"
#include "IR_interp_state.h"

extern bb_box_fn gvar_flat_chain_build(IR_graph_t * g);
extern void *rt_frame(void);
extern int g_frame_active;
extern void bb_pool_init(void);

static IR_t *g_kids[2];
static bb_match_kids_state_t g_ks;

int main(void) {
    bb_pool_init();
    IR_graph_t *g = IR_alloc(16, IR_LANG_SNO);
    if (!g) { fprintf(stderr, "IR_alloc failed\n"); return 2; }

    IR_t *succ = IR_node_alloc(g, IR_SUCCEED);
    IR_t *fail = IR_node_alloc(g, IR_FAIL);

    IR_t *subj = IR_node_alloc(g, IR_SUBJECT);
    IR_t *subj_lit = IR_node_alloc(g, IR_LIT_STRING);
    subj_lit->sval = "abc";
    subj->α = subj_lit;

    IR_t *lq = IR_node_alloc(g, IR_MATCH_LIT); lq->sval = "q";
    IR_t *lb = IR_node_alloc(g, IR_MATCH_LIT); lb->sval = "b";
    IR_t *alt = IR_node_alloc(g, IR_MATCH_ALT);
    g_kids[0] = lq; g_kids[1] = lb;
    g_ks.kids = g_kids; g_ks.nkids = 2;
    alt->counter = (int64_t)(intptr_t)&g_ks;

    IR_t *match = IR_node_alloc(g, IR_MATCH);
    IR_t *aux[1] = { alt };
    bb_operand_aux_set(g, match, aux, 1);

    subj->γ  = match; subj->ω  = fail;
    match->γ = succ;  match->ω = fail;
    g->entry = subj;

    g_frame_active = 1;
    bb_box_fn fn = gvar_flat_chain_build(g);
    g_frame_active = 0;
    if (!fn) { fprintf(stderr, "gvar_flat_chain_build returned NULL\n"); return 3; }
    printf("PROBE: gvar_flat_chain_build OK, fn=%p\n", (void*)fn);

    DESCR_t r = fn(rt_frame(), 0);
    printf("PROBE: ran fn(rt_frame(),0) without crash; result.v=%d\n", (int)r.v);
    if ((int)r.v == 1) printf("PROBE: PB-RB-4 ALT OK — ('q'|'b') found in 'abc', second alternative taken within one start position\n");
    else               printf("PROBE: PB-RB-4 ALT failed (result.v=%d) — expected 1\n", (int)r.v);
    return 0;
}
