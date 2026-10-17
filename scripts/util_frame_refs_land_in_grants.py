#!/usr/bin/env python3
import re, sys, os
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import util_frame_field_reference_census as C
SUB = re.compile(r"^\s*sub\s+rsp,\s*(\d+)")
def parse_graphs(zeta):
    graphs = []; cur = None
    for line in zeta.splitlines():
        m = C.GH.match(line)
        if m: cur = {"name": m.group(2), "end": int(m.group(4)), "fields": []}; graphs.append(cur); continue
        m = C.FLD.match(line)
        if m and cur is not None: cur["fields"].append({"off": int(m.group(1)), "size": int(m.group(2)), "what": m.group(4).strip()})
    return graphs
def bodies_of(asm):
    lines = asm.splitlines(); labels = []
    for i, l in enumerate(lines):
        m = re.match(r"^(FN__[A-Za-z0-9_$.]+|main):", l)
        if m: labels.append((i, m.group(1)))
    b = {}
    for k, (i, lbl) in enumerate(labels):
        j = labels[k + 1][0] if k + 1 < len(labels) else len(lines); b.setdefault(lbl, lines[i:j])
    return b
def main():
    a = sys.argv[1:]
    if not a: print("usage: util_frame_refs_land_in_grants.py <program> | --zeta F --asm F  [--only name,name]"); return 2
    only = set(a[a.index("--only") + 1].split(",")) if "--only" in a else None
    if "--zeta" in a: zeta = open(a[a.index("--zeta") + 1]).read(); asm = open(a[a.index("--asm") + 1]).read()
    else: zeta = C.run(["./scrip", "--dump-zeta", a[0]]); asm = C.run(["./scrip", "--compile", a[0]])
    graphs = parse_graphs(zeta); bodies = bodies_of(asm)
    if not graphs: print("REFUSE(2): --dump-zeta printed no graph"); return 2
    graded = 0; findings = 0; refs_total = 0
    for g in graphs:
        if only and g["name"] not in only: continue
        if g["name"] == "main": print("; grants 'main' NOT GRADED: the root graph's carve is not the flat activation frame this instrument reads (no 64-byte entry header at the top)"); continue
        body = bodies.get("FN__" + C.mangle(g["name"]))
        if body is None or not g["fields"]:
            print("; grants '%s' NOT GRADED: %s" % (g["name"], "no FN__ body in the emission" if body is None else "no fields")); continue
        carve = None
        for l in body:
            m = SUB.match(l)
            if m: carve = int(m.group(1)); break
        rbp = [int(m.group(2)) for l in body for m in C.REF.finditer(l) if m.group(1) == "rbp"]
        rsp = sum(1 for l in body for m in C.REF.finditer(l) if m.group(1) == "rsp")
        if not rbp and rsp: print("; grants '%s' NOT GRADED: the frame is not rbp-addressed in this body (rsp refs=%d)" % (g["name"], rsp)); continue
        if carve is None: print("; grants '%s' NOT GRADED: no 'sub rsp, K' carve in the body" % g["name"]); continue
        graded += 1; bad = set(); ingrant = 0; header = 0
        for n in rbp:
            refs_total += 1
            if n < g["end"]:
                if any(f["off"] <= n < f["off"] + f["size"] for f in g["fields"]): ingrant += 1
                else: bad.add("[rbp+%d] lies below region_end=%d and inside no granted field" % (n, g["end"]))
            elif n >= carve - 64: header += 1
            else: bad.add("[rbp+%d] lies above region_end=%d and below the entry header at %d: a quad the emitter addresses and the dump does not grant" % (n, g["end"], carve - 64))
        for b in sorted(bad): print(";   grants '%s' ⛔ %s" % (g["name"], b))
        findings += len(bad)
        print("; grants '%s' refs=%d in_grant=%d header=%d ungranted=%d region_end=%d carve=%d" % (g["name"], len(rbp), ingrant, header, len(bad), g["end"], carve))
    print("; grants TOTAL graphs=%d graded=%d refs=%d findings=%d" % (len(graphs), graded, refs_total, findings))
    print("; grants MEASURES every literal [rbp+N] in the graph's own FN__ body against the --dump-zeta grant table of the same binary; a frame addressed through another base register is not graded; a reference that lands in no grant is a finding, never a lead")
    if graded == 0: return 2
    return 1 if findings else 0
if __name__ == "__main__": sys.exit(main())
