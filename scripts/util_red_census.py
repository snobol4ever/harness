#!/usr/bin/env python3
"""util_red_census.py SUITE-KEY [--out DIR] [--limit N] -- THE FAILING TESTS OF ONE SUITE, GROUPED BY WHAT THEY SAY (the cio 2026-11-11, CIO-128; Lon
2026-11-11 09:4x CST, in the cio's window: "What else needs to be designed? ... Time to brainstorm."; the cio's answer: a failing test becomes a
task row only when a designer reads it, and 3,320 fail). For a suite the cycle grades on the package switch (its index has a path column), every
test whose latest mode-3 reading in the progress store is FAIL, CRASH, HANG or OOM is run ONCE more through scrip --run-files, and its result is
reduced to a SIGNATURE: how it ended (exit code, signal, timeout), the first line of its standard error with numbers, addresses, quoted text and
paths blanked, or, with an empty standard error, how its output first differs from the answer (nothing printed; shorter; first differing line).
Tests with one signature are one GROUP: one cause to find, one row to cut.
Writes DIR/SUITE.groups.tsv (count, signature, up to five tests) and DIR/SUITE.tests.tsv (test, signature); prints RED_CENSUS suite=K failing=N
ran=N groups=G largest=M covered_by_top_ten=P%. rc 0; rc 2 refused (no such suite, not on the package switch, no binary). Reads the corpus and
writes only under DIR and its scratch folder. A program ALL.omit names is no entry of the package (the builder ships it ungraded) and is
never counted or run, whatever an old reading of it says."""
import collections, csv, os, re, subprocess, sys, tempfile
ROOT = os.environ.get("S4E_HOME") or "/home/claude_cio"
sys.path.insert(0, os.path.join(ROOT, "harness", "scripts"))


def refuse(m):
    print(f"REFUSE(2) [util_red_census]: {m}"); sys.exit(2)


def norm(s):
    s = re.sub(r"/[^\s:'\"]+", "PATH", s)
    s = re.sub(r"0x[0-9a-fA-F]+", "ADDR", s)
    s = re.sub(r"'[^']*'|\"[^\"]*\"|`[^`]*`", "Q", s)
    s = re.sub(r"\b\d+\b", "N", s)
    s = re.sub(r"\b_G?N\b|\b_[A-Z]\w*\b", "VAR", s)
    return re.sub(r"\s+", " ", s).strip()[:140]


