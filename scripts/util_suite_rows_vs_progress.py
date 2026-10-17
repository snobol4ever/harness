#!/usr/bin/env python3
"""util_suite_rows_vs_progress.py -- THE CROSS-LANGUAGE BATCH AUDIT (MODE line 2 under DECTET, CEO-775; ceo CEO-780a; coo
2026-09-16, row util-suite-rows-vs-progress-the-cross-language-batch-audit-lands-as-an-instrument).

After each batch every HQ's suite rows are on origin and AGREE with the progress DB; a disagreement is a row. This reads
every .github/SUITES.tsv row against /home/resources/progress/results.tsv ON THE ROW'S OWN TREE (column `tree`), over the
modes each program declares (its LAST outcome per mode; PASS only when every recorded mode reads PASS), and prints per row:

    key  row pass/total  DB pass/population  xpass  measurer  last DB reading  verdict

  numerator   row today_pass  vs  DB PASS (AND over declared modes)
  denominator row today_total vs  DB population = every program with a row on that tree, plus every entry of the suite's
              OUTSIDE sidecar not already there (a sidecar-named program is OUTSIDE whatever the DB called it; the same
              reconciliation test_gate_score_row_denominator_includes_xfails.sh uses, sourced from one table below)
  xpass       programs whose PASS rows carry the note `xfail` -- THE DB FOLDS XPASS INTO PASS AND A SUITE BOARD DOES NOT
              (hq_snocone 2026-09-16): a numerator gap EQUAL to xpass means stale xfail markers still on the suite (promote
              them, CEO-753); a gap with xpass 0 means the row is simply behind its tree or its runner counts differently.

VERDICT per row: AGREE · DISAGREE (numerator and/or denominator, each with the difference) · UNPROVEN (no DB rows on the
row's tree, named -- CEO-750: a row without per-program evidence is DARK wearing a number) · DEFERRED (no tree, a DEFERRED
criterion: gnu_fd, CEO-579). rc=1 when any graded row DISAGREES; rc=2 when zero rows are gradable; else 0. An UNPROVEN row
does not by itself make rc=2 (CEO-786 confirmed this reading for the sibling gate: a per-row rc=2 is a standing refusal).

--selftest builds a scratch SUITES.tsv, DB and corpus under mktemp: an agreeing row, a planted NUMERATOR disagreement whose
gap equals its xpass count, a planted DENOMINATOR disagreement, an UNPROVEN row and a DEFERRED row, and proves rc=1 naming
the planted rows with the xpass column, rc=0 once they are removed, rc=2 on an empty DB.

env: S4E_SUITES_TSV, S4E_PROGRESS_DB, S4E_CORPUS_ROOT redirect the three inputs (the selftest and gates use them).
"""
import sys, os, re, collections, tempfile, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
CRITERION_NOTE_RX = re.compile(r"^(?!xfail$)[a-z]+(-[a-z]+)+$")   # a criterion label in the note column, e.g. outcome-class; hashes and xfail never match
DBNAME = {"sno-rungs": "snobol4-rungs", "icn-rungs": "icon-rungs", "pl-rungs": "prolog-rungs", "pas-rungs": "pascal-rungs",
          "raku-rungs": "raku-rungs", "snc-rungs": "snocone-rungs", "reb-rungs": "rebus-rungs", "x64tests": "spitbol_x64", "x32tests": "spitbol_x32"}
SIDECAR = {"sno-rungs": "tests/snobol4/ALL.outside.tsv",
           "gimpel": "packages/snobol4/gimpel/OUTSIDE_SPITBOL_BASELINE.tsv",
           "csnobol4": "packages/snobol4/csnobol4_suite/OUTSIDE_SPITBOL_BASELINE.tsv",
           "snoflake": "packages/snobol4/snoflake_suite/OUTSIDE_SPITBOL_BASELINE.tsv",
           "aisnobol": "packages/snobol4/aisnobol/OUTSIDE_SPITBOL_BASELINE.tsv",
           "dotnet": "packages/snobol4/dotnet/OUTSIDE_SPITBOL_BASELINE.tsv",
           "testpgms": "packages/snobol4/spitbol_testpgms/OUTSIDE_SPITBOL_BASELINE.tsv",
           "arizona": "packages/icon/arizona_tests/OUTSIDE_ARIZONA_BASELINE.tsv",
           "jcon": "packages/icon/jcon_tests/OUTSIDE_ARIZONA_BASELINE.tsv"}
