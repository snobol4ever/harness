#!/usr/bin/env python3
"""THE SIDECAR CENSUS -- which rungs entries owe an input file or a program-arguments declaration.

Lon 2026-09-08, in-chat to hq_T, verbatim: "Ensure all has sister (side cars) files for the ONE-LINERS
and MULTI-LINERS such that they have command-line args and an input file for each test along with the
ref and source files."

⛔⭐ WHY A CENSUS AND NOT A GUESS. An entry that reads stdin and is graded with /dev/null does not error:
it takes EOF, produces some shorter output, and its .ref was minted from THAT run -- so it passes forever
while testing nothing the author wrote. That is not hypothetical and it is not rare: corpus 6c94504c0
cured exactly one such entry (icon 831, whose companion sat in tests/icon/config/ where the finder did not
look until SCRIP bc9812abe), and the Icon rungs fell from a false 704/704 to an honest 703/704 the moment
it was fed. This tool finds the rest of that class BEFORE a ref is minted over it.
⭐ THE ARGV HALF IS THE SAME DEFECT WITH A QUIETER FACE. An Icon witness written `n := integer(args[1]) | 6`
runs GREEN on the `| 6` default, so the suite reports a pass for a program whose argument handling never
executed. corpus_suite_harness.py has carried full argv-sidecar support since 2026-09-06
(sidecar_argv_path / read_argv_sidecar / prog_argv through run_m3+run_m4) and NOT ONE rungs has ever had an
ALL.argv, so every one of those entries is graded along its no-arguments path.

⛔⭐ WHAT THIS TOOL CAN AND CANNOT SAY, stated up front because the distinction is the whole honesty of it.
It reads SOURCE TEXT for the constructs by which a program reaches for stdin or argv. That is a HEURISTIC:
it can name an entry that mentions INPUT inside a comment (false positive), and it cannot see a program that
reaches stdin through a path this file does not list (false negative). So its output is a WORK LIST, never a
verdict on an individual program -- the verdict is the oracle's, on the ref that gets cut once the entry is
fed. It is deliberately reported as "owes a declaration", not as "is wrong".
⛔ IT NEVER WRITES A SIDECAR. What input a program should be given is a decision with an oracle behind it,
and a tool that invented plausible input would manufacture exactly the self-pinned ref this census exists to
find -- a green cell proving only that the instrument agreed with itself.
"""
import argparse, importlib.util, json, os, re, sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("csh", _HERE / "corpus_suite_harness.py")
h = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(h)

