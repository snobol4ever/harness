#!/usr/bin/env python3
# util_queue_view.py -- QUEUE.tsv IS A VIEW (DESIGN-PLAN fleet-queue step 12, the cio 2026-11-05; skill fleet-bus section 8): the record of a row is its
# baton (RANK:, OWNER:, STATE:, QUEUE-JOB: in the head) and its job in the daemon; QUEUE.tsv is regenerated from them by every bus state write and by
# every tick, never edited by hand. A job's state overrides a stale STATE: a reserved job reads CLAIMED:<its claim's holder>, a ready job in a tier or
# seat tube reads QUEUED:<tube> when the baton still says CLAIMED (the lease expired), a buried job keeps the baton's parked state. A row whose baton
# carries no head lines yet (minted by an older bus) is read from the current QUEUE.tsv row and its head lines are written, so the view is self-healing.
#   --regenerate      rewrite QUEUE.tsv (header lines kept) and QUEUE.tsv.sig (sha256 of the body); prints VIEW rows=N tubes=M
#   --check           VIEW rows=N tubes=M age_s=S hand_edits=0|1 generated=1|0  (age_s since the last regeneration; hand_edits=1 when the file differs
#                     from its signature, i.e. something other than this tool wrote it last); rc 0 only when hand_edits=0 and generated=1
import os, re, sys, time, hashlib, glob
PO = os.environ.get("S4E_POST", "/home/resources/postoffice"); S4E = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
Q = os.path.join(PO, "QUEUE.tsv"); SIG = Q + ".sig"; TASKS = os.path.join(PO, "tasks"); LOCK = os.path.join(PO, ".mint.lock")
HEAD = re.compile(r"^(RANK|OWNER|STATE|QUEUE-JOB|LINKS): ?(.*)$", re.M)
def tubes_of(states): return set(s[len("QUEUED:"):] for s in states if s.startswith("QUEUED:") and len(s) > len("QUEUED:"))   # bus-one-queue: the tubes are the distinct T of a column QUEUED:T
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
    header, old = read_queue(); out = []; healed = 0; adopted = 0
    try: closed = set(l.split("\t")[1] for l in open(os.path.join(PO, "QUEUE.done.tsv")) if not l.startswith("#") and l.count("\t") >= 3)
    except OSError: closed = set()   # fleet-control step 9b (the cio, 2026-11-07 14:3x): QUEUE.done.tsv is the memory; a topic in it is closed whatever its baton or claim says
    # AN UNSIGNED QUEUE.tsv WAS WRITTEN BY SOMETHING ELSE SINCE THE LAST REGENERATION (a seat on an older bus writes the row, not the baton): for every row
    # whose QUEUE.tsv state or owner differs from its baton, the file is the newer truth and the baton adopts it (the cao's lost park, 2026-11-06 00:39Z)
    try: signed = open(SIG).read().strip() == body_hash(open(Q).read())
    except OSError: signed = False
    for p in sorted(glob.glob(os.path.join(TASKS, "*.task.md"))):
        topic = os.path.basename(p)[:-len(".task.md")]; s, d = head_of(p)
        if s is None: continue
        if "STATE" not in d or "RANK" not in d or "OWNER" not in d:
            if topic not in old: continue   # a baton with no row and no head lines is an archive, not a row
            rank, owner, state = old[topic]
            s = set_head(p, s, "RANK", str(rank)); s = set_head(p, s, "OWNER", owner); s = set_head(p, s, "STATE", state); healed += 1
            d.update({"RANK": str(rank), "OWNER": owner, "STATE": state})
        rank, owner, state = int(d["RANK"] or 2), d["OWNER"], d["STATE"]
        if not signed and topic in old and (old[topic][2] != state or old[topic][1] != owner):
            rank, owner, state = old[topic]; s = set_head(p, s, "OWNER", owner); s = set_head(p, s, "STATE", state); s = set_head(p, s, "RANK", str(rank)); adopted += 1
        state = claim_rule(topic, state)   # THE CLAIM IS THE LOCK: a claim file outranks a stale STATE line (a seat on an older bus writes no STATE line)
        if topic in closed: state = "DONE"   # five DONE rows came back FREE on 2026-11-07 when their claims were collected as residue and a state repair rewrote the column (the cao's reading)
        if state == "DONE":   # a DONE row leaves the view and lands once in QUEUE.done.tsv (the sweep's move, done here)
            if topic in old:
                dq = os.path.join(PO, "QUEUE.done.tsv")
                try: have = any(l.split("\t")[1:2] == [topic] for l in open(dq))
                except OSError: have = False
                if not have: open(dq, "a").write("%d\t%s\t%s\tDONE\n" % (rank, topic, owner))
            continue
        if re.match(r"^(RETIRED|SUPERSEDED)(:|$)", state):   # fleet-control step 9 (the cio, 2026-11-07, Lon: "process the 99 ... rows by either using or
            if topic in old:   # forgetting/deleting"): a retired or superseded row is terminal; it leaves the view and lands once in QUEUE.retired.tsv (the memory)
                rq = os.path.join(PO, "QUEUE.retired.tsv")
                try: have = any(l.split("\t")[1:2] == [topic] for l in open(rq))
                except OSError: have = False
                if not have: open(rq, "a").write("%d\t%s\t%s\t%s\n" % (rank, topic, owner, state))
            continue
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
    tubes = tubes_of(r[4] for r in out)
    print("VIEW rows=%d tubes=%d healed=%d adopted=%d signed_before=%d lock=%d" % (len(out), len(tubes), healed, adopted, int(signed), int(got))); return 0
