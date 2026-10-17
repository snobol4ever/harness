#!/usr/bin/env python3
"""util_ladder_forms_check.py -- every DECLARED form and pair has a WITNESS.

Lon 2026-09-04, in-chat to ceo, verbatim: "Make tasks to ensure a complete test ladder covering every feature in
isolation with variations and then combinations of features." A rung stopped being one witness and became a
FAMILY: one tiny witness per FORM the reference lists for that construct, then PAIRS combining it with the rungs
below. This is the instrument that says whether a language's ladder actually has them, and it is the blocking
row -- every per-language ladder DONE-WHEN refuses rc=2 until it can call this.

THE CENSUS SCHEMA (ceo, this row): RUNG CONSTRUCT REFERENCE FORMS PAIRS WITNESS_ORIGIN STATUS NOTE, in
corpus/tests/<lang>/config/LADDER.tsv. FORMS and PAIRS are slugs separated by '|', ';' or ',' -- the live
censuses use '|' and the ratified schema line names only the columns. A form's witness is any origin
in that language's ALL.csv matching ladder__<rung>_*_<form>; a pair's is ladder__<rung>_*_with_<lower>.

⛔⭐ IT BINDS COLUMNS BY NAME, NEVER BY POSITION, AND THE FOUR LIVE CENSUSES ARE WHY. Measured 2026-09-04 before
a line of this was written: pascal declares `RUNG CONSTRUCT ISO_7185_SECTION WITNESS STATUS`, icon and snobol4
declare `RUNG CONSTRUCT WITNESS_ORIGIN STATUS NOTE`, and rebus has NO HEADER LINE AT ALL -- four files, four
shapes, one nominal schema. Any index-based reader would have silently read pascal's ISO section as its
WITNESS_ORIGIN and reported a confident wrong answer. This is the same position-over-shape defect that cost
util_score_row.py a fleet-wide refusal and util_apply_score_grid.py a two-table splice, both cured today; the
third time it is written down as a rule rather than as a scar.

⛔⭐⭐ A CENSUS WITHOUT A FORMS COLUMN IS `NOT-IN-SCHEMA`, WHICH IS NEITHER PASS NOR FAIL. This is the whole
design risk of this checker and the reason it is stated before the code. Every ladder census on disk today
predates the amendment, so a checker that simply looked for missing witnesses would find NO declared forms, and
"zero declared, zero missing" reads as GREEN -- a vacuous pass over the exact gap the row exists to close, on
all seven languages at once, on the day it landed. Vacuity is the failure mode here, not strictness. So: zero
graded forms is a REFUSAL (rc=2), never a pass, and a census still on the old schema is reported by name as
owed work rather than counted as satisfied.

EXIT: 0 every declared form (and, under --phase all, every declared pair) has a witness; 1 something declared
has none; 2 REFUSED -- cannot measure (no census, no header, nothing graded).
"""
import os
import sys, os, re, csv, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
# ⛔⭐ S4E_HOME IS THE ROOT (/home/claude_T), NOT THE SCRIP DIRECTORY, AND GETTING THAT BACKWARDS IS INVISIBLE
# FROM AN INTERACTIVE SHELL. This first read `dirname(HERE)` (= SCRIP) and then took dirname AGAIN for corpus.
# With S4E_HOME UNSET both hops happen and the path is right, which is every run I made by hand. With
# S4E_HOME SET -- which is exactly what this row's own DONE-WHEN does -- the first hop is skipped, corpus
# resolves to /home/corpus, and ALL SEVEN languages report REFUSED "no census". ⭐ The bug therefore appeared
# only under the criterion, never under the author, and the DONE-WHEN caught it: a green shell run and a red
# gate disagreeing is the gate doing its job, not noise to route around. Convention copied from
# util_score_row.py:38 and lib_gate.sh:51 rather than re-derived -- they are the authority on this variable.
S4E = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(HERE, "..", "..", "SCRIP", ".."))
CORPUS = os.path.join(S4E, "corpus")
LANGS = ["snobol4", "icon", "prolog", "raku", "pascal", "snocone", "rebus"]
EXT = {"snobol4": ".sno", "icon": ".icn", "prolog": ".pl", "raku": ".raku",
       "pascal": ".pas", "snocone": ".sc", "rebus": ".reb"}
REQUIRED = ("RUNG", "CONSTRUCT")


def die(msg, rc=2):
    sys.stderr.write("REFUSED(%d) util_ladder_forms_check: %s\n" % (rc, msg))
    raise SystemExit(rc)


