#!/usr/bin/env python3
# icon_demo.py -- ONE LAUNCHER RUNS ANY GRADED GRAPHICS ENTRY ON THE CALLER'S DISPLAY (the cto's ruling 2026-11-16 15:2x CST, row
# icon-graphics-one-launcher-runs-any-graded-graphics-entry-on-the-callers-display; built by officer_02). Lon reads demos working, and every graded
# run is the screen road's, on a display of its own nobody looks at; about half of the graded entries need arguments, stdin or fixtures and cannot
# be started right by typing their name. This starts one for a person, staged exactly as the one prover stages it: by ipl_graphics_stage.py beside
# this file, which the prover imports too, never a copy of its staging.
#   icon_demo.py NAME [--oracle] [--args 'A B ...'] [--scrip DIR]
#       runs the entry NAME of ipl_gprogs, ipl_gpacks or ipl_gprocs (PKG/NAME when two packages share it; a pack's entry by FOLDER/NAME or its
#       NAME alone when unique) on SCRIP in mode 3, on the caller's DISPLAY, in a scratch folder of its own that it removes after: the program,
#       its fixtures and companions, its ALL.args arguments and its NAME.in on stdin (else the caller's terminal), as the entry's row says; then
#       the person drives it. SCRIP is $S4E_SCRIP/scrip (or --scrip DIR), started as the harness's mode 3 starts it: the row's compile_args and
#       declared heap and stack, the package's CONTRACT.tsv ipath and lpath, the entry's NAME.env and NAME.shims. --oracle runs the same staging
#       on the graphics oracle (icont and iconx of GRAPHICS_ICON_ORACLE_DIR), so the two can stand side by side. --args replaces the row's
#       arguments (the probe's planted wrong argument). The pin shim is not laid on a person's run: a person's clock is the clock.
#   icon_demo.py --list         every entry of the three packages, one line each: package, name, the Subject line of the program's header.
#   icon_demo.py --keys NAME    the program's header, its own text on how it is driven.
#   icon_demo.py --probe        the proof, on the screen road (util_screen_run.py beside this file, a display of its own): no DISPLAY refuses;
#       one entry of each kind (bare, arguments and a fixture, stdin, a pack of ipl_gpacks) run through this launcher under the road with its
#       NAME.events gives its stored NAME.out; the same through --oracle; a planted wrong argument reads RED; --list names every row. An arm
#       whose answer differs is run once more and says RETRIED, as the one prover runs a shaky entry again alone: a loaded box can end a run
#       at a still screen before the program has drawn its next picture (MEASURED 2026-11-16: mirroror and drawtree each read 1 screen line
#       once under load and their whole answer alone).
# It never sets DISPLAY and refuses rc 2 when none is set. A SEAT NEVER RUNS IT ON DISPLAY 0, which is Lon's screen: with S4E_SEAT set, a DISPLAY
# of :0 is refused rc 2; a seat's run is the road's. It writes nothing under the corpus. rc: the program's status; 2 a refusal.
import argparse, csv, io, os, re, shlex, shutil, signal, subprocess, sys, tempfile, types
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
SHOW = {k: os.environ[k] for k in ("DISPLAY", "XAUTHORITY", "WAYLAND_DISPLAY") if os.environ.get(k)}   # the caller's display, read before the harness drops it
import corpus_suite_harness as H
import ipl_graphics_stage as G
ROAD = HERE / "util_screen_run.py"
PROBE = (("bare", "ipl_gprogs", "sier1"), ("arguments and a fixture", "ipl_gprogs", "mirroror"), ("stdin", "ipl_gprogs", "palcheck"),
         ("a pack", "ipl_gpacks", "drawtree/drawtree"))
def refuse(m): print("REFUSE(2): " + m, file=sys.stderr); sys.exit(2)
def rows_of(pkg):
    return {r["entry"]: r for r in csv.DictReader(io.StringIO((pkg / "ALL.csv").read_text()))}
def find(spec):
    top = G.corpus() / "packages/icon"
    hits = []
    for p in G.PACKAGES:
        pkg = top / p
        if not (pkg / "ALL.csv").is_file(): continue
        for e in rows_of(pkg):
            if spec in (e, f"{p}/{e}") or ("/" in e and spec == e.split("/")[-1]): hits.append((pkg, e))
    if not hits: refuse(f"{spec} is no entry of {', '.join(G.PACKAGES)} under {top} (--list names them)")
    if len(hits) > 1: refuse(f"{spec} names {len(hits)} entries: " + ", ".join(f"{p.name}/{e}" for p, e in hits))
    return hits[0]
