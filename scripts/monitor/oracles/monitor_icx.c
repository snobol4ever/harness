#include "../h/rt.h"
#include "monitor_ipc_lib.h"
#include <stdlib.h>
#include <string.h>
static const char icx_lval[] = "<lval>";
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static int icx_named(dptr var, const char **np, uint32_t *nl)
{
    dptr dp = VarLoc(*var);
    dptr q = NULL;
    if (InRange(globals, dp, eglobals)) q = &gnames[dp - globals];
    else if (glbl_argp && pfp) {
        struct b_proc *proc = &BlkLoc(*glbl_argp)->proc;
        dptr arg1 = &glbl_argp[1];
        dptr loc1 = pfp->pf_locals;
        int npar = abs((int)proc->nparam), ndyn = abs((int)proc->ndynam);
        if (InRange(statics, dp, estatics)) { word i = dp - statics - proc->fstatic; if (i < 0 || i >= proc->nstatic) return 0; q = &proc->lnames[i + npar + ndyn]; }
        else if (InRange(arg1, dp, &arg1[npar])) q = &proc->lnames[dp - arg1];
        else if (InRange(loc1, dp, &loc1[ndyn])) q = &proc->lnames[dp - loc1 + npar];
    }
    if (!q) return 0;
    *np = StrLoc(*q); *nl = (uint32_t)StrLen(*q);
    return 1;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static uint8_t icx_wire_type(dptr v, const void **vp, uint32_t *vlen, unsigned char buf[8])
{
    *vp = NULL; *vlen = 0;
    if (Qual(*v)) { *vlen = (uint32_t)StrLen(*v); *vp = *vlen ? (const void *)StrLoc(*v) : NULL; return MWT_STRING; }
    switch (Type(*v)) {
        case T_Null:    return MWT_STRING;
        case T_Integer: mon_ipc_int_bytes((int64_t)IntVal(*v), buf); *vp = buf; *vlen = 8; return MWT_INTEGER;
        case T_Real:    { double d; GetReal(v, d); mon_ipc_real_bytes(d, buf); *vp = buf; *vlen = 8; return MWT_REAL; }
        case T_List:    return MWT_DATA;
        case T_Table:   return MWT_TABLE;
        case T_Record:  return MWT_DATA;
        case T_Set:     return MWT_DATA;
        case T_Proc:    return MWT_CODE;
        case T_File:    return MWT_FILE;
        default:        return MWT_UNKNOWN;
    }
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void icx_mon_stmt(word line) { static int spoke = 0; if (!spoke) { spoke = 1; mon_ipc_speak_output(); } mon_ipc_stmt((int64_t)line); }
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void icx_mon_output(FILE *f, char *s, word len) { if (f == stdout && s && len > 0) mon_ipc_output(s, (uint32_t)len); }
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void icx_mon_call(struct b_proc *p) { if (p) mon_ipc_call(StrLoc(p->pname), (uint32_t)StrLen(p->pname)); }
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void icx_mon_return(struct b_proc *p, dptr v)
{
    unsigned char b[8]; const void *vp; uint32_t vl; uint8_t t;
    if (!p || !v || !mon_ipc_live()) return;
    t = icx_wire_type(v, &vp, &vl, b);
    mon_ipc_return(StrLoc(p->pname), (uint32_t)StrLen(p->pname), t, vp, vl);
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void icx_mon_value(dptr var, dptr val)
{
    const char *np = icx_lval; uint32_t nl = 6; unsigned char b[8]; const void *vp; uint32_t vl; uint8_t t;
    if (!var || !val || !mon_ipc_live()) return;
    if (!Var(*var)) return;
    if ((*var).dword & F_Typecode) { int ty = Type(*var); if (ty != T_Tvsubs && ty != T_Tvtbl) return; }
    else if (Offset(*var) == 0 && !icx_named(var, &np, &nl)) { np = icx_lval; nl = 6; }
    t = icx_wire_type(val, &vp, &vl, b);
    mon_ipc_value(np, nl, t, vp, vl);
}
