#include <string.h>
#include "icall.h"
extern int interp(int fsig, descriptor *cargp);
int w5upto(int argc, descriptor argv[]) {
   ArgInteger(1);
   for (long i = 1; i <= IntegerVal(argv[1]); i++) {
      argv[0].dword = D_Integer; argv[0].vword = i;
      int sig = interp(1, argv);
      if (sig != 1) return sig;
   }
   return -1;
}
int w5words(int argc, descriptor argv[]) {
   char b[64];
   ArgInteger(1);
   for (long i = 1; i <= IntegerVal(argv[1]); i++) {
      int n = snprintf(b, sizeof b, "word-%ld-%s", i, i % 2 ? "odd" : "even");
      argv[0].dword = n; argv[0].vword = (word)alcstr(b, n);
      int sig = interp(1, argv);
      if (sig != 1) return sig;
   }
   RetConstString("last");
}
int w5sum(int argc, descriptor argv[]) {
   long s = 0;
   for (int i = 1; i <= argc; i++) { ArgInteger(i); s += IntegerVal(argv[i]); }
   RetInteger(s * 1000 + argc);
}
int w5echo(int argc, descriptor argv[]) {
   for (int i = 1; i <= argc; i++) {
      argv[0] = argv[i];
      int sig = interp(1, argv);
      if (sig != 1) return sig;
   }
   return -1;
}
