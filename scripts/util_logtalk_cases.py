#!/usr/bin/env python3
"""util_logtalk_cases.py -- THE LOGTALK ISO SUITE AS GENERATED UNITS (CIO-22 D; the cio 2026-11-11 on Lon's word in the coo's window 05:55 CST,
verbatim: "Get Logtalk and Roast running in the cycle runner."). The generator CONTRACT.tsv names for corpus/packages/prolog/logtalk_iso
(units=generated, generator=util_logtalk_cases): cases(pkg_dir) yields one case per case of the suite's 400 tests.lgt files, named
group:case exactly as ALL.csv names it, each the program util_logtalk_grade.py has always written for that case (its planner, its shim,
its database split, its sequenced prefixes, its exclusions: nothing is planned a second way here) and the ONE verdict line that program
prints when the case behaves as its own expectation says:
    @V succ         the case's goal succeeded, and it is expected to
    @V fail         the goal failed, and it is expected to
    @V ballmatch    the goal threw a ball that unifies with the one the case expects
NO ORACLE RUN cuts a ref: the ref is the suite's own expectation (ISO/IEC 13211-1's, as the Logtalk authors wrote it). A case the planner
cannot express, or one the suite's own tables put outside, is yielded with its reason and the builder names it in ALL.omit. Each case runs
with cwd its test file's own folder, which the grader copies to scratch (a case opens files beside its source and writes files there).
HOW THE PLANS ARE TAKEN: grade() of util_logtalk_grade.py is called with its one-case runner replaced by a recorder, so every decision it makes
before a run (parse, exclusions, sequencing, the outside set) is made by its own code; no program is run."""
import contextlib, io, os, sys

_HERE = os.path.dirname(os.path.abspath(__file__))
# The shim is ONE file of the package, lgtunit_shim.pl, included by every case: the grader copies a file a program names from the package
# folder to beside the staged program (_copy_companions), and scrip resolves an include beside the including file. MEASURED: with the shim's
# text in every case the container was 76.9 MB, 72.6 MB of it 3,524 copies of the shim.
SHIM_INCLUDE = ":- include('lgtunit_shim.pl')."


def cases(pkg_dir):
    if _HERE not in sys.path:
        sys.path.insert(0, _HERE)
    import util_logtalk_grade as g
    pkg_dir = os.path.abspath(str(pkg_dir))
    seen = {}

    def record(plan, db, shim_src, scrip, mode, workroot, srcdir, timeout=10, loaded=(), sw=(), key=None):
        seen[id(plan)] = (db, shim_src, loaded, srcdir)
        return ("succ", "")

    real = g.run_one
    g.run_one = record
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            res, errs = g.grade(pkg_dir, "/bin/true", ["m3"], jobs=1)
    finally:
        g.run_one = real
    if res is None:
        raise SystemExit("REFUSE(2) [util_logtalk_cases]: util_logtalk_grade.py refuses the suite: " + "; ".join("%s: %s" % (k, w) for k, w in errs[:5]))
    work, _results, info = res
    live = {}
    for i, (fc, p) in enumerate(work):
        name = info["progkey"][i]
        why = p.skip_reason or p.outside_reason
        if why:
            live[name] = {"reason": str(why)}
        elif id(p) not in seen:
            live[name] = {"reason": "the planner made no program for it"}
        else:
            db, shim_src, loaded, srcdir = seen[id(p)]
            want = p.want if p.want in ("succ", "fail") else "ballmatch"
            live[name] = {"program": g.program_text(p, db, SHIM_INCLUDE, loaded), "ref": "@V " + want, "cwd": os.path.relpath(srcdir, pkg_dir)}
    # THE TABLE IS THE DENOMINATOR (CIO-19): one dict for every entry of ALL.csv. A name the suite carries twice is two rows, NAME#1 and NAME#2
    # in the table's order (the planner's own key for a name the graded population holds twice). Where the planner holds the name ONCE, the
    # other row is the branch a :- if(...) guard decides false on this system (EXCLUDED_CASES.tsv names it WINDOWS_ONLY or EXCLUSIVE_BRANCH):
    # the live case takes NAME#1 and NAME#2 carries that reason. A table entry the planner took out before planning (a row of the suite's own
    # exclusion tables) is yielded with that table's class as its reason.
    declared = {}
    xp = os.path.join(pkg_dir, "EXCLUDED_CASES.tsv")
    if os.path.isfile(xp):
        with open(xp, encoding="utf-8") as f:
            for ln in f:
                c = ln.rstrip("\n").split("\t")
                if ln.strip() and not ln.startswith("#") and len(c) >= 2:
                    declared[c[0].strip()] = c[1].strip()
    import csv
    with open(os.path.join(pkg_dir, "ALL.csv"), newline="", encoding="utf-8") as f:
        table = [(r.get("entry") or "").strip() for r in csv.DictReader(f)]
    used = set()
    for entry in table:
        base, _, k = entry.partition("#")
        if entry in live:
            used.add(entry)
            yield dict(live[entry], name=entry)
        elif k == "1" and base in live:
            used.add(base)
            yield dict(live[base], name=entry)
        elif k and base in live:
            yield {"name": entry, "reason": "the branch of %s a :- if(...) guard decides false on this system (EXCLUDED_CASES.tsv: %s)" % (base, declared.get(base, "no row"))}
        else:
            yield {"name": entry, "reason": "taken out before planning by the suite's own table (EXCLUDED_CASES.tsv: %s)" % declared.get(base, "no row")}
    for name in sorted(set(live) - used):
        yield dict(live[name], name=name)   # a case the table lacks: the builder refuses on it, naming it