def header(src):
    out = []
    for l in src.read_text(errors="replace").split("\n"):
        if not l.startswith("#"):
            if out: break
            continue
        t = l[1:]
        if re.fullmatch(r"#+", t.strip()) or re.fullmatch(r"-+", t.strip()): t = ""
        out.append(t.rstrip())
    while out and not out[0].strip(): out.pop(0)
    while out and not out[-1].strip(): out.pop()
    return "\n".join(re.sub(r"\n{3,}", "\n\n", "\n".join(out)).split("\n"))
def subject(src):
    m = re.search(r"(?m)^#\s*Subject:\s*(.*\S)", src.read_text(errors="replace")) if src.is_file() else None
    return m.group(1) if m else "-"
def scrip_bin(given):
    d = Path(given or os.environ.get("S4E_SCRIP") or "")
    if not given and not os.environ.get("S4E_SCRIP"):
        import harness_paths
        d = harness_paths.scrip()
    if not (d / "scrip").is_file(): refuse(f"no scrip at {d}/scrip: name a built SCRIP with --scrip DIR or S4E_SCRIP")
    return d / "scrip"
def launch(spec, oracle=False, args=None, scrip=None):
    disp = SHOW.get("DISPLAY") or ""
    if not disp: refuse("no DISPLAY is set: this launcher shows a program on the caller's display and never chooses one")
    if os.environ.get("S4E_SEAT") and re.fullmatch(r"(unix|localhost)?:0(\.\d+)?", disp): refuse(f"a seat never runs this on display {disp}, Lon's screen; a seat's run is the road's (--probe)")
    pkg, name = find(spec)
    row = rows_of(pkg)[name]
    ents = {e.name: e for e in H.read_package_dir(pkg, ".icn")}
    if name not in ents: refuse(f"{name} is a row of {pkg}/ALL.csv the harness does not read as an entry")
    argv = G.read_args(pkg).get(name, []) if args is None else shlex.split(args)
    sin = G.stdin_of(pkg, row)
    work = Path(tempfile.mkdtemp(prefix="icon_demo."))
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143)); signal.signal(signal.SIGHUP, lambda *_: sys.exit(129))
    try:
        try:
            d, src = G.stage(ents[name], work / "run", pkg)
            for o in (row.get("out_files") or "").split(): (d / o).unlink(missing_ok=True)
            if oracle:
                M = G.oracle_dir()
                if not (M / "bin/icont").is_file(): refuse(f"no graphics oracle at {M}")
                env = G.oracle_env(M, G.corpus() / "packages/icon/ipl", d)
                cmd = G.oracle_build(M, name, src, d, env, modules=pkg.name == "ipl_gpacks") + argv
                env.update(SHOW)
            else:
                exe = scrip_bin(scrip)
                H._pkg_ipath_for(types.SimpleNamespace(lang="icon", sno=str(pkg / "ALL.csv")))
                env = dict(os.environ, **SHOW)
                side = H.side_env_for_source(d / src, d) or {}
                env.update({k: v for k, v in side.items() if k != "LD_PRELOAD"})
                kb = lambda c: int(row[c]) if (row.get(c) or "").strip().isdigit() else None
                cmd = [str(exe), "--run"] + (row.get("compile_args") or "").split() + H._size_switches(kb("heap_kb"), kb("stack_kb")) + [src] + (["--"] + argv if argv else [])
                sb = shutil.which("stdbuf")
                if sb: cmd = [sb, "-o0", "-e0"] + cmd
        except G.Refuse as e:
            refuse(str(e))
        f = open(sin, "rb") if sin else None
        try:
            return subprocess.run(cmd, cwd=d, env=env, stdin=f).returncode
        finally:
            if f: f.close()
    finally:
        shutil.rmtree(work, ignore_errors=True)
def do_list():
    top = G.corpus() / "packages/icon"
    n = 0
    for p in G.PACKAGES:
        pkg = top / p
        if not (pkg / "ALL.csv").is_file(): continue
        for e, r in rows_of(pkg).items():
            print(f"{p}\t{e}\t{subject(G.source_of(pkg, r))}"); n += 1
    return n
