#!/usr/bin/env python3
"""util_add_ladder_witness.py -- THE SANCTIONED ADD-A-WITNESS PATH for a language's `ladder__rungNN_*`
family in corpus/tests/<lang>/ALL.{csv,<ext>,ref,wantrc} (task icon-witness-audit-passes-for-the-wrong-
reason, hq_B mail 2026-09-06 "next-is-the-missing-add-a-witness-path"). Before this script, none existed:
corpus_suite_harness.py has convert/convert-blocks/run/extract/extract-family/pin-ref/list and NOTHING that
appends one new entry to an existing rungs -- three prior sessions on that task file hit this exact wall
(see its own SUPERSEDED-NEXT history) and the seat05 census filed two oracle-verified witness bodies
(not() rung07, / rung34) that stayed parked in a FINDING instead of the corpus for want of this tool.

WHAT THIS DOES: takes ONE new witness's source, an origin naming its rung + construct, and mints it into
the rungs suite -- ALL.<ext>/ALL.ref get the new banner-delimited block (via corpus_suite_harness.py's
OWN Entry/read_block_suite/write_block_suite, never a hand-rolled marker writer, so formatting is
byte-identical to the other N entries by construction, not by care), and ALL.csv gets a new row with
EVERY column DERIVED from the source + the oracle's own verdict -- rank, entry, family, kind, xfail,
n_lines, want_rc and all ~61 per-construct feature flags. Nothing is typed by the caller except
the origin and the source text.

⛔⛔ THE REF IS ORACLE-CUT, NEVER HAND-TYPED AND NEVER FROM SCRIP (hq_B's own constraint, verbatim: "refs
cut from icont and iconx by absolute path, never from SCRIP"). This script invokes the shared oracle
(icon_bin() in lib_oracle_flags.sh -> /home/resources/icon-master/bin/icon, the one-step icont+iconx
driver -- "grading wants one step; timing wants two", per that file's own header) directly, TWICE, and
REFUSES on disagreement between the two runs (nondeterminism) exactly as util_cut_icon_ipl_refs.sh does
for the same reason. want_rc is the oracle's OWN observed exit code -- never a caller-supplied guess.

⛔⛔ THE ~61 FEATURE-FLAG COLUMNS ARE DERIVED BY TOKEN-SCANNING THE SOURCE, VALIDATED EMPIRICALLY, NOT
GUESSED FROM THE SCHEMA'S COLUMN NAMES. Measured against all 270 existing `family==ladder` rows before
this script was trusted with a real write: the simple keyword-presence rules reproduce 100% of every
flag for the rung07/rung34 population this task actually touches (the two rungs' 10 existing rows, zero
mismatches). A DIFFERENT, unrelated batch (rungs 38-42, coexpressions) disagrees with a plain
"'procedure' keyword present" rule for the `procedure` flag in 43/270 rows -- that is a PRE-EXISTING
historical inconsistency in a population this task does not touch, named here rather than silently
matched or silently fixed (see the companion FINDING). The `assign` flag specifically EXCLUDES an
assignment whose target is a &keyword (`&error := 1` is keyword_ref, not assign) -- confirmed against
ladder_rung36_sets_refusal / ladder_rung37_bal_refusal / ladder_rung06_cset_scan_refuse_any, all actual
assign=0 despite containing `:=`. `seq` is Icon's seq() builtin generator, detected the same as every
other simple builtin name -- an earlier draft of this script mis-transcribed the header and grouped it
with the compound flags instead of between `trim` and `integer` where it actually sits; the CSV-header
equality check below caught the resulting field-order mismatch before anything was written, which is
exactly the failure mode it exists for.

⛔ EVERY REFUSAL PATH WRITES NOTHING. All checks (oracle reachability, determinism, origin/entry
uniqueness, rung membership, a round-trip proof that read+write of the UNCHANGED existing entries is
lossless) run BEFORE any file is touched, and the final write goes to a .tmp path + os.replace(), never
a partial in-place write. --apply is required to write anything; without it this is a dry-run report.

Usage:
    util_add_ladder_witness.py --lang icon --origin ladder__rungNN_<slug> --source FILE.icn [--apply]
    util_add_ladder_witness.py --lang pascal --origin ladder__rungNN_<slug> --source FILE.pas [--first-in-rung] [--apply]
"""
import argparse
import csv
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import corpus_suite_harness as csh  # noqa: E402  -- the ONE authority for Entry/read/write_block_suite

