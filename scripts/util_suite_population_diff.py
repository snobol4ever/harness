#!/usr/bin/env python3
"""util_suite_population_diff.py -- A SKIP THAT MOVES IS A RED, IN EITHER DIRECTION (coo, CEO-824, 2026-09-17;
row instruments-a-skip-count-change-between-batches-is-a-red-not-a-silent-population-change; the cfo's escalation).

THE DEFECT THIS EXISTS FOR, MEASURED.  A suite entry that SKIPs leaves the GRADED population with no red anywhere:
the pass count falls and nothing points at why.  The SNOBOL4 rungs read m4_pass=1970 m4_skip=0 at SCRIP ad0f85fae
and m4_pass=1967 m4_skip=3 at b12714737 -- and that landing's own commit said "equal to base program for program"
while its board wrote SCORE's SnoRungs row on that tree.  The three were cured at 0567ad829 and read skip=0 again at
a861648ab.  BOTH the appearance and the disappearance passed unremarked, because every reader compared PASS.

A SKIP IS NOT A RED AND NOT A PASS; IT IS THE DENOMINATOR MOVING.  Three programs that stop being graded lower the
pass count exactly like three regressions, and raise it again exactly like three cures, and no verdict in the ladder
fires either way.  So this instrument compares the two things nobody compares: THE SKIP COUNTS and THE GRADED
DENOMINATOR.  It is a comparison and a verdict, never a new measurement -- corpus_suite_harness.py already prints
m3_skip/m4_skip on its SUITE_BOARD line, and this reads what the runner printed.

  rc=0  GREEN -- every skip count and every denominator field identical between the two readings.
  rc=1  RED   -- a skip count or a denominator moved, in EITHER direction, with the fields named and, where the
                 readings carry per-entry lines, THE ENTRIES NAMED on both sides.
  rc=2  REFUSED -- a file missing, no SUITE_BOARD line in it, or the two lines are not two readings of ONE suite
                 (different family, or a shard against a full board).  Comparing two different populations is not a
                 comparison, and printing a number for it would be worse than printing nothing.

WHY IT WILL NOT NAME THE ENTRIES FROM A BOARD LINE ALONE, AND SAYS SO.  The SUITE_BOARD line carries counts, not
names.  The harness prints its non-PASS entries on stderr (SUITE_LIST_ALL=1 for all of them), so when the reading
handed here is the runner's FULL output the skip entries are named on both sides and the appearing/disappearing sets
are printed.  When it is the board line alone the instrument says the entries are NOT NAMED and why, rather than
implying a set it never saw.

  util_suite_population_diff.py BEFORE AFTER      two files, each a SUITE_BOARD line or a full runner output
  util_suite_population_diff.py --archive .github/board-lines/DATE-WHO.tsv --suite sno-rungs --from TREE --to TREE
                                                  two VERBATIM archived lines (ceo CEO-827), the runner's own output
  util_suite_population_diff.py --selftest        planted arms, plus the real archived pair when it is on disk
"""
import os
import re
import sys

BOARD_RX = re.compile(r"^SUITE_BOARD\s+(.*)$", re.M)
KV_RX = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)=(\S+)")
# the harness's non-PASS entry line: "  SKIP m4 name: detail [fp=... rc=...]"
ENTRY_RX = re.compile(r"^\s{2}([A-Z]+)(?:\([^)]*\))?\s+(m3|m4)\s+(\S+?):", re.M)

# THE TWO COLUMN FAMILIES THIS INSTRUMENT IS ABOUT.  Everything else on the board line (pass, fail, crash, hang) is
# printed as INFORMATION and never decides the verdict: a pass count that moves with the population fixed is the
# board doing its job, and this row is about the population moving underneath it.
SKIP_FIELDS = ("m3_skip", "m4_skip", "ast_skip", "m3_xfail_skip", "m4_xfail_skip", "ast_xfail_skip")
DENOM_FIELDS = ("m3_n", "m4_n", "all_n", "total", "shipped", "outside")
INFO_FIELDS = ("m3_pass", "m4_pass", "all_pass", "m3_fail", "m4_fail", "m3_crash", "m4_crash", "m3_hang", "m4_hang",
               "m3_unproven", "m4_unproven")
