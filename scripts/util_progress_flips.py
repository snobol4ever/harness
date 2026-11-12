#!/usr/bin/env python3
"""util_progress_flips.py -- THE TIME-BASED QUERIES OVER THE PROGRESS DATABASE (Lon 2026-09-06: "how many programs have
flipped green per hour?" · "Are you tracking every single package test suite and benchmark program individually?" ·
"You should have a list of every program and when it began working and its current status as to known problems.").

The table: /home/resources/progress/results.tsv (writer: harness/scripts/util_progress_append.py; contract in its docstring).

  util_progress_flips.py [--since 3d|12h] [--per hour|day|10m] [--mode m3|m4|ast|any] [--class rungs|package|benchmark]
                         [--suite KEY] [--live-only] [--names]
        the flip histogram: per bucket, programs that went not-PASS -> PASS (+) and PASS -> not-PASS (-), from
        consecutive readings of the same (suite, program, mode). Zero rows in a window prints "no rows recorded", never 0 flips.
  util_progress_flips.py --coverage
        every suite of /home/resources/progress/SUITES.tsv (and every benchmark suite seen): rows, programs seen / suite total, live vs
        replay rows, last row's age -- the answer to "are we tracking everything?", MISSING named as MISSING.
  util_progress_flips.py --contradictions [--since 3d] [--suite KEY] [--mode any]
  util_progress_flips.py --ratchet [--baseline TS]        # rc 0 clean · 1 named · 2 could not measure
        every (tree, corpus, suite, program, mode, config) key carrying TWO DIFFERENT OUTCOMES -- impossible under a
        byte-for-byte oracle diff unless something unrecorded changed, and silently resolved by arrival order in
        every other reading of this table. rc 1 when any are named.
  util_progress_flips.py --register [--out FILE] [--problems] [--program NAME]
        THE PROGRAM REGISTER: one line per (suite, program): status, when it first passed (began working), when it was
        last seen, its outcome per mode, and -- with --problems -- the queue rows that name it (known problems).
"""
import sys, csv, argparse, collections, datetime, os, re, glob, io

HERE = os.path.dirname(os.path.abspath(__file__))
SUITES_TSV = os.environ.get("S4E_SUITES_TSV") or "/home/resources/progress/SUITES.tsv"
PO = "/home/resources/postoffice"
# ⛔ THE SUITES.tsv KEY -> PROGRESS SUITE MAP IS READ FROM ITS ONE AUTHORITY, NEVER COPIED HERE (coo 2026-09-24, on the ceo's CEO-1230
# tick: "X64T MISSING by KEY MISMATCH (SUITES.tsv x64tests, the runner appends spitbol_x64, 1656 rows; util_suite_rows_vs_progress.py
# maps it, util_progress_flips.py --coverage does not"). This file carried its own copy, RUNGS_KEYS, which knew the seven rung suites and
# not x64tests, so --coverage printed X64T MISSING beside 1656 live rows under "(not in SUITES.tsv)" -- two instruments, two answers,
# one table. It now imports DBNAME from harness/scripts/util_suite_rows_vs_progress.py, the map that audit already used.
def suite_db_names():
    """SUITES.tsv key -> the progress table's suite name (a key it does not name is its own name), or None when the one map cannot be
    read -- a caller REFUSES then, because guessing the names is exactly how a suite with 1656 rows read MISSING."""
    sd = os.path.join(os.environ.get("S4E_HOME") or os.path.join(HERE, "..", ".."), "harness", "scripts")
    sys.path.insert(0, sd)
    try:
        import util_suite_rows_vs_progress as _m
        return dict(_m.DBNAME)
    except (ImportError, AttributeError):
        return None
    finally:
        if sys.path and sys.path[0] == sd:
            sys.path.pop(0)
REPLAY = "ceo-replay"
# The declared configuration that CONTINUES a runner's undeclared series when the runner began declaring (cmd_flips' NET rule, coo
# 2026-09-23). MEASURED, not assumed: over 2026-09-20T22:00Z..09-23T22:42Z the table's declared labels were `shipped` (394,631 rows, the
# board runners) and stress or arena campaigns (SCRIP_HEAP_MB=1, SCRIP_GC_STRESS=N and their combinations, the ceo's and hq_snocone's),
# which continue nothing. ⛔ ITS LIMIT, NAMED: a program whose normal run declares its own arena (CEO-1167, e.g. a benchmark at
# SCRIP_HEAP_KB=16384) is not continued by this set; if runners begin declaring another default label, it joins here with its census.
CONTINUES_UNDECLARED = ("shipped",)
NOT_A_READING = ("REFUSE", "SKIP", "MISSING", "UNGRADED")  # the run did not measure the program: never a flip, never "the previous reading", never a status


# ⛔⭐ THE RATCHET'S BASELINE IS THE COMMIT THAT GAVE THE TABLE A `config` COLUMN, AND IT IS A CONSTANT SO
# THAT NO CALLER CAN QUIETLY MOVE THE WINDOW UNTIL IT IS GREEN. Rows before it are HISTORY: 3.58M of them predate
# the column entirely and none can be disambiguated after the fact, so judging them would be a red nobody can
# ever clear -- and a gate nobody can be green under is turned off rather than obeyed. --baseline overrides it
# for fixtures and for asking what the table looked like at an older cut; the gate pins the constant.
CONFIG_BASELINE = "2026-09-21T17:53:17"
CONFIG_BASELINE_TREE = "f839e933b"


def parse_since(s):
    m = re.fullmatch(r"(\d+)([dhm])", s.strip())
    if not m:
        raise SystemExit(f"--since wants <n>d, <n>h or <n>m, got {s!r}")
    n, u = int(m.group(1)), m.group(2)
    delta = datetime.timedelta(days=n) if u == "d" else datetime.timedelta(hours=n) if u == "h" else datetime.timedelta(minutes=n)
    return (datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None) - delta).strftime("%Y-%m-%dT%H:%M:%S")


