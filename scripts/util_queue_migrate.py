#!/usr/bin/env python3
# util_queue_migrate.py -- THE MIGRATION (DESIGN-PLAN fleet-queue step 16, the cio 2026-11-05; skill fleet-bus section 8): every live row of QUEUE.tsv gets
# its one job in its tube, once: a row ASSIGNED, CLAIMED, RUNNING or MEASURING by a seat -> a ready job in seat-<seat> (priority 100+rank); a row
# PARKED*, BLOCKED-ON, GRANT-NEEDED or PARKED-AWAITING -> a BURIED job in seat-<owner> (or tier-<tier> for an @tier owner); a FREE row is the BACKLOG
# the company men cut from and gets no job; DONE rows are left alone. A row that already carries a QUEUE-JOB whose job exists is counted, not re-put.
#   --check    counts only: MIGRATE live=N queued=N backlog=N buried=N unaccounted=N (unaccounted: a live row whose class needs a job and has none, or
#              whose state is none of the above); rc 0 only when unaccounted=0
#   --apply    puts the missing jobs (and writes QUEUE-JOB: and RANK: on each baton), logs every move to postoffice/MIGRATION.log, then prints --check
import os, re, sys, subprocess, datetime
PO = os.environ.get("S4E_POST", "/home/resources/postoffice"); S4E = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
Q = os.path.join(S4E, "harness", "scripts", "util_queue.py"); TIERS = os.path.join(S4E, ".github", "TIERS.tsv")
LIVE = re.compile(r"^(ASSIGNED|CLAIMED|RUNNING|MEASURING):([^:]+)"); PARK = re.compile(r"^(PARKED|PARKED-[A-Z-]+|BLOCKED-ON|GRANT-NEEDED|RETIRED|SUPERSEDED)(:|$)")
import importlib.util
_spec = importlib.util.spec_from_file_location("util_queue", Q); _uq = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(_uq)
_GS, _C = _uq.client()   # one connection for the whole run (a subprocess per row read 465 rows in 80 s; the live fleet moves rows faster than that)
def q(*args):
    try:
        if args[0] == "stats-job":
            st = _C.stats_job(int(args[1])); return 0, "\t".join(str(st[k]) for k in ("id", "tube", "state"))
        if args[0] in ("put", "put-buried"):
            tube, topic = args[1], args[2]; pri = int(args[args.index("--pri") + 1]); ttr = int(args[args.index("--ttr") + 1])
            _C.use(tube); jid = _C.put(topic, priority=pri, ttr=ttr)
            if args[0] == "put-buried": _C.bury(_C.reserve_job(jid), priority=pri)
            return 0, str(jid)
    except _GS.NotFoundError:
        return 1, ""
    except Exception as e:
        return 2, str(e)
    r = subprocess.run([sys.executable, Q] + list(args), capture_output=True, text=True); return r.returncode, r.stdout.strip()
def tier_of(seat):
    try:
        for l in open(TIERS):
            f = l.rstrip("\n").split("\t")
            if not l.startswith("#") and len(f) > 6 and f[0] == seat: return {"1": "fable", "2": "opus", "3": "sonnet", "4": "haiku"}.get(f[6], "haiku")
    except OSError: pass
    return None
def ttr_for(owner):
    t = tier_of(owner) or "haiku"; return {"fable": 14400, "opus": 14400, "sonnet": 7200}.get(t, 3600)
def baton(topic): return os.path.join(PO, "tasks", topic + ".task.md")
def job_of(topic):
    try:
        for l in open(baton(topic)):
            m = re.match(r"^QUEUE-JOB: (\d+) tube=(\S+)", l)
            if m: return int(m.group(1)), m.group(2)
    except OSError: pass
    return None
def job_state(jid):
    rc, out = q("stats-job", str(jid)); return out.split("\t")[2] if rc == 0 and "\t" in out else None
def set_head(topic, key, value):
    p = baton(topic)
    try: s = open(p).read()
    except OSError: return False
    if re.search(r"^%s:" % re.escape(key), s, re.M): s = re.sub(r"^%s:.*$" % re.escape(key), "%s: %s" % (key, value), s, count=1, flags=re.M)
    else: s = re.sub(r"^(LINKS:.*)$", lambda m: m.group(1) + "\n%s: %s" % (key, value), s, count=1, flags=re.M)
    open(p, "w").write(s); return True
def rows():
    out = []
    for l in open(os.path.join(PO, "QUEUE.tsv")):
        f = l.rstrip("\n").split("\t")
        if l.startswith("#") or len(f) < 4 or not f[0].isdigit(): continue
        out.append((int(f[0]), f[1], f[2], f[3]))
    return out
def classify(rank, topic, owner, state):
    if state == "DONE": return "done", None, None
    if state == "FREE": return "backlog", None, None
    m = LIVE.match(state)
    if m: return "live", "seat-" + m.group(2), 100 + rank
    if PARK.match(state):
        tube = ("tier-" + owner[1:]) if owner.startswith("@") else ("seat-" + owner)
        return "parked", tube, 100 + rank
    return "unknown", None, None
def main(a):
    apply = "--apply" in a; log = open(os.path.join(PO, "MIGRATION.log"), "a") if apply else None
    live = queued = backlog = buried = unacc = put_n = 0; now = datetime.datetime.now(datetime.UTC).strftime("%FT%H:%MZ")
    for rank, topic, owner, state in rows():
        cls, tube, pri = classify(rank, topic, owner, state)
        if cls == "done": continue
        live += 1
        if cls == "backlog": backlog += 1; continue
        if cls == "unknown": unacc += 1; print("UNKNOWN %s %s" % (topic, state), file=sys.stderr); continue
        j = job_of(topic); st = job_state(j[0]) if j else None
        if cls == "live" and st in ("ready", "reserved"): queued += 1; continue
        if cls == "parked" and st in ("buried", "ready", "reserved"): buried += 1; continue
        if not os.path.isfile(baton(topic)): unacc += 1; print("NO-BATON %s" % topic, file=sys.stderr); continue
        if not apply:   # a row in flight between two verbs reads jobless for a second: re-read once after a settle before counting it
            import time; time.sleep(2); j = job_of(topic); st = job_state(j[0]) if j else None
            if (cls == "live" and st in ("ready", "reserved")) or (cls == "parked" and st in ("buried", "ready", "reserved")): queued += 1; continue
            unacc += 1; print("MISSING-JOB %s class=%s state=%s job=%s job_state=%s" % (topic, cls, state, j, st), file=sys.stderr); continue
        ttr = ttr_for(owner if not owner.startswith("@") else tube.split("-", 1)[1])
        rc, out = q("put-buried" if cls == "parked" else "put", tube, topic, "--pri", str(pri), "--ttr", str(ttr))
        if rc != 0 or not out.isdigit(): unacc += 1; print("PUT-FAILED %s %s: %s" % (topic, tube, out[:120]), file=sys.stderr); continue
        set_head(topic, "QUEUE-JOB", "%s tube=%s" % (out, tube)); set_head(topic, "RANK", str(rank)); put_n += 1
        log.write("%s %s %s job=%s tube=%s pri=%d ttr=%d state=%s\n" % (now, "BURIED" if cls == "parked" else "PUT", topic, out, tube, pri, ttr, state))
        if cls == "parked": buried += 1
        else: queued += 1
    if log: log.close()
    print("MIGRATE live=%d queued=%d backlog=%d buried=%d unaccounted=%d%s" % (live, queued, backlog, buried, unacc, (" put=%d" % put_n) if apply else ""))
    sys.exit(0 if unacc == 0 else 1)
main(sys.argv[1:])
