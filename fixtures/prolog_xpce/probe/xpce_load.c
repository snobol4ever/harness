#include <stdio.h>
void *rt_xpce_sym(const char *name);
int main(void) {
    void *p = rt_xpce_sym("scrip_xpce_load");
    printf("rt_xpce_sym(scrip_xpce_load) %s\n", p ? "found" : "not found");
    return p ? 0 : 1;
}
