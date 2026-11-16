# ipl_graphics_stage.py -- THE STAGING OF A GRAPHICS ENTRY OF THE IPL PACKAGES (ipl_gprogs, ipl_gpacks, ipl_gprocs), one copy, imported by the one
# prover (prove_ipl_gprogs_entry.py) and by the launcher a person types (icon_demo.py), so a program green on the screen road starts the same way on a
# person's display (the cto's ruling 2026-11-16 15:2x CST, row icon-graphics-one-launcher-runs-any-graded-graphics-entry-on-the-callers-display;
# officer_02 moved these lines out of the prover unchanged). The program and what its row says it needs are staged by the harness's own stage_entry
# (corpus_suite_harness.py, the road the cycle grades): the program, the companions its text names, its argv and stdin files, NAME.fixtures/ or its
# folder, the screen road's side files. What the harness reads beside a package and not through stage_entry is read here: ALL.args (a program's
# arguments, one line NAME<TAB>arg...), NAME.in (its stdin, beside its source), and the graphics oracle's build (icont -s, IPATH its lib, LPATH the
# ipl includes, HOME the run's own folder; a pack's modules translated with -c first, a file another $includes never alone, as prove_gpacks_entry.sh
# builds a pack). An importer puts this folder first on sys.path.
import os, re, subprocess
from pathlib import Path
HERE = Path(__file__).resolve().parent
import corpus_suite_harness as H
PACKAGES = ("ipl_gprogs", "ipl_gpacks", "ipl_gprocs")
class Refuse(Exception): pass
def sh_value(fn):
    q = subprocess.run(["bash", "-c", f'. "{HERE}/lib_oracle_flags.sh" >/dev/null 2>&1; . "{HERE}/lib_icon_ipl_isolation.sh" >/dev/null 2>&1; {fn}'], capture_output=True, text=True)
    return q.stdout.strip() if q.returncode == 0 else ""
def oracle_dir():
    return Path(sh_value('printf %s "$GRAPHICS_ICON_ORACLE_DIR"') or "/home/resources/icon-master-x")
def corpus():
    return Path(os.environ.get("S4E_CORPUS") or "/home/corpus")
def read_args(pkg):
    argl = {}
    if (Path(pkg) / "ALL.args").is_file():
        for l in (Path(pkg) / "ALL.args").read_text().split("\n"):
            if l.strip() and not l.startswith("#"):
                f = l.split("\t"); argl[f[0]] = f[1:]
    return argl
def source_of(pkg, row):
    return Path(pkg) / (row.get("path") or (row["entry"] + ".icn"))
def stdin_of(pkg, row):
    s = source_of(pkg, row).with_suffix(".in")
    return s if s.is_file() else None
def stage(entry, d, pkg):
    Path(d).mkdir(parents=True, exist_ok=True)
    try:
        cand, _ = H.stage_entry(entry, str(d), ".icn", str(pkg))
    except SystemExit:
        raise Refuse(f"the harness refused to stage {entry.name}")
    return cand.parent, cand.name
def oracle_env(M, ipl, d):
    return {"PATH": "/usr/bin:/bin", "LC_ALL": "C", "IPATH": f"{M}/lib", "LPATH": f"{ipl}/gincl {ipl}/incl", "HOME": str(d)}
def included(d):
    inc = set()
    for f in Path(d).glob("*.icn"):
        inc |= set(re.findall(r'(?m)^[ \t]*\$include[ \t]*"([^"]*)"', f.read_text(errors="replace")))
    return inc
def oracle_build(M, name, src, d, env, modules=False):
    if modules:
        inc = included(d)
        for m in sorted(Path(d).glob("*.icn")):
            if m.name == src or m.name in inc: continue
            b = subprocess.run([str(M / "bin/icont"), "-s", "-c", m.name], cwd=d, env=env, capture_output=True, timeout=300)
            if b.returncode: raise Refuse(f"{name}: the module {m.name} does not translate: {b.stderr.decode(errors='replace').strip()[:200]}")
    b = subprocess.run([str(M / "bin/icont"), "-s", "-o", Path(name).name, src], cwd=d, env=env, capture_output=True, timeout=300)
    if b.returncode: raise Refuse(f"{name} does not build: {b.stderr.decode(errors='replace').strip()[:200]}")
    return [str(M / "bin/iconx"), Path(name).name]