def check():
    try: sig = open(SIG).read().strip(); age = int(time.time() - os.stat(SIG).st_mtime); gen = 1
    except OSError: sig = ""; age = 10**6; gen = 0
    try: text = open(Q).read()
    except OSError: text = ""
    hand = 0 if (gen and body_hash(text) == sig) else 1
    header, rows = read_queue(); tubes = len(tubes_of(v[2] for v in rows.values()))
    print("VIEW rows=%d tubes=%d age_s=%d hand_edits=%d generated=%d" % (len(rows), tubes, age, hand, gen)); return 0 if (hand == 0 and gen == 1) else 1
def probe_retire():
    """--probe-retire: on a scratch postoffice (S4E_POST, never the live one) two rows, one FREE and one SUPERSEDED:x, each with a baton; after --regenerate the
    superseded row is out of QUEUE.tsv and in QUEUE.retired.tsv once, the FREE row stays; a second --regenerate appends nothing. Prints one RETIRE_PROBE line; rc 0 ok=1."""
    import subprocess, tempfile, shutil
    w = tempfile.mkdtemp(prefix="s4e-view-probe-", dir=os.environ.get("S4E_SCRATCH") or "/tmp/s4e/%s" % os.environ.get("S4E_SEAT", "cio")); os.makedirs(w + "/tasks")
    def baton(t, st): open("%s/tasks/%s.task.md" % (w, t), "w").write("# TASK %s\nRANK: 2\nOWNER: cio\nSTATE: %s\nLINKS: minted 2026-11-07T00:00:00Z\n\n## NEXT\n- x\n" % (t, st))
    baton("probe-live", "FREE"); baton("probe-dead", "SUPERSEDED:x"); baton("probe-gone", "RETIRED:y"); baton("probe-closed", "FREE")
    open(w + "/QUEUE.done.tsv", "w").write("2\tprobe-closed\tcio\tDONE\n")
    open(w + "/QUEUE.tsv", "w").write("# header\n2\tprobe-live\tcio\tFREE\n2\tprobe-dead\tcio\tSUPERSEDED:x\n2\tprobe-gone\tcio\tRETIRED:y\n2\tprobe-closed\tcio\tFREE\n")
    env = dict(os.environ, S4E_POST=w, S4E_QUEUE_NO_DAEMON="1")
    r1 = subprocess.run([sys.executable, "-I", os.path.abspath(__file__), "--regenerate"], env=env, capture_output=True, text=True)
    q1 = open(w + "/QUEUE.tsv").read(); ret1 = open(w + "/QUEUE.retired.tsv").read() if os.path.exists(w + "/QUEUE.retired.tsv") else ""
    r2 = subprocess.run([sys.executable, "-I", os.path.abspath(__file__), "--regenerate"], env=env, capture_output=True, text=True)
    ret2 = open(w + "/QUEUE.retired.tsv").read() if os.path.exists(w + "/QUEUE.retired.tsv") else ""
    live_stays = "\tprobe-live\t" in q1; dead_out = "probe-dead" not in q1 and "probe-gone" not in q1 and "probe-closed" not in q1
    closed_once = open(w + "/QUEUE.done.tsv").read().count("\tprobe-closed\t") == 1
    landed_once = ret1.count("\tprobe-dead\t") == 1 and ret1.count("\tprobe-gone\t") == 1 and "SUPERSEDED:x" in ret1 and "RETIRED:y" in ret1
    idempotent = ret2 == ret1
    ok = int(r1.returncode == 0 and r2.returncode == 0 and live_stays and dead_out and landed_once and idempotent and closed_once)
    shutil.rmtree(w, ignore_errors=True)
    print("RETIRE_PROBE rc1=%d rc2=%d live_stays=%d dead_out=%d landed_once=%d idempotent=%d closed_stays_closed=%d ok=%d" % (r1.returncode, r2.returncode, live_stays, dead_out, landed_once, idempotent, closed_once, ok)); return 0 if ok else 1
if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["--regenerate"]: sys.exit(regenerate())
    if a[:1] == ["--check"]: sys.exit(check())
    if a[:1] == ["--probe-retire"]: sys.exit(probe_retire())
    print("usage: util_queue_view.py --regenerate | --check | --probe-retire"); sys.exit(2)
