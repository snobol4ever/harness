#!/usr/bin/env python3
"""util_prelude_roads.py SUITE-KEY [--out DIR] [--limit N] | --probe -- A PROLOG SUITE RUN ON BOTH ROADS OF THE PRELUDE, ENTRY FOR ENTRY (the cio
2026-11-11, CIO-129, design prelude-object step 5; Lon 2026-11-09, COO-500: "Make Prolog run much faster by using a shared object for all the
prelude code."). The prelude shared object becomes the default only when no program can tell it from the prelude compiled from source. So every
entry of a suite on the package switch is run twice through scrip --run-files, once with SCRIP_PL_PRELUDE_SO=0 (the source road) and once with
the object of the root's own runtime (util_prelude_object.sh, the path form), and the two results are compared: how the entry ended, its standard
output and its standard error, byte for byte. An entry that FAILS on both roads is compared too (the coo's rule of 2026-11-11: two reds with
different output are a difference). The answer files are not read: this measures the two roads against each other, never against the oracle.
Writes DIR/SUITE.roads.tsv (entry, what differs, source road's end, object road's end, the first differing line of each) and prints
PRELUDE_ROADS suite=K entries=N differ=D end=E stdout=O stderr=S (tree HASH). rc 0 no entry differs; 1 some differ; 2 REFUSE (no such suite, not
Prolog, not on the package switch, no binary, a run refused, no entry ran). --probe proves the comparison on two scratch result folders made by
hand (one entry equal, one differing in its output, one in how it ended) and never runs scrip. Writes only under DIR and /tmp/s4e/<seat>."""
import csv, os, subprocess, sys, tempfile
ROOT = os.environ.get("S4E_HOME") or "/home/claude_cio"
HERE = os.path.dirname(os.path.abspath(__file__))


def refuse(m):
    print(f"REFUSE(2) [util_prelude_roads]: {m}"); sys.exit(2)


def read_road(rep_text, folder):
    """-> {entry: (how it ended, stdout bytes, stderr bytes)} from one scrip --run-files report and its --out folder."""
    got = {}
    for l in rep_text.split("\n"):
        c = l.split("\t")
        if len(c) != 6: continue
        nm = c[0].replace("/", "_")
        def rd(p):
            try: return open(p, "rb").read()
            except OSError: return b""
        got[c[0]] = (f"{c[1]} {c[2]}".strip(), rd(os.path.join(folder, nm + ".out")), rd(os.path.join(folder, nm + ".err")))
    return got


def first_diff(a, b):
    x, y = a.decode("utf-8", "replace").split("\n"), b.decode("utf-8", "replace").split("\n")
    k = next((i for i, (p, q) in enumerate(zip(x, y)) if p != q), min(len(x), len(y)))
    return (x[k] if k < len(x) else "(ends)")[:100], (y[k] if k < len(y) else "(ends)")[:100]


def compare(src, obj):
    """-> rows (entry, what, source end, object end, source line, object line) for every entry that differs; an entry one road lacks differs."""
    rows = []
    for n in sorted(set(src) | set(obj)):
        s, o = src.get(n), obj.get(n)
        if s is None or o is None:
            rows.append((n, "ran on one road only", s[0] if s else "-", o[0] if o else "-", "", "")); continue
        what = [w for w, i in (("end", 0), ("stdout", 1), ("stderr", 2)) if s[i] != o[i]]
        if not what: continue
        a, b = first_diff(s[1], o[1]) if "stdout" in what else first_diff(s[2], o[2]) if "stderr" in what else ("", "")
        rows.append((n, "+".join(what), s[0], o[0], a, b))
    return rows


def probe():
    t = tempfile.mkdtemp(prefix="prelude_roads_probe_", dir=f"/tmp/s4e/{os.environ.get('S4E_SEAT') or 'probe'}")
    for road, outs in (("s", {"a": b"1\n", "b": b"x\ny\n", "c": b"z\n"}), ("o", {"a": b"1\n", "b": b"x\nQ\n", "c": b"z\n"})):
        os.makedirs(os.path.join(t, road))
        for n, v in outs.items():
            open(os.path.join(t, road, n + ".out"), "wb").write(v); open(os.path.join(t, road, n + ".err"), "wb").write(b"")
    rep_s = "a\tEXIT\t0\t0\t0\t0\nb\tEXIT\t0\t0\t0\t0\nc\tEXIT\t0\t0\t0\t0\n"
    rep_o = "a\tEXIT\t0\t0\t0\t0\nb\tEXIT\t0\t0\t0\t0\nc\tCRASH\t11\t0\t0\t0\n"
    rows = compare(read_road(rep_s, os.path.join(t, "s")), read_road(rep_o, os.path.join(t, "o")))
    same = compare(read_road(rep_s, os.path.join(t, "s")), read_road(rep_s, os.path.join(t, "s")))
    got = {r[0]: r[1] for r in rows}
    ok = got == {"b": "stdout", "c": "end"} and not same and rows[0][4:] == ("y", "Q")
    print(f"ROADS_PROBE equal_entry=silent output_differs={got.get('b')} end_differs={got.get('c')} same_road_twice={len(same)}")
    print("GATE OK [util_prelude_roads --probe]" if ok else "GATE FAIL [util_prelude_roads --probe]")
    return 0 if ok else 1