def load(db):
    if not os.path.isfile(db):
        raise SystemExit(f"REFUSE(2): no progress database at {db}")
    rows = []
    unnamed = 0
    with open(db, encoding="utf-8", errors="replace", newline="") as f:
        rd = csv.DictReader(f, delimiter="\t")
        hdr = list(rd.fieldnames or [])
        for r in rd:
            if not r.get("ts_utc") or not r.get("program"):
                continue
            # ⛔⭐ A COLUMN THE HEADER DOES NOT NAME IS A COLUMN THIS READER CANNOT READ, AND IT SAYS SO RATHER
            # THAN DROPPING IT (coo 2026-09-21). csv.DictReader puts every field past the header into the
            # UNNAMED restkey, silently: that is how `fingerprint` -- written into every row since 2026-09-06 --
            # stayed invisible to every reader in the fleet for fifteen days while the writer's own gate was
            # green, because that gate builds its table fresh and a fresh table always gets a complete header.
            # Swallowing this would turn a wrong reader into a clean bill of health, which is the failure this
            # whole instrument exists to refuse.
            if r.get(None):
                unnamed = max(unnamed, len(r[None]))
            r["note"] = r.get("note") or ""
            r["measurer"] = r.get("measurer") or ""
            # A row written before the `config` column existed cannot say what it exercised, and `undeclared`
            # is the truthful reading of that silence -- never `shipped`, which would be this reader inventing
            # a fact about 3.5M historical runs.
            # ⛔ A SHORT ROW AND AN EXPLICITLY BLANK ONE ARE DIFFERENT FAULTS AND ONLY cmd_ratchet MAY TELL
            # THEM APART (coo 2026-09-21). csv.DictReader fills a MISSING trailing field with None; a writer
            # that emitted the column and left it empty gives "". Both read `undeclared` below, which is the
            # right reading for every other command here -- but only the first means THE WRITER IS STILL
            # EMITTING THE OLD WIDTH, which is the defect that hid `fingerprint` in 3.58M rows for fifteen days.
            r["_short"] = r.get("config") is None
            r["config"] = (r.get("config") or "").strip() or "undeclared"
            # ⭐ partition=core|shell:F|chunk:NN is the SHAPE of the run that read the program (CEO-1676 row (d)), never a configuration of the
            # program: a chunk reading and a whole-board reading of one program in one configuration are one series, so the token leaves the key.
            if "partition=" in r["config"] or "rr=1" in r["config"].split(","):   # rr=1: a reading of the coo's round robin (CEO-1805), the shape of the run too
                r["config"] = ",".join(t for t in r["config"].split(",") if not t.startswith("partition=") and t != "rr=1") or "shipped"
            rows.append(r)
    if unnamed:
        raise SystemExit(
            f"REFUSE(2): {db} writes {len(hdr) + unnamed} columns but its header names only {len(hdr)} "
            f"({', '.join(hdr)}). The last {unnamed} column(s) of every row land in csv's UNNAMED restkey and no "
            f"reader can reach them by name. This is not a reading. Run any append through "
            f"harness/scripts/util_progress_append.py, which migrates the header under the table's own lock.")
    rows.sort(key=lambda r: r["ts_utc"])
    return rows


def bucket_of(ts, per):
    if per == "hour":
        return ts[:13]
    if per == "day":
        return ts[:10]
    if per == "10m":
        return ts[:15] + "0"
    raise SystemExit(f"--per wants hour, day or 10m, got {per!r}")


