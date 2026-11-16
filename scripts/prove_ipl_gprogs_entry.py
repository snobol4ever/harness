#!/usr/bin/env python3
# prove_ipl_gprogs_entry.py [-j N] PKG NAME...  THE ONE PROVER OF AN ENTRY OF ipl_gprogs (the cto's ruling 2026-11-16 13:4x CST, row
# icon-graphics-one-prover-of-an-ipl-gprogs-entry-stands-in-harness; officer_07's prove_e2_entry.py of list E2, the widest of the five seats'
# provers, with the B prover's waiting-entry rule; MEASURED before it: the B prover laid NAME.in and never ALL.args and read iview and rstarlab
# RED while both are green). Every give that adds or changes an entry of ipl_gprogs names it as its proof; prove_gpacks_entry.sh is the packs'.
#   PKG   the ipl_gprogs folder (a patched copy, or $S4E_CORPUS/packages/icon/ipl_gprogs once applied)
#   NAME  an entry of PKG/ALL.csv (its path NAME.icn)
#   -j K  K entries at once, the two runs of each at once (default DEFAULT_J): each run has its own folder and the road its own Xvfb, and a run is
#         nearly all waiting for its screen to hold still, so the runs share the wall clock (the coo 2026-11-16 13:57 CST: this prover's seconds are
#         the speed of the grader's one landing lane for every Icon graphics give; the cto's ruling 14:0x CST). The road's verdict is never read
#         against a clock: at K above 1 an entry whose answer reads screen unstable or differs (between its runs or from NAME.out) is run once more
#         alone, both runs, nothing else running, and that second reading is its verdict (a line RETRIED-ALONE NAME says so), so load can make no
#         false red and hide no real one.
# EACH RUN IS STAGED BY THE HARNESS'S OWN stage_entry (corpus_suite_harness.py beside this file; the cto's ruling 2026-11-16 14:4x CST, on
# officer_04's finding): the program, the companions its text names, its argv and stdin files, NAME.fixtures/ (fixtures=staged) or its folder
# (fixtures=folder) and the screen road's side files, and nothing else of PKG, so this prover and the graded road cannot drift: a program that
# reads a file of PKG no name in its text gives away reads RED here as it does in the harness. Its cure is the entry's (a fixtures folder, a
# companion its text names), never this prover's. The answer is compared byte for byte with NAME.out, stricter than the harness on purpose (the
# same ruling: a ref is the oracle's bytes, and one that differs in a trailing newline or a decoded byte is a miscut ref).
# It honours what the harness honours beside an entry: its ALL.args line (the program's arguments), NAME.in (its stdin), the
# out_files cell (stdout, then each file's bytes in order; a file not written is <<out_files: N was not written>>), want_rc, and the screen road
# (util_screen_run.py beside this file): --out screen.dump with NAME.events and NAME.cap when out_files names screen.dump, else --no-screen,
# which NAME.display must then mark; NAME.depth as --depth either way; NAME.pin's clock and entropy shim on the program.
# NAME.DISPLAY MARKS A TEXT ENTRY OF THE GRAPHICS FACILITY, run under the road's display whether or not it opens a window (the cto 2026-11-16
# 15:5x CST, on colorwif: it calls PaletteColor and ColorValue and opens no window; the plain oracle stops it with error 106, so it is cut by the
# graphics oracle and graded on its text; one mark serves both, no second form).
# THE WAITING RULE (the ruling of 11:2x, and the cto's (a) of 13:5x: RED with no exemption): an entry the road finds waiting, that is ended by
# the road at a still screen and not by itself, carries NAME.events, or one line of PKG/EVENTS-NONE.tsv with its reason and then no
# NAME.events; either fault reads RED. An entry that ends by itself, or that never holds still (screen unstable), needs neither. Which ended it is
# read from a status file the program's own shell writes when the program ends; the road's kill of the program's group leaves none.
# Built by the graphics oracle (GRAPHICS_ICON_ORACLE_DIR of lib_oracle_flags.sh: icont -s, IPATH its lib, LPATH the ipl includes), HOME its own
# folder, DISPLAY unset; each NAME runs twice, each run in a copy of PKG of its own, the package copied once at the start and every reading taken
# of that copy, so a tree changed under the proof cannot change its verdict. The two runs must be equal (answer and status), the answer equal to
# PKG/NAME.out and the status to the row's want_rc. Verdicts print in the order the names were given.
# rc 0 GREEN (every NAME), 1 RED (named), 2 REFUSAL (no oracle, no road, no row, no NAME.out, a build that fails, a road that refuses).
import csv, io, os, shutil, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
DEFAULT_J = 4
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import corpus_suite_harness as H
ROAD = HERE / "util_screen_run.py"
class Refuse(Exception): pass
def refuse(m): print("REFUSE(2): " + m); sys.exit(2)
def sh_value(fn):
    q = subprocess.run(["bash", "-c", f'. "{HERE}/lib_oracle_flags.sh" >/dev/null 2>&1; . "{HERE}/lib_icon_ipl_isolation.sh" >/dev/null 2>&1; {fn}'], capture_output=True, text=True)
    return q.stdout.strip() if q.returncode == 0 else ""