UNG = {"UNGRADED", "SKIP", "MISSING", "UNPROVEN"}


# ⛔ A DRIVER IS ITS LIBRARY'S VEHICLE (CEO-1269): the progress writer records NAME_driver under NAME, and a sidecar written before the
# re-keying still names the driver (gimpel's OUTSIDE file: BAL_driver.sno), so the stem folds the suffix -- else the one program
# counts twice, once from the DB and once from the sidecar (gimpel read 160 against its row of 148, coo 2026-09-25).
# ⛔ AN INCLUDE LIBRARY'S FILE IS NAME.INC OR NAME.inc AND ITS PROGRESS KEY STAYS NAME.sno (corpus fb0900573; ceo CEO-1317, declared in
# gimpel's README): the stem folds .INC/.inc too, else gimpel's sidecars named 10 libraries a second time (152 against its row of 142).
# ⛔ AND THE PAIR CONVENTION: a stem the package ships twice, as the program x.spt and the library x.inc, is graded through x_driver and
# x_lib_driver (gimpel since CEO-1319), so x_lib_driver's stem is x -- else its OUTSIDE row counted a 146th program against gimpel's 145.
def stem(n):
    b = re.sub(r"\.(sno|spt|sc|icn|pl|reb|raku|pas|inc|INC)$", "", n.split("/")[-1])
    return b[: -len("_lib_driver")] if b.endswith("_lib_driver") else re.sub(r"_driver$", "", b)


# ⛔ PACKAGES WITH NO OUTSIDE FILE WHOSE ROW IS STILL THEIR SHIPPED POPULATION (ceo CEO-1272, coo 2026-09-25): IPL publishes the
# inventory's shipped count since SCRIP e6120e5ba, so its UNGRADED/UNGRADABLE sidecars are part of the row's denominator exactly as
# they are for the packages above; without the fold the audit read IPL's 843 against a DB population of 194.
PKG_SIDECARS = {"ipl": "packages/icon/ipl", "puzzles": "packages/prolog/puzzles"}


def container_stems(corpus, key):
    """The names a row's denominator leaves out, from the sidecars beside the suite: CONTAINERS.tsv (CEO-1272, files that are not
    programs) and EXCLUDED.tsv (CEO-1286, programs not in the SPITBOL dialect) -- together the row's Excl (CEO-1288). A DB row
    written for one on an older corpus, before its sidecar named it, is not a program of the row and is not counted."""
    d = os.path.dirname(SIDECAR[key]) if key in SIDECAR else PKG_SIDECARS.get(key)
    out = set()
    for fn in ("CONTAINERS.tsv", "EXCLUDED.tsv"):
        fp = os.path.join(corpus, d, fn) if d else ""
        if fp and os.path.exists(fp):
            names = [l.split("\t")[0].strip() for l in open(fp, encoding="utf-8", errors="replace") if l.strip() and not l.startswith("#")]
            # a PATH-keyed package (IPL, sidecar_stems) names one FILE per row, never every file sharing its basename
            out |= {("path:" + n) if path_keyed(key) else stem(n) for n in names}
    return out


def path_keyed(key):
    return key not in SIDECAR and key in PKG_SIDECARS


def _noext(n):
    return re.sub(r"\.[A-Za-z0-9]+$", "", n)


def read_rows(suites):
    rows = []
    for line in open(suites, encoding="utf-8"):
        if line.startswith("#") or line.startswith("key") or not line.strip():
            continue
        c = line.rstrip("\n").split("\t")
        while len(c) < 12:
            c.append("")
        rows.append(c)
    return rows


