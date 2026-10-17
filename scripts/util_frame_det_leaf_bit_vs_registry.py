#!/usr/bin/env python3
import re, sys, os
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import util_frame_field_reference_census as C
DL = re.compile(r"^;\s+reuse\s+\+\d+\s+IR_CALL\s+.*det leaf (\S+): no beta, argv dead at gamma")
BOX = re.compile(r"^(n\d+_call(?:_direct|_pl_leaf|_pas_bi|_callee_rec|_field_rec|_byname|_try|_method|_redisp|_apply|_eval|_gen)?_bx):")
CALL = re.compile(r"^\s*call\s+([A-Za-z0-9_$.@]+)")
def main():
    a = sys.argv[1:]
    if not a: print("usage: util_frame_det_leaf_bit_vs_registry.py <program>"); return 2
    zeta = C.run(["./scrip", "--dump-zeta", a[0]]); asm = C.run(["./scrip", "--compile", a[0]])
    graphs = []; cur = None
    for line in zeta.splitlines():
        m = C.GH.match(line)
        if m: cur = {"name": m.group(2), "leaves": []}; graphs.append(cur); continue
        m = DL.match(line)
        if m and cur is not None: cur["leaves"].append(m.group(1))
    if not graphs: print("REFUSE(2): --dump-zeta printed no graph"); return 2
    lines = asm.splitlines(); labels = []
    for i, l in enumerate(lines):
        m = re.match(r"^(FN__[A-Za-z0-9_$.]+|main):", l)
        if m: labels.append((i, m.group(1)))
    bodies = {}
    for k, (i, lbl) in enumerate(labels):
        j = labels[k + 1][0] if k + 1 < len(labels) else len(lines); bodies.setdefault(lbl, lines[i:j])
    graded = 0; bad = 0; tot_bits = 0; tot_direct = 0
    for g in graphs:
        body = bodies.get("main" if g["name"] == "main" else "FN__" + C.mangle(g["name"]))
        if body is None: print("; detleaf '%s' NOT GRADED: no FN__ body in the emission" % g["name"]); continue
        direct = 0; byname = 0; cur_box = None; seen = set()
        for l in body:
            m = BOX.match(l)
            if m: cur_box = m.group(1); continue
            if re.match(r"^n\d+_[a-z_0-9]+_bx:", l): cur_box = None; continue
            m = CALL.match(l)
            if m and cur_box and cur_box not in seen:
                seen.add(cur_box)
                if m.group(1).startswith("rt_call_arr_bl"): byname += 1
                else: direct += 1
        graded += 1; nb = len(g["leaves"]); tot_bits += nb; tot_direct += direct
        ok = (nb == direct)
        if not ok: bad += 1
        print("; detleaf '%s' sealed=%d emitted_direct=%d emitted_byname=%d %s%s" % (g["name"], nb, direct, byname, "agree" if ok else "⛔ DISAGREE", "" if ok else " sealed=" + ",".join(g["leaves"])))
    print("; detleaf TOTAL graphs=%d graded=%d sealed=%d emitted_direct=%d disagree=%d" % (len(graphs), graded, tot_bits, tot_direct, bad))
    print("; detleaf MEASURES per graph: the calls --dump-zeta prints with the det-leaf claim 'det leaf <name>: no beta, argv dead at gamma' (the lowerer's seal, read by the reuse relation; since rung 2 the result goes through the ordinary reader rule, so the line may read CANDIDATE, ELIDED or PINNED) against the IR_CALL boxes (n<k>_call_bx) whose first call instruction targets a registry symbol rather than rt_call_arr_bl (the by-name dispatch); the two must agree in both directions, and a graph whose body is not found is NOT GRADED by name")
    if graded == 0: return 2
    return 1 if bad else 0
if __name__ == "__main__": sys.exit(main())
