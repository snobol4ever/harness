#!/usr/bin/env python3
"""util_declare_owed.py -- THE OWED PROGRAMS OF A PACKAGE ROW DECLARED BY THEIR MEASURED CLASS (the cio 2026-11-12 13:4x CST, row
packages-owed-snobol4-icon-cio under packages-consolidation-finish-cio; Lon 13:2x, in the coo's window, verbatim: "Has both the TESTS and PACKAGES
part of $/corpus unification and consolidation finished yet? if not, get CIO and CFO on it STAT. Now!").

A program is OWED when ALL.omit leaves it out by the builder's own measurement and neither EXCLUDED.tsv nor CONTAINERS.tsv declares it
(util_cycle_inventory.py --owed KEY, skill suites-and-grading section 3). A CLOSED FACT is declared, never deleted: this tool appends one row a
program to the package's EXCLUDED.tsv, name TAB CLASS TAB evidence, the CLASS a word lib_excluded.sh's inventory_excluded_names accepts and the
evidence the builder's reason verbatim. A class an attribute can cure (NEEDS-INPUT a NAME.in, MISSING-INCLUDE the include path, a missing
dependency) is never declared: it is listed as LEFT, for its absorption. A reason the map does not know is LEFT too, never guessed.

usage: util_declare_owed.py KEY [--root S4E_HOME] [--skip CLASS[,CLASS...]] [--row TOPIC] [--declare-empty] [--write]
  without --write it prints what it would declare and changes nothing; --skip leaves a mapped class owed (the grader's FPC NO-OUTPUT, graded by
  exit code); --declare-empty declares NO-OUTPUT and EMPTY too, only after their arguments, stdin and goal are ruled out. One line per program, DECLARE or LEFT, then OWED-DECLARE key=K declared=N left=M (rc 0), or REFUSE(2) when it cannot read the row.
"""
import os, re, subprocess, sys

# the builder's class word (the reason's first word, or a phrase of the older builder's prose) -> the vocabulary of lib_excluded.sh
CLOSED = [
    (r"^(ORACLE-REFUSES|ORACLE-DIES|ORACLE-HANGS|DIFFERS-BETWEEN-RUNS|NONDETERMINISTIC|DOES-NOT-END|CLOCK-SEEDED|READS-THE-ENVIRONMENT):", "NO_ORACLE_ANSWER"),
    (r"^the oracle answers differently on two runs", "NO_ORACLE_ANSWER"),
    (r"^oracle died", "NO_ORACLE_ANSWER"),
    (r"^oracle (hung|timed out|crashed)", "NO_ORACLE_ANSWER"),
    (r"^the oracle's translator refused it", "NO_ORACLE_ANSWER"),
    (r"^LIBRARY:", "NOT_A_UNIT_TEST"),
    (r"^multi-program file", "NOT_A_UNIT_TEST"),
    (r"^NEEDS-DISPLAY: the source names NativeCall", "NEEDS_C_LIBRARY"),   # NativeCall is Raku's C foreign-function interface, no display (the cfo 2026-11-12, row packages-owed-prolog-raku-cfo: 33 such programs in rakudo-t and raku-examples)
    (r"^NEEDS-DISPLAY: the source names Term(inal)?::", "NEEDS_TERMINAL"),   # Term::ANSIColor, Terminal::*: a terminal, Lon's NEEDS_TERMINAL word, not a graphics facility
    (r"^NEEDS-DISPLAY:", "NEEDS_GRAPHICS_FACILITY"),
    (r"^NEEDS-NETWORK:", "NEEDS_NETWORK"),
    (r"^NEEDS-C-COMPILER:", "NEEDS_C_LIBRARY"),
    (r"^NEEDS-ITS-OWN-SYSTEM:", "NO_ORACLE_ANSWER"),   # its main raises under the oracle for a builtin or library of another system's own (trealla-more: fork/0, Trealla's socket library, put_atts/2): the oracle gives no answer
    (r"(?i)^loads c through \S+\.clib", "NEEDS_LOADFUNC"),
]


