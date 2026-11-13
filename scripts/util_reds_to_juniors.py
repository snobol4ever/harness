#!/usr/bin/env python3
"""util_reds_to_juniors.py -- EVERY RED OF THE TEST SUITE IS A JUNIOR'S BUG ROW (the grader 2026-11-12, on the coo's brief reds-to-juniors-feeder;
Lon 2026-11-12 10:4x CST, in the coo's window, verbatim: "We are about to start the entore fleet on fixing all the bugs ONE at a tIME." / "Send every bug
fro the test suite to a junior. Then we'll watch somethings escaalate to senior, then officer, then BOSS (COO), the CHARIMAN-OF-THE-BOARD, me.").

The sibling of util_reds_to_designers.py (COO-488), whose reading and whose rowed test it reuses: the designers' road sends a red to its area officer
as a design job; this road sends it to a junior as a bug, with the steps a junior follows, and it walks every suite, not one.
  ORDER    the suites of SUITES.tsv with reds (today_total - today_pass > 0), the smallest red count first, so a suite reaches 100 soonest; a suite's
           reds are read only when the limit is not yet reached, so a call with a small --limit reads one or two suites, never the table.
  READING  util_score_row.py from-progress --suite KEY --reds --dry-run under S4E_MODES=m3 (it writes nothing): its SUITE_ROW board line first, then
           its SUITE_ROW_RED lines; a suite whose writer prints no board line is skipped and named (SKIP_SUITE), never read as no reds.
  ROWED    a red is skipped when its topic (KEY-red-<entry slug>, the designers' own topic) is a live row of QUEUE.tsv, or a live row's DONE-WHEN
           names the entry (util_reds_to_designers.live_rows and plan).
  DEALING  each new row goes to the junior holding the fewest live rows in QUEUE.tsv (owner, ASSIGNED:, CLAIMED: or QUEUED:seat-), ties by number:
           round robin over the juniors of TIERS.tsv (role junior, the roster the seat folders make) with no state of its own, so one call or many never fill one tube (the stagger rule).
  OUTPUT   one line per bug: JUNIOR_BUG suite=K entry=E junior=J topic=T reading=R; then FEED_BOARD suites_read=N reds=N rowed=N closed=N alike=N bugs=N limit=N (closed: an entry whose topic already has a baton, a DONE row waiting for the cycle; alike: a red listed in a shared cause's members file of the newest cause census, /home/resources/progress/causes-<date>/<cause>.members.tsv or S4E_CAUSES_DIR, held by that cause's row, one CAUSE_HELD line per cause).
  --apply  mints each bug: s4e_msg.sh mint TOPIC 1 --to JUNIOR --stdin. The mint's WAKE line is PRINTED, never sent (the coo wakes in waves).
  --limit N  at most N bugs in one call (default 20).   --suites K1,K2  only these suite keys.   --juniors J1,J2  another seat list.
  --stock  THE CLOCK STOCKS THE TUBES (the cio 2026-11-13, row the-tick-keeps-every-live-juniors-tube-stocked; Lon, in the coo's window, verbatim: "It seems
           not enough work is going to JUNIORS. Is that correct?"; MEASURED 13:21: 11 of 16 juniors idle, nothing dealing a red but the coo's hand, and one
           feeder call for one bug 3 min 7 s and 33 CPU-s, so no junior's next can run it). ONE FILE, <postoffice>/FEED.conf, key=value a line: depth=N the
           live rows every junior holds (0 or no file: off, nothing read, nothing minted), skip_suites=K1,K2 never dealt, max=N the most bugs one run mints
           (32). The juniors counted are the live set's alive ones (lib_wake.sh s4e_wake_live_of_tier haiku; S4E_FEED_JUNIORS names them for a probe); each
           is brought to the depth and no further, the emptiest first; a run that owes nothing reads no suite. One run at a time (flock -n on
           <postoffice>/.feed.lock). With --apply it mints, appends each WAKE line to $S4E_FEED_WAKES when set, and writes one line to
           /home/resources/progress/FEED_STOCK.tsv (S4E_FEED_LEDGER). box_tick.py starts it every fifth tick as the transient unit s4e-feed.
           Prints FEED_STOCK depth=N juniors=N owed=N minted=N secs=N.
  --probe-causes  the cause holds read every census of the newest day (two dirs of one day both hold, an older day's not, S4E_CAUSES_DIR a colon list).
  --probe-stock  the proof on a scratch postoffice: no file mints nothing; depth 2 brings a junior with 0, 1 and 2 live rows to 2, 2 and 2; a
           skipped suite is never dealt; a junior outside the named set gets nothing; a second run owes nothing. Prints FEED_STOCK_PROBE ... ok=1.
  --probe  plants a scratch postoffice (S4E_POST) with two suites' reds, a live row and a DONE row, runs --apply there with real mints, and prints
           FEED_PROBE; rc 0 only when the limit, the order, the rowed skip and the dealing read as designed. It never touches the live queue.
rc 0 read; 1 a probe that read otherwise; 2 REFUSE (no SUITES.tsv, no SUITE_RUNNERS.tsv, a mint refused under --probe).
"""
import os, re, subprocess, sys, tempfile, shutil, glob, time, fcntl

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import util_reds_to_designers as d2d

