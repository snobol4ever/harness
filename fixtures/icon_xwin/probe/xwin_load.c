#include <stdio.h>
extern void *rt_xwin_sym(const char *name);
int main(void) {
   void *p = rt_xwin_sym("bt_DrawLine");
   printf("rt_xwin_sym bt_DrawLine %s\n", p ? "found" : "missing");
   return p ? 0 : 1;
}
