#!/usr/bin/env python3
"""util_raku_operator_coverage.py -- OPERATOR COVERAGE, WITH THE DENOMINATOR TAKEN FROM RAKUDO'S OWN GRAMMAR
(hq_raku 2026-09-16, on Lon's order to complete the Raku grammar "from the official Raku specification").

⛔⭐⭐ THE FIRST THING TO KNOW, BECAUSE IT DECIDES THE WHOLE METHOD: THERE IS NO BNF SPECIFICATION OF RAKU.
The language's normative specification is ROAST -- an executable test suite, which is why our roast board is
the completeness measure at all. The nearest thing to a written grammar is rakudo's own `src/Perl6/Grammar.nqp`,
5933 lines of NQP: a self-hosted, backtracking, recursive-descent grammar whose operator table is DECLARATIVE
and whose everything else is not. So "convert the specification" is only honest for the part that IS declared,
and that part is exactly the operator table this script extracts:

    my %additive := nqp::hash('prec', 't=', 'assoc', 'left', 'dba', 'additive');   # a precedence level
    token infix:sym<+> { <sym> <O(|%additive)> }                                   # an operator at that level

⭐ EVERYTHING ELSE IN THAT FILE RESISTS CONVERSION ON PURPOSE, and it is worth saying why rather than
discovering it three days in: Raku's grammar is MUTABLE DURING ITS OWN PARSE (`sub infix:<foo>` adds an
operator mid-file, `use` can install a slang), it dispatches by LONGEST-TOKEN protoregex across a braid of
sublanguages (main/quote/regex/pod), and it consults a live symbol table (`$*W`) to decide whether a bare
identifier is a type, a term or a call. No LALR(1) grammar can express a grammar that changes while it runs.
The operator table is the part that is a TABLE, and a table is portable.

WHAT THIS MEASURES: for every operator rakudo declares, the smallest snippet that exercises it, through
`scrip --dump-ast`, rc=0 or not. ⛔ THE DENOMINATOR IS DERIVED FROM Grammar.nqp ON EVERY RUN and never
transcribed -- if rakudo gains an operator, this number goes DOWN by itself, which is the only way a
coverage figure can stay honest as its target moves (CLAUDE.md: derive, never quote).
⛔ IT PUBLISHES NOTHING: no SCORE row, no board, no progress append -- so ONE RUNNER ONE BOARD is untouched
and any seat may run it. ⛔ It REFUSES rc=2 rather than printing a fraction over a population it could not
build: no grammar source, no binary, or zero operators extracted.

Usage: util_raku_operator_coverage.py [--summary] [--list-missing] [--grammar PATH] [--json OUT]
"""
import argparse, collections, json, os, re, subprocess, sys

CANDIDATE_GRAMMARS = [
    "/home/resources/rakudo-main/src/Perl6/Grammar.nqp",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "refs", "rakudo-main", "src", "Perl6", "Grammar.nqp"),
]

def refuse(msg, code=2):
    print("⛔ REFUSE(%d) [raku operator coverage]: %s" % (code, msg), file=sys.stderr)
    sys.exit(code)

def find_grammar(explicit):
    tried = []
    for c in ([explicit] if explicit else []) + CANDIDATE_GRAMMARS:
        tried.append(c)
        if c and os.path.isfile(c):
            return c
    refuse("no rakudo Grammar.nqp -- tried: %s. It is the only declarative source for the operator table; "
           "without it this script has no denominator and will not invent one." % ", ".join(tried))

def extract(path):
    """The conversion proper: precedence levels, then the operators bound to them."""
    lines = open(path, encoding="utf8", errors="replace").read().split("\n")
    src = "\n".join(lines)
    levels = {}
    for m in re.finditer(r"my %([a-z_]+)\s*:=\s*nqp::hash\(\s*'prec',\s*'([^']+)',\s*'assoc',\s*'([^']+)'", src):
        levels[m.group(1)] = {"prec": m.group(2), "assoc": m.group(3)}
    decl = re.compile(r"\b(?:token|rule|method)\s+(infix|prefix|postfix)\s*:\s*sym\s*<<?(.*?)>>?\s*\{")
    ops, seen = [], set()
    for i, ln in enumerate(lines):
        m = decl.search(ln)
        if not m:
            continue
        cat, sym = m.group(1), m.group(2)
        # ⛔ THE LEVEL IS READ FROM A BOUNDED WINDOW, NOT THE WHOLE FILE: <O(|%level)> sits in the token's
        # own body, and an unbounded search would happily bind an operator to the NEXT operator's level.
        win = "\n".join(lines[i:i + 12])
        o = re.search(r"<O\(\s*\|%([a-z_]+)", win)
        if not o or o.group(1) not in levels:
            continue
        key = (cat, sym)
        if key in seen:
            continue
        seen.add(key)
        lv = levels[o.group(1)]
        ops.append({"cat": cat, "sym": sym, "level": o.group(1), "prec": lv["prec"], "assoc": lv["assoc"]})
    return ops, levels