ROOT = os.path.dirname(os.path.dirname(HERE))
PO = os.environ.get("S4E_POST", "/home/resources/postoffice")
SUITES = os.environ.get("S4E_SUITES_TSV", "/home/resources/progress/SUITES.tsv")
RUNNERS = os.path.join(HERE, "SUITE_RUNNERS.tsv")
import util_tiers
JUNIORS = [r["seat"] for r in util_tiers.load()[0] if r["role"] == "junior"]
EXT = {"snobol4": "sno", "icon": "icn", "prolog": "pl", "pascal": "pas", "raku": "raku", "rebus": "reb", "snocone": "sc"}
LANG_SKILL = {"snobol4": "snobol4", "snocone": "snobol4", "rebus": "snobol4", "icon": "icon", "prolog": "prolog", "pascal": "pascal", "raku": "raku",
              "scriptix": "scrip-architecture"}


def refuse(why):
    print("REFUSE(2): " + why); sys.exit(2)


def arg(name, default):
    a = sys.argv[1:]
    return a[a.index(name) + 1] if name in a and a.index(name) + 1 < len(a) else default


def suites_with_reds(path, only):
    if not os.path.isfile(path): refuse("no suite table %s" % path)
    out = []
    for l in open(path, encoding="utf-8", errors="replace"):
        c = l.rstrip("\n").split("\t")
        if l.startswith("#") or len(c) < 10 or c[0] == "key": continue
        try: reds = int(c[9]) - int(c[8])
        except ValueError: continue
        if reds > 0 and (not only or c[0] in only): out.append((reds, c[0], c[3]))
    return [(k, lang, n) for n, k, lang in sorted(out)]


def runner_rows(path):
    if not os.path.isfile(path): refuse("no %s" % path)
    rows = {}
    for l in open(path, encoding="utf-8", errors="replace"):
        c = l.rstrip("\n").split("\t")
        if l.startswith("#") or len(c) < 5: continue
        rows[c[0]] = c
    return rows


def reproduce(key, lang, entry, rows):
    r = rows.get(key)
    if r and r[1] in ("master", "pkg"):
        d = "corpus/tests/" + r[2] if r[1] == "master" else r[4]
        x = EXT.get(r[2], r[2])
        return ("python3 harness/scripts/corpus_suite_harness.py run %s/ALL.%s %s/ALL.ref --lang %s --modes m3 --partition 'entry:%s'" % (d, x, d, r[2], entry),
                "python3 harness/scripts/corpus_suite_harness.py extract %s/ALL.%s %s/ALL.ref '%s' /tmp/s4e/$S4E_SEAT/bug.%s --out-ref /tmp/s4e/$S4E_SEAT/bug.ref --out-in /tmp/s4e/$S4E_SEAT/bug.in" % (d, x, d, entry, x),
                "bash harness/scripts/monitor_run.sh /tmp/s4e/$S4E_SEAT/bug.%s --oracle" % x)
    if r and r[1] == "small":
        return ("bash harness/scripts/%s (the suite's own runner; the entry %s is one of its programs)" % (r[3], entry),
                "the program %s as its runner names it" % entry, "bash harness/scripts/monitor_run.sh <that program> --oracle")
    return ("the suite %s has no runner row in SUITE_RUNNERS.tsv: grade %s by the command its suite row names" % (key, entry),
            "the program %s" % entry, "bash harness/scripts/monitor_run.sh <that program> --oracle")


