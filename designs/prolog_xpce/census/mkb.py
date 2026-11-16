import sys, re, os
src_root, dst_root = sys.argv[1], sys.argv[2]
PCE = ":- op(200, fy, @).\n:- op(250, yfx, ?).\n:- op(800, xfx, :=).\n"
PUSH = ":- op(1200, xfx, :->).\n:- op(1200, xfx, :<-).\n:- op(910, xfy, ::).\n:- op(100, xf, *).\n:- op(125, xf, ?).\n:- op(150, xf, ...).\n:- op(100, xfx, ..).\n"
POP = ":- op(0, xfx, :->).\n:- op(0, xfx, :<-).\n:- op(0, xfy, ::).\n:- op(0, xf, *).\n:- op(0, xf, ?).\n:- op(0, xf, ...).\n:- op(0, xfx, ..).\n"
for rel in open("files.txt").read().split():
    lines = open(os.path.join(src_root, rel), encoding="utf-8", errors="replace").read().split("\n")
    one = lambda t: " ".join(t.strip().split("\n")) + " "
    out, pending_pop = [], False
    txt = "\n".join(lines); mm = re.search(r"^:-\s*module\(", txt, re.M)
    at_line, mod_open = (0, False)
    if mm:
        at_line = txt[:mm.start()].count("\n"); mod_open = True
    for i, ln in enumerate(lines):
        pre = one(PCE) if (i == 0 and not mm) else ""
        if re.match(r":-\s*(pce_begin_class|pce_extend_class|emacs_begin_mode|emacs_extend_mode|draw_begin_shape)", ln): pre += one(PUSH)
        post = ""
        if re.match(r":-\s*(pce_end_class|emacs_end_mode|draw_end_shape)", ln): pending_pop = True
        if mod_open and i >= at_line and re.search(r"\)\s*\.\s*(%.*)?$", ln):
            post += " " + one(PCE); mod_open = False
        if pending_pop and ln.rstrip().endswith("."):
            post += " " + one(POP); pending_pop = False
        out.append(pre + ln + post)
    # the preamble adds 3 lines and each push/pop 7: record a line map so a B error maps back to the source line
    d = os.path.join(dst_root, os.path.dirname(rel)); os.makedirs(d, exist_ok=True)
    open(os.path.join(dst_root, rel), "w").write("\n".join(out))
