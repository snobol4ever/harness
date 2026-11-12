/* PB-RB-4 mode-3 execution probe — BB_MATCH drives an IR_MATCH_CAT('a','b') graph over 'aab'.
   Exercises the right-omega -> left-beta INNER backtrack edge of flat_drive_cat under the
   restored 3-piece bb_match (PB-RB-3): at start 0, 'a' matches (delta 0->1), 'b' fails vs
   subject[1]=='a' -> right_omega -> left_beta -> lit'a' beta undoes delta -> xcat_omega ->
   match_advance (ch.18 step 6); at start 1, 'a' then 'b' both match -> SUCCEED (result.v==1).
   Kids ride the counter-held bb_match_kids_state_t exactly as src/tools/emit_per_kind_audit.c. */
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
    subj_lit->sval = "aab";
    subj->α = subj_lit;

    IR_t *la = IR_node_alloc(g, IR_MATCH_LIT); la->sval = "a";
    IR_t *lb = IR_node_alloc(g, IR_MATCH_LIT); lb->sval = "b";
    IR_t *cat = IR_node_alloc(g, IR_MATCH_CAT);
    g_kids[0] = la; g_kids[1] = lb;
    g_ks.kids = g_kids; g_ks.nkids = 2;
    cat->counter = (int64_t)(intptr_t)&g_ks;

    IR_t *match = IR_node_alloc(g, IR_MATCH);
    IR_t *aux[1] = { cat };
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
    if ((int)r.v == 1) printf("PROBE: PB-RB-4 CAT OK — 'a' 'b' found in 'aab' via right-omega->left-beta backtrack + ch.18 outer slide\n");
    else               printf("PROBE: PB-RB-4 CAT failed (result.v=%d) — expected 1\n", (int)r.v);
    return 0;
}
