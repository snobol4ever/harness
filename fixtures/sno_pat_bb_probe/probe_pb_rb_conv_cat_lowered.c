/* PB-RB-CONV groundwork probe — BB_MATCH drives an IR_MATCH_CAT in the LOWERED (wire_seq) encoding.
   The live lowerer (lower.c wire_seq) sets NO sidecar for IR_MATCH_CAT (only IR_GCONJ gets ival
   state) and never populates the legacy counter-held bb_match_kids_state_t that flat_drive_cat
   read: the arms are PORT-CHAINED — kid i's gamma -> kid i+1's entry, last kid's gamma -> the
   CAT node — and lower_match_entry hands MATCH entry[0] (the FIRST arm), not the CAT node.
   Before this probe's fix a lowered CAT walked as ONE leaf box whose gamma was the scan's
   success — matching only the first arm, silent wrong. This probe builds CAT('a','b') exactly
   as wire_seq does under lower_match_entry (la.gamma=lb, lb.gamma=cat, gamma_in=omega_in=match,
   no sidecar, counter zero, MATCH aux[0]=la) over subject 'aab' and expects the start-1 match
   after the right-fail / left-undo / ch.18 outer slide (result.v==1) — proving the native
   chain drives the REAL lower wire_seq output. */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "IR.h"
#include "bb_box.h"

extern bb_box_fn gvar_flat_chain_build(IR_graph_t * g);
extern void *rt_frame(void);
extern int g_frame_active;
extern void bb_pool_init(void);

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

    IR_t *la  = IR_node_alloc(g, IR_MATCH_LIT); la->sval = "a";
    IR_t *lb  = IR_node_alloc(g, IR_MATCH_LIT); lb->sval = "b";
    IR_t *cat = IR_node_alloc(g, IR_MATCH_CAT);
    IR_t *match = IR_node_alloc(g, IR_MATCH);
    la->γ  = lb;    la->ω  = match;
    lb->γ  = cat;   lb->ω  = match;
    cat->γ = match; cat->ω = match;
    IR_t *aux[1] = { la };
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
    if ((int)r.v == 1) printf("PROBE: PB-RB-CONV CAT-LOWERED OK — gamma-chained wire_seq arms (no sidecar) drive natively\n");
    else               printf("PROBE: PB-RB-CONV CAT-LOWERED failed (result.v=%d) — expected 1\n", (int)r.v);
    return 0;
}
