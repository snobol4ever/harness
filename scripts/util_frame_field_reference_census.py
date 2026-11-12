#!/usr/bin/env python3
import re, subprocess, sys, os
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP")
def run(args):
    p = subprocess.run(args, capture_output=True, text=True, errors="replace", cwd=ROOT, timeout=120)
    return p.stdout
def mangle(nm):
    out = []
    for ch in nm:
        if (ch.isalnum() and ord(ch) < 128) or ch in "_$.":
            out.append(ch)
        else:
            out.extend("$%02X" % b for b in ch.encode("utf-8"))
    if sum(len(u) for u in out) <= 48:
        return "".join(out)
    h, keep = 1469598103934665603, ""
    for b in nm.encode("utf-8"):
        h = ((h ^ b) * 1099511628211) & 0xFFFFFFFFFFFFFFFF
    for u in out:
        if len(keep) + len(u) > 31:
            break
        keep += u
    return "%s$%016x" % (keep, h)
GH = re.compile(r"^;\s*graph\s+(\d+)\s+'([^']*)'\s+—\s+slots=(\d+)\s+region_end=(\d+)")
FLD = re.compile(r"^;\s+\+(\d+)\s+(\d+)\s+(\S+)\s+(.*?)\s+(\S+)\s*$")
REF = re.compile(r"\[(rbp|rsp)\s*\+\s*(\d+)\]")
def main():
    if len(sys.argv) < 2: print("usage: util_frame_field_reference_census.py <program> [--all]"); return 2
    prog = sys.argv[1]; show_all = "--all" in sys.argv
    zeta = run(["./scrip", "--dump-zeta", prog]); asm = run(["./scrip", "--compile", prog])
    graphs = []; cur = None
    for line in zeta.splitlines():
        m = GH.match(line)
        if m: cur = {"name": m.group(2), "end": int(m.group(4)), "fields": []}; graphs.append(cur); continue
        m = FLD.match(line)
        if m and cur is not None: cur["fields"].append({"off": int(m.group(1)), "size": int(m.group(2)), "kind": m.group(3), "what": m.group(4).strip(), "op": m.group(5)})
    if not graphs: print("REFUSE(2): --dump-zeta printed no graph"); return 2
    lines = asm.splitlines(); labels = []
    for i, l in enumerate(lines):
        m = re.match(r"^(FN__[A-Za-z0-9_$.]+|main):", l)
        if m: labels.append((i, m.group(1)))
    bodies = {}
    for k, (i, lbl) in enumerate(labels):
        j = labels[k + 1][0] if k + 1 < len(labels) else len(lines)
        bodies.setdefault(lbl, lines[i:j])
    total_fields = 0; dead_total = 0; censused = 0
    for g in graphs:
        body = bodies.get("main" if g["name"] == "main" else "FN__" + mangle(g["name"]))
        if body is None or not g["fields"]:
            print("; census '%s' NOT CENSUSED: %s" % (g["name"], "no FN__ body in the emission" if body is None else "no fields")); continue
        rsp_refs = sum(1 for l in body for m in REF.finditer(l) if m.group(1) == "rsp")
        rbp_refs = sum(1 for l in body for m in REF.finditer(l) if m.group(1) == "rbp")
        if rbp_refs == 0 and rsp_refs > 0:
            print("; census '%s' NOT CENSUSED: the frame is not rbp-addressed in this body (rbp refs=0, rsp refs=%d) -- an rsp-placed frame is outside what this instrument can see" % (g["name"], rsp_refs)); continue
        refs = {}; leas = {}
        for l in body:
            is_lea = l.strip().startswith("lea")
            for m in REF.finditer(l):
                if m.group(1) != "rbp": continue
                n = int(m.group(2))
                for f in g["fields"]:
                    if f["off"] <= n < f["off"] + f["size"]:
                        key = f["off"]
                        if is_lea: leas[key] = leas.get(key, 0) + 1
                        else: refs[key] = refs.get(key, 0) + 1
        covered = set()
        fs = sorted(g["fields"], key=lambda f: f["off"])
        for idx, f in enumerate(fs):
            if leas.get(f["off"], 0):
                covered.add(f["off"]); j = idx + 1
                while j < len(fs) and fs[j]["what"].startswith("call.argv"): covered.add(fs[j]["off"]); j += 1
        dead = []
        censused += 1
        for f in fs:
            total_fields += 1
            r = refs.get(f["off"], 0); l = leas.get(f["off"], 0); via = f["off"] in covered and not l
            status = "NOREF" if (r == 0 and l == 0 and not via) else "live"
            if status == "NOREF": dead.append(f); dead_total += 1
            if show_all or status == "NOREF":
                print(";   census '%s' +%-5d %-3d %-8s refs=%-3d lea=%-2d %s %-36s %s" % (g["name"], f["off"], f["size"], f["kind"], r, l, "via-pointer" if via else ("NOREF      " if status == "NOREF" else "direct     "), f["what"][:36], f["op"]))
        print("; census '%s' fields=%d noref=%d noref_bytes=%d rsp_refs=%d region_end=%d" % (g["name"], len(fs), len(dead), sum(f["size"] for f in dead), rsp_refs, g["end"]))
    print("; census TOTAL graphs=%d censused=%d fields=%d noref=%d" % (len(graphs), censused, total_fields, dead_total))
    print("; census MEASURES literal [rbp+N] references and lea-covered call.argv blocks in the graph's own FN__ body; a field reached through any other base register or from another body is NOT seen -- NOREF is a lead, never a verdict")
    return 0
if __name__ == "__main__": sys.exit(main())
