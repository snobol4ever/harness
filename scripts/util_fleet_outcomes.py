#!/usr/bin/env python3
"""util_fleet_outcomes.py -- THE OUTCOME LEDGER OF DESIGN-PLAN fleet-queue (step 15; skill fleet-bus section 8 "The outcome ledger"; the coo's
assignment COO-474, 2026-11-05, on Lon's word: "Monitor the failure rate, i.e. escalation rate of the tasks, and ADJUST ACCORDINGLY.").

FLEET.db is SQLite (stdlib sqlite3, WAL): ONE ROW PER TICK PER TUBE and ONE ROW PER LEASE, ASK, ESCALATION AND WAKE EVENT. The tick (step 10, box_tick.sh)
is the writer; this file is the schema, the writers it calls and the reader the coo runs. Nothing here knows a seat's name: a tube's tier is
passed by the writer (from TIERS.tsv, step 2); the only names fixed here are the four tiers and the `tier-` tube prefix the design itself names.

  --check [--window-h N] [--stale-s S]   print the window's numbers (default 24 h); rc 0 GREEN, rc 1 RED (no tick in the window, or the newest tick
                                         is older than --stale-s, default 300: the tick writes every 60 s), rc 2 could not read (no db, a foreign
                                         schema, a failed integrity check). Never creates the db.
  --init                                 create the db (every writer creates it too)
  --selftest                             prove every number on a fixture db in a scratch directory: rc 0 / 1
  tick [--ts T] --stdin | --tube X --tier Y --ready N --reserved N --delayed N --buried N --oldest-ready-s S [--idle-above N]
                                         --stdin reads TSV lines: tube tier ready reserved delayed buried oldest_ready_s [idle_above]
                                         (one transaction for the whole tick; a repeated (ts, tube) replaces its row)
  lease-start --topic T --tube X --tier Y --seat S [--waited-s N]      a job reserved (prints LEASE id=N)
  lease-end   --topic T --seat S --outcome done|escalated|buried|expired|released     closes that seat's newest open lease on that topic
  ask-put     --topic Q --asker S --tube X          ask-answer --topic Q --by S
  escalation  --topic T --from-tube X --to-tube Z --from-tier A --to-tier B --rung N --via try|policy --measurement 0|1
  wake        --seat S --topic T --by hook|tick|monitor|hand
  common: --db PATH (else $S4E_FLEET_DB, else /home/resources/progress/FLEET.db)   --now EPOCH   (writers also take --ts EPOCH)

THE NUMBERS (every one is a query over the rows in the window, nearest-rank percentiles, minutes floored):
  ticks              distinct tick timestamps in the window
  p50/p95_ready_min  over the `tier-` tubes' tick rows that had a job ready: the age of the OLDEST ready job at that tick (the step-17 minute measure;
                     a job stuck in a tube is counted at every tick it waits, so it cannot hide)
  ask_p50/p95_min    ask latency, put to answer; an ask still open counts as now minus put (a stuck ask shows, it is never dropped)
  lease_expiries     leases that ended `expired` in the window (a dead session; the tube returned the job)
  hand_wakes         wake rows `by=hand` in the window (a person woke a seat; the acceptance is zero)
  served_p95_min     over leases started in the window: the minutes the job sat ready before it was reserved
  ESCALATION         per tier, over the LAST 20 CLOSURES of that tier (not the window): a closure is a lease that ended `done` or `escalated`;
                     rate = escalated / closed; `buried`, `expired` and `released` are not closures. NA when the tier has no closure yet.
rc 0 GREEN | 1 RED, naming what is red | 2 could not measure. The db's rows are the record; a hand edit of them is a forgery.
"""
import argparse, math, os, shutil, sqlite3, subprocess, sys, tempfile, time

DEFAULT_DB = "/home/resources/progress/FLEET.db"
SCHEMA_VERSION = 1
TIERS = ("haiku", "sonnet", "opus", "fable")
OUTCOMES = ("done", "escalated", "buried", "expired", "released")
VIAS = ("try", "policy")
WAKERS = ("hook", "tick", "monitor", "hand")
TIER_TUBE_PREFIX = "tier-"
CLOSURE_WINDOW = 20


def q(vals):
    return ", ".join("'%s'" % v for v in vals)


