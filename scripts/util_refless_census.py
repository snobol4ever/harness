#!/usr/bin/env python3
"""util_refless_census.py -- EVERY BENCHMARK, DEMO, TEST AND GC WITNESS CARRYING NO REF, BY LANGUAGE, BY NAME.

Row instruments-the-refless-census-names-every-benchmark-and-test-carrying-no-ref-by-language
(coo, 2026-09-21, MODE TENET).

LON'S ORDER, verbatim to the ceo 2026-09-20: "Add a REF file for all benchmark and tests since how would you
know what you are measuring unless the output is correct." Landed as RULES.md FACT RULES clause 1.

⛔ THIS IS THE CENSUS AND NOT THE CUTTING. Each language's HQ cuts its own refs from its own oracle, because
only that oracle can say what the right answer is, and that obligation is already law. What did not exist is
the instrument that NAMES every refless program by language, so the fleet can tell progress from a narrowed
denominator. So a refless program is never a failure HERE: this instrument exits 0 whenever it could measure,
and the number it prints is the work outstanding, not a red. It REFUSES rc=2 when it can find no population,
because reporting zero refless programs for a tree it could not read is the one answer that would be a lie.

⛔ IT NAMES AND NEVER ONLY COUNTS (CEO-997 batch 30 clause 2 -- an instrument that aggregates must be able to
answer "name one member of this count"). Every count printed here is followed by its members; --check FAILS
if any nonzero count cannot produce one. A bare "168 refless" is the shape that let 62% of the benchmark tree
be timed without anyone knowing its output was correct.

⛔⭐ AND IT SPLITS REFLESS FROM OUTSIDE-THE-BASELINE, WHICH IS THE HALF THE ROW EXISTS FOR. Those two read
identically today -- a program with no expected output -- and only one of them is honest:
  * OUTSIDE-BASELINE: the program has NO ref AND the ONE oracle REFUSES it, so no ref CAN exist. It is
    named in an OUTSIDE tsv
    with the measurement that put it there, it is a statement about the ORACLE and never about us (RULES.md
    FACT RULE CEO-542), and per CEO-749 IT STAYS IN THE PUBLISHED DENOMINATOR.
  * REFLESS: nobody has cut the ref yet. It is simply ungraded, and it is work owed.
⛔ THE CLASSES ARE EXCLUSIVE AND HAS-REF WINS, WHICH IS A CHOICE AND IS STATED: a program may both carry a
ref and be listed OUTSIDE (three SNOBOL4 rungs entries are exactly that), and such a program is counted
HAS-REF here because this census measures REF DEBT, not denominator membership. So the OUTSIDE column reads
"refless, and explained" -- it is the part of the gap that is NOT work owed. Denominator membership is
SUITES.tsv's and the harness's business, and per CEO-749 an OUTSIDE entry stays in the published denominator
either way.

Counting an OUTSIDE program as refless overstates the debt and invites someone to "fix" a row that is about
the oracle; counting a refless program as OUTSIDE hides the debt and narrows the denominator silently. The
census therefore reads all ten OUTSIDE records in the corpus and reports the two populations separately.

⛔ THE OUTSIDE RECORDS USE TWO NAMING CONVENTIONS AND THAT IS MEASURED, NOT ASSUMED: OUTSIDE_SPITBOL_BASELINE
.tsv and OUTSIDE_ARIZONA_BASELINE.tsv under packages/ and benchmarks/, plus tests/snobol4/ALL.outside.tsv --
ten files on 2026-09-21. A census that knew only one convention would silently miss the other's population and
report those programs as refless debt. Both shapes are name<TAB>CLASS<TAB>reason with # comments.

⛔ THE RUNGS SUITES ARE NOT PER-FILE AND THE BANNER IS PER-LANGUAGE COMMENT SYNTAX, which is the trap in this
population. tests/<lang>/ALL.<ext> is a CONTAINER: a "program" is an ENTRY indexed in ALL.csv, and its ref is
a banner-delimited block in ALL.ref whose delimiter is that language's OWN comment syntax -- measured on
2026-09-21: icon/raku/rebus "#----", pascal "{----}", snocone "/*----*/", prolog "%----", snobol4 "*----".
A census hand-rolling one regex reads 826 of 826 for icon and ZERO for four other languages, which is exactly
what a first pass with grep produced. So the banner authority is IMPORTED from corpus_suite_harness.py
(banner_re_for + LANG_CONFIGS) and never re-derived here -- RULES.md: lib_* and the harness are sourced
authorities, source them, never copy. If that import fails this population REFUSES rather than guessing.
"""

