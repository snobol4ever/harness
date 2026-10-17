/* (d2) SELF-COST-SHARE INSTRUMENT — answers "what fraction of the window is the
 * PORTED BODY'S OWN work", which a call count and a bail count both provably cannot
 * (s188 / s221). Method: rdtsc-bracket the target INCLUSIVE, rdtsc-bracket each of its
 * already-asm callees INCLUSIVE, and report SELF = INCLUSIVE - sum(callees). Bracket
 * overhead is identical per call site, so it inflates INCLUSIVE and CALLEE alike and
 * the SELF share is bounded, not invented. Container-legal: no perf/gdb/valgrind. */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <dlfcn.h>
typedef struct DESCR_t { int32_t v; uint32_t slen; union { char *s; int64_t i; double r; void *p; }; } DESCR_t;
static inline uint64_t tsc(void) { uint32_t lo, hi; __asm__ __volatile__("rdtsc" : "=a"(lo), "=d"(hi)); return ((uint64_t)hi << 32) | lo; }
static uint64_t c_subvar, c_deref, c_agg, c_toint, c_lview;
static unsigned long n_subvar, n_deref, n_agg, n_toint, n_lview;
static int depth;
static DESCR_t (*r_subvar)(DESCR_t, DESCR_t);
static DESCR_t (*r_deref)(DESCR_t);
static void *(*r_agg)(int, unsigned long);
static int64_t (*r_toint)(DESCR_t);
static int (*r_lview)(DESCR_t, DESCR_t **, int *);
DESCR_t rt_subscript_var(DESCR_t b, DESCR_t i) {
    if (!r_subvar) r_subvar = dlsym(RTLD_NEXT, "rt_subscript_var");
    uint64_t t0 = tsc(); depth++; DESCR_t v = r_subvar(b, i); depth--; c_subvar += tsc() - t0; n_subvar++; return v;
}
DESCR_t rt_deref(DESCR_t v) {
    if (!r_deref) r_deref = dlsym(RTLD_NEXT, "rt_deref");
    uint64_t t0 = tsc(); DESCR_t r = r_deref(v); uint64_t d = tsc() - t0; if (depth) { c_deref += d; n_deref++; } return r;
}
void *rt_agg_alloc(int k, unsigned long n) {
    if (!r_agg) r_agg = dlsym(RTLD_NEXT, "rt_agg_alloc");
    uint64_t t0 = tsc(); void *p = r_agg(k, n); uint64_t d = tsc() - t0; if (depth) { c_agg += d; n_agg++; } return p;
}
int64_t to_int(DESCR_t d0) {
    if (!r_toint) r_toint = dlsym(RTLD_NEXT, "to_int");
    uint64_t t0 = tsc(); int64_t r = r_toint(d0); uint64_t d = tsc() - t0; if (depth) { c_toint += d; n_toint++; } return r;
}
int rt_list_view(DESCR_t b, DESCR_t **e, int *n) {
    if (!r_lview) r_lview = dlsym(RTLD_NEXT, "rt_list_view");
    uint64_t t0 = tsc(); int r = r_lview(b, e, n); uint64_t d = tsc() - t0; if (depth) { c_lview += d; n_lview++; } return r;
}
__attribute__((destructor)) static void report(void) {
    uint64_t callees = c_deref + c_agg + c_toint + c_lview;
    uint64_t self = c_subvar > callees ? c_subvar - callees : 0;
    fprintf(stderr, "SELFCOST subvar_incl=%llu n=%lu | deref=%llu(%lu) agg=%llu(%lu) toint=%llu(%lu) lview=%llu(%lu) | callees=%llu SELF=%llu self_pct_of_incl=%.1f%%\n",
        (unsigned long long)c_subvar, n_subvar, (unsigned long long)c_deref, n_deref, (unsigned long long)c_agg, n_agg,
        (unsigned long long)c_toint, n_toint, (unsigned long long)c_lview, n_lview,
        (unsigned long long)callees, (unsigned long long)self, c_subvar ? 100.0 * self / c_subvar : 0.0);
}