SCHEMA = """
CREATE TABLE IF NOT EXISTS tick(
  ts INTEGER NOT NULL, tube TEXT NOT NULL, tier TEXT NOT NULL CHECK(tier IN (%(tiers)s)),
  ready INTEGER NOT NULL CHECK(ready >= 0), reserved INTEGER NOT NULL CHECK(reserved >= 0),
  delayed INTEGER NOT NULL CHECK(delayed >= 0), buried INTEGER NOT NULL CHECK(buried >= 0),
  oldest_ready_s INTEGER NOT NULL CHECK(oldest_ready_s >= 0), idle_above INTEGER NOT NULL DEFAULT 0 CHECK(idle_above >= 0),
  PRIMARY KEY(ts, tube)) WITHOUT ROWID;
CREATE INDEX IF NOT EXISTS tick_tube ON tick(tube, ts);
CREATE TABLE IF NOT EXISTS lease(
  id INTEGER PRIMARY KEY, topic TEXT NOT NULL, tube TEXT NOT NULL, tier TEXT NOT NULL CHECK(tier IN (%(tiers)s)), seat TEXT NOT NULL,
  start_ts INTEGER NOT NULL, waited_s INTEGER NOT NULL DEFAULT 0 CHECK(waited_s >= 0),
  end_ts INTEGER, outcome TEXT CHECK(outcome IS NULL OR outcome IN (%(outcomes)s)),
  CHECK((end_ts IS NULL) = (outcome IS NULL)));
CREATE INDEX IF NOT EXISTS lease_closure ON lease(tier, end_ts);
CREATE INDEX IF NOT EXISTS lease_open ON lease(topic, seat) WHERE end_ts IS NULL;
CREATE TABLE IF NOT EXISTS ask(
  id INTEGER PRIMARY KEY, topic TEXT NOT NULL UNIQUE, asker TEXT NOT NULL, tube TEXT NOT NULL,
  put_ts INTEGER NOT NULL, answered_ts INTEGER, answered_by TEXT, CHECK((answered_ts IS NULL) = (answered_by IS NULL)));
CREATE TABLE IF NOT EXISTS escalation(
  id INTEGER PRIMARY KEY, ts INTEGER NOT NULL, topic TEXT NOT NULL, from_tube TEXT NOT NULL, to_tube TEXT NOT NULL,
  from_tier TEXT NOT NULL CHECK(from_tier IN (%(tiers)s)), to_tier TEXT NOT NULL CHECK(to_tier IN (%(tiers)s)),
  rung INTEGER NOT NULL CHECK(rung >= 2), via TEXT NOT NULL CHECK(via IN (%(vias)s)), measurement INTEGER NOT NULL CHECK(measurement IN (0, 1)));
CREATE TABLE IF NOT EXISTS wake(
  id INTEGER PRIMARY KEY, ts INTEGER NOT NULL, seat TEXT NOT NULL, topic TEXT NOT NULL, by TEXT NOT NULL CHECK(by IN (%(wakers)s)));
CREATE INDEX IF NOT EXISTS wake_ts ON wake(ts);
""" % {"tiers": q(TIERS), "outcomes": q(OUTCOMES), "vias": q(VIAS), "wakers": q(WAKERS)}


class Refuse(Exception):
    pass


def open_rw(path):
    d = os.path.dirname(os.path.abspath(path))
    if not os.path.isdir(d):
        raise Refuse("no directory %s for the ledger" % d)
    c = sqlite3.connect(path, timeout=10, isolation_level=None)
    c.execute("PRAGMA busy_timeout=10000")
    c.execute("PRAGMA journal_mode=WAL")
    c.execute("PRAGMA synchronous=NORMAL")
    v = c.execute("PRAGMA user_version").fetchone()[0]
    if v not in (0, SCHEMA_VERSION):
        raise Refuse("%s is schema version %d, this file writes %d" % (path, v, SCHEMA_VERSION))
    c.executescript(SCHEMA)
    if v == 0:
        c.execute("PRAGMA user_version=%d" % SCHEMA_VERSION)
    return c