def load(po, juniors):
    q = os.path.join(po, "QUEUE.tsv"); n = {j: 0 for j in juniors}
    for l in open(q, encoding="utf-8", errors="replace"):
        c = l.rstrip("\n").split("\t")
        # ⛔ A PARKED ROW IS NO LOAD (the coo 2026-11-12 21:4x, measured: junior_01 and junior_15 sat idle with two and three PARKED-AWAITING rows each
        # while junior_04 and junior_14 were dealt two new rows apiece): a row waiting on a verdict, a block or a hold keeps no seat busy
        if l.startswith("#") or len(c) < 4 or re.match(r"^(DONE|RETIRED|PARKED|BLOCKED)", c[3]): continue
        for j in juniors:
            if c[2] == j or c[3] in ("ASSIGNED:" + j, "CLAIMED:" + j, "QUEUED:seat-" + j): n[j] += 1; break
    return n


def body(key, lang, entry, reading, rows):
    rep, ext, ora = reproduce(key, lang, entry, rows)
    q = '"${S4E_HOME:?REFUSE(2): S4E_HOME unset}"'
    rd = 'o="$(S4E_MODES=m3 python3 -I harness/scripts/util_score_row.py from-progress --suite %s --reds --dry-run 2>&1)"' % key
    have = "printf '%%s\\n' \"$o\" | grep -q '^SUITE_ROW suite=%s '" % key
    red = "printf '%%s\\n' \"$o\" | grep -qE '^SUITE_ROW_RED %s '" % re.escape(entry)
    # the decisive lines are printed before the test, so done and next show what they measured (the cio 2026-11-12 23:2x)
    show = "printf '%%s\\n' \"$o\" | grep -E '^SUITE_ROW suite=%s |^SUITE_ROW_RED %s ' || true" % (key, re.escape(entry))
    sk = "fleet-bus seat-conduct suites-and-grading gates-and-witnesses " + LANG_SKILL.get(lang, "scrip-architecture")
    return ("GOAL: BUG. The %s entry %s reads red in mode 3 (%s). Find the cause, cure it, land it. One bug, one row; after one honest try that cannot land, escalate it.\n"
            "SKILLS: %s\n"
            "DONE-WHEN: cd %s && %s; %s; %s && ! %s\n"
            "PREMISE-WHEN: cd %s && %s; %s; { %s || { echo 'REFUSE(2): the score writer printed no SUITE_ROW line'; exit 2; }; } && %s\n"
            "## NEXT\n"
            "1. Reproduce, from the root with S4E_HOME set: %s\n"
            "2. The oracle: %s ; then %s\n"
            "3. Find the cause and cure it in a clean worktree: bash harness/scripts/s4e_worktree.sh new %s (load the skill the gate names before each edit).\n"
            "4. Prove it in the worktree: the reproduce line of step 1 reads PASS for the entry in mode 3; bash harness/scripts/test_feature_reps.sh %s <the feature you touched>; bash harness/scripts/test_smoke_%s.sh.\n"
            "5. Land it: bash harness/scripts/s4e_land.sh --home <the worktree> --gate '<the step 1 line, grepping m3_pass=1 m3_fail=0>' <the repos you changed>; then s4e_msg.sh claim and done.\n"
            "6. After one honest try that cannot land: bash harness/scripts/s4e_msg.sh escalate %s --stdin with the measurement (what you ran, what it printed), and send the WAKE it prints.\n"
            % (key, entry, reading, sk, q, rd, show, have, red, q, rd, show, have, red, rep, ext, ora, re.sub(r"[^a-z0-9]+", "-", entry.lower()).strip("-")[:40] or "bug",
               lang, {"rebus": "rebus", "snocone": "snocone"}.get(lang, lang), d2d.topic_of(key, entry)))


def read_suite(key):
    env = dict(os.environ, S4E_MODES="m3")
    p = subprocess.run([sys.executable, "-I", os.path.join(HERE, "util_score_row.py"), "from-progress", "--suite", key, "--reds", "--dry-run"],
                       capture_output=True, text=True, env=env, timeout=1800)
    return p.stdout + p.stderr


