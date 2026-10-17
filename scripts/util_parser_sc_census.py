#!/usr/bin/env python3
"""util_parser_sc_census.py [--lang L[,L]] [--population corpus|ladder|rungs] [--declared TSV] [--jobs N (default: the fan-out ceiling of lib_fanout.py, max(2, min(4, cores - demand)), CEO-1333)] [--timeout S] [--list TSV]

DOES EACH BOOTSTRAP PARSER WORK? (Lon 2026-09-23 15:2x, in-chat to the ceo: hq_snocone "to get all the SCRIP bootstrap
parsers working".) For every language, the Snocone-hosted parser SCRIP/bootstrap/parser_<lang>.sc -- loaded behind the
14-file bootstrap runtime in the order ../harness/scripts/run_scrip_parser.sh declares, BY CONCATENATION (the Snocone branch of the
driver never reads a -L chain; util_parser_sc_census.sh's note) -- is run by ./scrip over every program of a declared
population with the program as its stdin. POPULATION ladder (default): every entry of the language's rungs whose ALL.csv
origin is ladder__* -- the construct ladder, one construct per rung, cut from the public reference; POPULATION rungs:
every entry of the rungs; POPULATION corpus, the default (Lon to hq_snocone 15:2x: "Test the parsers using all the corpus
sources"): every file of the language's extension under corpus/, the ALL.* containers and the root library/ (the second .sc chain) excluded -- a package's own library/ counts (hq_snocone 2026-09-26: the depth-blind prune dropped packages/prolog/swi_tests/library, 39 .pl). CLASSIFICATION (hq_snocone's, kept): the first non-blank output line not starting with SEQ<n>
begins with '(' = PARSED (the parser emitted a tree); contains "Parse Error" = REFUSED; a clean exit (rc 0, no error line) that
printed nothing = EMPTY (hq_snocone 2026-09-25: a source holding only comments and control lines -- the gimpel *_driver.sno that are
one -INCLUDE -- has no statement to print, which is neither a tree shown nor a crash); a clean exit whose output is "Parsed." and no
tree = RECOGNIZED (a recognizer's acceptance: not a tree, so still red, and not a crash); anything
else -- a crash, a timeout, heap exhaustion, a runtime error -- = CRASH, its first line named, because a parser that dies is not a
parser that declines. A program's time limit is 10 x its language's start-up on an empty input (10..300 s) unless --timeout S names one;
without --timeout every program that times out is re-run alone at 300 s before it counts, so a load rise mid-run is no CRASH.
It prints its denominator per language as each language finishes and names the first REFUSED and first CRASH; --list TSV
also writes EVERY member as a row (lang, corpus-relative source or rungs key, class, first line) so a class can be read whole
(hq_snocone 2026-09-27: 66 Icon CRASHes on the SCRIP arm were one name on the board line and no list). A REFUSED
source listed in --declared (default SCRIP/bootstrap/tests/parser_refusals.tsv: lang, corpus-relative path, the measurement
that the source is not a legal program of its language, or for an EMPTY source that it holds no statement) is DECLARED, never red;
an undeclared refusal or EMPTY is red, because a parser that declines a legal program, or prints nothing for one, is not working. rc 0 GREEN (every language: population > 0, CRASH 0, undeclared REFUSED 0),
1 RED, 2 REFUSE (no ./scrip, no rungs, a population that could not be materialized).
PARSED is a tree, not a CORRECT tree: equivalence with the C frontend's AST is the next bar, written in the row's GOAL.
"""
import concurrent.futures
import sys as _fanout_sys, os as _fanout_os
_fanout_sys.path.insert(0, _fanout_os.path.dirname(_fanout_os.path.abspath(__file__)))
import lib_fanout
import csv
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIP = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
HOME = os.environ.get("S4E_HOME") or os.path.dirname(SCRIP)
CORPUS = os.path.join(HOME, "corpus")
RT = ["global", "case", "assign", "match", "counter", "stack", "tree", "ShiftReduce", "tdump", "gen", "qize", "semantic", "omega", "trace"]
LANGS = [("snobol4", "sno"), ("icon", "icn"), ("prolog", "pl"), ("raku", "raku"), ("pascal", "pas"), ("snocone", "sc"), ("rebus", "reb")]
SEQ = re.compile(r"^SEQ[0-9]")
# THE PER-PROGRAM LIMIT IS AN ORDER OF MAGNITUDE ABOVE WHAT THE LANGUAGE'S CHAIN COSTS TO START (hq_snocone 2026-09-25, measured): a
# fixed 10 s read the Raku chain as 128 CRASH of 129 when 85 print their answer in 5-12 s at box load 15 (the 2011-line chain's
# compile), and Icon's 9.4 s start-up on an empty input killed all 1329 before one character was parsed -- a limit beside the
# measurement is a flaky bound, never a hang detector. So each language's chain is run once on an empty stdin (TBOOT cap) and a
# program's limit is 10 x that start-up, clamped to TMIN..TMAX; a chain that cannot start within TBOOT makes every program of its
# language a CRASH named START-UP, none run (each would only time out later). --timeout S still fixes one limit for all.
TMIN, TMAX, TBOOT = 10, 300, 120
# HUGE HEAP AND HUGE STACK, ALWAYS (Lon 2026-09-26, in-chat to hq_snocone, verbatim: "You should run with huge heap and huge stack
# always to avoid limits."), committed lazily (RSS 45 MB either way) -- and the size is the CHAIN's declaration, never typed here (ceo
# CEO-1353, RULES.md clause 8 (g)(4)): bootstrap/parser_<lang>.heap and .stack, read through corpus_suite_harness, the one reader.
import corpus_suite_harness as _harness


