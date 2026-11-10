#!/usr/bin/env python3
"""util_tests_layout_census.py -- WHAT SITS UNDER corpus/tests/ BESIDE THE CONTAINERS, AND WHY (the cio 2026-11-10, CIO-24, on Lon's words in the
cio's window, verbatim: "I suspect the $/corpus/tests folder should contain one folder per language with the name of the language." / "What's
confusing is the ONE-LINER and MULTI-LINER programs are not grouped into the one file. Why are these folders not organized properly. Get to work.").

THE LAW it reads against is Lon's of 2026-08-29/30 (corpus 11a36c87f): a language's folder is FLAT, its container files side by side (ALL.<ext>,
ALL.ref, ALL.csv and the other ALL.* sidecars, PARTITION.tsv, and EXCLUDED.tsv, the declaration of what is out of the denominator), ONE config/ folder, and every program absorbed into the container.

usage: util_tests_layout_census.py [--root S4E_HOME] [--lang L] [--list] [--check]
For each language folder, every tracked file that is neither the container nor under config/, classed:
  PAIR-ORPHAN      a program with its .ref beside it whose name ALL.csv and ALL.excluded.txt never mention: no cell grades it (absorb it)
  PAIR-IN-TABLE    a program with its .ref whose name ALL.csv mentions: absorbed already, the loose copy is a duplicate (compare, then delete)
  PAIR-EXCLUDED    a program with its .ref that ALL.excluded.txt names: left out of the container by a reason and kept loose
  PROGRAM-NO-REF   a program with no .ref beside it (a parser fixture, a module another program loads, a sample): no run grades it
  SIDECAR          a .ref .in .heap .stack .argv .env or the like beside a loose program
  TABLE DOC OTHER  a step table or census (.tsv .csv), a document (.md .txt), anything else
and, for the folder as a whole, SUBFOLDERS (every directory but config/). Then the entries of corpus/tests/ that are not a language folder.
--list prints one line per file (class, path); --check: rc 0 when no selected language holds a file outside the container and config/ and, with no
--lang, corpus/tests/ holds nothing but the language folders; rc 1 otherwise; rc 2 refused. It reads; it writes nothing and runs no program."""
import collections, os, subprocess, sys

EXT = {"snobol4": "sno", "icon": "icn", "prolog": "pl", "pascal": "pas", "raku": "raku", "rebus": "reb", "snocone": "sc"}
PROG = {"sno", "icn", "pl", "pas", "raku", "reb", "sc", "spt", "inc", "t", "lgt", "P", "scrip", "pp", "p"}
SIDE = {"ref", "in", "input", "heap", "stack", "argv", "env", "wantrc", "mask", "timeout", "cmdline", "ast-only", "ast", "out", "expected", "xfail",
        "stdin", "outfiles", "dat"}
ORDER = ("PAIR-ORPHAN", "PAIR-IN-TABLE", "PAIR-EXCLUDED", "PROGRAM-NO-REF", "SIDECAR", "TABLE", "DOC", "OTHER")


def opt(a, name):
    return a[a.index(name) + 1] if name in a and a.index(name) + 1 < len(a) else None


def main():
    a = sys.argv[1:]
    root = opt(a, "--root") or os.environ.get("S4E_HOME") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    corpus = os.path.join(root, "corpus")
    tests = os.path.join(corpus, "tests")
    only = opt(a, "--lang")
    if not os.path.isdir(tests) or (only and only not in EXT):
        print("REFUSE(2) [tests-layout]: no %s, or --lang is not one of %s" % (tests, " ".join(EXT)))
        return 2
    tracked = subprocess.run(["git", "-C", corpus, "ls-files", "--", "tests"], capture_output=True, text=True).stdout.split("\n")
    tracked = [f[len("tests/"):] for f in tracked if f]
    bad = 0
    total = collections.Counter()
    print("TESTS-LAYOUT root=%s" % root)
    print("%-9s %7s %6s  %s  %s" % ("lang", "tracked", "loose", "  ".join("%s" % c for c in ORDER), "subfolders"))
    for lang, e in EXT.items():
        if only and lang != only:
            continue
        files = [f[len(lang) + 1:] for f in tracked if f.startswith(lang + "/")]
        fs = set(files)
        d = os.path.join(tests, lang)
        blob = {}
        for n in ("ALL.csv", "ALL.excluded.txt"):
            p = os.path.join(d, n)
            blob[n] = open(p, encoding="utf-8", errors="replace").read() if os.path.isfile(p) else ""
        cls = collections.Counter()
        subs = collections.Counter()
        rows = []
        for rel in files:
            top = rel.split("/", 1)[0] if "/" in rel else "."
            b = os.path.basename(rel)
            if top == "config" or (top == "." and (b.startswith("ALL.") or b in ("PARTITION.tsv", "EXCLUDED.tsv"))):
                continue
            if top != ".":
                subs[top] += 1
            ext = b.rsplit(".", 1)[-1] if "." in b else ""
            stem = b.rsplit(".", 1)[0]
            if ext in PROG:
                if (rel.rsplit(".", 1)[0] + ".ref") in fs:
                    c = "PAIR-IN-TABLE" if stem in blob["ALL.csv"] else ("PAIR-EXCLUDED" if stem in blob["ALL.excluded.txt"] else "PAIR-ORPHAN")
                else:
                    c = "PROGRAM-NO-REF"
            elif ext in SIDE:
                c = "SIDECAR"
            elif ext in ("tsv", "csv"):
                c = "TABLE"
            elif ext in ("md", "txt"):
                c = "DOC"
            else:
                c = "OTHER"
            cls[c] += 1
            rows.append((c, rel))
        loose = sum(cls.values())
        bad += 1 if loose else 0
        total.update(cls)
        print("%-9s %7d %6d  %s  %d%s" % (lang, len(files), loose, "  ".join("%*d" % (len(c), cls[c]) for c in ORDER), len(subs),
                                           (" (" + " ".join("%s:%d" % kv for kv in sorted(subs.items())) + ")") if subs else ""))
        if "--list" in a:
            for c, rel in sorted(rows):
                print("    %s\t%s/%s" % (c, lang, rel))
    strangers = collections.Counter()
    if not only:
        for f in tracked:
            top = f.split("/", 1)[0]
            if top not in EXT:
                strangers[top + ("/" if "/" in f else "")] += 1
        print("%-9s %7s %6d  %s" % ("ALL", "", sum(total.values()), "  ".join("%*d" % (len(c), total[c]) for c in ORDER)))
        print("NOT-A-LANGUAGE under corpus/tests/: %s" % (" ".join("%s(%d)" % kv for kv in sorted(strangers.items())) or "none"))
        bad += 1 if strangers else 0
    print("TESTS-LAYOUT not_ok=%d" % bad)
    return 1 if ("--check" in a and bad) else 0


sys.exit(main())