IDENTITY_FIELDS = ("family", "shard")


def read_board(path, out):
    """the SUITE_BOARD fields and the per-mode SKIP entry names of one reading; None (with a printed reason) if it
    cannot be read -- an unreadable reading is rc=2, never an empty one"""
    if not os.path.exists(path):
        out(f"REFUSED(2): {path} does not exist -- nothing was read, and that is not a zero")
        return None
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError as e:
        out(f"REFUSED(2): {path}: {e}")
        return None
    boards = BOARD_RX.findall(text)
    if not boards:
        out(f"REFUSED(2): {path} carries no SUITE_BOARD line -- this instrument compares what a runner printed, and "
            "there is nothing here to compare")
        return None
    if len(boards) > 1:
        out(f"REFUSED(2): {path} carries {len(boards)} SUITE_BOARD lines -- which reading is the one? Split them, or "
            "pass the single board this comparison is about")
        return None
    fields = {k: v for k, v in KV_RX.findall(boards[0])}
    skips = {"m3": set(), "m4": set()}
    for kind, mode, name in ENTRY_RX.findall(text):
        if kind == "SKIP":
            skips[mode].add(name)
    return {"path": path, "fields": fields, "skips": skips, "has_entries": bool(ENTRY_RX.search(text))}


def read_archive(path, suite, tree, out):
    """one reading out of a board-lines TSV (tree<TAB>suite<TAB>measurer<TAB>verbatim line; ceo CEO-827).

    THIS IS WHY THE ARCHIVE EXISTS.  The pair this instrument was built for -- the SNOBOL4 rungs' m4_skip 0 -> 3 at
    b12714737 and 3 -> 0 at a861648ab -- could not be diffed at all on the morning it was ruled, because every receipt
    in .github paraphrased its board in prose.  A reading reconstructed by hand is faithful at best; it is not the
    runner's own line, and this instrument will not let one wear the other's authority."""
    if not os.path.exists(path):
        out(f"REFUSED(2): no archive at {path} -- nothing was read, and that is not a zero")
        return None
    rows = []
    for ln in open(path, encoding="utf-8", errors="replace"):
        if ln.startswith("#") or not ln.strip():
            continue
        parts = ln.rstrip("\n").split("\t")
        if len(parts) < 4:
            continue
        rows.append(parts[:4])
    hit = [r for r in rows if r[0].startswith(tree) and r[1] == suite]
    if not hit:
        have = sorted({(r[1]) for r in rows})
        trees = sorted({r[0] for r in rows if r[1] == suite})
        out(f"REFUSED(2): {path} holds no verbatim line for suite {suite!r} at tree {tree!r}. "
            + (f"That suite is archived at: {', '.join(trees)}." if trees else f"Suites archived here: {', '.join(have) or 'none'}.")
            + " A comparison cannot be made from a reading nobody kept")
        return None
    lines = {r[3] for r in hit}
    if len(lines) > 1:
        out(f"REFUSED(2): {path} holds {len(lines)} DIFFERENT lines for {suite} at {tree} -- two readings of one tree "
            "disagree, which is a finding of its own, not an input to this one")
        return None
    text = hit[0][3]
    fields = {k: v for k, v in KV_RX.findall(text.split("SUITE_BOARD", 1)[-1])} if "SUITE_BOARD" in text else {}
    if not fields:
        out(f"REFUSED(2): the archived line for {suite} at {tree} carries no SUITE_BOARD fields: {text[:80]!r}")
        return None
    return {"path": f"{os.path.basename(path)}[{suite}@{hit[0][0]} by {hit[0][2]}]", "fields": fields,
            "skips": {"m3": set(), "m4": set()}, "has_entries": False}


