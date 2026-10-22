#!/usr/bin/env python3
"""util_g_runtime_abi_offsets.py [--check]

g_runtime.abi is the block of the runtime's globals that asm leaves, the emitter's templates and the inline asm of the runtime address by
byte offset from g_runtime (CEO-1561, the struct row; ceo ruling struct-plan-approved-bar-is-13: the offset-and-static-assert design).
The block is the first member of g_runtime_t, so an offset is stable while the block's own members keep their order. This script reads
the block's members from src/runtime/core/g_runtime_abi.h, asks the C compiler for each member's offsetof, and writes
src/runtime/core/g_runtime_abi.inc: one `#define G_RT_OFF_<MEMBER> <n>` per member, usable from C, C++ and the cpp-processed asm. With
--check it only compares and exits 1 when the checked-in file differs (the static asserts of g_runtime.c say the same at build time).
Run it from SCRIP after adding or reordering a member of g_abi_t.
"""
import os, re, subprocess, sys, tempfile
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "SCRIP"))
H = os.path.join(ROOT, "src/runtime/core/g_runtime_abi.h")
INC = os.path.join(ROOT, "src/runtime/core/g_runtime_abi.inc")
CHK = os.path.join(ROOT, "src/runtime/core/g_runtime_abi_check.inc")
def members():
    s = open(H, encoding="utf-8").read()
    body = s[s.index("typedef struct {"):s.index("} g_abi_t;")]
    return re.findall(r"\b(\w+)(?:\[[^\]]*\])?;", body)
def main():
    ms = members()
    probe = '#include <stdio.h>\n#include <stddef.h>\n#include "g_runtime.h"\nint main(void) {\n' + "".join('    printf("%s %%zu\\n", offsetof(g_runtime_t, abi.%s));\n' % (m, m) for m in ms) + "    return 0;\n}\n"
    with tempfile.TemporaryDirectory() as d:
        c = os.path.join(d, "p.c"); x = os.path.join(d, "p")
        open(c, "w").write(probe)
        inc = ["-I" + os.path.join(ROOT, "src", p) for p in ("runtime/core", "ir", "runtime", "runtime/rt")]
        r = subprocess.run(["gcc", "-w", "-o", x, c] + inc, capture_output=True, text=True)
        if r.returncode:
            print(r.stderr); sys.exit(2)
        out = subprocess.run([x], capture_output=True, text=True).stdout.split("\n")
    text = "".join("#define G_RT_OFF_%s %s\n" % (l.split()[0].upper(), l.split()[1]) for l in out if l.strip())
    chk = "".join('_Static_assert(offsetof(g_runtime_t, abi.%s) == G_RT_OFF_%s, "g_runtime.abi.%s moved: asm leaves, templates and the poll leaf address it by G_RT_OFF_%s; run harness/scripts/util_g_runtime_abi_offsets.py");\n' % (m, m.upper(), m, m.upper()) for m in ms)
    if "--check" in sys.argv:
        cur = open(INC).read() if os.path.exists(INC) else ""
        cur2 = open(CHK).read() if os.path.exists(CHK) else ""
        ok = cur == text and cur2 == chk
        print("FRESH: %d offsets" % len(ms) if ok else "STALE: run util_g_runtime_abi_offsets.py"); sys.exit(0 if ok else 1)
    open(INC, "w").write(text); open(CHK, "w").write(chk); print("wrote %s and %s (%d offsets)" % (INC, CHK, len(ms)))
main()