# ⛔ ONE TABLE, KEYED BY LANGUAGE, AND EVERY PATTERN IS A CONSTRUCT THAT ACTUALLY REACHES THE STREAM.
# Deliberately NOT a generic word list: `read` appears in Icon prose constantly, so the Icon pattern wants
# the call shape. Where a language has several spellings they are all here, because a partial resolver never
# says so -- it just answers "no" and the caller mints a starved ref (the class this whole file is about).
STDIN_RE = {
    # ⛔⭐ `reads(` UNANCHORED MATCHED FOUR ENTRIES THAT NEVER TOUCH STDIN, and it broke this table's own
    # stated contract one line above it: Icon's reads(f,i) reads from FILE f, and only a bare reads() (or
    # reads(&input)) defaults to the stream. All four witnesses bind their file with open(): ladder_rung41_
    # rt_flush_seek_where and procedure_record_every_replace_2 (open("fncs1.dat")), ladder_rung41_rt_read_
    # reads_from_file -- whose NAME says so -- and procedure_record_every_replace_12, where reads(f,0) is an
    # error-provocation in a V9GEN torture entry. ⭐ An over-match here is not the harmless direction: this
    # census is a WORK LIST, so a false positive spends a seat's sitting authoring input for a program that
    # reads none, and it inflates the floor that the real campaign has to ratchet down through.
    "icon":    r'\bread\s*\(\s*\)|\breads\s*\(\s*\)|\breads\s*\(\s*&input\b|!\s*&input\b|\bread\s*\(\s*&input',
    "snobol4": r'\bINPUT\b',
    "snocone": r'\bINPUT\b',
    "prolog":  r'\bread\s*\(|\bread_term\s*\(|\bget_char\s*\(|\bread_line',
    "pascal":  r'\bread(ln)?\s*[\(;]',
    "raku":    r'\$\*IN\b|\bget\s*\(|\blines\s*\(|\bslurp\s*\(',
    "rebus":   r'\bINPUT\b',
}
ARGV_RE = {
    # ⛔ THE SECOND ALTERNATIVE MATCHES A DECLARATION, NOT A USE -- see inert_argv_match() below, which is
    # what keeps `procedure main(args)` with `args` never named again from counting as argument-sensitive.
    "icon":    r'\bargs?\s*\[|\bprocedure\s+main\s*\(\s*[A-Za-z_]',
    "snobol4": r'\bHOST\s*\(\s*[24]\b',
    "snocone": r'\bHOST\s*\(\s*[24]\b',
    "prolog":  r'\bargv\b',
    "pascal":  r'\bParamStr\b|\bParamCount\b',
    # ⛔ RAKU'S MAIN IS CASE-SENSITIVE and this whole table is compiled re.I, so the bare alternative
    # matched `sub main()` -- an ORDINARY subroutine with an EMPTY signature, which cannot observe an
    # argument under any circumstances. Measured 2026-09-19 (coo): 33 of the 36 raku entries this census
    # called argument-owing were lowercase `sub main()` with empty parens. Only `sub MAIN` is Raku's
    # command-line entry point, so that alternative is pinned case-sensitive with (?-i:...).
    "raku":    r'@\*ARGS\b|(?-i:\bsub\s+MAIN\s*\()',
    "rebus":   r'\bHOST\s*\(\s*[24]\b|\bARGV\b',
}
EXT = {"icon": ".icn", "snobol4": ".sno", "snocone": ".sc", "prolog": ".pl",
       "pascal": ".pas", "raku": ".raku", "rebus": ".reb"}


def refuse(msg):
    print(f"REFUSED(2): {msg}", file=sys.stderr)
    sys.exit(2)


def read_rungs(tests_dir, lang):
    """Read one rung suite through the harness -- the ONE authority -- or return None if it has no rungs."""
    d = Path(tests_dir) / lang
    sno = d / f"ALL{EXT[lang]}"
    if not sno.is_file():
        return None
    ref = d / "ALL.ref"
    if not ref.is_file():
        refuse(f"{lang}: {sno} exists but {ref} does not -- a suite pair with no refs cannot be censused")
    cfg = h.LANG_CONFIGS.get(lang)
    ip = h.sidecar_in_path(sno)
    # ⛔ snobol4 is the one format-A dialect (one-line entries interleaved with blocks) and MUST go through
    # read_suite; every other rungs is format-B only and read_block_suite is its reader. Using the wrong one
    # does not error -- it silently returns a different population, which is the census defect in miniature.
    if cfg is None:
        entries = h.read_suite(sno, ref, in_path=ip)
    else:
        br = h.banner_re_for(cfg["comment_open"], cfg["comment_close"])
        entries = h.read_block_suite(sno, ref, br, in_path=ip)
    return d, sno, entries


