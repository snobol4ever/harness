#!/usr/bin/env python3
"""util_empty_output_stderr_census.py --suite KEY=PKGDIR:LANG [--suite ...] [--out DIR] -- THE EMPTY-OUTPUT CLASS, CENSUSED BY WHAT IT SAID
(the ceo, CEO-1709, 2026-10-14: about 480 programs across ProRosetta, ProPuzzles, Trealla and PasRosetta FAIL with an EMPTY stdout,
fp=d41d8cd9, the md5 of nothing -- "a first-stderr-line census of those programs is the most valuable board you can run").

For each suite: the progress table's NEWEST mode-3 row per program of that suite key (the table is compacted, not time-ordered, so the
newest timestamp wins) selects every program whose row is FAIL or CRASH with fp=d41d8cd9. Those entries are cut out of the package's
container (ALL.<ext> and ALL.ref by their banners, with their ALL.csv and ALL.wantrc rows) into a COPY of the package directory, so the
prelude and every companion file stand where the program expects them, and corpus_suite_harness.py grades that mini-container in mode 3
with SUITE_STDERR_HEAD=1 (each red line carries err1=<the first non-empty stderr line>) and S4E_PROGRESS_OFF=1 (no progress row, no
score row: a census is a measurement, never a reading of the suite). The first stderr lines are grouped into classes (numbers, quoted
atoms and paths folded) and printed per suite, largest first, with an example program each; the full table goes to DIR/census.tsv.
DIR is the caller's: --out DIR, else the one fixed directory $S4E_HOME/.scratch/empty_census_out (else /tmp/empty_census_out) that a rerun
reuses -- the table is the deliverable, so it is never removed, and a fixed name cannot pile up a /tmp directory per run. The package copy
the harness grades is scratch and is removed as soon as it has been graded.
rc 0 measured, 2 could not measure.
"""
import collections, os, re, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REFUSED = []   # a suite the harness would not grade is named and skipped, never read as "0 red", and the run ends rc 2
DB = os.environ.get("S4E_PROGRESS_DB", "/home/resources/progress/results.tsv")
BANNER = re.compile(r"^(?:%|\{)-{10,} (\d+) (\S+?)\}?\s*$")
EXT = {"prolog": "pl", "pascal": "pas"}


def refuse(msg):
    print("⛔ REFUSED (rc 2): " + msg, file=sys.stderr)
    sys.exit(2)


def empty_programs(key):
    newest = {}
    with open(DB, encoding="utf-8", errors="replace") as f:
        head = f.readline().rstrip("\n").split("\t")
        ix = {h: i for i, h in enumerate(head)}
        for ln in f:
            c = ln.rstrip("\n").split("\t")
            if len(c) <= ix["note"] or c[ix["suite"]] != key or c[ix["mode"]] != "m3":
                continue
            p = c[ix["program"]]
            if p not in newest or c[ix["ts_utc"]] > newest[p][0]:
                newest[p] = (c[ix["ts_utc"]], c[ix["outcome"]], c[ix["note"]], c[ix["scrip"]])
    sel = sorted(p for p, (_, o, n, _) in newest.items() if o in ("FAIL", "CRASH") and "fp=d41d8cd9" in n)
    trees = collections.Counter(v[3] for p, v in newest.items() if p in sel)
    return sel, trees


def cut(path, names):
    out, keep = [], False
    for ln in open(path, encoding="utf-8", errors="replace"):
        m = BANNER.match(ln.rstrip("\n"))
        if m:
            keep = m.group(2) in names
        if keep:
            out.append(ln)
    return "".join(out)