def diff(a, b, out=print):
    """rc 0/1/2 over two readings; every moved field named with both values, every nameable entry named"""
    if a is None or b is None:
        return 2
    fa, fb = a["fields"], b["fields"]
    for k in IDENTITY_FIELDS:
        if fa.get(k) != fb.get(k):
            out(f"REFUSED(2): these are not two readings of ONE suite -- {k}={fa.get(k, '<absent>')} in {a['path']} "
                f"and {k}={fb.get(k, '<absent>')} in {b['path']}. A comparison across populations is not a comparison")
            return 2
    moved_skip = [(k, fa.get(k), fb.get(k)) for k in SKIP_FIELDS if k in fa or k in fb if fa.get(k) != fb.get(k)]
    moved_den = [(k, fa.get(k), fb.get(k)) for k in DENOM_FIELDS if k in fa or k in fb if fa.get(k) != fb.get(k)]
    moved_info = [(k, fa.get(k), fb.get(k)) for k in INFO_FIELDS if k in fa or k in fb if fa.get(k) != fb.get(k)]
    for k, x, y in moved_skip:
        out(f"⛔ SKIP MOVED {k}: {x} -> {y}  (a skip is the DENOMINATOR moving, not a red and not a pass: entries that "
            "stop being graded lower the pass count exactly like regressions, and raise it exactly like cures)")
    for k, x, y in moved_den:
        out(f"⛔ DENOMINATOR MOVED {k}: {x} -> {y}  (the two pass counts are over different populations; comparing them "
            "is a criterion change and belongs in SUITES.tsv's criterion_changed column, never in silence)")
    for k, x, y in moved_info:
        out(f"   information (does not decide this verdict) {k}: {x} -> {y}")
    if moved_skip:
        if a["has_entries"] or b["has_entries"]:
            for mode in ("m3", "m4"):
                appeared = sorted(b["skips"][mode] - a["skips"][mode])
                gone = sorted(a["skips"][mode] - b["skips"][mode])
                if appeared:
                    out(f"   {mode} SKIP APPEARED ({len(appeared)}): " + ", ".join(appeared[:20])
                        + (f" ... +{len(appeared) - 20} more" if len(appeared) > 20 else ""))
                if gone:
                    out(f"   {mode} SKIP DISAPPEARED ({len(gone)}): " + ", ".join(gone[:20])
                        + (f" ... +{len(gone) - 20} more" if len(gone) > 20 else ""))
                if not appeared and not gone and (fa.get(mode + "_skip") != fb.get(mode + "_skip")):
                    out(f"   {mode} SKIP entries NOT NAMED: the count moved but the entry lines name no {mode} skip on "
                        "either side -- run the runner with SUITE_LIST_ALL=1 so the 40-line sample cannot hide them")
        else:
            out("   ENTRIES NOT NAMED: neither reading carries the runner's per-entry lines, only its board line. "
                "Re-run with SUITE_LIST_ALL=1 and keep the runner's stderr, or pass its full output here; this "
                "instrument will not imply a set it never saw")
    n_moved = len(moved_skip) + len(moved_den)
    pop = (f"population: {len(SKIP_FIELDS)} skip field(s) and {len(DENOM_FIELDS)} denominator field(s) compared over "
           f"family={fa.get('family', '<unnamed>')}"
           + (f" shard={fa['shard']}" if fa.get("shard") else "")
           + f"; {n_moved} moved, {len(moved_info)} informational field(s) moved")
    out(pop)
    if n_moved:
        out(f"⛔ POPULATION-DIFF RED: {a['path']} -> {b['path']}: {len(moved_skip)} skip and {len(moved_den)} "
            "denominator field(s) moved between two readings of one suite. Name the entries and row them, or record "
            "the criterion change -- do not compare the pass counts across this.")
        return 1
    out(f"POPULATION-DIFF GREEN: {a['path']} -> {b['path']}: every skip count and every denominator field identical; "
        "the pass counts above are comparable.")
    return 0