def road_run(pkg, name, extra, tmp):
    row = rows_of(pkg)[name]
    stem = G.source_of(pkg, row).with_suffix("")
    road = [sys.executable, "-I", str(ROAD), "--out", "screen.dump"]
    for x, fl in ((".events", "--events"), (".cap", "--cap"), (".depth", "--depth")):
        f = Path(str(stem) + x)
        if f.is_file(): road += [fl, str(f) if x == ".events" else f.read_text().strip()]
    cwd = Path(tempfile.mkdtemp(dir=tmp))
    env = {k: v for k, v in os.environ.items() if k not in ("DISPLAY", "XAUTHORITY")}
    env["TMPDIR"] = str(tmp)
    t = int(row.get("timeout_s") or 600) + 300
    p = subprocess.run(road + ["--", sys.executable, "-I", str(Path(__file__).resolve()), f"{pkg.name}/{name}"] + extra, cwd=cwd, env=env, stdin=subprocess.DEVNULL, capture_output=True, timeout=t)
    if p.returncode == 2 and b"REFUSE" in p.stderr: refuse(f"the road refused {name}: {p.stderr.decode(errors='replace').strip()[:300]}")
    ans = p.stdout + ((cwd / "screen.dump").read_bytes() if (cwd / "screen.dump").is_file() else b"<<out_files: screen.dump was not written>>\n")
    return ans, p.returncode, Path(str(stem) + ".out").read_bytes(), int(row.get("want_rc") or 0)
def probe(scrip):
    if not ROAD.is_file(): refuse(f"no road {ROAD}")
    if not shutil.which("Xvfb") or not shutil.which("xwd"): refuse("no Xvfb or no xwd: the road cannot run")
    exe = scrip_bin(scrip)
    tmp = Path(tempfile.mkdtemp(prefix="icon_demo_probe."))
    bad = 0
    def arm(n, ok, what):
        nonlocal bad
        print(f"  arm {n} {'GREEN' if ok else 'RED'}: {what}"); bad += 0 if ok else 1
    try:
        env = {k: v for k, v in os.environ.items() if k != "DISPLAY"}
        q = subprocess.run([sys.executable, "-I", str(Path(__file__).resolve()), "sier1"], env=env, stdin=subprocess.DEVNULL, capture_output=True, timeout=60)
        arm(1, q.returncode == 2 and b"no DISPLAY" in q.stderr, f"with no DISPLAY it refuses (rc {q.returncode})")
        os.environ["S4E_SCRIP"] = str(exe.parent)
        k = 2
        for kind, p, name in PROBE:
            pkg = G.corpus() / "packages/icon" / p
            for extra, eng in (([], "SCRIP"), (["--oracle"], "the oracle")):
                if eng != "SCRIP" and kind != "bare": continue
                ans, rc, want, wrc = road_run(pkg, name, extra, tmp)
                if ans != want or rc != wrc:
                    print(f"  RETRIED {p}/{name} on {eng}: the first reading differed ({ans.count(b'screen ')} screen lines); the road's verdict is never read against a clock, so it runs once more")
                    ans, rc, want, wrc = road_run(pkg, name, extra, tmp)
                arm(k, ans == want and rc == wrc, f"{kind}: {p}/{name} on {eng} under the road with its events gives its {Path(name).name}.out (status {rc}, {ans.count(b'screen ')} screen lines)"); k += 1
        pkg = G.corpus() / "packages/icon/ipl_gprogs"
        ans, rc, want, _ = road_run(pkg, "mirroror", ["--args", "no-such-image.gif"], tmp)
        arm(k, ans != want, "a planted wrong argument (mirroror given no-such-image.gif) does not give mirroror.out"); k += 1
        rows = sum(len(rows_of(G.corpus() / "packages/icon" / p)) for p in G.PACKAGES if (G.corpus() / "packages/icon" / p / "ALL.csv").is_file())
        q = subprocess.run([sys.executable, "-I", str(Path(__file__).resolve()), "--list"], capture_output=True, timeout=120)
        arm(k, q.returncode == 0 and len(q.stdout.decode().strip().split("\n")) == rows, f"--list names every row of the three packages ({rows})")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("ICON_DEMO_PROBE " + ("RED" if bad else "OK") + f": {bad} arm(s) red")
    return 1 if bad else 0
def main():
    ap = argparse.ArgumentParser(description="run a graded Icon graphics entry on the caller's display, staged as its prover stages it")
    ap.add_argument("name", nargs="?")
    ap.add_argument("--oracle", action="store_true"); ap.add_argument("--args"); ap.add_argument("--scrip")
    ap.add_argument("--list", action="store_true"); ap.add_argument("--keys", metavar="NAME"); ap.add_argument("--probe", action="store_true")
    a = ap.parse_args()
    if a.probe: sys.exit(probe(a.scrip))
    if a.list: do_list(); sys.exit(0)
    if a.keys:
        pkg, name = find(a.keys); print(header(G.source_of(pkg, rows_of(pkg)[name]))); sys.exit(0)
    if not a.name: refuse("usage: icon_demo.py NAME [--oracle] [--args 'A B'] [--scrip DIR] | --list | --keys NAME | --probe")
    sys.exit(launch(a.name, a.oracle, a.args, a.scrip))
if __name__ == "__main__":
    main()
