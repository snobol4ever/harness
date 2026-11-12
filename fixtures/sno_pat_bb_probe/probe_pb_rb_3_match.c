/* PB-RB-3 mode-3 execution probe — BB_MATCH inline-drives a sealed IR_MATCH_LIT element.
   Builds SUBJECT('abc') -> MATCH(element='b') -> SUCCEED as a four-port flat chain,
   JITs it via gvar_flat_chain_build, and runs it with rt_frame. The MATCH box runs the
   SPITBOL Manual ch.18 unanchored OUTER start-loop: 'b' fails at cursor 0 ('a'), the
   start cursor advances to 1, 'b' matches at cursor 1 -> the whole match succeeds.
   Confirms: the element is reached by JUMP (jmp elem_entry / element ω -> match_advance),
   NOT a (ζ,int entry) C call; stackless (ζ=r12, cursor in Δ via [r10]); no value stack. */
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

    /* SUBJECT('abc') — loads Σ base + Σlen into its ζ-slot */
    IR_t *subj = IR_node_alloc(g, IR_SUBJECT);
    IR_t *subj_lit = IR_node_alloc(g, IR_LIT_STRING);
    subj_lit->sval = "abc";
    subj->α = subj_lit;

    /* MATCH driving a sealed IR_MATCH_LIT('b') carried in operand_aux */
    IR_t *elem = IR_node_alloc(g, IR_MATCH_LIT);
    elem->sval = "b";
    IR_t *match = IR_node_alloc(g, IR_MATCH);
    IR_t *aux[1] = { elem };
    bb_operand_aux_set(g, match, aux, 1);

    /* wire the chain: SUBJECT.γ -> MATCH, MATCH.γ -> SUCCEED; both .ω -> FAIL */
    subj->γ  = match; subj->ω  = fail;
    match->γ = succ;  match->ω = fail;

    g->entry = subj;

    g_frame_active = 1;
    bb_box_fn fn = gvar_flat_chain_build(g);
    g_frame_active = 0;
    if (!fn) { fprintf(stderr, "gvar_flat_chain_build returned NULL\n"); return 3; }

    unsigned char *code = (unsigned char *)fn;
    FILE *bf = fopen("/tmp/probe_match.bin", "wb");
    if (bf) { fwrite(code, 1, 320, bf); fclose(bf); }
    printf("PROBE: gvar_flat_chain_build OK, fn=%p\n", (void*)fn);

    DESCR_t r = fn(rt_frame(), 0);
    printf("PROBE: ran fn(rt_frame(),0) without crash; result.v=%d\n", (int)r.v);
    if ((int)r.v == 1) printf("PROBE: MATCH SUCCEEDED — 'b' found in 'abc' via ch.18 outer start-loop\n");
    else               printf("PROBE: MATCH did not succeed (result.v=%d) — expected 1\n", (int)r.v);
    return 0;
}
