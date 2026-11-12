#!/usr/bin/env python3
"""util_cycle_inventory.py -- THE TEST CYCLE'S INVENTORY: what every suite row needs before the one launch grades all of it (the cio 2026-11-10, on
Lon's word in the cio's window, verbatim: "It's time to complete the test-suite cycle runner. Inventory what needs finishing and fix. As an example,
many suites do not have their "container", i.e. all the TSV/CSV files for the unified test harness to run.").

usage: util_cycle_inventory.py [--root S4E_HOME] [--log CYCLE.log] [--only KEY[,KEY...]] [--owed KEY] [--check] [--check-lap]

One line per row of SUITE_RUNNERS.tsv that is not a port row:
  SRCP    the container files present beside the table: S ALL.<ext>, R ALL.ref, C ALL.csv, P PARTITION.tsv (a dot for an absent one); 2 in the S place: format 2 (MULTI.md or ONE.<ext>)
  csv     rows of ALL.csv (absorbed entries and carried settings rows)
  cont    entries the container holds (corpus_suite_harness.py list)
  part    entries the cycle's cells name (PARTITION.tsv, core and chunk:NN)
  gone    cell entries the container lacks: the harness refuses the whole cell rc 2
  nocell  container entries no cell names: the cycle never grades them
  owed    programs the builder left out by its OWN measurement (ALL.omit) that no package table (EXCLUDED.tsv, CONTAINERS.tsv) declares out
          of the denominator: published, shipped, and graded by nothing since the package runners were deleted (harness cc2783502)
  cells   the cycle cells of the row; lap: the last finished lap's cells by exit code (rc:n); held: cells named in CYCLE.skip
VERDICT words: BY-ITS-RUNNER (kind small: one cell a lap by the row's runner, COO-516; structurally not ok until it is a package), NOT-IN-CYCLE (kind none, or a small row with no runner), NO-CONTAINER, NO-PARTITION, PARTITION-NAMES-n-ABSENT,
n-ENTRIES-IN-NO-CELL, OWED-n, and from the lap n-CELLS-REFUSE and CELL-DIED-OR-TIMED-OUT; HELD-n-CELLS is Lon's hold and is not a defect, and a row
whose every cell is held is printed with its words and counted by neither check until the hold is lifted.
--owed KEY prints that row's owed programs with the builder's reason. --check: rc 1 when a selected row carries a structural word (everything but
the lap's); --check-lap: the lap's words count too. rc 2 refused. It reads; it writes nothing and runs no program."""
import collections, csv, os, re, subprocess, sys

EXT = {"snobol4": "sno", "icon": "icn", "prolog": "pl", "pascal": "pas", "raku": "raku", "rebus": "reb", "snocone": "sc"}
DECLARED = re.compile(r"EXCLUDED\.tsv|CONTAINERS\.tsv|graded through|through its driver|\.ref beside|not a case file")
FMT = "%-18s %-6s %-4s %6s %6s %6s %5s %6s %5s %5s  %-14s %s"


def opt(a, name):
    return a[a.index(name) + 1] if name in a and a.index(name) + 1 < len(a) else None


def table_names(d, fn):
    s = set()
    p = os.path.join(d, fn)
    if os.path.isfile(p):
        for x in open(p, encoding="utf-8", errors="replace"):
            if x.startswith("#") or not x.strip():
                continue
            n = x.split("\t", 1)[0].strip()
            s.add(n)
            s.add(os.path.splitext(n)[0])
    return s


def owed_of(d):
    reasons = {}
    p = os.path.join(d, "ALL.omit")
    if os.path.isfile(p):
        for x in open(p, encoding="utf-8", errors="replace"):
            if ": " in x:
                reasons[x.split(": ", 1)[0].strip()] = x.split(": ", 1)[1].strip()
    out = table_names(d, "EXCLUDED.tsv") | table_names(d, "CONTAINERS.tsv")
    return [(n, reasons[n]) for n in sorted(reasons) if n not in out and os.path.splitext(n)[0] not in out and not DECLARED.search(reasons[n])]


