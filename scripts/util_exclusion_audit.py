#!/usr/bin/env python3
"""util_exclusion_audit.py -- EVERY EXCLUSION A PACKAGE DECLARES IS DECIDED AGAIN BY THE BUILDER'S OWN ORACLE CUT, WITH NO DECLARATION IN FORCE
(the cio 2026-11-11, CIO-60 and CIO-33 (d); Lon 2026-11-10 11:4x CST, verbatim: "Let's not exclude anything by decree. I release all excludes I
sanctioned. All must be looked at again with fresh eyes."). The builder (util_build_package_suite.py) honours a declared exclusion without
measuring it and has its own measured reasons for leaving a program out. So a package built on a COPY whose declaration tables hold no data row is
the audit: what the builder then admits the oracle answers; what it still leaves out carries a measured reason.

usage: util_exclusion_audit.py run --package DIR --lang LANG --work SCRATCH [--out FILE]
       util_exclusion_audit.py check --package DIR [--strict] [--out FILE]
       util_exclusion_audit.py keep --package DIR --name NAME --why "THE MEASUREMENT" [--out FILE]
       util_exclusion_audit.py --probe
run    SCRATCH must be under /tmp/s4e and must not exist. DIR is copied to SCRATCH/<its name>; in the copy EXCLUDED.tsv, EXCLUDED_CASES.tsv,
       UNGRADABLE.tsv and every EXCLUDED.*.tsv keep their comment lines alone; the builder runs on the copy with --twice (and --src-ext when the
       index's path column names another extension than LANG's), through util_batch.sh, its output kept as SCRATCH/audit.log. Then one line a
       data row of the ORIGINAL tables goes to FILE (default /home/resources/progress/EXCLUSION-AUDIT.tsv), seven cells: date and time CST, the
       package's path from the corpus root, the name, the old class, the verdict, the evidence, the package's corpus commit. The verdict:
         REVIEW      the copy's index holds the name as an entry the copy's ALL.omit does not name (evidence: admitted by the builder, and the
                     declared class). THIS IS NOT "THE ORACLE ANSWERS IT": the builder admits any program with a non-empty answer. MEASURED
                     2026-11-11 by the cfo on trealla_tests and xsb_tests, the oracle run by hand on each: of the 12 names this verdict (then
                     called ANSWERED) gave, two stop on an oracle ERROR in mid-run with output before it, two are implementation accidents
                     an officer declared, one varies between runs (two equal runs are a sample), seven need threads. So the tool never says
                     delete. A REVIEW row is RELEASED (its line deleted from the table) only when its declared class is NO_ORACLE_ANSWER and
                     the oracle, run by hand twice through its accessor, ends rc 0 with an empty standard error and equal output; every
                     other REVIEW row is KEPT by the keep verb with the measurement, and a class that is an officer's reading of an accident,
                     a variation or a capability is released only by the language's designer.
         NO-ANSWER   the copy's ALL.omit names it (evidence: that line's reason)
         NOT-A-TEST  the package's CONTAINERS.tsv names it (evidence: that row's kind)
         UNDECIDED   otherwise (evidence: the audit.log line that names it, or: not named by the build)
       rc 0; rc 1 when the corpus checkout is not clean after; rc 2 refused (the builder refused the copy: its last lines are printed; or THE
       CONTROL: an entry the package grades today is no entry of the copy, so the builder was not invoked as the package is built and every name
       would read NO-ANSWER: no line is written).
check  rc 0 when every data row of DIR's declaration tables has a line in FILE for that package and name at DIR's corpus commit; rc 1 naming the
       first ten that have none. --strict: rc 0 when every row the tables hold today has a line, at any commit, whose latest verdict is NO-ANSWER
       or REVIEW-KEPT (the audit has been acted on: every REVIEW row is released or kept with its measurement, the NOT-A-TEST rows are gone
       and none is UNDECIDED).
keep   writes one REVIEW-KEPT line for NAME (a data row of DIR's tables whose latest line reads REVIEW or REVIEW-KEPT), its evidence the --why
       text, which must say what was measured (40 characters at least). rc 0; rc 2 refused (no such row, its latest verdict is another, a
       short --why).
--probe a planted package of three SNOBOL4 programs (one the oracle answers, one that prints nothing, one a planted CONTAINERS.tsv names) with a
       planted EXCLUDED.tsv naming all three reads AUDIT_PROBE answered=1 no_answer=1 not_a_test=1, rc 0; rc 1 with the lines read otherwise;
       rc 2 when the builder or the oracle cannot run here. It writes only under its own scratch folder."""
