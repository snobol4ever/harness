#!/usr/bin/env python3
# util_container_check.py -- THE ONE CONTAINER, MEASURED (DESIGN-PLAN one-container, the grader 2026-11-17; Lon, in the grader's window, verbatim:
# "We want a consistent test-suite system where the stdin, stdout, exit-value, compile args, run-time args, needed environment variables, and a
# list of needed input files and locations, list of output files and locations, etc. We want one system where the tracking containers are all
# identical and run by ONE system."; skill suites-and-grading section 10). For every master, pkg and small row of SUITE_RUNNERS.tsv it reads the
# suite's folder and says whether it is THE ONE CONTAINER: the files form (ALL.csv with a path column), every run column of the schema in ALL.csv,
# and no run fact spelled anywhere else (a whole-suite ALL.args, ALL.in, ALL.rc, ALL.env, ALL.outfiles ..., a per-entry NAME.args, NAME.env,
# NAME.outfiles, NAME.rc ..., the old container ALL.<ext>/ALL.ref). Read only.
#   util_container_check.py [--list] [--suite KEY] [--min N] [--check]
#     prints one line a suite with --list (key form ok|NONCONFORMING and what is off), then the totals line
#     CONTAINERS suites=N conforming=C forms=... ; --min N rc 1 when fewer than N conform; --check rc 1 when any does not; rc 2 a table unread.
import csv, os, sys
from pathlib import Path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import harness_paths
H, C = Path(harness_paths.harness()), Path(harness_paths.corpus())
RUN_COLS = ("entry", "path", "dialect", "compile_args", "run_args", "env", "stdin", "in_files", "out_files", "want_rc", "stderr", "compare",
            "heap_kb", "stack_kb", "timeout_s")
OLD_ALL = ("ALL.args", "ALL.argv", "ALL.in", "ALL.stdin", "ALL.rc", "ALL.env", "ALL.outfiles", "ALL.dialect", "ALL.timeout.tsv", "ALL.ref")
OLD_SIDE = (".args", ".env", ".outfiles", ".rc", ".stdin", ".dat", ".inp", ".std", ".cmp", ".ref")
EXT = {"snobol4": "sno", "icon": "icn", "prolog": "pl", "pascal": "pas", "raku": "raku", "rebus": "reb", "snocone": "sc", "scriptix": "md"}
def refuse(m): print("REFUSE(2) [util_container_check]: " + m); sys.exit(2)
def suite_dir(kind, lang, table):
    if table.startswith("corpus/"): return C / table[7:]
    if kind == "master": return C / "tests" / lang
    return None
def judge(key, kind, lang, runner, table):
    d = suite_dir(kind, lang, table)
    if kind == "small": return "script", [f"its own runner {runner}"]
    if d is None or not d.is_dir(): return "none", ["no folder"]
    off, names = [], set(os.listdir(d))
    cols = []
    if (d / "ALL.csv").is_file():
        try:
            with open(d / "ALL.csv", newline="", encoding="utf-8", errors="replace") as f: cols = next(csv.reader(f), [])
        except OSError as e: refuse(f"{d}/ALL.csv: {e}")
    if "path" in cols: form = "files"
    elif "MULTI-LINERS.md" in names or any(n.startswith("ONE-LINERS.") for n in names): form = "groups"
    elif f"ALL.{EXT.get(lang, '')}" in names: form = "container"
    else: form = "table-only" if cols else "none"
    if form != "files": off.append(f"form {form}")
    miss = [c for c in RUN_COLS if c not in cols]
    if miss: off.append("columns missing " + ",".join(miss))
    old = sorted(n for n in names if n in OLD_ALL or n == f"ALL.{EXT.get(lang, '')}")
    if old: off.append("whole-suite files " + ",".join(old))
    side = {}
    for p in d.rglob("*"):
        if p.is_file() and not p.name.startswith("ALL.") and p.suffix in OLD_SIDE: side[p.suffix] = side.get(p.suffix, 0) + 1
    if side: off.append("per-entry files " + ",".join(f"{s}:{n}" for s, n in sorted(side.items())))
    return form, off
def main(a):
    rows = [l.rstrip("\n").split("\t") for l in open(H / "scripts/SUITE_RUNNERS.tsv", encoding="utf-8") if not l.startswith("#")]
    want = a[a.index("--suite") + 1] if "--suite" in a else None
    n = ok = 0; forms = {}
    for r in rows:
        if len(r) < 5 or r[1] not in ("master", "pkg", "small"): continue
        if want and r[0] != want: continue
        form, off = judge(*r[:5]); n += 1; forms[form] = forms.get(form, 0) + 1
        if not off: ok += 1
        if "--list" in a or want: print(f"{r[0]}\t{form}\t{'ok' if not off else 'NONCONFORMING ' + '; '.join(off)}")
    print(f"CONTAINERS suites={n} conforming={ok} forms=" + ",".join(f"{k}:{v}" for k, v in sorted(forms.items())))
    if "--min" in a and ok < int(a[a.index("--min") + 1]): return 1
    if "--check" in a and ok < n: return 1
    return 0
sys.exit(main(sys.argv[1:]))