def main(argv):
    if argv[:1] == ["--probe"]:
        os.makedirs(f"/tmp/s4e/{os.environ.get('S4E_SEAT') or 'probe'}", exist_ok=True); return probe()
    if not argv: refuse("usage: util_prelude_roads.py SUITE-KEY [--out DIR] [--limit N] | --probe")
    key = argv[0]
    out = argv[argv.index("--out") + 1] if "--out" in argv else "/home/resources/progress/PRELUDE-ROADS"
    limit = int(argv[argv.index("--limit") + 1]) if "--limit" in argv else 0
    row = next((c for c in (l.rstrip("\n").split("\t") for l in open(os.path.join(ROOT, "harness/scripts/SUITE_RUNNERS.tsv"), encoding="utf-8")) if c and c[0] == key), None)
    if not row or len(row) < 5: refuse(f"no suite {key} in SUITE_RUNNERS.tsv")
    if row[2] != "prolog": refuse(f"{key} is a {row[2]} suite: the prelude object is Prolog's")
    d = os.path.join(ROOT, row[4])
    idx = os.path.join(d, "ALL.csv")
    if not os.path.isfile(idx): refuse(f"{d} has no ALL.csv")
    with open(idx, newline="", encoding="utf-8", errors="replace") as f:
        rows = list(csv.DictReader(f))
    if not rows or "path" not in rows[0]: refuse(f"{key} is not on the package switch (its index has no path column)")
    scrip = os.path.join(ROOT, "SCRIP", "scrip")
    if not os.access(scrip, os.X_OK): refuse(f"no binary at {scrip}")
    p = subprocess.run(["bash", os.path.join(HERE, "util_prelude_object.sh"), "--root", ROOT], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    so = p.stdout.strip()
    if p.returncode != 0 or not os.path.isfile(so): refuse(f"no prelude object: {p.stderr.strip()[-200:]}")
    seat = os.environ.get("S4E_SEAT") or "roads"
    os.makedirs(f"/tmp/s4e/{seat}", exist_ok=True)
    t = tempfile.mkdtemp(prefix=f"prelude_roads_{key}_", dir=f"/tmp/s4e/{seat}")
    extra = []
    if limit:
        om = os.path.join(d, "ALL.omit")
        omitted = {l.split(": ", 1)[0] for l in open(om, "rb").read().decode("utf-8", "replace").split("\n") if l.strip() and not l.startswith("#") and ": " in l} if os.path.isfile(om) else set()
        only = os.path.join(t, "only.txt")
        open(only, "w", encoding="utf-8").write("".join(r["entry"] + "\n" for r in [r for r in rows if r["entry"] not in omitted][:limit]))
        extra = ["--only", only]
    roads = {}
    for name, sw in (("source", "0"), ("object", so)):
        o = os.path.join(t, name)
        cmd = ["bash", os.path.join(HERE, "util_run_slot.sh"), scrip, "--run-files", d, "--out", o, "--work", os.path.join(t, name + ".w")] + extra
        r = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=t, env=dict(os.environ, SCRIP_PL_PRELUDE_SO=sw, SNO_LIB=os.path.join(ROOT, "corpus")))
        if r.returncode != 0: refuse(f"scrip --run-files on the {name} road ended rc {r.returncode}: {r.stderr.decode('utf-8', 'replace').strip()[-200:]}")
        roads[name] = read_road(r.stdout.decode("utf-8", "replace"), o)
    if not roads["source"]: refuse("no entry ran on the source road")
    diff = compare(roads["source"], roads["object"])
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, key + ".roads.tsv"), "w", encoding="utf-8") as f:
        f.write(f"# PRELUDE ROADS of {key}: entry\twhat differs\tsource road ended\tobject road ended\tsource road's first differing line\tobject road's\n")
        for r in diff: f.write("\t".join(r) + "\n")
    tree = subprocess.run(["git", "-C", os.path.join(ROOT, "SCRIP"), "rev-parse", "--short=9", "HEAD"], stdout=subprocess.PIPE, text=True).stdout.strip()
    cnt = lambda w: sum(1 for r in diff if w in r[1].split("+"))
    print(f"PRELUDE_ROADS suite={key} entries={len(roads['source'])} differ={len(diff)} end={cnt('end')} stdout={cnt('stdout')} stderr={cnt('stderr')} (tree {tree})")
    return 1 if diff else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
