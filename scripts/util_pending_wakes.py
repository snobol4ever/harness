#!/usr/bin/env python3
"""util_pending_wakes.py -- THE LADDER GOES UP BY ITSELF, AND EVERY WAKE IS ONE LIST (COO-488, Lon 2026-11-08 13:4x: "Is this "design assign" and
"task help escalation" automatic? if not it needs be." / "the former goes down and the ladder goe up."; designed by officer_05).

A Claude session has no inbound event but a SendMessage from another session, and no script may forge one (a cross-session message to a session in
another permission mode waits for its user's approval; a raw socket write would bypass that hold). So the wake stays a SendMessage, sent by the coo
each tick from ONE list this command prints; the rung move it decides itself.
  READS   the bus tubes (util_queue.py tubes: seat-*, tier-*, ask-* only), each ready tube's head (peek: age, topic); TIERS.tsv (seat, name,
          tier, role); the live set (a seat whose s4e-seat-<seat>.scope holds a claude process; --live a,b,c names it instead); the claims
          (a seat holding a claim with a RESERVED job= line and no DONE is busy); MODE's BOSSES: and ON-CALL: lines.
  PRINTS  WAKE <SESSION> seat=<s> tube=<t> ready=N oldest=Ns [overdue]   one per ready job, to an idle live taker:
              seat-<s>  -> s;  tier-<t> -> the live seats of that tier whose role is not designer, bosses left out;  ask-<t> -> the live
              seats of that tier, bosses left out.  tier-fable, ask-fable and a tier-1 seat's own seat tube (seat-cio, seat-cto) are never woken here (COO-486: the bosses sleep unless the fleet is on
              fire; a fire is the coo's call), they print FIRE_ONLY lines instead.
          PROMOTE <topic> tube=tier-sonnet -> tier-opus oldest=Ns   a senior's escalation ready past twice the limit (LIMIT_S 1800, fleet-queue 9:
              past the limit it is re-woken by its WAKE line marked overdue; past twice, it climbs one rung, to the officers, COO-485).
          STUCK <topic> tube=tier-opus oldest=Ns    an officer's escalation past twice the limit: it climbs no further by itself (COO-486); the
              coo reads it and decides fire or a park for the designing officer.
          WAKE_BOARD wakes=N overdue=N promote=N stuck=N fire_only=N unwakeable=N (tree <harness hash>)
          UNWAKEABLE tube=<t> ready=N: no idle live taker (every taker busy or asleep): informational.
  --apply  runs s4e_msg.sh queue <topic> --tier opus for each PROMOTE (the caller's seat moves it; queue prints the WAKE line of the new tube).
  --probe  plants tubes, tiers, claims and a live set in a scratch dir and prints WAKE_PROBE; rc 0 only when it reads as designed.
rc 0 read; 2 REFUSE (no tiers table, the queue unreachable). Read-only without --apply.
"""
import os, re, subprocess, sys, tempfile, shutil

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(os.path.dirname(HERE))
PO = os.environ.get("S4E_POST", "/home/resources/postoffice"); UQ = os.path.join(HERE, "util_queue.py")
LIMIT_S = 1800
TIER_NAME = {"1": "fable", "2": "opus", "3": "sonnet", "4": "haiku"}
CG = "/sys/fs/cgroup/user.slice/user-%d.slice/user@%d.service/s4e.slice/s4e-seats.slice" % (os.getuid(), os.getuid())


def refuse(why):
    print("REFUSE(2): " + why); sys.exit(2)


def arg(name, default):
    a = sys.argv[1:]
    return a[a.index(name) + 1] if name in a and a.index(name) + 1 < len(a) else default


def tiers(path):
    if not os.path.isfile(path): refuse("no tiers table %s" % path)
    rows, head = [], None
    for l in open(path, encoding="utf-8"):
        if l.startswith("#") or not l.strip(): continue
        c = l.rstrip("\n").split("\t")
        if head is None: head = c; continue
        rows.append(dict(zip(head, c)))
    return rows


