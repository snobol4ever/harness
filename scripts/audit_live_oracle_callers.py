#!/usr/bin/env python3
"""audit_live_oracle_callers.py [--dir DIR] [--check | --update | --selftest] [--baseline FILE] [--top N] -- THE LIVE-ORACLE CALLERS RATCHET (CEO-2041).

THE RULE (the cto's ruling of 2026-10-31 17:1x CDT on shared-dev step 8, ARCH-SHARED-DEVELOPMENT 3.4): every live oracle run goes through
util_oracle.sh -- one run slot before the clock, timeout -k 5, the SHA-keyed shared cache under /home/resources/progress/oracle. This census
reads the source of every script under $S4E_HARNESS/scripts (or --dir) and counts, per file, the lines that still name an oracle binary
directly: a call of one of the accessors of lib_oracle_flags.sh that util_oracle.sh serves (ACCESSORS below) or a literal path to one of
those binaries or to their wrappers (PATHS below). A guard such as [ -x "$(swipl_bin)" ] counts too: util_oracle.sh refuses rc 2 on a
missing binary itself, so a caller moved to it needs no guard.

NOT COUNTED: a comment line (shell or Python), a Python docstring line, a shell echo or printf line (it prints text, it calls nothing), a
bare command name on PATH (swipl, raku: test_gate_no_bare_gprolog_or_gplc_outside_the_accessors.sh and the accessors' own refusals own
that road), the benchmark oracle sbl_clean_bin (a timed run, never cached) and the rivals util_oracle.sh does not serve (jcon, csnobol4).

EXEMPT (by basename, each with its reason; see EXEMPT below): util_oracle.sh (the one caller), monitor_run.sh (the monitor bracket must run
the oracle live, the cto's ruling), lib_oracle_flags.sh (defines the accessors), oracle_gprolog.sh and oracle_gplc.sh (the wrappers the
gprolog and gplc accessors name, which util_oracle.sh itself runs), util_toolchain_preflight.sh (it proves the binary
itself runs at its declared path; a cached answer would hide a broken one).

THE GRADERS' ROADS (corpus_suite_harness.py, the package runners) are counted like every other file; moving them is the coo's (the row's
GOAL), and the ratchet only refuses their rise.

    --check     rc 0 when no file's count rose and no new file appears (a file whose count fell prints LOWER: run --update), rc 1 otherwise
                (each ROSE or NEW FILE named), rc 2 without a baseline or with an empty population
    --update    rewrites the baseline, only downward: rc 1 and nothing written when a file rose or a new file appears; a missing baseline is created
    --selftest  the census's own fixtures: each counted form counted, each excluded form refused
    (none)      prints the census, rc 0
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_BASELINE = os.path.join(HERE, "audit_live_oracle_callers.baseline.tsv")
ACCESSORS = ["sbl_correctness_bin", "icont_bin", "icon_bin", "iconx_bin", "swipl_bin", "gprolog_bin", "gplc_bin", "xsb_bin", "unicon_bin",
             "rakudo_bin", "fpc_bin"]
PATHS = [r"/home/resources/x64/bin/sbl\b", r"/usr/bin/swipl\b", r"/usr/bin/fpc\b", r"/usr/bin/raku\b", r"rakudo-local/bin/raku\b",
         r"icon-master/bin/icon[tx]?\b", r"prologs/xsb/XSB/bin/xs[b]\b", r"unicon/bin/unicon\b", r"\boracle_gprolog\.sh\b",
         r"\boracle_gplc\.sh\b", r"gprolog-mon/pristine/gprolog-1\.6\.0/bin\b"]
EXEMPT = {
    "util_oracle.sh": "the one live-oracle caller (CEO-2041)",
    "monitor_run.sh": "the monitor bracket must run the oracle live (the cto's ruling, 2026-10-31 17:1x CDT)",
    "lib_oracle_flags.sh": "defines the accessors; a definition is not a call",
    "oracle_gprolog.sh": "the wrapper gprolog_bin names, which util_oracle.sh runs",
    "oracle_gplc.sh": "the wrapper gplc_bin names, which util_oracle.sh runs",
    "audit_live_oracle_callers.py": "this census; its pattern list names every binary it counts",
    "util_toolchain_preflight.sh": "proves the binary itself runs at its declared path (PREFLIGHT_SBL plant); a cached answer would hide a broken one",
}
SIG = re.compile(r"(?<![\w$])(?:%s)(?!\w)|%s" % ("|".join(ACCESSORS), "|".join(PATHS)))
SUFFIXES = (".sh", ".py", ".inc", ".bash")


def scan_text(text, is_py):
    """The 1-based line numbers of the lines of text that name an oracle binary directly."""
    hits, in_doc = [], None
    for i, s in enumerate(text.split("\n")):
        st = s.lstrip()
        if is_py:
            if in_doc:
                if in_doc in s:
                    in_doc = None
                continue
            m = re.match(r'[rbuRBU]?("""|\'\'\')', st)
            if m:
                if st.count(m.group(1)) < 2:
                    in_doc = m.group(1)
                continue
        if st.startswith("#"):
            continue
        if not is_py and re.match(r"(echo|printf)\b", st):
            continue
        if SIG.search(s):
            hits.append(i + 1)
    return hits


