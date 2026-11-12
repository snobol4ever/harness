/* PB-RB-5 probe — CAPTURE boxes in the flat chain (IR_MATCH_ASSIGN_COND / IR_MATCH_ASSIGN_IMM
   de-brokered to flat-inline emission). Builds the capture EXACTLY as lower.c TT_CAPT_*_ASGN
   wires it: the ASSIGN node's α field holds the child's entry, the child's γ points BACK to
   the ASSIGN node (the mode-2 oracle back-edge; the flat walker drives by labels so the
   back-edge is topology-faithful but inert), and the construct's resume is the child's β.
   Semantics under test (SPITBOL manual ch.13/18): the matched subject substring
   Σ[saved_δ .. δ) is assigned to the variable — COND via the deferred-capture path that the
   scan driver flushes on overall success, IMM at the point of sub-match. Here the probe runs
   the chain DIRECTLY (no rt_scan driver), so g_rt_dcap_active==0 and rt_cap_assign_cursor
   assigns straight into the NV store; the probe sets the runtime Σ/Σlen globals exactly as
   the scan driver would before driving.
   Phase 1: SUBJECT('abc') → MATCH( COND( LIT('b') ) . V )       → expect V == "b"
   Phase 2: SUBJECT('abc') → MATCH( IMM( ALT('q','b') ) $ W )    → expect W == "b"
            (ALT in the lowered wire_alt encoding: arms in operand_aux, ports set, counter 0 —
             proves flat_drive_capture composes with the aux-arm flat_drive_alt path.) */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "IR.h"
#include "bb_box.h"

extern bb_box_fn gvar_flat_chain_build(IR_graph_t * g);
extern void *rt_frame(void);
extern int g_frame_active;
extern void bb_pool_init(void);
extern const char *Σ;
extern int Σlen;
extern DESCR_t NV_GET_fn(const char *name);

static int check_nv(const char *name, const char *want) {
    DESCR_t d = NV_GET_fn(name);
    const char *s = d.s ? d.s : "";
    int len = d.slen ? (int)d.slen : (int)strlen(s);
    printf("PROBE: NV[%s] = \"%.*s\" (len=%d)\n", name, len, s, len);
    return (int)strlen(want) == len && strncmp(s, want, (size_t)len) == 0;
}

static int run_phase(const char *tag, int imm, IR_t *(*mk_child)(IR_graph_t *, IR_t *, IR_t *),
                     const char *var, const char *want) {
    IR_graph_t *g = IR_alloc(24, IR_LANG_SNO);
    if (!g) { fprintf(stderr, "IR_alloc failed\n"); return 0; }

    IR_t *succ = IR_node_alloc(g, IR_SUCCEED);
    IR_t *fail = IR_node_alloc(g, IR_FAIL);

    IR_t *subj = IR_node_alloc(g, IR_SUBJECT);
    IR_t *subj_lit = IR_node_alloc(g, IR_LIT_STRING);
    subj_lit->sval = "abc";
    subj->α = subj_lit;

    IR_t *asg = IR_node_alloc(g, imm ? IR_MATCH_ASSIGN_IMM : IR_MATCH_ASSIGN_COND);
    asg->sval = var;
    IR_t *child = mk_child(g, asg, fail);
    asg->α = child;
    asg->γ = succ; asg->ω = fail;

    IR_t *match = IR_node_alloc(g, IR_MATCH);
    IR_t *aux[1] = { asg };
    bb_operand_aux_set(g, match, aux, 1);

    subj->γ  = match; subj->ω  = fail;
    match->γ = succ;  match->ω = fail;
    g->entry = subj;

    Σ = "abc"; Σlen = 3;
    g_frame_active = 1;
    bb_box_fn fn = gvar_flat_chain_build(g);
    g_frame_active = 0;
    if (!fn) { fprintf(stderr, "gvar_flat_chain_build returned NULL (%s)\n", tag); return 0; }
    printf("PROBE: [%s] gvar_flat_chain_build OK, fn=%p\n", tag, (void*)fn);

    DESCR_t r = fn(rt_frame(), 0);
    printf("PROBE: [%s] ran fn(rt_frame(),0) without crash; result.v=%d\n", tag, (int)r.v);
    if ((int)r.v != 1) { printf("PROBE: [%s] match failed (result.v=%d) — expected 1\n", tag, (int)r.v); return 0; }
    return check_nv(var, want);
}

static IR_t *mk_lit_b(IR_graph_t *g, IR_t *back, IR_t *fail) {
    IR_t *lb = IR_node_alloc(g, IR_MATCH_LIT); lb->sval = "b";
    lb->γ = back; lb->ω = fail;
    return lb;
}

static IR_t *mk_alt_qb(IR_graph_t *g, IR_t *back, IR_t *fail) {
    IR_t *lq  = IR_node_alloc(g, IR_MATCH_LIT); lq->sval = "q";
    IR_t *lb  = IR_node_alloc(g, IR_MATCH_LIT); lb->sval = "b";
    IR_t *alt = IR_node_alloc(g, IR_MATCH_ALT);
    lq->γ = back; lq->ω = lb;
    lb->γ = back; lb->ω = fail;
    IR_t *arms[2] = { lq, lb };
    bb_operand_aux_set(g, alt, arms, 2);
    alt->γ = back; alt->ω = fail;
    return alt;
}

int main(void) {
    bb_pool_init();
    int ok1 = run_phase("COND-LIT", 0, mk_lit_b,  "V", "b");
    int ok2 = run_phase("IMM-ALT",  1, mk_alt_qb, "W", "b");
    if (ok1 && ok2) printf("PROBE: PB-RB-5 CAPTURE OK — COND+IMM assign the matched substring in the flat chain\n");
    else            printf("PROBE: PB-RB-5 CAPTURE failed (cond=%d imm=%d)\n", ok1, ok2);
    return 0;
}
