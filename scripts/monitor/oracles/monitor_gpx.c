#include "engine_pl.h"
#include "monitor_ipc_lib.h"
#include <stdio.h>
#include <string.h>
#ifndef FC
#define FC
#endif
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
static const char *gpx_key(int func, PlLong arity, char *buf, size_t cap, uint32_t *len)
{
    const char *nm = (func >= 0 && (PlULong) func < pl_max_atom && pl_atom_tbl[func].name) ? pl_atom_tbl[func].name : "?";
    int n = snprintf(buf, cap, "%s/%ld", nm, (long) arity);
    if (n < 0) n = 0;
    if ((size_t) n >= cap) n = (int) cap - 1;
    *len = (uint32_t) n;
    return buf;
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void FC Pl_Mon_Stmt(PlLong line) { mon_ipc_stmt((int64_t) line); }
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void FC Pl_Mon_Call(int func, PlLong arity)
{
    char b[1024]; uint32_t l;
    if (!mon_ipc_live()) return;
    gpx_key(func, arity, b, sizeof b, &l);
    mon_ipc_call(b, l);
}
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
void FC Pl_Mon_Return(int func, PlLong arity)
{
    char b[1024]; uint32_t l;
    if (!mon_ipc_live()) return;
    gpx_key(func, arity, b, sizeof b, &l);
    mon_ipc_return(b, l, MWT_STRING, NULL, 0);
}