def selftest():
    """planted arms, the recorded SNOBOL4 pair included -- an instrument that reds on everything measures nothing"""
    import tempfile
    fails = 0
    arms = 0

    def ck(ok, label):
        nonlocal fails, arms
        arms += 1
        print(("  ok    " if ok else "  FAIL  ") + label)
        if not ok:
            fails += 1

    w = tempfile.mkdtemp(prefix="suite_pop_diff."); __import__("atexit").register(__import__("shutil").rmtree, w, True)

    def put(name, text):
        p = os.path.join(w, name)
        open(p, "w", encoding="utf-8").write(text)
        return p

    base = ("SUITE_BOARD family=ALL total=1982 shipped=1982 outside=8 m3_n=1974 m3_pass=1970 m3_fail=3 m3_skip=0 "
            "m4_n=1974 m4_pass=1970 m4_fail=3 m4_skip=0 all_pass=1970 all_n=1982\n")
    skipped = base.replace("m4_pass=1970 m4_fail=3 m4_skip=0", "m4_pass=1967 m4_fail=3 m4_skip=3").replace(
        "all_pass=1970", "all_pass=1967")
    a, b = put("a", base), put("b", skipped)
    buf = []
    ck(diff(read_board(a, buf.append), read_board(b, buf.append), buf.append) == 1 and any("SKIP MOVED m4_skip: 0 -> 3" in l for l in buf),
       "the recorded ad0f85fae -> b12714737 pair (m4_skip 0 -> 3, pass 1970 -> 1967) is RED and names the field")
    buf.clear()
    ck(diff(read_board(b, buf.append), read_board(a, buf.append), buf.append) == 1 and any("SKIP MOVED m4_skip: 3 -> 0" in l for l in buf),
       "the DISAPPEARANCE (3 -> 0, the 0567ad829 cure) is equally RED -- a skip that vanishes is as much a population change as one that appears")
    buf.clear()
    ck(diff(read_board(a, buf.append), read_board(a, buf.append), buf.append) == 0,
       "two identical readings are GREEN -- an instrument that reds on everything measures nothing")
    buf.clear()
    moved_pass = base.replace("m4_pass=1970 m4_fail=3", "m4_pass=1967 m4_fail=6").replace("all_pass=1970", "all_pass=1967")
    c = put("c", moved_pass)
    r = diff(read_board(a, buf.append), read_board(c, buf.append), buf.append)
    ck(r == 0 and any("information (does not decide this verdict) m4_pass" in l for l in buf),
       "three PASSes turning into three FAILs with the population fixed is GREEN here and printed as information -- that is the board's red, not this instrument's")
    buf.clear()
    d = put("d", base.replace("m4_n=1974", "m4_n=1971"))
    ck(diff(read_board(a, buf.append), read_board(d, buf.append), buf.append) == 1 and any("DENOMINATOR MOVED m4_n: 1974 -> 1971" in l for l in buf),
       "a graded denominator that moves with every skip count equal is RED too -- the pass counts are over different populations")
    buf.clear()
    e = put("e", base.replace("family=ALL", "family=OTHER"))
    ck(diff(read_board(a, buf.append), read_board(e, buf.append), buf.append) == 2,
       "two different families REFUSE rc=2 -- comparing two populations is not a comparison")
    buf.clear()
    f = put("f", base.rstrip("\n") + " shard=1/4\n")
    ck(diff(read_board(a, buf.append), read_board(f, buf.append), buf.append) == 2,
       "a shard reading against a full board REFUSES rc=2")
    buf.clear()
    ck(read_board(os.path.join(w, "nope"), buf.append) is None and any("does not exist" in l for l in buf),
       "a missing file REFUSES rc=2 and says so, never an empty reading")
    buf.clear()
    g = put("g", "the runner crashed before it printed a board\n")
    ck(read_board(g, buf.append) is None and any("no SUITE_BOARD line" in l for l in buf),
       "a file with no SUITE_BOARD line REFUSES rc=2 -- there is nothing here to compare")
    buf.clear()
    h = put("h", base + base)
    ck(read_board(h, buf.append) is None and any("2 SUITE_BOARD lines" in l for l in buf),
       "two board lines in one file REFUSE rc=2 -- which reading is the one?")
    buf.clear()
    full_a = base + "  FAIL m4 some_entry: bytes differ [fp=deadbeef rc=0]\n"
    full_b = (skipped + "  SKIP m4 eval_2: scrip --compile failed [fp=00000000 rc=1]\n"
              "  SKIP m4 eval_convert_branch_1: scrip --compile failed [fp=00000000 rc=1]\n"
              "  SKIP m4 simple_output_64: scrip --compile failed [fp=00000000 rc=1]\n")
    i, j = put("i", full_a), put("j", full_b)
    buf.clear()
    r = diff(read_board(i, buf.append), read_board(j, buf.append), buf.append)
    ck(r == 1 and any("m4 SKIP APPEARED (3): eval_2, eval_convert_branch_1, simple_output_64" in l for l in buf),
       "with the runner's per-entry lines in hand the three appearing entries are NAMED, which is the whole point of the row")
    buf.clear()
    r = diff(read_board(j, buf.append), read_board(i, buf.append), buf.append)
    ck(r == 1 and any("m4 SKIP DISAPPEARED (3):" in l for l in buf),
       "and the same three are named when they go away")
    buf.clear()
    r = diff(read_board(a, buf.append), read_board(b, buf.append), buf.append)
    ck(r == 1 and any("ENTRIES NOT NAMED" in l for l in buf),
       "board lines alone: the instrument says the entries are NOT NAMED and why, rather than implying a set it never saw")
    # THE ARCHIVE READER (ceo CEO-827): a verbatim line kept by a receipt, and every way it can refuse.
    arc = put("arc.tsv",
              "# header\n"
              "b12714737\tsnobol4-rungs\tceo\t" + skipped.strip() + "\n"
              "a861648ab\tsnobol4-rungs\tceo\t" + base.strip() + "\n"
              "b12714737\ticon-rungs\tceo\tSUITE_BOARD family=ALL total=826 m3_n=826 m4_n=826 m4_skip=0\n")
    buf.clear()
    ck(diff(read_archive(arc, "snobol4-rungs", "b12714737", buf.append),
            read_archive(arc, "snobol4-rungs", "a861648ab", buf.append), buf.append) == 1
       and any("SKIP MOVED m4_skip: 3 -> 0" in l for l in buf),
       "the ARCHIVED pair (the runner's own lines, CEO-827) reds on m4_skip 3 -> 0 -- a reading, not a reconstruction")
    buf.clear()
    ck(read_archive(arc, "raku-rungs", "b12714737", buf.append) is None
       and any("holds no verbatim line for suite" in l and "Suites archived here" in l for l in buf),
       "an archive with no line for that suite REFUSES rc=2 and NAMES what it does hold")
    buf.clear()
    ck(read_archive(arc, "snobol4-rungs", "deadbeef", buf.append) is None
       and any("That suite is archived at: a861648ab, b12714737." in l for l in buf),
       "a tree the archive never recorded REFUSES rc=2 and names the trees it has for that suite")
    buf.clear()
    dupe = put("dupe.tsv", "b12714737\tsnobol4-rungs\tceo\t" + skipped.strip() + "\n"
                           "b12714737\tsnobol4-rungs\thq_snobol4\t" + base.strip() + "\n")
    ck(read_archive(dupe, "snobol4-rungs", "b12714737", buf.append) is None
       and any("DIFFERENT lines" in l for l in buf),
       "two DIFFERENT archived lines for one tree and suite REFUSE rc=2 -- two readings of one tree disagreeing is its own finding, not an input to this one")
    buf.clear()
    ck(read_archive(os.path.join(w, "no-archive.tsv"), "snobol4-rungs", "b12714737", buf.append) is None
       and any("no archive at" in l for l in buf),
       "a missing archive REFUSES rc=2, never an empty reading")
    print(f"population: {arms} selftest arm(s), {fails} FAIL")
    print("SELFTEST " + ("PASS" if fails == 0 else "FAIL"))
    return 0 if fails == 0 else 1


def main(argv):
    if "--selftest" in argv:
        return selftest()
    if "--archive" in argv:
        # util_suite_population_diff.py --archive F --suite KEY --from TREE --to TREE
        opt = {}
        it = iter(range(len(argv)))
        for i in it:
            if argv[i].startswith("--") and i + 1 < len(argv):
                opt[argv[i][2:]] = argv[i + 1]
        missing = [k for k in ("archive", "suite", "from", "to") if k not in opt]
        if missing:
            print(__doc__)
            print(f"REFUSED(2): --archive needs {' '.join('--' + m for m in missing)}")
            return 2
        a = read_archive(opt["archive"], opt["suite"], opt["from"], print)
        b = read_archive(opt["archive"], opt["suite"], opt["to"], print)
        return diff(a, b, print)
    if len(argv) != 2:
        print(__doc__)
        print("REFUSED(2): give exactly two readings (BEFORE AFTER), or --archive/--suite/--from/--to, or --selftest")
        return 2
    a = read_board(argv[0], print)
    b = read_board(argv[1], print)
    return diff(a, b, print)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
