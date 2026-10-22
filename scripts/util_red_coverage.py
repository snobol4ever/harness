#!/usr/bin/env python3
"""util_red_coverage.py [--suite KEY ...] [--limit N] [--engines] -- EVERY RED HAS A ROW, PER CLASS NOT PER ENTRY (ceo CEO-1887 line 2).

Joins the coo's /home/resources/progress/results.tsv (the newest reading per suite, program and mode) with the live batons under the
postoffice (every QUEUE row not DONE, RETIRED or SUPERSEDED): a red is ROWED when the program's name (its last path component, or the
entry name after a family prefix) appears in a live baton's text, UNROWED otherwise. Unrowed reds are grouped into CLASSES by their
fingerprint (results.tsv column 13), else by their note with digits stripped (column 12), else by outcome, and each class names one
witness: the ceo mints one row per class with that witness, never one per entry (XsbTests' 733 reds are not 733 rows).
UNGRADED and UNGRADABLE rows are not reds here; they are completeness (line 3) and are counted beside the reds.
Port-engine suites (a key with @) are skipped unless --engines.
Board line per suite: RED_COVERAGE_BOARD suite=<k> reds=<n> rowed=<r> unrowed=<u> classes=<c> ungraded=<g>
rc 0 no unrowed class over the suites read · rc 1 an unrowed class remains · rc 2 could not read.
"""
import sys, os, re, glob
RES = "/home/resources/progress/results.tsv"
PO = "/home/resources/postoffice"
REDS = {"FAIL", "CRASH", "HANG", "REJECT", "OOM", "UNPROVEN", "SKIP"}
COMPLETENESS = {"UNGRADED", "UNGRADABLE", "OUTSIDE"}
def live_batons():
    live = []
    for l in open(PO + "/QUEUE.tsv", "rb").read().decode("utf-8").split("\n"):
        f = l.split("\t")
        if len(f) >= 4 and f[0].isdigit() and f[3].split(":")[0] not in ("DONE", "RETIRED", "SUPERSEDED"):
            p = "%s/tasks/%s.task.md" % (PO, f[1])
            if os.path.isfile(p): live.append((f[1], open(p, encoding="utf-8", errors="replace").read().lower()))
    return live
def names(program):
    n = program.lower(); out = {n}
    base = n.rsplit("/", 1)[-1]; out.add(base)
    if ":" in base: out.update(x for x in base.split(":") if len(x) > 3)
    if "#" in base: out.add(base.split("#")[0])
    out.add(re.sub(r"\.(pl|pas|icn|sno|sc|raku|reb|t)$", "", base))
    return {x for x in out if len(x) > 3}
def main(argv):
    only = []; limit = 8; engines = False; i = 0
    while i < len(argv):
        if argv[i] == "--suite": only.append(argv[i + 1]); i += 2
        elif argv[i] == "--limit": limit = int(argv[i + 1]); i += 2
        elif argv[i] == "--engines": engines = True; i += 1
        else: i += 1
    if not os.path.isfile(RES): print("REFUSE(2): no %s" % RES); return 2
    newest = {}
    with open(RES, encoding="utf-8", errors="replace") as fh:
        hdr = fh.readline().rstrip("\n").split("\t")
        for l in fh:
            f = l.rstrip("\n").split("\t")
            if len(f) < 10: continue
            k = (f[5], f[7], f[8])
            if k not in newest or f[0] > newest[k][0]: newest[k] = f
    live = live_batons(); blob = "\n".join(t for _, t in live)
    suites = sorted({k[0] for k in newest if (engines or "@" not in k[0]) and (not only or k[0] in only)})
    total_unrowed_classes = 0
    import datetime
    now = datetime.datetime.utcnow()
    def ts(s):
        try: return datetime.datetime.strptime(s[:19], "%Y-%m-%dT%H:%M:%S")
        except ValueError: return None
    for s in suites:
        reds = {}; ungraded = 0; dropped = 0
        top = max((ts(f[0]) for (sk, _, _), f in newest.items() if sk == s and ts(f[0])), default=None)
        if top is None: continue
        if (now - top).days >= 7:
            print("RED_COVERAGE_STALE suite=%s newest=%s (older than 7 days: a retired key or an ungraded suite; not counted)" % (s, top.strftime("%Y-%m-%d")))
            continue
        for (sk, prog, mode), f in newest.items():
            if sk != s: continue
            t = ts(f[0])
            if t is None or (top - t).days >= 3: dropped += 1; continue
            if f[9] in COMPLETENESS: ungraded += 1
            elif f[9] in REDS: reds.setdefault(prog, []).append(f)
        if not reds and not ungraded: continue
        rowed = {}; unrowed = {}
        for prog, fs in reds.items():
            hit = any(n in blob for n in names(prog))
            (rowed if hit else unrowed)[prog] = fs
        classes = {}
        for prog, fs in unrowed.items():
            f = fs[0]; fp = f[12] if len(f) > 12 and f[12] else ""
            key = fp or (re.sub(r"\d+", "#", f[11]) if len(f) > 11 and f[11] else "") or f[9]
            classes.setdefault(key, []).append((prog, f[9], f[11] if len(f) > 11 else ""))
        total_unrowed_classes += len(classes)
        print("RED_COVERAGE_BOARD suite=%s reds=%d rowed=%d unrowed=%d classes=%d ungraded=%d" % (s, len(reds), len(rowed), len(unrowed), len(classes), ungraded))
        for key, members in sorted(classes.items(), key=lambda kv: -len(kv[1]))[:limit]:
            w = members[0]
            print("  class %-36s n=%-4d witness %s  outcome %s  note %s" % (key[:36], len(members), w[0], w[1], w[2][:80]))
    print("RED_COVERAGE_TOTAL suites=%d unrowed_classes=%d" % (len(suites), total_unrowed_classes))
    return 1 if total_unrowed_classes else 0
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
