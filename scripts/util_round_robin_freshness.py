#!/usr/bin/env python3
"""util_round_robin_freshness.py [--loop-dir D] [--hours H] -- IS THE VERIFIER LOOP REFRESHING ITS LIVE POPULATION, ONE TEST AT A TIME?

The DONE-WHEN of the coo's row instruments-the-verifier-loop-cycles-every-suites-chunks-in-its-spare-time-and-runs-core-plus-shell-per-landing-ceo-1676,
re-cut by the ceo at CEO-1835 (2026-10-18) on the coo's measurement: the old criterion counted every program name ever recorded in the progress
database, ghosts included (gimpel 562 names for 145 shipped), and the suites the focus idles and the ceo holds, so it measured the bookkeeping, not
the loop. THE POPULATION is the live one: the suite rotation's members as the loop itself lists them (loop8.sh's ROT array in the loop directory),
less the members idle_units names, each member's denominator as util_score_row.py from-progress --dry-run reads it (total=, its db_suite=);
a member from-progress cannot read is named unresolved and left out. Members idle under ORDER-OF-WORK and members HELD (listed in idle_units below its "# HELD"
line) are left out and NAMED with their counts. FRESH: the distinct programs of a member's progress suite, capped at its denominator, with a coo reading tagged rr=1 (the round robin) or req=<seat> (a request, the
loop's other input, CEO-1806) inside the window. OUTSIDE: any coo reading in the window that carries neither tag, over the whole database.
Prints one ROUND_ROBIN_LIVE line; rc 0 iff outside is 0 and four fifths of the live population is fresh, 1 otherwise, 2 when it cannot measure."""
import argparse, datetime, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
MASTER_KEY = {"snobol4": "sno-rungs", "icon": "icn-rungs", "prolog": "pl-rungs", "pascal": "pas-rungs", "raku": "raku-rungs", "snocone": "snc-rungs", "rebus": "reb-rungs"}
TAG_RR = re.compile(r"(^|[ ;,])rr=1([ ;,]|$)")
TAG_REQ = re.compile(r"(^|[ ;,])req=[a-z_0-9]+([ ;,]|$)")


def refuse(msg):
    print("REFUSE(2) [util_round_robin_freshness]: " + msg)
    sys.exit(2)


def rotation(loop_dir):
    path = os.path.join(loop_dir, "loop8.sh")
    if not os.path.exists(path):
        refuse("no loop8.sh in %s -- the rotation is the loop's own member list" % loop_dir)
    text = open(path, encoding="utf-8", errors="replace").read()
    m = re.search(r"^ROT=\((.*?)^\)", text, re.S | re.M)
    if not m:
        refuse("%s has no ROT=( ... ) array" % path)
    out = []
    for e in re.findall(r'"([^"]+)"', m.group(1)):
        f = e.split("|")
        if f[0] == "master" and len(f) > 1:
            out.append((f[1], MASTER_KEY.get(f[1])))
        elif f[0] == "pkg" and len(f) > 4:
            out.append((f[1], f[4]))
        elif f[0] == "small" and len(f) > 2:
            out.append((f[1], f[2]))
    return out


def idle_and_held(loop_dir):
    idle, held, in_held = set(), set(), False
    path = os.path.join(loop_dir, "idle_units")
    if os.path.exists(path):
        for ln in open(path, encoding="utf-8", errors="replace"):
            ln = ln.strip()
            if ln.startswith("# HELD"):
                in_held = True
            elif ln and not ln.startswith("#"):
                (held if in_held else idle).add(ln)
    return idle, held


def population(key):
    """(progress suite name, denominator) as util_score_row.py from-progress --dry-run reads them -- the ONE population rule (shipped minus
    EXCLUDED, Gimpel's libraries, SWI's and Logtalk's cases), never a second copy of it; (None, None) when from-progress cannot read the key."""
    r = subprocess.run([sys.executable, os.path.join(HERE, "util_score_row.py"), "from-progress", "--suite", key, "--dry-run"],
                       capture_output=True, text=True, timeout=600)
    m = re.search(r"^SUITE_ROW suite=\S+ pass=\d+ total=(\d+) .*? db_suite=(\S+) ", r.stdout, re.M)
    return (m.group(2), int(m.group(1))) if m else (None, None)


def stem(n):
    b = n.rsplit("/", 1)[-1]
    return n[: len(n) - len(b)] + (b.rsplit(".", 1)[0] if "." in b else b)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--loop-dir", default="/home/claude_coo/.scratch/verifier")
    ap.add_argument("--hours", type=float, default=72.0)
    a = ap.parse_args()
    db = os.environ.get("S4E_PROGRESS_DB", "/home/resources/progress/results.tsv")
    if not os.path.exists(db):
        refuse("the progress DB %s does not exist" % db)
    since = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=a.hours)).strftime("%Y-%m-%dT%H:%M:%S")
    idle, held = idle_and_held(a.loop_dir)
    live, idle_n, held_n, unread = {}, {}, {}, []
    for member, key in rotation(a.loop_dir):
        if not key:
            continue
        if member in held or member in idle:
            dbsuite, total = population(key)
            (held_n if member in held else idle_n)[member] = total if total is not None else -1
            continue
        dbsuite, total = population(key)
        if dbsuite is None:
            unread.append(member)
            continue
        live[dbsuite] = live.get(dbsuite, 0) + total
    if not live:
        refuse("no live rotation member resolved to a table")
    fresh, outside = {}, 0
    with open(db, encoding="utf-8", errors="replace") as fh:
        fh.readline()
        for line in fh:
            f = line.rstrip("\n").split("\t")
            if len(f) < 14 or f[0] <= since or f[3] != "coo":
                continue
            rr, req = bool(TAG_RR.search(f[13])), bool(TAG_REQ.search(f[13]))
            if not (rr or req):
                outside += 1
                continue
            if f[5] in live:
                fresh.setdefault(f[5], set()).add(stem(f[7]))
    tests = sum(live.values())
    nfresh = sum(min(len(fresh.get(k, ())), n) for k, n in live.items())   # capped at the denominator: a program outside it never counts twice
    fmt = lambda d: ",".join("%s:%d" % kv for kv in sorted(d.items())) or "none"
    print("ROUND_ROBIN_LIVE window=%gh members=%d tests=%d fresh=%d (%.0f%%) outside=%d idle=[%s] held=[%s]%s (ceo CEO-1835: the rotation's non-idle, non-held members; fresh is rr=1 or req=)"
          % (a.hours, len(live), tests, nfresh, 100.0 * nfresh / tests, outside, fmt(idle_n), fmt(held_n), (" unresolved=[%s]" % ",".join(unread)) if unread else ""))
    worst = sorted(((n - min(len(fresh.get(k, ())), n), k, min(len(fresh.get(k, ())), n), n) for k, n in live.items()), reverse=True)[:6]
    print("ROUND_ROBIN_STALEST " + " ".join("%s=%d/%d" % (k, fr, n) for _, k, fr, n in worst))
    ok = outside == 0 and nfresh * 5 >= tests * 4
    print("GREEN" if ok else "RED: %s" % ("coo readings outside the loop in the window" if outside else "under four fifths of the live population is fresh"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