def population(d):
    out = []
    for n in sorted(os.listdir(d)):
        p = os.path.join(d, n)
        if os.path.isfile(p) and not os.path.islink(p) and n.endswith(SUFFIXES) and n not in EXEMPT:
            out.append(n)
    return out


def census(d):
    counts = {}
    for n in population(d):
        with open(os.path.join(d, n), errors="replace") as f:
            k = len(scan_text(f.read(), n.endswith(".py")))
        if k:
            counts[n] = k
    return counts


def read_baseline(path):
    b = {}
    with open(path) as f:
        for ln in f.read().splitlines()[1:]:
            if ln.strip() and not ln.startswith("#"):
                n, k = ln.split("\t")[:2]
                b[n] = int(k)
    return b


def write_baseline(path, counts):
    with open(path, "w") as f:
        f.write("file\tsites\n")
        for n in sorted(counts):
            f.write("%s\t%d\n" % (n, counts[n]))


def compare(cur, base):
    rose = [(n, base.get(n), k) for n, k in sorted(cur.items()) if n not in base or k > base[n]]
    fell = [(n, b, cur.get(n, 0)) for n, b in sorted(base.items()) if cur.get(n, 0) < b]
    return rose, fell


def selftest():
    cases = [
        ('SW="$(swipl_bin)" || exit 2', False, 1), ('"$(sbl_correctness_bin)" -bf x.sno < /dev/null', False, 1),
        ("timeout -k 5 60 /home/resources/x64/bin/sbl -bf x.sno", False, 1), ('B=$(rakudo_bin); "$B" t.raku', False, 1),
        ('run(["/usr/bin/swipl", "-q", p])', True, 1), ("bash \"$HERE/oracle_gprolog.sh\" --consult x.pl", False, 1),
        ("ICONT=/home/resources/icon-master/bin/icont", False, 1),
        ("# swipl_bin is the accessor", False, 0), ('echo "use $(swipl_bin) here"', False, 0), ("x = 1  # not swipl_bin", True, 1),
        ('"""swipl_bin in a docstring"""', True, 0), ("$swipl_binary --version", False, 0), ("my_swipl_bin_count=3", False, 0),
        ('"$(sbl_clean_bin)" -bf k.sno', False, 0), ("bash util_oracle.sh swipl -- -q -g main x.pl", False, 0), ("swipl -q x.pl", False, 0),
    ]
    bad = 0
    for text, is_py, want in cases:
        got = len(scan_text(text, is_py))
        if got != want:
            print("FAIL: %r (py=%s) counted %d, want %d" % (text, is_py, got, want))
            bad += 1
    doc = '"""\nswipl_bin\nicont_bin\n"""\nx = swipl_bin()\n'
    if scan_text(doc, True) != [5]:
        print("FAIL: a multi-line docstring is not skipped: %r" % scan_text(doc, True))
        bad += 1
    if bad:
        return 1
    print("selftest: %d forms read as declared (counted, comment, echo, docstring, look-alike, bench oracle, util_oracle.sh, bare name)" % (len(cases) + 1))
    return 0


def main(argv):
    d, baseline, mode, top = HERE, DEFAULT_BASELINE, None, 15
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--check", "--update", "--selftest"):
            mode = a
        elif a in ("--dir", "--baseline", "--top") and i + 1 < len(argv):
            i += 1
            if a == "--dir":
                d = argv[i]
            elif a == "--baseline":
                baseline = argv[i]
            else:
                top = int(argv[i])
        else:
            print("usage: " + __doc__.split("\n")[0].split(" -- ")[0])
            return 2
        i += 1
    if mode == "--selftest":
        return selftest()
    if not os.path.isdir(d) or not population(d):
        print("REFUSE(2): no script population under %s" % d)
        return 2
    cur = census(d)
    tot = sum(cur.values())
    for n, k in sorted(cur.items(), key=lambda x: -x[1])[:top]:
        print("  %5d  %s" % (k, n))
    print("CENSUS: %d file(s) of %d name an oracle binary directly, %d site(s); exempt: %s" % (len(cur), len(population(d)), tot,
                                                                                             " ".join(sorted(EXEMPT))))
    if mode == "--update":
        if os.path.exists(baseline):
            rose, _ = compare(cur, read_baseline(baseline))
            if rose:
                for n, b, k in rose:
                    print("REFUSE(1): %s rose from %s to %d -- a baseline is only lowered" % (n, "absent" if b is None else b, k))
                return 1
        write_baseline(baseline, cur)
        print("baseline written: %d file(s), %d site(s) -> %s" % (len(cur), tot, baseline))
        return 0
    if mode != "--check":
        return 0
    if not os.path.exists(baseline):
        print("REFUSE(2): no baseline at %s -- run --update once" % baseline)
        return 2
    base = read_baseline(baseline)
    rose, fell = compare(cur, base)
    for n, b, k in fell:
        print("LOWER: %s fell from %d to %d -- run --update in the same landing" % (n, b, k))
    for n, b, k in rose:
        print("RED: %s %s (%s -> %d): call the oracle through util_oracle.sh" % ("NEW FILE" if b is None else "ROSE", n, "absent" if b is None else b, k))
    print("CHECK: %d file(s), %d site(s) against a baseline of %d file(s), %d site(s); %d rose, %d fell" % (len(cur), tot, len(base), sum(base.values()),
                                                                                                         len(rose), len(fell)))
    return 1 if rose else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