def mode_line(mode, key):
    try:
        for l in open(mode, encoding="utf-8", errors="replace"):
            if l.startswith(key + ":"): return l.split(":", 1)[1].split()
    except OSError: pass
    return []


def live_by_scope(seat):
    p = os.path.join(CG, "s4e-seat-%s.scope" % seat, "cgroup.procs")
    try: pids = [x.strip() for x in open(p) if x.strip()]
    except OSError: return False
    for pid in pids:
        try:
            if open("/proc/%s/comm" % pid).read().strip() == "claude": return True
        except OSError: pass
    return False


def busy(claims):
    b = set()
    if not os.path.isdir(claims): return b
    for f in os.listdir(claims):
        if not f.endswith(".claim"): continue
        try: ls = open(os.path.join(claims, f), encoding="utf-8", errors="replace").read().split("\n")
        except OSError: continue
        if ls[0].strip() and not any(l.strip() == "DONE" for l in ls) and any(l.startswith("RESERVED job=") for l in ls): b.add(ls[0].strip())
    return b


def live_tubes():
    p = subprocess.run([sys.executable, UQ, "tubes"], capture_output=True, text=True, timeout=60)
    if p.returncode != 0: refuse("util_queue.py tubes failed: %s" % (p.stdout + p.stderr).strip()[:200])
    out = []
    for l in p.stdout.splitlines():
        c = l.split("\t")
        if len(c) < 2 or not re.match(r"^(seat|tier|ask)-", c[0]) or not c[1].isdigit() or int(c[1]) == 0: continue
        pk = subprocess.run([sys.executable, UQ, "peek", c[0]], capture_output=True, text=True, timeout=60).stdout.rstrip("\n").split("\t")
        age = int(pk[3]) if len(pk) > 4 and pk[3].isdigit() else 0
        out.append((c[0], int(c[1]), age, pk[4] if len(pk) > 4 else ""))
    return out


def plan(tubes, seats, live, busyset, bosses):
    by = {s["seat"]: s for s in seats}
    idle = lambda s: s in live and s not in busyset
    wakes, promote, stuck, fire, unw = [], [], [], [], []
    for tube, ready, age, topic in tubes:
        kind, _, rest = tube.partition("-")
        over = age > LIMIT_S
        if tube in ("tier-fable", "ask-fable"): fire.append((tube, ready, age)); continue
        if kind == "seat" and by.get(rest, {}).get("tier") == "1": fire.append((tube, ready, age)); continue   # a sleeping boss's own tube (cio, cto): fire only, COO-486
        if kind == "seat":
            cands = [rest] if rest in by and idle(rest) else []
        else:
            tn = [k for k, v in TIER_NAME.items() if v == rest]
            cands = [s["seat"] for s in seats if tn and s.get("tier") == tn[0] and s["seat"] not in bosses and idle(s["seat"])
                     and not (kind == "tier" and s.get("role") == "designer")]
        if tube == "tier-sonnet" and age > 2 * LIMIT_S and topic: promote.append((topic, tube, age))
        if tube == "tier-opus" and age > 2 * LIMIT_S and topic: stuck.append((topic, tube, age))
        if not cands: unw.append((tube, ready)); continue
        for s in cands[:ready]: wakes.append((by[s].get("name", s.upper()), s, tube, ready, age, over))
    return wakes, promote, stuck, fire, unw


