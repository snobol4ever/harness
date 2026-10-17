#include <stdio.h>
extern unsigned char rtx_gate_misc;
extern unsigned char rtx_gate_alloc;
extern unsigned char rtx_gate_str;
extern unsigned char rtx_gate_leaf;
extern unsigned char rtx_gate_arith;
extern unsigned char rtx_gate_icnvar;
extern unsigned char rtx_gate_icnnum;
extern unsigned char rtx_gate_icnrel;
extern unsigned char rtx_gate_icnagg;
extern unsigned char rtx_gate_match;
extern unsigned char rtx_gate_icngen;
extern unsigned char rtx_gate_icncall;
extern unsigned char rtx_gate_icnsub;
extern unsigned char rtx_gate_plunify;
int main(void) {
    struct { const char *name; unsigned char *byte; } g[] = {
        {"misc", &rtx_gate_misc}, {"alloc", &rtx_gate_alloc}, {"str", &rtx_gate_str}, {"leaf", &rtx_gate_leaf},
        {"arith", &rtx_gate_arith}, {"icnvar", &rtx_gate_icnvar}, {"icnnum", &rtx_gate_icnnum}, {"icnrel", &rtx_gate_icnrel},
        {"icnagg", &rtx_gate_icnagg}, {"match", &rtx_gate_match}, {"icngen", &rtx_gate_icngen}, {"icncall", &rtx_gate_icncall},
        {"icnsub", &rtx_gate_icnsub}, {"plunify", &rtx_gate_plunify},
    };
    int n = (int)(sizeof(g) / sizeof(g[0]));
    int disarmed = 0;
    for (int i = 0; i < n; i++) {
        int v = (int)*g[i].byte;
        if (!v) disarmed++;
        printf("%-8s %d %s\n", g[i].name, v, v ? "ARMED" : "DISARMED");
    }
    printf("TOTAL %d/%d armed\n", n - disarmed, n);
    return disarmed ? 1 : 0;
}
