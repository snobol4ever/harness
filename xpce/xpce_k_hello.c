/* The kernel alone, hosted by forty lines of C: a picture with a box and a line of text, then the event loop.
   No Prolog is in this process. Linked against the kernel library alone (util_xpce_kernel_build.sh hello): argument text adds the line of text. The oracle's cut of the two pictures is xpce_k_hello.pl and xpce_k_box.pl under swipl on one thread. */
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <h/interface.h>
int xpce_host_initialise(int handles, const char *home, const char *appdata, int argc, char **argv);
static PceObject nm(const char *s) { return cToPceName_nA(s, strlen(s)); }
int main(int argc, char **argv)
{ const char *home = getenv("XPCE_HOME_DIR") ? getenv("XPCE_HOME_DIR") : "/home/resources/xpce-V9.0.4";
  if ( !xpce_host_initialise(0, home, getenv("XPCE_APPDATA_DIR"), argc, argv) ) { fprintf(stderr, "pceInitialise failed\n"); return 1; }
  PceObject NIL = cToPceAssoc("nil");
  PceObject pic = pceNew(NIL, nm("picture"), 0, NULL);
  PceObject wh[2] = { cToPceInteger(160), cToPceInteger(90) };
  PceObject box = pceNew(NIL, nm("box"), 2, wh);
  PceObject xy[2] = { cToPceInteger(30), cToPceInteger(30) };
  PceObject at = pceNew(NIL, nm("point"), 2, xy);
  PceObject a[2] = { box, at };
  if ( !pic || !box || !pceSend(pic, 0, nm("display"), 2, a) ) { fprintf(stderr, "display failed\n"); return 1; }
  if ( argc > 1 && strcmp(argv[1], "text") == 0 )
  { PceObject s[1] = { cToPceStringA(NIL, "Hello from the kernel", 21, 0) };
    PceObject t = pceNew(NIL, nm("text"), 1, s);
    PceObject xy2[2] = { cToPceInteger(30), cToPceInteger(140) };
    PceObject b[2] = { t, pceNew(NIL, nm("point"), 2, xy2) };
    if ( !t || !pceSend(pic, 0, nm("display"), 2, b) ) { fprintf(stderr, "text failed\n"); return 1; }
  }
  if ( !pceSend(pic, 0, nm("open"), 0, NULL) ) { fprintf(stderr, "open failed\n"); return 1; }
  printf("opened\n"); fflush(stdout);
  for(;;) pceDispatch(-1, 250);   /* -1: no descriptor. MEASURED: watching descriptor 0 at end of file starves the X events and the window is never painted */
}