def census_path(lang):
    return os.path.join(CORPUS, "tests", lang, "config", "LADDER.tsv")


def read_census(lang, path=None):
    # Returns (rows, header_map, why) -- rows is a list of dicts keyed by UPPERCASED column name. `why` is a
    # refusal reason when the file cannot be read as a census at all, and rows is then empty.
    p = path or census_path(lang)
    if not os.path.exists(p):
        return [], {}, "no census at %s" % p
    lines = []
    for lineno, raw in enumerate(open(p, encoding="utf-8"), start=1):
        s = raw.rstrip("\n")
        if not s.strip() or s.lstrip().startswith("#"):
            continue
        lines.append((lineno, s))
    if not lines:
        return [], {}, "census %s has no data lines" % p
    # ⛔ THE HEADER IS THE ONE WHOSE FIRST FIELD IS LITERALLY `RUNG`. rebus's census opens straight into data
    # (`rung00<TAB>hello<TAB>...`), so "first line is the header" would consume a real rung as column names and
    # then report one fewer rung than exists -- an off-by-one that looks like a census, not like an error.
    hdr = None
    for i, (lineno, l) in enumerate(lines):
        if l.split("\t")[0].strip().upper() == "RUNG":
            hdr = i
            break
    if hdr is None:
        return [], {}, ("census %s has NO HEADER LINE (no row whose first field is RUNG) -- it cannot be read "
                        "by name, and reading it by position is what this checker refuses to do" % p)
    names = [c.strip().upper() for c in lines[hdr][1].split("\t")]
    missing = [c for c in REQUIRED if c not in names]
    if missing:
        return [], {}, "census %s header lacks %s (has: %s)" % (p, ", ".join(missing), ", ".join(names))
    cmap = {n: i for i, n in enumerate(names)}
    rows = []
    for lineno, l in lines[hdr + 1:]:
        f = l.split("\t")
        if not f or not f[0].strip():
            continue
        # ⛔ A ROW WITH THE WRONG FIELD COUNT REFUSES, NEVER GETS GRADED ON THE FIELDS IT HAPPENED TO HAVE.
        # A cell holding a literal newline splits ONE logical row into several physical lines (the fragments
        # carry too few fields); a stray extra tab carries too many. Either way, silently zero-padding or
        # truncating answers a narrower question than the one asked and cannot say so on its own
        # (FINDING-2026-09-06-seat08-ladder-tsv-embedded-newlines-broke-the-forms-check-for-every-row-after.md).
        if len(f) != len(names):
            return [], {}, ("census %s line %d has %d field(s), expected %d (header: %s) -- refusing rather "
                            "than grading a row on the fields it happened to have"
                            % (p, lineno, len(f), len(names), ", ".join(names)))
        rows.append({n: f[i].strip() for n, i in cmap.items()})
    return rows, cmap, None


def origins_of(lang):
    # The witness population is the language's own ALL.csv `origin` column, read BY NAME for the same reason
    # the census is. Returns a set, or None when the suite index is absent.
    p = os.path.join(CORPUS, "tests", lang, "ALL.csv")
    if not os.path.exists(p):
        return None
    out = set()
    with open(p, encoding="utf-8", newline="") as fh:
        for rec in csv.DictReader(fh):
            o = (rec.get("origin") or "").strip()
            if o:
                out.add(o)
    return out


def slugs(cell):
    # ⛔⭐ `|` IS THE LIVE SEPARATOR AND SPLITTING ONLY ON `;,` PRODUCED A PLAUSIBLE WRONG ANSWER. Measured on
    # the first census written to the amended schema (prolog, hq_C corpus e351e9a4c): forms are pipe-joined
    # (`collect_all|empty_result|template_is_compound|...`), so this returned ONE form whose name was the whole
    # joined string, reported it as missing, and printed "36 declared slot(s) have no witness" -- a number that
    # is wrong in BOTH directions at once (36 rungs' worth of forms collapsed to 36 slots) while looking
    # exactly like a real measurement. ⭐ The schema line ceo ratified names the COLUMNS, not the separator;
    # accepting all three is the only reading that cannot be wrong about a census someone else writes.
    return [s.strip() for s in re.split(r"[;,|]", cell or "") if s.strip()]


