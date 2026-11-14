#!/usr/bin/env python3
# util_tiers.py -- THE ONE TIERS TABLE, CHECKED (DESIGN-PLAN fleet-queue step 2; the cio, 2026-11-05, on Lon's word: "each level in the hierarchy
# serving the one below"; skill fleet-bus section 8). The table is .github/TIERS.tsv: one row per seat, its name, root, model, effort, color, tier
# and role. Every reader reads that table: .github/scripts/spawn_fleet.sh (its --table output is compared here), the dispatcher and the Stop gate
# (their seat-specific case patterns are counted here; a seat-class pattern in a reader is a second tiers table and is refused).
#   util_tiers.py --list    print the table
#   util_tiers.py --check   validate the table and the readers; print ONE line
#     TIERS seats=N tiers=T fable=F opus=O sonnet=S haiku=H spawn_table=same|differ dispatcher_patterns=N|unmeasured stop_gate_patterns=N|unmeasured
#   The line carries the exact tokens the probe reads (test_design_fleet_queue_steps.sh --step 2) and only when every token is right; a problem is
#   printed after it as PROBLEM, and the exit is 1 (RED). rc 2 REFUSE: no table. The dispatcher path is S4E_DISPATCHER, else
#   harness/scripts/box_tick.sh when it exists (fleet-queue step 10), else the coo's controller until the tick lands; a dispatcher
#   that cannot be read is 'unmeasured', never counted as zero.
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import harness_paths as HP
ROOT = os.environ.get("S4E_HOME") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
TIERS = os.path.join(str(HP.github()), "TIERS.tsv")
SPAWN = os.path.join(str(HP.github()), "scripts", "spawn_fleet.sh")
# The dispatcher is the TICK of fleet-queue step 10 (harness/scripts/box_tick.sh, written by worker_03; it takes its seat classes from
# util_tiers.py --tier-of, never a case arm). Until that file exists the counted dispatcher is the coo's controller, outside every repo
# (the cio's ruling, 2026-11-05 17:4x). COO_CONTROLLER is removed when the tick lands and the coo swaps its controller out.
TICK = os.path.join(str(HP.harness()), "scripts", "box_tick.sh")
COO_CONTROLLER = "/home/claude_coo/.scratch/verifier/box_controller.sh"
DISPATCHER = os.environ.get("S4E_DISPATCHER") or (TICK if os.path.isfile(TICK) else COO_CONTROLLER)
STOP_GATE = os.path.join(str(HP.harness()), "scripts", "s4e_stop_gate.sh")
HEADER = ["seat", "name", "root", "model", "effort", "color", "tier", "role"]
TIER_MODEL = {"1": "claude-opus-5-5","2": "claude-opus-5-5", "3": "claude-sonnet-5-5", "4": "claude-haiku-5-5"}
SEAT_MODEL = {"cto": "claude-fable-5-2", "cio": "claude-fable-5-2", "cfo": "claude-fable-5-2"}
EFFORTS = {"xhigh", "high", "medium"}
COLORS = {"red", "green", "yellow", "purple", "cyan"}
CLASS_GLOBS = ["hq_*", "worker_[0-9]"]


def refuse(msg):
    print("REFUSE(2) [util_tiers]: " + msg, file=sys.stderr)
    sys.exit(2)


def load():
    if not os.path.isfile(TIERS):
        refuse("no tiers table at " + TIERS)
    rows, problems, header = [], [], None
    with open(TIERS) as f:
        for n, line in enumerate(f, 1):
            if line.startswith("#") or not line.strip():
                continue
            cells = line.rstrip("\n").split("\t")
            if header is None:
                header = cells
                if cells != HEADER:
                    problems.append("header is %s, want %s" % (cells, HEADER))
                continue
            if len(cells) != len(HEADER):
                problems.append("line %d: %d cells, want %d" % (n, len(cells), len(HEADER)))
                continue
            rows.append(dict(zip(HEADER, cells), line=n))
    seen_seat, seen_name = set(), set()
    for r in rows:
        if r["seat"] in seen_seat:
            problems.append("seat %s listed twice (line %d)" % (r["seat"], r["line"]))
        if r["name"] in seen_name:
            problems.append("name %s listed twice (line %d)" % (r["name"], r["line"]))
        seen_seat.add(r["seat"])
        seen_name.add(r["name"])
        if r["tier"] not in TIER_MODEL:
            problems.append("seat %s: tier %r is not 1-4 (line %d)" % (r["seat"], r["tier"], r["line"]))
        elif r["model"] != SEAT_MODEL.get(r["seat"], TIER_MODEL[r["tier"]]):
            problems.append("seat %s: model %s is not tier %s's %s" % (r["seat"], r["model"], r["tier"], SEAT_MODEL.get(r["seat"], TIER_MODEL[r["tier"]])))
        if r["effort"] not in EFFORTS:
            problems.append("seat %s: effort %r not in %s" % (r["seat"], r["effort"], sorted(EFFORTS)))
        if r["color"] not in COLORS:
            problems.append("seat %s: color %r not in %s" % (r["seat"], r["color"], sorted(COLORS)))
        if r["root"] != "/home/claude_" + r["seat"]:
            problems.append("seat %s: root %s is not /home/claude_%s" % (r["seat"], r["root"], r["seat"]))
    return rows, problems