def read_db(db, want):
    """last outcome (and note, measurer, ts) per (suite, tree, program, mode) for the wanted (suite, tree) pairs."""
    last = {}
    with open(db, encoding="utf-8") as fh:
        fh.readline()
        for line in fh:
            f = line.rstrip("\n").split("\t")
            if len(f) < 10 or (f[5], f[1]) not in want or f[8] not in ("m3", "m4"):
                continue
            last[(f[5], f[1], f[7], f[8])] = (f[9], f[11] if len(f) > 11 else "", f[3], f[0])
    return last


def sidecar_stems(corpus, key):
    """(outside, ungradable, ungraded) name sets from the suite's sidecars: the OUTSIDE file the map names, plus the
    package's UNGRADABLE.tsv / UNGRADED.tsv beside it (ceo CEO-798: the runner's PACKAGE_INVENTORY line is the population
    authority and those two files are its record on disk; csnobol4: 61 UNGRADABLE of which the 49 OUTSIDE are a subset)."""
    sc = SIDECAR.get(key)
    out, ungradable, ungraded = set(), set(), set()
    if not sc and key in PKG_SIDECARS:
        # keyed by PATH, not stem: these packages record only their graded programs in the DB, never a sidecar one, and IPL ships four
        # basenames twice over (gener, morse, rep ... in procs/ and progs/), so a stem key merged four distinct files (843 read 839)
        for fn, dst in (("UNGRADABLE.tsv", ungradable), ("UNGRADED.tsv", ungraded)):
            fp = os.path.join(corpus, PKG_SIDECARS[key], fn)
            if os.path.exists(fp):
                for l in open(fp, encoding="utf-8", errors="replace"):
                    if l.startswith("#") or not l.strip():
                        continue
                    dst.add("path:" + l.split("\t")[0].strip())
        return out, ungradable, ungraded - ungradable
    if sc and os.path.exists(os.path.join(corpus, sc)):
        for l in open(os.path.join(corpus, sc), encoding="utf-8", errors="replace"):
            if l.startswith("#") or not l.strip():
                continue
            name = l.split("\t")[0].strip()
            # a name carrying ':' is a ROW inside an already-graded program, not a program of its own (ceo
            # CEO-516: lgint's three unbounded bigexp arms are named this way so lgint stays in the graded
            # population) -- counting it here double-counts the program as an extra OUTSIDE entry.
            if ":" in name:
                continue
            out.add(stem(name))
    # the lockdown buckets sit beside the OUTSIDE file and are read whether or not it exists: a package whose last OUTSIDE row was
    # graded deletes the file (test_gate_icn_outside_baseline_is_read_and_mirrored.sh refuses an empty one), and its UNGRADED rows stand
    if sc:
        for fn, dst in (("UNGRADABLE.tsv", ungradable), ("UNGRADED.tsv", ungraded)):
            fp = os.path.join(corpus, os.path.dirname(sc), fn)
            if os.path.exists(fp):
                for l in open(fp, encoding="utf-8", errors="replace"):
                    if l.startswith("#") or not l.strip():
                        continue
                    dst.add(stem(l.split("\t")[0].strip()))
    return out, ungradable - out, ungraded - out - ungradable


def population_inputs(corpus, key, d):
    """The DB rows and the sidecar name sets ONE suite's population is tallied from, with CONTAINERS.tsv's names removed from all of
    them (CEO-1272). Shared by this audit and util_score_row.py's write-time cross-check, so the two cannot disagree on who counts."""
    side, s_ungradable, s_ungraded = sidecar_stems(corpus, key)
    cont = container_stems(corpus, key)
    if cont:
        # ⛔ IPL's EXCLUDED.tsv names gprogs/spokes.icn; folded to the stem "spokes" it also dropped the graded gprocs/spokes, so
        # util_score_row refused hq_icon's 581/581 as 580 on a6747c757 (coo 2026-09-27). A path-keyed package filters by path.
        if path_keyed(key):
            cp = {_noext(c[5:]) for c in cont}
            d = {p: mm for p, mm in d.items() if _noext(p) not in cp}
        else:
            d = {p: mm for p, mm in d.items() if stem(p) not in cont}
        side, s_ungradable, s_ungraded = side - cont, s_ungradable - cont, s_ungraded - cont
    return d, side, s_ungradable, s_ungraded


