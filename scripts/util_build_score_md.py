#!/usr/bin/env python3
# util_build_score_md.py -- computed generator for the SCORE.md "STANDARDIZED DISPLAY" grid (row
# score-md-master-driven-display, ceo's all-hands-consolidation assignment to seat08, 2026-08-30).
#
# WHY THIS EXISTS: SCORE.md is Lon's "central location for the current score" -- but its own text
# already names its worst defect: 15 of 17 rows carried an unpinned "s283h tree" label that names no
# commit anyone can check out (RULES.md STALE-ORIENTATION / HANDOFF-COMPLETE-NEEDS-A-PUSH, applied to
# a scoreboard). A hand-typed grid re-introduces that defect every time someone edits it by hand.
#
# WHAT THIS DOES, AND DOES NOT, DO. It does NOT reimplement any language's grading logic -- that would
# be a second, drifting copy of logic that already exists and is owned per-language (the exact class
# RULES.md's FACT RULES spend a whole chapter warning about). It (1) reads each language's
# corpus/tests/<lang>/ALL.csv rungs for entry/xfail counts -- genuinely rungs-driven, no duplicated
# logic, RUNGS PENDING (never a fabricated number) where no rungs exists yet; (2) invokes each
# language's own existing, authoritative floor/smoke gate script and parses its OWN printed verdict
# line with a NAMED per-language pattern -- a pattern miss is UNPROVEN, never a guess; (3) stamps every
# run with real, checkable per-repo commit hashes (+DIRTY), same discipline as lib_gate.sh's gate_stamp,
# so a reader can `git checkout` exactly what produced a given grid; (4) runs each language's RUNGS BOARD -- the harness's own
# `run` on corpus/tests/<lang>/ALL.<ext> + ALL.ref, both modes -- and parses its one SUITE_BOARD line, so all seven languages carry
# the SAME instrument in the same column (ceo 2026-09-01 -> hq_B; Lon's #1-priority Prolog number is that column's crash count).
import csv, os, re, subprocess, sys, time

S4E = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SCRIP_ROOT = os.path.join(S4E, "SCRIP")
CORPUS_ROOT = os.path.join(S4E, "corpus")
GITHUB_ROOT = os.path.join(S4E, ".github")
GATE_TIMEOUT = int(os.environ.get("SCORE_GATE_TIMEOUT", "570"))

LANGS = ["snobol4", "icon", "prolog", "raku", "pascal", "snocone", "rebus"]

# ONE AUTHORITY per language for how to invoke its floor/smoke gate and how to read its verdict line.
# Each entry's script is unmodified and unowned by this file -- this table only reads what it already
# prints. A script's output format changing breaks its `pattern` match LOUDLY (UNPROVEN), never silently.
_SNOBOL4_RUNGS_RE = re.compile(r"rungs: total=(\d+) . m3 xfail=(\d+) xpass=(\d+) . m4 xfail=(\d+) xpass=(\d+)")


def _fmt_snobol4(m, out):
    base = "m3 %s/%s · m4 %s/%s SKIP=%s" % (m.group(2), m.group(3), m.group(4), m.group(5), m.group(6))
    mm = _SNOBOL4_RUNGS_RE.search(out)
    if not mm:
        return base + " (rungs xfail/xpass line not found -- reported PER MODE would be needed here, never summed: see hq_C's simple_output_63 caution, an m4 SKIP is not an m4 XPASS)"
    return base + (" · rungs total=%s xfail/xpass m3=%s/%s m4=%s/%s (PER MODE, never summed -- an XPASS in one mode "
                   "can be a SKIP in the other, e.g. simple_output_63)" % (mm.group(1), mm.group(2), mm.group(3), mm.group(4), mm.group(5)))