import argparse
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
CORPUS = os.path.normpath(os.path.join(ROOT, "..", "corpus"))

# extension -> language. The frontend's own table (src/driver/scrip.c dispatches by these).
EXT_LANG = {
    ".sno": "snobol4", ".spt": "snobol4", ".sc": "snocone", ".icn": "icon",
    ".pl": "prolog", ".reb": "rebus", ".raku": "raku", ".pas": "pascal",
}
PROG_EXTS = tuple(EXT_LANG)


def tree_stamp(path):
    try:
        h = subprocess.run(["git", "-C", path, "rev-parse", "--short", "HEAD"],
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=20)
        t = h.stdout.decode().strip() or "unknown"
        d = subprocess.run(["git", "-C", path, "status", "--porcelain"],
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=20)
        return t + ("-dirty" if d.stdout.strip() else "")
    except Exception:
        return "unknown"


def load_outside():
    """Every OUTSIDE record in the corpus -> {bare name -> (file, class, reason)}.

    BOTH naming conventions, because there are two and a census that knows one under-reports the other's
    population as refless debt.

    ⛔ THE MATCH IS SCOPED TO THE RECORD'S OWN SUBTREE, not global by bare name. Ten records name 148
    programs, and bare names repeat across the corpus (benchmarks/prolog alone has boyer, browse, cal,
    chat_parser and crypt twice). A global name match would let a record about one tree silently excuse an
    identically-named program in another -- an OUTSIDE claim attached to a program no oracle ever refused,
    which is the dishonest half of the very split this census exists to draw.
    """
    out = {}   # (scope_dir, bare name) -> (file, class, reason)
    files = []
    if not os.path.isdir(CORPUS):
        return out, files
    for base, _dirs, names in os.walk(CORPUS):
        for n in names:
            low = n.lower()
            if "outside" not in low or not low.endswith((".tsv",)):
                continue
            p = os.path.join(base, n)
            files.append(os.path.relpath(p, CORPUS))
            try:
                with open(p, "r", encoding="utf-8", errors="replace") as fh:
                    for raw in fh:
                        s = raw.strip()
                        if not s or s.startswith("#"):
                            continue
                        parts = raw.rstrip("\n").split("\t")
                        name = parts[0].strip()
                        if not name:
                            continue
                        out.setdefault((os.path.relpath(base, CORPUS),
                                        os.path.splitext(os.path.basename(name))[0]),
                                       (os.path.relpath(p, CORPUS),
                                        parts[1].strip() if len(parts) > 1 else "",
                                        parts[2].strip() if len(parts) > 2 else ""))
            except OSError:
                continue
    return out, files


def file_population(rootdir, label):
    """Per-file populations: a program is a file, its ref is the sibling <stem>.ref."""
    rows = []
    if not os.path.isdir(rootdir):
        return rows
    for base, _dirs, names in os.walk(rootdir):
        for n in sorted(names):
            stem, ext = os.path.splitext(n)
            if ext not in EXT_LANG:
                continue
            p = os.path.join(base, n)
            has = os.path.exists(os.path.join(base, stem + ".ref"))
            rows.append({"pop": label, "lang": EXT_LANG[ext], "name": stem,
                         "path": os.path.relpath(p, ROOT if label == "gc_witnesses" else CORPUS),
                         "has_ref": has})
    return rows


