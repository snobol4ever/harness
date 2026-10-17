#define MVM_SHARED 1
#include "moar.h"
#include "monitor_ipc_lib.h"
#include <string.h>
#define RKX_REG(tc, idx) (*tc->interp_reg_base)[*((MVMuint16 *)(cur_op + idx))]
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static MVMObject *rkx_decont(MVMThreadContext *tc, MVMObject *v)
{
    if (!v || !IS_CONCRETE(v)) return v;
    const MVMContainerSpec *cs = STABLE(v)->container_spec;
    if (!cs) return v;
    if (cs->name && (strcmp(cs->name, "value_desc_cont") == 0 || strcmp(cs->name, "native_ref") == 0)) { MVMRegister r; cs->fetch(tc, v, &r); return r.o; }
    return NULL;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static uint8_t rkx_wire_type(MVMThreadContext *tc, MVMObject *v, const void **vp, uint32_t *vlen, unsigned char buf[8], char **tofree)
{
    *vp = NULL; *vlen = 0; *tofree = NULL;
    v = rkx_decont(tc, v);
    if (!v || !IS_CONCRETE(v)) return MWT_UNKNOWN;
    const MVMStorageSpec *ss = REPR(v)->get_storage_spec(tc, STABLE(v));
    if (ss->can_box & MVM_STORAGE_SPEC_CAN_BOX_STR) {
        MVMuint64 n = 0; char *c = MVM_string_utf8_encode(tc, MVM_repr_get_str(tc, v), &n, 0);
        *tofree = c; *vp = n ? (const void *)c : NULL; *vlen = (uint32_t)n; return MWT_STRING;
    }
    if (ss->can_box & MVM_STORAGE_SPEC_CAN_BOX_INT) {
        if (REPR(v)->ID == MVM_REPR_ID_P6opaque && MVM_bigint_is_big(tc, v)) return MWT_UNKNOWN;
        mon_ipc_int_bytes((int64_t)MVM_repr_get_int(tc, v), buf); *vp = buf; *vlen = 8; return MWT_INTEGER;
    }
    if (ss->can_box & MVM_STORAGE_SPEC_CAN_BOX_NUM) { mon_ipc_real_bytes((double)MVM_repr_get_num(tc, v), buf); *vp = buf; *vlen = 8; return MWT_REAL; }
    const char *nm = MVM_6model_get_debug_name(tc, v);
    if (!strcmp(nm, "Array") || !strcmp(nm, "List") || !strcmp(nm, "Seq") || !strcmp(nm, "Slip") || !strcmp(nm, "Range")) return MWT_ARRAY;
    if (!strcmp(nm, "Hash") || !strcmp(nm, "Map")) return MWT_TABLE;
    if (!strcmp(nm, "Sub") || !strcmp(nm, "Block") || !strcmp(nm, "Method") || !strcmp(nm, "Routine") || !strcmp(nm, "Code") || !strcmp(nm, "WhateverCode")) return MWT_CODE;
    if (!strcmp(nm, "IO::Handle")) return MWT_FILE;
    return MWT_UNKNOWN;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static void rkx_named_event(MVMThreadContext *tc, MVMString *name, MVMObject *val, int is_return)
{
    unsigned char b[8]; const void *vp; uint32_t vl; char *tofree; MVMuint64 nl = 0;
    char *nm = MVM_string_utf8_encode(tc, name, &nl, 0);
    uint8_t t = rkx_wire_type(tc, val, &vp, &vl, b, &tofree);
    if (is_return) mon_ipc_return(nm, (uint32_t)nl, t, vp, vl); else mon_ipc_value(nm, (uint32_t)nl, t, vp, vl);
    if (tofree) MVM_free(tofree);
    MVM_free(nm);
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static MVMuint8 s_p6monstmt[] = { MVM_operand_int64 | MVM_operand_read_reg };
static void p6monstmt(MVMThreadContext *tc, MVMuint8 *cur_op) { mon_ipc_stmt((int64_t)RKX_REG(tc, 0).i64); }
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static MVMuint8 s_p6moncall[] = { MVM_operand_str | MVM_operand_read_reg };
static void p6moncall(MVMThreadContext *tc, MVMuint8 *cur_op)
{
    MVMuint64 nl = 0; char *nm;
    if (!mon_ipc_live()) return;
    nm = MVM_string_utf8_encode(tc, RKX_REG(tc, 0).s, &nl, 0);
    mon_ipc_call(nm, (uint32_t)nl);
    MVM_free(nm);
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static MVMuint8 s_p6monval[] = { MVM_operand_obj | MVM_operand_write_reg, MVM_operand_str | MVM_operand_read_reg, MVM_operand_obj | MVM_operand_read_reg };
static void p6monval(MVMThreadContext *tc, MVMuint8 *cur_op)
{
    MVMObject *v = RKX_REG(tc, 4).o;
    RKX_REG(tc, 0).o = v;
    if (!mon_ipc_live()) return;
    rkx_named_event(tc, RKX_REG(tc, 2).s, v, 0);
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static MVMuint8 s_p6monret[] = { MVM_operand_obj | MVM_operand_write_reg, MVM_operand_str | MVM_operand_read_reg, MVM_operand_obj | MVM_operand_read_reg };
static void p6monret(MVMThreadContext *tc, MVMuint8 *cur_op)
{
    MVMObject *v = RKX_REG(tc, 4).o;
    RKX_REG(tc, 0).o = v;
    if (!mon_ipc_live()) return;
    rkx_named_event(tc, RKX_REG(tc, 2).s, v, 1);
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
MVM_DLL_EXPORT void Rakudo_mon_ops_init(MVMThreadContext *tc)
{
    MVM_ext_register_extop(tc, "p6monstmt", p6monstmt, 1, s_p6monstmt, NULL, NULL, 0);
    MVM_ext_register_extop(tc, "p6moncall", p6moncall, 1, s_p6moncall, NULL, NULL, 0);
    MVM_ext_register_extop(tc, "p6monval",  p6monval,  3, s_p6monval,  NULL, NULL, 0);
    MVM_ext_register_extop(tc, "p6monret",  p6monret,  3, s_p6monret,  NULL, NULL, 0);
}