av = sys.argv[1:]
jobs = DEFAULT_J
if av[:1] == ["-j"]:
    if len(av) < 2 or not av[1].isdigit() or int(av[1]) < 1: refuse("-j takes a count of 1 or more")
    jobs, av = int(av[1]), av[2:]
if len(av) < 2: refuse("usage [-j N] PKG NAME...")
pkg, names = Path(av[0]).resolve(), av[1:]
M = Path(sh_value('printf %s "$GRAPHICS_ICON_ORACLE_DIR"') or "/home/resources/icon-master-x")
IPL = Path(os.environ.get("S4E_CORPUS") or "/home/corpus") / "packages/icon/ipl"
if not (M / "bin/icont").is_file() or not (M / "bin/iconx").is_file(): refuse(f"no graphics oracle at {M}")
if not ROAD.is_file(): refuse(f"no road {ROAD}")
if not (pkg / "ALL.csv").is_file(): refuse(f"no {pkg}/ALL.csv")
if not (IPL / "gincl").is_dir(): refuse(f"no {IPL}/gincl")
seat = os.environ.get("S4E_SEAT") or "prove"
base = Path(f"/tmp/s4e/{seat}"); base.mkdir(parents=True, exist_ok=True)
work = Path(tempfile.mkdtemp(prefix="prove_ipl_gprogs.", dir=base))
def one_run(c, n):
    name, d = c["name"], work / f"{c['name']}.{n}"
    d.mkdir()
    try:
        cand, _ = H.stage_entry(c["entry"], str(d), ".icn", str(pkg))
    except SystemExit:
        raise Refuse(f"the harness refused to stage {name}")
    d, src = cand.parent, cand.name
    env = {"PATH": "/usr/bin:/bin", "LC_ALL": "C", "IPATH": f"{M}/lib", "LPATH": f"{IPL}/gincl {IPL}/incl", "HOME": str(d)}
    b = subprocess.run([str(M / "bin/icont"), "-s", "-o", name, src], cwd=d, env=env, capture_output=True, timeout=300)
    if b.returncode: raise Refuse(f"{name} does not build: {b.stderr.decode(errors='replace').strip()[:200]}")
    for o in c["outs"]: (d / o).unlink(missing_ok=True)
    st = work / f"{name}.{n}.status"
    wrap = ["/bin/sh", "-c", '"$@"; r=$?; echo "$r" > "$0"; exit "$r"', str(st)]
    sin = open(pkg / f"{name}.in", "rb") if (pkg / f"{name}.in").is_file() else subprocess.DEVNULL
    try:
        p = subprocess.run(c["road"] + ["--"] + wrap + c["pin"] + [str(M / "bin/iconx"), name] + c["args"], cwd=d, env=env, stdin=sin, capture_output=True, timeout=3600)
    finally:
        if sin is not subprocess.DEVNULL: sin.close()
    if p.returncode == 2 and b"REFUSE" in p.stderr: raise Refuse(f"the road refused {name}: {p.stderr.decode(errors='replace').strip()[:200]}")
    ans = p.stdout
    for o in c["outs"]:
        f = d / o
        ans += f.read_bytes() if f.is_file() else f"<<out_files: {o} was not written>>\n".encode()
    dump = (d / "screen.dump").read_text(errors="replace").strip().split("\n")[-1] if c["screen"] and (d / "screen.dump").is_file() else ""
    waited = c["screen"] and not st.is_file() and dump.startswith("screen ") and dump != "screen unstable"
    shutil.rmtree(work / f"{name}.{n}", ignore_errors=True)
    return p.returncode, ans, waited