def counts(rows):
    by = {}
    for r in rows:
        by[r["tier"]] = by.get(r["tier"], 0) + 1
    return by


def spawn_check(rows):
    if not os.path.isfile(SPAWN):
        return "not-in-repo", []   # the spawn program is Lon's, in his home, not in a repo (Lon 2026-11-07 16:5x: "This is a program I run"); it reads TIERS.tsv by full path, so there is nothing here to compare
    try:
        p = subprocess.run(["bash", SPAWN, "--table"], capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired:
        return "unmeasured", ["spawn_fleet.sh --table ran past 60 s"]
    if p.returncode != 0:
        return "unmeasured", ["spawn_fleet.sh --table rc=%d: %s" % (p.returncode, p.stderr.strip()[:200])]
    got = [tuple(x.split("\t")) for x in p.stdout.splitlines() if x.strip()]
    want = [(r["seat"], r["name"], r["root"], r["model"], r["effort"], r["color"]) for r in rows]
    if got == want:
        return "same", []
    return "differ", ["spawn_fleet.sh --table (%d rows) differs from TIERS.tsv (%d rows)" % (len(got), len(want))]


def seat_class_lines(path, names):
    # a case arm whose pattern names a seat or a seat class: the words after ' in ' up to the arm's ')'
    hits = []
    with open(path, errors="replace") as f:
        for n, line in enumerate(f, 1):
            m = re.search(r"(?:^\s*|[;&|{(]\s*)case\s+(?:\"[^\"]*\"|'[^']*'|\S+)\s+in\s", line)
            if not m:
                continue
            seg = line[m.end():].split(")", 1)[0]
            if any(g in seg for g in CLASS_GLOBS) or any(re.search(r"(?<![\w])" + re.escape(s) + r"(?![\w])", seg) for s in names):
                hits.append(n)
    return hits


def reader_check(path, names):
    if not os.path.isfile(path):
        return "unmeasured", ["no reader at " + path]
    hits = seat_class_lines(path, names)
    if hits:
        return str(len(hits)), ["%s: %d seat-class case arm(s) at line(s) %s -- a second tiers table" % (path, len(hits), ",".join(map(str, hits[:8])))]
    return "0", []


def main():
    args = sys.argv[1:]
    if args == ["--list"]:
        rows, _ = load()
        for r in rows:
            print("\t".join(r[k] for k in HEADER[:-1]))
        return 0
    if args != ["--check"]:
        print("usage: util_tiers.py --list | --check", file=sys.stderr)
        return 2
    rows, problems = load()
    if not rows:
        refuse("no seat rows in " + TIERS)
    by = counts(rows)
    names = [r["seat"] for r in rows]
    spawn_tok, p1 = spawn_check(rows)
    disp_tok, p2 = reader_check(DISPATCHER, names)
    stop_tok, p3 = reader_check(STOP_GATE, names)
    problems += p1 + p2 + p3
    print("TIERS seats=%d tiers=%d fable=%d opus=%d sonnet=%d haiku=%d spawn_table=%s dispatcher_patterns=%s stop_gate_patterns=%s"
          % (len(rows), len(by), by.get("1", 0), by.get("2", 0), by.get("3", 0), by.get("4", 0), spawn_tok, disp_tok, stop_tok))
    for p in problems:
        print("PROBLEM " + p)
    ok = not problems
    print("GATE %s [util_tiers]" % ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