def inert_argv_match(lang, text):
    """True when the ARGV_RE hit CANNOT observe the program's arguments, so the entry owes no declaration.

    ⛔⭐ ONE CASE ONLY, AND IT IS THE SAME OVER-MATCH `reads(` WAS: Icon's second alternative matches
    `procedure main(P)` -- a PARAMETER DECLARATION. A program that declares P and never names it again
    cannot behave differently under any arguments whatsoever, so grading it bare is not a starved run, it
    is the only run there is. Measured on the Icon rungs: procedure_scan_while_1 and procedure_every_alt_20
    declare `args` with ZERO further references.
    ⭐ THE REFINEMENT IS DELIBERATELY NOT A REGEX. A pattern can say "this text mentions arguments"; only a
    second pass over the entry can say "and here is where it reads them", and that is exactly the question
    a work list must answer. Anything that DOES name the parameter -- `args[1]`, or merely `dump(args)`,
    which images it -- stays flagged: observing the list is argument-sensitivity even without a subscript.
    """
    if lang != "icon":
        return False
    if re.search(r'\bargs?\s*\[', text, re.I):        # a subscript reads an argument; never inert
        return False
    m = re.search(r'\bprocedure\s+main\s*\(\s*([A-Za-z_]\w*)', text, re.I)
    if not m:
        return False
    param = m.group(1)
    # every mention of the name OTHER than the declaration itself
    body = text[:m.start(1)] + text[m.end(1):]
    return not re.search(r'\b%s\b' % re.escape(param), body)


def declared_argv(d):
    """Entry names carrying a declaration in ALL.argv. Absent file -> empty set, never an error."""
    a = d / "ALL.argv"
    if not a.is_file():
        return set()
    names = set()
    for raw in a.read_text(encoding="utf-8").splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        names.add(raw.split("\t")[0].strip())
    return names


# ⛔⭐ THE SECOND DECLARATION, AND WHY IT COULD NOT BE A ROW IN ALL.argv (ceo CEO-962, 2026-09-20, on the coo's
# report; row instrument-the-nineteen-non-gc-blocking-arms-...). Three raku entries carry a REAL `sub MAIN(...)`
# whose parameters are ALL DEFAULTED: they run correctly bare, and they CAN observe an argument if given one.
# That second fact is the whole difference from Icon's never-named parameter, so the ceo REFUSED the widening of
# inert_argv_match() that would have covered them -- "a matcher widened to cover them silently absolves an
# unbounded future class of the same shape, and a criterion a widening satisfies while the debt stands is FALSE
# rather than lenient" -- and ruled the cure to be A DECLARATION BESIDE THE DATA, the shape this tree already
# uses for the CEO-409 mask and the OUTSIDE_SPITBOL_BASELINE sidecar: name the programs, with the reason.
# ⛔ AND IT MUST BE A SEPARATE FILE, which is a MEASURED constraint and not a preference:
# corpus_suite_harness.py:read_argv_sidecar REFUSES a name in ALL.argv declared with NO arguments ("no arguments
# is already the default -- remove the line rather than restating it"), so the three could not be written there
# without either refusing the whole raku rungs rc=2 or inventing arguments no oracle cut a ref for. ALL.argv
# says WHAT TO PASS and the harness executes it; ALL.argv.bare says THIS ENTRY IS GRADED BARE ON PURPOSE, WITH
# THE REASON, and NOTHING EXECUTES IT -- grading is byte-for-byte unchanged by its existence, which is exactly
# what makes it a declaration about the census rather than a change to the measurement.
# ⛔ EVERY ROW CARRIES ITS REASON OR THE CENSUS REFUSES rc=2: a bare name here would be an exemption with no
# author and no argument, which is the thing a floor drop must never be able to hide.
def declared_bare(d, known=None):
    """Entry names DECLARED to be graded bare on purpose, from ALL.argv.bare (`name<TAB>reason`).

    Absent file -> empty set. REFUSES (rc=2) on a row with no reason, on a row naming no entry in the rungs
    (a rename or a stale leftover silently withdraws the guarantee the file was written to add -- the same
    refusal read_argv_sidecar makes for its own file), and on a name declared in BOTH ALL.argv and
    ALL.argv.bare, which is two declarations contradicting each other about one program.
    """
    a = d / "ALL.argv.bare"
    if not a.is_file():
        return set()
    names, unknown, reasonless = set(), [], []
    for raw in a.read_text(encoding="utf-8").splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        parts = raw.split("\t")
        name, reason = parts[0].strip(), "\t".join(parts[1:]).strip()
        if not reason:
            reasonless.append(name); continue
        if known is not None and name not in known:
            unknown.append(name); continue
        names.add(name)
    if reasonless:
        refuse(f"{a}: declared bare with NO REASON: {reasonless} -- a name alone is an exemption with no "
               f"author and no argument, and a floor that falls on one of those falls on nothing")
    if unknown:
        refuse(f"{a}: declarations with no matching entry: {unknown} -- a rename or a stale leftover, and "
               f"either way it silently withdraws the guarantee this file was written to add")
    return names