# AN EMPTY ANSWER IS NO CLOSED FACT UNTIL IT IS RE-MEASURED (the cio 2026-11-12 13:4x, measured on snoflake: 34 programs the builder read EMPTY or
# DIED carried their stdin in an @input header the builder never fed; with it every one answered, and the package's denominator went 79 -> 122;
# unicon-uni's NO-OUTPUT programs print a usage line or read &input): a program that printed nothing is LEFT unless --declare-empty is given,
# after its arguments, stdin and goal are ruled out by hand.
EMPTY = [(r"^NO-OUTPUT:", "NO_ORACLE_ANSWER"), (r"^oracle produced EMPTY output", "NO_ORACLE_ANSWER")]


def word(reason):
    m = re.match(r"([A-Z][A-Z-]+):", reason)
    return m.group(1) if m else reason.split(" ", 1)[0]


def main():
    a = sys.argv[1:]
    if not a or a[0].startswith("-"):
        print(__doc__.strip().split("\n\n")[-1])
        return 2
    key = a[0]
    opt = lambda n: a[a.index(n) + 1] if n in a and a.index(n) + 1 < len(a) else None
    root = opt("--root") or os.environ.get("S4E_HOME") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    skip = set((opt("--skip") or "").split(",")) - {""}
    row = opt("--row") or "packages-consolidation-finish-cio"
    write = "--write" in a
    d = None
    for l in open(os.path.join(root, "harness/scripts/SUITE_RUNNERS.tsv"), encoding="utf-8"):
        c = l.rstrip("\n").split("\t")
        if not l.startswith("#") and len(c) >= 5 and c[0] == key and c[1] == "pkg":
            d = os.path.join(root, c[4])
    if not d or not os.path.isdir(d):
        print("REFUSE(2) [declare-owed]: %s is no pkg row of SUITE_RUNNERS.tsv with a directory under %s" % (key, root))
        return 2
    r = subprocess.run([sys.executable, "-I", os.path.join(root, "harness/scripts/util_cycle_inventory.py"), "--root", root, "--owed", key],
                       capture_output=True, text=True, errors="replace")
    lines = r.stdout.rstrip("\n").split("\n")
    if r.returncode != 0 or not lines or not lines[-1].startswith("OWED %s n=" % key):
        print("REFUSE(2) [declare-owed]: util_cycle_inventory.py --owed %s did not answer (rc %d): %s" % (key, r.returncode, (r.stdout + r.stderr)[-200:]))
        return 2
    rows, left = [], 0
    for l in lines[:-1]:
        name, _, reason = l.partition("\t")
        cls = next((v for p, v in CLOSED + (EMPTY if "--declare-empty" in a else []) if re.search(p, reason)), None)
        if cls is None or word(reason) in skip:
            left += 1
            print("LEFT     %s  [%s]" % (name, reason[:120]))
            continue
        ev = re.sub(r"[\t\r\n]+", " ", reason).strip()
        rows.append("%s\t%s\t%s (the builder's measurement in ALL.omit; declared by util_declare_owed.py, row %s)" % (name, cls, ev, row))
        print("DECLARE  %s  %s" % (name, cls))
    if write and rows:
        p = os.path.join(d, "EXCLUDED.tsv")
        head = "" if os.path.isfile(p) else ("# EXCLUDED.tsv -- %s: the programs this package ships and does not grade, one row a program: name<TAB>CLASS<TAB>evidence,\n"
                                             "# the CLASS a word lib_excluded.sh accepts and the evidence the builder's measurement (ALL.omit), declared by util_declare_owed.py.\n" % key)
        with open(p, "a", encoding="utf-8") as f:
            if head:
                f.write(head)
            elif open(p, "rb").read()[-1:] not in (b"\n", b""):
                f.write("\n")
            f.write("\n".join(rows) + "\n")
    print("OWED-DECLARE key=%s declared=%d left=%d%s" % (key, len(rows), left, " written=%s" % os.path.relpath(os.path.join(d, "EXCLUDED.tsv"), root) if write and rows else " (dry run)" if not write else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