def snippet(cat, sym):
    """The smallest program that puts this operator in code position. Parse-only, so types never matter."""
    if cat == "infix":
        if sym == "?":                       # infix:<?> IS the ternary, and ?? !! is its real surface
            return "my $a; my $b; my $c; my $x = $a ?? $b !! $c;\n"
        if sym == ",":
            return "my $a; my $b; my $x = ($a , $b);\n"
        return "my $a; my $b; my $x = $a %s $b;\n" % sym
    if cat == "prefix":
        return "my $a; my $x = %s $a;\n" % sym
    if cat == "postfix":
        return "my $a; my $x = $a%s;\n" % sym
    return None

def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--summary", action="store_true", help="headline only")
    ap.add_argument("--list-missing", action="store_true", help="print every unparsed operator, one per line, bare")
    ap.add_argument("--grammar")
    ap.add_argument("--json")
    a = ap.parse_args()
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    scrip = os.path.join(root, "scrip")
    if not os.access(scrip, os.X_OK):
        refuse("no scrip binary at %s (run: make)" % scrip)
    gpath = find_grammar(a.grammar)
    ops, levels = extract(gpath)
    if not ops:
        refuse("extracted ZERO operators from %s -- the grammar's shape has moved and this parser of it is "
               "stale; a coverage fraction over an empty table is not a measurement" % gpath)
    tmp = os.path.join(os.environ.get("TMPDIR", "/tmp"), "raku_opcov_%d.raku" % os.getpid())
    rows = []
    try:
        for o in ops:
            s = snippet(o["cat"], o["sym"])
            if s is None:
                continue
            open(tmp, "w").write(s)
            try:
                r = subprocess.run([scrip, "--dump-ast", tmp], capture_output=True, timeout=20,
                                   stdin=subprocess.DEVNULL)
                ok = (r.returncode == 0)
            except subprocess.TimeoutExpired:
                ok = False
            rows.append(dict(o, parsed=ok))
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)
    n = len(rows)
    good = [r for r in rows if r["parsed"]]
    bad = [r for r in rows if not r["parsed"]]
    # ⛔ THE IDENTITY IS ASSERTED, NOT ASSUMED, like every other census in this tree.
    if len(good) + len(bad) != n:
        refuse("the verdicts do not close: total=%d parsed=%d unparsed=%d" % (n, len(good), len(bad)))
    if a.json:
        json.dump(rows, open(a.json, "w"), ensure_ascii=False, indent=0)
    if a.list_missing:
        for r in sorted(bad, key=lambda x: (x["cat"], x["sym"])):
            print("%s:%s\t%s\t%s\t%s" % (r["cat"], r["sym"], r["level"], r["prec"], r["assoc"]))
        return 0
    try:
        head = subprocess.run(["git", "-C", root, "rev-parse", "--short=9", "HEAD"],
                              capture_output=True, text=True).stdout.strip() or "unversioned"
    except Exception:
        head = "unversioned"
    print("RAKU_OPERATOR_COVERAGE PARSED %d/%d (%.1f%%) unparsed=%d levels=%d "
          "source=%s measure=--dump-ast_rc0 scrip=%s"
          % (len(good), n, 100.0 * len(good) / n, len(bad), len(levels), gpath, head))
    if not a.summary:
        by = collections.defaultdict(list)
        for r in bad:
            by[(r["prec"], r["level"], r["assoc"])].append("%s:%s" % (r["cat"], r["sym"]))
        print("RAKU_OPERATOR_UNPARSED, by the precedence level rakudo files each under (tightest first):")
        for k in sorted(by, reverse=True):
            print("    %s %-18s %-6s %3d  %s" % (k[0], k[1], k[2], len(by[k]), " ".join(sorted(by[k]))))
        print("RAKU_OPERATOR_PARSED (%d): %s"
              % (len(good), " ".join(sorted("%s:%s" % (r["cat"], r["sym"]) for r in good))))
    print("⛔ NOTHING WRITTEN: no SCORE row, no board, no progress append.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