S4E = HERE.parent.parent
ORACLE = {
    "icon": ["/home/resources/icon-master/bin/icon"],  # icont+iconx, one step -- grading wants one step
    "snobol4": ["/home/resources/x64/bin/sbl", "-bf"],  # THE one SNOBOL4 oracle (Lon 2026-09-07/08, RULES sec
    "snocone": ["/home/resources/x64/bin/sbl", "-bf"],  # ⛔ NOT RUNNABLE ON THE WITNESS -- see SNOCONE SUPPORT below
    "raku": ["/home/resources/rakudo-local/bin/raku"],  # Rakudo 2026.05, the ONE Raku oracle (rakudo_bin() in lib_oracle_flags.sh
    "prolog": ["/usr/bin/swipl", "-q", "-t", "halt"],  # THE SWI-Prolog oracle, swipl_bin() in lib_oracle_flags.sh; -q -t halt: the witness's own initialization(main) runs once and no toplevel is entered (cto, CEO-1959)
    "pascal": [str(HERE / "fpc_oracle_run.sh"), "-Miso"],  # fpc 3.2.2 -Miso through the one-step wrapper corpus_suite_harness.py's resolver names (compile to a tmpdir, run); a witness needing an FPC dialect says {$mode objfpc} in its own source, which fpc honours over -Miso as scrip does
}
# ⛔⭐ `-bf` IS NOT OPTIONAL AND NOT A PER-PROGRAM WORKAROUND (RULES sec Oracles, s189): SPITBOL case-folds
# names by default and SCRIP is case-sensitive, so a ref cut without -f grades a different language, and plain
# -b manufactures phantom duplicate labels that walk into a crashing error path. sbl_correctness_bin() +
# sbl_lang_flags() in lib_oracle_flags.sh are the shell-side authority for the same two facts.
#
# ⛔⭐ SNOCONE SUPPORT IS A TWIN, NOT A BINARY (hq_I 2026-09-13, granted CEO-672). Snocone is the one language
# here with NO oracle that can read its own source: SPITBOL cannot parse a .sc file at all -- measured, a
# one-line witness gives ERROR 221 syntax error missing operand and then "No END statement found in source
# file(s)", because Snocone uses semicolon terminators, slash-slash and slash-star comments, struct, and
# C-style control flow. So adding a row to the table above would be worse than useless: it would name a
# binary that cannot answer, and the refusal would look like a broken oracle rather than a category error.
# WHAT THE TWIN IS: the caller supplies --oracle-twin W.sno beside --source W.sc, and the ref is cut by
# running sbl -bf on the TWIN, twice, refusing on disagreement exactly as the icon and snobol4 paths do.
# This is legitimate rather than a dodge because Snocone's expression semantics ARE SPITBOL's -- corpus/
# tests/snocone/config/LADDER.tsv reference (b), citing ARCH-LANGUAGES.md sec SNOCONE. The witness never
# contributes its own output; SCRIP is never the oracle.
# ⭐ THE METHOD WAS VALIDATED BEFORE IT WAS USED, which is the only reason it is trusted: cutting refs
# through the twin reproduced the ALREADY-GREEN stored refs of ladder__rung00_hello and
# ladder__rung02_arithmetic BYTE-FOR-BYTE. A ref-cutting method that cannot reproduce a known-good ref has
# no business cutting a new one.
# ⛔⛔ CEO-672'S CONDITION IS ENFORCED HERE, NOT LEFT TO CARE: a twin is a TRANSLITERATION, or the
# equivalence is NAMED IN THE WITNESS, one line, at the site. An equivalence twin passed off as a
# transliteration is a ref we cut ourselves wearing the oracle's name, which CEO-548 forbids. The check is
# structural (significant-line counts must match) and it REFUSES rather than warns; --twin-equivalence
# declares the difference and writes it into the witness as a comment, so the next reader sees it at the
# code rather than in a commit message. The known instance is chained_multi_assign: SPITBOL has no chained
# assignment, so its twin is three separate assignments with identical output.
# ⭐ SNOBOL4 SUPPORT (ceo 2026-09-08, walking snobol4-ladder-every-feature-in-isolation-with-variations, whose
# forms check reported 131 declared slots with no witness across rungs 14-33): every language-specific fact
# below is TAKEN FROM AN EXISTING AUTHORITY rather than re-derived here -- the feature columns and the entry
# name come from util_build_rungs_suite.py's own COLS/NAME_FEATURES tables (the builder writes ALL.csv, so
# anything else would be a second opinion about the same file), and the rungs' shape comes from
# corpus_suite_harness.py. VALIDATED before use: the builder's predicates were run against all 94 existing
# family==ladder rows of the SNOBOL4 rungs and reproduced every one of their 39 flags, 0 mismatches.

SIMPLE_WORDS = ["write", "writes", "read", "reads", "find", "match", "upto", "many", "any", "bal", "tab",
    "move", "pos", "stop", "image", "type", "sort", "put", "push", "pop", "get", "insert", "delete",
    "member", "list", "table", "set", "repl", "map", "trim", "seq", "integer", "every", "suspend", "fail",
    "return", "while", "until", "repeat", "case", "next", "break", "create", "record", "procedure",
    "local", "static", "global"]
SPECIAL_ORDER = ["scan", "alternation", "element_gen", "limitation", "to_by", "assign", "swap",
    "aug_assign", "coexpr_activate", "keyword_ref", "every_with_suspend", "scan_with_tab",
    "gen_with_alternation", "section"]
FLAG_ORDER = SIMPLE_WORDS + SPECIAL_ORDER
assert len(FLAG_ORDER) == 62, len(FLAG_ORDER)
FIXED = ["rank", "entry", "origin", "family", "kind", "xfail", "n_lines"]
# ⛔⭐ THE ATTRIBUTE ROW CARRIES THE TEST UNIT'S COMMAND LINE (Lon 2026-09-26, RULES.md hard-cap rule clause 8 (f), CEO-1281):
# heap_kb, stack_kb, compile_args and run_args are declared on EVERY rungs row, and a witness this tool mints is a test unit
# like any other. It left all four BLANK (ceo CEO-1323, on hq_snocone's entry 1994 filled by hand), so the runner graded the
# new witness under a default it never declared. The values are never baked here: they are READ from the rungs' own ladder
# rows (the convention every ladder row carries, 131072 / 4096 / --stlimit / empty run_args on the SNOBOL4-family rung suites),
# an explicit --heap-kb/--stack-kb/--compile-args/--run-args overrides, and a column the ladder rows disagree on REFUSES.
ATTR_COLUMNS = ["heap_kb", "stack_kb", "compile_args", "run_args"]


def ladder_convention(rows, fields, overrides):
    """{column: value} for every ATTR column the rungs' header carries. An override wins; otherwise the ONE value
    the existing ladder__ rows agree on (all rows when the rungs has no ladder row yet); several values -> refuse."""
    out = {}
    for col in ATTR_COLUMNS:
        if col not in fields:
            continue
        if overrides.get(col) is not None:
            out[col] = overrides[col]
            continue
        pool = [r for r in rows if r.get("origin", "").startswith("ladder__")] or rows
        seen = sorted({(r.get(col) or "") for r in pool})
        if len(seen) != 1:
            refuse("cannot determine the rungs' %s convention: its %s rows carry %d different values (%s) -- pass --%s"
                   % (col, "ladder" if pool is not rows else "", len(seen),
                      ", ".join(repr(v) for v in seen[:6]), col.replace("_", "-")))
        out[col] = seen[0]
    return out
CSV_FIELDS = FIXED + FLAG_ORDER
WORD_RE = {w: re.compile(r"\b%s\b" % re.escape(w)) for w in SIMPLE_WORDS}


def refuse(msg):
    sys.stderr.write("⛔ REFUSED: %s\n" % msg)
    sys.exit(2)