def main():
    a = sys.argv[1:]
    root = opt(a, "--root") or os.environ.get("S4E_HOME") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    prog = os.environ.get("S4E_CYCLE_PROG", "/home/resources/progress")
    log = opt(a, "--log") or os.path.join(prog, "CYCLE.log")
    only = set((opt(a, "--only") or "").split(",")) - {""}
    want_owed = opt(a, "--owed")
    runners = os.path.join(root, "harness/scripts/SUITE_RUNNERS.tsv")
    if not os.path.isfile(runners):
        print("REFUSE(2) [cycle-inventory]: no %s" % runners)
        return 2
    laps = collections.defaultdict(dict)
    done = []
    if os.path.isfile(log):
        for l in open(log, encoding="utf-8", errors="replace"):
            m = re.search(r" CELL lap=(\d+) \d+/\d+ (\S+) (\S+) rc=(\S+) secs=(\S+)", l)
            if m:
                laps[int(m.group(1))][(m.group(2), m.group(3))] = m.group(4)
                continue
            m = re.search(r" LAP (\d+) done ", l)
            if m:
                done.append(int(m.group(1)))
    lap = max(done) if done else None
    held = collections.Counter()
    if os.path.isfile(os.path.join(prog, "CYCLE.skip")):
        for l in open(os.path.join(prog, "CYCLE.skip"), encoding="utf-8", errors="replace"):
            f = l.rstrip("\n").split("\t")
            if len(f) >= 3:
                held[f[1]] += 1
    bad = bad_lap = rows = 0
    if not want_owed:
        print("INVENTORY root=%s lap_read=%s" % (root, lap))
        print(FMT % ("key", "kind", "SRCP", "csv", "cont", "part", "gone", "nocell", "owed", "cells", "lap rc:n", "verdict"))
    for l in open(runners, encoding="utf-8"):
        if l.startswith("#") or not l.strip():
            continue
        f = l.rstrip("\n").split("\t")
        if len(f) < 5 or f[1] == "port":
            continue
        key, kind, lang, runner, table = f[:5]
        if (only and key not in only) or (want_owed and key != want_owed):
            continue
        rows += 1
        if kind not in ("master", "pkg"):
            if kind == "small" and runner not in ("", "-"):   # COO-516: one cell (all) a lap, run by the row's own runner until the suite is a package
                rc = (laps.get(lap, {}) if lap is not None else {}).get((key, "all"), "-")
                print(FMT % (key, kind, "----", "-", "-", "-", "-", "-", "-", 1, "%s:1" % rc if rc != "-" else "-", "BY-ITS-RUNNER (%s; not a package yet)" % runner))
                bad += 1
                bad_lap += 0 if rc in ("0", "1") else 1
                continue
            print(FMT % (key, kind, "----", "-", "-", "-", "-", "-", "-", 0, "-", "NOT-IN-CYCLE (runner %s)" % runner))
            bad += 1
            bad_lap += 1
            continue
        d = os.path.join(root, "corpus/tests", lang) if kind == "master" else os.path.join(root, table)
        e = EXT.get(lang, "?")
        src, ref, cs, pt = (os.path.join(d, n) for n in ("ALL." + e, "ALL.ref", "ALL.csv", "PARTITION.tsv"))
        flags = "".join(c if os.path.isfile(p) else "." for c, p in zip("SRCP", (src, ref, cs, pt)))
        ncsv = "-"
        cont = None
        part = collections.defaultdict(set)
        if os.path.isfile(cs):
            with open(cs, encoding="utf-8", errors="replace", newline="") as fh:
                ncsv = sum(1 for _ in csv.DictReader(fh))
        fmt2 = os.path.isfile(os.path.join(d, "MULTI.md")) or os.path.isfile(os.path.join(d, "ONE." + e))   # format 2, read by the harness under the ALL.<ext> ALL.ref line (CIO-24 f; the cfo 2026-11-12: sno-rungs read NO-CONTAINER since its regroup)
        if fmt2:
            flags = "2" + flags[1:]
        if (os.path.isfile(src) and os.path.isfile(ref)) or fmt2:
            r = subprocess.run([sys.executable, os.path.join(root, "harness/scripts/corpus_suite_harness.py"), "list", src, ref, "--lang", lang],
                               capture_output=True, text=True, errors="replace")
            cont = set(x for x in r.stdout.split("\n") if x.strip()) if r.returncode == 0 else None
        if os.path.isfile(pt):
            ip = ie = None
            for pl in open(pt, encoding="utf-8", errors="replace"):
                if pl.startswith("#"):
                    continue
                c = pl.rstrip("\n").split("\t")
                if ip is None:
                    if "part" in c and "entry" in c:
                        ip, ie = c.index("part"), c.index("entry")
                    continue
                if len(c) > ip and (c[ip] == "core" or c[ip].startswith("chunk:")):
                    part[c[ip]].add(c[ie])
        pnames = set().union(*part.values()) if part else set()
        gone = len(pnames - cont) if cont is not None else "-"
        nocell = len(cont - pnames) if cont is not None else "-"
        owed = owed_of(d) if (kind == "pkg" and cont is not None) else []
        if want_owed:
            for n, why in owed:
                print("%s\t%s" % (n, why))
            print("OWED %s n=%d" % (key, len(owed)))
            return 0
        rcs = collections.Counter(laps[lap][(key, c)] for c in part if lap and (key, c) in laps[lap]) if lap else {}
        v, vl = [], []
        if cont is None:
            v.append("NO-CONTAINER")
        if not part:
            v.append("NO-PARTITION")
        if cont is not None and gone:
            v.append("PARTITION-NAMES-%d-ABSENT" % gone)
        if cont is not None and nocell:
            v.append("%d-ENTRIES-IN-NO-CELL" % nocell)
        if owed:
            v.append("OWED-%d" % len(owed))
        if rcs.get("2"):
            vl.append("%d-CELLS-REFUSE" % rcs["2"])
        if any(k not in ("0", "1", "2") for k in rcs):
            vl.append("CELL-DIED-OR-TIMED-OUT")
        hold = ["HELD-%d-CELLS" % held[key]] if held.get(key) else []
        if not (part and held.get(key, 0) >= len(part)):   # a row whose every cell Lon holds is shown with its words and counted by neither check
            bad += 1 if v else 0
            bad_lap += 1 if (v or vl) else 0
        print(FMT % (key, kind, flags, ncsv, len(cont) if cont is not None else "-", len(pnames) if part else "-", gone, nocell,
                     len(owed) if kind == "pkg" and cont is not None else "-", len(part),
                     " ".join("%s:%d" % kv for kv in sorted(rcs.items())) or "-", " ".join(v + vl + hold) or "OK"))
    if want_owed:
        print("REFUSE(2) [cycle-inventory]: no pkg row %s with a container" % want_owed)
        return 2
    if only and rows != len(only):
        print("REFUSE(2) [cycle-inventory]: --only named %d row(s), %d found" % (len(only), rows))
        return 2
    print("INVENTORY rows=%d structural_not_ok=%d with_lap_not_ok=%d" % (rows, bad, bad_lap))
    if "--check-lap" in a:
        return 1 if bad_lap else 0
    if "--check" in a:
        return 1 if bad else 0
    return 0


sys.exit(main())
