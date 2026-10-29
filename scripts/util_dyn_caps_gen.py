#!/usr/bin/env python3
"""util_dyn_caps_gen.py <dir> -- writes the six cap-exceeding witnesses of ARCH-DYNAMIC-STORAGE.md into <dir>:
defines200.sno (200 DEFINEs; SNO_DEF_MAX is 128), preds600.pl (600 predicates; MAX_PREDS is 512), args70.icn (a 70-argument
call; CALL_ARGS_MAX is 64), multi300.raku (300 multi candidates that all accept one call; by_name_dispatch.c held 256 accepted
candidates and silently answered k256 for K300), cmpdeep.pl (compare/3 on terms nested 200000 deep; unification.c held a 1024-frame
walk stack and fell back to the recursive walk), blobs150.sno (a pattern built at run time with 150 unfenced alternations, matched through a deferred
reference, so its blob frame's layout needs 4 * 150 + 8 = 608 entries; emit.cpp's g_blob_lay held 512 and silently dropped the
rest, and the tiling check then aborted -- hq_snocone's transpiled parser_rebus.sno wall, cfo 2026-09-24). Each is a legal program
of its industry-standard language whose answer the oracle prints. The SNOBOL4 ones keep every line under SPITBOL's 1024 columns."""
import os
import sys


def main(argv):
    d = argv[1]
    os.makedirs(d, exist_ok=True)
    n = 200
    L = ['        DEFINE("f%d()")' % i for i in range(1, n + 1)]
    L.append("                                                 :(go)")
    L += ["f%d      f%d = %d                                :(RETURN)" % (i, i, i) for i in range(1, n + 1)]
    L.append("go      total = 0")
    L += ["        total = total + f%d()" % i for i in range(1, n + 1)]
    L += ["        OUTPUT = total", "END"]
    open(os.path.join(d, "defines200.sno"), "w", newline="\n").write("\n".join(L) + "\n")
    n = 600
    L = [":- initialization(main)."] + ["p%d(%d)." % (i, i) for i in range(1, n + 1)]
    L.append("main :- " + ", ".join("p%d(X%d), write(X%d), nl" % (i, i, i) for i in range(1, n + 1)) + ", halt.")
    open(os.path.join(d, "preds600.pl"), "w", newline="\n").write("\n".join(L) + "\n")
    n = 70
    args = ", ".join("a%d" % i for i in range(1, n + 1))
    body = "s := 0; " + " ".join("s +:= a%d;" % i for i in range(1, n + 1)) + " return s;"
    src = "procedure f(%s)\n  %s\nend\nprocedure main()\n  write(f(%s));\nend\n" % (args, body, ", ".join(str(i) for i in range(1, n + 1)))
    open(os.path.join(d, "args70.icn"), "w", newline="\n").write(src)
    n = 150
    alts = ["(('w%d' R(%d)) *Q | 'v%d')" % (i, i, i) for i in range(n)]
    body = "(P = " + " ".join("(" + " ".join(alts[k:k + 50]) + ")" for k in range(0, n, 50)) + ")"
    L, cur = ["        DEFINE('R(N)')                          :(R_END)", "R       R = LEN(0)                              :(RETURN)", "R_END", "        Q = 'q'"], "       "
    for tok in body.split(" "):
        if len(cur) + len(tok) + 1 > 70:
            L.append(cur)
            cur = "+ " + tok
        else:
            cur = cur + " " + tok
    L.append(cur)
    L += ["        S = '" + "".join("v%d" % i for i in range(n)) + "'", "        S POS(0) *P . M RPOS(0)                 :S(Y)F(NO)",
          "Y       OUTPUT = SIZE(M)                        :(END)", "NO      OUTPUT = 'no'", "END"]
    open(os.path.join(d, "blobs150.sno"), "w", newline="\n").write("\n".join(L) + "\n")
    n = 300
    L = ["class K1 { }"] + ["class K%d is K%d { }" % (i, i - 1) for i in range(2, n + 1)] + ["multi sub f(K%d $x) { 'k%d' }" % (i, i) for i in range(1, n + 1)]
    L += ["say f(K300.new);", "say f(K1.new);", "say f(K150.new);", "say f(K256.new);", "say f(K257.new);"]
    open(os.path.join(d, "multi300.raku"), "w", newline="\n").write("\n".join(L) + "\n")
    L = ["nest(0, Leaf, Leaf) :- !.", "nest(N, Leaf, f(T, b)) :- N1 is N - 1, nest(N1, Leaf, T).",
         "t(N) :- nest(N, a, T1), nest(N, c, T2), compare(O, T1, T2), write(N-O), nl, compare(O2, T2, T1), write(O2), nl, compare(O3, T1, T1), write(O3), nl.",
         ":- t(10), t(2000), t(20000), t(200000)."]
    open(os.path.join(d, "cmpdeep.pl"), "w", newline="\n").write("\n".join(L) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