# ONE AUTHORITY per language for how to invoke its floor/smoke gate and how to read its verdict line.
# Each entry's script is unmodified and unowned by this file -- this table only reads what it already
# prints. A script's output format changing breaks its `pattern` match LOUDLY (UNPROVEN), never silently.
# `format(m, out)` takes the matched pattern AND the gate's full raw output, so a format function can pull
# a SECOND line out of the same run when useful (snobol4's xfail/xpass) without a second gate invocation.
GATES = {
    "snobol4": {"script": "test_corpus_snobol4.sh", "args": [],
        "pattern": re.compile(r"GATE (OK|FAIL): m3 PASS=(\d+) FAIL=(\d+).*?m4 PASS=(\d+) FAIL=(\d+) SKIP=(\d+)", re.S),
        "format": _fmt_snobol4},
    "icon": {"script": "test_icon_rung_suite.sh", "args": ["--mode", "interp"],
        "pattern": re.compile(r"--- Icon \(interp\): PASS=(\d+) FAIL=(\d+)(?: BADEXIT=(\d+))? XFAIL=(\d+)(?: REFUSED=(\d+))?(?: MISSING=(\d+))? TOTAL=(\d+)"),
        "format": lambda m, out: "interp PASS=%s FAIL=%s XFAIL=%s TOTAL=%s" % (m.group(1), m.group(2), m.group(4), m.group(7))},
    "prolog": {"script": "test_smoke_prolog.sh", "args": [],
        "pattern": re.compile(r"mode-2 \(--run\):\s+PASS=(\d+) FAIL=(\d+)\s*/\s*(\d+)"),
        "format": lambda m, out: "m2 PASS=%s FAIL=%s / %s (HARD GATE)" % (m.group(1), m.group(2), m.group(3))},
    "raku": {"script": "test_smoke_raku.sh", "args": [],
        "pattern": re.compile(r"mode-3 \(--run\):\s+PASS=(\d+) FAIL=(\d+) REFUSED=(\d+)\s*/\s*(\d+)"),
        "format": lambda m, out: "m3 PASS=%s FAIL=%s REFUSED=%s / %s" % (m.group(1), m.group(2), m.group(3), m.group(4))},
    "pascal": {"script": "test_gate_pascal_m3.sh", "args": [],
        "pattern": re.compile(r"M3: PASS=(\d+) FAIL=(\d+) NOREF=(\d+) XFAIL=(\d+)"),
        "format": lambda m, out: "m3 PASS=%s FAIL=%s NOREF=%s XFAIL=%s" % (m.group(1), m.group(2), m.group(3), m.group(4))},
    "snocone": {"script": "test_smoke_snocone.sh", "args": [],
        "pattern": re.compile(r"PASS=(\d+) FAIL=(\d+)"),
        "format": lambda m, out: "PASS=%s FAIL=%s" % (m.group(1), m.group(2))},
    "rebus": {"script": "test_smoke_rebus.sh", "args": [],
        "pattern": re.compile(r"PASS=(\d+) FAIL=(\d+)"),
        "format": lambda m, out: "PASS=%s FAIL=%s" % (m.group(1), m.group(2))},
}


# ⭐ THE RUNGS BOARD, ONE INSTRUMENT FOR ALL SEVEN (ceo 2026-09-01 -> hq_B: "the display should carry the same instrument for
# all seven -- a smoke on one row and a rung suite board on another is two axes in one grid"). The instrument is the harness's own
# `run` on the language's ALL.<ext> + ALL.ref rungs, both modes -- exactly what test_corpus_snobol4.sh wraps for SNOBOL4 and what
# ceo quoted for Prolog (total=371 · m3 pass=218 fail=5 crash=139 · m4 pass=218 fail=5 crash=7 skip=132 at 8eac17da). This file
# still grades nothing itself: it invokes the harness unmodified and parses its ONE printed SUITE_BOARD line; a pattern miss is
# UNPROVEN, never a guess. Counts are reported PER MODE and never summed (an XPASS in one mode can be a SKIP in the other).
# ⛔ The smoke/floor column stays: the two columns answer different questions (floor = must-never-regress bar, rungs = the whole
# suite's state), and Lon's #1-priority number for Prolog is the rungs' crash count, which no smoke carries.
RUNGS_TIMEOUT = int(os.environ.get("SCORE_RUNGS_TIMEOUT", "900"))
RUNG_SUITES = {  # lang -> (extension of the rungs program file, --lang value for the harness; "" = snobol4, the harness default)
    "snobol4": (".sno", ""), "icon": (".icn", "icon"), "prolog": (".pl", "prolog"), "raku": (".raku", "raku"),
    "pascal": (".pas", "pascal"), "snocone": (".sc", "snocone"), "rebus": (".reb", "rebus"),
}
# ⛔ BOTH OF THESE READ THE BOARD BY POSITION AND BOTH WERE ONE INSERTION FROM SILENCE (coo, CEO-839).
# `family=\S+ total=` required total to FOLLOW family, and the mode regex required EIGHT fields in exactly that
# order with nothing between any two of them.  The same shape, in test_gate_harness_refusal_is_rc2.sh arm 9, went
# red against a CORRECT board the day shipped=/outside= landed between total= and m3_n= (CEO-749/772) and stayed
# red for a day -- and here a miss is worse than red: it returns UNPROVEN, so SCORE.md would have quietly said
# "no SUITE_BOARD line from the harness" about a harness that printed one.  Fields are read BY NAME now.
_SUITE_BOARD_LINE_RE = re.compile(r"^SUITE_BOARD .*$", re.M)
_FIELD_RE = re.compile(r"(?:^|\s)([A-Za-z_][A-Za-z0-9_]*)=(\S+)")
_MODE_FIELDS = ("pass", "fail", "crash", "hang", "unproven", "skip", "xfail", "xpass")


