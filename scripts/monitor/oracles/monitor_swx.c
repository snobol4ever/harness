#include "pl-incl.h"
#include "pl-proc.h"
#include "monitor_ipc_lib.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static int swx_on = -1;
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static uint32_t swx_key(atom_t name, size_t arity, char *buf, size_t cap)
{
    size_t len = 0; char *s = NULL;
    if (!PL_atom_mbchars(name, &len, &s, REP_UTF8|CVT_ATOM|BUF_STACK) || !s) { s = "?"; len = 1; }
    int n = snprintf(buf, cap, "%.*s/%zu", (int) len, s, arity);
    if (n < 0) n = 0;
    if ((size_t) n >= cap) n = (int) cap - 1;
    return (uint32_t) n;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void mon_swx_call(Definition def)
{
    char b[1024];
    if (!mon_ipc_live()) return;
    uint32_t l = swx_key(def->functor->name, def->functor->arity, b, sizeof b);
    mon_ipc_call(b, l);
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static
PRED_IMPL("$mon_enabled", 0, mon_enabled, 0)
{
    if (swx_on < 0) {
        const char *e = getenv("SWIPL_MON"), *r = getenv("MONITOR_READY_PIPE");
        swx_on = (e && strcmp(e, "1") == 0) || (r && *r && !(e && strcmp(e, "0") == 0));
    }
    return swx_on && !GD->bootsession;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static
PRED_IMPL("$mon_stmt", 1, mon_stmt, 0)
{
    PRED_LD
    int64_t line;
    if (mon_ipc_live() && PL_get_int64(A1, &line)) mon_ipc_stmt(line);
    return true;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static
PRED_IMPL("$mon_ret", 2, mon_ret, 0)
{
    PRED_LD
    atom_t name; size_t arity; char b[1024];
    if (mon_ipc_live() && PL_get_atom(A1, &name) && PL_get_size_ex(A2, &arity)) mon_ipc_return(b, swx_key(name, arity, b, sizeof b), MWT_STRING, NULL, 0);
    return true;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static
PRED_IMPL("$mon_mark", 1, mon_mark, PL_FA_TRANSPARENT)
{
    PRED_LD
    Procedure proc;
    if (get_procedure(A1, &proc, 0, GP_FIND)) set(proc->definition, P_MON_CALL);
    return true;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
BeginPredDefs(mon)
  PRED_DEF("$mon_enabled", 0, mon_enabled, 0)
  PRED_DEF("$mon_stmt",    1, mon_stmt,    0)
  PRED_DEF("$mon_ret",     2, mon_ret,     0)
  PRED_DEF("$mon_mark",    1, mon_mark,    PL_FA_TRANSPARENT)
EndPredDefs
