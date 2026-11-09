#!/usr/bin/env python3
"""util_swi_cases_census.py [--only REL] [--list] -- CIO-20: every swi_tests entry, both ways, mode 3.

For each entry of corpus/packages/prolog/swi_tests/ALL.csv:
  ONE      the one launch (corpus_suite_harness.py run ... --partition entry:NAME) with S4E_PROGRESS_DB set to a fresh
           scratch file; its per-case rows are read by column name (program, outcome).
  REF      util_swi_grade_file.sh NAME.pl; its out= directory's m file (unit:test#k TAB WORD).
Cases are compared by key. A case present on one side only is a disagreement, and so is a differing word.
Prints one DISAGREE line per disagreeing entry (its first differing case, both words) and one CENSUS line:
  CENSUS entries=N agree=A disagree=D
--only REL   the one entry REL (for example library/test_csv), as the proof uses it
--list       print only the disagreeing entry names, then the CENSUS line
"""
import csv, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("S4E_HOME") or os.path.dirname(os.path.dirname(HERE))
PKG = "corpus/packages/prolog/swi_tests"
SEAT = os.environ.get("S4E_SEAT") or "census"
SCRATCH = "/tmp/s4e/%s/census" % SEAT
LAUNCH_TIMEOUT = 900
GRADE_TIMEOUT = 600
WORDS = ("PASS", "FAIL", "HANG", "CRASH", "UNGRADED")


def entries():
    with open(os.path.join(ROOT, PKG, "ALL.csv"), encoding="utf-8", newline="") as fh:
        return [row["entry"] for row in csv.DictReader(fh) if row.get("entry")]


def one_side(entry, scratch):
    if os.path.exists(scratch):
        os.unlink(scratch)
    env = dict(os.environ, S4E_PROGRESS_DB=scratch)
    try:
        subprocess.run(["python3", "-I", "harness/scripts/corpus_suite_harness.py", "run", PKG + "/ALL.pl", PKG + "/ALL.ref",
                        "--lang", "prolog", "--modes", "m3", "--partition", "entry:" + entry],
                       cwd=ROOT, env=env, stdin=subprocess.DEVNULL, capture_output=True, timeout=LAUNCH_TIMEOUT)
    except subprocess.TimeoutExpired:
        return {"LAUNCH-TIMEOUT": "TIMEOUT"}
    cases = {}
    if not os.path.exists(scratch):
        return cases
    prefix = entry + ".pl:"
    with open(scratch, encoding="utf-8", errors="replace") as fh:
        header = None
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if header is None:
                if "program" in parts and "outcome" in parts:
                    header = parts
                continue
            if len(parts) < len(header):
                continue
            prog = parts[header.index("program")]
            if not prog.startswith(prefix):
                continue
            cases[prog[len(prefix):]] = parts[header.index("outcome")]
    return cases


def ref_side(entry):
    env = dict(os.environ, S4E_HOME=ROOT)
    try:
        out = subprocess.run(["bash", "harness/scripts/util_swi_grade_file.sh", entry + ".pl"], cwd=ROOT, env=env,
                             stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=GRADE_TIMEOUT).stdout
    except subprocess.TimeoutExpired:
        return {"GRADE-TIMEOUT": "TIMEOUT"}
    d = None
    for line in out.splitlines():
        if line.startswith("SWI_FILE ") and " out=" in line:
            d = line.split(" out=", 1)[1].strip()
    cases = {}
    if not d:
        return cases
    try:
        with open(os.path.join(d, "m"), encoding="utf-8", errors="replace") as fh:
            for line in fh:
                parts = line.rstrip("\n").split("\t")
                if len(parts) >= 2 and "#" in parts[0] and parts[1] in WORDS:
                    cases[parts[0]] = parts[1]
    except OSError:
        pass
    return cases


def census_one(entry):
    scratch = os.path.join(SCRATCH, entry.replace("/", "__") + ".tsv")
    os.makedirs(SCRATCH, exist_ok=True)
    one = one_side(entry, scratch)
    ref = ref_side(entry)
    keys = list(ref.keys()) + [k for k in one.keys() if k not in ref]
    for k in keys:
        a, b = one.get(k, "ABSENT"), ref.get(k, "ABSENT")
        if a != b:
            return False, "DISAGREE entry=%s case=%s one=%s ref=%s" % (entry, k, a, b)
    return True, None


def main(argv):
    only, list_only = None, False
    i = 0
    while i < len(argv):
        if argv[i] == "--only":
            only = argv[i + 1]
            i += 2
            continue
        if argv[i] == "--list":
            list_only = True
        i += 1
    names = [only] if only else entries()
    agree = disagree = 0
    for name in names:
        ok, line = census_one(name)
        if ok:
            agree += 1
        else:
            disagree += 1
            print(line.split(" case=")[0].replace("DISAGREE entry=", "") if list_only else line, flush=True)
    print("CENSUS entries=%d agree=%d disagree=%d" % (len(names), agree, disagree), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