def board_fields(line):
    """every NAME=VALUE on a board line, read by identity -- order and adjacency are not part of the reading"""
    return {m.group(1): m.group(2) for m in _FIELD_RE.finditer(line)}


def run_rungs(lang):
    ext, harness_lang = RUNG_SUITES.get(lang, (None, None))
    if ext is None:
        return "UNPROVEN(2): no rungs instrument wired in this generator for %r" % lang
    prog = os.path.join(CORPUS_ROOT, "tests", lang, "ALL" + ext); ref = os.path.join(CORPUS_ROOT, "tests", lang, "ALL.ref")
    if not (os.path.isfile(prog) and os.path.isfile(ref)):
        return "RUNGS PENDING (no ALL%s + ALL.ref under corpus/tests/%s)" % (ext, lang)
    cmd = ["python3", os.path.join("scripts", "corpus_suite_harness.py"), "run", prog, ref, "--modes", "m3,m4"] + (["--lang", harness_lang] if harness_lang else [])
    try:
        p = subprocess.run(cmd, cwd=SCRIP_ROOT, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=RUNGS_TIMEOUT)
    except subprocess.TimeoutExpired:
        return "UNPROVEN(2): rungs run timed out after %ss -- unmeasured, not a verdict" % RUNGS_TIMEOUT
    out = (p.stdout or "") + "\n" + (p.stderr or "")
    m = _SUITE_BOARD_LINE_RE.search(out)
    if not m:
        tail = " ".join((p.stderr or p.stdout or "").strip().split("\n")[-1:])[:160]
        return "UNPROVEN(%d): no SUITE_BOARD line from the harness%s" % (p.returncode, (" -- " + tail) if tail else "")
    f = board_fields(m.group(0))
    if "total" not in f:
        return "UNPROVEN(%d): the SUITE_BOARD line carries no total= field -- %s" % (p.returncode, m.group(0)[:160])
    cols = ["total=%s" % f["total"]]
    for mode in ("m3", "m4"):
        if ("%s_pass" % mode) not in f:
            continue
        # a field the board did not print is ABSENT, never silently 0: the old regex demanded all eight and
        # returned nothing at all when one was missing, which read as "no board" rather than "a shorter board".
        missing = [k for k in _MODE_FIELDS if ("%s_%s" % (mode, k)) not in f]
        bits = ["%s pass=%s fail=%s crash=%s" % (mode, f.get("%s_pass" % mode, "?"),
                                                 f.get("%s_fail" % mode, "?"), f.get("%s_crash" % mode, "?"))]
        for k in ("hang", "unproven", "skip", "xfail", "xpass"):
            v = f.get("%s_%s" % (mode, k))
            if v is not None and v != "0":
                bits.append("%s=%s" % (k, v))
        if missing:
            bits.append("ABSENT:" + ",".join(missing))
        cols.append(" ".join(bits))
    return " · ".join(cols) + " (PER MODE, never summed)"