def arena(lang):
    """scrip's -d/-s switches for the chain of `lang`, from bootstrap/parser_<lang>.heap and .stack; refuses an undeclared chain."""
    drv = os.path.join(SCRIP, "bootstrap", "parser_%s.sc" % lang)
    heap, _ = _harness.heap_declarations(drv)
    stack, _ = _harness.stack_declarations(drv)
    sw = _harness._size_switches(heap.get("parser_" + lang), stack.get("parser_" + lang))
    if not sw:
        refuse("%s declares no heap or stack (bootstrap/parser_%s.heap, .stack) -- the chain's sizes are its declaration" % (drv, lang))
    return sw


def refuse(msg):
    print("REFUSE(2): " + msg)
    sys.exit(2)


def opt(argv, name, default):
    return argv[argv.index(name) + 1] if name in argv else default


def extract(src, ref, key, by_origin, out):
    cmd = [sys.executable, os.path.join(HERE, "corpus_suite_harness.py"), "extract", src, ref]
    cmd += ([out, "--origin", key] if by_origin else [key, out])
    cmd += ["--out-in", out + ".in"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return r.returncode == 0 and os.path.isfile(out), (r.stdout + r.stderr).strip().splitlines()[-1:] or [""]


def parse_one(scrip, chain, lang, prog, timeout):
    try:
        with open(prog, "rb") as f:
            r = subprocess.run([scrip] + arena(lang) + [chain], stdin=f, capture_output=True, timeout=timeout)
        text = (r.stdout + r.stderr).decode("utf-8", "replace")
        tag = ""
    except subprocess.TimeoutExpired as e:
        text = ((e.stdout or b"") + (e.stderr or b"")).decode("utf-8", "replace")
        tag = "TIMEOUT %ss" % timeout
    except OSError as e:
        return "UNEXTRACTED", "could not run %s (%s): the program was not measured" % (scrip, e.strerror or e)
    first = ""
    for line in text.splitlines():
        if line.strip() and not SEQ.match(line):
            first = line.strip()
            break
    if tag:
        return "CRASH", tag
    # ⛔ THE EXIT CODE AND EVERY LINE ARE READ, NOT THE FIRST LINE ALONE (hq_snocone 2026-09-23, measured): on SCRIP the
    # rebus parser prints its first tree and then SIGSEGVs, rc=139, which a first-line test called PARSED; and the parser's
    # refusal is a line that IS "Parse Error" -- beauty.sc prints the words, so its correct tree contains them.
    lines = [l.strip() for l in text.splitlines() if l.strip() and not SEQ.match(l)]
    if any(re.fullmatch(r"Parse Error\.?", l) for l in lines):
        return "REFUSED", "Parse Error"
    # hq_snocone 2026-09-27: an error marker is read only on a line that is not part of a tree (a tree line opens with ( or ) or is
    # indented), and FATAL only at column 0 -- five SNOBOL4 sources printed their whole tree, rc 0, and were called CRASH because a
    # string literal in the tree read "****** FATAL ERROR ******" or a keyword read &FATALLIMIT.
    raw = [l for l in text.splitlines() if l.strip() and not SEQ.match(l) and l[:1] not in "() \t"]
    err = next((l.strip() for l in raw if re.search(r"\bERROR \d+ --|^Error \d+|^FATAL\b|ZGC-STALE|CORRUPT CAPTURE", l)), "")
    if r.returncode != 0 or err:
        return "CRASH", "%s (rc=%d)" % (err or first or "no output", r.returncode)
    if not lines:
        return "EMPTY", "no output, rc=0"
    if first.startswith("("):
        return "PARSED", first
    # RECOGNIZED (hq_snocone 2026-09-25): a clean exit that prints "Parsed." and no tree is a recognizer's acceptance -- the old
    # parser_raku.sc's phase 1 (it builds trees since the 2026-09-29 rewrite) -- neither a tree (still red) nor a crash.
    if any(re.fullmatch(r"Parsed\.?", l) for l in lines):
        return "RECOGNIZED", first
    return "CRASH", first or "(no output, rc=%d)" % r.returncode


def task(scrip, chain, lang, ext, src, ref, key, by_origin, d, timeout):
    if by_origin is None:
        prog = key
    else:
        safe = re.sub(r"[^A-Za-z0-9_.-]", "_", key)
        prog = os.path.join(d, safe + "." + ext)
        ok, why = extract(src, ref, key, by_origin, prog)
        if not ok:
            return lang, key, "UNEXTRACTED", why[0]
    cls, first = parse_one(scrip, chain, lang, prog, timeout)
    return lang, key, cls, first


KNOWN = ("--lang", "--population", "--declared", "--jobs", "--timeout", "--list")


def main(argv):
    if "--help" in argv or "-h" in argv:
        print(__doc__.strip())
        return 0
    i = 1
    while i < len(argv):
        if argv[i] not in KNOWN or i + 1 >= len(argv):
            refuse("argument %r is not one this instrument implements, or has no value; the arguments are %s, each followed by its value (--help prints the usage)" % (argv[i], ", ".join(KNOWN)))
        i += 2
    pop = opt(argv, "--population", "corpus")
    decl_path = opt(argv, "--declared", os.path.join(SCRIP, "bootstrap", "tests", "parser_refusals.tsv"))
    declared = set()
    if os.path.isfile(decl_path):
        for line in open(decl_path, encoding="utf-8"):
            f = line.rstrip("\n").split("\t")
            if len(f) >= 3 and not line.startswith("#") and f[2].strip():
                declared.add((f[0], f[1]))
    jobs = int(opt(argv, "--jobs", str(lib_fanout.fanout_width())))
    timeout = int(opt(argv, "--timeout", "0"))
    want = opt(argv, "--lang", "")
    listpath = opt(argv, "--list", "")
    listed = []
    langs = [l for l in LANGS if not want or l[0] in want.split(",")]
    if not langs:
        refuse("no language matches --lang " + want)
    if pop not in ("corpus", "ladder", "rungs"):
        refuse("--population is corpus, ladder or rungs")
    scrip = os.path.join(SCRIP, "scrip")
    if not os.access(scrip, os.X_OK):
        refuse("no ./scrip at " + scrip + " -- run make")
    sys.path.insert(0, HERE)
    import corpus_suite_harness as harness
    harness.require_fresh(harness.resolve_paths())
    boot = os.path.join(SCRIP, "bootstrap")
    tmp = tempfile.mkdtemp(prefix="parser_sc_census.")
    try:
        rt = b"".join(open(os.path.join(boot, n + ".sc"), "rb").read() for n in RT)
        work = []
        pops = {}
        for lang, ext in langs:
            parser = os.path.join(boot, "parser_%s.sc" % lang)
            if not os.path.isfile(parser):
                refuse("no bootstrap parser " + parser)
            chain = os.path.join(tmp, "chain_%s.sc" % lang)
            open(chain, "wb").write(rt + open(parser, "rb").read())
            if pop == "corpus":
                files = []
                for dp, dn, fn in os.walk(CORPUS):
                    dn[:] = [x for x in dn if x != ".git" and not (x == "library" and dp == CORPUS)]
                    files += [os.path.join(dp, x) for x in fn if x.endswith("." + ext) and not x.startswith("ALL.")]
                files.sort()
                pops[lang] = len(files)
                for fpath in files:
                    work.append((scrip, chain, lang, ext, "", "", fpath, None, "", timeout))
                continue
            tdir = os.path.join(CORPUS, "tests", lang)
            src, ref, idx = os.path.join(tdir, "ALL." + ext), os.path.join(tdir, "ALL.ref"), os.path.join(tdir, "ALL.csv")
            if not (os.path.isfile(src) and os.path.isfile(ref) and os.path.isfile(idx)):
                refuse("the %s rungs (ALL.%s, ALL.ref, ALL.csv) is not under %s" % (lang, ext, tdir))
            rows = list(csv.DictReader(open(idx, encoding="utf-8")))
            keys = [(r["origin"], True) for r in rows if r.get("origin", "").startswith("ladder__")] if pop == "ladder" else [(r["entry"], False) for r in rows if r.get("entry")]
            pops[lang] = len(keys)
            d = os.path.join(tmp, lang)
            os.makedirs(d, exist_ok=True)
            for key, by_origin in keys:
                work.append((scrip, chain, lang, ext, src, ref, key, by_origin, d, timeout))
        print("PARSER-SC CENSUS, population %s, arena %s, tree %s, timeout %s, jobs %d, declared refusals %d from %s" % (pop, "; ".join("%s %s" % (l, " ".join(arena(l))) for l, _ in langs), subprocess.run(["git", "-C", SCRIP, "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip(), ("%ss per program (--timeout)" % timeout) if timeout else "per language, 10 x its start-up on an empty input, %d..%d s" % (TMIN, TMAX), jobs, len(declared), decl_path if os.path.isfile(decl_path) else "(none)"), flush=True)
        print("%-8s %6s %7s %6s %8s %8s %6s %6s %6s  %s" % ("lang", "pop", "PARSED", "RECOG", "REFUSED", "DECLARED", "CRASH", "EMPTY", "UNEXT", "first undeclared refusal / first crash / first empty"), flush=True)
        red = unext = tp = tn = 0
        for lang, _ in langs:
            r = {"PARSED": 0, "RECOGNIZED": 0, "REFUSED": 0, "DECLARED": 0, "CRASH": 0, "EMPTY": 0, "UNEXTRACTED": 0, "first": {}}
            mine = [w for w in work if w[2] == lang]
            tl, boot_s = timeout, None
            if not timeout:
                t0 = time.time()
                try:
                    subprocess.run([scrip] + arena(lang) + [mine[0][1] if mine else os.devnull], stdin=subprocess.DEVNULL, capture_output=True, timeout=TBOOT)
                    boot_s = time.time() - t0
                    tl = int(max(TMIN, min(TMAX, 10 * boot_s)))
                except subprocess.TimeoutExpired:
                    pass
            if not timeout and boot_s is None:
                results = [(lang, w[6], "CRASH", "START-UP over %ds on an empty input" % TBOOT) for w in mine]
            else:
                mine = [w[:9] + (tl,) for w in mine]
                with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as ex:
                    results = list(ex.map(lambda w: task(*w), mine))
                # A TIMEOUT IS RE-TIMED ALONE BEFORE IT COUNTS (hq_snocone 2026-09-27, measured 09-27d): the limit is fixed once from the
                # start-up, so a load rise mid-run turned six Raku programs into TIMEOUT crashes that each parse, rc 0, in 36..85 s when
                # re-run alone. Each TIMEOUT is re-run serially at TMAX; only one that still times out is a CRASH.
                if not timeout:
                    again = {w[6]: w[:9] + (TMAX,) for w in mine}
                    results = [task(*again[x[1]]) if x[2] == "CRASH" and x[3].startswith("TIMEOUT") else x for x in results]
            for _l, key, cls, first in results:
                rel = os.path.relpath(key, CORPUS) if os.path.isabs(key) else key
                if cls in ("REFUSED", "EMPTY") and (lang, rel) in declared:
                    cls = "DECLARED"
                r[cls] += 1
                r["first"].setdefault(cls, "%s [%s]" % (rel, first[:60]))
                listed.append("%s\t%s\t%s\t%s" % (lang, rel, cls, first.replace("\t", " ")[:200]))
            n = pops[lang]
            tp += r["PARSED"]
            tn += n
            f = " | ".join(x for x in (r["first"].get("REFUSED", ""), r["first"].get("CRASH", ""), r["first"].get("EMPTY", ""), r["first"].get("UNEXTRACTED", "")) if x)
            print("%-8s %6d %7d %6d %8d %8d %6d %6d %6d  %s" % (lang, n, r["PARSED"], r["RECOGNIZED"], r["REFUSED"], r["DECLARED"], r["CRASH"], r["EMPTY"], r["UNEXTRACTED"], f), flush=True)
            if not timeout:
                print("%-8s start-up on an empty input %s, so %s" % ("", ("%.1f s" % boot_s) if boot_s is not None else "over %d s" % TBOOT, ("a program's limit %d s" % tl) if boot_s is not None else "every program is a CRASH, none run"), flush=True)
            unext += r["UNEXTRACTED"]
            if n == 0 or r["CRASH"] or r["REFUSED"] or r["EMPTY"] or r["RECOGNIZED"]:
                red += 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        if listpath:
            with open(listpath, "w") as lf:
                lf.write("".join(x + "\n" for x in listed))
    print("PARSER-SC CENSUS: parsed=%d of %d over %d language(s); languages with a crash or an undeclared refusal: %d; unextracted: %d" % (tp, tn, len(langs), red, unext))
    if unext:
        print("REFUSE(2): %d program(s) of the population could not be materialized -- the census cannot say the parsers work over a population it did not read" % unext)
        return 2
    if red:
        print("RED: %d of %d bootstrap parser(s) crash on, or decline without a declared reason, a program of their %s population" % (red, len(langs), pop))
        return 1
    print("GREEN: every bootstrap parser parses its %s population to a tree, every refusal declared with its reason" % pop)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
