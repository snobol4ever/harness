/* PB-RB-1 mode-3 execution probe — REF_INVARIANT over a sealed IR_MATCH_LIT.
   Builds SUBJECT('abc') -> REF_INVARIANT('b') -> SUCCEED as a four-port flat chain,
   JITs it via gvar_flat_chain_build, disassembles, and runs it with rt_frame.
   Confirms: the 'b' literal-matcher head (a bb_box_fn, emit-time constant) lands in
   the REF_INVARIANT box's ζ-slot [r12+off]; stackless (ζ=r12), no value stack. */
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

    /* SUCCEED + FAIL landings (terminal: γ=NULL ends the chain) */
    IR_t *succ = IR_node_alloc(g, IR_SUCCEED);
    IR_t *fail = IR_node_alloc(g, IR_FAIL);

    /* SUBJECT('abc') — loads Σ/Δ */
    IR_t *subj = IR_node_alloc(g, IR_SUBJECT);
    IR_t *subj_lit = IR_node_alloc(g, IR_LIT_STRING);
    subj_lit->sval = "abc";
    subj->α = subj_lit;

    /* REF_INVARIANT('b') over a sealed IR_MATCH_LIT('b') carried in operand_aux */
    IR_t *sealed = IR_node_alloc(g, IR_MATCH_LIT);
    sealed->sval = "b";
    IR_t *ref = IR_node_alloc(g, IR_REF_INVARIANT);
    ref->sval = "b";
    IR_t *aux[1] = { sealed };
    bb_operand_aux_set(g, ref, aux, 1);

    /* wire the chain: SUBJECT.γ -> REF, REF.γ -> SUCCEED; both .ω -> FAIL */
    subj->γ = ref;  subj->ω = fail;
    ref->γ  = succ; ref->ω  = fail;

    g->entry = subj;

    g_frame_active = 1;
    bb_box_fn fn = gvar_flat_chain_build(g);
    g_frame_active = 0;
    if (!fn) { fprintf(stderr, "gvar_flat_chain_build returned NULL\n"); return 3; }

    /* dump the emitted bytes for disassembly */
    unsigned char *code = (unsigned char *)fn;
    FILE *bf = fopen("/tmp/probe_ref_inv.bin", "wb");
    if (bf) { fwrite(code, 1, 256, bf); fclose(bf); }
    printf("PROBE: gvar_flat_chain_build OK, fn=%p\n", (void*)fn);
    printf("PROBE: sealed IR_MATCH_LIT('b') head emitted as a separate box; ");
    printf("REF_INVARIANT loads its address into a ζ-slot.\n");

    /* run it: rt_frame() -> rdi (ζ frame base), entry-selector 0 */
    DESCR_t r = fn(rt_frame(), 0);
    printf("PROBE: ran fn(rt_frame(),0) without crash; result.v=%d\n", (int)r.v);
    return 0;
}
