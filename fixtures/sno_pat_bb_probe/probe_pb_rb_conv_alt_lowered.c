/* PB-RB-CONV groundwork probe — BB_MATCH drives an IR_MATCH_ALT in the LOWERED encoding.
   The live lowerer (lower.c wire_alt) carries alternation arms in the operand_aux sidecar
   (PEERS RULE) and port-wires them (arm.gamma -> ALT node, arm0.omega -> arm1 entry); it
   never populates the legacy counter-held bb_match_kids_state_t that flat_drive_alt read.
   Before this probe's fix a lowered ALT read nkids==0 and emitted the DEGENERATE arm —
   silent wrong. This probe builds ALT('q','b') exactly as wire_alt does (aux arms, ports
   set, counter zero) over subject 'abc' and expects the within-position second-alternative
   match at start 1 (result.v==1) — proving the native chain drives the REAL lower output. */
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
    subj_lit->sval = "abc";
    subj->α = subj_lit;

    IR_t *lq  = IR_node_alloc(g, IR_MATCH_LIT); lq->sval = "q";
    IR_t *lb  = IR_node_alloc(g, IR_MATCH_LIT); lb->sval = "b";
    IR_t *alt = IR_node_alloc(g, IR_MATCH_ALT);
    lq->γ = alt; lq->ω = lb;
    lb->γ = alt; lb->ω = fail;
    IR_t *arms[2] = { lq, lb };
    bb_operand_aux_set(g, alt, arms, 2);

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
    if ((int)r.v == 1) printf("PROBE: PB-RB-CONV ALT-LOWERED OK — operand_aux arms (wire_alt encoding) drive natively\n");
    else               printf("PROBE: PB-RB-CONV ALT-LOWERED failed (result.v=%d) — expected 1\n", (int)r.v);
    return 0;
}
