#define _GNU_SOURCE
#include <link.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#define MAXS 8192
static const char *nm_[MAXS]; static unsigned long ct_[MAXS]; static int n_=0;
static int slot(const char*s){ for(int i=0;i<n_;i++) if(!strcmp(nm_[i],s)) return i;
  if(n_<MAXS){ nm_[n_]=strdup(s); ct_[n_]=0; return n_++; } return -1; }
unsigned int la_version(unsigned int v){ (void)v; return LAV_CURRENT; }
unsigned int la_objopen(struct link_map *m, Lmid_t l, uintptr_t *c){ (void)m;(void)l;(void)c; return LA_FLG_BINDFROM|LA_FLG_BINDTO; }
uintptr_t la_symbind64(Elf64_Sym *s, unsigned int n, uintptr_t *r, uintptr_t *d, unsigned int *f, const char *x){
  (void)n;(void)r;(void)d;(void)x; *f=0; return s->st_value; }
Elf64_Addr la_x86_64_gnu_pltenter(Elf64_Sym *s, unsigned int n, uintptr_t *r, uintptr_t *d, La_x86_64_regs *g, unsigned int *f, const char *x, long int *w){
  (void)n;(void)r;(void)d;(void)g;(void)f;(void)w;
  if(x && strncmp(x,"rt_",3)==0){ int i=slot(x); if(i>=0) ct_[i]++; }
  return s->st_value; }
__attribute__((destructor)) static void rep(void){
  const char *p=getenv("AUDIT_OUT"); if(!p) p="/tmp/aud/counts.txt";
  FILE*f=fopen(p,"a"); if(!f) return;
  for(int i=0;i<n_;i++) if(ct_[i]) fprintf(f,"%lu %s\n",ct_[i],nm_[i]);
  fclose(f); }
/*----------------------------------------------------------------------------------------------------------*/
/* HOW TO USE, AND THE TRAP THAT MAKES IT WRONG (s11).  This is an LD_AUDIT library: it counts rt_* calls per
   symbol with ZERO knowledge of any signature, which is what makes a whole-call-set census tractable where
   util_rtx_icn_0d_census.c (one hand-written signature per symbol) does not scale.
   BUILD:  gcc -shared -fPIC -o /tmp/audit.so ../harness/scripts/util_rtcc_crossing_audit.c
   RUN:    AUDIT_OUT=/tmp/c.txt LD_AUDIT=/tmp/audit.so SCRIP_RTCC=1 ./prog < /dev/null ; sort -rn /tmp/c.txt
   ⛔ MUST BE RUN ON A **MODE-4** BINARY, NEVER `scrip --run` (mode-3).  la_pltenter only sees PLT-routed calls.
   Mode-3 executes generated code from an RX slab that has no PLT and is not a link_map object, so GENERATED->C
   CROSSINGS ARE INVISIBLE THERE and what you measure is intra-C PLT traffic inside libscrip_rt.so -- the
   COMPLEMENT of what RC-6 wants.  Proven s11: in mode-3 rt_call_arr/rt_arg_stage read 0 while having 4/5
   emitted call sites, and rt_chain_enter/rt_gc_point read 2.69M while having ZERO emitted call sites.  An
   exact inverse correlation; reading that table as hotness would have aimed RC-6 at symbols generated code
   never calls.  Mode-4 links the emitted .s into a real ELF where `call rt_foo` goes through the PLT.
   MODE-4 RECIPE (arm-matched -- emit arm and run arm MUST agree or you get a SIGSEGV, not a wrong number):
     SCRIP_RTCC=1 ./scrip --compile f.sno < /dev/null > f.s
     gcc -c -o f.o f.s && gcc -o f f.o out/libscrip_rt.so -no-pie -Wl,-rpath,out
     AUDIT_OUT=/tmp/c.txt LD_AUDIT=/tmp/audit.so SCRIP_RTCC=1 ./f < /dev/null
   COUNTS ARE EXACT (not sampled); the ~15-40x slowdown is irrelevant to a census and MUST NOT be timed. */