def cause_dirs(root="/home/resources/progress"):
    # EVERY CENSUS OF THE NEWEST DAY, NEVER ONLY THE LAST ONE (the coo 2026-11-13 16:4x CST, MEASURED: the sorted glob's [-1] read only causes-2026-11-13b,
    # the raku census, so the cto's fpc-source causes and the 56-entry gate_cases_snobol4 trace cause of causes-2026-11-13 were released, and the feeder
    # dealt trace members to juniors again between 22:24Z and 22:30Z): every causes-<date>*/ directory of the newest date; S4E_CAUSES_DIR names one or
    # more (colon-separated) instead
    if os.environ.get("S4E_CAUSES_DIR"): return [x for x in os.environ["S4E_CAUSES_DIR"].split(":") if x]
    ds = sorted(glob.glob(os.path.join(root, "causes-*/")))
    days = [m.group(1) for m in (re.match(r"causes-(\d{4}-\d{2}-\d{2})", os.path.basename(x.rstrip("/"))) for x in ds) if m]
    if not days: return []
    last = max(days)
    return [x for x in ds if os.path.basename(x.rstrip("/")).startswith("causes-" + last)]


def cause_holds(d=None):
    # (suite, entry) -> the shared cause whose row holds it: every <cause>.members.tsv (columns suite, cause, entry) of every census of the newest day
    # (cause_dirs); the first file read in name order names the cause; no census, no hold
    h = {}
    for dd in ([d] if d else cause_dirs()):
        for p in sorted(glob.glob(os.path.join(dd, "*.members.tsv"))):
            try:
                for l in open(p, encoding="utf-8", errors="replace"):
                    c = l.rstrip("\n").split("\t")
                    if len(c) >= 3 and c[0] != "suite": h.setdefault((c[0], c[2]), os.path.basename(p)[:-len(".members.tsv")])
            except OSError: pass
    return h


def probe_causes():
    """two censuses of one day both hold, an older day's does not, S4E_CAUSES_DIR lists override; prints CAUSES_PROBE ... ok=1"""
    w = tempfile.mkdtemp(prefix="causes_probe_", dir=os.environ.get("TMPDIR") or None)
    saved = os.environ.pop("S4E_CAUSES_DIR", None)
    try:
        for d, cause, suite, entry in (("causes-2026-11-12", "old", "s0", "e0"), ("causes-2026-11-13", "trace", "s1", "e1"), ("causes-2026-11-13b", "raku", "s2", "e2")):
            os.makedirs(os.path.join(w, d))
            open(os.path.join(w, d, cause + ".members.tsv"), "w").write("suite\tcause\tentry\n%s\t%s\t%s\n" % (suite, cause, entry))
        dirs = cause_dirs(w)
        h = {}
        for dd in dirs: h.update(cause_holds(dd))
        both = ("s1", "e1") in h and ("s2", "e2") in h; old = ("s0", "e0") in h
        os.environ["S4E_CAUSES_DIR"] = os.path.join(w, "causes-2026-11-12") + ":" + os.path.join(w, "causes-2026-11-13b")
        ov = cause_holds(); env_ok = set(ov) == {("s0", "e0"), ("s2", "e2")}
        ok = both and not old and len(dirs) == 2 and env_ok
        print("CAUSES_PROBE dirs=%d newest_day_both_held=%d older_day_held=%d env_list=%d ok=%d" % (len(dirs), int(both), int(old), int(env_ok), int(ok)))
        return ok
    finally:
        os.environ.pop("S4E_CAUSES_DIR", None)
        if saved is not None: os.environ["S4E_CAUSES_DIR"] = saved
        shutil.rmtree(w, ignore_errors=True)


def design_witnesses(root=os.path.join(HERE, "..", "designs")):
    # every entry named in the witnesses column of a design's STEPS.tsv (harness/designs/*/STEPS.tsv, skill design-plans)
    w = {}
    for p in glob.glob(os.path.join(root, "*", "STEPS.tsv")):
        try:
            head = None
            for l in open(p, encoding="utf-8", errors="replace"):
                if l.startswith("#") or not l.strip(): continue
                c = l.rstrip("\n").split("\t")
                if head is None: head = c; continue
                if "witnesses" in head and len(c) > head.index("witnesses"):
                    for x in c[head.index("witnesses")].split(): w.setdefault(x, "%s:%s" % (os.path.basename(os.path.dirname(p)), c[0]))
        except OSError: pass
    return w