def main(argv):
    if not argv: refuse("usage: util_red_census.py SUITE-KEY [--out DIR] [--limit N]")
    key = argv[0]
    out = argv[argv.index("--out") + 1] if "--out" in argv else "/home/resources/progress/RED-CENSUS"
    limit = int(argv[argv.index("--limit") + 1]) if "--limit" in argv else 10**9
    row = None
    for l in open(os.path.join(ROOT, "harness/scripts/SUITE_RUNNERS.tsv"), encoding="utf-8"):
        c = l.rstrip("\n").split("\t")
        if c and c[0] == key: row = c
    if not row or len(row) < 5: refuse(f"no suite {key} in SUITE_RUNNERS.tsv")
    d = os.path.join(ROOT, row[4])
    idx = os.path.join(d, "ALL.csv")
    if not os.path.isfile(idx): refuse(f"{d} has no ALL.csv")
    with open(idx, newline="", encoding="utf-8", errors="replace") as f:
        rows = list(csv.DictReader(f))
    if not rows or "path" not in rows[0]: refuse(f"{key} is not on the package switch (its index has no path column): convert the package first")
    om = os.path.join(d, "ALL.omit")
    omitted = {l.split(": ", 1)[0] for l in open(om, "rb").read().decode("utf-8", "replace").split("\n") if l.strip() and not l.startswith("#") and ": " in l} if os.path.isfile(om) else set()
    path_of = {r["entry"]: r["path"] for r in rows if r["entry"] not in omitted}
    last = {}
    with open("/home/resources/progress/results.tsv", encoding="utf-8", errors="replace") as f:
        for l in f:
            c = l.rstrip("\n").split("\t")
            if len(c) > 9 and c[5] == key and c[8] == "m3": last[c[7]] = c[9]
    failing = sorted(n for n, o in last.items() if o in ("FAIL", "CRASH", "HANG", "OOM") and n in path_of)[:limit]
    if not failing:
        print(f"RED_CENSUS suite={key} failing=0 ran=0 groups=0"); return 0
    scrip = os.path.join(ROOT, "SCRIP", "scrip")
    if not os.access(scrip, os.X_OK): refuse(f"no binary at {scrip}")
    seat = os.environ.get("S4E_SEAT") or "census"
    os.makedirs(f"/tmp/s4e/{seat}", exist_ok=True)
    t = tempfile.mkdtemp(prefix=f"red_census_{key}_", dir=f"/tmp/s4e/{seat}")
    only = os.path.join(t, "only.txt")
    open(only, "w", encoding="utf-8").write("".join(n + "\n" for n in failing))
    cmd = ["bash", os.path.join(ROOT, "harness/scripts/util_run_slot.sh"), scrip, "--run-files", d, "--out", os.path.join(t, "o"), "--work", os.path.join(t, "w"), "--only", only]
    r = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=t, env=dict(os.environ, SNO_LIB=os.path.join(ROOT, "corpus")))
    if r.returncode != 0: refuse(f"scrip --run-files {d} ended rc {r.returncode}: {r.stderr.decode('utf-8', 'replace').strip()[-200:]}")
    rep = {}
    for l in r.stdout.decode("utf-8", "replace").split("\n"):
        c = l.split("\t")
        if len(c) == 6: rep[c[0]] = (c[1], c[2])
    sig_of = {}
    for n in failing:
        typ, num = rep.get(n, ("NO-REPORT", ""))
        nm = n.replace("/", "_")
        def rd(p):
            try: return open(p, "rb").read().decode("utf-8", "replace")
            except OSError: return ""
        got, err = rd(os.path.join(t, "o", nm + ".out")), rd(os.path.join(t, "o", nm + ".err"))
        want = rd(os.path.join(d, os.path.splitext(path_of[n])[0] + ".out"))
        end = {"EXIT": f"exit {num}", "ABORT": "abort", "CRASH": f"signal {num}", "TIMEOUT": "timeout", "HANG": "timeout", "DEFERRED": "not run by the switch", "OVERFLOW": "output over the bound"}.get(typ, typ.lower())
        e1 = next((x for x in err.split("\n") if x.strip()), "")
        if e1: what = "stderr: " + norm(e1)
        elif typ != "EXIT": what = "no message"
        else:
            g, w = got.rstrip("\n").split("\n"), want.rstrip("\n").split("\n")
            if got.strip() == "": what = "prints nothing"
            elif g == w: what = "output equal to the answer (the red is its exit code, a mask or a stream the answer does not hold)"
            else:
                k = next((i for i, (a, b) in enumerate(zip(g, w)) if a != b), min(len(g), len(w)))
                what = f"output differs: {'stops early' if k >= len(g) else 'prints more' if k >= len(w) else 'first at a line of ' + ('the first three' if k < 3 else 'the body')}"
        sig_of[n] = f"{end} | {what}"
    groups = collections.defaultdict(list)
    for n, s in sig_of.items(): groups[s].append(n)
    os.makedirs(out, exist_ok=True)
    order = sorted(groups.items(), key=lambda kv: -len(kv[1]))
    with open(os.path.join(out, key + ".groups.tsv"), "w", encoding="utf-8") as f:
        f.write(f"# RED CENSUS of {key}: count\tsignature\tup to five tests\n")
        for s, ns in order: f.write(f"{len(ns)}\t{s}\t{' '.join(ns[:5])}\n")
    with open(os.path.join(out, key + ".tests.tsv"), "w", encoding="utf-8") as f:
        for n in failing: f.write(f"{n}\t{sig_of[n]}\n")
    top = sum(len(ns) for _, ns in order[:10])
    print(f"RED_CENSUS suite={key} failing={len(failing)} ran={len(rep)} groups={len(groups)} largest={len(order[0][1])} covered_by_top_ten={100 * top // len(failing)}%")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