def witness_for(origins, rung, form, pair=False):
    # ladder__<rung>_<anything>_<form>, or ..._with_<lower> for a pair. The construct segment is deliberately
    # not pinned: the four live censuses spell it four ways and the FORM is the thing being proved present.
    # ⛔ FIXED 2026-09-04 (seat12, row raku-ladder-every-feature-in-isolation-with-variations): the mandatory
    # UNDERSCORE after the rung number must not itself be optional-with-\b, but the OLD pattern's
    # `(?:_|\b).*_<form>$` required a SECOND underscore before the form no matter what -- so a construct
    # bundled into ITS OWN name with no separate form suffix (ladder__rung00_hello, form "hello"; Prolog's
    # ladder__rung01_fact_rule, form "fact_rule") could never match, since after consuming the one real "_"
    # there was nothing left for the required "_<form>" to consume. \b never rescues this: "_" counts as a
    # word character in \w, so digit-to-"_" is not a boundary either -- the alternation's \b branch was
    # already dead weight, not a working fallback. Verified false-negative on both this row's and prolog's
    # real censuses before this fix (see this row's LEDGER). The mandatory "_" still anchors the rung
    # boundary (unchanged: prevents rung1 matching inside rung10/11/.../19's origins); what changed is that
    # everything between that "_" and the form is now OPTIONAL (`(?:.*_)?`), not required.
    rn = re.sub(r"^rung0*", "", rung, flags=re.I) or "0"
    pat = re.compile(r"^ladder__rung0*%s_(?:.*_)?%s%s$"
                     % (re.escape(rn), "with_" if pair else "", re.escape(form)), re.I)
    return sorted(o for o in origins if pat.match(o))