def feed(order, reader, po, rows, limit, juniors, apply):
    topics, dw = d2d.live_rows(po)
    n = load(po, juniors); bugs = []; reds_n = rowed_n = read_n = unread_n = closed_n = alike_n = design_n = 0
    holds = cause_holds(); dws = design_witnesses(); dred = {}; cheld = {}
    for key, lang in order:
        if len(bugs) >= limit: break
        text = reader(key)
        if not re.search(r"^SUITE_ROW suite=", text, re.M):
            print("SKIP_SUITE suite=%s (the score writer printed no SUITE_ROW board line: %s)" % (key, (text.strip().splitlines() or ["no output"])[-1][:160])); continue
        read_n += 1
        reds = [(m.group(1), m.group(2).strip()) for m in re.finditer(r"^SUITE_ROW_RED (\S+) (.*)$", text, re.M)]
        # ⛔ AN UNREAD ENTRY IS NO BUG (the coo 2026-11-12, measured: junior_05, junior_09 and junior_10 each found their row's entry passing,
        # its red the label m3=UNREAD on a tree no reading covers yet -- raku-rungs read 95 UNREAD and 1 FAIL): only a measured red is minted;
        # an unread entry waits for the cycle's lap
        unread_n += sum(1 for _e, r in reds if "UNREAD" in r)
        reds = [(e, r) for e, r in reds if "UNREAD" not in r]
        reds_n += len(reds)
        # ⛔ REDS OF ONE SHARED CAUSE ARE ONE BUG (skill fleet-bus 1; the coo 2026-11-13 09:1x, on the cto's census of 08:5x, measured: the key of
        # 11-12 was results.tsv column 13, the BINARY's identity at the board's start, never an output hash, so every red graded on one build read
        # alike and waited behind one row): a red listed in a shared cause's members file is held by that cause's row, counted alike=N; every
        # other red is its own bug
        for e, reading in reds:
            pat = re.compile(r"(^|[^A-Za-z0-9_/])" + re.escape(e) + r"($|[^A-Za-z0-9_/])")
            t = d2d.topic_of(key, e)
            if t in topics or any(pat.search(l) for l in dw.values()): rowed_n += 1; continue
            if (key, e) in holds: alike_n += 1; cheld[holds[(key, e)]] = cheld.get(holds[(key, e)], 0) + 1; continue
            # ⛔ A DESIGN STEP'S WITNESS IS HELD BY ITS STEP (the coo 2026-11-13 00:3x, on officer_04's reading: tabling-one-engine step 2 had no live row,
            # so its witnesses oe1 to oe10 were dealt to eight seats one by one): such a red is never a junior's bug; its step row holds it, design=N
            if e in dws: design_n += 1; dred.setdefault(dws[e], []).append(e); continue
            # ⛔ A CLOSED ROW'S ENTRY WAITS FOR THE CYCLE (the coo 2026-11-12 21:3x, measured: six of nine picks refused at mint, "already exists", each a
            # DONE row in QUEUE.done.tsv whose cure landed after the tree of the entry's red reading; each refusal left its junior unfed): the topic's
            # baton exists, so the entry is counted rowed and the junior takes the next red
            if os.path.exists(os.path.join(po, "tasks", t + ".task.md")): rowed_n += 1; closed_n += 1; continue
            if len(bugs) >= limit: break
            j = min(juniors, key=lambda s: (n[s], juniors.index(s))); n[j] += 1; topics.add(t)
            bugs.append((key, lang, e, j, t, reading))
            print("JUNIOR_BUG suite=%s entry=%s junior=%s topic=%s reading=%s" % (key, e, j, t, reading))
    for c in sorted(cheld): print("CAUSE_HELD cause=%s reds=%d (held by the shared cause's row of the cause census)" % (c, cheld[c]))
    for d in sorted(dred): print("DESIGN_RED step=%s reds=%d first=%s (held by its step row; a closed step's red is a regression)" % (d, len(dred[d]), dred[d][0]))
    minted = 0
    if apply:
        for key, lang, e, j, t, reading in bugs:
            p = subprocess.run(["bash", os.path.join(HERE, "s4e_msg.sh"), "mint", t, "1", "--to", j, "--stdin"], input=body(key, lang, e, reading, rows),
                               capture_output=True, text=True, env=dict(os.environ, S4E_POST=po))
            ok = p.returncode == 0; minted += int(ok)
            for l in (p.stdout + p.stderr).splitlines():
                if l.startswith(("minted ", "WAKE:", "queued ", "⛔", "REFUSE")): print(l)
            if not ok: print("MINT_REFUSED topic=%s rc=%d" % (t, p.returncode))
    tree = subprocess.run(["git", "-C", os.path.join(ROOT, "harness"), "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()
    print("FEED_BOARD suites_read=%d reds=%d unread=%d rowed=%d closed=%d alike=%d design=%d bugs=%d minted=%d limit=%d (tree %s)" % (read_n, reds_n, unread_n, rowed_n, closed_n, alike_n, design_n, len(bugs), minted, limit, tree or "?"))
    return bugs, rowed_n, minted


def feed_conf(po):
    c = {}
    try:
        for l in open(os.path.join(po, "FEED.conf"), encoding="utf-8", errors="replace"):
            l = l.split("#", 1)[0].strip()
            if "=" in l: k, v = l.split("=", 1); c[k.strip()] = v.strip()
    except OSError: pass
    return c


def live_juniors():
    if os.environ.get("S4E_FEED_JUNIORS") is not None: return [x for x in os.environ["S4E_FEED_JUNIORS"].split(",") if x]
    r = subprocess.run(["bash", "-c", '. "$0"; s4e_wake_live_of_tier haiku', os.path.join(HERE, "lib_wake.sh")], capture_output=True, text=True,
                       env=dict(os.environ, S4E_POST=PO, S4E_HOME=ROOT))
    return [x for x in r.stdout.split() if x in JUNIORS]


def stock(po, order_of, reader, rows, apply):
    """-> (owed, minted): bring every live junior to FEED.conf's depth; nothing owed reads nothing"""
    t0 = time.time(); c = feed_conf(po)
    try: depth = int(c.get("depth", "0")); cap = int(c.get("max", "32"))
    except ValueError: refuse("FEED.conf: depth and max are whole numbers")
    if depth <= 0:
        print("FEED_STOCK off (no depth in %s: the feeder runs by hand only)" % os.path.join(po, "FEED.conf")); return 0, 0
    lock = open(os.path.join(po, ".feed.lock"), "a")
    try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print("FEED_STOCK busy (another stock run holds %s)" % os.path.join(po, ".feed.lock")); return 0, 0
    js = live_juniors(); n = load(po, js)
    need = [j for j in js if n[j] < depth]; owed = min(cap, sum(depth - n[j] for j in need)); minted = 0; skip = set(x for x in c.get("skip_suites", "").split(",") if x)
    if owed:
        wakes = []
        class Tee:
            def write(self, t):
                sys.__stdout__.write(t)
                wakes.extend(l for l in t.splitlines() if l.startswith("WAKE:"))
            def flush(self): sys.__stdout__.flush()
        sys.stdout = Tee()
        try: _bugs, _rowed, minted = feed([(k, lang) for k, lang in order_of() if k not in skip], reader, po, rows, owed, need, apply)
        finally: sys.stdout = sys.__stdout__
        if apply and wakes and os.environ.get("S4E_FEED_WAKES"):
            with open(os.environ["S4E_FEED_WAKES"], "a", encoding="utf-8") as f:
                for w in wakes: f.write("%s %s\n" % (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), w))
    secs = int(time.time() - t0)
    if apply:
        led = os.environ.get("S4E_FEED_LEDGER", "/home/resources/progress/FEED_STOCK.tsv")
        try:
            new = not os.path.exists(led)
            with open(led, "a", encoding="utf-8") as f:
                if new: f.write("# FEED_STOCK.tsv -- one line a stock run of util_reds_to_juniors.py --stock --apply (the cio 2026-11-13): FEED.conf's values are judged from it\nts_utc\tdepth\tjuniors\tneedy\towed\tminted\tsecs\tskip_suites\n")
                f.write("%s\t%d\t%d\t%d\t%d\t%d\t%d\t%s\n" % (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), depth, len(js), len(need), owed, minted, secs, ",".join(sorted(skip)) or "-"))
        except OSError as e: print("FEED_STOCK ledger not written: %s" % e)
    print("FEED_STOCK depth=%d juniors=%d needy=%d owed=%d minted=%d secs=%d%s" % (depth, len(js), len(need), owed, minted, secs, "" if apply else " (dry: no --apply)"))
    return owed, minted