def census(tests_dir, langs):
    rows, examined = [], 0
    for lang in langs:
        got = read_rungs(tests_dir, lang)
        if got is None:
            continue
        d, sno, entries = got
        rs, ra = re.compile(STDIN_RE[lang], re.I), re.compile(ARGV_RE[lang], re.I)
        decl_a = declared_argv(d)
        decl_bare = declared_bare(d, known={e.name for e in entries})
        _both = decl_a & decl_bare
        if _both:
            refuse(f"{d}: {sorted(_both)} are declared in BOTH ALL.argv and ALL.argv.bare -- one file says "
                   f"pass these arguments and the other says this entry is graded bare on purpose, and a "
                   f"reader cannot be asked to pick")
        for e in entries:
            examined += 1
            text = "\n".join(e.sno_lines)
            owes_in = bool(rs.search(text)) and e.stdin is None
            owes_argv = (bool(ra.search(text)) and not inert_argv_match(lang, text)
                         and e.name not in decl_a and e.name not in decl_bare)
            if owes_in or owes_argv:
                rows.append({"lang": lang, "name": e.name, "seq": e.seq, "kind": e.kind,
                             "owes_stdin": owes_in, "owes_argv": owes_argv})
    return rows, examined


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tests-dir", default=None, help="corpus/tests (default: derived from this script)")
    ap.add_argument("--lang", action="append", default=None, help="restrict to one language (repeatable)")
    ap.add_argument("--json", action="store_true", help="machine-readable, for the gate")
    args = ap.parse_args()

    tests = Path(args.tests_dir) if args.tests_dir else _HERE.parent.parent / "corpus" / "tests"
    if not tests.is_dir():
        refuse(f"no corpus tests directory at {tests}")
    langs = args.lang or list(EXT)
    for l in langs:
        if l not in EXT:
            refuse(f"unknown language {l!r} -- known: {', '.join(sorted(EXT))}")

    rows, examined = census(tests, langs)
    # ⛔ ZERO EXAMINED IS A REFUSAL, NEVER A CLEAN CENSUS. An empty denominator printing the success shape is
    # the failure this whole tree keeps re-learning (lib_gate.sh's own reason for the same rule).
    if examined == 0:
        refuse(f"censused ZERO entries under {tests} -- nothing was measured, and that is not the same as "
               f"nothing being owed")

    if args.json:
        print(json.dumps({"examined": examined, "rows": rows}))
        return 0

    ow_in = [r for r in rows if r["owes_stdin"]]
    ow_a = [r for r in rows if r["owes_argv"]]
    print(f"SIDECAR CENSUS over {examined} rungs entries in {len(langs)} language(s)")
    print(f"{'lang':10}{'owes ALL.in':>13}{'owes ALL.argv':>15}")
    for l in langs:
        a = sum(1 for r in ow_in if r["lang"] == l)
        b = sum(1 for r in ow_a if r["lang"] == l)
        if a or b:
            print(f"{l:10}{a:13}{b:15}")
    print(f"{'TOTAL':10}{len(ow_in):13}{len(ow_a):15}   (examined {examined})")
    for tag, rs_ in (("stdin", ow_in), ("argv", ow_a)):
        if rs_:
            print(f"\n-- entries owing an {tag} declaration (up to 40 of {len(rs_)}):")
            for r in rs_[:40]:
                print(f"   {r['lang']:9} {r['kind']:5} {r['name']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