def census(key, pkg, lang, outdir):
    names, trees = empty_programs(key)
    if not names:
        print(f"== {key}: no program's newest mode-3 row reads an empty stdout -- nothing to census")
        return []
    ext = EXT.get(lang) or refuse(f"no container extension known for --lang {lang}")
    src = os.path.join(pkg, "ALL." + ext)
    os.path.isfile(src) or refuse(f"no container at {src}")
    work = tempfile.mkdtemp(prefix=f"empty_census_{key}_", dir=outdir); __import__("atexit").register(shutil.rmtree, work, True)
    copy = os.path.join(work, os.path.basename(pkg.rstrip("/")))
    shutil.copytree(pkg, copy, symlinks=True)
    nset = set(names)
    open(os.path.join(copy, "ALL." + ext), "w").write(cut(src, nset))
    # the sidecars keep only the entries the cut ACTUALLY holds: a progress name with no banner (a container fragment, an older corpus's
    # name) is not an entry, and a sidecar row naming it makes the harness refuse the whole mini-container
    nset = {m.group(2) for m in (BANNER.match(l.rstrip("\n")) for l in open(os.path.join(copy, "ALL." + ext), encoding="utf-8", errors="replace")) if m}
    open(os.path.join(copy, "ALL.ref"), "w").write(cut(os.path.join(pkg, "ALL.ref"), nset))
    for side in ("ALL.wantrc", "ALL.argv", "ALL.in", "ISO_EXPECTED_REFUSALS.tsv"):   # every sidecar the harness checks against the entries
        p = os.path.join(pkg, side)
        if os.path.isfile(p):
            rows = [l for l in open(p, encoding="utf-8", errors="replace") if l.startswith("#") or l.split("\t")[0].strip() in nset]
            open(os.path.join(copy, side), "w").write("".join(rows))
    csvp = os.path.join(pkg, "ALL.csv")
    if os.path.isfile(csvp):
        L = open(csvp, encoding="utf-8").read().split("\n")
        hdr = L[0].split(","); ei = hdr.index("entry") if "entry" in hdr else 1
        open(os.path.join(copy, "ALL.csv"), "w").write("\n".join([L[0]] + [l for l in L[1:] if l and l.split(",")[ei] in nset]) + "\n")
    got = sum(1 for l in open(os.path.join(copy, "ALL." + ext), encoding="utf-8", errors="replace") if BANNER.match(l.rstrip("\n")))
    env = dict(os.environ, S4E_PROGRESS_OFF="1", SUITE_LIST_ALL="1", SUITE_STDERR_HEAD="1")
    r = subprocess.run([sys.executable, os.path.join(HERE, "corpus_suite_harness.py"), "run", os.path.join(copy, "ALL." + ext),
                        os.path.join(copy, "ALL.ref"), "--lang", lang, "--modes", "m3"], env=env, capture_output=True, text=True)
    shutil.rmtree(work, ignore_errors=True)   # the mini-container is a package copy: released the moment it has been graded, not at exit
    open(os.path.join(outdir, f"{key}.harness.out"), "w").write(r.stdout + r.stderr)
    # ⛔ A HARNESS THAT DID NOT GRADE IS A REFUSAL, NEVER "0 red": the first draft read a harness traceback as every program cured
    if r.returncode not in (0, 1) or "SUITE_BOARD " not in (r.stdout + r.stderr):
        REFUSED.append(key)
        print("⛔ REFUSED (this suite only): " + f"{key}: the harness did not grade the mini-container (rc {r.returncode}); its output is in {outdir}/{key}.harness.out: "
               + (r.stdout + r.stderr).strip().split("\n")[-1][:200])
        return []
    rows = []
    red = re.compile(r"^\s+([A-Z]+) m3 (\S+): .*\[fp=(\w+) rc=(\S+)\] err1=(.*)$")
    for ln in (r.stdout + r.stderr).split("\n"):
        m = red.match(ln)
        if m:
            rows.append((key, m.group(2), m.group(1), m.group(3), m.group(4), m.group(5)))
    passed = len(names) - len(rows)
    print(f"== {key}: {len(names)} empty-output program(s) on progress trees {dict(trees)}; {got} cut into the mini-container ({len(names) - got} name(s) with no banner); "
          f"graded now in mode 3: {len(rows)} red, {got - len(rows)} no longer red (the tree moved since their row)")
    return rows


def klass(e):
    e = re.sub(r"(?:(?<=\s)|(?<=^)|(?<=[('\"=]))/[\w.-]+(?:/[\w.-]+)+", "<path>", e)   # a path starts a token; name/3 is a predicate
    e = re.sub(r"'[^']*'|\"[^\"]*\"", "<q>", e)
    e = re.sub(r"\b\d+\b", "N", e)
    e = re.sub(r"_G\d+|_\d+", "_V", e)
    return e[:110]


def main(argv):
    suites = [argv[i + 1] for i, a in enumerate(argv) if a == "--suite"]
    outdir = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(os.path.join(os.environ["S4E_HOME"], ".scratch") if os.environ.get("S4E_HOME") else tempfile.gettempdir(), "empty_census_out")
    suites or refuse("usage: util_empty_output_stderr_census.py --suite KEY=PKGDIR:LANG [...] [--out DIR]")
    os.makedirs(outdir, exist_ok=True)
    os.path.isfile(DB) or refuse(f"no progress table at {DB}")
    allrows = []
    for s in suites:
        m = re.match(r"^([\w-]+)=(.+):(\w+)$", s) or refuse(f"--suite {s} is not KEY=PKGDIR:LANG")
        allrows += census(m.group(1), m.group(2), m.group(3), outdir)
    with open(os.path.join(outdir, "census.tsv"), "w") as f:
        f.write("suite\tprogram\tverdict\tfp\trc\tfirst_stderr_line\tclass\n")
        for r in allrows:
            f.write("\t".join(r) + "\t" + klass(r[5]) + "\n")
    for key in dict.fromkeys(r[0] for r in allrows):
        c = collections.Counter(klass(r[5]) for r in allrows if r[0] == key)
        ex = {}
        for r in allrows:
            if r[0] == key: ex.setdefault(klass(r[5]), r[1])
        print(f"-- {key}: {sum(c.values())} red, {len(c)} class(es) by first stderr line")
        for k, n in c.most_common(25):
            print(f"   {n:4d}  {k}   (e.g. {ex[k]})")
    print(f"EMPTY_OUTPUT_CENSUS suites={len(suites)} refused={len(REFUSED)}{(' (' + ' '.join(REFUSED) + ')') if REFUSED else ''} red={len(allrows)} table={os.path.join(outdir, 'census.tsv')}")
    return 2 if REFUSED else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