def probe_stock():
    w = tempfile.mkdtemp(prefix="feed_stock_probe_", dir=os.environ.get("TMPDIR") or None)
    try:
        J = JUNIORS[:4]
        for sub in ["tasks", "claims"] + ["%s/inbox" % j for j in J + [os.environ.get("S4E_SEAT") or "grader"]]: os.makedirs(os.path.join(w, sub), exist_ok=True)
        open(os.path.join(w, "BOARD.md"), "w").close()
        try: shutil.copy(os.path.join(PO, "MODE"), os.path.join(w, "MODE"))
        except OSError: open(os.path.join(w, "MODE"), "w").write("TENET\n")
        q0 = "1\trow-a\t%s\tQUEUED:seat-%s\n1\trow-b\t%s\tCLAIMED:%s\n1\trow-c\t%s\tQUEUED:seat-%s\n1\trow-p\t%s\tPARKED-AWAITING:verdict\n" % (J[1], J[1], J[2], J[2], J[2], J[2], J[0])
        open(os.path.join(w, "QUEUE.tsv"), "w").write(q0)
        # each planted row carries its baton: a mint rewrites QUEUE.tsv and drops a row with no task file (MEASURED 2026-11-13, officer_06: without
        # these the four planted rows vanished at the first mint, so the second run read rows=2,1,0,0 and owed 3 again)
        for t in ("row-a", "row-b", "row-c", "row-p"): open(os.path.join(w, "tasks", t + ".task.md"), "w").write("# TASK %s\nDONE-WHEN: false\n" % t)
        planted = {"skipme": "SUITE_ROW suite=skipme pass=0 total=2\nSUITE_ROW_RED s/k1 m3=FAIL@a\nSUITE_ROW_RED s/k2 m3=FAIL@a\n",
                   "big": "SUITE_ROW suite=big pass=1 total=9\n" + "".join("SUITE_ROW_RED b/x%d m3=FAIL@a\n" % i for i in range(1, 9))}
        order = lambda: [("skipme", "icon"), ("big", "prolog")]
        os.makedirs(os.path.join(w, "causes")); os.environ["S4E_CAUSES_DIR"] = os.path.join(w, "causes")
        os.environ["S4E_FEED_JUNIORS"] = ",".join(J[:3]); os.environ["S4E_FEED_LEDGER"] = os.path.join(w, "FEED_STOCK.tsv"); os.environ["S4E_FEED_WAKES"] = os.path.join(w, "wakes")
        off = stock(w, order, lambda k: planted[k], {}, True)
        open(os.path.join(w, "FEED.conf"), "w").write("# planted\ndepth=2\nskip_suites=skipme\n")
        first = stock(w, order, lambda k: planted[k], {}, True)
        n = load(w, J); q = open(os.path.join(w, "QUEUE.tsv"), encoding="utf-8").read()
        again = stock(w, order, lambda k: planted[k], {}, True)
        led = [l for l in open(os.path.join(w, "FEED_STOCK.tsv"), encoding="utf-8") if not l.startswith(("#", "ts_utc"))]
        open(os.path.join(w, "FEED.conf"), "w").write("depth=3\nmax=1\n")
        capped = stock(w, order, lambda k: planted[k], {}, True)
        ok = (off == (0, 0) and first == (3, 3) and [n[j] for j in J] == [2, 2, 2, 0] and "skipme-red" not in q and again == (0, 0) and len(led) == 2
              and capped == (1, 1))
        print("FEED_STOCK_PROBE off=%d,%d first_owed=%d first_minted=%d rows=%s skipped_dealt=%d again_owed=%d ledger_lines=%d capped_minted=%d ok=%d"
              % (off[0], off[1], first[0], first[1], ",".join(str(n[j]) for j in J), int("skipme-red" in q), again[0], len(led), capped[1], int(ok)))
        return ok
    finally:
        for k in ("S4E_FEED_JUNIORS", "S4E_FEED_LEDGER", "S4E_FEED_WAKES"): os.environ.pop(k, None)
        shutil.rmtree(w, ignore_errors=True)