def repo_stamp(path):
    if not os.path.isdir(os.path.join(path, ".git")):
        return "unknown"
    try:
        h = subprocess.run(["git", "-C", path, "rev-parse", "--short", "HEAD"],
                            capture_output=True, text=True, timeout=10).stdout.strip()
        dirty = subprocess.run(["git", "-C", path, "status", "--porcelain"],
                                capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        return "unknown"
    if not h:
        return "unknown"
    return h + ("-DIRTY" if dirty else "")


# ⛔⭐ THIS COLUMN USED TO COUNT `xfail` OUT OF ALL.csv, AND THAT MADE THE SNOBOL4 ROW CONTRADICT ITSELF
# (hq_B 2026-09-02, FINDING-2026-09-02-hq_B-all-csv-is-a-generated-index-...). ALL.csv is GENERATED by
# util_build_rungs_suite.py (:1320 writes the column as int(bool(e.xfail))), while every GRADER -- the
# boards, the census, lib_rungs_extract.sh -- reads the ALL.xfail SIDECAR through read_suite. An XFAIL
# promotion edits the three hand-maintained homes (ALL.sno / ALL.ref / ALL.xfail) and does NOT re-run the
# builder, so the generated index goes stale: measured at 80 in the CSV against 70 from the reader, over
# exactly the ten entries promoted by c487af7c + 04177c4b + 2d75933e + 5b44ca01.
# ⭐ THE SYMPTOM WAS PUBLISHED AND UNREAD: SCORE.md's own snobol4 row carried "80 xfail" beside its board's
# "xfail=70", one row, two numbers, for the same quantity. A scoreboard that disagrees with itself in a
# single row is worse than one that is merely wrong, because each half looks sourced.
# ⛔ SO THIS READS THE GRADERS' AUTHORITY, NOT THE INDEX. It does not reimplement anything (this file's own
# rule): read_suite IS the function the boards call. A rung suite that cannot be read REFUSES into the column
# as UNPROVEN rather than falling back to the CSV -- a fallback to the other authority is what produced the
# contradiction in the first place.
def rungs_info(lang):
    ext, harness_lang = RUNG_SUITES.get(lang, (None, None))
    if ext is None:
        return None
    prog = os.path.join(CORPUS_ROOT, "tests", lang, "ALL" + ext)
    ref = os.path.join(CORPUS_ROOT, "tests", lang, "ALL.ref")
    if not (os.path.isfile(prog) and os.path.isfile(ref)):
        return None
    # ⛔⭐ AND IT MUST PICK THE READER THE WAY cmd_run DOES, BY LANGUAGE -- NOT just call read_suite.
    # read_suite() is the SNOBOL4 one-line dialect; every other rungs is a BLOCK suite and needs
    # read_block_suite() with that language's banner regex. Calling read_suite on a .pl/.icn/.pas/.sc
    # rungs does not fail cleanly -- it mis-parses into nonsense ("family.ref is shorter than
    # family.sno at seq 4607" on a 534-entry icon rungs), which is the same wrong-reader trap that
    # makes `corpus_suite_harness.py list` unusable on any non-.sno rungs. Mirroring cmd_run's own
    # dispatch (LANG_CONFIGS + banner_re_for) keeps this file's "never reimplement" rule intact.
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    try:
        import corpus_suite_harness as _h
        _in, _x = _h.sidecar_in_path(prog), _h.sidecar_xfail_path(prog)
        if harness_lang:
            _cfg = _h.LANG_CONFIGS[harness_lang]
            _re = _h.banner_re_for(_cfg["comment_open"], _cfg["comment_close"])
            entries = _h.read_block_suite(prog, ref, _re, in_path=_in, x_path=_x)
        else:
            entries = _h.read_suite(prog, ref, in_path=_in, x_path=_x)
    except Exception as exc:
        return {"unproven": "%s: %s" % (type(exc).__name__, str(exc)[:90])}
    return {"entries": len(entries), "xfail": sum(1 for e in entries if e.xfail)}


def run_gate(lang, fake_missing=False):
    g = GATES.get(lang)
    if not g:
        return "UNPROVEN(2): no gate wired in this generator for %r" % lang
    script_path = os.path.join(SCRIP_ROOT, "scripts", g["script"])
    if fake_missing or not os.path.isfile(script_path):
        return "UNPROVEN(2): gate script missing at ../harness/scripts/%s" % g["script"]
    cmd = ["bash", os.path.join("scripts", g["script"])] + g["args"]
    try:
        p = subprocess.run(cmd, cwd=SCRIP_ROOT, stdin=subprocess.DEVNULL,
                            capture_output=True, text=True, timeout=GATE_TIMEOUT)
    except subprocess.TimeoutExpired:
        return "UNPROVEN(2): gate timed out after %ss -- an rc is not a measurement of time, this is NOT a hang/pass verdict, just unmeasured" % GATE_TIMEOUT
    out = (p.stdout or "") + "\n" + (p.stderr or "")
    m = g["pattern"].search(out)
    if not m:
        # Surface the gate's OWN stated reason when it gave one (a REFUSES/UNPROVEN line is more useful
        # than a generic "didn't match" -- this is exactly what caught the live corpus/demos vs corpus/demo
        # path mismatch during this row's own build) -- never fabricate a number either way.
        first_line = next((ln.strip() for ln in out.splitlines() if ln.strip()), "")
        reason = (": %s" % first_line) if first_line else ""
        return "UNPROVEN(2): gate ran (rc=%d), output did not match the expected pattern%s" % (p.returncode, reason)
    return g["format"](m, out)


def build_grid(langs):
    lines = ["| Language | Rungs suite (`ALL.csv`) | Floor/smoke gate | Rungs board (`ALL.<ext>` via `corpus_suite_harness.py run`, m3 · m4) |", "|---|---|---|---|"]
    for lang in langs:
        mi = rungs_info(lang)
        if mi is None:
            rungs_col = "RUNGS PENDING"
        elif "unproven" in mi:
            rungs_col = "UNPROVEN (read_suite refused: %s)" % mi["unproven"]
        else:
            rungs_col = ("%d entries" % mi["entries"]) + (", %d xfail" % mi["xfail"] if mi["xfail"] else "")
        gate_col = run_gate(lang)
        board_col = run_rungs(lang)
        lines.append("| %s | %s | %s | %s |" % (lang, rungs_col, gate_col, board_col))
    stamp = "tree: SCRIP=%s corpus=%s .github=%s  generated %s" % (
        repo_stamp(SCRIP_ROOT), repo_stamp(CORPUS_ROOT), repo_stamp(GITHUB_ROOT),
        time.strftime("%Y-%m-%dT%H:%MZ", time.gmtime()))
    return "\n".join(lines) + "\n\n_%s_\n" % stamp


def selftest():
    # RULES.md TWO-PART PROOF, applied to this generator itself: exercise BOTH directions before
    # trusting a single row of its own output -- prove it can say "not measured" (UNPROVEN, on a
    # deliberately-broken gate) AND that it can say "measured" (a real PASS/FAIL, on a real gate).
    ok = True
    # ⛔ The positive-control arm below deliberately does NOT use snobol4: it is picked to be the smallest,
    # fastest gate this table knows (a smoke test, seconds not minutes) precisely so this generator's OWN
    # mechanism is proven independent of any ONE language's gate happening to be healthy this week. Coupling
    # a tool's self-test to a specific language's external gate health is an accidental dependency, not a
    # deliberate one -- caught live during this row's own build when test_corpus_snobol4.sh started
    # refusing (a real, separately-flagged corpus/demos path defect, hq_C `snobol4-floor-gate-refuses-demos-
    # vs-demo-path-mismatch`) and took this selftest down with it for a reason that had nothing to do with
    # this generator.
    missing = run_gate("rebus", fake_missing=True)
    if not missing.startswith("UNPROVEN(2)"):
        print("SELFTEST FAIL: a missing gate script did not refuse loudly -- got: %r" % missing)
        ok = False
    else:
        print("SELFTEST: missing-gate arm correctly UNPROVEN -- %s" % missing)
    real = run_gate("rebus")
    if real.startswith("UNPROVEN"):
        print("SELFTEST FAIL: the real rebus gate could not be measured at all -- got: %r" % real)
        ok = False
    else:
        print("SELFTEST: real rebus gate produced a measured result -- %s" % real)
    unwired = run_gate("no-such-language")
    if "no gate wired" not in unwired:
        print("SELFTEST FAIL: an unwired language did not refuse cleanly -- got: %r" % unwired)
        ok = False
    else:
        print("SELFTEST: unwired-language arm correctly refused -- %s" % unwired)
    print("SELFTEST %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


def main():
    argv = sys.argv[1:]
    if "--selftest" in argv:
        return selftest()
    only = None
    for a in argv:
        if a.startswith("--lang="):
            only = a.split("=", 1)[1]
    langs = [only] if only else LANGS
    if only and only not in GATES:
        sys.stderr.write("REFUSED: unknown language %r. Known: %s\n" % (only, ", ".join(LANGS)))
        return 2
    print(build_grid(langs))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