def age_str(ts):
    try:
        t = datetime.datetime.strptime(ts[:19], "%Y-%m-%dT%H:%M:%S")
    except ValueError:
        return "?"
    d = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None) - t
    m = int(d.total_seconds() // 60)
    return f"{m}m" if m < 120 else f"{m // 60}h" if m < 48 * 60 else f"{m // 1440}d"


def cmd_flips(a, rows):
    since = parse_since(a.since)
    sel = [r for r in rows if (a.mode == "any" or r["mode"] == a.mode) and (a.klass == "all" or r["class"] == a.klass)
           and (not a.suite or r["suite"] == a.suite) and (not a.live_only or r["measurer"] != REPLAY)]
    last = {}
    ups = collections.defaultdict(list)
    downs = collections.defaultdict(list)
    in_window = 0
    for r in sel:
        # ⛔ SAME KEY AS THE NET MEASURE BELOW: a consecutive reading is only consecutive WITHIN one
        # configuration. Across configurations it is not a flip, it is a differential.
        k = (r["suite"], r["program"], r["mode"], r["config"])
        if r["ts_utc"] >= since:
            in_window += 1
        if r["outcome"] in NOT_A_READING:
            continue
        prev = last.get(k)
        last[k] = r
        if r["ts_utc"] < since or prev is None:
            continue
        b = bucket_of(r["ts_utc"], a.per)
        if prev["outcome"] != "PASS" and r["outcome"] == "PASS":
            ups[(b, r["class"])].append(f'{r["suite"]}:{r["program"]}:{r["mode"]}' + ('' if r["config"] == "undeclared" else f' @{r["config"]}'))
        if prev["outcome"] == "PASS" and r["outcome"] != "PASS":
            downs[(b, r["class"])].append(f'{r["suite"]}:{r["program"]}:{r["mode"]}' + ('' if r["config"] == "undeclared" else f' @{r["config"]}'))
    print(f"bucket({a.per}, UTC)   rungs +/-   package +/-   bench +/-   (mode {a.mode}; class {a.klass}; rows {len(sel)}; since {since}{'; live only' if a.live_only else ''})")
    if in_window == 0:
        newest = sel[-1]["ts_utc"] if sel else "none"
        print(f"  NO ROWS RECORDED in the window -- the newest matching row is {newest} ({age_str(newest) if sel else '-'} old). This is a recording gap, not zero flips.")
    buckets = sorted({b for b, _ in list(ups) + list(downs)})
    tm = tp = tb = 0
    for b in buckets:
        mu, md = len(ups[(b, "rungs")]), len(downs[(b, "rungs")])
        pu, pd = len(ups[(b, "package")]), len(downs[(b, "package")])
        bu, bd = len(ups[(b, "benchmark")]), len(downs[(b, "benchmark")])
        tm += mu; tp += pu; tb += bu
        print(f"{b:20s} {mu:5d}/{md:<4d}   {pu:5d}/{pd:<4d}   {bu:4d}/{bd:<4d}  " + ("#" * min(mu + pu + bu, 60)))
        if a.names:
            for k in ((b, "rungs"), (b, "package"), (b, "benchmark")):
                for x in ups[k]:
                    print("    +", x)
                for x in downs[k]:
                    print("    -", x)
    print(f"TOTAL newly-passing in window: rungs {tm}, package {tp}, benchmark {tb}  (rows in window: {in_window})")
    # ⛔⭐ A ZERO MUST SAY WHICH ZERO IT IS (coo 2026-09-21, ceo rank 0 at CEO-1047/CEO-1050). The old code said
    # "this is a recording gap, not zero flips" ONLY when the window held no rows at all -- so the far more
    # common shape printed a confident 0 with nothing beside it: rows arriving all afternoon, every one of them
    # either -dirty (skipped by rule 5) or a REPEAT READING of a program already at that outcome. Measured on
    # the live table this sitting: a 4h window with 3067 rows, ten seats working, and a bare 0 -- while THREE
    # measurers had appended over THREE of 25 suites and fifteen package suites had been silent for four days.
    # "Nothing flipped" and "almost nobody recorded" are different facts and an instrument that prints the same
    # character for both has not measured anything.
    if in_window and tm + tp + tb == 0:
        w = [r for r in sel if r["ts_utc"] >= since]
        w_clean = [r for r in w if not (r["scrip"].endswith("-dirty") or r["corpus"].endswith("-dirty"))]
        seats = sorted({r["measurer"] for r in w}); suites = sorted({r["suite"] for r in w})
        print(f"  ⛔ THE ZERO IS NOT A READING OF THE FLEET, IT IS A READING OF WHAT REACHED THIS TABLE: {in_window} rows in the "
              f"window from {len(seats)} measurer(s) over {len(suites)} suite(s), of which {len(w_clean)} carry a clean tree stamp "
              f"and {in_window - len(w_clean)} are -dirty and therefore not positions in a series (MASTER-PLAN rule 5).")
        print(f"     measurers: {', '.join(seats) or '-'}")
        print(f"     suites:    {', '.join(suites) or '-'}")
        print(f"     Every suite NOT named above contributed no evidence at all in this window. Run --coverage for their ages "
              f"before reading this zero as progress.")
    # THE NET MEASURE (coo, COO-50, MASTER-PLAN rule 5): distinct programs green at the LAST clean reading that were
    # not green at the window base -- the base is the last clean reading before the window, else the first clean
    # reading inside it. A -dirty tree stamp is cited for its number, never its position in a series, so a dirty
    # row is not a position here (--include-dirty restores the raw series). Both modes must agree for "any".
    base, latest, dirty_skipped = {}, {}, 0
    base_row, latest_row, last_pass_row = {}, {}, {}   # the rows behind base/latest, and the last PASS row per key (for the lost lines)
    for r in sel:
        if r["outcome"] in NOT_A_READING:
            continue
        if not a.include_dirty and (r["scrip"].endswith("-dirty") or r["corpus"].endswith("-dirty")):
            dirty_skipped += 1
            continue
        # ⛔⭐ THE CONFIGURATION IS PART OF THE KEY (coo 2026-09-21, ceo rank 0 at CEO-1047/CEO-1050). Keyed on
        # (suite, program, mode) alone, a program run at six GC configurations is ONE cell and the LAST row
        # appended wins -- so a PASS at the shipped arena silently overwrites a FAIL at arena=1, and the
        # divergence the fleet is hunting is invisible to this measure by construction.
        k = (r["suite"], r["program"], r["mode"], r["config"])
        if r["ts_utc"] < since or k not in base:
            base[k] = r["outcome"]; base_row[k] = r
        latest[k] = r["outcome"]; latest_row[k] = r
        if r["outcome"] == "PASS":
            last_pass_row[k] = r
    # ⛔⭐ A STOPPED UNDECLARED SERIES IS SUPERSEDED, NEVER A VERDICT OF ITS OWN (coo 2026-09-23, row instruments-progress-flips-counts-a-
    # program-lost-when-its-runner-began-declaring-a-config-and-the-undeclared-series-stopped; the ceo's 17:0x measurement). Keying on the
    # config is right (a shipped PASS must never hide an arena FAIL), but the day a runner began DECLARING its config, the program's
    # undeclared series stopped, and its last reading stayed its verdict forever: 37 rungs programs read LOST over 09-20..09-23 while every
    # one PASSED on its latest published clean reading. ONE RULE: an undeclared series is SUPERSEDED when the declared series that
    # CONTINUES it -- the same (suite, program, mode) at a configuration in CONTINUES_UNDECLARED -- has a clean reading after its last one.
    # It stops being a position, and the continuing series, when it was BORN INSIDE THE WINDOW after the undeclared base, INHERITS that
    # base, so the program is compared base -> now ACROSS the switch: a regression across the change stays LOST, a red-to-green across it
    # is a GAIN (the mirror the old rule missed), a green-then-red across it is no longer a gain (the mirror false gain). ⛔ ONLY THE
    # CONTINUING SERIES INHERITS. The first cut handed the base to EVERY declared series born in the window, and on the frozen 4.18M-row
    # snapshot rungs LOST went 37 -> 83: sixty stress and arena series (SCRIP_HEAP_MB=1, SCRIP_GC_STRESS=N, born inside the window, most
    # of them STOPPED) read as losses against an undeclared PASS they never continued. Across configurations a change is a differential,
    # not a flip (this function's own rule, and --contradictions says the same), so an arena series keeps its own base exactly as before.
    # A declared series is NEVER superseded: one whose own base was green and whose last reading is red stays LOST even beside a later
    # shipped PASS, and when it has stopped (a retired arm) it says STOPPED beside the program's latest reading. The superseded are
    # COUNTED on the NET line and NAMED under --names, so the rule is itself a reading.
    groups = collections.defaultdict(list)
    for k in latest:
        groups[k[:3]].append(k)
    superseded, stopped_decl, inherited = {}, {}, set()
    for g, ks in groups.items():
        u = g + ("undeclared",)
        decl = [k for k in ks if k[3] != "undeclared"]
        if u in latest and decl:
            later = [k for k in decl if k[3] in CONTINUES_UNDECLARED and latest_row[k]["ts_utc"] > latest_row[u]["ts_utc"]]
            if later:
                superseded[u] = max(later, key=lambda k: latest_row[k]["ts_utc"])
                for k in later:
                    if base_row[k]["ts_utc"] >= since and base_row[k]["ts_utc"] > base_row[u]["ts_utc"]:
                        base[k] = base[u]; base_row[k] = base_row[u]; inherited.add(k)
                        if k not in last_pass_row and u in last_pass_row:
                            last_pass_row[k] = last_pass_row[u]
        newest = max(ks, key=lambda k: latest_row[k]["ts_utc"])
        for k in decl:
            if latest_row[k]["ts_utc"] < latest_row[newest]["ts_utc"]:
                stopped_decl[k] = latest_row[newest]
    cls_of = {}
    for r in sel:
        cls_of.setdefault(r["suite"], r["class"])
    net = collections.defaultdict(set)
    lost = collections.defaultdict(set)
    reclass = collections.defaultdict(set)   # PASS -> OUTSIDE: a reclassification by the oracle's own measurement, never a loss (ceo CEO-806)
    RECLASS = {"OUTSIDE"}
    # ⛔⭐ PASS -> DEFERRED OR UNGRADABLE IS A PROGRAM THAT WENT DARK, NEVER "NOT A LOSS" (coo 2026-09-25, ceo CEO-1270). CEO-806 ruled
    # PASS -> OUTSIDE a reclassification, and this reader had widened that set to UNGRADABLE, UNGRADED and DEFERRED without a ruling. So
    # X64T's math_diff/div/prod/sum -- m4 PASS on 55f6339b9, then DEFERRED on 04549eb5c when the statement switch took their asm past the
    # runner's 128 MB budget -- read "lost 0" and "reclassified 4, not a loss": correct programs the runner stopped grading, reported as
    # nothing lost. They are not red either, so they get their own line: the measurement was lost (CEO-582, DARK is worse than RED).
    # UNGRADED is not here because it is NOT_A_READING, so the last real reading stands.
    dark = collections.defaultdict(set)
    DARK = {"DEFERRED", "UNGRADABLE"}
    gained_across = set()
    for k in latest:
        if k in superseded:
            continue
        suite, prog, mode, _cfg = k
        cls = cls_of.get(suite, "?")
        if base.get(k) != "PASS" and latest.get(k) == "PASS":
            net[cls].add((suite, prog))
            if k in inherited:
                gained_across.add((suite, prog))
        if base.get(k) == "PASS" and latest.get(k) != "PASS":
            # ⛔ A PASS THAT BECAME OUTSIDE IS A RECLASSIFICATION, NOT A LOSS (ceo CEO-806, 2026-09-16: seven of nine 'rungs losses' were the
            # SnoRungs ALL.outside.tsv entries appended as OUTSIDE by hq_snobol4's runner, whose 'last PASS' was the false green CEO-749 named).
            # 'lost' keeps PASS -> FAIL/CRASH/HANG (and the rest of the red family); the reclassified are printed on their own line, named.
            (reclass if latest.get(k) in RECLASS else dark if latest.get(k) in DARK else lost)[cls].add((suite, prog))
    print(f"NET distinct programs green now, not green at the window base (dirty rows skipped: {dirty_skipped}): "
          f"rungs {len(net['rungs'])}, package {len(net['package'])}, benchmark {len(net['benchmark'])}; "
          f"lost since the base: rungs {len(lost['rungs'])}, package {len(lost['package'])}, benchmark {len(lost['benchmark'])}; "
          f"went DARK (PASS -> DEFERRED/UNGRADABLE: a program that passed and is no longer graded -- not red, and never no loss): rungs {len(dark['rungs'])}, package {len(dark['package'])}, benchmark {len(dark['benchmark'])}; "
          f"reclassified (PASS -> OUTSIDE, CEO-806, not a loss): rungs {len(reclass['rungs'])}, package {len(reclass['package'])}, benchmark {len(reclass['benchmark'])}; "
          f"superseded undeclared series (a declared series of the same program and mode read after their last reading, so they are not positions): {len(superseded)}")
    if a.names:
        # ⭐ WHAT THE OLD RULE MADE OF EACH SUPERSEDED SERIES IS PRINTED BESIDE IT, and every gain is named, because the ceo's 17:0x
        # measurement found the LOSS half and the GOAL asked for the mirror in the GAIN half to be measured and named: a series that
        # went red-to-green before the switch read as a gain the program does not have, and a program red before the switch and green
        # after it read as no gain at all. Equal counts can hide different programs; only names show which ones moved.
        for u in sorted(superseded):
            ur, d = latest_row[u], superseded[u]; dr = latest_row[d]
            was = (" -- the old rule read this series a LOSS" if base[u] == "PASS" and latest[u] != "PASS" and latest[u] not in RECLASS and latest[u] not in DARK
                   else " -- the old rule read this series a GAIN" if base[u] != "PASS" and latest[u] == "PASS" else "")
            print(f"    superseded {u[0]}:{u[1]} {u[2]}: undeclared last {ur['outcome']} {ur['scrip']} {ur['ts_utc'][:16]} -> @{d[3]} {dr['outcome']} {dr['scrip']} {dr['ts_utc'][:16]}{was}")
        for cls in ("rungs", "package", "benchmark"):
            for suite, prog in sorted(net[cls]):
                print(f"    gained {suite}:{prog}" + (" (across the config switch: red on the undeclared base, green on a declared series now)" if (suite, prog) in gained_across else ""))
        for cls in ("rungs", "package", "benchmark"):
            for suite, prog in sorted(dark[cls]):
                _to = sorted({f"{m_} {v}" for (s_, p_, m_, c_), v in latest.items() if (s_, p_) == (suite, prog) and v in DARK})
                print(f"    went dark {suite}:{prog} -> {', '.join(_to)} (it passed at the base; no graded reading since)")
        for cls in ("rungs", "package", "benchmark"):
            for suite, prog in sorted(reclass[cls]):
                _to = sorted({v for (s_, p_, m_, c_), v in latest.items() if (s_, p_) == (suite, prog) and v in RECLASS})
                print(f"    reclassified {suite}:{prog} -> {'/'.join(_to)}")
    if a.names:
        # ⛔ A LOST COUNT WITHOUT NAMES CANNOT BE TRIAGED (ceo CEO-778(4)/CEO-779(5); coo 2026-09-16, row util-progress-flips-names-
        # every-lost-since-base-program): one `lost` line per program with the modes it lost, the last tree and time it read PASS,
        # and the tree, time and outcome it reads now -- the same shape as the +/- flip lines, and a row for its HQ by name.
        for cls in ("rungs", "package", "benchmark"):
            for suite, prog in sorted(lost[cls]):
                parts = []
                for k in sorted(k for k in latest if k[0] == suite and k[1] == prog and k not in superseded):
                    mode, cfg = k[2], k[3]
                    if base.get(k) == "PASS" and latest.get(k) != "PASS":
                        lp = last_pass_row.get(k, base_row.get(k)); lr = latest_row[k]
                        at = "" if cfg == "undeclared" else f" @{cfg}"
                        across = " (across the config switch: its base is the undeclared series')" if k in inherited else ""
                        st = stopped_decl.get(k)
                        stop = (f" -- STOPPED: this configuration has no reading since; the program's latest reading is {st['outcome']}"
                                f" @{st['config']} {st['scrip']} {st['ts_utc'][:16]}") if st else ""
                        parts.append(f"{mode}{at}: last PASS {lp['scrip']} {lp['ts_utc'][:16]} -> {lr['outcome']} {lr['scrip']} {lr['ts_utc'][:16]} by {lr['measurer']}{across}{stop}")
                print(f"    lost {suite}:{prog}  " + " · ".join(parts))
    return 0


def cmd_contradictions(a, rows):
    """⛔⭐ ONE TREE, ONE CORPUS, ONE PROGRAM, ONE MODE, ONE CONFIGURATION -- AND TWO DIFFERENT OUTCOMES.

    Under a byte-for-byte oracle diff that is impossible unless something the row does not record changed. Every
    reader of this table resolves such a collision BY ARRIVAL ORDER -- `latest[k] = outcome` in a loop over rows
    sorted by time -- so the losing arm simply disappears and the measure reports the survivor with no sign that
    anything was overwritten. That is the shape this command refuses to leave silent.

    Measured on the live table when this was written (2026-09-21, before the `config` column existed): 139 such
    keys since 09-20, e.g. raku-rungs token_say_4 m3 reading both PASS and FAIL at the CLEAN tree 5418432bb.
    Those historical rows all read config=undeclared and CANNOT be disambiguated after the fact -- naming them is
    the honest thing available. A contradiction between two DECLARED configurations is not listed here: that is a
    differential finding, and it is what the new key preserves instead of destroying.

    rc 0 = none · rc 1 = contradictions named.
    """
    since = parse_since(a.since)
    sel = [r for r in rows if r["ts_utc"] >= since and r["outcome"] not in NOT_A_READING
           and (a.mode == "any" or r["mode"] == a.mode) and (a.klass == "all" or r["class"] == a.klass)
           and (not a.suite or r["suite"] == a.suite)]
    seen = collections.defaultdict(lambda: collections.defaultdict(list))
    for r in sel:
        seen[(r["scrip"], r["corpus"], r["suite"], r["program"], r["mode"], r["config"])][r["outcome"]].append(r)
    bad = {k: v for k, v in seen.items() if len(v) > 1}
    print(f"contradictions: one tree, one corpus, one program, one mode, ONE CONFIGURATION, two or more outcomes "
          f"(mode {a.mode}; class {a.klass}; since {since}; rows examined {len(sel)})")
    if not bad:
        print(f"  none over {len(seen)} distinct keys -- every key reads one outcome, so no reading in this window was "
              f"silently overwritten by arrival order.")
        return 0
    by_suite = collections.Counter(k[2] for k in bad)
    undeclared = sum(1 for k in bad if k[5] == "undeclared")
    print(f"  ⛔ {len(bad)} CONTRADICTORY KEY(S) over {len(seen)} distinct keys. {undeclared} of them carry "
          f"config=undeclared, which means the table cannot say what differed and the difference is UNRECOVERABLE.")
    for suite, n in by_suite.most_common():
        print(f"     {suite:20s} {n}")
    for k in sorted(bad)[:40]:
        tree, corpus, suite, prog, mode, cfg = k
        outs = bad[k]
        detail = " · ".join(f"{oc} x{len(rs)} ({rs[0]['ts_utc'][:16]} by {rs[0]['measurer']})" for oc, rs in sorted(outs.items()))
        print(f"    {suite}:{prog}:{mode} @{cfg} tree {tree} corpus {corpus} -> {detail}")
    if len(bad) > 40:
        print(f"    ... and {len(bad) - 40} more (narrow with --suite/--since)")
    print("  ⛔ NOT RESOLVED HERE AND NOT RESOLVABLE HERE. Each of these is a row for the suite's owner: either the run "
        "was not the configuration the row claims, or the program is nondeterministic, and those are different defects.")
    return 1


def ratchet_scan(db, base):
    """THE CONFIGURATION RATCHET'S INPUTS IN TWO STREAMING PASSES, WITHOUT HOLDING THE TABLE (coo 2026-09-23, the ceo's CEO-1212
    under CEO-801): load() builds a dict per row of the whole table -- 4.18M rows, measured at 4556 MB tree-wide, the heaviest arm
    of the blocking set and the one that set its memory cap -- to answer a question about a few per-lane aggregates. This reads
    the file twice with the SAME csv dialect, the SAME row filter and the SAME column semantics as load(), and emulates load()'s
    stable sort by timestamp with (ts_utc, file position) keys, so every count, every order and every tie reads exactly as
    cmd_ratchet read them over load(); test_gate_progress_readers_stream_and_answer_the_same.sh holds that byte for byte.
    Returns a dict of aggregates, or raises the same SystemExit load() raises on an unnamed column."""
    if not os.path.isfile(db):
        raise SystemExit(f"REFUSE(2): no progress database at {db}")
    def rows_of():
        with open(db, encoding="utf-8", errors="replace", newline="") as f:
            rd = csv.reader(f, delimiter="\t")
            hdr = next(rd, [])
            yield hdr
            nh = len(hdr)
            ix = {h: i for i, h in enumerate(hdr)}
            i_ts, i_prog, i_mode, i_suite, i_meas, i_cfg = (ix.get(c, 1 << 30) for c in
                                                            ("ts_utc", "program", "mode", "suite", "measurer", "config"))
            idx = -1
            for fl in rd:
                if not fl:
                    continue
                idx += 1
                n = len(fl)
                ts = fl[i_ts] if i_ts < n else None
                prog = fl[i_prog] if i_prog < n else None
                if not ts or not prog:
                    yield None   # load() skips these BEFORE it reads their unnamed columns
                    continue
                cfg = fl[i_cfg] if i_cfg < n else None
                yield ((ts, idx), n - nh if n > nh else 0, ts, prog, fl[i_mode] if i_mode < n else None,
                       fl[i_suite] if i_suite < n else None, (fl[i_meas] if i_meas < n else None) or "",
                       cfg is None, (cfg or "").strip() or "undeclared")
    it = rows_of(); hdr = next(it)
    n_rows = 0; newest = None; unnamed = 0
    n_sel = 0; declared = 0
    short_n, short_first, short_min_ts = {}, {}, {}
    first_decl = {}
    for row in it:
        if row is None:
            continue
        key, extra, ts, _prog, _mode, suite, meas, short, cfg = row
        if extra and extra > unnamed: unnamed = extra
        n_rows += 1
        if newest is None or ts > newest: newest = ts
        if ts < base:
            continue
        n_sel += 1
        k = (meas, suite)
        if short:
            short_n[k] = short_n.get(k, 0) + 1
            if k not in short_first or key < short_first[k]: short_first[k] = key
            if k not in short_min_ts or ts < short_min_ts[k]: short_min_ts[k] = ts
        if cfg != "undeclared":
            declared += 1
            if k not in first_decl or key < first_decl[k]: first_decl[k] = key
    if unnamed:
        raise SystemExit(
            f"REFUSE(2): {db} writes {len(hdr) + unnamed} columns but its header names only {len(hdr)} "
            f"({', '.join(hdr)}). The last {unnamed} column(s) of every row land in csv's UNNAMED restkey and no "
            f"reader can reach them by name. This is not a reading. Run any append through "
            f"harness/scripts/util_progress_append.py, which migrates the header under the table's own lock.")
    later_n, later_first = {}, {}
    if first_decl:
        it = rows_of(); next(it)
        for row in it:
            if row is None:
                continue
            key, _extra, ts, prog, mode, suite, meas, _short, cfg = row
            if ts < base or cfg != "undeclared":
                continue
            k = (meas, suite)
            if k in first_decl and key > first_decl[k]:
                later_n[k] = later_n.get(k, 0) + 1
                if k not in later_first or key < later_first[k][0]: later_first[k] = (key, prog, mode)
    return {"n_rows": n_rows, "newest": newest, "n_sel": n_sel, "declared": declared,
            "short": sorted(((-n, short_first[k], k, n, short_min_ts[k]) for k, n in short_n.items())),
            "first_decl": {k: v[0] for k, v in first_decl.items()},
            "later": sorted(((-n, later_first[k][0], k, n, later_first[k]) for k, n in later_n.items()))}


def cmd_ratchet(a, _rows=None):
    """⛔⭐ A LANE THAT HAS DECLARED ITS CONFIGURATION MAY NEVER SILENTLY STOP, AND NO WRITER MAY STILL BE
    EMITTING THE OLD WIDTH.

    THE HOLE THIS CLOSES, quoted from the writer it closes it around. util_progress_append.py refuses an
    undeclared row in exactly ONE case: when a GC axis is set IN ITS OWN PROCESS ENVIRONMENT. That refusal is
    correct and it is also bounded, and the writer's own comment says why -- "the runner may set the axis
    per-child, so an empty environment here is an ABSENCE OF EVIDENCE about the child". A runner that forks its
    children with SCRIP_GC_STRESS set and then appends from a clean parent meets no refusal at all. So the
    undeclared population can grow forever and the writer's guard can never fire on it. That is the ratchet's
    subject, and it is judged HERE, against the long-lived table, because that is the only place the defect
    exists -- a gate that builds its subject fresh under mktemp cannot see it (the fifteen-day `fingerprint`
    blindness is the proof).

    THREE ARMS AND A FLOOR:
      A  SHORT ROWS -- a row appended at or after the baseline carrying FEWER COLUMNS than the header names.
         This is the exact shape that hid `fingerprint` inside 3.58M rows for fifteen days while its own gate
         stayed green. 13610 such rows were appended earlier on the baseline's own day.
      B  DECLARATION REGRESSION -- a (measurer, suite) pair that HAS declared a real configuration at or after
         the baseline and later appended `undeclared` anyway. Absence is tolerated; REGRESSION is not.
      FLOOR  zero rows at or after the baseline is REFUSE(2), never green: an instrument that reports success
         while doing nothing is the recurring failure (RULES.md INSTRUMENT LAWS).

    ⛔ WHAT THIS DELIBERATELY DOES NOT DO, AND THE NUMBER THAT DECIDED IT: it does not red a lane that has
    NEVER declared. On the day it was written exactly ONE measurer had declared a configuration SINCE THE COLUMN
    EXISTED -- hq_snocone, 12096 rows -- and the other nine had not. ⛔ BOUNDED IN PLACE 2026-09-21 BY THE ceo
    (CEO-1060) AND THE BOUND IS RIGHT: the `config` column did not EXIST before 17:53:17Z, so "has ever declared"
    spans THIRTY MINUTES, and a population that could not have contained the thing cannot be evidence that nobody
    does it -- A NULL RESULT BOUNDS THE PROBE, NOT THE THING PROBED. What the number actually establishes is that
    ONE SEAT HAS RUN A BOARD THROUGH THE NEW WRITER AND IT DECLARED CORRECTLY: a working mechanism with a sample
    of one, NOT fleet-wide non-compliance. The design conclusion is UNCHANGED and is if anything stronger -- with
    nine lanes not yet observed at all, a ratchet on ABSENCE would red seats whose behaviour has never been
    measured. A ratchet on ABSENCE would therefore
    have been a fleet-wide red on arrival, and a gate nobody can be green under is turned off rather than
    obeyed. The floor rises one lane at a time, by that lane's own first declaration, and from then on it
    cannot fall. That is what makes it a ratchet rather than a deadline.

    rc 0 = clean · rc 1 = named · rc 2 = could not measure.
    """
    base = a.baseline or CONFIG_BASELINE
    # ⛔ THE WINDOW NAMES ITSELF HONESTLY OR THE READING IS UNLABELLED. An overridden baseline is NOT the
    # column's commit and must never be printed as though it were: this line said "= SCRIP f839e933b" under
    # --baseline on its first run, which is the same class of fault -- a number wearing a provenance it does
    # not have -- that this whole instrument exists to refuse.
    origin = (f"= SCRIP {CONFIG_BASELINE_TREE}, the commit that added the column"
              if not a.baseline else "OVERRIDDEN by --baseline; this is NOT the column's commit")
    sc = ratchet_scan(a.db, base)
    newest = sc["newest"] if sc["n_rows"] else "<none>"
    print(f"config ratchet: no short rows, and no lane stops declaring once it has started "
          f"(baseline {base} {origin}; rows at or after it {sc['n_sel']} of {sc['n_rows']}; "
          f"newest row in table {newest})")
    if not sc["n_sel"]:
        print(f"  ⛔ REFUSE(2): NOTHING TO MEASURE. Not one row has been appended at or after the baseline, so "
              f"every arm below would be vacuously green over an EMPTY population. The newest row in the table "
              f"is {newest}. A ratchet with no population is not a reading of the fleet, it is a reading of "
              f"nothing (RULES.md INSTRUMENT LAWS: a missing prerequisite is rc=2, never green).")
        return 2

    bad = 0

    # ---- ARM A: the writer is still emitting the old width -------------------------------------------------
    short = sc["short"]
    if short:
        bad += 1
        print(f"  ⛔ ARM A -- {sum(x[3] for x in short)} SHORT ROW(S) of {sc['n_sel']}: appended at or after the baseline with "
              f"fewer columns than the header names, so the trailing column(s) are ABSENT rather than blank and "
              f"no reader can tell the difference after the fact.")
        for _neg, _first_key, (m, s), n, first in short[:12]:
            print(f"     {m or '<no measurer>':12s} {s:20s} {n:6d} row(s), first {first}")
        if len(short) > 12:
            print(f"     ... and {len(short) - 12} more (measurer, suite) pair(s)")
        print("     FIX: append through harness/scripts/util_progress_append.py, which writes every column the "
              "header names and migrates the header under the table's own lock.")
    else:
        print(f"  ok   ARM A: 0 short rows of {sc['n_sel']} -- every row at or after the baseline carries the full "
              f"header width.")

    # ---- ARM B: a lane that declared, then stopped ---------------------------------------------------------
    first_decl, later_undecl = sc["first_decl"], sc["later"]
    if later_undecl:
        bad += 1
        print(f"  ⛔ ARM B -- {len(later_undecl)} LANE(S) STOPPED DECLARING after they had started. A pair that "
              f"has recorded what it exercised and then records `undeclared` is not a lane that never had the "
              f"axis: it is a lane whose next board collapses into the SAME (suite, program, mode) cell as the "
              f"reading it should be compared against, and the collision is resolved by ARRIVAL ORDER.")
        for _neg, _first_key, k, n, (fk, fprog, fmode) in later_undecl:
            m, s = k
            print(f"     {m or '<no measurer>':12s} {s:20s} declared first at {first_decl[k]}, then {n} "
                  f"undeclared row(s) from {fk[0]} (e.g. {fprog} {fmode})")
        print("     FIX: declare it -- --config shipped, or --config 'SCRIP_GC_STRESS=5,SCRIP_HEAP_MB=1'. The "
              "writer GUESSES NOTHING and will not infer `shipped` from an empty environment (CEO-812 applied "
              "to the record instead of the heap).")
    else:
        print(f"  ok   ARM B: {len(first_decl)} lane(s) have declared at or after the baseline and not one of "
              f"them has stopped.")

    declared = sc["declared"]
    print(f"  population: {sc['n_sel']} row(s) at or after the baseline · {declared} declared · "
          f"{sc['n_sel'] - declared} undeclared · {len(first_decl)} declaring lane(s) "
          f"({', '.join(sorted({m for m, _ in first_decl})) or 'none'})")
    if bad:
        print(f"  ⛔ RATCHET RED on {bad} of 2 arm(s).")
        return 1
    print("  ✅ RATCHET GREEN. No lane that has declared has stopped, and no writer is emitting the old width.")
    return 0


def read_suites_tsv():
    out = []
    if not os.path.isfile(SUITES_TSV):
        return out
    with open(SUITES_TSV, encoding="utf-8") as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            parts = line.rstrip("\n").split("\t")
            if parts[0] == "key":
                hdr = parts
                continue
            d = dict(zip(hdr, parts))
            out.append(d)
    return out


def cmd_coverage(a, rows):
    by = collections.defaultdict(lambda: {"rows": 0, "live": 0, "programs": set(), "last": "", "modes": set(), "class": ""})
    for r in rows:
        b = by[r["suite"]]
        b["rows"] += 1
        b["live"] += (r["measurer"] != REPLAY)
        b["programs"].add(r["program"])
        b["modes"].add(r["mode"])
        b["class"] = r["class"]
        if r["ts_utc"] > b["last"]:
            b["last"] = r["ts_utc"]
    suites = read_suites_tsv()
    names = suite_db_names()
    if names is None:
        print("REFUSE(rc=2): --coverage cannot read the SUITES.tsv-key -> progress-suite map from harness/scripts/util_suite_rows_vs_progress.py "
              "(DBNAME) beside this .github -- without it a suite whose runner appends under another name reads MISSING", file=sys.stderr)
        return 2
    print(f"{'suite (SUITES.tsv key)':24s} {'nick':8s} {'db suite':16s} {'rows':>6s} {'live':>6s} {'programs':>12s} {'modes':8s} {'last row (UTC)':20s} age")
    missing = []
    seen = set()
    for s in suites:
        key = s["key"]
        dbk = names.get(key, key)
        seen.add(dbk)
        b = by.get(dbk)
        total = s.get("today_total", "?")
        if not b:
            missing.append(f"{key} ({s.get('nick', '')}, {total} programs in the table)")
            print(f"{key:24s} {s.get('nick', ''):8s} {dbk:16s} {0:6d} {0:6d} {'0/' + str(total):>12s} {'-':8s} {'-':20s} MISSING")
            continue
        print(f"{key:24s} {s.get('nick', ''):8s} {dbk:16s} {b['rows']:6d} {b['live']:6d} {str(len(b['programs'])) + '/' + str(total):>12s} {','.join(sorted(b['modes'])):8s} {b['last']:20s} {age_str(b['last'])}")
    extra = [k for k in by if k not in seen]
    for k in sorted(extra):
        b = by[k]
        print(f"{'(not in SUITES.tsv)':24s} {'':8s} {k:16s} {b['rows']:6d} {b['live']:6d} {len(b['programs']):>12d} {','.join(sorted(b['modes'])):8s} {b['last']:20s} {age_str(b['last'])}  class={b['class']}")
    live_total = sum(b["live"] for b in by.values())
    print(f"SUMMARY: {len(suites) - len(missing)} of {len(suites)} table suites have rows; {len(missing)} MISSING; live (non-replay) rows {live_total} of {len(rows)}; benchmark suites seen: {sorted(k for k, b in by.items() if b['class'] == 'benchmark') or 'NONE'}")
    for m in missing:
        print("  MISSING:", m)
    return 0


def problems_index(programs):
    """program -> [queue rows / task files naming it]. One pass over the postoffice; exact-token match."""
    idx = collections.defaultdict(set)
    names = sorted(programs, key=len, reverse=True)
    pat = re.compile(r"(?<![A-Za-z0-9_])(" + "|".join(re.escape(n) for n in names if len(n) >= 4) + r")(?![A-Za-z0-9_])") if names else None
    if pat is None:
        return idx
    for f in glob.glob(os.path.join(PO, "tasks", "*.task.md")):
        topic = os.path.basename(f)[:-len(".task.md")]
        try:
            txt = io.open(f, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        for m in set(pat.findall(txt)):
            idx[m].add(topic)
    states = {}
    try:
        for line in io.open(os.path.join(PO, "QUEUE.tsv"), encoding="utf-8", errors="replace"):
            p = line.rstrip("\n").split("\t")
            if len(p) >= 4 and not line.startswith("#"):
                states[p[1]] = p[3]
    except OSError:
        pass
    return {k: sorted(f"{t}[{states.get(t, 'done/retired')}]" for t in v) for k, v in idx.items()}


def cmd_register(a, rows):
    per = collections.defaultdict(lambda: {"class": "", "lang": "", "modes": collections.defaultdict(dict), "first_pass": "", "last": "", "ever_pass": False, "was_pass_then_broke": ""})
    for r in rows:
        if a.program and r["program"] != a.program:
            continue
        if a.suite and r["suite"] != a.suite:
            continue
        # ⛔ ONE ROW PER (suite, program, CONFIGURATION) -- blending configurations here would report a program
        # as WORKING because it passes at the shipped arena while it CRASHES at arena=1, which is precisely the
        # class of fact this register exists to surface.
        k = (r["suite"], r["program"], r["config"])
        e = per[k]
        e["class"], e["lang"] = r["class"], r["lang"]
        e["last"] = max(e["last"], r["ts_utc"])
        if r["outcome"] in NOT_A_READING:
            e.setdefault("unmeasured", set()).add(r["mode"])
            continue
        md = e["modes"][r["mode"]]
        prev = md.get("outcome")
        md["outcome"], md["ts"], md["measurer"] = r["outcome"], r["ts_utc"], r["measurer"]
        if r["outcome"] == "PASS":
            e["ever_pass"] = True
            if not e["first_pass"] or r["ts_utc"] < e["first_pass"]:
                e["first_pass"] = r["ts_utc"]
            if not md.get("first_pass"):
                md["first_pass"] = r["ts_utc"]
        if prev == "PASS" and r["outcome"] != "PASS":
            md["broke"] = r["ts_utc"]
    probs = problems_index({p for _, p, _c in per}) if a.problems else {}
    out = io.StringIO()
    w = csv.writer(out, delimiter="\t", lineterminator="\n")
    w.writerow(["suite", "program", "config", "class", "lang", "status", "began_working_utc", "last_seen_utc", "m3", "m4", "ast", "last_measurer", "known_problems"])
    counts = collections.Counter()
    for (suite, prog, cfg), e in sorted(per.items()):
        modes = e["modes"]
        graded = {m: d["outcome"] for m, d in modes.items()}
        # ⛔ THE STATUS IS READ OVER THE GRADED MODES, m3 AND m4, WHEREVER THE PROGRAM HAS ONE (coo 2026-09-25, ceo CEO-1269).
        # The harness's dead "ast" default graded --dump-ast against run refs and wrote rebus-rungs ast FAIL rows three
        # times (coo 09-21, ceo 09-24 and 09-25), so arith_divide at the shipped config read PARTIAL(m3,m4) with m3 and m4
        # both PASS -- 75 rebus-rungs register rows carried ast=FAIL. ast still decides an entry that was only ever
        # graded in ast (the parser-ladder entries before corpus a6646f04c), and its column is still printed.
        basis = {m: o for m, o in graded.items() if m in ("m3", "m4")} or graded
        passing = [m for m, o in basis.items() if o == "PASS"]
        if basis and len(passing) == len(basis):
            status = "WORKING"
        elif passing:
            status = "PARTIAL(" + ",".join(sorted(passing)) + ")"
        elif any(modes[m].get("first_pass") for m in basis):
            status = "REGRESSED"
        elif not graded:
            status = "UNGRADED"
        else:
            status = "NEVER-PASSED"
        counts[status.split("(")[0]] += 1
        last_meas = max(modes.values(), key=lambda d: d["ts"])["measurer"] if modes else ""
        w.writerow([suite, prog, cfg, e["class"], e["lang"], status, e["first_pass"] or "-", e["last"], graded.get("m3", "-"), graded.get("m4", "-"), graded.get("ast", "-"), last_meas, "; ".join(probs.get(prog, [])) if a.problems else ""])
    text = out.getvalue()
    if a.out:
        with open(a.out, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print(f"register: {len(per)} programs -> {a.out}  " + "  ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    else:
        sys.stdout.write(text)
        print("# " + "  ".join(f"{k}={v}" for k, v in sorted(counts.items())) + f"  programs={len(per)}", file=sys.stderr)
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", default=os.environ.get("S4E_PROGRESS_DB") or "/home/resources/progress/results.tsv")
    ap.add_argument("--since", default="3d")
    ap.add_argument("--per", default="hour")
    ap.add_argument("--mode", default="m3")
    ap.add_argument("--class", dest="klass", default="all")
    ap.add_argument("--suite", default="")
    ap.add_argument("--live-only", action="store_true")
    ap.add_argument("--include-dirty", action="store_true", help="count -dirty tree rows as positions in the NET series (default: skipped, MASTER-PLAN rule 5)")
    ap.add_argument("--names", action="store_true")
    ap.add_argument("--coverage", action="store_true")
    ap.add_argument("--contradictions", action="store_true", help="name every (tree, corpus, suite, program, mode, config) key carrying two different outcomes -- readings this table's readers resolve by ARRIVAL ORDER")
    ap.add_argument("--ratchet", action="store_true", help="the configuration ratchet: no writer still emits the old column width, and no lane that has declared what it exercised has silently stopped (judged against the LIVE table, never a fixture)")
    ap.add_argument("--baseline", default="", help="with --ratchet: override the baseline timestamp (default: the commit that added the `config` column)")
    ap.add_argument("--register", action="store_true")
    ap.add_argument("--problems", action="store_true", help="with --register: name the queue rows / task files that mention each program (one pass over the postoffice)")
    ap.add_argument("--program", default="", help="with --register: one program")
    ap.add_argument("--out", default="", help="with --register: write the TSV here instead of stdout")
    a = ap.parse_args()
    if a.ratchet:
        return cmd_ratchet(a)   # streams the table itself -- never load() (ratchet_scan)
    # THE CURRENT TABLE (Lon 2026-09-29, in-chat to the cto, verbatim: "delete th entire file and just keep an CURRENT TABLE. We are
    # close enough to 100% now to do that."; the swap ran 18:57 CDT, SCRIP 52b2a0ffd's upsert): results.tsv.current beside the table
    # means a board REPLACES the row of each key it re-measures, so no earlier reading survives. A flip is two readings of one key and
    # a contradiction is two outcomes on one key; neither can exist here, so those arms REFUSE rc=2 rather than print a zero that
    # reads like a measurement (INSTRUMENT LAWS). --coverage reads the current rows unchanged; --register's first-PASS column becomes
    # the earliest reading still in the table and says so.
    current = os.path.exists(a.db + ".current")
    if current and not (a.coverage or a.register or a.program):
        print("⛔ REFUSED (rc=2): %s is a CURRENT TABLE (%s.current): one row per (class, suite, lang, program, mode), each re-measure "
              "REPLACES its row, so no key keeps two readings and %s cannot be measured here -- a zero would describe the table, not the "
              "fleet. The transition a board makes is visible only to the writer, at the moment it replaces a row." % (
                  a.db, a.db, "a contradiction" if a.contradictions else "a flip (not-PASS -> PASS across two readings)"))
        return 2
    rows = load(a.db)
    if a.coverage:
        return cmd_coverage(a, rows)
    if a.contradictions:
        return cmd_contradictions(a, rows)
    if a.register or a.program:
        a.register = True
        if current:
            print("⛔ %s is a CURRENT TABLE: the register's first-PASS column is the earliest reading STILL IN THE TABLE (the latest PASS "
                  "of each key re-measured since the swap), not when the program began working; REGISTER.tsv as built before the swap "
                  "keeps the history." % a.db, file=sys.stderr)
        return cmd_register(a, rows)
    return cmd_flips(a, rows)


if __name__ == "__main__":
    sys.exit(main())