def open_ro(path):
    if not os.path.isfile(path):
        raise Refuse("no ledger at %s (the tick has not written one)" % path)
    try:
        c = sqlite3.connect("file:%s?mode=ro" % path, uri=True, timeout=10)
        c.execute("PRAGMA busy_timeout=10000")
        v = c.execute("PRAGMA user_version").fetchone()[0]
        if v != SCHEMA_VERSION:
            raise Refuse("%s is schema version %d, this file reads %d" % (path, v, SCHEMA_VERSION))
        r = c.execute("PRAGMA quick_check").fetchone()[0]
        if r != "ok":
            raise Refuse("%s fails quick_check: %s" % (path, r))
        for t in ("tick", "lease", "ask", "escalation", "wake"):
            c.execute("SELECT 1 FROM %s LIMIT 1" % t)
    except sqlite3.Error as e:
        raise Refuse("cannot read %s: %s" % (path, e))
    return c


def pct(vals, p):
    if not vals:
        return 0
    s = sorted(vals)
    return s[max(0, math.ceil(p * len(s) / 100.0) - 1)]


def minutes(s):
    return int(s) // 60


def need(cond, msg):
    if not cond:
        raise Refuse(msg)


def w_tick(c, ts, rows):
    need(rows, "a tick with no tube rows writes nothing")
    c.execute("BEGIN IMMEDIATE")
    try:
        c.executemany("INSERT OR REPLACE INTO tick(ts, tube, tier, ready, reserved, delayed, buried, oldest_ready_s, idle_above) VALUES (?,?,?,?,?,?,?,?,?)",
                      [(ts,) + r for r in rows])
        c.execute("COMMIT")
    except sqlite3.Error as e:
        c.execute("ROLLBACK")
        raise Refuse("tick refused: %s" % e)
    return "TICK ts=%d rows=%d" % (ts, len(rows))


def w_one(c, sql, args, what):
    try:
        cur = c.execute(sql, args)
    except sqlite3.Error as e:
        raise Refuse("%s refused: %s" % (what, e))
    return cur


def w_lease_start(c, ts, topic, tube, tier, seat, waited):
    cur = w_one(c, "INSERT INTO lease(topic, tube, tier, seat, start_ts, waited_s) VALUES (?,?,?,?,?,?)", (topic, tube, tier, seat, ts, waited), "lease-start")
    return "LEASE id=%d topic=%s seat=%s tier=%s" % (cur.lastrowid, topic, seat, tier)


def w_lease_end(c, ts, topic, seat, outcome):
    c.execute("BEGIN IMMEDIATE")
    try:
        r = c.execute("SELECT id, tier FROM lease WHERE topic=? AND seat=? AND end_ts IS NULL ORDER BY id DESC LIMIT 1", (topic, seat)).fetchone()
        need(r, "lease-end: seat %s holds no open lease on %s" % (seat, topic))
        c.execute("UPDATE lease SET end_ts=?, outcome=? WHERE id=?", (ts, outcome, r[0]))
        c.execute("COMMIT")
    except (sqlite3.Error, Refuse) as e:
        c.execute("ROLLBACK")
        raise e if isinstance(e, Refuse) else Refuse("lease-end refused: %s" % e)
    return "LEASE-END id=%d tier=%s outcome=%s" % (r[0], r[1], outcome)


def w_ask_put(c, ts, topic, asker, tube):
    w_one(c, "INSERT INTO ask(topic, asker, tube, put_ts) VALUES (?,?,?,?)", (topic, asker, tube, ts), "ask-put")
    return "ASK topic=%s tube=%s" % (topic, tube)


def w_ask_answer(c, ts, topic, by):
    cur = w_one(c, "UPDATE ask SET answered_ts=?, answered_by=? WHERE topic=? AND answered_ts IS NULL", (ts, by, topic), "ask-answer")
    need(cur.rowcount == 1, "ask-answer: no open ask %s" % topic)
    return "ASK-ANSWER topic=%s by=%s" % (topic, by)


def w_escalation(c, ts, a):
    w_one(c, "INSERT INTO escalation(ts, topic, from_tube, to_tube, from_tier, to_tier, rung, via, measurement) VALUES (?,?,?,?,?,?,?,?,?)",
          (ts, a.topic, a.from_tube, a.to_tube, a.from_tier, a.to_tier, a.rung, a.via, a.measurement), "escalation")
    return "ESCALATION-EVENT topic=%s %s->%s rung=%d via=%s" % (a.topic, a.from_tier, a.to_tier, a.rung, a.via)