import csv, datetime, glob, os, re, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DEFAULT_OUT = "/home/resources/progress/EXCLUSION-AUDIT.tsv"
LANG_EXT = {"snobol4": ".sno", "snocone": ".sc", "rebus": ".reb", "icon": ".icn", "prolog": ".pl", "pascal": ".pas", "raku": ".raku"}
CLASS = re.compile(r"^[A-Z][A-Z0-9_-]+$")


def refuse(msg):
    print(f"REFUSE(2) [util_exclusion_audit]: {msg}")
    sys.exit(2)


def tables_of(d):
    return sorted(p for p in glob.glob(os.path.join(d, "EXCLUDED*.tsv")) + glob.glob(os.path.join(d, "UNGRADABLE.tsv")) if os.path.isfile(p))


def data_rows(path):
    """(name, class) for every data row: column 1 the name and column 2 the class; in a table whose second cell is no class word (EXCLUDED_CASES.tsv
    of a per-case package: file, case, class) the name is the first two cells joined by a tab and the class the third. A header line is no row."""
    out = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for ln in f:
            if not ln.strip() or ln.startswith("#"):
                continue
            c = ln.rstrip("\n").split("\t")
            if c[0].strip() in ("name", "file", "program", "entry", "case"):
                continue
            if len(c) >= 3 and not CLASS.match(c[1].strip()) and CLASS.match(c[2].strip()):
                out.append((c[0].strip() + "\t" + c[1].strip(), c[2].strip()))
            else:
                out.append((c[0].strip(), c[1].strip() if len(c) > 1 else ""))
    return out


