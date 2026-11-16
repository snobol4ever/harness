#!/usr/bin/env python3
# prove_ipl_gprogs_entry.py PKG NAME...  THE ONE PROVER OF AN ENTRY OF ipl_gprogs (the cto's ruling 2026-11-16 13:4x CST, row
# icon-graphics-one-prover-of-an-ipl-gprogs-entry-stands-in-harness; officer_07's prove_e2_entry.py of list E2, the widest of the five seats'
# provers, with the B prover's waiting-entry rule; MEASURED before it: the B prover laid NAME.in and never ALL.args and read iview and rstarlab
# RED while both are green). Every give that adds or changes an entry of ipl_gprogs names it as its proof; prove_gpacks_entry.sh is the packs'.
#   PKG   the ipl_gprogs folder (a patched copy, or $S4E_CORPUS/packages/icon/ipl_gprogs once applied)
#   NAME  an entry of PKG/ALL.csv (its path NAME.icn)
# It honours what the harness honours beside an entry: its ALL.args line (the program's arguments), NAME.in (its stdin), NAME.fixtures/ with
# fixtures=staged (its contents staged beside the program, as stage_fixtures does), every other file of PKG beside it (the files form), the
# out_files cell (stdout, then each file's bytes in order; a file not written is <<out_files: N was not written>>), want_rc, and the screen road
# (util_screen_run.py beside this file): --out screen.dump with NAME.events and NAME.cap when out_files names screen.dump, else --no-screen,
# which NAME.display must then mark; NAME.depth as --depth either way; NAME.pin's clock and entropy shim on the program.
# THE WAITING RULE (the ruling of 11:2x: a program that waits is graded on a script of its own): an entry the road finds waiting, that is ended
# by the road at a still screen and not by itself, carries NAME.events, or one line of PKG/EVENTS-NONE.tsv with its reason and then no
# NAME.events; either fault reads RED. An entry that ends by itself, or that never holds still (screen unstable), needs neither. Which ended it is
# read from a status file the program's own shell writes when the program ends; the road's kill of the program's group leaves none.
# Built by the graphics oracle (GRAPHICS_ICON_ORACLE_DIR of lib_oracle_flags.sh: icont -s, IPATH its lib, LPATH the ipl includes), HOME its own
# folder, DISPLAY unset; each NAME runs twice, each run in a copy of PKG of its own, the package copied once at the start and every reading taken
# of that copy, so a tree changed under the proof cannot change its verdict. The two runs must be equal (answer and status), the answer equal to
# PKG/NAME.out and the status to the row's want_rc.
# rc 0 GREEN (every NAME), 1 RED (named), 2 REFUSAL (no oracle, no road, no row, no NAME.out, a build that fails, a road that refuses).
import csv, io, os, shutil, subprocess, sys, tempfile
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROAD = HERE / "util_screen_run.py"
def refuse(m): print("REFUSE(2): " + m); sys.exit(2)
def sh_value(fn):
    q = subprocess.run(["bash", "-c", f'. "{HERE}/lib_oracle_flags.sh" >/dev/null 2>&1; . "{HERE}/lib_icon_ipl_isolation.sh" >/dev/null 2>&1; {fn}'], capture_output=True, text=True)
    return q.stdout.strip() if q.returncode == 0 else ""
