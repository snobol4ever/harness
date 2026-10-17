#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <dlfcn.h>
typedef struct DESCR_t { int32_t v; uint32_t slen; union { char *s; int64_t i; double r; void *p; }; } DESCR_t;
static unsigned long n_subvar, n_subget, n_subget2, n_deref, n_aggalloc, n_toint, n_fieldvar;
static DESCR_t (*r_subvar)(DESCR_t, DESCR_t);
static DESCR_t (*r_subget)(DESCR_t, DESCR_t);
static DESCR_t (*r_subget2)(DESCR_t, DESCR_t, DESCR_t);
static DESCR_t (*r_deref)(DESCR_t);
static void *(*r_aggalloc)(int, unsigned long);
static int64_t (*r_toint)(DESCR_t);
static DESCR_t (*r_fieldvar)(const char *, DESCR_t);
DESCR_t rt_subscript_var(DESCR_t b, DESCR_t i) { if (!r_subvar) r_subvar = dlsym(RTLD_NEXT, "rt_subscript_var"); n_subvar++; return r_subvar(b, i); }
DESCR_t subscript_get(DESCR_t b, DESCR_t i) { if (!r_subget) r_subget = dlsym(RTLD_NEXT, "subscript_get"); n_subget++; return r_subget(b, i); }
DESCR_t subscript_get2(DESCR_t a, DESCR_t i, DESCR_t j) { if (!r_subget2) r_subget2 = dlsym(RTLD_NEXT, "subscript_get2"); n_subget2++; return r_subget2(a, i, j); }
DESCR_t rt_deref(DESCR_t v) { if (!r_deref) r_deref = dlsym(RTLD_NEXT, "rt_deref"); n_deref++; return r_deref(v); }
void *rt_agg_alloc(int k, unsigned long n) { if (!r_aggalloc) r_aggalloc = dlsym(RTLD_NEXT, "rt_agg_alloc"); n_aggalloc++; return r_aggalloc(k, n); }
int64_t to_int(DESCR_t d) { if (!r_toint) r_toint = dlsym(RTLD_NEXT, "to_int"); n_toint++; return r_toint(d); }
DESCR_t rt_field_var(const char *f, DESCR_t o) { if (!r_fieldvar) r_fieldvar = dlsym(RTLD_NEXT, "rt_field_var"); n_fieldvar++; return r_fieldvar(f, o); }
__attribute__((destructor)) static void report(void) {
    fprintf(stderr, "0DSUB subscript_var=%lu subscript_get=%lu subscript_get2=%lu deref=%lu agg_alloc=%lu to_int=%lu field_var=%lu\n",
            n_subvar, n_subget, n_subget2, n_deref, n_aggalloc, n_toint, n_fieldvar);
}