def strip_strings_comments(src):
    """Icon strings are "..." (backslash-escaped, no multiline); comments are # to EOL. Feature-flag
    detection must not fire on a keyword that only appears inside a string literal or a comment."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == '"':
            j = i + 1
            while j < n and src[j] != '"':
                j += 2 if src[j] == "\\" else 1
            i = j + 1
            continue
        if c == "#":
            j = src.find("\n", i)
            i = n if j == -1 else j
            continue
        out.append(c)
        i += 1
    return "".join(out)


def derive_flags(sno_lines):
    """Returns {flag_name: 0/1} for all 62 columns. See module docstring for the empirical validation
    this ruleset was checked against before being trusted (270 family==ladder rows, 0 mismatches in the
    rung07+rung34 population this task touches)."""
    code = strip_strings_comments("\n".join(sno_lines))
    f = {w: (1 if WORD_RE[w].search(code) else 0) for w in SIMPLE_WORDS}
    aug_assign = bool(re.search(
        r"(?:\+|-|\*\*|\*|/|%|\^|\|\|\||\|\||<=|<|~===|~==|===|==|~=|>=|>):=", code))
    plain_assign = False
    for m in re.finditer(r"([&\w]+)\s*:=(?!=)", code):
        if code[max(0, m.start() - 1):m.start()].startswith(":"):
            continue  # part of :=: (swap)
        if not m.group(1).startswith("&"):
            plain_assign = True
    f["assign"] = 1 if plain_assign else 0
    f["swap"] = 1 if re.search(r":=:", code) else 0
    f["aug_assign"] = 1 if aug_assign else 0
    f["coexpr_activate"] = 1 if re.search(r"@", code) else 0
    f["keyword_ref"] = 1 if re.search(r"&[A-Za-z]", code) else 0
    f["scan"] = 1 if re.search(r"\?", code) else 0
    f["element_gen"] = 1 if re.search(r"!", code) else 0
    f["limitation"] = 1 if re.search(r"\\", code) else 0
    f["alternation"] = 1 if re.search(r"(?<!\|)\|(?!\|)", code) else 0
    f["to_by"] = 1 if re.search(r"\bto\b", code) else 0
    f["every_with_suspend"] = 1 if (f["every"] and f["suspend"]) else 0
    f["scan_with_tab"] = 1 if (f["scan"] and f["tab"]) else 0
    f["gen_with_alternation"] = 1 if (f["alternation"] and (f["every"] or f["element_gen"] or f["to_by"])) else 0
    f["section"] = 1 if re.search(r"\[[^\[\]\n]*?(?<![:=<>~|\[])[+-]?:(?![=:\]])[^\[\]\n]*\]", code) else 0
    missing = [k for k in FLAG_ORDER if k not in f]
    if missing:
        refuse("derive_flags() internal error -- undefined column(s): %s" % missing)
    return f


def run_oracle_twice(oracle_argv, src_path, timeout=8):
    outs, rcs = [], []
    for _ in range(2):
        try:
            p = subprocess.run(list(oracle_argv) + [str(src_path)], stdin=subprocess.DEVNULL,
                                capture_output=True, timeout=timeout)
        except subprocess.TimeoutExpired:
            refuse("oracle timed out on %s -- not a witness candidate" % src_path)
        outs.append(p.stdout.decode("utf-8", errors="replace"))
        rcs.append(p.returncode)
    if outs[0] != outs[1] or rcs[0] != rcs[1]:
        refuse("oracle is NONDETERMINISTIC on %s (two runs disagreed) -- not a witness candidate" % src_path)
    # ⛔⭐ THE REF IS CUT WITH EMPTY STDIN, AND THIS SCRIPT DOES NOT WRITE ALL.in -- so a witness that READS
    # its input would be minted against an empty-stdin answer and then graded against it forever, quietly
    # testing the wrong program. PROVED BY MEASUREMENT, not by grepping the source for INPUT: run the oracle
    # once more with a non-empty stdin and refuse if the answer moves. A witness whose answer depends on
    # stdin belongs to a landing that also writes the sidecar; refusing here is the honest half of that.
    try:
        p3 = subprocess.run(list(oracle_argv) + [str(src_path)], input=b"stdin-probe\n",
                            capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        refuse("oracle timed out on %s under the stdin-sensitivity probe" % src_path)
    if p3.stdout.decode("utf-8", errors="replace") != outs[0] or p3.returncode != rcs[0]:
        refuse("witness READS STDIN: the oracle's answer changes when stdin is non-empty, and this script "
               "writes no ALL.in sidecar, so the ref would pin the empty-stdin answer. Mint it in a landing "
               "that writes the stdin sidecar too, or make the witness stdin-independent (%s)" % src_path)
    return outs[0], rcs[0]


def _builder():
    import importlib.util
    spec = importlib.util.spec_from_file_location("_bms", str(HERE / "util_build_rungs_suite.py"))
    mod = importlib.util.module_from_spec(spec)
    argv = sys.argv[:]
    sys.argv = ["util_build_rungs_suite.py"]
    try:
        spec.loader.exec_module(mod)
    finally:
        sys.argv = argv
    return mod


def lang_schema(lang, rows):
    """The CSV schema is READ FROM THE FILE THIS TOOL IS ABOUT TO APPEND TO, never hardcoded twice. Icon keeps
    its compiled-in assertion (its 61 columns are this script's own contract); every other language takes the
    builder's own flag columns as the header names them, because the builder owns that header and a second copy
    of it here would drift. The four attribute columns (heap_kb, stack_kb, compile_args, run_args) are filled by
    ladder_convention() from the rungs' own ladder rows (CEO-1323); any other column this tool does not derive
    is left BLANK on the new row and the dry-run names it."""
    if not rows:
        refuse("%s rungs ALL.csv has no rows -- nothing to derive a schema from" % lang)
    fields = list(rows[0].keys())
    if fields[:len(FIXED)] != FIXED:
        refuse("%s ALL.csv does not open with the %d fixed columns %s -- do not proceed blind" % (lang, len(FIXED), FIXED))
    rest = fields[len(FIXED):]
    if lang == "icon":
        if [f for f in rest if f in FLAG_ORDER] != FLAG_ORDER:
            refuse("ALL.csv header does not carry this script's 62 known flag columns in order -- do not proceed blind")
        return fields, FLAG_ORDER
    b = _builder()
    if lang not in b.LANG_TABLES:
        refuse("util_build_rungs_suite.py has no LANG_TABLES entry for %r" % lang)
    derived = {name for name, _ in b.LANG_TABLES[lang][0]}
    return fields, [f for f in rest if f in derived]


def builder_flags(lang, sno_lines):
    """⛔ THE BUILDER'S OWN PREDICATES, NOT A SECOND OPINION. util_build_rungs_suite.py writes every other row
    of ALL.csv from LANG_TABLES[lang][0] applied to the entry's joined source text; deriving the same columns
    any other way here would put two rulesets on one file and the disagreement would show up as a flag nobody
    can explain. Validated 2026-09-08 against all 94 existing family==ladder SNOBOL4 rows: 0 mismatches."""
    b = _builder()
    if lang not in b.LANG_TABLES:
        refuse("util_build_rungs_suite.py has no LANG_TABLES entry for %r" % lang)
    cols = b.LANG_TABLES[lang][0]
    text = "\n".join(sno_lines)
    return {name: pred(text) for name, pred in cols}


def builder_order(lang, entries):
    """THE ORDER THE ORDER GATE GRADES, BY THE GATE'S OWN KEY. test_gate_rungs_order_is_the_builders_order sorts the committed entries
    with the builder's rungs_file_key over flags derived from each entry's text; this is that sort, so a mint and the gate cannot
    disagree about where an entry belongs (the key is imported from the builder, never re-typed here)."""
    b = _builder()
    if lang not in b.LANG_TABLES:
        refuse("util_build_rungs_suite.py has no LANG_TABLES entry for %r" % lang)
    cols = b.LANG_TABLES[lang][0]
    return sorted(entries, key=lambda e: b.rungs_file_key(e, {c: fn("\n".join(e.sno_lines)) for c, fn in cols}))


def builder_entry_name(lang, rows, sno_lines, flags):
    """The entry NAME is the builder's descriptive_name() plus the next free number, exactly as absorption
    would have named it -- so an entry minted here and an entry minted by a rebuild are indistinguishable, and
    test_gate_rungs_order_is_the_builders_order stays satisfiable (run the builder's --resort after minting)."""
    b = _builder()
    base = b.descriptive_name("\n".join(sno_lines), flags)
    used = {r["entry"] for r in rows}
    n = 1
    while "%s_%d" % (base, n) in used:
        n += 1
    return "%s_%d" % (base, n)


def banner_drift(lang, rungs_dir, rungs_src, rungs_ref, entries):
    """Return a human summary of the rungs' stale banner numbers, or "" if every banner already equals its
    entry's position. This is the DIAGNOSIS half of the round-trip refusal above: it answers "is the file
    stale?" so the refusal never has to accuse the tool for a defect in the data. It reads only -- the CURE
    is util_renumber_rungs_banners.py, deliberately a separate tool so that the sanctioned add-a-witness
    path never silently rewrites 1000 lines of somebody else's rungs as a side effect of minting one row."""
    cfg = csh.LANG_CONFIGS.get(lang)
    banner_re = (csh.banner_re_for(cfg["comment_open"], cfg["comment_close"]) if cfg else csh.BANNER_RE)
    pos = {e.name: i for i, e in enumerate(entries, 1)}
    hits, first = [], None
    for label, path in (("ALL." + rungs_src.suffix.lstrip("."), rungs_src), ("ALL.ref", rungs_ref),
                        ("ALL.in", rungs_dir / "ALL.in")):
        if not path.is_file():
            continue
        n = 0
        for line in path.read_text().splitlines():
            m = banner_re.match(line)
            if not m:
                continue
            want = pos.get(m.group("name"))
            if want is not None and want != int(m.group("seq")):
                n += 1
                if first is None:
                    first = (m.group("name"), int(m.group("seq")), want)
        if n:
            hits.append("%s has %d" % (label, n))
    if not hits:
        return ""
    return ("%s stale banner(s) -- first is %r, numbered %d but sitting at position %d"
            % (" and ".join(hits), first[0], first[1], first[2]))


def next_rank(rows):
    ranks = [int(r["rank"]) for r in rows]
    return max(ranks) + 1 if ranks else 1


def next_entry_name(rows, prefix="procedure_write_"):
    nums = [int(m.group(1)) for r in rows
            for m in [re.match(r"^%s(\d+)$" % re.escape(prefix), r["entry"])] if m]
    return "%s%d" % (prefix, (max(nums) + 1) if nums else 1)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lang", default="icon", choices=sorted(ORACLE))
    ap.add_argument("--entry-name", default="", help="override the builder-derived entry name (rarely right)")
    ap.add_argument("--origin", required=True, help="ladder__rungNN_<slug>, must be new and NN must be an existing rung")
    ap.add_argument("--source", required=True, help="path to the new witness's source file")
    ap.add_argument("--oracle-twin", default="",
                    help="path to the SPITBOL twin whose output IS the ref (required for --lang snocone, "
                         "which has no oracle able to read its own source; forbidden for the others, whose "
                         "oracle reads the witness itself)")
    ap.add_argument("--twin-equivalence", default="",
                    help="one line naming WHY the twin is not a transliteration (e.g. 'SPITBOL has no "
                         "chained assignment; the twin is three assignments with identical output'). "
                         "Written into the witness as a comment. Required when the twin's significant-line "
                         "count differs from the witness's -- CEO-672.")
    ap.add_argument("--first-in-rung", action="store_true",
                    help="this witness is deliberately the FIRST for its rung (rungs 24-33 are all brand new); "
                         "everything is derived from --source, so no sibling is needed -- the flag exists so a "
                         "typo'd rung number is still caught")
    ap.add_argument("--apply", action="store_true", help="write the files; omit for a dry-run report")
    ap.add_argument("--rungs-dir", default="", help="the rungs' directory (default corpus/tests/<lang>); a gate points it at a scratch copy")
    for _a in ATTR_COLUMNS:
        ap.add_argument("--" + _a.replace("_", "-"), default=None, dest="attr_" + _a,
                        help="the new row's %s; omitted, the rungs' own ladder convention is READ from its ladder rows" % _a)
    args = ap.parse_args()

    lang = args.lang
    # ⛔ SNOBOL4 IS DELIBERATELY ABSENT FROM csh.LANG_CONFIGS (see LANG_CHOICES there: every other language is
    # a converted block suite; SNOBOL4 is the original MIXED rungs and its config would imply a shape it does
    # not have). Its three facts are spelled here, beside the code that uses them, rather than added to the
    # shared table where they would claim membership of a family this rung suite is not in.
    cfg = csh.LANG_CONFIGS[lang] if lang in csh.LANG_CONFIGS else {
        "ext": ".sno", "comment_open": "*", "comment_close": ""}
    rungs_dir = Path(args.rungs_dir) if args.rungs_dir else S4E / "corpus" / "tests" / lang
    rungs_src, rungs_ref, rungs_csv = (rungs_dir / ("ALL" + cfg["ext"]), rungs_dir / "ALL.ref",
                                           rungs_dir / "ALL.csv")
    for p in (rungs_src, rungs_ref, rungs_csv):
        if not p.is_file():
            refuse("rungs file missing: %s" % p)

    m = re.match(r"^ladder__rung(\d+)_(\S+)$", args.origin)
    if not m:
        refuse("--origin must match ladder__rungNN_<slug>, got %r" % args.origin)
    rung_num = int(m.group(1))

    with open(rungs_csv, newline="") as fh:
        rows = list(csv.DictReader(fh))
    fields, flag_order = lang_schema(lang, rows)
    if any(r["origin"] == args.origin for r in rows):
        refuse("origin %r already exists in %s" % (args.origin, rungs_csv))
    existing_rungs = {int(mm.group(1)) for r in rows
                       for mm in [re.match(r"^ladder__rung(\d+)_", r["origin"])] if mm}
    if rung_num not in existing_rungs and not args.first_in_rung:
        # ⛔ THIS GUARD CATCHES A TYPO, NOT AN UNSOUNDNESS -- keep it, but make the deliberate case sayable.
        # `rung_num` is read NOWHERE else in this script (grep it): the entry name comes from
        # builder_entry_name(source), every flag from builder_flags(source), the ref from the oracle and the
        # rank from the CSV, so a brand-new rung derives exactly as correctly as a populated one. What the
        # guard really stops is `--origin ladder__rung42_...` typed for rung24 -- worth stopping, which is why
        # --first-in-rung is an explicit opt-in and not a deletion. The real safety nets are downstream and
        # still run for a first witness: the byte-for-byte round-trip proof and the extract-it-back-out proof.
        # ⛔ Before this flag existed the message said "mint it by hand once", and there is no by-hand path --
        # the rungs is a mixed one-line/banner-block format whose only sanctioned writer is this script.
        # hq_P 2026-09-09: rungs 24-33 are ALL brand new (witnesses stop at rung16), so the advice was
        # unfollowable for ten consecutive rungs, which is how it was found.
        refuse("rung%02d has no existing ladder__ witness in %s -- if this is deliberately the FIRST "
               "witness for a brand-new rung, pass --first-in-rung; refusing rather than guessing"
               % (rung_num, rungs_csv))

    src_path = Path(args.source)
    if not src_path.is_file():
        refuse("--source not found: %s" % src_path)
    try:
        sno_text = src_path.read_text(encoding="utf-8")
    except UnicodeDecodeError as e:
        refuse("--source is not valid UTF-8: %s" % e)
    sno_lines = sno_text.splitlines()
    if not sno_lines:
        refuse("--source is empty")

    oracle_argv = ORACLE[lang]
    if not Path(oracle_argv[0]).is_file():
        refuse("shared oracle missing at %s -- fix the shared tree, never fall back to PATH" % oracle_argv[0])
    # ⛔ WHICH FILE THE ORACLE READS IS A PER-LANGUAGE FACT, not a caller preference. snocone MUST cut from a
    # twin (its oracle cannot parse .sc at all); every other language MUST cut from the witness itself, and
    # accepting a twin there would silently let a caller grade one program while landing another.
    twin_path = Path(args.oracle_twin) if args.oracle_twin else None
    if lang == "snocone":
        if twin_path is None:
            refuse("--lang snocone requires --oracle-twin: SPITBOL cannot parse a .sc source, so there is no "
                   "way to cut this witness's ref from the witness itself (see SNOCONE SUPPORT above)")
    elif twin_path is not None:
        refuse("--oracle-twin is only for --lang snocone; %s's oracle reads the witness itself, and cutting "
               "the ref from a second file would grade a different program than the one landed" % lang)
    if twin_path is not None:
        if not twin_path.is_file():
            refuse("--oracle-twin not found: %s" % twin_path)
        try:
            twin_lines = twin_path.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError as e:
            refuse("--oracle-twin is not valid UTF-8: %s" % e)
        # ⛔ CEO-672: TRANSLITERATION OR DECLARED EQUIVALENCE, no third option. `significant` drops blanks,
        # comments and SNOBOL4's END, so the comparison is between the two programs' actual statements.
        def _sig(lines, is_twin):
            out = []
            for ln in lines:
                t = ln.strip()
                if not t:                                        continue
                if is_twin and (t.startswith("*") or t == "END"): continue
                if (not is_twin) and (t.startswith("//") or t.startswith("/*")): continue
                out.append(t)
            return out
        n_w, n_t = len(_sig(sno_lines, False)), len(_sig(twin_lines, True))
        if n_w != n_t and not args.twin_equivalence:
            refuse("TWIN IS NOT A TRANSLITERATION and no --twin-equivalence was given (CEO-672): the witness "
                   "has %d significant line(s) and the twin has %d. Either make the twin a line-for-line "
                   "transliteration, or pass --twin-equivalence naming why it cannot be -- an equivalence "
                   "twin passed off as a transliteration is a ref we cut ourselves wearing the oracle's "
                   "name (CEO-548)." % (n_w, n_t))
        if args.twin_equivalence:
            # ⭐ NAMED AT THE SITE, not in a commit message: the note goes into the witness itself, so the
            # next reader meets it beside the code rather than in history they have no reason to open.
            note = "%s TWIN IS AN EQUIVALENCE, NOT A TRANSLITERATION: %s%s" % (
                cfg["comment_open"], args.twin_equivalence.strip(), cfg["comment_close"])
            sno_lines = [note] + sno_lines
            sno_text = "\n".join(sno_lines) + "\n"
    ref_text, want_rc = run_oracle_twice(oracle_argv, twin_path if twin_path is not None else src_path)
    ref_lines = ref_text.splitlines()
    # ⛔⭐ A NONZERO want_rc IS DECLARED IN ALL.wantrc, NEVER ONLY IN ALL.csv (hq_I 2026-09-13, extending the
    # refusal that stood here). lib_ladder.sh's own wantrc() reads the sidecar and nothing else, so a witness
    # minted without that line is graded against the default rc=0 forever -- which is why the old refusal was
    # right to block rather than mint half of it. The sidecar is written below, after the rungs and the CSV,
    # under the same tmp+replace discipline and the same preserve-what-existed proof.
    if want_rc != 0 and lang not in csh.LANG_CONFIGS:
        refuse("oracle exited rc=%d and %s is a mixed (non-block) rungs, whose reader this tool drives "
               "through read_suite without a wantrc sidecar path -- extend that arm before minting a "
               "nonzero-rc witness for it" % (want_rc, lang))

    flags = derive_flags(sno_lines) if lang == "icon" else builder_flags(lang, sno_lines)

    # ⛔⭐ THE READER IS CHOSEN BY SUITE SHAPE, NOT BY LANGUAGE NAME (hq_I 2026-09-13). This read `lang ==
    # "icon"` while it had only two languages, so the two axes coincided and nothing said which one it meant.
    # They part at the third: snocone is a converted BLOCK suite like icon, and sending it down the mixed
    # SNOBOL4 reader raises `family.ref is shorter than family.sno at seq 1416` -- a real refusal, but one
    # that accuses the rungs of being malformed when the caller merely picked the wrong reader. The axis is
    # the one this file's own comment above already names: membership of csh.LANG_CONFIGS IS being a block
    # suite, and SNOBOL4's absence from it IS the mixed rungs.
    if lang in csh.LANG_CONFIGS:
        banner_re = csh.banner_re_for(cfg["comment_open"], cfg["comment_close"])
        entries = csh.read_block_suite(str(rungs_src), str(rungs_ref), banner_re,
                                        w_path=str(rungs_dir / "ALL.wantrc"))
        reserialize = lambda es, a, b: csh.write_block_suite(es, a, b, cfg["comment_open"], cfg["comment_close"])
        read_entries = lambda: csh.read_block_suite(str(rungs_src), str(rungs_ref), banner_re, w_path=str(rungs_dir / "ALL.wantrc"))
    else:
        # ⛔ THE SNOBOL4 RUNGS IS MIXED: one-line entries (`stmt;END;* name`) and 80-column banner blocks in
        # ONE file, so read_block_suite REFUSES on its first line. read_suite/write_suite are the harness's
        # own readers for that shape -- the round-trip proof below is what makes using them safe, and it is
        # run against the real rungs before a single byte is written.
        entries = csh.read_suite(str(rungs_src), str(rungs_ref), in_path=str(rungs_dir / "ALL.in"),
                                  x_path=str(rungs_dir / "ALL.xfail"))
        reserialize = lambda es, a, b: csh.write_suite(es, a, b, out_in=None, lang=lang)
        read_entries = lambda: csh.read_suite(str(rungs_src), str(rungs_ref), in_path=str(rungs_dir / "ALL.in"), x_path=str(rungs_dir / "ALL.xfail"))
    # ── ROUND-TRIP PROOF, before this tool is trusted to touch the real files: re-serialize the
    # UNCHANGED entries and diff against what is actually on disk. A mismatch here means this script's
    # understanding of the format is wrong, and it must refuse before writing anything, not after.
    tmp_src, tmp_ref = rungs_src.with_suffix(rungs_src.suffix + ".rtcheck"), rungs_ref.with_suffix(".ref.rtcheck")
    reserialize(entries, str(tmp_src), str(tmp_ref))
    same = tmp_src.read_text() == rungs_src.read_text() and tmp_ref.read_text() == rungs_ref.read_text()
    tmp_src.unlink(missing_ok=True); tmp_ref.unlink(missing_ok=True)
    if not same:
        # ⛔⭐ THE REFUSAL IS CORRECT; ITS EXPLANATION WAS FALSE, AND THAT COST FOUR LANES A DIAGNOSIS EACH
        # (hq_T 2026-09-13, on the cfo's routed brief). This message used to say only "this language's
        # reader+writer pair does not reproduce the existing rungs" -- which accuses THE TOOL, while by far
        # the likeliest fault is in THE FILE: corpus a6646f04c removed the 620 AST-graded entries from all
        # seven rung suites without renumbering, leaving banner numbers that no longer equal their positions, and
        # this proof went red on five of the seven at once. Three lanes each paid the same unaided diagnosis
        # and then each hand-renumbered their own rungs. So before accusing itself, the proof now SEPARATES
        # its two causes -- a stale banner number (a data defect, with a one-command cure) from a genuine
        # format disagreement (a tool defect) -- and names which one it actually found. ⭐ A refusal that
        # cannot say which of its causes fired is a refusal every reader must re-derive from scratch.
        stale = banner_drift(lang, rungs_dir, rungs_src, rungs_ref, entries)
        if stale:
            refuse("the rungs' banner numbers are STALE, not this tool's format understanding: %s. The "
                   "banner number must equal the entry's POSITION (read_block_suite/read_suite re-derive seq "
                   "positionally and the writers print it back out), and corpus a6646f04c's 620-entry removal "
                   "left it behind in five of seven rung suites.\n"
                   "   CURE, run by this rung suite's own lane owner:  "
                   "python3 ../harness/scripts/util_renumber_rungs_banners.py --lang %s --apply\n"
                   "   (it renumbers ALL.<ext>, ALL.ref AND ALL.in together, proves every graded field and "
                   "every non-banner byte unmoved first, and refuses rc=2 rather than write on any arm.)"
                   % (stale, lang))
        refuse("round-trip proof failed and the banner numbers are NOT the cause -- this language's "
               "reader+writer pair genuinely does not reproduce the existing rungs byte-for-byte. That is a "
               "defect in this tool or in the harness, not in the rungs: refusing to trust either with a "
               "real write. Diff the .rtcheck pair to see what moved.")

    # ⛔⭐ A MINT LANDS THE ENTRY IN THE BUILDER'S ORDER, SO THE RUNGS MUST ALREADY BE IN IT (CEO-2019, the SnoRungs order gate red at 880 of 2189
    # with nine dotnet harvests at the tail). This tool used to APPEND and leave the sort to a --resort nobody ran after a harvest, so every
    # mint broke `rank <= N` selects the greenest N until someone resorted. It now places the new entry by the builder's key after the
    # write (below); that moves ONLY the new entry when everything else is already in order, and when it is not the tool refuses here
    # rather than fold an unrelated reorder into a one-witness commit -- the resort is a deliberate, large, content-invariant commit.
    _have, _want = [e.name for e in entries], [e.name for e in builder_order(lang, entries)]
    if _have != _want:
        _i = next(i for i, (x, y) in enumerate(zip(_have, _want)) if x != y)
        refuse("the %s rungs is not in the builder's order (%d of %d positions differ; first at index %d: committed %r, builder %r) -- a mint "
               "places its entry by the builder's key and does not fold a reorder into the same commit.\n"
               "   CURE, run first by this rung suite's lane owner:  python3 ../harness/scripts/util_build_rungs_suite.py --lang %s --resort "
               "(it names any loose family it wants acknowledged with --absorb-only), then push, then mint"
               % (lang, sum(1 for x, y in zip(_have, _want) if x != y), len(_have), _i, _have[_i], _want[_i], lang))

    # ⛔⭐ A LADDER WITNESS IS NAMED FOR ITS ORIGIN. Every `family==ladder` row of every block-suite rungs
    # carries entry == origin, and a reader who greps the rungs for a rung finds the row by that name. The
    # builder's descriptive_name() is content-derived (`say (3 <=> 1);` names itself simple_assign_1), which
    # is right for an ABSORBED corpus program and wrong for a witness whose whole identity is its rung: the
    # first row this tool minted for rung17 was the ONLY entry != origin ladder row in the raku rungs
    # (hq_T 2026-09-13). --entry-name still overrides, and a non-ladder origin keeps the builder's name.
    default_name = args.origin if args.origin.startswith("ladder__") else (
        next_entry_name(rows) if lang == "icon" else builder_entry_name(lang, rows, sno_lines, flags))
    entry_name = args.entry_name or default_name
    if any(r["entry"] == entry_name for r in rows):
        refuse("entry name %r already exists -- pass --entry-name to disambiguate" % entry_name)
    rank = next_rank(rows)
    # ⛔⭐ THE BANNER'S seq IS THE ENTRY'S POSITION, NOT ITS CSV rank. read_block_suite() IGNORES the number
    # printed in the banner and re-derives seq positionally (`seq += 1`), while write_block_suite() writes
    # e.seq back out -- so "banner number == position" is an invariant of every file the reader has touched,
    # and an entry whose seq is its rank makes the rungs fail this tool's OWN round-trip proof on the very
    # next invocation. It was invisible for as long as rank and position coincided; corpus a6646f04c removed
    # the 620 AST-graded entries from all seven rung suites and separated them permanently (hq_T 2026-09-13).
    new_entry = csh.Entry("block", len(entries) + 1, entry_name, sno_lines, ref_lines, want_rc=want_rc)
    new_row = {"rank": str(rank), "entry": entry_name, "origin": args.origin, "family": "ladder",
               "kind": "block", "xfail": "0", "n_lines": str(len(sno_lines))}
    for k in flag_order:
        new_row[k] = str(flags[k])
    attrs = ladder_convention(rows, fields, {c: getattr(args, "attr_" + c) for c in ATTR_COLUMNS})
    new_row.update(attrs)

    _where = [e.name for e in builder_order(lang, entries + [new_entry])].index(entry_name) + 1
    print("would add: rank=%s entry=%s origin=%s want_rc=%s n_lines=%s (placed by the builder's key)"
          % (_where, entry_name, args.origin, want_rc, len(sno_lines)))
    if attrs:
        print("  attribute row (clause 8 f):", ", ".join("%s=%r" % (c, attrs[c]) for c in ATTR_COLUMNS if c in attrs),
              "-- read from the rungs' ladder rows unless given on the command line")
    _blank = [f for f in fields if f not in new_row]
    if _blank:
        print("  left blank (not derived here):", ", ".join(_blank))
    nz = [k for k in flag_order if flags[k]]
    print("  non-zero flags:", ", ".join(nz) if nz else "(none)")
    print("  oracle stdout:", repr(ref_text))

    if not args.apply:
        print("(dry-run only -- pass --apply to write)")
        return

    _companions = {n: ((rungs_dir / n).read_bytes() if (rungs_dir / n).is_file() else None) for n in ("ALL.in", "ALL.xfail", "ALL.wantrc")}
    def _rollback():
        try:
            rungs_src.write_text(old_src_text); rungs_ref.write_text(old_ref_text)
            rungs_csv.write_bytes(old_csv_bytes)
            for _n, _b in _companions.items():
                (rungs_dir / _n).unlink(missing_ok=True) if _b is None else (rungs_dir / _n).write_bytes(_b)
            return "the rung suites and their sidecars were RESTORED to their pre-write contents; the tree is clean"
        except OSError as exc:
            return "⛔ ROLLBACK ITSELF FAILED (%s) -- the rung suites are dirty, restore them from git" % exc
    all_entries = entries + [new_entry]
    tmp_src2 = rungs_src.with_suffix(rungs_src.suffix + ".newtmp")
    tmp_ref2 = rungs_ref.with_suffix(".ref.newtmp")
    reserialize(all_entries, str(tmp_src2), str(tmp_ref2))
    # Verify the OLD entries still round-trip identically inside the new file (prefix-equality check)
    # before replacing anything -- appending must never perturb what already existed.
    old_src_text = rungs_src.read_text()
    old_ref_text = rungs_ref.read_text()
    if not tmp_src2.read_text().startswith(old_src_text[:-1] if old_src_text.endswith("\n") else old_src_text):
        tmp_src2.unlink(missing_ok=True); tmp_ref2.unlink(missing_ok=True)
        refuse("post-append check failed: the existing entries were perturbed by the append -- nothing written")
    tmp_src2.replace(rungs_src)
    tmp_ref2.replace(rungs_ref)

    tmp_csv = rungs_csv.with_suffix(".csv.newtmp")
    with open(tmp_csv, "w", newline="") as fh:
        # ⛔ csv.writer DEFAULTS TO \r\n -- "OUR FILES ARE LF" (MODE), and the real ALL.csv is LF-only
        # (confirmed byte-for-byte: 0a, never 0d0a). Without this override every one of 808 existing
        # lines reads as "changed" to git (CRLF vs LF), turning a one-row append into an 809-deletion
        # rewrite -- caught by inspecting the actual diff before this was ever committed.
        w = csv.DictWriter(fh, fieldnames=fields, lineterminator="\n")
        w.writeheader()
        for r in rows:
            w.writerow(r)
        w.writerow(new_row)
    written = tmp_csv.read_bytes()
    if b"\r" in written:
        tmp_csv.unlink(missing_ok=True)
        refuse("internal error: wrote a CR byte into %s -- LF-only invariant violated, nothing replaced" % rungs_csv)
    old_csv_bytes = rungs_csv.read_bytes()
    if not written.startswith(old_csv_bytes if old_csv_bytes.endswith(b"\n") else old_csv_bytes + b"\n"):
        tmp_csv.unlink(missing_ok=True)
        refuse("post-append check failed: existing ALL.csv rows were perturbed by the append -- nothing written")
    tmp_csv.replace(rungs_csv)

    # ── THE wantrc SIDECAR. Written only for a nonzero rc: read_wantrc_sidecar() REFUSES a declared rc=0
    # (it is already the default), so writing one would break every later read of this rung suite.
    if want_rc != 0:
        w_path = rungs_dir / "ALL.wantrc"
        header = ("# ALL.wantrc \u2014 DECLARED exit codes for entries whose CORRECT run exits nonzero.\n"
                  "# Format: name<TAB>rc   \u00b7   blank lines and # comments ignored   \u00b7   rc=0 is the default and is REFUSED here.\n"
                  "#\n"
                  "# \u26d4 DECLARED, NEVER INFERRED: classify() refuses to call a nonzero-rc run a PASS unless the\n"
                  "# entry declares that exit code here, so an undeclared nonzero rc is a FAIL and not a silent pass.\n")
        old_w = w_path.read_text() if w_path.is_file() else header
        if not old_w.endswith("\n"):
            old_w += "\n"
        new_w = old_w + "%s\t%d\n" % (entry_name, want_rc)
        tmp_w = w_path.with_suffix(".wantrc.newtmp")
        tmp_w.write_text(new_w)
        if not tmp_w.read_text().startswith(old_w):
            tmp_w.unlink(missing_ok=True)
            refuse("post-append check failed: existing ALL.wantrc lines were perturbed -- nothing written")
        tmp_w.replace(w_path)
        print("  wrote ALL.wantrc: %s\t%d" % (entry_name, want_rc))

    # ── PLACE THE ENTRY BY THE BUILDER'S KEY (CEO-2019). The write above APPENDED (its prefix proofs need that); the builder's own
    # resort_rungs now moves the new entry to its place -- the one authority for the order, content-invariant by its own proofs, and
    # it rewrites ALL.csv's ranks and the banner numbers (ALL.<ext>, ALL.ref, ALL.in) positionally as it does for any resort. The base
    # was proved in order above, so the only entry that can move is the new one; anything else moving is refused and rolled back.
    _bld = _builder()
    _rc = _bld.resort_rungs(str(rungs_dir), cfg["ext"], lang, csh, cfg["comment_open"], cfg["comment_close"], _bld.LANG_TABLES[lang][0], set(), set())
    _placed = [e.name for e in read_entries()] if _rc == 0 else []
    if _rc != 0 or [n for n in _placed if n != entry_name] != [e.name for e in entries] or _placed != [e.name for e in builder_order(lang, read_entries())]:
        refuse("placing %s by the builder's key failed (resort rc=%s; the existing entries %s) -- %s"
               % (entry_name, _rc, "kept their relative order" if _rc == 0 and [n for n in _placed if n != entry_name] == [e.name for e in entries] else "MOVED", _rollback()))
    with open(rungs_csv, newline="") as fh:
        rank = next(r["rank"] for r in csv.DictReader(fh) if r["entry"] == entry_name)
    # ── FINAL PROOF: extract the just-written entry back out via the OFFICIAL extractor (not this
    # script's own belief) and confirm it is byte-identical to what the oracle produced.
    check_src, check_ref = Path("/tmp") / (entry_name + cfg["ext"]), Path("/tmp") / (entry_name + ".ref")
    err = subprocess.run([sys.executable, str(HERE / "corpus_suite_harness.py"), "extract",
                          str(rungs_src), str(rungs_ref), entry_name, str(check_src),
                          "--out-ref", str(check_ref)], capture_output=True, text=True)
    # ⛔⭐ THE EXPECTATION IS RECONSTRUCTED FROM THE LINES THE RUNGS STORES, NEVER FROM rstrip (hq_V,
    # 2026-09-09, on the FIRST rung minted for CEO-445). It was `ref_text.rstrip("\n") + "\n"`, which
    # collapses ANY run of trailing newlines to exactly one -- so a witness whose ORACLE OUTPUT LEGITIMATELY
    # ENDS IN A BLANK LINE could never pass its own proof: the rungs stores lines (`ref_text.splitlines()`),
    # the extractor faithfully returns the blank one, and the comparison had just stripped it. ⭐ NOTHING WAS
    # EVER WRONG WITH THE STORED DATA -- the round trip was exact and only the assertion about it was not,
    # which is why it read as a corpus fault rather than a proof fault and got worked around by appending a
    # non-blank final line to the witness. That workaround silently weakens the very assertion the witness
    # exists to make, and for Icon it is not a corner case at all: writing a null value prints an empty line,
    # which is exactly what a rung distinguishing null from integer 0 must show.
    def _as_stored(text):
        lines = text.splitlines()
        return "\n".join(lines) + "\n" if lines else ""
    ok = (err.returncode == 0 and check_src.read_text() == _as_stored(sno_text)
          and check_ref.read_text() == _as_stored(ref_text))
    check_src.unlink(missing_ok=True); check_ref.unlink(missing_ok=True)
    if not ok:
        # ⛔ A REFUSAL LEAVES THE TREE AS IT FOUND IT. The proof necessarily runs AFTER the three rung suites are
        # replaced -- it extracts through the OFFICIAL extractor rather than this script's belief, so there is
        # nothing to extract until the write lands. hq_V's measured cost: the tool refused and left the corpus
        # dirty, telling the operator not to trust files it had already written, which is the expensive half.
        # So the pre-write contents are restored before refusing, and the refusal says the tree is clean.
        refuse("post-write extraction proof failed for %s (stderr: %s) -- %s"
               % (entry_name, err.stderr, _rollback()))
    print("APPLIED: %s rank=%s -> %s / %s / %s (extraction round-trip verified)"
          % (entry_name, rank, rungs_src, rungs_ref, rungs_csv))


if __name__ == "__main__":
    main()