def rungs_population():
    """Per-ENTRY population for the seven rungs suites, read THROUGH THE HARNESS'S OWN READER.

    ⛔⭐ THE PAIRING IS NOT RE-DERIVED HERE, AND THE FIRST DRAFT PROVED WHY. tests/<lang>/ALL.<ext> is a
    CONTAINER: an entry's ref is either a banner-delimited block (the banner being that language's OWN comment
    syntax -- icon/raku/rebus "#----", pascal "{----}", snocone "/*----*/", prolog "%----", snobol4 "*----")
    or, in the SNOBOL4 dialect, a positional one-line ref with NO marker of its own. SNOBOL4's ALL.ref is
    MIXED: 1162 block entries and 820 one-line entries interleaved in one file. A census that classifies a
    suite as "banner" the moment it finds any banner reads all 820 one-line entries as refless and reports
    817 REFLESS SNOBOL4 ENTRIES THAT ALL HAVE REFS -- a false debt larger than the real one, which is exactly
    the overstatement this row exists to prevent. read_suite()'s own docstring documents that ambiguity and
    resolves it by peeling trailing ref lines off a block's segment for each following one-line entry.

    SO THE DISPATCH IS THE HARNESS'S, COPIED IN SHAPE FROM corpus_suite_harness.py:1223 AND NOT INVENTED:
    a language present in LANG_CONFIGS is a format-(B)-only dialect and is read by read_block_suite() with
    its own banner regex; a language absent from it is the SNOBOL4 default dialect and is read by
    read_suite(). If a reader RAISES, that language REFUSES with the exception rather than reporting zero --
    read_suite() raises ValueError("family.ref is shorter than family.sno") on a pure-banner suite, and
    swallowing that would turn a wrong reader into a clean bill of health.
    """
    try:
        sys.path.insert(0, HERE)
        import corpus_suite_harness as H  # noqa: E402
    except Exception as e:  # noqa: BLE001
        return None, "cannot import the suite authority corpus_suite_harness.py: %s" % e

    tests = os.path.join(CORPUS, "tests")
    if not os.path.isdir(tests):
        return None, "no corpus/tests directory at %s" % tests
    rows, refused = [], []
    for lang in sorted(os.listdir(tests)):
        d = os.path.join(tests, lang)
        if not os.path.isfile(os.path.join(d, "ALL.csv")):
            continue
        lc = H.LANG_CONFIGS.get(lang)
        ext = lc["ext"] if lc else ".sno"
        src, ref = os.path.join(d, "ALL" + ext), os.path.join(d, "ALL.ref")
        if not (os.path.isfile(src) and os.path.isfile(ref)):
            refused.append("%s: no ALL%s / ALL.ref pair" % (lang, ext))
            continue
        try:
            if lc:
                entries = H.read_block_suite(src, ref,
                                             H.banner_re_for(lc["comment_open"], lc["comment_close"]))
                reader = "read_block_suite"
            else:
                entries = H.read_suite(src, ref)
                reader = "read_suite"
        except Exception as e:  # noqa: BLE001
            refused.append("%s: %s raised %s: %s"
                           % (lang, "read_block_suite" if lc else "read_suite", type(e).__name__, e))
            continue
        kinds = {}
        for en in entries:
            kinds[en.kind] = kinds.get(en.kind, 0) + 1
        for en in entries:
            rt = getattr(en, "ref_text_or_lines", None)
            if rt is None:
                rt = getattr(en, "ref", None)
            rows.append({"pop": "rungs:" + lang, "lang": lang, "name": en.name,
                         "path": "tests/%s/ALL%s#%s" % (lang, ext, en.seq),
                         "has_ref": bool(rt),
                         "shape": "%s line=%d block=%d" % (reader, kinds.get("line", 0),
                                                           kinds.get("block", 0))})
    return rows, ("; ".join(refused) if refused else None)


