/* The stream file's seams (HOSTING 3.9, road S3): the nine names pl-stream.c of swipl 9.0.4 asks of the rest of SWI-Prolog, answered for a kernel
   that runs on one thread with no Prolog engine in its library. pl-stream.c and pl-utf8.c themselves are compiled as they stand. */
#include <stdlib.h>
#include "SWI-Stream.h"
#include "SWI-Prolog.h"
typedef struct PL_locale PL_locale;
int PL_handle_signals(void) { return 0; }                 /* no Prolog signal is pending on the kernel's side */
term_t PL_exception(qid_t qid) { (void)qid; return 0; }   /* no Prolog exception stands on the kernel's side */
record_t PL_record(term_t t) { (void)t; return 0; }
void PL_erase(record_t r) { (void)r; }
extern void *pceMalloc(size_t n);   /* the kernel's own layer (itf/interface.c): these two seams are the kernel's class by construction, no direct site */
extern void pceFree(void *p);
void *PL_malloc_uncollectable(size_t n) { return pceMalloc(n); }
void PL_free(void *p) { if ( p ) pceFree(p); }
PL_locale *acquireLocale(PL_locale *l) { return l; }
void releaseLocale(PL_locale *l) { (void)l; }
void initStreamLocale(IOSTREAM *s) { s->locale = NULL; }
void initEncoding(void) { }
int reportStreamError(IOSTREAM *s) { (void)s; return 1; }   /* called when a close finds an error with no Prolog to tell: the stream's own error flag stands for the kernel side to read (HOSTING 3.7) */