def blank(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        keep = [ln for ln in f if ln.startswith("#")]
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(keep)


def corpus_of(d):
    r = subprocess.run(["git", "-C", d, "rev-parse", "--show-toplevel"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def pkg_commit(d):
    top = corpus_of(d)
    if not top:
        return "-"
    r = subprocess.run(["git", "-C", top, "log", "-1", "--format=%h", "--abbrev=9", "--", os.path.relpath(d, top)], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    return r.stdout.strip() or "-"


def src_ext_of(d, lang):
    p = os.path.join(d, "ALL.csv")
    if not os.path.isfile(p):
        return None
    with open(p, newline="", encoding="utf-8", errors="replace") as f:
        rows = list(csv.DictReader(f))
    if not rows or "path" not in rows[0]:
        return None
    cnt = {}
    for r in rows:
        e = os.path.splitext(r.get("path") or "")[1]
        if e:
            cnt[e] = cnt.get(e, 0) + 1
    if not cnt:
        return None
    e = max(cnt, key=cnt.get)
    return e if e != LANG_EXT.get(lang) else None


def shipped_entries(d):
    """The entries a package grades today: the entry cells of its index that its ALL.omit does not name."""
    om = set()
    op = os.path.join(d, "ALL.omit")
    if os.path.isfile(op):
        with open(op, encoding="utf-8", errors="replace") as f:
            om = {ln.split(": ", 1)[0].strip() for ln in f if ": " in ln and not ln.startswith("#")}
    out = []
    with open(os.path.join(d, "ALL.csv"), newline="", encoding="utf-8", errors="replace") as f:
        for row in csv.DictReader(f):
            e = (row.get("entry") or "").strip()
            if e and e not in om:
                out.append(e)
    return out


def keys_of(name):
    """The spellings a table's name may take in the index: as written, without its extension, and its bare file name without its extension."""
    n = name.split("\t")[0]
    stem = os.path.splitext(n)[0]
    return {name, n, stem, os.path.basename(stem)}


def audit(pkg, lang, work, out, batch=True):
    pkg = os.path.abspath(pkg)
    if not os.path.isdir(pkg) or not os.path.isfile(os.path.join(pkg, "ALL.csv")):
        refuse(f"{pkg} is no package (no ALL.csv)")
    work = os.path.abspath(work)
    if not work.startswith("/tmp/s4e/") or os.path.exists(work):
        refuse(f"--work {work} must be under /tmp/s4e and must not exist")
    rows = []
    for t in tables_of(pkg):
        rows += [(n, c, os.path.basename(t)) for n, c in data_rows(t)]
    shipped = shipped_entries(pkg)
    os.makedirs(work)
    copy = os.path.join(work, os.path.basename(pkg))
    shutil.copytree(pkg, copy, symlinks=True)
    for t in tables_of(copy):
        blank(t)
    cmd = [sys.executable, os.path.join(HERE, "util_build_package_suite.py"), copy, "--lang", lang, "--twice"]
    sx = src_ext_of(pkg, lang)
    if sx:
        cmd += ["--src-ext", sx]
    if batch:
        cmd = ["bash", os.path.join(HERE, "util_batch.sh")] + cmd
    r = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace", env=dict(os.environ, S4E_HOME=ROOT))
    log = os.path.join(work, "audit.log")
    with open(log, "w", encoding="utf-8") as f:
        f.write(r.stdout)
    if r.returncode != 0:
        print("\n".join(r.stdout.strip().split("\n")[-6:]))
        refuse(f"the builder refused the copy of {pkg} with its declaration tables emptied (rc {r.returncode}); its output is {log}")
    entries, omit, containers = set(), {}, {}
    with open(os.path.join(copy, "ALL.csv"), newline="", encoding="utf-8", errors="replace") as f:
        for row in csv.DictReader(f):
            entries |= {(row.get("entry") or "").strip(), (row.get("path") or "").strip(), os.path.splitext((row.get("path") or "").strip())[0]}
    op = os.path.join(copy, "ALL.omit")
    if os.path.isfile(op):
        with open(op, encoding="utf-8", errors="replace") as f:
            for ln in f:
                if ": " in ln and not ln.startswith("#"):
                    k, _, v = ln.rstrip("\n").partition(": ")
                    omit[k.strip()] = v.strip()
    # THE CONTROL ARM (the cfo's measurement on gnu_prolog, 2026-11-11): the copy's build is the instrument, and it measures only when it rebuilds
    # the package AS SHIPPED. A package the plain builder does not build (libraries graded through per-driver arms, another oracle, a generator)
    # comes out with its own shipped entries omitted for the builder's reason, and then EVERY name reads NO-ANSWER, declared or not. So: every
    # entry the package grades today must be an entry of the copy that the copy's ALL.omit does not name, or the run refuses and writes no line.
    copy_entries = set(shipped_entries(copy))
    lost = [e for e in shipped if e not in copy_entries]
    if lost:
        why = omit.get(lost[0], "not in the copy's index")
        refuse(f"the builder did not rebuild {pkg} as shipped: {len(lost)} of its {len(shipped)} graded entries are not entries of the copy (first: {lost[0]}: {why[:120]}); the audit measures nothing here and writes no line; its output is {log}")
    cp = os.path.join(pkg, "CONTAINERS.tsv")
    if os.path.isfile(cp):
        for n, c in data_rows(cp):
            containers[n] = c
    loglines = r.stdout.split("\n")
    top = corpus_of(pkg)
    rel = os.path.relpath(pkg, top) if top else pkg
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M CST")
    commit = pkg_commit(pkg)
    tally, lines = {}, []
    for name, cls, table in rows:
        ks = keys_of(name)
        hit_omit = next((k for k in ks if k in omit), None)
        hit_cont = next((k for k in ks if k in containers), None)
        if hit_cont is not None:
            v, ev = "NOT-A-TEST", containers[hit_cont]
        elif hit_omit is not None:
            v, ev = "NO-ANSWER", omit[hit_omit]
        elif ks & entries:
            v, ev = "REVIEW", "admitted by the builder (a non-empty answer, not a clean one); declared class %s" % (cls or "-")
        else:
            base = os.path.basename(os.path.splitext(name.split("\t")[0])[0])
            ln = next((l for l in loglines if re.search(r"(^|[\s/\]:])" + re.escape(base) + r"([\s:.,]|$)", l)), None)
            v, ev = "UNDECIDED", (ln.strip()[:200] if ln else "not named by the build")
        tally[v] = tally.get(v, 0) + 1
        lines.append("\t".join([stamp, rel, name.replace("\t", " "), cls or "-", v, ev.replace("\t", " ")[:300], commit]))
    with open(out, "a", encoding="utf-8") as f:
        for ln in lines:
            f.write(ln + "\n")
    print("EXCLUSION_AUDIT package=%s declared=%d %s log=%s" % (rel, len(rows), " ".join(f"{k.lower().replace('-', '_')}={tally[k]}" for k in sorted(tally)), log))
    if top:
        s = subprocess.run(["git", "-C", top, "status", "--short", "--", rel], stdout=subprocess.PIPE, text=True)
        if s.stdout.strip():
            print(f"RED: the corpus checkout is not clean after the audit: {s.stdout.strip().splitlines()[0]}")
            return 1, tally
    return 0, tally


def check_strict(pkg, out):
    """check --strict: THE AUDIT HAS BEEN ACTED ON. rc 0 when every data row the package's declaration tables hold TODAY has a line in the audit
    table, at any commit, and the LATEST line for that name reads NO-ANSWER or REVIEW-KEPT: what was released and what is no test (NOT-A-TEST)
    has left the tables, a REVIEW row that stays carries its measurement, and nothing stands UNDECIDED. rc 1 naming the first ten rows that are not audited or whose latest verdict is another."""
    pkg = os.path.abspath(pkg)
    top = corpus_of(pkg)
    rel = os.path.relpath(pkg, top) if top else pkg
    latest = {}
    if os.path.isfile(out):
        with open(out, encoding="utf-8", errors="replace") as f:
            for ln in f:
                c = ln.rstrip("\n").split("\t")
                if len(c) >= 7 and c[1] == rel:
                    latest[c[2]] = c[4]
    want = []
    for t in tables_of(pkg):
        want += [n.replace("\t", " ") for n, _ in data_rows(t)]
    bad = [(n, latest.get(n, "NOT AUDITED")) for n in want if latest.get(n) not in ("NO-ANSWER", "REVIEW-KEPT")]
    print("EXCLUSION_AUDIT_STRICT package=%s declared=%d standing_on_the_oracles_no_answer=%d kept_after_review=%d" % (rel, len(want), sum(1 for n in want if latest.get(n) == "NO-ANSWER"), sum(1 for n in want if latest.get(n) == "REVIEW-KEPT")))
    for n, v in bad[:10]:
        print(f"  {v}: {n} is still declared")
    return 1 if bad else 0


def keep(pkg, name, why, out):
    """keep: one REVIEW-KEPT line for a row the audit read REVIEW, with the measurement that keeps it."""
    pkg = os.path.abspath(pkg)
    top = corpus_of(pkg)
    rel = os.path.relpath(pkg, top) if top else pkg
    if len(why.strip()) < 40: refuse("--why must say what was measured (the oracle's exit, its error line, the class and who releases it): 40 characters at least")
    rows = {n.replace("\t", " "): c for t in tables_of(pkg) for n, c in data_rows(t)}
    if name not in rows: refuse(f"{name!r} is no data row of {rel}'s declaration tables")
    latest = None
    if os.path.isfile(out):
        with open(out, encoding="utf-8", errors="replace") as f:
            for ln in f:
                c = ln.rstrip("\n").split("\t")
                if len(c) >= 7 and c[1] == rel and c[2] == name: latest = c[4]
    if latest not in ("REVIEW", "REVIEW-KEPT", "ANSWERED"): refuse(f"{name!r}: its latest verdict is {latest or 'NOT AUDITED'}; keep is for a row the audit read REVIEW")
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M CST")
    who = os.environ.get("S4E_SEAT") or "-"
    with open(out, "a", encoding="utf-8") as f:
        f.write("\t".join([stamp, rel, name, rows[name] or "-", "REVIEW-KEPT", (who + ": " + why.strip()).replace("\t", " ").replace("\n", " ")[:600], pkg_commit(pkg)]) + "\n")
    print(f"EXCLUSION_AUDIT_KEEP package={rel} name={name} by={who}")
    return 0


def check(pkg, out):
    pkg = os.path.abspath(pkg)
    top = corpus_of(pkg)
    rel = os.path.relpath(pkg, top) if top else pkg
    commit = pkg_commit(pkg)
    have = set()
    if os.path.isfile(out):
        with open(out, encoding="utf-8", errors="replace") as f:
            for ln in f:
                c = ln.rstrip("\n").split("\t")
                if len(c) >= 7 and c[1] == rel and c[6] == commit:
                    have.add(c[2])
    want = []
    for t in tables_of(pkg):
        want += [n.replace("\t", " ") for n, _ in data_rows(t)]
    missing = [n for n in want if n not in have]
    print("EXCLUSION_AUDIT_CHECK package=%s commit=%s declared=%d audited=%d" % (rel, commit, len(want), len(want) - len(missing)))
    for n in missing[:10]:
        print(f"  NOT AUDITED {n}")
    return 1 if missing else 0


def probe():
    seat = os.environ.get("S4E_SEAT") or "probe"
    base = f"/tmp/s4e/{seat}"
    os.makedirs(base, exist_ok=True)
    t = tempfile.mkdtemp(prefix="exclusion_audit_probe_", dir=base)
    try:
        pkg = os.path.join(t, "probe_pkg")
        os.makedirs(pkg)

        def put(n, text):
            with open(os.path.join(pkg, n), "w", encoding="utf-8") as f:
                f.write(text)

        put("answers.sno", "        OUTPUT = 'answered'\nEND\n")
        put("silent.sno", "        X = 1\nEND\n")
        put("part.sno", "        OUTPUT = 'a part'\nEND\n")
        put("keeper.sno", "        OUTPUT = 'kept'\nEND\n")
        put("EXCLUDED.tsv", "# planted: the probe's three declarations\nanswers.sno\tPROBE_CLASS\tplanted\nsilent.sno\tPROBE_CLASS\tplanted\npart.sno\tPROBE_CLASS\tplanted\n")
        put("CONTAINERS.tsv", "# planted\npart.sno\tINCLUDED_BY\tkeeper.sno -- planted for the probe\n")
        b = subprocess.run([sys.executable, os.path.join(HERE, "util_build_package_suite.py"), pkg, "--lang", "snobol4"], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, text=True, errors="replace", env=dict(os.environ, S4E_HOME=ROOT))
        if b.returncode != 0 or not os.path.isfile(os.path.join(pkg, "ALL.csv")):
            print("\n".join(b.stdout.strip().split("\n")[-4:]))
            refuse("the builder cannot build the planted package here (no oracle, or it refuses)")
        out = os.path.join(t, "audit.tsv")
        rc, tally = audit(pkg, "snobol4", os.path.join(t, "work"), out, batch=False)
        got = "AUDIT_PROBE review=%d no_answer=%d not_a_test=%d" % (tally.get("REVIEW", 0), tally.get("NO-ANSWER", 0), tally.get("NOT-A-TEST", 0))
        if got != "AUDIT_PROBE review=1 no_answer=1 not_a_test=1" or tally.get("UNDECIDED") or tally.get("ANSWERED"):
            print(got)
            with open(out, encoding="utf-8") as f:
                print(f.read().rstrip())
            return 1
        with open(os.path.join(pkg, "CONTAINERS.tsv"), "w", encoding="utf-8") as f: f.write("# planted\n")
        with open(os.path.join(pkg, "EXCLUDED.tsv"), "w", encoding="utf-8") as f: f.write("# planted: two rows stay\nanswers.sno\tPROBE_CLASS\tplanted\nsilent.sno\tPROBE_CLASS\tplanted\n")
        import io, contextlib
        with contextlib.redirect_stdout(io.StringIO()):
            before = check_strict(pkg, out)
            keep(pkg, "answers.sno", "planted measurement: the oracle ends rc 0 and the class is the designer's to release", out)
            after = check_strict(pkg, out)
        print(got + " strict_with_a_review_row=%s strict_after_keep=%s" % ("red" if before == 1 else "green", "green" if after == 0 else "red"))
        return 0 if before == 1 and after == 0 else 1
    finally:
        shutil.rmtree(t, ignore_errors=True)


def main(argv):
    if argv == ["--probe"]:
        return probe()
    if not argv or argv[0] not in ("run", "check", "keep"):
        refuse("usage: util_exclusion_audit.py run --package DIR --lang LANG --work SCRATCH [--out FILE] | check --package DIR [--out FILE] | --probe")
    opt, i = {}, 1
    strict = "--strict" in argv
    argv = [a for a in argv if a != "--strict"]
    while i < len(argv):
        if argv[i] in ("--package", "--lang", "--work", "--out", "--name", "--why") and i + 1 < len(argv):
            opt[argv[i][2:]] = argv[i + 1]
            i += 2
        else:
            refuse(f"read {argv[i]!r}; see the usage")
    out = opt.get("out", DEFAULT_OUT)
    if argv[0] == "check":
        if "package" not in opt:
            refuse("check needs --package DIR")
        return check_strict(opt["package"], out) if strict else check(opt["package"], out)
    if argv[0] == "keep":
        for k in ("package", "name", "why"):
            if k not in opt:
                refuse(f"keep needs --{k}")
        return keep(opt["package"], opt["name"], opt["why"], out)
    for k in ("package", "lang", "work"):
        if k not in opt:
            refuse(f"run needs --{k}")
    if opt["lang"] not in LANG_EXT:
        refuse(f"--lang is one of {', '.join(sorted(LANG_EXT))}")
    return audit(opt["package"], opt["lang"], opt["work"], out)[0]


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
