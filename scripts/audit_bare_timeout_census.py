#!/usr/bin/env python3
"""audit_bare_timeout_census.py -- THE CENSUS OF GRADED RUNS WHOSE TIMEOUT IS NOT RETRIED UNDER LOAD (ceo CEO-1335; the coo 2026-10-09).

A runner that grades a unit under its own per-program timeout calls util_timeout_retry.sh ("$TIMEOUT_RETRY", timeout's own argv) or,
in Python, lib_timeout_retry.run (subprocess.run's own signature): a timeout while the 1-minute load exceeds the cores is then run once
more, and only a second timeout stands. This census reads the runner population's source and names every call that still times a
run out bare -- a shell `timeout DURATION ...` at command position, or a Python subprocess.run(..., timeout=...) -- unless the line
says why it is not a graded unit with the marker `timeout-retry: exempt -- <reason>` (a whole-suite cap, a git fetch).

THE POPULATION: every runner ../harness/scripts/one_runner_boards.txt names (the guarded suite runners), test_demos_suite.sh, lib_ladder.sh (the
one body of the seven ladders) and util_logtalk_grade.py (the Logtalk grader); --files replaces it (the gate's fail-once fixture).
The bench runners are outside it: their timed runs must not carry the tool's own process, and a timing read under load is void
whatever its timeout did. A line that only prints text (echo, printf) is not a call.

EXIT: 0 no bare graded timeout · 1 one or more, each named file:line · 2 could not read the population.
"""
import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
EXTRA = ["test_demos_suite.sh", "lib_ladder.sh", "util_logtalk_grade.py"]
SH = re.compile(r'(^|[\s(;&|!]|\$\()timeout\s+(?:-[A-Za-z-]+\s+\S+\s+)*(?:"?\$|[0-9])')
PYRUN = re.compile(r'\bsubprocess\.run\(')
MARK = "timeout-retry: exempt"


def population():
    lst = HERE / "one_runner_boards.txt"
    names = [ln.split()[0] for ln in lst.read_text().splitlines() if ln.strip() and not ln.lstrip().startswith("#")]
    return [HERE / n for n in names + EXTRA]


def py_calls(lines):
    """(line number, text) of every subprocess.run( call whose argument list carries timeout=, read across its continuation lines."""
    out = []
    for i, s in enumerate(lines):
        if not PYRUN.search(s) or s.lstrip().startswith("#"):
            continue
        depth, text, j = 0, "", i
        while j < len(lines):
            seg = lines[j][lines[j].index("subprocess.run(") if j == i else 0:]
            text += seg
            depth += seg.count("(") - seg.count(")")
            if depth <= 0:
                break
            j += 1
        if "timeout=" in text and MARK not in "".join(lines[i:j + 1]):
            out.append((i + 1, s.strip()))
    return out


def scan(path):
    lines = path.read_text(errors="replace").split("\n")
    found = []
    if path.suffix == ".py":
        return py_calls(lines)
    in_py = False
    for i, s in enumerate(lines):
        st = s.lstrip()
        if re.match(r"python3 - <<'?PY'?", st) or re.search(r"<<'PY'\s*(\|.*)?$", s):
            in_py = True
            py_start = i
            continue
        if in_py:
            if st == "PY":
                found.extend((py_start + 1 + n, t) for n, t in py_calls(lines[py_start + 1:i]))
                in_py = False
            continue
        if st.startswith("#") or re.match(r"(echo|printf)\b", st) or MARK in s or "TIMEOUT_RETRY" in s:
            continue
        if SH.search(s):
            found.append((i + 1, s.strip()))
    return found


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--files", nargs="*", help="read these files instead of the runner population")
    a = ap.parse_args()
    try:
        files = [Path(f) for f in a.files] if a.files else population()
    except OSError as e:
        print("REFUSE(2): the runner population is unreadable: %s" % e)
        return 2
    missing = [f for f in files if not f.is_file()]
    if missing:
        print("REFUSE(2): %d file(s) of the population are missing: %s" % (len(missing), " ".join(str(m) for m in missing[:5])))
        return 2
    total, per = 0, []
    for f in files:
        hits = scan(f)
        total += len(hits)
        for n, t in hits:
            print("  BARE  %s:%d  %s" % (f.name, n, t[:150]))
        per.append((f.name, len(hits)))
    exempt = sum(Path(f).read_text(errors="replace").count(MARK) for f in files)
    print("population: %d runner file(s); bare graded timeouts: %d; exempt by marker: %d" % (len(files), total, exempt))
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