def w_wake(c, ts, seat, topic, by):
    w_one(c, "INSERT INTO wake(ts, seat, topic, by) VALUES (?,?,?,?)", (ts, seat, topic, by), "wake")
    return "WAKE seat=%s by=%s" % (seat, by)


def parse_tick_lines(text):
    rows = []
    for n, line in enumerate(text.splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        f = line.rstrip("\n").split("\t")
        need(len(f) in (7, 8), "tick line %d: want 7 or 8 tab-separated fields, got %d" % (n, len(f)))
        try:
            nums = [int(x) for x in f[2:]]
        except ValueError:
            raise Refuse("tick line %d: a count is not an integer" % n)
        rows.append((f[0], f[1], nums[0], nums[1], nums[2], nums[3], nums[4], nums[5] if len(nums) > 5 else 0))
    return rows


def measure(c, now, window_h):
    lo = now - window_h * 3600
    m = {}
    m["ticks"] = c.execute("SELECT COUNT(DISTINCT ts) FROM tick WHERE ts >= ? AND ts <= ?", (lo, now)).fetchone()[0]
    m["newest"] = c.execute("SELECT MAX(ts) FROM tick WHERE ts <= ?", (now,)).fetchone()[0]
    ages = [r[0] for r in c.execute("SELECT oldest_ready_s FROM tick WHERE ts >= ? AND ts <= ? AND ready > 0 AND tube LIKE ?",
                                    (lo, now, TIER_TUBE_PREFIX + "%"))]
    m["ready"] = ages
    per = {}
    for tube, age in c.execute("SELECT tube, oldest_ready_s FROM tick WHERE ts >= ? AND ts <= ? AND ready > 0 AND tube LIKE ? ORDER BY tube",
                               (lo, now, TIER_TUBE_PREFIX + "%")):
        per.setdefault(tube, []).append(age)
    m["per_tube"] = per
    m["tubes"] = [r[0] for r in c.execute("SELECT DISTINCT tube FROM tick WHERE ts >= ? AND ts <= ? AND tube LIKE ? ORDER BY tube", (lo, now, TIER_TUBE_PREFIX + "%"))]
    lat, opn = [], 0
    for put, ans in c.execute("SELECT put_ts, answered_ts FROM ask WHERE put_ts >= ? AND put_ts <= ?", (lo, now)):
        if ans is None:
            opn += 1
            lat.append(max(0, now - put))
        else:
            lat.append(max(0, ans - put))
    m["asks"], m["open_asks"], m["ask_lat"] = len(lat), opn, lat
    m["expiries"] = c.execute("SELECT COUNT(*) FROM lease WHERE outcome='expired' AND end_ts >= ? AND end_ts <= ?", (lo, now)).fetchone()[0]
    m["hand_wakes"] = c.execute("SELECT COUNT(*) FROM wake WHERE by='hand' AND ts >= ? AND ts <= ?", (lo, now)).fetchone()[0]
    m["served"] = [r[0] for r in c.execute("SELECT waited_s FROM lease WHERE start_ts >= ? AND start_ts <= ?", (lo, now))]
    esc = {}
    for t in TIERS:
        rows = c.execute("SELECT outcome FROM lease WHERE tier=? AND outcome IN ('done','escalated') AND end_ts <= ? ORDER BY end_ts DESC, id DESC LIMIT ?",
                         (t, now, CLOSURE_WINDOW)).fetchall()
        esc[t] = (sum(1 for r in rows if r[0] == "escalated"), len(rows))
    m["esc"] = esc
    return m


def render(m, now, window_h, stale_s):
    out, red = [], []
    age = (now - m["newest"]) if m["newest"] is not None else None
    out.append("FLEET db=sqlite window_h=%d ticks=%d p95_ready_min=%d ask_p95_min=%d lease_expiries=%d hand_wakes=%d p50_ready_min=%d ask_p50_min=%d "
               "served_p95_min=%d asks=%d open_asks=%d age_s=%s" % (
                   window_h, m["ticks"], minutes(pct(m["ready"], 95)), minutes(pct(m["ask_lat"], 95)), m["expiries"], m["hand_wakes"],
                   minutes(pct(m["ready"], 50)), minutes(pct(m["ask_lat"], 50)), minutes(pct(m["served"], 95)), m["asks"], m["open_asks"],
                   "NA" if age is None else age))
    for tube in m["tubes"]:
        a = m["per_tube"].get(tube, [])
        out.append("TUBE tube=%s waiting_ticks=%d p50_ready_min=%d p95_ready_min=%d" % (tube, len(a), minutes(pct(a, 50)), minutes(pct(a, 95))))
    for t in TIERS:
        e, c = m["esc"][t]
        out.append("ESCALATION tier=%s escalated=%d closed=%d of=%d rate_pct=%s" % (t, e, c, CLOSURE_WINDOW, "NA" if c == 0 else (100 * e + c // 2) // c))
    if m["ticks"] == 0:
        red.append("no tick row in the last %d h: the tick (step 10) is not writing this ledger" % window_h)
    elif age is not None and age > stale_s:
        red.append("the newest tick is %d s old (limit %d s): the tick writes every 60 s" % (age, stale_s))
    for r in red:
        out.append("RED: " + r)
    return out, (1 if red else 0)


def do_check(path, now, window_h, stale_s):
    c = open_ro(path)
    try:
        out, rc = render(measure(c, now, window_h), now, window_h, stale_s)
    except sqlite3.Error as e:
        raise Refuse("cannot read %s: %s" % (path, e))
    finally:
        c.close()
    print("\n".join(out))
    return rc


def selftest():
    me = os.path.abspath(__file__)
    base = tempfile.mkdtemp(prefix="s4e_fleet_outcomes_selftest.", dir=os.environ.get("TMPDIR", "/tmp"))
    db = os.path.join(base, "FLEET.db")
    now = 1_800_000_000
    fails = []

    def run(*a, stdin=None, env=None):
        r = subprocess.run([sys.executable, "-I", me, "--db", db] + list(a) if a[0].startswith("--") else [sys.executable, "-I", me] + list(a) + ["--db", db],
                           input=stdin, capture_output=True, text=True, timeout=60)
        return r.returncode, r.stdout, r.stderr

    def expect(name, cond, detail=""):
        print("  %s %s%s" % ("ok  " if cond else "FAIL", name, "" if cond else " -- " + detail))
        if not cond:
            fails.append(name)

    import re
    probe = re.compile(r"^FLEET db=sqlite window_h=24 ticks=[1-9][0-9]* p95_ready_min=[0-9]+ ask_p95_min=[0-9]+ lease_expiries=[0-9]+ hand_wakes=[0-9]+", re.M)
    print("selftest in %s" % base)

    rc, o, e = run("--check", "--now", str(now))
    expect("missing db: rc 2, nothing created", rc == 2 and not os.path.exists(db), "rc=%d out=%r err=%r" % (rc, o, e))

    c = open_rw(db)
    c.close()
    rc, o, e = run("--check", "--now", str(now))
    expect("empty db: rc 1 RED, ticks=0, the step-15 probe does not match", rc == 1 and "ticks=0 " in o and "RED:" in o and not probe.search(o), "rc=%d out=%r" % (rc, o))
    expect("empty db: every tier prints NA", o.count("rate_pct=NA") == len(TIERS), o)

    c = open_rw(db)
    for i in range(100):
        ts = now - 600 * 60 + i * 60
        age = (i + 1) * 60
        rows = [("tier-haiku", "haiku", 1, 0, 0, 0, age, 2), ("tier-sonnet", "sonnet", 0, 0, 0, 0, 0, 0), ("tier-opus", "opus", 0, 0, 0, 0, 0, 0),
                ("tier-fable", "fable", 0, 0, 0, 0, 0, 0), ("seat-x", "haiku", 3, 0, 0, 0, 99999, 0)]
        w_tick(c, ts, rows)
    w_tick(c, now - 25 * 3600, [("tier-haiku", "haiku", 1, 0, 0, 0, 999 * 60, 0)])
    w_tick(c, now - 30, [("tier-haiku", "haiku", 0, 0, 0, 0, 0, 0)])
    w_tick(c, now - 30, [("tier-haiku", "haiku", 0, 0, 0, 0, 0, 0)])
    for k in range(1, 11):
        w_ask_put(c, now - 7200 + k, "q-a-%d" % k, "worker_01", "ask-sonnet")
        w_ask_answer(c, now - 7200 + k + k * 60, "q-a-%d" % k, "secretary")
    w_ask_put(c, now - 45 * 60, "q-open", "worker_02", "ask-sonnet")
    w_ask_put(c, now - 26 * 3600, "q-old", "worker_03", "ask-sonnet")
    t = now - 5000
    for n in range(25):
        w_lease_start(c, t, "h-%d" % n, "tier-haiku", "haiku", "worker_01", 600 if n < 20 else 3000)
        t += 60
        w_lease_end(c, t, "h-%d" % n, "worker_01", "escalated" if (n < 5 or 5 <= n < 11) else "done")
        t += 60
    for n in range(3):
        w_lease_start(c, t, "x-%d" % n, "tier-haiku", "haiku", "worker_02", 0)
        w_lease_end(c, t + 5, "x-%d" % n, "worker_02", ["expired", "buried", "released"][n])
        t += 60
    w_lease_start(c, now - 3600, "dead-1", "tier-haiku", "haiku", "worker_04", 0)
    w_lease_end(c, now - 3000, "dead-1", "worker_04", "expired")
    w_lease_start(c, now - 3600, "dead-2", "tier-sonnet", "sonnet", "president", 0)
    w_lease_end(c, now - 3000, "dead-2", "president", "expired")
    w_lease_start(c, now - 26 * 3600, "dead-0", "tier-haiku", "haiku", "worker_05", 0)
    w_lease_end(c, now - 25 * 3600, "dead-0", "worker_05", "expired")
    for n, tier in enumerate(("sonnet", "sonnet", "sonnet")):
        w_lease_start(c, now - 900 + n, "s-%d" % n, "tier-sonnet", tier, "vice_president", 0)
        w_lease_end(c, now - 800 + n, "s-%d" % n, "vice_president", "escalated" if n == 1 else "done")
    for by in ("hook", "hook", "tick", "monitor", "hand", "hand"):
        w_wake(c, now - 100, "worker_09", "t", by)
    w_wake(c, now - 26 * 3600, "worker_09", "t", "hand")
    c.close()

    rc, o, e = run("--check", "--now", str(now))
    line = o.splitlines()[0] if o else ""
    want = ("FLEET db=sqlite window_h=24 ticks=101 p95_ready_min=95 ask_p95_min=45 lease_expiries=3 hand_wakes=2 p50_ready_min=50 ask_p50_min=6 "
            "served_p95_min=50 asks=11 open_asks=1 age_s=30")
    expect("fixture: rc 0 GREEN", rc == 0, "rc=%d out=%r err=%r" % (rc, o, e))
    expect("fixture: the FLEET line, every number exact", line == want, "\n    got  %s\n    want %s" % (line, want))
    expect("fixture: the step-15 probe regex matches", bool(probe.search(o)))
    expect("fixture: the 25 h tick, the 26 h ask, the 25 h expiry and the 26 h hand wake are outside the window", "ticks=101 " in line and "asks=11 " in line)
    expect("fixture: seat tubes never enter the ready age", "p95_ready_min=95" in line and "tube=seat-x" not in o)
    expect("fixture: haiku escalation is the last 20 of 25 closures (6 of 20 = 30), buried/expired/released not closures",
           "ESCALATION tier=haiku escalated=6 closed=20 of=20 rate_pct=30" in o, o)
    expect("fixture: sonnet 1 of 3 = 33", "ESCALATION tier=sonnet escalated=1 closed=3 of=20 rate_pct=33" in o, o)
    expect("fixture: opus and fable have no closure: NA", "ESCALATION tier=opus escalated=0 closed=0 of=20 rate_pct=NA" in o and "tier=fable escalated=0 closed=0 of=20 rate_pct=NA" in o, o)
    expect("fixture: the per-tube line", "TUBE tube=tier-haiku waiting_ticks=100 p50_ready_min=50 p95_ready_min=95" in o, o)

    rc, o2, e = run("--check", "--now", str(now + 1000))
    expect("stale: the newest tick 1030 s old -> rc 1 RED naming it, the numbers still print", rc == 1 and "RED: the newest tick is 1030 s old" in o2 and "ESCALATION tier=haiku" in o2, "rc=%d" % rc)
    rc, o3, e = run("--check", "--now", str(now + 1000), "--stale-s", "2000")
    expect("stale: --stale-s 2000 reads GREEN", rc == 0, "rc=%d" % rc)

    rc, o4, e = run("tick", "--ts", str(now - 30), "--stdin", stdin="tier-haiku\thaiku\t0\t0\t0\t0\t0\n# comment\n\ntier-fable\tfable\t1\t0\t0\t0\t60\t1\n")
    expect("CLI tick --stdin writes 2 rows; a repeated (ts, tube) replaces", rc == 0 and "rows=2" in o4, "rc=%d out=%r err=%r" % (rc, o4, e))
    rc, o5, e = run("--check", "--now", str(now))
    expect("CLI tick: still 101 ticks (no duplicate), tier-fable now has a waiting tick", "ticks=101 " in o5 and "TUBE tube=tier-fable waiting_ticks=1 " in o5, o5)
    rc, o6, e = run("tick", "--ts", str(now), "--tube", "tier-haiku", "--tier", "haiku", "--ready", "1", "--reserved", "0", "--delayed", "0", "--buried", "0", "--oldest-ready-s", "120")
    expect("CLI tick by flags", rc == 0 and "rows=1" in o6, "rc=%d err=%r" % (rc, e))
    rc, o, e = run("lease-start", "--topic", "cli-1", "--tube", "tier-haiku", "--tier", "haiku", "--seat", "worker_07", "--waited-s", "30")
    expect("CLI lease-start", rc == 0 and o.startswith("LEASE id="), "rc=%d out=%r err=%r" % (rc, o, e))
    rc, o, e = run("lease-end", "--topic", "cli-1", "--seat", "worker_07", "--outcome", "done")
    expect("CLI lease-end", rc == 0 and "outcome=done" in o, "rc=%d out=%r err=%r" % (rc, o, e))
    rc, o, e = run("lease-end", "--topic", "cli-1", "--seat", "worker_07", "--outcome", "done")
    expect("CLI lease-end twice: rc 2, the lease is closed once", rc == 2 and "no open lease" in e, "rc=%d err=%r" % (rc, e))
    rc, o, e = run("ask-put", "--topic", "q-cli", "--asker", "worker_08", "--tube", "ask-sonnet")
    expect("CLI ask-put", rc == 0, e)
    rc, o, e = run("ask-answer", "--topic", "q-cli", "--by", "manager")
    expect("CLI ask-answer", rc == 0, e)
    rc, o, e = run("ask-answer", "--topic", "q-cli", "--by", "manager")
    expect("CLI ask-answer twice: rc 2", rc == 2, "rc=%d" % rc)
    rc, o, e = run("escalation", "--topic", "cli-2", "--from-tube", "tier-haiku", "--to-tube", "tier-sonnet", "--from-tier", "haiku", "--to-tier", "sonnet",
                   "--rung", "2", "--via", "try", "--measurement", "1")
    expect("CLI escalation", rc == 0 and "haiku->sonnet" in o, "rc=%d err=%r" % (rc, e))
    rc, o, e = run("wake", "--seat", "worker_10", "--topic", "cli-3", "--by", "hand", "--ts", str(now - 10))
    expect("CLI wake", rc == 0, e)
    rc, o, e = run("--check", "--now", str(now))
    expect("CLI wake by hand counted: hand_wakes=3", "hand_wakes=3 " in o, o.splitlines()[0])
    rc, o, e = run("lease-start", "--topic", "bad", "--tube", "tier-haiku", "--tier", "gpt", "--seat", "w")
    expect("a tier outside the four is refused by the schema: rc 2", rc == 2 and "CHECK" in e.upper(), "rc=%d err=%r" % (rc, e))
    rc, o, e = run("wake", "--seat", "w", "--topic", "t", "--by", "magic")
    expect("a waker outside the four is refused: rc 2", rc == 2, "rc=%d" % rc)

    with open(db, "r+b") as f:
        f.seek(0)
        f.write(b"NOT A SQLITE FILE!")
    rc, o, e = run("--check", "--now", str(now))
    expect("a corrupted db: rc 2, not a pass", rc == 2, "rc=%d out=%r" % (rc, o))

    shutil.rmtree(base, ignore_errors=True)
    print("SELFTEST %s: %d check(s) failed" % ("RED" if fails else "GREEN", len(fails)) if fails else "SELFTEST GREEN: fixture db proved, every number exact")
    return 1 if fails else 0


def build_parser():
    ap = argparse.ArgumentParser(prog="util_fleet_outcomes.py", description="the fleet outcome ledger (FLEET.db)")

    def common(p, sup):
        d = argparse.SUPPRESS if sup else None
        p.add_argument("--db", default=d)
        p.add_argument("--now", type=int, default=d)

    common(ap, False)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--init", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--window-h", type=int, default=24)
    ap.add_argument("--stale-s", type=int, default=300)
    sub = ap.add_subparsers(dest="verb")

    def verb(name, *flags):
        p = sub.add_parser(name)
        common(p, True)
        p.add_argument("--ts", type=int, default=None)
        for f in flags:
            kw = {"type": int} if f in ("--ready", "--reserved", "--delayed", "--buried", "--oldest-ready-s", "--idle-above", "--waited-s", "--rung", "--measurement") else {}
            if f in ("--idle-above", "--waited-s"):
                kw["default"] = 0
            p.add_argument(f, required=("default" not in kw and f != "--stdin"), **kw)
        return p

    t = verb("tick", "--tube", "--tier", "--ready", "--reserved", "--delayed", "--buried", "--oldest-ready-s", "--idle-above")
    for a in t._actions:
        if a.dest in ("tube", "tier", "ready", "reserved", "delayed", "buried", "oldest_ready_s"):
            a.required = False
    t.add_argument("--stdin", action="store_true")
    verb("lease-start", "--topic", "--tube", "--tier", "--seat", "--waited-s")
    verb("lease-end", "--topic", "--seat", "--outcome")
    verb("ask-put", "--topic", "--asker", "--tube")
    verb("ask-answer", "--topic", "--by")
    verb("escalation", "--topic", "--from-tube", "--to-tube", "--from-tier", "--to-tier", "--rung", "--via", "--measurement")
    verb("wake", "--seat", "--topic", "--by")
    return ap


def main(argv):
    ap = build_parser()
    a = ap.parse_args(argv)
    path = a.db or os.environ.get("S4E_FLEET_DB") or DEFAULT_DB
    now = a.now if a.now is not None else int(time.time())
    try:
        if a.selftest:
            return selftest()
        if a.check:
            return do_check(path, now, a.window_h, a.stale_s)
        if a.init:
            open_rw(path).close()
            print("INIT db=%s version=%d" % (path, SCHEMA_VERSION))
            return 0
        if not a.verb:
            ap.print_usage(sys.stderr)
            raise Refuse("name --check, --init, --selftest or a writer verb")
        ts = a.ts if a.ts is not None else now
        c = open_rw(path)
        try:
            if a.verb == "tick":
                if a.stdin:
                    rows = parse_tick_lines(sys.stdin.read())
                else:
                    need(a.tube and a.tier and None not in (a.ready, a.reserved, a.delayed, a.buried, a.oldest_ready_s),
                         "tick: give --stdin, or --tube --tier --ready --reserved --delayed --buried --oldest-ready-s")
                    rows = [(a.tube, a.tier, a.ready, a.reserved, a.delayed, a.buried, a.oldest_ready_s, a.idle_above)]
                msg = w_tick(c, ts, rows)
            elif a.verb == "lease-start":
                msg = w_lease_start(c, ts, a.topic, a.tube, a.tier, a.seat, a.waited_s)
            elif a.verb == "lease-end":
                need(a.outcome in OUTCOMES, "lease-end: --outcome is one of %s" % "|".join(OUTCOMES))
                msg = w_lease_end(c, ts, a.topic, a.seat, a.outcome)
            elif a.verb == "ask-put":
                msg = w_ask_put(c, ts, a.topic, a.asker, a.tube)
            elif a.verb == "ask-answer":
                msg = w_ask_answer(c, ts, a.topic, a.by)
            elif a.verb == "escalation":
                msg = w_escalation(c, ts, a)
            else:
                msg = w_wake(c, ts, a.seat, a.topic, a.by)
        finally:
            c.close()
        print(msg)
        return 0
    except Refuse as e:
        print("REFUSE(2) [util_fleet_outcomes]: %s" % e, file=sys.stderr)
        return 2
    except sqlite3.Error as e:
        print("REFUSE(2) [util_fleet_outcomes]: sqlite: %s" % e, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
