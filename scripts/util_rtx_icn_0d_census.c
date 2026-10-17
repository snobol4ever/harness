#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <dlfcn.h>
typedef struct DESCR_t { int32_t v; uint32_t slen; union { char *s; int64_t i; double r; void *p; }; } DESCR_t;
static unsigned long n_relop, n_binop, n_listbang, n_makelist, n_sized, n_datfield, n_strcoerce, n_procvalue, n_subget2, n_subset;
static int (*r_relop)(DESCR_t, DESCR_t, int, DESCR_t *);
static int (*r_binop)(DESCR_t, DESCR_t, int, DESCR_t *);
static DESCR_t (*r_listbang)(DESCR_t, int64_t *);
static DESCR_t (*r_makelist)(DESCR_t *, int);
static DESCR_t (*r_sized)(uint64_t, uint64_t);
static DESCR_t (*r_datfield)(const char *, DESCR_t);
static DESCR_t (*r_strcoerce)(DESCR_t);
static DESCR_t (*r_procvalue)(const char *);
static DESCR_t (*r_subget2)(DESCR_t, DESCR_t, DESCR_t);
static int (*r_subset)(DESCR_t, DESCR_t, DESCR_t);
int rt_relop_overload(DESCR_t a, DESCR_t b, int op, DESCR_t *out) { if (!r_relop) r_relop = dlsym(RTLD_NEXT, "rt_relop_overload"); n_relop++; return r_relop(a, b, op, out); }
int rt_binop_overload(DESCR_t a, DESCR_t b, int op, DESCR_t *out) { if (!r_binop) r_binop = dlsym(RTLD_NEXT, "rt_binop_overload"); n_binop++; return r_binop(a, b, op, out); }
DESCR_t rt_list_bang_at(DESCR_t o, int64_t *i) { if (!r_listbang) r_listbang = dlsym(RTLD_NEXT, "rt_list_bang_at"); n_listbang++; return r_listbang(o, i); }
DESCR_t rt_make_list(DESCR_t *a, int n) { if (!r_makelist) r_makelist = dlsym(RTLD_NEXT, "rt_make_list"); n_makelist++; return r_makelist(a, n); }
DESCR_t rt_size_d(uint64_t lo, uint64_t hi) { if (!r_sized) r_sized = dlsym(RTLD_NEXT, "rt_size_d"); n_sized++; return r_sized(lo, hi); }
DESCR_t dat_field_get(const char *f, DESCR_t o) { if (!r_datfield) r_datfield = dlsym(RTLD_NEXT, "dat_field_get"); n_datfield++; return r_datfield(f, o); }
DESCR_t rt_str_coerce(DESCR_t d) { if (!r_strcoerce) r_strcoerce = dlsym(RTLD_NEXT, "rt_str_coerce"); n_strcoerce++; return r_strcoerce(d); }
DESCR_t rt_proc_value(const char *n) { if (!r_procvalue) r_procvalue = dlsym(RTLD_NEXT, "rt_proc_value"); n_procvalue++; return r_procvalue(n); }
DESCR_t subscript_get2(DESCR_t a, DESCR_t i, DESCR_t j) { if (!r_subget2) r_subget2 = dlsym(RTLD_NEXT, "subscript_get2"); n_subget2++; return r_subget2(a, i, j); }
int subscript_set(DESCR_t a, DESCR_t i, DESCR_t v) { if (!r_subset) r_subset = dlsym(RTLD_NEXT, "subscript_set"); n_subset++; return r_subset(a, i, v); }
__attribute__((destructor)) static void report(void) {
    fprintf(stderr, "0DCENSUS relop=%lu binop=%lu list_bang=%lu make_list=%lu size_d=%lu dat_field=%lu str_coerce=%lu proc_value=%lu subget2=%lu subset=%lu\n",
            n_relop, n_binop, n_listbang, n_makelist, n_sized, n_datfield, n_strcoerce, n_procvalue, n_subget2, n_subset);
}