def check_lang(lang, phase, path=None, verbose=True):
    # Returns (status, declared, witnessed, missing) where status is one of OK / MISSING / NOT-IN-SCHEMA /
    # REFUSED. NOT-IN-SCHEMA is a first-class outcome, never folded into OK -- see the banner.
    rows, cmap, why = read_census(lang, path)
    if why:
        if verbose:
            print("  %-8s REFUSED  %s" % (lang, why))
        return "REFUSED", 0, 0, []
    origins = origins_of(lang)
    if origins is None:
        if verbose:
            print("  %-8s REFUSED  no ALL.csv -- there is no witness population to check declarations against" % lang)
        return "REFUSED", 0, 0, []
    has_forms = "FORMS" in cmap
    has_pairs = "PAIRS" in cmap
    if not has_forms:
        if verbose:
            print("  %-8s NOT-IN-SCHEMA  census has no FORMS column (%d rungs declared, old schema) -- "
                  "owed: amend to RUNG CONSTRUCT REFERENCE FORMS PAIRS WITNESS_ORIGIN STATUS NOTE" % (lang, len(rows)))
        return "NOT-IN-SCHEMA", 0, 0, []
    declared = witnessed = 0
    missing = []
    # ⛔⭐⭐ A CENSUS ENUMERATED FROM THE IMPLEMENTATION CANNOT NAME A GAP (ceo ruling on Lon's "Is Icon really
    # at 90%? I do not believe it", 2026-09-04; the class hq_C first named for Prolog). If the FORMS were read
    # off what the compiler already does, every form has a witness BY CONSTRUCTION and the row reads 199/199
    # while proving nothing about the language standard. Measured on the live tree the hour this landed: icon
    # is 46 of 46 rows `oracle-observed`, ZERO from-standard, while prolog/raku/pascal/snocone/rebus cite a
    # standard on every row -- so this is one census, not a general rot.
    # ⭐ WHOEVER WROTE THE ICON CENSUS LABELLED IT HONESTLY. The cells say `oracle-observed:` in their own
    # words; nothing was hidden. The defect is that the CHECKER credited them anyway, which is the instrument's
    # fault and not the author's -- an honest label nobody reads is the same as no label.
    # A row like that is NOT-FROM-THE-STANDARD: its forms still count in the DENOMINATOR (they are declared)
    # but are never credited as witnessed, so the language reads what it has actually earned against the book.
    not_std, notstd_forms = [], []
    if "REFERENCE" in cmap:
        for r in rows:
            ref = (r.get("REFERENCE") or "").strip()
            if not ref or re.match(r"(?i)\s*(oracle-observed|implementation-observed|observed)\b", ref):
                not_std.append(r.get("RUNG", "?"))
    # ⛔⭐ A RUNG WITH AN EMPTY FORMS CELL IS OWED, NOT ZERO. Found by converting the first census by hand:
    # a file that declares forms for rung00 and leaves the other ten blank counted only what it declared,
    # witnessed all of it, and read OK -- so a census could go green having enumerated one rung out of
    # twelve. That is the vacuity guard's own hole, one level down from the NOT-IN-SCHEMA case: the top
    # level asks "does this file use the schema", and it never asked "does every rung actually use it".
    undeclared = [r.get("RUNG", "?") for r in rows if not slugs(r.get("FORMS", ""))]
    for r in rows:
        rung = r.get("RUNG", "")
        rung_not_std = rung in not_std
        for form in slugs(r.get("FORMS", "")):
            declared += 1
            if rung_not_std:
                notstd_forms.append("%s/%s form %s -- REFERENCE is not the standard, so this form is OWED "
                                    "however many witnesses it has" % (lang, rung, form))
            elif witness_for(origins, rung, form):
                witnessed += 1
            else:
                missing.append("%s/%s form %s" % (lang, rung, form))
        if phase == "all" and has_pairs:
            for low in slugs(r.get("PAIRS", "")):
                declared += 1
                if witness_for(origins, rung, low, pair=True):
                    witnessed += 1
                else:
                    missing.append("%s/%s pair with_%s" % (lang, rung, low))
    if declared == 0:
        if verbose:
            print("  %-8s REFUSED  FORMS column present but EMPTY on every rung -- nothing to grade, and "
                  "'zero declared, zero missing' must never read as green" % lang)
        return "REFUSED", 0, 0, []
    # ⛔ THE TWO SHORTFALLS ARE COUNTED SEPARATELY BECAUSE THEY ARE DIFFERENT WORK. A declared form with no
    # witness needs a witness minted; a rung with an empty FORMS cell needs somebody to READ THE REFERENCE
    # first. Reporting them as one number ("13/13 witnessed (10 without a witness)") reads as a
    # contradiction and hides which of the two jobs is owed.
    nowit = len(missing)
    # ⛔ THREE DISTINCT SHORTFALLS, THREE DISTINCT JOBS, so they are never summed into one number: a declared
    # form with NO WITNESS needs a witness minted; a rung with an EMPTY FORMS cell needs the reference read;
    # a form whose REFERENCE IS NOT THE STANDARD needs the census RE-DERIVED from the book. Reporting icon's
    # as "199 declared forms with NO witness" was actively false -- they all have witnesses, and saying so
    # would send someone to mint 199 witnesses that already exist.
    missing += notstd_forms
    if undeclared:
        missing += ["%s/%s FORMS cell is empty -- no form enumerated from the reference" % (lang, r) for r in undeclared]
    if verbose:
        short = []
        if nowit:
            short.append("%d declared form(s) with NO witness" % nowit)
        if notstd_forms:
            short.append("%d form(s) NOT-FROM-THE-STANDARD (REFERENCE is oracle-observed) -- census must be "
                         "re-derived from the book, the witnesses exist" % len(notstd_forms))
        if undeclared:
            short.append("%d rung(s) with NO forms declared" % len(undeclared))
        print("  %-8s %-8s %d/%d declared %s witnessed%s" % (
            lang, "OK" if not missing else "MISSING", witnessed, declared,
            "form" + ("s" if declared != 1 else "") + ("+pairs" if phase == "all" and has_pairs else ""),
            "" if not short else "  -- " + "; ".join(short)))
    return ("OK" if not missing else "MISSING"), declared, witnessed, missing