def main():
    ap = argparse.ArgumentParser(description="name every refless program by language")
    ap.add_argument("--check", action="store_true",
                    help="gate mode: verify the census can measure and that every count can NAME a member")
    ap.add_argument("--lang", default="", help="restrict to one language")
    ap.add_argument("--pop", default="", help="restrict to one population (benchmarks, demos, ...)")
    ap.add_argument("--limit", type=int, default=12, help="names printed per language (0 = all)")
    ap.add_argument("--tsv", default="", help="write the machine record here")
    args = ap.parse_args()

    ctree, stree = tree_stamp(CORPUS), tree_stamp(ROOT)
    outside, ofiles = load_outside()

    rows = []
    rows += file_population(os.path.join(CORPUS, "benchmarks"), "benchmarks")
    rows += file_population(os.path.join(CORPUS, "demos"), "demos")
    rows += file_population(os.path.join(HERE, "gc_witnesses"), "gc_witnesses")
    mrows, merr = rungs_population()
    rungs_refused = merr

    print("REFLESS CENSUS -- corpus %s · SCRIP %s -- every program carrying no ref, BY NAME" % (ctree, stree))
    print("  OUTSIDE records read: %d file(s), %d named program(s)" % (len(ofiles), len(outside)))
    for f in sorted(ofiles):
        print("      %s" % f)
    if rungs_refused:
        print("  ⛔ REFUSE: the rungs-suite population COULD NOT BE MEASURED -- %s" % rungs_refused)
        print("     It is NOT reported as zero: an unmeasured population printed as clean is the defect this")
        print("     census exists to prevent.")
    else:
        rows += mrows
    print("")

    if args.lang:
        rows = [r for r in rows if r["lang"] == args.lang]
    if args.pop:
        rows = [r for r in rows if r["pop"] == args.pop or r["pop"].startswith(args.pop)]

    if not rows:
        print("⛔ REFUSE(2): NO POPULATION FOUND. Nothing was measured, and reporting zero refless programs")
        print("   for a tree this instrument could not read would be the one answer that is a lie.")
        print("   corpus expected at %s" % CORPUS)
        return 2

    # classify: has_ref / OUTSIDE (named in an outside record) / REFLESS
    for r in rows:
        if r["has_ref"]:
            r["cls"] = "HAS-REF"
        else:
            hit = None
            d = os.path.dirname(r["path"])
            while True:
                if (d, r["name"]) in outside:
                    hit = outside[(d, r["name"])]
                    break
                nd = os.path.dirname(d)
                if nd == d or not d:
                    break
                d = nd
            if hit:
                r["cls"] = "OUTSIDE-BASELINE"
                r["why"] = hit
            else:
                r["cls"] = "REFLESS"
    for r in rows:
        if r.get("cls"):
            continue
        r["cls"] = "REFLESS"

    langs = sorted({r["lang"] for r in rows})
    pops = sorted({r["pop"] for r in rows})
    grand = {"HAS-REF": 0, "OUTSIDE-BASELINE": 0, "REFLESS": 0}
    named_ok = True

    for pop in pops:
        prows = [r for r in rows if r["pop"] == pop]
        shape = prows[0].get("shape")
        print("=== %s%s -- %d program(s) ===" % (pop, (" [%s pairing]" % shape) if shape else "", len(prows)))
        for lang in langs:
            lr = [r for r in prows if r["lang"] == lang]
            if not lr:
                continue
            # ⛔ NAME UNIQUELY OR THE NAMING REQUIREMENT IS NOT MET: bare stems repeat across directories
            # (boyer appears twice in benchmarks/prolog), and "boyer, boyer" names nothing an HQ can act on.
            seen_stems = {}
            for r in lr:
                seen_stems[r["name"]] = seen_stems.get(r["name"], 0) + 1
            def _label(r):
                return r["path"] if seen_stems.get(r["name"], 0) > 1 else r["name"]
            refless = sorted(_label(r) for r in lr if r["cls"] == "REFLESS")
            outs = sorted(_label(r) for r in lr if r["cls"] == "OUTSIDE-BASELINE")
            hr = sum(1 for r in lr if r["cls"] == "HAS-REF")
            grand["HAS-REF"] += hr
            grand["OUTSIDE-BASELINE"] += len(outs)
            grand["REFLESS"] += len(refless)
            print("  %-9s population=%-5d has_ref=%-5d OUTSIDE=%-4d REFLESS=%d"
                  % (lang, len(lr), hr, len(outs), len(refless)))
            # ⛔ every nonzero count NAMES a member, or this instrument is the thing it was built to replace
            if refless:
                show = refless if args.limit == 0 else refless[: args.limit]
                print("      REFLESS, owed a ref cut from %s's oracle by that HQ: %s%s"
                      % (lang, ", ".join(show),
                         "" if len(show) == len(refless) else "  ... and %d more (--limit 0 for all)"
                         % (len(refless) - len(show))))
            elif len([r for r in lr if r["cls"] == "REFLESS"]):
                named_ok = False
            if outs:
                show = outs if args.limit == 0 else outs[: args.limit]
                print("      OUTSIDE-BASELINE -- refless AND EXPLAINED, so NOT work owed: the ONE oracle")
                print("      refuses these, they STAY in the published")
                print("      denominator (CEO-749); a statement about the oracle, never about us (CEO-542): %s%s"
                      % (", ".join(show),
                         "" if len(show) == len(outs) else "  ... and %d more" % (len(outs) - len(show))))
        print("")

    total = sum(grand.values())
    print("IDENTITY: HAS-REF=%d + OUTSIDE-BASELINE=%d + REFLESS=%d = %d, population %d %s"
          % (grand["HAS-REF"], grand["OUTSIDE-BASELINE"], grand["REFLESS"], total, len(rows),
             "OK" if total == len(rows) else "⛔ MISMATCH"))
    print("REFLESS-CENSUS: corpus=%s scrip=%s population=%d has_ref=%d outside=%d refless=%d "
          "outside_records=%d rungs_population=%s"
          % (ctree, stree, len(rows), grand["HAS-REF"], grand["OUTSIDE-BASELINE"], grand["REFLESS"],
             len(ofiles), "REFUSED" if rungs_refused else "measured"))
    print("⛔ REFLESS IS WORK OWED AND NOT A RED HERE: this row is the census, not the cutting. Each language's")
    print("   HQ cuts its own refs from its own oracle, because only that oracle can say what the right answer")
    print("   is. What this instrument forbids is a NARROWED DENOMINATOR passing as progress.")

    if args.tsv:
        with open(args.tsv, "w", encoding="utf-8") as fh:
            fh.write("# util_refless_census.py corpus=%s scrip=%s\n" % (ctree, stree))
            fh.write("population\tlanguage\tname\tclass\tpath\n")
            for r in sorted(rows, key=lambda x: (x["pop"], x["lang"], x["name"])):
                fh.write("%s\t%s\t%s\t%s\t%s\n" % (r["pop"], r["lang"], r["name"], r["cls"], r["path"]))

    if total != len(rows):
        print("⛔ REFUSE(2): the identity does not close, so this census is not trustworthy")
        return 2

    if args.check:
        bad = 0
        if not named_ok:
            print("⛔ CHECK FAILED: a nonzero REFLESS count could not name a member")
            bad += 1
        if len(ofiles) == 0:
            print("⛔ CHECK REFUSED(2): no OUTSIDE record was found anywhere in the corpus. The refless/OUTSIDE")
            print("   split is this census's whole point, and with no records read every OUTSIDE program would")
            print("   be reported as refless debt.")
            return 2
        if rungs_refused:
            print("⛔ CHECK REFUSED(2): the rungs population could not be measured, named above")
            return 2
        for pop in pops:
            if not [r for r in rows if r["pop"] == pop]:
                print("⛔ CHECK FAILED: population %s is empty" % pop)
                bad += 1
        if bad:
            return 1
        print("✅ CHECK: %d population(s) measured, identity closes, %d OUTSIDE record(s) read, and every"
              % (len(pops), len(ofiles)))
        print("   nonzero count names its members.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