def classify(mm, outside_named):
    v = {o for o, _n in mm.values()}
    # the runner's recorded class outranks the sidecar (ceo CEO-799): a sidecar-named entry WITH a DB row keeps the DB's class;
    # the sidecar classes only an entry the DB has no row for (Budne: 49 declared, 22 measured today, 27 UNGRADABLE debt)
    if "OUTSIDE" in v:
        return "OUTSIDE"
    if outside_named and not v:
        return "OUTSIDE"
    if "DEFERRED" in v:
        return "DEFERRED"
    if v == {"PASS"}:
        return "PASS"
    if v == {"UNGRADABLE"}:
        return "UNGRADABLE"
    if v <= UNG:
        return "UNGRADED"
    return "FAIL"


def tally(d, side, s_ungradable, s_ungraded):
    """ONE tally of a suite's DB rows on one tree, shared by this audit and by util_score_row.py's write-time cross-check
    (row instruments-a-suite-row-set-from-a-runners-printed-line-can-drift-from-the-append-behind-it): the PASS count by
    program class, the population with the sidecars folded in, the xpass count, and the note-column facts.
    ⛔ A CRITERION LABEL IN THE DB'S NOTE COLUMN IS THE CONTRACT (hq_prolog 2026-09-17): the INRIA runner records the
    finest per-ENTRY verdict it retains -- outcome class only, noted `outcome-class` on every row -- while the row it
    publishes is the suite's own criterion (outcome class AND bindings), which the bindings comparator keeps only as
    counters.  The DB's PASS count is then an UPPER BOUND on the row's numerator, not its equal; comparing them as
    equals convicts an honest row every tick.  A label is a lower-case hyphenated token that is not `xfail`; hashes
    (the other note shape) never match.  Bounded when every graded row carries the label.  The note column is
    SPACE-SEPARATED TOKENS (xfail, fp=…, rc=…, shard=k/N, a criterion label): read it token-wise."""
    cnt = collections.Counter()
    seen = set()
    xpass = 0
    for p, mm in d.items():
        seen.add(stem(p))
        k = classify(mm, stem(p) in side)
        cnt[k] += 1
        if k == "PASS" and all("xfail" in (n or "").split() for _o, n in mm.values()):
            xpass += 1
    labels = {tok for mm in d.values() for _o, n in mm.values() for tok in (n or "").split() if CRITERION_NOTE_RX.match(tok)}
    bounded = bool(labels) and all(any(tok in labels for tok in (n or "").split()) for mm in d.values() for _o, n in mm.values())
    shards = {tok for mm in d.values() for _o, n in mm.values() for tok in (n or "").split() if tok.startswith("shard=")}
    cnt["OUTSIDE"] += len(side - seen)
    cnt["UNGRADABLE"] += len(s_ungradable - seen)
    cnt["UNGRADED"] += len(s_ungraded - seen)
    return cnt, sum(cnt.values()), xpass, labels, bounded, shards


