#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <dlfcn.h>
typedef struct DESCR_t { int32_t v; uint32_t slen; union { char *s; int64_t i; double r; void *p; }; } DESCR_t;
typedef DESCR_t (*binop_fn)(DESCR_t, DESCR_t);
static unsigned long n_add, n_sub, n_mul, n_div, n_mod;
static unsigned long rr_add, ii_add, other_add;
static unsigned long rr_all, ii_all, other_all;
static binop_fn r_add, r_sub, r_mul, r_div, r_mod;
static void tally(DESCR_t a, DESCR_t b, unsigned long *rr, unsigned long *ii, unsigned long *ot) {
    if (a.v == 7 && b.v == 7) { if (rr) (*rr)++; rr_all++; }
    else if (a.v == 6 && b.v == 6) { if (ii) (*ii)++; ii_all++; }
    else { if (ot) (*ot)++; other_all++; }
}
DESCR_t rt_add(DESCR_t a, DESCR_t b) { if (!r_add) r_add = (binop_fn)dlsym(RTLD_NEXT, "rt_add"); n_add++; tally(a, b, &rr_add, &ii_add, &other_add); return r_add(a, b); }
DESCR_t rt_sub(DESCR_t a, DESCR_t b) { if (!r_sub) r_sub = (binop_fn)dlsym(RTLD_NEXT, "rt_sub"); n_sub++; tally(a, b, 0, 0, 0); return r_sub(a, b); }
DESCR_t rt_mul(DESCR_t a, DESCR_t b) { if (!r_mul) r_mul = (binop_fn)dlsym(RTLD_NEXT, "rt_mul"); n_mul++; tally(a, b, 0, 0, 0); return r_mul(a, b); }
DESCR_t rt_div(DESCR_t a, DESCR_t b) { if (!r_div) r_div = (binop_fn)dlsym(RTLD_NEXT, "rt_div"); n_div++; tally(a, b, 0, 0, 0); return r_div(a, b); }
DESCR_t rt_mod(DESCR_t a, DESCR_t b) { if (!r_mod) r_mod = (binop_fn)dlsym(RTLD_NEXT, "rt_mod"); n_mod++; tally(a, b, 0, 0, 0); return r_mod(a, b); }
__attribute__((destructor)) static void report(void) {
    fprintf(stderr, "CENSUS add=%lu sub=%lu mul=%lu div=%lu mod=%lu | TAGS realreal=%lu intint=%lu other=%lu | ADD realreal=%lu intint=%lu other=%lu\n",
            n_add, n_sub, n_mul, n_div, n_mod, rr_all, ii_all, other_all, rr_add, ii_add, other_add);
}