def selftest():
    # ⛔ THE ARM THAT MATTERS IS THE VACUITY ARM. A checker that reports GREEN for a census declaring nothing
    # would pass all seven languages on the day this landed and close the row while proving nothing.
    import tempfile, shutil
    ok = True
    d = tempfile.mkdtemp(prefix="ladder_forms.selftest.")
    global CORPUS
    real = CORPUS
    try:
        CORPUS = d
        def mk(lang, census, origins):
            cd = os.path.join(d, "tests", lang, "config")
            os.makedirs(cd, exist_ok=True)
            open(os.path.join(cd, "LADDER.tsv"), "w", encoding="utf-8").write(census)
            with open(os.path.join(d, "tests", lang, "ALL.csv"), "w", encoding="utf-8", newline="") as fh:
                w = csv.writer(fh, lineterminator="\n")   # ⛔ OUR FILES ARE LF (RULES.md); csv defaults to CRLF.
                w.writerow(["rank", "entry", "origin", "family"])
                for o in origins:
                    w.writerow(["1", o, o, "ladder"])
        HDR = "RUNG\tCONSTRUCT\tREFERENCE\tFORMS\tPAIRS\tWITNESS_ORIGIN\tSTATUS\tNOTE\n"
        cases = []
        # 1. every declared form witnessed -> OK
        mk("aaa", HDR + "rung00\thello\tsec1\tbare;quoted\t\t-\tBUILT\t\n",
           ["ladder__rung00_hello_bare", "ladder__rung00_hello_quoted"])
        cases.append(("every declared form has a witness", "aaa", "isolation", "OK"))
        # 2. one form with no witness -> MISSING
        mk("bbb", HDR + "rung00\thello\tsec1\tbare;quoted\t\t-\tBUILT\t\n", ["ladder__rung00_hello_bare"])
        cases.append(("a declared form with no witness is caught", "bbb", "isolation", "MISSING"))
        # 3. FORMS column present but empty -> REFUSED, never OK
        mk("ccc", HDR + "rung00\thello\tsec1\t\t\t-\tBUILT\t\n", ["ladder__rung00_hello"])
        cases.append(("an EMPTY forms column REFUSES rather than reading green", "ccc", "isolation", "REFUSED"))
        # 4. old schema (no FORMS column) -> NOT-IN-SCHEMA, never OK
        mk("ddd", "RUNG\tCONSTRUCT\tWITNESS_ORIGIN\tSTATUS\tNOTE\nrung00\thello\tladder__rung00_hello\tBUILT\t\n",
           ["ladder__rung00_hello"])
        cases.append(("an old-schema census is NOT-IN-SCHEMA, not a vacuous pass", "ddd", "isolation", "NOT-IN-SCHEMA"))
        # 5. headerless census (rebus's live shape) -> REFUSED
        mk("eee", "rung00\thello\tprogram + OUTPUT\tBUILT\n", ["ladder__rung00_hello"])
        cases.append(("a headerless census REFUSES instead of eating a rung as its header", "eee", "isolation", "REFUSED"))
        # 6. pairs are graded only under --phase all
        mk("fff", HDR + "rung01\tarith\tsec2\tadd\thello\t-\tBUILT\t\n", ["ladder__rung01_arith_add"])
        cases.append(("a missing PAIR is invisible under --phase isolation", "fff", "isolation", "OK"))
        cases.append(("the same missing PAIR is caught under --phase all", "fff", "all", "MISSING"))
        # 7. pipe-separated forms -- the live prolog spelling; splitting only on ;, made one form of the lot
        mk("ggg", HDR + "rung00\thello\tsec1\tbare|quoted|nl\t\t-\tBUILT\t\n",
           ["ladder__rung00_hello_bare", "ladder__rung00_hello_quoted", "ladder__rung00_hello_nl"])
        cases.append(("PIPE-separated forms split into one form each", "ggg", "isolation", "OK"))
        mk("hhh", HDR + "rung00\thello\tsec1\tbare|quoted|nl\t\t-\tBUILT\t\n",
           ["ladder__rung00_hello_bare", "ladder__rung00_hello_quoted"])
        cases.append(("a missing form inside a PIPE list is caught individually", "hhh", "isolation", "MISSING"))
        # 8. a census that enumerates ONE rung and leaves the rest blank must not read OK
        mk("iii", HDR + "rung00\thello\tsec1\tbare\t\t-\tBUILT\t\nrung01\tarith\tsec2\t\t\t-\tBUILT\t\n",
           ["ladder__rung00_hello_bare"])
        cases.append(("a rung with an EMPTY forms cell is owed, not silently zero", "iii", "isolation", "MISSING"))
        # 9. a census enumerated from the IMPLEMENTATION cannot name a gap -- witnesses present, still owed
        mk("jjj", HDR + "rung00\thello\toracle-observed: what the compiler already prints\tbare|quoted\t\t-\tBUILT\t\n",
           ["ladder__rung00_hello_bare", "ladder__rung00_hello_quoted"])
        cases.append(("an oracle-observed REFERENCE is OWED even with every witness present",
                      "jjj", "isolation", "MISSING"))
        mk("kkk", HDR + "rung00\thello\tISO 1234 sec 5.1\tbare|quoted\t\t-\tBUILT\t\n",
           ["ladder__rung00_hello_bare", "ladder__rung00_hello_quoted"])
        cases.append(("the SAME rows with a real standard citation read OK", "kkk", "isolation", "OK"))
        # 10. a data row with the WRONG FIELD COUNT -- the embedded-literal-newline defect shape
        # (FINDING-2026-09-06-seat08-ladder-tsv-embedded-newlines-broke-the-forms-check-for-every-row-after.md):
        # a cell containing a literal "\n" splits ONE logical row into several physical lines, and the fragment
        # lines carry fewer tab-separated fields than the header declares. Reading N fields out of an M-field
        # row must REFUSE, never grade the row on the fields it happened to have.
        mk("lll", HDR + "rung00\thello\tsec1\tbare|quoted\t\t-\tBUILT\t\nrung01\ttruncated fragment\n",
           ["ladder__rung00_hello_bare", "ladder__rung00_hello_quoted"])
        cases.append(("a data row with the wrong field count REFUSES instead of grading a fragment",
                      "lll", "isolation", "REFUSED"))
        for label, lang, phase, want in cases:
            got, _d, _w, _m = check_lang(lang, phase, verbose=False)
            if got == want:
                print("SELFTEST: %s" % label)
            else:
                print("SELFTEST FAIL: %s -- got %s, wanted %s" % (label, got, want)); ok = False
    finally:
        CORPUS = real
        shutil.rmtree(d, ignore_errors=True)
    print("SELFTEST %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--lang")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--phase", choices=("isolation", "all"), default="isolation")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if a.lang and a.all:
        die("--lang and --all name two different populations -- pass one, never both")
    langs = [a.lang] if a.lang else LANGS
    if a.lang and a.lang not in LANGS:
        die("unknown language %r. Known: %s" % (a.lang, ", ".join(LANGS)))
    print("ladder FORMS/PAIRS check -- phase=%s, %d language(s), corpus %s" % (a.phase, len(langs), CORPUS))
    tot_d = tot_w = 0
    allmissing, statuses = [], {}
    for l in langs:
        st, d, w, m = check_lang(l, a.phase)
        statuses[l] = st
        tot_d += d
        tot_w += w
        allmissing += m
    print("  ---")
    print("  DENOMINATOR: %d declared form/pair slot(s) across %d language(s); %d witnessed, %d without a witness"
          % (tot_d, len(langs), tot_w, len(allmissing)))
    for st in ("OK", "MISSING", "NOT-IN-SCHEMA", "REFUSED"):
        named = [l for l in langs if statuses.get(l) == st]
        if named:
            print("  %-14s %s" % (st + ":", " ".join(named)))
    if allmissing:
        # ⛔ A COUNT WITHOUT NAMES CANNOT BE TRIAGED (RULES sec THE INSTRUMENT LAWS, batch 14 -- the same
        # 40-line cap measured on corpus_suite_harness.py, where two rung-2 defects hid behind 170 SKIPs).
        # This listing had the identical cap and no way to lift it: the one flag a reader would reach for,
        # could not be lifted at all: 131 slots, 40 named, and the walker could not see the rung it stands on.
        # LADDER_LIST_ALL=1 names every slot, spelled after the harness's own SUITE_LIST_ALL=1 rather than as a
        # new flag -- --all here already means all LANGUAGES, and the two would have read as one.
        # hq_P 2026-09-09: LADDER_LIST_ALL=0 read as TRUE here -- os.environ.get returns the STRING "0",
        # which is truthy, so the one spelling a reader uses to turn a flag OFF turned it ON.
        show_all = os.environ.get("LADDER_LIST_ALL", "") not in ("", "0")
        shown = allmissing if show_all else allmissing[:40]
        for m in shown:
            print("    no witness: %s" % m)
        if len(shown) < len(allmissing):
            print("    ... and %d more -- re-run with LADDER_LIST_ALL=1 to name every slot."
                  % (len(allmissing) - len(shown)))
            print("    ⛔ A CALLER THAT GRADES ON THESE LINES MUST SET IT, or it counts this WINDOW and not")
            print("       the census: a DONE-WHEN grepping `no witness:` read 20 for rungs 24-33 when the")
            print("       true figure was 109, and its count MOVED when another seat cured a LOWER rung.")
    # ⛔ NOTHING GRADED IS A REFUSAL. Today every census is still on the old schema, so this is the expected
    # answer for a while -- and it is the honest one. A checker that printed GREEN here would have closed the
    # row it exists to open.
    if tot_d == 0:
        die("graded ZERO declared forms across %s -- no census carries a populated FORMS column yet, so this "
            "run measured nothing. That is owed work, not a pass." % ", ".join(langs))
    print("VERDICT: %s" % ("PASS -- every declared form%s has a witness" % ("/pair" if a.phase == "all" else "")
                           if not allmissing else "FAIL -- %d declared slot(s) have no witness" % len(allmissing)))
    return 1 if allmissing else 0


if __name__ == "__main__":
    raise SystemExit(main())