def audit(suites, db, corpus, out=print):
    rows = read_rows(suites)
    if not rows:
        out("⛔ REFUSES (rc=2): SUITES.tsv carries no rows")
        return 2
    want = {(DBNAME.get(c[0], c[0]), c[10]): c[0] for c in rows if c[10]}
    last = read_db(db, want)
    progs = collections.defaultdict(lambda: collections.defaultdict(dict))
    meas = collections.defaultdict(set)
    lastts = collections.defaultdict(str)
    for (s, t, p, m), (o, note, who, ts) in last.items():
        progs[(s, t)][p][m] = (o, note)
        meas[(s, t)].add(who)
        lastts[(s, t)] = max(lastts[(s, t)], ts)
    graded = agree = 0
    disagree, unproven, deferred = [], [], []
    out(f"{'key':12} {'row':>10} {'DB':>10} {'xpass':>5}  {'measurer':10} {'last DB reading':19}  verdict")
    for c in rows:
        key, nick, P, T, tree, crit = c[0], c[1], c[8], c[9], c[10], c[11]
        tag = f"{key:12} {(P or '-') + '/' + (T or '-'):>10}"
        if not tree and "DEFERRED" in crit.upper():
            deferred.append(key)
            out(f"{tag} {'-':>10} {'-':>5}  {'-':10} {'-':19}  DEFERRED by ruling ({crit[:50]})")
            continue
        if not tree:
            unproven.append(key)
            out(f"{tag} {'-':>10} {'-':>5}  {'-':10} {'-':19}  UNPROVEN: no tree on the row (never measured)")
            continue
        d = progs.get((DBNAME.get(key, key), tree), {})
        d, side, s_ungradable, s_ungraded = population_inputs(corpus, key, d)
        if not d:
            unproven.append(key)
            out(f"{tag} {'-':>10} {'-':>5}  {'-':10} {'-':19}  UNPROVEN: no progress rows for this suite on {tree} (CEO-750)")
            continue
        cnt, pop, xpass, labels, bounded, shards = tally(d, side, s_ungradable, s_ungraded)
        graded += 1
        p_row = int(P) if P.isdigit() else -1
        t_row = int(T) if T.isdigit() else -1
        who = ",".join(sorted(x for x in meas[(DBNAME.get(key, key), tree)] if x))[:10]
        line = f"{tag} {str(cnt['PASS']) + '/' + str(pop):>10} {xpass:>5}  {who:10} {lastts[(DBNAME.get(key, key), tree)][:19]:19}"
        why = []
        if bounded and p_row <= cnt["PASS"]:
            pass   # the DB's criterion is looser than the row's: its count bounds the row from above (verdict printed below)
        elif bounded:
            why.append(f"numerator row {P} EXCEEDS the DB's '{'/'.join(sorted(labels))}' upper bound {cnt['PASS']} ({cnt['PASS'] - p_row:+d})")
        elif p_row != cnt["PASS"]:
            gap = cnt["PASS"] - p_row
            why.append(f"numerator row {P} vs DB {cnt['PASS']} ({gap:+d})" + (" = xpass: STALE MARKERS, promote them (CEO-753)" if gap == xpass and xpass > 0 else ""))
        if t_row != pop:
            why.append(f"denominator row {T} vs DB population {pop} ({t_row - pop:+d}; PASS {cnt['PASS']} FAIL {cnt['FAIL']} OUTSIDE {cnt['OUTSIDE']} UNGRADABLE {cnt['UNGRADABLE']} UNGRADED {cnt['UNGRADED']} DEFERRED {cnt['DEFERRED']})")
        if shards:
            why.append(f"the last reading on this tree is PARTIAL ({', '.join(sorted(shards))}) -- a shard, not a board")
        if why:
            disagree.append(f"{key}: " + "; ".join(why))
            out(f"{line}  DISAGREE: " + "; ".join(why))
        elif bounded:
            agree += 1
            out(f"{line}  AGREE-BOUNDED: the DB carries criterion '{'/'.join(sorted(labels))}' per entry, an upper bound ({cnt['PASS']}) on the row's own criterion ({P}); compared as a bound, never as equals")
        else:
            agree += 1
            out(f"{line}  AGREE")
    out(f"population: {len(rows)} row(s): {graded} graded, {agree} agree, {len(disagree)} disagree, {len(unproven)} unproven ({', '.join(unproven) or 'none'}), {len(deferred)} deferred by ruling ({', '.join(deferred) or 'none'})")
    if graded == 0:
        out("⛔ REFUSES (rc=2): zero rows gradable -- no SUITES.tsv row has progress rows on its own tree; this audit measured nothing.")
        return 2
    if disagree:
        out(f"⛔ DISAGREE [suite_rows_vs_progress]: {len(disagree)} of {graded} graded row(s) do not agree with the progress DB on their own tree -- each is a row for its HQ:")
        for x in disagree:
            out("    " + x)
        return 1
    out(f"✅ AGREE [suite_rows_vs_progress]: {agree}/{graded} graded row(s) agree with the progress DB on their own tree.")
    return 0


