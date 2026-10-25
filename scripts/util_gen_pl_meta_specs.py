#!/usr/bin/env python3
"""util_gen_pl_meta_specs.py -- THE META-PREDICATE SPECS OF THE BUILTINS, ONE TABLE PER DIALECT, CUT FROM THE ORACLES
(the cto's ARCH-PROLOG-DATABASE.md section 4c, ruled 2026-10-24 under CEO-1964/1971; row
prolog-predicate-property-meta-predicate-is-one-record-column-read-in-both-dialects-sec-4c-ceo-1964).

predicate_property(H, meta_predicate(Spec)) answers from ONE column of the predicate's record. A predicate with Prolog source
gets the column from its :- meta_predicate directive at lowering; a builtin with no Prolog source (the C and asm builtins and
the control constructs) gets it from the table this script writes, never from a list typed by hand.

  --cut      run the oracles and write harness/scripts/pl_meta_specs.tsv: swipl 9.0.4's
             findall over predicate_property(system:H, meta_predicate(S)) (147 rows) and gprolog 1.4.5's
             predicate_property(H, meta_predicate(S)) over its builtins (54 rows), each spec's arguments printed as the oracle
             prints them (0..9 : ^ // ? + - * for swipl, 0..9 : ? + - for gprolog -- verbatim, never normalised).
  (default)  write SCRIP/src/runtime/pl_meta_specs.inc from the TSV: one token array and two row tables (swi, gnu), each row
             { name, arity, index of its first token }; the runtime and the lowerer read it through rt_pl_meta_builtin.
  --check    rc 1 when the .inc is not what the TSV gives (an .inc edited by hand, or a TSV re-cut without a regeneration).

rc 0 written or current; rc 1 stale; rc 2 cannot read or run what it needs.
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TSV = os.path.join(HERE, "pl_meta_specs.tsv")
INC = os.path.join(HERE, "..", "..", "SCRIP", "src", "runtime", "pl_meta_specs.inc")
SWIPL = "/usr/bin/swipl"
GPLC = "/usr/bin/gplc"
SWI_GOAL = ("forall((predicate_property(system:H, meta_predicate(S)), functor(S, N, A)), "
            "(S =.. [_|Ts], format('swi~a~w~a~w', ['\\t', N, '\\t', A]), forall(member(T, Ts), format('~a~w', ['\\t', T])), nl))")
GNU_PROG = (":- initialization(main).\n"
            "main :- ( predicate_property(H, meta_predicate(S)), functor(S, N, A), S =.. [_|Ts], "
            "write(gnu), put_char('\\t'), write(N), put_char('\\t'), write(A), "
            "( member(T, Ts), put_char('\\t'), write(T), fail ; true ), nl, fail ; true ).\n")


def refuse(msg):
    print("REFUSE(2): " + msg, file=sys.stderr)
    sys.exit(2)


def cut():
    for b in (SWIPL, GPLC):
        if not os.access(b, os.X_OK):
            refuse("oracle %s is not installed" % b)
    rows = []
    out = subprocess.run([SWIPL, "-q", "-g", SWI_GOAL, "-t", "halt"], capture_output=True, text=True, timeout=120)
    if out.returncode != 0:
        refuse("swipl failed: " + out.stderr.strip()[:200])
    rows += [l.split("\t") for l in out.stdout.splitlines() if l.startswith("swi\t")]
    with tempfile.TemporaryDirectory() as d:
        src, exe = os.path.join(d, "m.pl"), os.path.join(d, "m")
        with open(src, "w") as f:
            f.write(GNU_PROG)
        c = subprocess.run([GPLC, "-o", exe, src], capture_output=True, text=True, timeout=120)
        if c.returncode != 0:
            refuse("gplc failed: " + c.stderr.strip()[:200])
        out = subprocess.run([exe], capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL)
        rows += [l.split("\t") for l in out.stdout.splitlines() if l.startswith("gnu\t")]
    for r in rows:
        if len(r) != 3 + int(r[2]):
            refuse("a row whose token count is not its arity: " + "|".join(r))
    rows = sorted(set(tuple(r) for r in rows), key=lambda r: (r[0], r[1], int(r[2])))
    with open(TSV, "w") as f:
        f.write("# pl_meta_specs.tsv -- written by util_gen_pl_meta_specs.py --cut from swipl 9.0.4 and gprolog 1.4.5; never edited by hand.\n")
        f.write("# columns: dialect <TAB> name <TAB> arity <TAB> one argument spec per column, verbatim as the oracle prints it\n")
        for r in rows:
            f.write("\t".join(r) + "\n")
    print("cut %d rows (swi %d, gnu %d) -> %s" % (len(rows), sum(r[0] == "swi" for r in rows), sum(r[0] == "gnu" for r in rows), TSV))


def c_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render():
    try:
        lines = [l.rstrip("\n") for l in open(TSV, encoding="utf-8") if l.strip() and not l.startswith("#")]
    except OSError:
        refuse("cannot read " + TSV)
    rows = [l.split("\t") for l in lines]
    toks, tables = [], {"swi": [], "gnu": []}
    for r in rows:
        if r[0] not in tables or len(r) != 3 + int(r[2]):
            refuse("a malformed row in the TSV: " + "|".join(r))
        tables[r[0]].append((r[1], int(r[2]), len(toks)))
        toks += r[3:]
    o = ["static const char *const pl_meta_tok[] = {"]
    o += ["    " + c_str(t) + "," for t in toks]
    o.append("    (const char *)0 };")
    for d in ("swi", "gnu"):
        o.append("static const pl_meta_row_t pl_meta_rows_%s[] = {" % d)
        o += ["    { %s, %d, %d }," % (c_str(n), a, i) for n, a, i in tables[d]]
        o.append("    { (const char *)0, 0, 0 } };")
    return "\n".join(o) + "\n"


def main():
    args = sys.argv[1:]
    if args == ["--cut"]:
        cut()
        args = []
    text = render()
    if args == ["--check"]:
        try:
            have = open(INC, encoding="utf-8").read()
        except OSError:
            refuse("cannot read " + INC)
        if have != text:
            print("STALE: %s is not what %s gives -- run util_gen_pl_meta_specs.py" % (INC, TSV))
            sys.exit(1)
        print("FRESH: %s is what %s gives" % (os.path.basename(INC), os.path.basename(TSV)))
        return
    if args:
        refuse("usage: util_gen_pl_meta_specs.py [--cut | --check]")
    with open(INC, "w", encoding="utf-8") as f:
        f.write(text)
    print("wrote " + INC)


main()
