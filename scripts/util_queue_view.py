#!/usr/bin/env python3
# util_queue_view.py -- QUEUE.tsv IS A VIEW (DESIGN-PLAN fleet-queue step 12, the cio 2026-11-05; skill fleet-bus section 8): the record of a row is its
# baton (RANK:, OWNER:, STATE:, QUEUE-JOB: in the head) and its job in the daemon; QUEUE.tsv is regenerated from them by every bus state write and by
# every tick, never edited by hand. A job's state overrides a stale STATE: a reserved job reads CLAIMED:<its claim's holder>, a ready job in a tier or
# seat tube reads QUEUED:<tube> when the baton still says CLAIMED (the lease expired), a buried job keeps the baton's parked state. A row whose baton
# carries no head lines yet (minted by an older bus) is read from the current QUEUE.tsv row and its head lines are written, so the view is self-healing.
#   --regenerate      rewrite QUEUE.tsv (header lines kept) and QUEUE.tsv.sig (sha256 of the body); prints VIEW rows=N tubes=M
#   --check           VIEW rows=N tubes=M age_s=S hand_edits=0|1 generated=1|0  (age_s since the last regeneration; hand_edits=1 when the file differs
#                     from its signature, i.e. something other than this tool wrote it last); rc 0 only when hand_edits=0 and generated=1
import os, re, sys, time, hashlib, glob, importlib.util
PO = os.environ.get("S4E_POST", "/home/resources/postoffice"); S4E = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
Q = os.path.join(PO, "QUEUE.tsv"); SIG = Q + ".sig"; TASKS = os.path.join(PO, "tasks"); LOCK = os.path.join(PO, ".mint.lock")
HEAD = re.compile(r"^(RANK|OWNER|STATE|QUEUE-JOB|LINKS): ?(.*)$", re.M)
def queue_client():
    spec = importlib.util.spec_from_file_location("util_queue", os.path.join(S4E, "harness", "scripts", "util_queue.py")); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    try: return m.client()
    except SystemExit: return None, None
def body_hash(text): return hashlib.sha256(text.encode()).hexdigest()
def read_queue():
    header, rows = [], {}
    try:
        for l in open(Q):
            if l.startswith("#"): header.append(l.rstrip("\n")); continue
            f = l.rstrip("\n").split("\t")
            if len(f) >= 4 and f[0].isdigit(): rows[f[1]] = (int(f[0]), f[2], f[3])
    except OSError: pass
    return header, rows
def head_of(path):
    try: s = open(path).read()
    except OSError: return None, None
    top = s.split("\n## ", 1)[0]; d = {}
    for m in HEAD.finditer(top): d.setdefault(m.group(1), m.group(2).strip())
    return s, d
def set_head(path, s, key, value):
    if re.search(r"^%s:" % key, s, re.M): s = re.sub(r"^%s:.*$" % key, "%s: %s" % (key, value), s, count=1, flags=re.M)
    else: s = re.sub(r"^(LINKS:.*)$", lambda m: m.group(1) + "\n%s: %s" % (key, value), s, count=1, flags=re.M)
    open(path, "w").write(s); return s
def mint_ts(d): m = re.search(r"(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ)", d.get("LINKS", "")); return m.group(1) if m else ""
def claim_rule(topic, state):
    try: lines = open(os.path.join(PO, "claims", topic + ".claim")).read().splitlines()
    except OSError: return state
    if not lines: return state
    holder = lines[0].strip()
    if any(l.strip() == "DONE" for l in lines): return "DONE"
    if any(l.startswith("PARKED-AROUND") for l in lines) and re.match(r"^(PARKED|BLOCKED-ON|GRANT-NEEDED|RETIRED|SUPERSEDED)", state): return state
    if re.match(r"^MEASURING:%s:" % re.escape(holder), state): return state
    if any(l.startswith("ASSIGNED-BY") for l in lines) and not any(l.startswith(("RUNNING", "RESERVED")) for l in lines): return "ASSIGNED:" + holder
    return "CLAIMED:" + holder
def claim_reserved(topic):
    try: return any(l.startswith("RESERVED job=") for l in open(os.path.join(PO, "claims", topic + ".claim")))
    except OSError: return False