def selftest():
    w = tempfile.mkdtemp(prefix="suite_rows_vs_progress.")
    try:
        os.makedirs(os.path.join(w, "corpus", "tests", "snobol4"))
        suites = os.path.join(w, "SUITES.tsv")
        db = os.path.join(w, "results.tsv")
        hdr = "key\tnick\temoji\tlang\tfirst_date\tfirst_pass\tfirst_total\ttoday_date\ttoday_pass\ttoday_total\ttree\tcriterion_changed\n"
        rows = ["sno-rungs\tSnoM\tx\tsnobol4\t2026-09-06\t1\t3\t2026-09-16\t2\t4\tfeedbeef1\tfixture\n",       # 2 PASS 1 FAIL + 1 sidecar OUTSIDE = 2/4 AGREE
                "snc-rungs\tSncM\tx\tsnocone\t2026-09-03\t1\t3\t2026-09-16\t1\t3\tfeedbeef1\tfixture\n",       # DB 2/3, the extra PASS is an xfail-noted one: gap == xpass
                "gimpel\tGimpel\tx\tsnobol4\t2026-09-04\t1\t2\t2026-09-16\t1\t2\tfeedbeef1\tfixture\n",         # DB 1/3 (1 PASS 1 FAIL 1 UNGRADED): denominator planted
                "roast\tRoast\tx\traku\t2026-09-03\t4\t986\t2026-09-13\t6\t986\tdeadbeef2\tfixture\n",           # no rows on its tree: UNPROVEN
                "gnu_fd\tGnuFD\tx\tprolog\t\t\t\t\t\t30\t\tDEFERRED by ruling CEO-579\n",
                "inria\tINRIA\tx\tprolog\t2026-09-05\t1\t3\t2026-09-16\t2\t3\tfeedbeef1\tfixture\n",           # DB 3 PASS all noted outcome-class: an upper bound, row 2 <= 3 AGREE-BOUNDED
                "swi\tSWI\tx\tprolog\t2026-09-05\t1\t3\t2026-09-16\t3\t3\tfeedbeef1\tfixture\n"]              # DB 2 PASS noted outcome-class: row 3 EXCEEDS the bound -> DISAGREE
        open(suites, "w").write("# fixture\n" + hdr + "".join(rows))
        open(os.path.join(w, "corpus", "tests", "snobol4", "ALL.outside.tsv"), "w").write("p_out\tORACLE_REFUSES\tfixture\n")
        def row(tree, suite, prog, mode, out, note=""):
            return f"2026-09-16T00:00:00\t{tree}\tc\tfixture\trungs\t{suite}\tsnobol4\t{prog}\t{mode}\t{out}\t0\t{note}\n"
        lines = ["ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\n"]
        for m in ("m3", "m4"):
            lines += [row("feedbeef1", "snobol4-rungs", "p1", m, "PASS"), row("feedbeef1", "snobol4-rungs", "p2", m, "PASS"), row("feedbeef1", "snobol4-rungs", "p3", m, "FAIL")]
            lines += [row("feedbeef1", "snocone-rungs", "s1", m, "PASS"), row("feedbeef1", "snocone-rungs", "s2", m, "PASS", "xfail"), row("feedbeef1", "snocone-rungs", "s3", m, "FAIL")]
            lines += [row("feedbeef1", "gimpel", "g1", m, "PASS"), row("feedbeef1", "gimpel", "g2", m, "CRASH"), row("feedbeef1", "gimpel", "g3", m, "UNGRADED")]
            lines += [row("feedbeef1", "inria", "i%d" % k, m, "PASS", "outcome-class") for k in (1, 2, 3)]
            lines += [row("feedbeef1", "swi", "w1", m, "PASS", "outcome-class"), row("feedbeef1", "swi", "w2", m, "PASS", "outcome-class"), row("feedbeef1", "swi", "w3", m, "FAIL", "outcome-class")]
        lines += [row("feedbeef1", "snobol4-rungs", "p2", "m3", "FAIL"), row("feedbeef1", "snobol4-rungs", "p2", "m3", "PASS")]   # last row wins
        open(db, "w").write("".join(lines))
        fails = 0
        def ck(ok, label):
            nonlocal fails
            print(("  ok    " if ok else "  FAIL  ") + label)
            if not ok:
                fails += 1
        buf = []
        rc = audit(suites, db, os.path.join(w, "corpus"), out=buf.append)
        txt = "\n".join(buf)
        ck(rc == 1 and "sno-rungs" in txt and re.search(r"sno-rungs .*AGREE", txt) and re.search(r"snc-rungs .*DISAGREE: numerator row 1 vs DB 2 \(\+1\) = xpass: STALE MARKERS", txt) and
           re.search(r"gimpel .*DISAGREE: denominator row 2 vs DB population 3", txt) and re.search(r"roast .*UNPROVEN", txt) and re.search(r"gnu_fd .*DEFERRED", txt),
           "(a) rc=1: the agreeing row AGREEs, the planted numerator gap is named and equals its xpass (stale markers), the planted denominator gap is named by class, UNPROVEN and DEFERRED named")
        ck(bool(re.search(r"inria .*AGREE-BOUNDED: the DB carries criterion 'outcome-class' per entry, an upper bound \(3\) on the row's own criterion \(2\)", txt))
           and bool(re.search(r"swi .*DISAGREE: numerator row 3 EXCEEDS the DB's 'outcome-class' upper bound 2", txt)) and "inria" not in " ".join(l for l in buf if "DISAGREE [" in l),
           "(a2) a DB whose every row carries a criterion label bounds the row from above: row <= bound reads AGREE-BOUNDED with the label, row > bound DISAGREEs as EXCEEDS (hq_prolog 2026-09-17)")
        open(suites, "w").write("# fixture\n" + hdr + rows[0] + rows[3] + rows[4])
        buf = []
        rc = audit(suites, db, os.path.join(w, "corpus"), out=buf.append)
        ck(rc == 0 and "1 agree" in "\n".join(buf), "(b) rc=0 once the planted rows are removed (the agreeing, UNPROVEN and DEFERRED rows remain)")
        open(db, "w").write(lines[0])
        buf = []
        rc = audit(suites, db, os.path.join(w, "corpus"), out=buf.append)
        ck(rc == 2, "(c) rc=2 REFUSES on an empty DB (zero rows gradable)")
        # (d) THE THREE POPULATION RULES OF 2026-09-25 (coo): a driver-named sidecar row and its library-named DB row are ONE program
        # (CEO-1269); a CONTAINERS.tsv name is no program even with a stale DB row on the tree (CEO-1272); and a package with no outside
        # file folds its sidecars BY PATH, so two files sharing a basename count twice (IPL). Each row reads AGREE only with all three.
        dn = os.path.join(w, "corpus", "packages", "snobol4", "dotnet"); os.makedirs(dn)
        open(os.path.join(dn, "OUTSIDE_SPITBOL_BASELINE.tsv"), "w").write("X_driver.sno\tORACLE_REFUSES\tfixture\nq_lib_driver.sno\tORACLE_REFUSES\tthe library of a twice-shipped stem (fixture)\n")
        open(os.path.join(dn, "UNGRADABLE.tsv"), "w").write("X_driver.sno\tORACLE_REFUSES\tfixture\nY.INC\tORACLE_REFUSES\tan include library, keyed Y.sno in the DB (fixture)\n")
        open(os.path.join(dn, "CONTAINERS.tsv"), "w").write("chap.sno\tMULTI_PROGRAM\t2 top-level END statements (fixture)\n")
        ip = os.path.join(w, "corpus", "packages", "icon", "ipl"); os.makedirs(ip)
        open(os.path.join(ip, "UNGRADED.tsv"), "w").write("procs/dup.icn\tNEEDS_DRIVER\tfixture\ngprocs/dup.icn\tNEEDS_DRIVER\tfixture\n")
        open(os.path.join(ip, "EXCLUDED.tsv"), "w").write("gprogs/a1.icn\tNEEDS_GRAPHICS_FACILITY\tthe namesake of the graded gprocs/a1 (fixture)\n")
        open(suites, "w").write("# fixture\n" + hdr + "dotnet\tDotnet\tx\tsnobol4\t2026-09-25\t2\t5\t2026-09-25\t2\t5\tfeedbeef1\tfixture\n"
                                + "ipl\tIPL\tx\ticon\t2026-09-25\t1\t3\t2026-09-25\t1\t3\tfeedbeef1\tfixture\n")
        dl = [lines[0]]
        for m in ("m3", "m4"):
            dl += [row("feedbeef1", "dotnet", "d1", m, "PASS"), row("feedbeef1", "dotnet", "X", m, "UNGRADED"), row("feedbeef1", "dotnet", "chap", m, "UNGRADED"), row("feedbeef1", "dotnet", "Y", m, "UNGRADED"), row("feedbeef1", "dotnet", "q.spt", m, "PASS"), row("feedbeef1", "dotnet", "q.inc", m, "UNGRADED"),
                   row("feedbeef1", "ipl", "gprocs/a1", m, "PASS")]
        open(db, "w").write("".join(dl))
        buf = []
        rc = audit(suites, db, os.path.join(w, "corpus"), out=buf.append)
        txt = "\n".join(buf)
        ck(rc == 0 and re.search(r"dotnet .*AGREE", txt) and re.search(r"ipl .*AGREE", txt),
           "(d) a driver-named sidecar row is its library's DB row, a NAME.INC sidecar row is its NAME.sno DB row, q_lib_driver's OUTSIDE row is the library q.inc beside the program q.spt, a container's stale DB row is no program, IPL's two same-basename sidecar files count twice and its EXCLUDED gprogs/a1 leaves the graded gprocs/a1 in -- both rows AGREE" + ("" if rc == 0 else " :: " + " | ".join(l for l in buf if "DISAGREE" in l)[:300]))
        print(f"population: 4 selftest arm(s), {fails} FAIL")
        print("SELFTEST " + ("PASS" if fails == 0 else "FAIL"))
        return 0 if fails == 0 else 1
    finally:
        shutil.rmtree(w, ignore_errors=True)


def main(argv):
    if "--selftest" in argv:
        return selftest()
    if any(a.startswith("-") for a in argv):
        sys.stderr.write("usage: util_suite_rows_vs_progress.py [--selftest]   (env: S4E_SUITES_TSV S4E_PROGRESS_DB S4E_CORPUS_ROOT)\n")
        return 2
    _root = os.path.abspath(os.path.join(HERE, "..", "..", "SCRIP", ".."))
    suites = os.environ.get("S4E_SUITES_TSV") or ("/home/resources/progress/SUITES.tsv" if re.fullmatch(r"/home/claude_[A-Za-z0-9_]+", os.path.realpath(_root)) else os.path.join(_root, ".github", "SUITES.tsv"))
    db = os.environ.get("S4E_PROGRESS_DB") or "/home/resources/progress/results.tsv"
    corpus = os.environ.get("S4E_CORPUS_ROOT") or os.path.join(HERE, "..", "..", "SCRIP", "..", "corpus")
    for f, what in ((suites, "SUITES.tsv"), (db, "the progress DB")):
        if not os.path.exists(f):
            print(f"⛔ REFUSES (rc=2): cannot read {what} at {f}")
            return 2
    return audit(suites, db, corpus)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
