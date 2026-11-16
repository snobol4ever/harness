/* The three kernel entries a host needs that the kernel's own headers hide (ker/proto.h declares them COMMON, so the oracle's plugin, which
   holds its binding inside itself, never exports them): each is exported here under a name of the library's own. */
#include <h/kernel.h>
#include <h/interface.h>
__attribute__((visibility("default"))) int xpce_host_initialise(int handles, const char *home, const char *appdata, int argc, char **argv)
{ return pceInitialise(handles, home, appdata, argc, argv); }
__attribute__((visibility("default"))) void *xpce_host_postscript_stream(void) { return pcePostScriptStream(); }
__attribute__((visibility("default"))) void xpce_host_rewind_answer_stack(AnswerMark *mark, PceObject obj) { _rewindAnswerStack(mark, obj); }
/* THE KERNEL CLASS OF ALLOC-CLASSES.tsv (step 2 of the plan): the build renames malloc, calloc, realloc, strdup and free onto these five in every object whose
   direct sites are all the kernel's own. Each goes through the kernel's three slots, which a host fills (SCRIP's binding points them at the graphics arena) and
   which are libc's while no host does. They are the library's own and are not exported. */
#include <string.h>
#define XPCE_K __attribute__((visibility("hidden")))
XPCE_K void *xpce_k_malloc(size_t n) { return pceMalloc(n); }
XPCE_K void *xpce_k_realloc(void *p, size_t n) { return pceRealloc(p, n); }
XPCE_K void xpce_k_free(void *p) { if ( p ) pceFree(p); }
XPCE_K void *xpce_k_calloc(size_t n, size_t m)
{ size_t z = n * m; void *p;
  if ( m && z / m != n ) return NULL;
  if ( (p = pceMalloc(z ? z : 1)) ) memset(p, 0, z);
  return p;
}
XPCE_K char *xpce_k_strdup(const char *s)
{ size_t n = strlen(s) + 1; char *p = pceMalloc(n);
  if ( p ) memcpy(p, s, n);
  return p;
}
