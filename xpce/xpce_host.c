/* The three kernel entries a host needs that the kernel's own headers hide (ker/proto.h declares them COMMON, so the oracle's plugin, which
   holds its binding inside itself, never exports them): each is exported here under a name of the library's own. */
#include <h/kernel.h>
#include <h/interface.h>
__attribute__((visibility("default"))) int xpce_host_initialise(int handles, const char *home, const char *appdata, int argc, char **argv)
{ return pceInitialise(handles, home, appdata, argc, argv); }
__attribute__((visibility("default"))) void *xpce_host_postscript_stream(void) { return pcePostScriptStream(); }
__attribute__((visibility("default"))) void xpce_host_rewind_answer_stack(AnswerMark *mark, PceObject obj) { _rewindAnswerStack(mark, obj); }
