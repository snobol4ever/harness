#include <string>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include "emit.h"
extern "C" {
#include "bb_template_common.h"
#include "descr.h"
}
#include "x86_asm.h"
#include <cstdlib>
static void dump_hex(const char * label, const std::string & s) {
    printf("%s ", label);
    for (size_t i = 2; i < s.size(); i++) printf("%02x", (unsigned char)s[i]);
    printf("  (%zu raw bytes)\n", s.size() >= 2 ? s.size() - 2 : 0);
}
int main(int argc, char ** argv) {
    if (argc < 2) { fprintf(stderr, "usage: probe <good|bad_cmp|bad_and|bad_or>\n"); return 2; }
    std::string mode = argv[1];
    if (mode == "good") {
        g_medium = BB_MEDIUM_BINARY;
        dump_hex("cmp_bin", x86("cmp", "rdi", RDQ("r13", 32)));
        dump_hex("and_bin", x86("and", "rdi", RDQ("r13", 32)));
        dump_hex("or_bin ", x86("or",  "rdi", RDQ("r13", 32)));
        g_medium = BB_MEDIUM_TEXT;
        std::string ct = x86("cmp", "rdi", RDQ("r13", 32)); while (!ct.empty() && ct.back() == '\n') ct.pop_back();
        std::string at = x86("and", "rdi", RDQ("r13", 32)); while (!at.empty() && at.back() == '\n') at.pop_back();
        std::string ot = x86("or",  "rdi", RDQ("r13", 32)); while (!ot.empty() && ot.back() == '\n') ot.pop_back();
        printf("cmp_txt [%s]\n", ct.c_str());
        printf("and_txt [%s]\n", at.c_str());
        printf("or_txt  [%s]\n", ot.c_str());
        return 0;
    }
    std::string fr64 = std::string(x86_fr64_prefix()) + "16]";
    g_medium = BB_MEDIUM_BINARY;
    if (mode == "bad_cmp") { std::string r = x86("cmp", "rdi", fr64); printf("UNEXPECTED NON-ABORT, got %zu bytes\n", r.size()); return 0; }
    if (mode == "bad_and") { std::string r = x86("and", "rdi", fr64); printf("UNEXPECTED NON-ABORT, got %zu bytes\n", r.size()); return 0; }
    if (mode == "bad_or")  { std::string r = x86("or",  "rdi", fr64); printf("UNEXPECTED NON-ABORT, got %zu bytes\n", r.size()); return 0; }
    fprintf(stderr, "unknown mode\n");
    return 2;
}