def report(r):
    wakes, promote, stuck, fire, unw = r
    for n, s, t, rd, age, over in wakes: print("WAKE %s seat=%s tube=%s ready=%d oldest=%ds%s" % (n, s, t, rd, age, " overdue" if over else ""))
    for tp, t, age in promote: print("PROMOTE %s tube=%s -> tier-opus oldest=%ds" % (tp, t, age))
    for tp, t, age in stuck: print("STUCK %s tube=%s oldest=%ds (COO-486: no climb by itself; the coo decides fire or a park)" % (tp, t, age))
    for t, rd, age in fire: print("FIRE_ONLY tube=%s ready=%d oldest=%ds (the bosses sleep unless the fleet is on fire, COO-486)" % (t, rd, age))
    for t, rd in unw: print("UNWAKEABLE tube=%s ready=%d: no idle live taker" % (t, rd))
    tree = subprocess.run(["git", "-C", os.path.join(ROOT, "harness"), "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()
    print("WAKE_BOARD wakes=%d overdue=%d promote=%d stuck=%d fire_only=%d unwakeable=%d (tree %s)"
          % (len(wakes), sum(1 for w in wakes if w[5]), len(promote), len(stuck), len(fire), len(unw), tree or "?"))


def probe():
    seats = [dict(seat="cio", name="CIO", tier="1", role="fleet-system"), dict(seat="coo", name="COO", tier="2", role="testing-officer"),
             dict(seat="officer_01", name="OFFICER-01", tier="2", role="designer"), dict(seat="officer_05", name="OFFICER-05", tier="2", role="escalation"),
             dict(seat="senior_01", name="SENIOR-01", tier="3", role="company-man"), dict(seat="junior_02", name="JUNIOR-02", tier="4", role="worker"),
             dict(seat="junior_03", name="JUNIOR-03", tier="4", role="worker"), dict(seat="junior_04", name="JUNIOR-04", tier="4", role="worker")]
    live = {"cio", "coo", "officer_01", "officer_05", "senior_01", "junior_02", "junior_03"}
    busyset = {"junior_03"}
    tubes = [("tier-haiku", 2, 30, "h1"), ("seat-junior_04", 1, 10, "s4"), ("tier-opus", 1, 4000, "o1"), ("tier-sonnet", 1, 4000, "n1"),
             ("tier-fable", 1, 50, "f1"), ("ask-opus", 1, 2000, "a1"), ("seat-cio", 1, 90, "c1")]
    wakes, promote, stuck, fire, unw = r = plan(tubes, seats, live, busyset, {"cio", "coo", "cto"})
    report(r)
    w = sorted((s, t) for _, s, t, _, _, _ in wakes)
    want = sorted([("junior_02", "tier-haiku"), ("officer_05", "tier-opus"), ("senior_01", "tier-sonnet"), ("officer_01", "ask-opus")])
    ok = (w == want and [p[0] for p in promote] == ["n1"] and [s[0] for s in stuck] == ["o1"] and [f[0] for f in fire] == ["tier-fable", "seat-cio"]
          and ("seat-junior_04", 1) in unw and sum(1 for x in wakes if x[5]) == 3)
    print("WAKE_PROBE wakes=%d designer_skipped_on_tier=%d busy_skipped=%d boss_skipped=%d promote=%d stuck=%d fire_only=%d ok=%d"
          % (len(wakes), int(("officer_01", "tier-opus") not in w), int(all(s != "junior_03" for s, _ in w)), int(all(s not in ("coo", "cio") for s, _ in w)),
             len(promote), len(stuck), len(fire), int(ok)))
    return ok


if __name__ == "__main__":
    if "--probe" in sys.argv[1:]: sys.exit(0 if probe() else 1)
    seats = tiers(arg("--tiers", os.path.join(ROOT, ".github", "TIERS.tsv")))
    lv = arg("--live", None)
    live = set(lv.split(",")) if lv else {s["seat"] for s in seats if live_by_scope(s["seat"])}
    bosses = set(mode_line(os.path.join(PO, "MODE"), "BOSSES")) or {"cio", "coo", "cto"}
    r = plan(live_tubes(), seats, live, busy(arg("--claims", os.path.join(PO, "claims"))), bosses)
    report(r)
    if "--apply" in sys.argv[1:]:
        for tp, t, age in r[1]:
            p = subprocess.run(["bash", os.path.join(HERE, "s4e_msg.sh"), "queue", tp, "--tier", "opus"], capture_output=True, text=True)
            for l in (p.stdout + p.stderr).splitlines():
                if l.startswith(("queued ", "WAKE:", "⛔")): print(l)
    sys.exit(0)