def probe():
    w = tempfile.mkdtemp(prefix="feed_probe_", dir=os.environ.get("TMPDIR") or None)
    try:
        for sub in ["tasks", "claims"] + ["%s/inbox" % j for j in JUNIORS[:3] + [os.environ.get("S4E_SEAT") or "grader"]]: os.makedirs(os.path.join(w, sub), exist_ok=True)
        open(os.path.join(w, "BOARD.md"), "w").close()
        try: shutil.copy(os.path.join(PO, "MODE"), os.path.join(w, "MODE"))
        except OSError: open(os.path.join(w, "MODE"), "w").write("TENET\n")
        open(os.path.join(w, "QUEUE.tsv"), "w").write("1\tlive-row\tjunior_01\tQUEUED:seat-junior_01\n1\tdone-row\tjunior_02\tDONE\n")
        open(os.path.join(w, "tasks", "live-row.task.md"), "w").write("# TASK live-row\nDONE-WHEN: grep -q '^SUITE_ROW_RED progs/rowed ' x\n")
        planted = {"tiny": "SUITE_ROW suite=tiny pass=1 total=3\nSUITE_ROW_RED progs/rowed m3=FAIL@a\nSUITE_ROW_RED progs/a1 m3=FAIL@a\n",
                   "big": "SUITE_ROW suite=big pass=1 total=5\nSUITE_ROW_RED b/x1 m3=FAIL@a\nSUITE_ROW_RED b/x2 m3=CRASH@a\nSUITE_ROW_RED b/x3 m3=FAIL@a\nSUITE_ROW_RED b/x4 m3=FAIL@a\n",
                   "mute": "REFUSE(2): planted refusal\n"}
        rows = {"tiny": ["tiny", "pkg", "icon", "corpus_suite_harness.py", "corpus/packages/icon/tiny"]}
        os.makedirs(os.path.join(w, "causes")); os.environ["S4E_CAUSES_DIR"] = os.path.join(w, "causes")
        open(os.path.join(w, "causes", "shared.members.tsv"), "w").write("suite\tcause\tentry\nbig\tshared\tb/x1\n")
        bugs, rowed, minted = feed([("mute", "icon"), ("tiny", "icon"), ("big", "prolog")], lambda k: planted[k], w, rows, 3, JUNIORS[:3], True)
        q = open(os.path.join(w, "QUEUE.tsv"), encoding="utf-8").read()
        got = [(b[2], b[3]) for b in bugs]
        want = [("progs/a1", "junior_02"), ("b/x2", "junior_03"), ("b/x3", "junior_01")]
        baton = open(os.path.join(w, "tasks", "tiny-red-progs-a1.task.md"), encoding="utf-8", errors="replace").read() if os.path.isfile(os.path.join(w, "tasks", "tiny-red-progs-a1.task.md")) else ""
        steps = all(s in baton for s in ("## NEXT", "--partition 'entry:progs/a1'", "monitor_run.sh", "s4e_worktree.sh new", "s4e_land.sh", "escalate tiny-red-progs-a1", "SKILLS: fleet-bus"))
        ok = got == want and rowed == 1 and minted == 3 and "tiny-red-progs-a1" in q and "b/x1" not in str(bugs) and "b/x4" not in str(bugs) and steps
        print("FEED_PROBE bugs=%d minted=%d rowed=%d limit_held=%d dealt=%s baton_steps=%d ok=%d" % (len(bugs), minted, rowed, int(len(bugs) == 3),
              ",".join(j for _, j in got), int(steps), int(ok)))
        return ok
    finally:
        shutil.rmtree(w, ignore_errors=True)


if __name__ == "__main__":
    if "--probe" in sys.argv[1:]: sys.exit(0 if probe() else 1)
    if "--probe-stock" in sys.argv[1:]: sys.exit(0 if probe_stock() else 1)
    if "--probe-causes" in sys.argv[1:]: sys.exit(0 if probe_causes() else 1)
    if "--stock" in sys.argv[1:]:
        stock(PO, lambda: [(k, lang) for k, lang, _ in suites_with_reds(SUITES, set())], read_suite, runner_rows(RUNNERS), "--apply" in sys.argv[1:]); sys.exit(0)
    only = set(x for x in arg("--suites", "").split(",") if x)
    juniors = [x for x in arg("--juniors", ",".join(JUNIORS)).split(",") if x]
    order = suites_with_reds(SUITES, only)
    feed([(k, lang) for k, lang, _ in order], read_suite, PO, runner_rows(RUNNERS), int(arg("--limit", "20")), juniors, "--apply" in sys.argv[1:])
    sys.exit(0)