def claim_holder(topic):
    try: return open(os.path.join(PO, "claims", topic + ".claim")).readline().strip()
    except OSError: return ""
def regenerate():
    gs, c = queue_client(); header, old = read_queue(); out = []; healed = 0; tubes = set()
    for p in sorted(glob.glob(os.path.join(TASKS, "*.task.md"))):
        topic = os.path.basename(p)[:-len(".task.md")]; s, d = head_of(p)
        if s is None: continue
        if "STATE" not in d or "RANK" not in d or "OWNER" not in d:
            if topic not in old: continue   # a baton with no row and no head lines is an archive, not a row
            rank, owner, state = old[topic]
            s = set_head(p, s, "RANK", str(rank)); s = set_head(p, s, "OWNER", owner); s = set_head(p, s, "STATE", state); healed += 1
            d.update({"RANK": str(rank), "OWNER": owner, "STATE": state})
        rank, owner, state = int(d["RANK"] or 2), d["OWNER"], d["STATE"]
        state = claim_rule(topic, state)   # THE CLAIM IS THE LOCK: a claim file outranks a stale STATE line (a seat on an older bus writes no STATE line)
        if state == "DONE":   # a DONE row leaves the view and lands once in QUEUE.done.tsv (the sweep's move, done here)
            if topic in old:
                dq = os.path.join(PO, "QUEUE.done.tsv")
                try: have = any(l.split("\t")[1:2] == [topic] for l in open(dq))
                except OSError: have = False
                if not have: open(dq, "a").write("%d\t%s\t%s\tDONE\n" % (rank, topic, owner))
            continue
        m = re.match(r"^(\d+) tube=(\S+)", d.get("QUEUE-JOB", ""))
        if m and c is not None:
            try:
                st = c.stats_job(int(m.group(1))); tubes.add(st["tube"]); js = st["state"]
                if js == "reserved":
                    h = claim_holder(topic)
                    if h and not re.match(r"^(CLAIMED|RUNNING|MEASURING|ASSIGNED):", state): state = "CLAIMED:" + h
                elif js in ("ready", "delayed") and re.match(r"^(CLAIMED|RUNNING):", state) and claim_reserved(topic): state = "QUEUED:" + st["tube"]   # the lease expired: the claim says RESERVED, the job is back
            except gs.NotFoundError: pass
        out.append((rank, mint_ts(d), topic, owner, state))
    out.sort(key=lambda r: (r[0], r[1] and -int(r[1].replace("-", "").replace("T", "").replace(":", "").rstrip("Z")) or 0, r[2]))
    body = "".join("%d\t%s\t%s\t%s\n" % (r[0], r[2], r[3], r[4]) for r in out)
    text = "\n".join(header) + ("\n" if header else "") + body
    got = False
    for _ in range(30):
        try: os.mkdir(LOCK); got = True; break
        except FileExistsError: time.sleep(0.1)
    try:
        tmp = Q + ".view.tmp"; open(tmp, "w").write(text); os.chmod(tmp, 0o664); os.replace(tmp, Q); open(SIG, "w").write(body_hash(text) + "\n")
    finally:
        if got:
            try: os.rmdir(LOCK)
            except OSError: pass
    if c is not None: c.close()
    print("VIEW rows=%d tubes=%d healed=%d lock=%d" % (len(out), len(tubes), healed, int(got))); return 0
def check():
    try: sig = open(SIG).read().strip(); age = int(time.time() - os.stat(SIG).st_mtime); gen = 1
    except OSError: sig = ""; age = 10**6; gen = 0
    try: text = open(Q).read()
    except OSError: text = ""
    hand = 0 if (gen and body_hash(text) == sig) else 1
    header, rows = read_queue(); tubes = 0; gs, c = queue_client()
    if c is not None:
        try: tubes = len(c.tubes())
        finally: c.close()
    print("VIEW rows=%d tubes=%d age_s=%d hand_edits=%d generated=%d" % (len(rows), tubes, age, hand, gen)); return 0 if (hand == 0 and gen == 1) else 1
if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["--regenerate"]: sys.exit(regenerate())
    if a[:1] == ["--check"]: sys.exit(check())
    print("usage: util_queue_view.py --regenerate | --check"); sys.exit(2)