if len(sys.argv) < 3: refuse("usage PKG NAME...")
pkg = Path(sys.argv[1]).resolve()
M = Path(sh_value('printf %s "$GRAPHICS_ICON_ORACLE_DIR"') or "/home/resources/icon-master-x")
IPL = Path(os.environ.get("S4E_CORPUS") or "/home/corpus") / "packages/icon/ipl"
if not (M / "bin/icont").is_file() or not (M / "bin/iconx").is_file(): refuse(f"no graphics oracle at {M}")
if not ROAD.is_file(): refuse(f"no road {ROAD}")
if not (pkg / "ALL.csv").is_file(): refuse(f"no {pkg}/ALL.csv")
if not (IPL / "gincl").is_dir(): refuse(f"no {IPL}/gincl")
seat = os.environ.get("S4E_SEAT") or "prove"
base = Path(f"/tmp/s4e/{seat}"); base.mkdir(parents=True, exist_ok=True)
work = Path(tempfile.mkdtemp(prefix="prove_ipl_gprogs.", dir=base))
bad = 0
try:
    snap = work / "pkg"
    shutil.copytree(pkg, snap)
    pkg = snap
    rows = {r["entry"]: r for r in csv.DictReader(io.StringIO((pkg / "ALL.csv").read_text()))}
    argl, none = {}, {}
    if (pkg / "ALL.args").is_file():
        for l in (pkg / "ALL.args").read_text().split("\n"):
            if l.strip() and not l.startswith("#"):
                f = l.split("\t"); argl[f[0]] = f[1:]
    if (pkg / "EVENTS-NONE.tsv").is_file():
        for l in (pkg / "EVENTS-NONE.tsv").read_text().split("\n"):
            f = l.split("\t")
            if l and not l.startswith("#") and len(f) > 1 and f[1].strip(): none[f[0]] = f[1]
    for name in sys.argv[2:]:
        r = rows.get(name) or refuse(f"{name} has no row in {pkg}/ALL.csv")
        if not (pkg / f"{name}.out").is_file(): refuse(f"{name} has no {name}.out")
        outs = [o for o in (r.get("out_files") or "").split(" ") if o]
        screen = "screen.dump" in outs
        events = (pkg / f"{name}.events").is_file()
        if screen and (pkg / f"{name}.display").exists(): refuse(f"{name} names screen.dump and carries {name}.display")
        if not screen and not (pkg / f"{name}.display").exists(): refuse(f"{name} names no screen.dump and has no {name}.display")
        if name in none and events: bad = 1; print(f"RED {name}: named in EVENTS-NONE.tsv and carries {name}.events"); continue
        road = [sys.executable, "-I", str(ROAD)]
        if screen:
            road += ["--out", "screen.dump"]
            if events: road += ["--events", str(pkg / f"{name}.events")]
            if (pkg / f"{name}.cap").is_file(): road += ["--cap", (pkg / f"{name}.cap").read_text().strip()]
        else:
            road += ["--no-screen"]
        if (pkg / f"{name}.depth").is_file(): road += ["--depth", (pkg / f"{name}.depth").read_text().strip()]
        pin = []
        if (pkg / f"{name}.pin").is_file():
            so = sh_value("ipl_pin_shim_path")
            if not so: refuse("no pin shim (ipl_pin_shim_path)")
            pin = ["env", "LD_PRELOAD=" + so]
        fx = pkg / f"{name}.fixtures"
        staged = (r.get("fixtures") or "") == "staged" and fx.is_dir()
        runs, waited = [], False
        for n in (1, 2):
            d = work / f"{name}.{n}"
            shutil.copytree(pkg, d)
            if staged: shutil.copytree(fx, d, dirs_exist_ok=True)
            env = {"PATH": "/usr/bin:/bin", "LC_ALL": "C", "IPATH": f"{M}/lib", "LPATH": f"{IPL}/gincl {IPL}/incl", "HOME": str(d)}
            b = subprocess.run([str(M / "bin/icont"), "-s", "-o", name, f"{name}.icn"], cwd=d, env=env, capture_output=True, timeout=300)
            if b.returncode: refuse(f"{name} does not build: {b.stderr.decode(errors='replace').strip()[:200]}")
            for o in outs: (d / o).unlink(missing_ok=True)
            st = work / f"{name}.{n}.status"
            wrap = ["/bin/sh", "-c", '"$@"; r=$?; echo "$r" > "$0"; exit "$r"', str(st)]
            sin = open(pkg / f"{name}.in", "rb") if (pkg / f"{name}.in").is_file() else subprocess.DEVNULL
            try:
                p = subprocess.run(road + ["--"] + wrap + pin + [str(M / "bin/iconx"), name] + argl.get(name, []), cwd=d, env=env, stdin=sin, capture_output=True, timeout=3600)
            finally:
                if sin is not subprocess.DEVNULL: sin.close()
            if p.returncode == 2 and b"REFUSE" in p.stderr: refuse(f"the road refused {name}: {p.stderr.decode(errors='replace').strip()[:200]}")
            ans = p.stdout
            for o in outs:
                f = d / o
                ans += f.read_bytes() if f.is_file() else f"<<out_files: {o} was not written>>\n".encode()
            runs.append((p.returncode, ans))
            dump = (d / "screen.dump").read_text(errors="replace").strip().split("\n")[-1] if screen and (d / "screen.dump").is_file() else ""
            if screen and n == 1 and not st.is_file() and dump.startswith("screen ") and dump != "screen unstable": waited = True
        want = (pkg / f"{name}.out").read_bytes()
        why = []
        if waited and not events and name not in none: why.append(f"it waits for an event and carries no {name}.events and no EVENTS-NONE.tsv line")
        if runs[0] != runs[1]: why.append("the two runs differ")
        if runs[0][1] != want: why.append(f"the answer differs from {name}.out")
        if str(runs[0][0]) != (r.get("want_rc") or "0"): why.append(f"status {runs[0][0]}, want_rc {r.get('want_rc')}")
        if why: bad = 1; print(f"RED {name}: " + "; ".join(why))
        elif name in none: print(f"NAMED {name}: EVENTS-NONE.tsv, its still picture stands; twice equal, its {name}.out, status {runs[0][0]}")
        else: print(f"GREEN {name}: twice equal, its {name}.out, status {runs[0][0]}" + ("" if not screen else ", waits, its script" if waited else ", ends by itself"))
finally:
    shutil.rmtree(work, ignore_errors=True)
print("PROVE_IPL_GPROGS " + ("RED" if bad else "OK") + f": {len(sys.argv) - 2} entries")
sys.exit(bad)
