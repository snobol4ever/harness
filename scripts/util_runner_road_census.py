#!/usr/bin/env python3
"""util_runner_road_census.py -- read-only census of SUITE_RUNNERS.tsv (skill suites-and-grading).

Per row: BATCH_ROAD (does the runner take the batch road) and MODES (does its mode
list come from S4E_MODES). It runs nothing; it reads text only.
rc 0 when every cycle row (master or pkg) reads on and s4e; rc 1 otherwise; rc 2 REFUSE.
"""
import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TABLE = os.path.join(HERE, "SUITE_RUNNERS.tsv")
LIB_RE = re.compile(r'^\s*(?:source|\.)\s+.*?(lib_[A-Za-z0-9_]+\.sh)')
BATCH_RE = re.compile(r'corpus_suite_harness\.py|--harness\b')
S4E_DEFAULT = '${S4E_MODES:-'


def refuse(msg):
    print("REFUSE(2): " + msg)
    sys.exit(2)


def is_code(line):
    s = line.lstrip()
    return s != "" and not s.startswith("#")


def read_rows():
    try:
        with open(TABLE, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError as e:
        refuse("cannot read %s: %s" % (TABLE, e))
    rows = []
    for line in lines:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        cols = line.split("\t")
        if len(cols) < 5:
            refuse("malformed row in %s: %r" % (TABLE, line))
        rows.append({"key": cols[0], "kind": cols[1], "lang": cols[2], "runner": cols[3]})
    if not any(r["kind"] in ("master", "pkg") for r in rows):
        refuse("no master or pkg row in %s" % TABLE)
    return rows


def sources(script):
    path = os.path.join(HERE, script)
    out, seen, todo = [], set(), [path]
    while todo:
        f = todo.pop(0)
        if f in seen or not os.path.isfile(f):
            continue
        seen.add(f)
        with open(f, encoding="utf-8", errors="replace") as fh:
            text = fh.read().splitlines()
        out.append((f, text))
        for line in text:
            if is_code(line):
                m = LIB_RE.match(line)
                if m:
                    todo.append(os.path.join(HERE, m.group(1)))
    return path, out


def batch(row, path, srcs):
    if not os.path.isfile(path):
        return "nofile"
    if row["kind"] == "master":
        return "on"
    for _, text in srcs:
        for line in text:
            if is_code(line) and BATCH_RE.search(line):
                return "on"
    return "off"


def modes(row, srcs):
    if row["kind"] == "master":
        return "s4e", ""
    n, places = 0, []
    for f, text in srcs:
        for no, line in enumerate(text, 1):
            if not is_code(line):
                continue
            i = line.find("m3,m4")
            while i >= 0:
                if not line[:i].endswith(S4E_DEFAULT):
                    n += 1
                    places.append("%s:%d" % (os.path.basename(f), no))
                i = line.find("m3,m4", i + 1)
    if n == 0:
        return "s4e", ""
    return "fixed", "(%d literal m3,m4: %s)" % (n, " ".join(places[:3]))


def census(rows):
    results = []
    for row in rows:
        words = row["runner"].split()
        script = words[0] if words else ""
        path, srcs = sources(script)
        b = batch(row, path, srcs)
        m, note = modes(row, srcs)
        bl = "BATCH_ROAD row=%s kind=%s runner=%s %s" % (row["key"], row["kind"], script, b)
        ml = ("MODES row=%s s4e" % row["key"]) if m == "s4e" else ("MODES row=%s fixed %s" % (row["key"], note))
        results.append((row, b, m, bl, ml))
    return results


def main():
    ap = argparse.ArgumentParser(description="read-only census of SUITE_RUNNERS.tsv")
    ap.add_argument("--key", help="print only this row's two lines")
    args = ap.parse_args()
    rows = read_rows()
    results = census(rows)
    if args.key is not None:
        hit = [r for r in results if r[0]["key"] == args.key]
        if not hit:
            refuse("no row with key %s in %s" % (args.key, TABLE))
        _, b, m, bl, ml = hit[0]
        print(bl)
        print(ml)
        sys.exit(0 if b == "on" and m == "s4e" else 1)
    for _, _, _, bl, ml in results:
        print(bl)
        print(ml)
    cycle = [r for r in results if r[0]["kind"] in ("master", "pkg")]
    batch_on = sum(1 for r in cycle if r[1] == "on")
    batch_off = sum(1 for r in cycle if r[1] in ("off", "nofile"))
    modes_s4e = sum(1 for r in cycle if r[2] == "s4e")
    modes_fixed = sum(1 for r in cycle if r[2] == "fixed")
    print("RUNNER_ROAD_CENSUS rows=%d cycle_rows=%d batch_on=%d batch_off=%d modes_s4e=%d modes_fixed=%d"
          % (len(results), len(cycle), batch_on, batch_off, modes_s4e, modes_fixed))
    sys.exit(0 if batch_on == len(cycle) and modes_s4e == len(cycle) else 1)


if __name__ == "__main__":
    main()