bad, verdicts = 0, {}
try:
    shutil.copytree(pkg, work / "pkg")
    pkg = work / "pkg"
    rows = {r["entry"]: r for r in csv.DictReader(io.StringIO((pkg / "ALL.csv").read_text()))}
    try:
        ents = {e.name: e for e in H.read_package_dir(pkg, ".icn")}
    except (SystemExit, ValueError) as ex:
        refuse(f"the harness cannot read {pkg} as a package: {ex}")
    argl, none = {}, {}
    if (pkg / "ALL.args").is_file():
        for l in (pkg / "ALL.args").read_text().split("\n"):
            if l.strip() and not l.startswith("#"):
                f = l.split("\t"); argl[f[0]] = f[1:]
    if (pkg / "EVENTS-NONE.tsv").is_file():
        for l in (pkg / "EVENTS-NONE.tsv").read_text().split("\n"):
            f = l.split("\t")
            if l and not l.startswith("#") and len(f) > 1 and f[1].strip(): none[f[0]] = f[1]
    pin, cfg = None, []
    for name in dict.fromkeys(names):
        r = rows.get(name) or refuse(f"{name} has no row in {pkg}/ALL.csv")
        if not (pkg / f"{name}.out").is_file(): refuse(f"{name} has no {name}.out")
        outs = [o for o in (r.get("out_files") or "").split(" ") if o]
        screen = "screen.dump" in outs
        events = (pkg / f"{name}.events").is_file()
        if screen and (pkg / f"{name}.display").exists(): refuse(f"{name} names screen.dump and carries {name}.display")
        if not screen and not (pkg / f"{name}.display").exists(): refuse(f"{name} names no screen.dump and has no {name}.display")
        if name in none and events: verdicts[name] = f"RED {name}: named in EVENTS-NONE.tsv and carries {name}.events"; continue
        road = [sys.executable, "-I", str(ROAD)]
        if screen:
            road += ["--out", "screen.dump"]
            if events: road += ["--events", str(pkg / f"{name}.events")]
            if (pkg / f"{name}.cap").is_file(): road += ["--cap", (pkg / f"{name}.cap").read_text().strip()]
        else:
            road += ["--no-screen"]
        if (pkg / f"{name}.depth").is_file(): road += ["--depth", (pkg / f"{name}.depth").read_text().strip()]
        p = []
        if (pkg / f"{name}.pin").is_file():
            if pin is None: pin = sh_value("ipl_pin_shim_path")
            if not pin: refuse("no pin shim (ipl_pin_shim_path)")
            p = ["env", "LD_PRELOAD=" + pin]
        if name not in ents: refuse(f"{name} is a row of ALL.csv the harness does not read as an entry")
        cfg.append({"name": name, "row": r, "outs": outs, "screen": screen, "events": events, "road": road, "pin": p, "entry": ents[name], "args": argl.get(name, [])})
    def pool(cs, k):
        with ThreadPoolExecutor(max_workers=2 * k) as ex:
            futs = {(c["name"], n): ex.submit(one_run, c, n) for c in cs for n in (1, 2)}
            try:
                return {key: f.result() for key, f in futs.items()}
            except Refuse as e:
                for f in futs.values(): f.cancel()
                refuse(str(e))
    def shaky(c, a, b):
        return a[:2] != b[:2] or a[1] != (pkg / f"{c['name']}.out").read_bytes() or b"screen unstable" in a[1] or b"screen unstable" in b[1]
    res = pool(cfg, jobs)
    retried = []
    if jobs > 1:
        for c in cfg:
            if shaky(c, res[(c["name"], 1)], res[(c["name"], 2)]):
                retried.append(c["name"]); res.update(pool([c], 1))
    for c in cfg:
        name, r = c["name"], c["row"]
        a, b = res[(name, 1)], res[(name, 2)]
        if name in retried: print(f"RETRIED-ALONE {name}")
        why = []
        if (a[2] or b[2]) and not c["events"] and name not in none: why.append(f"it waits for an event and carries no {name}.events and no EVENTS-NONE.tsv line")
        if a[:2] != b[:2]: why.append("the two runs differ")
        if a[1] != (pkg / f"{name}.out").read_bytes(): why.append(f"the answer differs from {name}.out")
        if str(a[0]) != (r.get("want_rc") or "0"): why.append(f"status {a[0]}, want_rc {r.get('want_rc')}")
        if why: verdicts[name] = f"RED {name}: " + "; ".join(why)
        elif name in none: verdicts[name] = f"NAMED {name}: EVENTS-NONE.tsv, its still picture stands; twice equal, its {name}.out, status {a[0]}"
        else: verdicts[name] = f"GREEN {name}: twice equal, its {name}.out, status {a[0]}" + ("" if not c["screen"] else ", waits, its script" if a[2] else ", ends by itself")
    for name in dict.fromkeys(names):
        print(verdicts[name]); bad |= verdicts[name].startswith("RED")
finally:
    shutil.rmtree(work, ignore_errors=True)
print("PROVE_IPL_GPROGS " + ("RED" if bad else "OK") + f": {len(dict.fromkeys(names))} entries")
sys.exit(1 if bad else 0)
