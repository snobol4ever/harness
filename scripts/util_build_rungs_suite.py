#!/usr/bin/env python3
"""util_build_rungs_suite.py -- THE ONE FLAT SUITE + THE FEATURE DATABASE (Lon 2026-08-29, in-chat to CEO, verbatim in substance:
"I think we have organized the tests completely wrong. We should have ONE set of tests, and a database file, CSV file, which has
all the attributes you need to help isolate feature usage. So one flat list with attributes of each feature used in the program.
You could create as many as 30 attributes, for instance the one word primitive functions used like FENCE, POS, ARBNO, then
combinations like PATTERN . tz . *function(tz) would be a named construct. And there should be one big *.sno and one big *.ref
file. Not 10's of folders and 100's of files.")

Builds corpus/tests/snobol4/master/{ALL.sno, ALL.ref, ALL.csv} from EVERY suite pair under corpus/tests/snobol4/.
 - Entry names are prefixed with their source family (probe_kw__kw_defaults) so the flat namespace cannot collide; a collision REFUSES.
 - ALL.csv is the attribute database: one row per entry, ~30 columns of 0/1 feature flags scanned from the entry's own source text
   (primitives by exact UPPER name; constructs by syntax shape; combination columns for named constructs like capture_plus_defer,
   Lon's PATTERN . tz . *function(tz) example). The scanner is a lexical approximation, documented per column -- a DB row is a
   finding aid for isolating feature usage, never a semantic proof.
 - A family whose suite pair will not read (the malformed-conversion class) or that carries a stdin sidecar this merge cannot
   represent is EXCLUDED LOUDLY on stderr and listed in ALL.csv's sibling ALL.excluded.txt -- never silently dropped (the
   shrunken-denominator law).
 - Validation: the written pair is re-read and the entry count must equal the sum of the included families' counts, else REFUSE
   and write nothing. Grading is unchanged machinery: python3 ../harness/scripts/corpus_suite_harness.py run ALL.sno ALL.ref --modes m3,m4.
Stdlib only. Uses corpus_suite_harness's own read_suite/write_suite -- ONE authority for the suite grammar, never a second parser.

⛔⛔ CUT-OVER LANGUAGES RE-VERIFY IN A SCRATCH TREE AND DIFF -- NEVER BY DELETING IN PLACE.
(Law 2 AMENDED, ceo 2026-08-30, on hq_P + seat14 reproducing it independently; both reverted, origin intact.)
Law 2 says a GUARD CHANGE REQUIRES A CLEAN REBUILD. That is correct for a language with live sources -- it
cured icon's 14 false failures the same night -- and CATASTROPHIC for a CUT-OVER one, because "clean" means
deleting ALL.* and on a cut-over language THE RUNGS IS THE ONLY COPY. Measured on snobol4: rm ALL.* then
rebuild yields TWO entries where 1576 stood, because only 2 loose pairs remain absorbable. The build reports
success. hq_P's phrasing is the one to remember: CLOBBER-BY-GUARD-REBUILD IS CLOBBER WEARING THE LAW AS COVER.

  HOW TO RE-VERIFY A GUARD CHANGE ON A CUT-OVER LANGUAGE:
    1. cp -r corpus/tests/<lang> into a scratch tree; point S4E_HOME at its parent.
    2. Rebuild THERE. The real rungs is never opened for writing.
    3. ⛔ DIFF WITH util_rungs_content_diff.py -- NOT with `diff`. See the correction below.
    4. Bring differences across SURGICALLY, by the language owner. Never adopt a scratch tree wholesale.
  ⛔⛔ CORRECTION TO STEP 3, 2026-08-30, AND IT IS A REPAIR TO THIS PROCEDURE'S OWN AUTHOR (hq_C).
  Step 3 originally said "DIFF scratch against live". THAT CANNOT BE EXECUTED AS WRITTEN. Measured on
  snobol4 at corpus 5a48a5d5, scratch rebuild vs committed rungs: ALL.sno 1438 changed lines, ALL.csv
  2632, ALL.xfail 152 -- and the CONTENT WAS IDENTICAL (1726 entries both sides, 0 lost, 0 gained, 0
  bodies differing, xfail 77/77 with 76 reasons each).
  ⭐ CAUSE: `seq` is a POSITIONAL index and the rebuild's ordering differs from the committed file's.
  `code_eval_replace_1` sits at seq 1659 committed and 987 rebuilt; 694 of 1726 entries shift by exactly
  +1 to accommodate, rewriting their banners and CSV rows. Banner counts identical, 908/908. So
  build(read(X)) == X in CONTENT and != X in ORDER.
  ⛔ THEREFORE A BYTE DIFF OF A RUNGS IS ~3000 LINES OF PURE RENUMBERING AND A REAL CHANGE IS INVISIBLE
  INSIDE IT -- the procedure was asking for a needle in a haystack it generated itself. hq_P predicted
  this ("a 3154-line diff that would bury any real change") before the mechanism was known.
  ✅ Use `python3 ../harness/scripts/util_rungs_content_diff.py <live> <scratch> [--lang L]`: it compares what the
  grader reads -- name, body, ref, stdin, xfail, reason, want_rc -- and IGNORES seq and file order, which
  carry no meaning any grader consults. rc=0 identical, rc=1 real differences (named), rc=2 cannot measure.
  ⛔ AND DO NOT COMMIT A REBUILD WHOSE ONLY CHANGE IS THAT REORDERING: it buries the next real diff for
  no gain. A regen is worth committing when the CONTENT diff is non-empty, not when the byte diff is.
  ⭐ The shrink refusal below is the automated floor under this procedure, not a replacement for it: it stops
  the catastrophic case (0 < pairs << base), but a rebuild that shrinks the rungs by a NON-dramatic amount
  still passes the ratio and still loses entries. The scratch diff is what sees those.
  ⛔ A language is CUT OVER when its sources have been retired and the rungs is the source. The tell is this
  builder REFUSING with the collapse message -- if you see it, you are on a cut-over tree and step 1 applies.
  Related shapes that write into the rungs and therefore need the same care: --split-write (emits a derived
  pair, adopts nothing) and lib_rungs_extract.sh (materializes entries OUT, never in).
"""
import os
import re
import sys
import hashlib
import csv
import glob
import shutil
import argparse
import subprocess
import pathlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import corpus_suite_harness as h  # noqa: E402
# ⛔⭐ EVERY ENTRY CARRIES ITS SETTINGS (Lon 2026-09-25, in-chat to the ceo, verbatim: "Ensure that all the test suite programs have the
# stack size and heap size setting placed into the per-program attribute files."; ceo CEO-1261): a row the builder writes with no heap_kb
# or stack_kb of its own gets SPITBOL's defaults, read from the harness constants test_gate_suite_runners_honour_the_tests_declared_memory.sh
# holds to the runtime (-d128m and -s4m) -- a declaration an author measured is carried forward unchanged, never replaced by these.
DEFAULT_HEAP_KB = str(h.GC_HEAP_CAP_KB)
DEFAULT_STACK_KB = str(h.GC_STACK_FLOOR_KB)
# the unit's command line (RULES.md hard-cap rule clause 8 (f), ceo CEO-1281): carried forward like heap_kb, never re-derived --
# nothing in an entry's text says what switches its compile needs or what arguments its run takes
CMD_COLS = ("compile_args", "run_args")


def carried_cmd_cols(csv_path):
    """The command-line columns a rewrite of the table at csv_path writes: the ones it already has, or both for a new table.
    A rebuild carries the table's shape and never imposes a column the table was not given, so --reindex on an unmodified
    tree stays byte-identical (test_gate_rungs_builder_reindex_only.sh arm a) while the tables gain the columns."""
    if not os.path.isfile(csv_path):
        return list(CMD_COLS)
    with open(csv_path, newline="") as f:
        hdr = next(csv.reader(f), [])
    return [c for c in CMD_COLS if c in hdr]

def _stdin_sidecar_names(src_path):
    """The companions h.stdin_companion_candidates() found, rendered RELATIVE TO THE SOURCE'S DIRECTORY.
    ⛔ Never `.name` alone: `w.stdin` and `config/w.stdin` both render as "w.stdin", so the diagnostic whose
    whole job is to say WHICH file stopped the absorption would print the same word twice -- the identical
    trap hq_U cured inside loose_stdin_companion()'s AMBIGUOUS message on 2026-09-08."""
    _p = pathlib.Path(src_path)
    _d = _p.parent
    return ", ".join(str(c.relative_to(_d)) if _d in c.parents else c.name
                     for c in h.stdin_companion_candidates(_p))


def _stdin_text_for_absorption(src_path):
    """The stdin a plain program must be absorbed WITH, or (None, reason) if it cannot be carried.

    ⛔⭐ THE RULE THIS REPLACES NAMED A CAPABILITY THAT HAD SINCE LANDED (hq_V 2026-09-11). Both guard sites
    below used to EXCLUDE a stdin-bearing plain program with "stays as files until the stdin-sections format
    extension lands" -- a rationale written when the rungs had no way to carry input. It has one: the rungs
    pair ships `ALL.in`, write_stdin_sidecar() emits it, read_suite/read_block_suite attach it BY NAME, and
    run_suite_entry() feeds it. MEASURED BEFORE THIS CHANGE, in the tree it governs: the icon rungs' ALL.in
    already carries 20 stdin-fed entries. The extension is not pending; it shipped, and the park outlived it.
    ⭐ THIS IS THE MISSING-CAPABILITY CLASS corpus/tests/icon/KEEP.md NAMES IN ITS OWN WORDS -- *a rationale
    that names a MISSING CAPABILITY needs a RE-MEASURE date, not just an author date* -- and it is the second
    time this month the same shape turned seats away from work that was already possible.
    ⛔ IT DOES NOT WEAKEN THE GUARD THE PARK WAS PROTECTING, WHICH IS REAL AND STAYS: absorbing a stdin-reading
    program WITHOUT its input grades it against /dev/null, it stops at EOF before reaching the behaviour it was
    written to test, and the truncated run is filed as a documented red (seat04 measured exactly that on pascal
    read1-4). The cure for that is to CARRY the input, not to refuse the program; what still refuses is a
    program whose input cannot be carried FAITHFULLY, and that refusal is h.loose_stdin_companion()'s own --
    AMBIGUOUS (two companions, so nobody can say which is the input) and non-UTF-8 (bytes this text path
    cannot round-trip). Asked through the grader's finder, never a local spelling list, for the reason landed
    one day earlier: when this question had three written answers, two of them were silently wrong."""
    _txt, _path, _why = h.loose_stdin_companion(pathlib.Path(src_path))
    # ⛔ (None, None) means NO COMPANION EXISTS and is NOT a refusal: the program is absorbed exactly as it was
    # before this helper existed, fed nothing, because it reads nothing. Only a non-empty reason excludes.
    return _txt, _why


S4E = os.environ.get("S4E_HOME", os.path.dirname(os.path.dirname(HERE)))
PO = os.environ.get("S4E_POST", "/home/resources/postoffice")   # the fleet queue, for PENDING.md row-state

# -- ⭐ LANGUAGE PARAMETERISATION (hq_B 2026-08-29, ceo/Lon: rung suites for the other six languages).
# ROOT/ext/columns were hardcoded to snobol4. They are now selected by --lang; `snobol4` keeps its EXACT
# previous column set and naming table, so its rungs rebuilds BYTE-IDENTICAL -- that identity is the control
# arm for this change and is verified, not assumed.
# ⛔ snocone and rebus REUSE the snobol4 columns deliberately rather than getting invented ones: both are
# SNOBOL-family dialects over the same pattern primitives, and a fabricated column set would make their CSVs
# incomparable with snobol4's for no gain. prolog and raku get their own, because their primitives share
# almost nothing with the pattern vocabulary.
LANG_EXT = {"snobol4": ".sno", "prolog": ".pl", "raku": ".raku", "snocone": ".sc", "rebus": ".reb",
            "icon": ".icn", "pascal": ".pas"}

# -- the attribute columns: (name, predicate over the entry's joined source text) ------------------------------------
UPPER = lambda w: (lambda t: 1 if re.search(r"\b%s\b" % w, t) else 0)
COLS = [
    ("FENCE", UPPER("FENCE")), ("ARB", UPPER("ARB")), ("ARBNO", UPPER("ARBNO")), ("POS", UPPER("POS")),
    ("RPOS", UPPER("RPOS")), ("TAB", UPPER("TAB")), ("RTAB", UPPER("RTAB")), ("LEN", UPPER("LEN")),
    ("SPAN", UPPER("SPAN")), ("BREAK", UPPER("BREAK")), ("ANY", UPPER("ANY")), ("NOTANY", UPPER("NOTANY")),
    ("BAL", UPPER("BAL")), ("REM", UPPER("REM")), ("ABORT", UPPER("ABORT")), ("DEFINE", UPPER("DEFINE")),
    ("OPSYN", UPPER("OPSYN")), ("TABLE", UPPER("TABLE")), ("ARRAY", UPPER("ARRAY")), ("EVAL", UPPER("EVAL")),
    ("CODE", UPPER("CODE")), ("APPLY", UPPER("APPLY")), ("CONVERT", UPPER("CONVERT")), ("DATATYPE", UPPER("DATATYPE")),
    ("TRIM", UPPER("TRIM")), ("DUPL", UPPER("DUPL")), ("REPLACE", UPPER("REPLACE")), ("SIZE", UPPER("SIZE")),
    # constructs by syntax shape (lexical approximations, see header)
    ("cond_assign", lambda t: 1 if re.search(r"\s\.\s+[A-Za-z]", t) else 0),                # P . var
    ("imm_assign", lambda t: 1 if re.search(r"\s\$\s+[A-Za-z]", t) else 0),                 # P $ var (binary $)
    ("deferred_eval", lambda t: 1 if re.search(r"\*[A-Za-z(]", t) else 0),                  # *expr / *f(x)
    ("indirect_ref", lambda t: 1 if re.search(r"\$[A-Za-z(]", t) else 0),                    # $name (unary, no space)
    ("alternation", lambda t: 1 if "|" in t else 0),
    ("keyword_ref", lambda t: 1 if re.search(r"&[A-Z]", t) else 0),
    ("goto_fail", lambda t: 1 if ":F(" in t else 0),
    ("goto_success", lambda t: 1 if ":S(" in t else 0),
    # named combination constructs
    ("capture_plus_defer", lambda t: 1 if (re.search(r"\s\.\s+[A-Za-z]", t) and re.search(r"\*[A-Za-z(]", t)) else 0),  # Lon's PATTERN . tz . *function(tz)
    ("arbno_with_alt", lambda t: 1 if (re.search(r"\bARBNO\b", t) and "|" in t) else 0),
    ("fence_guarded_fail", lambda t: 1 if (re.search(r"\bFENCE\b", t) and ":F(" in t) else 0),
]


# -- descriptive renaming (Lon 2026-08-29, second ruling same session, verbatim in substance: "rename each and every test in
# the line-break column which will match the CSV file name. Abandon the old naming convention and make nice names that are
# descriptive and use snake_case, so like simple_pattern_with_replace_[0-9], nested_eval, etc.") -- the NAME is derived from
# the entry's own scanned features, most-salient-first, numbered for uniqueness; the old family__stem survives ONLY as the
# CSV's `origin` column (provenance is a database attribute, not a naming convention). ---------------------------------------
NAME_FEATURES = [
    ("DEFINE", "user_function"), ("OPSYN", "opsyn"), ("APPLY", "apply"), ("CODE", "code_eval"), ("EVAL", "eval"),
    ("ARBNO", "arbno"), ("FENCE", "fence"), ("BAL", "bal"), ("ARB", "arb"), ("SPAN", "span"), ("BREAK", "break"),
    ("ANY", "any"), ("NOTANY", "notany"), ("TAB", "tab"), ("RTAB", "rtab"), ("POS", "pos"), ("RPOS", "rpos"),
    ("LEN", "len"), ("REM", "rem"), ("ABORT", "abort"), ("TABLE", "table"), ("ARRAY", "array"),
    ("CONVERT", "convert"), ("DATATYPE", "datatype"), ("TRIM", "trim"), ("DUPL", "dupl"), ("REPLACE", "replace"),
    ("SIZE", "size"), ("deferred_eval", "defer"), ("cond_assign", "capture"), ("imm_assign", "imm_capture"),
    ("indirect_ref", "indirect"), ("alternation", "alt"), ("keyword_ref", "keyword"),
]
_REPL_RE = re.compile(r"^\S+\s+\S.*=\s")

# -- prolog attributes: primitives are lowercase atoms, so the matcher differs from snobol4's UPPER ----------
LOW = lambda w: (lambda t: 1 if re.search(r"(?<![A-Za-z0-9_])%s\s*\(" % w, t) else 0)   # name( -- a CALL, not a word
BARE = lambda w: (lambda t: 1 if re.search(r"(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % w, t) else 0)
PROLOG_COLS = [
    ("findall", LOW("findall")), ("bagof", LOW("bagof")), ("setof", LOW("setof")), ("forall", LOW("forall")),
    ("assert", LOW("assert")), ("asserta", LOW("asserta")), ("assertz", LOW("assertz")), ("retract", LOW("retract")),
    ("abolish", LOW("abolish")), ("catch", LOW("catch")), ("throw", LOW("throw")), ("between", LOW("between")),
    ("functor", LOW("functor")), ("arg", LOW("arg")), ("copy_term", LOW("copy_term")), ("call", LOW("call")),
    ("var", LOW("var")), ("nonvar", LOW("nonvar")), ("atom", LOW("atom")), ("number", LOW("number")),
    ("write", LOW("write")), ("writeq", LOW("writeq")), ("write_canonical", LOW("write_canonical")),
    ("format", LOW("format")), ("nl", BARE("nl")), ("clause", LOW("clause")), ("succ", LOW("succ")),
    ("op", LOW("op")),
    # constructs by syntax shape
    ("cut", lambda t: 1 if re.search(r"(^|[\s,(])!\s*[,.)]", t) else 0),
    ("dcg", lambda t: 1 if "-->" in t else 0),
    ("if_then_else", lambda t: 1 if ("->" in t and ";" in t) else 0),
    ("negation", lambda t: 1 if "\\+" in t else 0),
    ("unify", lambda t: 1 if re.search(r"[^:=<>\\]=[^=<>]", t) else 0),
    ("univ", lambda t: 1 if "=.." in t else 0),
    ("list_cons", lambda t: 1 if re.search(r"\[[^\]]*\|[^\]]*\]", t) else 0),
    ("directive", lambda t: 1 if re.search(r"^\s*:-", t, re.M) else 0),
    # named combinations
    ("findall_with_var_goal", lambda t: 1 if (re.search(r"findall\s*\(", t) and re.search(r"findall\s*\([^,]*,\s*[A-Z_]", t)) else 0),
    ("catch_with_throw", lambda t: 1 if (re.search(r"catch\s*\(", t) and re.search(r"throw\s*\(", t)) else 0),
    ("assert_then_retract", lambda t: 1 if (re.search(r"assert[az]?\s*\(", t) and re.search(r"retract\s*\(", t)) else 0),
]
PROLOG_NAME_FEATURES = [
    ("findall", "findall"), ("bagof", "bagof"), ("setof", "setof"), ("forall", "forall"),
    ("catch", "catch"), ("throw", "throw"), ("assert", "assert"), ("asserta", "asserta"), ("assertz", "assertz"),
    ("retract", "retract"), ("abolish", "abolish"), ("between", "between"), ("clause", "clause"),
    ("functor", "functor"), ("copy_term", "copy_term"), ("call", "call"), ("op", "op"),
    ("dcg", "dcg"), ("cut", "cut"), ("if_then_else", "ite"), ("negation", "naf"), ("univ", "univ"),
    ("list_cons", "list"), ("write_canonical", "write_canonical"), ("writeq", "writeq"), ("format", "format"),
    ("directive", "directive"),
]
# ⭐ THE regex COLUMN MARKS EVERY REGEX CONSTRUCT, NOT THE BARE WORD (the coo 2026-10-10, row instruments-the-raku-rungs-regex-attribute-
# column-marks-3-of-74-...; the cfo's finding: BARE("regex") marked 3 of the 73 rungs entries carrying a construct, so the area smoke, which
# selects by this column through ../harness/scripts/area_map.tsv, could not see the Raku regex roll-out). A regex, token, rule or grammar declaration
# (the keyword not a sigilled name, followed by a name or a signature), a smartmatch against a literal pattern ~~ /.../ or ~~ m/.../,
# an m//, rx// or s/// quote with or without adverbs (not $m/2, a division), and the .subst and .match methods.
RAKU_REGEX_CONSTRUCT = re.compile(r"(?<![$@%&\w-])(regex|token|rule|grammar)\s+[\w<-]|~~\s*(m|rx)?\s*/|(?<![$@%&\w])(s|m|rx)(:\w+)*/|\.subst\b|\.match\b")
RAKU_COLS = [
    ("sub", BARE("sub")), ("multi", BARE("multi")), ("my", BARE("my")), ("our", BARE("our")),
    ("say", LOW("say")), ("print", LOW("print")), ("given", BARE("given")), ("when", BARE("when")),
    ("if", BARE("if")), ("elsif", BARE("elsif")), ("unless", BARE("unless")), ("for", BARE("for")),
    ("while", BARE("while")), ("loop", BARE("loop")), ("return", BARE("return")), ("class", BARE("class")),
    ("has", BARE("has")), ("method", BARE("method")), ("regex", lambda t: 1 if RAKU_REGEX_CONSTRUCT.search(t) else 0), ("token", BARE("token")),
    ("grep", LOW("grep")), ("map", LOW("map")), ("sort", LOW("sort")), ("join", LOW("join")),
    ("split", LOW("split")), ("sprintf", LOW("sprintf")), ("die", LOW("die")), ("try", BARE("try")),
    ("sigil_scalar", lambda t: 1 if re.search(r"\$[A-Za-z_]", t) else 0),
    ("sigil_array", lambda t: 1 if re.search(r"@[A-Za-z_]", t) else 0),
    ("sigil_hash", lambda t: 1 if re.search(r"%[A-Za-z_]", t) else 0),
    ("junction", lambda t: 1 if re.search(r"\b(any|all|none|one)\s*\(", t) else 0),
    ("range_op", lambda t: 1 if ".." in t else 0),
    ("feed_op", lambda t: 1 if ("==>" in t or "<==" in t) else 0),
    ("smartmatch", lambda t: 1 if "~~" in t else 0),
    ("string_concat", lambda t: 1 if "~" in t else 0),
    ("sub_with_return", lambda t: 1 if (re.search(r"\bsub\b", t) and re.search(r"\breturn\b", t)) else 0),
    ("for_with_say", lambda t: 1 if (re.search(r"\bfor\b", t) and re.search(r"say\s*\(?", t)) else 0),
    ("regex_with_smartmatch", lambda t: 1 if (re.search(r"\b(regex|token|rule)\b", t) and "~~" in t) else 0),
]
RAKU_NAME_FEATURES = [
    ("class", "class"), ("method", "method"), ("multi", "multi"), ("sub", "sub"), ("token", "token"),
    ("regex", "regex"), ("given", "given"), ("when", "when"), ("for", "for"), ("while", "while"),
    ("loop", "loop"), ("grep", "grep"), ("map", "map"), ("sort", "sort"), ("join", "join"), ("split", "split"),
    ("junction", "junction"), ("smartmatch", "smartmatch"), ("feed_op", "feed"), ("range_op", "range"),
    ("sigil_hash", "hash"), ("sigil_array", "array"), ("say", "say"), ("try", "try"), ("die", "die"),
]
# -- icon attributes: Icon's vocabulary is GENERATORS and STRING SCANNING, so the columns are built around
# result sequences (every/suspend/alternation/element-generation) and the scanning environment (?/tab/move/&pos),
# not around pattern primitives. Deliberately NOT the SNOBOL4 table: `ANY`/`TAB`/`POS` exist in both languages
# with different meanings, and borrowing would make a cross-language profile read as agreement where there is none.
ICON_SECTION_RE = re.compile(r"\[[^\[\]\n]*?(?<![:=<>~|\[])[+-]?:(?![=:\]])[^\[\]\n]*\]")
ICON_COLS = [
    ("write", LOW("write")), ("writes", LOW("writes")), ("read", LOW("read")), ("reads", LOW("reads")),
    ("find", LOW("find")), ("match", LOW("match")), ("upto", LOW("upto")), ("many", LOW("many")),
    ("any", LOW("any")), ("bal", LOW("bal")), ("tab", LOW("tab")), ("move", LOW("move")),
    ("pos", LOW("pos")), ("stop", LOW("stop")), ("image", LOW("image")), ("type", LOW("type")),
    ("sort", LOW("sort")), ("put", LOW("put")), ("push", LOW("push")), ("pop", LOW("pop")),
    ("get", LOW("get")), ("insert", LOW("insert")), ("delete", LOW("delete")), ("member", LOW("member")),
    ("list", LOW("list")), ("table", LOW("table")), ("set", LOW("set")), ("repl", LOW("repl")),
    ("map", LOW("map")), ("trim", LOW("trim")), ("seq", LOW("seq")), ("integer", LOW("integer")),
    # control and declaration keywords (bare words, Icon is lowercase and case-sensitive)
    ("every", BARE("every")), ("suspend", BARE("suspend")), ("fail", BARE("fail")), ("return", BARE("return")),
    ("while", BARE("while")), ("until", BARE("until")), ("repeat", BARE("repeat")), ("case", BARE("case")),
    ("next", BARE("next")), ("break", BARE("break")), ("create", BARE("create")), ("record", BARE("record")),
    ("procedure", BARE("procedure")), ("local", BARE("local")), ("static", BARE("static")), ("global", BARE("global")),
    # constructs by syntax shape (lexical approximations)
    ("scan", lambda t: 1 if re.search(r"\?\s*[A-Za-z_{(\"]", t) else 0),                  # expr ? expr -- scanning
    ("alternation", lambda t: 1 if re.search(r"[^|]\|[^|]", t) else 0),                    # e1 | e2 -- result sequence
    ("element_gen", lambda t: 1 if re.search(r"(^|[\s(,=])!\s*[A-Za-z_(\"]", t, re.M) else 0),  # !x
    ("limitation", lambda t: 1 if re.search(r"\\\s*[0-9A-Za-z_(]", t) else 0),               # e \ n
    ("to_by", lambda t: 1 if re.search(r"(?<![A-Za-z0-9_])to(?![A-Za-z0-9_])", t) else 0),  # i to j [by k]
    ("assign", lambda t: 1 if ":=" in t else 0),
    ("swap", lambda t: 1 if ":=:" in t else 0),
    ("aug_assign", lambda t: 1 if re.search(r"[-+*/|&]:=", t) else 0),
    ("coexpr_activate", lambda t: 1 if "@" in t else 0),
    ("keyword_ref", lambda t: 1 if re.search(r"&[a-z]", t) else 0),
    # named combinations
    ("every_with_suspend", lambda t: 1 if (re.search(r"(?<![A-Za-z0-9_])every(?![A-Za-z0-9_])", t) and re.search(r"(?<![A-Za-z0-9_])suspend(?![A-Za-z0-9_])", t)) else 0),
    ("scan_with_tab", lambda t: 1 if (re.search(r"\?\s*[A-Za-z_{(\"]", t) and re.search(r"(?<![A-Za-z0-9_])tab\s*\(", t)) else 0),
    ("gen_with_alternation", lambda t: 1 if (re.search(r"(?<![A-Za-z0-9_])(every|suspend)(?![A-Za-z0-9_])", t) and re.search(r"[^|]\|[^|]", t)) else 0),
    ("section", lambda t: ICON_SECTION_RE.search(re.sub(r'"(?:\\.|[^"\\\n])*"', '""', t)) and 1 or 0),   # s[i:j], s[i+:n], s[i-:n] -- a section, not a := or :=: inside brackets
]
ICON_NAME_FEATURES = [
    ("procedure", "procedure"), ("record", "record"), ("create", "coexpr"), ("every", "every"),
    ("suspend", "suspend"), ("scan", "scan"), ("element_gen", "elemgen"), ("alternation", "alt"),
    ("limitation", "limit"), ("to_by", "to"), ("swap", "swap"), ("coexpr_activate", "activate"),
    ("case", "case"), ("while", "while"), ("until", "until"), ("repeat", "repeat"), ("fail", "fail"),
    ("tab", "tab"), ("move", "move"), ("upto", "upto"), ("many", "many"), ("find", "find"), ("match", "match"),
    ("bal", "bal"), ("sort", "sort"), ("table", "table"), ("list", "list"), ("set", "set"), ("map", "map"),
    ("repl", "repl"), ("seq", "seq"), ("write", "write"), ("writes", "writes"), ("read", "read"),
    ("keyword_ref", "keyword"), ("aug_assign", "augassign"), ("global", "global"), ("static", "static"),
]
# -- pascal attributes: ISO Pascal is CASE-INSENSITIVE, so every matcher here folds case (the corpus happens to
# be lowercase throughout, but a table that only matched lowercase would silently under-report an upper-case
# dialect file and read as "this program uses no constructs" rather than as a miss).
PAS = lambda w: (lambda t: 1 if re.search(r"(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % w, t, re.I) else 0)
PASCAL_COLS = [
    ("program", PAS("program")), ("procedure", PAS("procedure")), ("function", PAS("function")),
    ("var", PAS("var")), ("const", PAS("const")), ("type", PAS("type")), ("record", PAS("record")),
    ("array", PAS("array")), ("set", PAS("set")), ("file", PAS("file")), ("packed", PAS("packed")),
    ("label", PAS("label")), ("goto", PAS("goto")), ("with", PAS("with")), ("case", PAS("case")),
    ("while", PAS("while")), ("repeat", PAS("repeat")), ("for", PAS("for")), ("downto", PAS("downto")),
    ("forward", PAS("forward")), ("nil", PAS("nil")), ("div", PAS("div")), ("mod", PAS("mod")),
    ("in", PAS("in")), ("writeln", PAS("writeln")), ("write", PAS("write")), ("readln", PAS("readln")),
    ("read", PAS("read")), ("new", PAS("new")), ("dispose", PAS("dispose")), ("ord", PAS("ord")),
    ("chr", PAS("chr")), ("succ", PAS("succ")), ("pred", PAS("pred")), ("abs", PAS("abs")),
    ("sqr", PAS("sqr")), ("sqrt", PAS("sqrt")), ("trunc", PAS("trunc")), ("round", PAS("round")),
    ("eof", PAS("eof")), ("eoln", PAS("eoln")), ("odd", PAS("odd")),
    # constructs by syntax shape
    ("assign", lambda t: 1 if ":=" in t else 0),
    ("pointer", lambda t: 1 if re.search(r"\^\s*[A-Za-z_;)\]]", t) else 0),
    ("set_literal", lambda t: 1 if re.search(r"\[[^\]]*\.\.[^\]]*\]", t) else 0),
    ("subrange", lambda t: 1 if re.search(r"[0-9A-Za-z_'\)]\s*\.\.\s*[0-9A-Za-z_']", t) else 0),
    ("nested_proc", lambda t: 1 if len(re.findall(r"(?<![A-Za-z0-9_])(procedure|function)(?![A-Za-z0-9_])", t, re.I)) > 1 else 0),
    # named combinations
    ("for_with_array", lambda t: 1 if (re.search(r"(?<![A-Za-z0-9_])for(?![A-Za-z0-9_])", t, re.I) and re.search(r"(?<![A-Za-z0-9_])array(?![A-Za-z0-9_])", t, re.I)) else 0),
    ("with_record", lambda t: 1 if (re.search(r"(?<![A-Za-z0-9_])with(?![A-Za-z0-9_])", t, re.I) and re.search(r"(?<![A-Za-z0-9_])record(?![A-Za-z0-9_])", t, re.I)) else 0),
    ("pointer_with_new", lambda t: 1 if (re.search(r"\^", t) and re.search(r"(?<![A-Za-z0-9_])new\s*\(", t, re.I)) else 0),
]
PASCAL_NAME_FEATURES = [
    ("program", "program"), ("function", "function"), ("procedure", "procedure"), ("record", "record"),
    ("array", "array"), ("set", "set"), ("file", "file"), ("packed", "packed"), ("pointer", "pointer"),
    ("with", "with"), ("case", "case"), ("while", "while"), ("repeat", "repeat"), ("for", "for"),
    ("downto", "downto"), ("goto", "goto"), ("label", "label"), ("forward", "forward"),
    ("nested_proc", "nested"), ("set_literal", "setlit"), ("subrange", "subrange"), ("div", "div"),
    ("mod", "mod"), ("writeln", "writeln"), ("readln", "readln"), ("new", "new"), ("dispose", "dispose"),
    ("sqrt", "sqrt"), ("trunc", "trunc"), ("round", "round"), ("eof", "eof"), ("odd", "odd"),
]
# -- the snobol4 master alone gains an arithmetic column (CEO-1683: a binop template cure had no named handful). A binary + - * / ** is a SNOBOL4
# operator only between blanks (no blank is concatenation, and *X is a deferred reference), so the scan reads code lines only (a column-1 * is a
# comment), takes the quoted literals out first, and wants blank or tab on both sides of the operator. snocone and rebus keep COLS: their
# operators do not need the blanks, so this scan would read them wrong.
ARITH_STR = re.compile(r"'[^']*'|\"[^\"]*\"")
ARITH_OP = re.compile(r"[ \t](?:\*\*|[-+*/])[ \t]")
def _arith(t):
    return 1 if ARITH_OP.search(ARITH_STR.sub("''", "\n".join(l for l in t.split("\n") if not l.startswith("*")))) else 0
SNO_COLS = COLS + [("arith", _arith)]
LANG_TABLES = {
    "snobol4": (SNO_COLS, NAME_FEATURES),   # the 39 shared columns, then arith
    "snocone": (COLS, NAME_FEATURES),   # SNOBOL-family: same pattern vocabulary, deliberately shared
    "rebus":   (COLS, NAME_FEATURES),   # SNOBOL-family: same pattern vocabulary, deliberately shared
    "prolog":  (PROLOG_COLS, PROLOG_NAME_FEATURES),
    "raku":    (RAKU_COLS, RAKU_NAME_FEATURES),
    "icon":    (ICON_COLS, ICON_NAME_FEATURES),
    "pascal":  (PASCAL_COLS, PASCAL_NAME_FEATURES),
}



def _origin_key(fam, name):
    """⛔⭐ THE ONE PLACE AN ORIGIN KEY IS SPELLED (row: the absorb verifier marked established families
    UNVERIFIED; seat03 root-caused it 2026-09-04 after hitting it on rung06 AND rung07).

    Absorption assigns `fam` for the degenerate case where the entry IS the family, and `fam__name`
    otherwise. The round-trip VERIFIER reconstructed that key independently, from the loose file's
    BASENAME -- and a file in an already-established family is named with the family prefix already on
    it (`ladder__rung07_table.sno`), so the verifier built the DOUBLED `ladder__ladder__rung07_table`
    and looked up a key absorption had never written. Every established family therefore came back
    UNVERIFIED no matter how correct the absorption was.
    ⛔ THE COST WAS NOT THE WRONG WORD ON A REPORT. `--delete-absorbed` refuses to delete an unverified
    source, correctly -- so the safety rule held, and what broke was the operator's ability to tell a
    real round-trip failure from this one. Two rungs in a row were landed by verifying BY HAND with
    rungs_extract_origin, which is exactly the work the verifier exists to save, and a verifier that
    cries wolf on every established family is one nobody will read on the day it is right.
    ⭐ The cure is not a smarter reconstruction: it is that reconstruction stops. The writer and the
    reader now call this function, so the key cannot drift between them again."""
    name = str(name)
    if name == fam:
        return fam
    # a loose file in an established family already carries the family prefix -- strip it before keying,
    # or the key doubles. (`ladder__rung07_table` -> `rung07_table` -> `ladder__rung07_table`.)
    pfx = "%s__" % fam
    if name.startswith(pfx):
        name = name[len(pfx):]
    return "%s__%s" % (fam, name)


def descriptive_name(text, flags):
    parts = [short for col, short in NAME_FEATURES if flags.get(col)]
    is_match = 1 if re.search(r"^\s*\S+\s+[A-Z*'\"(]", text, re.M) else 0
    if not parts:
        if "OUTPUT" in text:
            base = "simple_output"
        elif "=" in text:
            base = "simple_assign"
        else:
            base = "simple_program"
    else:
        base = "_".join(parts[:3])
        if _REPL_RE.search(text.replace("\n", " ")) and "pattern" not in base and is_match:
            base = base + "_replace"
        if flags.get("goto_fail") or flags.get("goto_success"):
            base = base + "_branch"
    return base



# ⛔ dirs whose pairs are COMPANION-DEPENDENT and must NOT be absorbed: an entry runs ALONE in a scratch dir, so a
# test needing sibling files beside it would grade a DIFFERENT program. linker/ is the multi-file IMPORT/EXPORT
# class (its companions are themselves source files, invisible to the extension rule); probe_loose/ is the
# characterized un-convertible residue by definition; rtx_func_11 is the -INCLUDE class whose include resolution
# provably differs between its own dir and rungs/ (absorbed copy graded m3-red while the source grades green --
# measured v5); all stay loose until their owning rows settle representation.
EXCLUDE_DIRS = {"linker", "probe_loose", "rtx_func_11"}
COMPANION_EXTS = {".inc", ".dat", ".input", ".in", ".json"}


# ============================================================ deferral contract: KEEP.md / PENDING.md ===
# ⭐ Row master-suite-builder-honours-deferral-contract-and-scopes-absorption, requirement 1: the gate
# `test_gate_suite_conversion_complete.sh` already polices a KEEP.md ("stays loose forever, on purpose")
# and a PENDING.md `## DEFERRED` list ("converts later, when a named row lands") -- but until now this
# builder had ZERO references to either filename, so absorbing a family the gate was protecting was not a
# misuse, it was the ONLY way to convert anything: the gate polices what the builder cannot see. MEASURED
# harm: a scoped run absorbed `coexpr_gc_stack_witness`, the live DONE-WHEN witness of a DIFFERENT row.
# ⛔ The matcher below is a deliberate Python port of that gate's own bash matcher (delimited substring,
# directory-scoped ancestor walk, config/*KEEP.md tree-wide, unique-bare-basename fallback) -- KEEP BOTH IN
# SYNC. A second, looser matcher here would silently reopen the substring/scope bugs that gate already paid
# to fix (root KEEP.md's bare "plunit.pl" once also declared a same-named file three directories away).
# ⭐ A PENDING deferral blocks absorption ONLY while its row is LIVE -- mirroring the gate's own
# pending_row_state(), a straight port (claim file says DONE -> EXPIRED; else listed in QUEUE.done.tsv ->
# EXPIRED; else listed in QUEUE.tsv -> LIVE; else DANGLING). MEASURED WHY THIS MUST RESOLVE STATE, not just
# "listed = blocked": tests/icon/PENDING.md defers rung36_jcon_scan/rung36_jcon_scan2 to row
# icon-scan-env-value-residue, and that row is DONE (its claim file's last line is literally "DONE") --
# test_gate_suite_conversion_complete.sh's own PBAD bucket already calls this "a deferral whose row has
# landed has outlived its reason: CONVERT these now." An unconditional "still listed = still blocked" rule
# would make that gate's own prescribed fix unreachable through this tool. EXPIRED and DANGLING (row done,
# missing, or archived) are both stale-per-the-gate and therefore absorbable; only LIVE (and UNVERIFIABLE,
# failing closed rather than guessing) still blocks.
_DELIM_CACHE = {}
def _delim_match(token, text):
    """Delimited substring match -- identical regex shape to test_gate_suite_conversion_complete.sh's
    KEEP.md/PENDING.md grep (leading boundary excludes ./-, trailing boundary allows them)."""
    pat = _DELIM_CACHE.get(token)
    if pat is None:
        pat = re.compile(r"(?:^|[^A-Za-z0-9_./-])%s(?:[^A-Za-z0-9_-]|$)" % re.escape(token), re.MULTILINE)
        _DELIM_CACHE[token] = pat
    return pat.search(text) is not None


def _ancestor_files(start_dir, root, filename):
    """<start_dir>/filename, its parent's, ... up to and including <root>/filename -- nearest first,
    mirroring the gate's `probe="$d"; while : ; do ... probe=$(dirname "$probe"); done` walk."""
    found = []
    probe = os.path.abspath(start_dir)
    root_abs = os.path.abspath(root)
    while True:
        cand = os.path.join(probe, filename)
        if os.path.isfile(cand):
            found.append(cand)
        if probe == root_abs:
            break
        parent = os.path.dirname(probe)
        if parent == probe:
            break
        probe = parent
    return found


def _declared_in_keep(path, root, basename_counts):
    """The KEEP.md declaring `path` (nearest ancestor first, then tree-wide config/*KEEP.md), or None."""
    b = os.path.basename(path)
    for kf in _ancestor_files(os.path.dirname(path), root, "KEEP.md"):
        text = open(kf, encoding="utf-8", errors="replace").read()
        rel = os.path.relpath(path, os.path.dirname(kf))
        if _delim_match(rel, text) or (basename_counts.get(b, 0) == 1 and _delim_match(b, text)):
            return kf
    for kf in sorted(glob.glob(os.path.join(root, "config", "*KEEP.md"))):
        text = open(kf, encoding="utf-8", errors="replace").read()
        rel = os.path.relpath(path, root)   # a config/ KEEP.md describes files sitting flat in TREE, not itself
        if _delim_match(rel, text) or (basename_counts.get(b, 0) == 1 and _delim_match(b, text)):
            return kf
    return None


def _pending_deferred_items(text):
    """[(row_or_None, item_line), ...] for every '- '/'* ' line under a '## DEFERRED' heading -- mirrors
    the gate's pending_sections() awk exactly, prose anywhere else in a PENDING.md is inert by design."""
    out, in_section, row = [], False, None
    for line in text.splitlines():
        if re.match(r"^##\s+DEFERRED(\s|$)", line):
            row = re.sub(r"^##\s+DEFERRED\s*", "", line).rstrip() or None
            in_section = True
            continue
        if re.match(r"^##\s", line):
            in_section = False
            continue
        if in_section and re.match(r"^\s*[-*]\s", line):
            out.append((row, line))
    return out


def _pending_row_of(text):
    """The file-level `ROW:` line -- fallback for a bare `## DEFERRED` heading with no per-section row."""
    m = re.search(r"^\s*ROW:\s*([A-Za-z0-9_.-]+)", text, re.MULTILINE)
    return m.group(1) if m else None


def _pending_row_state(row, po_dir):
    """LIVE | EXPIRED | DANGLING | UNVERIFIABLE -- a direct port of the gate's own pending_row_state():
    a claim file whose LAST line is exactly DONE, or a row listed in QUEUE.done.tsv, is EXPIRED; a row
    listed in QUEUE.tsv (regardless of that row's own state column) is LIVE; otherwise DANGLING; the queue
    being unreadable at all is UNVERIFIABLE. Deliberately NOT re-derived from QUEUE.tsv's state column --
    same two-independent-copies risk the gate itself was built to avoid, just one file mirroring another."""
    q = os.path.join(po_dir, "QUEUE.tsv")
    if not os.access(q, os.R_OK):
        return "UNVERIFIABLE"
    c = os.path.join(po_dir, "claims", row + ".claim")
    if os.path.isfile(c):
        try:
            if any(line.rstrip("\n") == "DONE" for line in open(c, encoding="utf-8", errors="replace")):
                return "EXPIRED"
        except OSError:
            pass
    row_pat = re.compile(r"^[0-9]+\t%s\t" % re.escape(row))
    d = os.path.join(po_dir, "QUEUE.done.tsv")
    if os.access(d, os.R_OK):
        try:
            if any(row_pat.match(line) for line in open(d, encoding="utf-8", errors="replace")):
                return "EXPIRED"
        except OSError:
            pass
    try:
        if any(row_pat.match(line) for line in open(q, encoding="utf-8", errors="replace")):
            return "LIVE"
    except OSError:
        return "UNVERIFIABLE"
    return "DANGLING"


def _pending_deferral(path, root, basename_counts, po_dir):
    """(pending_file, row, state) for the nearest ancestor PENDING.md '## DEFERRED' item matching `path`
    (no config/ tree-wide form -- the gate does not give PENDING.md one either), or None if nothing defers
    it. `row` may be None (no per-section heading and no file-level ROW: line); treated as blocking,
    conservatively, same as the gate's own PBAD-unnamed bucket."""
    b = os.path.basename(path)
    for pf in _ancestor_files(os.path.dirname(path), root, "PENDING.md"):
        text = open(pf, encoding="utf-8", errors="replace").read()
        rel = os.path.relpath(path, os.path.dirname(pf))
        for row, item in _pending_deferred_items(text):
            if _delim_match(rel, item) or (basename_counts.get(b, 0) == 1 and _delim_match(b, item)):
                if row is None:
                    row = _pending_row_of(text)
                state = _pending_row_state(row, po_dir) if row else "LIVE"
                return (pf, row, state)
    return None


# ⭐⭐ THE ONE ATTRIBUTE EXTRACTOR, CALLABLE OUTSIDE A BUILD (hq_B 2026-08-29, for the construct check).
# The builder computed flags inline, so anything else wanting a construct profile had to RE-IMPLEMENT the
# predicates. ⛔ That is the defect this exposure exists to prevent: the construct check must ask "does any
# rungs entry still cover what this deleted file covered", and it can only recover the deleted file's text
# from git history. If the historical profile and the rungs' profile are computed by TWO implementations,
# any disagreement between them is UNATTRIBUTABLE -- you cannot tell a real coverage loss from a drift
# between two copies of the same rule. One function, two callers, or the comparison is not worth making.
# ⚠️ A profile is a LEXICAL approximation. It can show a construct is ABSENT from every rung suite entry; it
# cannot show that the behaviour is adequately tested. Callers must treat it as one-directional.
def attrs_for_text(text, lang="snobol4"):
    """Construct profile for arbitrary source text, in `lang`'s attribute vocabulary. -> {column: 0|1}"""
    if lang not in LANG_TABLES:
        raise ValueError("no attribute table for language %r -- add it deliberately rather than "
                         "borrowing another dialect's columns" % lang)
    cols, _ = LANG_TABLES[lang]
    return {c: fn(text) for c, fn in cols}


def discover_pairs(ROOT, OUTDIR, EXT):
    pairs, excluded = [], []
    seen_excl_prefix = set()
    for dirpath, dirnames, filenames in os.walk(ROOT):
        rel_dir = os.path.relpath(dirpath, ROOT)
        top = rel_dir.split(os.sep)[0] if rel_dir != "." else ""
        if top in EXCLUDE_DIRS:
            if any(f.endswith(EXT) for f in filenames):
                excluded.append((rel_dir.replace(os.sep, "_"), "companion-dependent dir class (%s) -- stays as files" % top))
            dirnames[:] = []
            continue
        dir_companions = sorted({os.path.splitext(f)[1] for f in filenames if os.path.splitext(f)[1] in COMPANION_EXTS})
        for fn in sorted(filenames):
            if not fn.endswith(EXT):
                continue
            if fn.startswith("ALL"):
                continue  # the rungs pair itself is never a source
            # ⭐ (Lon 2026-08-29, "take all those *.sno"): the former excluded classes (probe_loose_*, linker_*,
            # rtx_func_11_*) absorb like everything else -- auto-XFAIL by source verdict keeps documented reds
            # from inflating FAIL, and runtime companions resolve from the config/ subfolder both at source
            # grading and from the rungs (the harness searches <dir>/config since this commit).
            sno = os.path.join(dirpath, fn)
            ref = sno[:-len(EXT)] + ".ref"
            if not os.path.isfile(ref):
                # ⭐ .expected AS A FALLBACK REFERENCE (row master-suite-builder-honours-deferral-contract-
                # and-scopes-absorption, on the row's own cited witnesses). rung36_jcon_scan[2].icn carry a
                # sibling .expected, never a .ref -- the per-rung smoke convention (test_icon_ir_rung_36.sh
                # reads "${base}.expected" the identical way main()'s "plain" absorption reads a .ref: raw
                # expected stdout, compared verbatim) rather than the suite convention. Without this
                # fallback these files are structurally invisible to discover_pairs regardless of the
                # deferral contract, and the row's own verification note ("ready to convert... it is the
                # absorb tooling that blocks it, nothing else") is only true once this gap closes too.
                # ⛔ .ref TAKES PRIORITY WHENEVER BOTH EXIST (unaffected: 6 tests/icon files carry both,
                # e.g. rung03_suspend_gen*, and keep absorbing exactly as before -- this fallback only ever
                # fires for the .ref-less remainder).
                ref_expected = sno[:-len(EXT)] + ".expected"
                if os.path.isfile(ref_expected):
                    ref = ref_expected
                else:
                    continue  # pairless loose witnesses are not board members and are untouched
            rel = os.path.relpath(sno, ROOT)
            fam = rel[:-len(EXT)].replace(os.sep, "_")
            pairs.append((fam, sno, ref, dir_companions))
    # ⛔ NEVER ABSORB A KEEPER OR A DEFERRED FILE (requirement 1 -- see the module comment above
    # _declared_in_keep). basename_counts is computed over exactly this population -- the same "loose
    # candidates with a matching .ref" set the gate's own uniqueness rule needs to decide whether a bare
    # basename mention is unambiguous.
    basename_counts = {}
    for _fam, _sno, _ref, _dc in pairs:
        b = os.path.basename(_sno)
        basename_counts[b] = basename_counts.get(b, 0) + 1
    kept_pairs = []
    for fam, sno, ref, dir_companions in pairs:
        kf = _declared_in_keep(sno, ROOT, basename_counts)
        if kf:
            excluded.append((fam, "KEEPER, declared in %s -- never absorbed (deferral contract)" % os.path.relpath(kf, ROOT)))
            continue
        pd = _pending_deferral(sno, ROOT, basename_counts, PO)
        if pd:
            pf, prow, pstate = pd
            if pstate in ("LIVE", "UNVERIFIABLE"):
                excluded.append((fam, "DEFERRED (row %s: %s), declared in %s -- never absorbed (deferral contract)"
                                       % (prow or "UNNAMED", pstate, os.path.relpath(pf, ROOT))))
                continue
            # else EXPIRED/DANGLING: the deferral is stale -- test_gate_suite_conversion_complete.sh's own
            # PBAD bucket already says "CONVERT these now"; falls through to absorbable below.
        kept_pairs.append((fam, sno, ref, dir_companions))
    return kept_pairs, excluded


# ============================================================ rungs-to-rungs: kind split ===
def split_write(OUTDIR, EXT, lang, _CO, _CC, do_write):
    """⭐ --split-write: emit Lon's END STATE -- a ONE-LINERS file and a MULTI-LINERS file side by side.

    Lon 2026-08-29/30 (routed by ceo): per language, one-liners and multi-liners live in SEPARATE files in
    one flat dir. ceo ruled (2026-08-30) that the write half belongs HERE rather than in the verify-first
    splitter, because this file already owns rungs writing; reading THE rungs as input is a
    RUNGS-TO-RUNGS verb, distinct from the source rebuild whose zero-pairs refusal stays untouched.

    ⛔⭐ THE SPLIT REMOVES A CORRECTNESS INVARIANT THAT IS CURRENTLY HELD BY CONVENTION, and this is the
    strongest argument for the format rather than a side effect of it. write_suite()'s own docstring
    records that format-(B) blocks MUST be emitted LAST: a banner block ends only at the next banner or
    EOF, so any one-line entry written after a block is SILENTLY SWALLOWED into that block's body --
    measured on probe/eval, 21 entries written and 22 read back, one duplicated. In separate files a
    one-liner CANNOT be swallowed, because the one-liners file contains no blocks at all. The ordering
    rule stops being something a writer must remember and becomes a property of the layout.

    ⛔ IT DOES NOT ADOPT THE SPLIT. ALL.* is left exactly as it is; nothing re-points; no source is
    deleted. ceo adopted the ordering law as stated: the split files land in one commit, ADOPTION is its
    own commit gated on the per-entry named-set equality proof, never both together -- otherwise a moved
    floor cannot be attributed to a converter defect or a real regression.

    Verification before writing, and all three must hold (redundant on purpose -- a duplicate that
    replaces a lost entry passes a count and fails a set):
      1. PARTITION  every entry lands in exactly one side; union == input; intersection empty.
      2. COUNT      len(one) + len(multi) == len(input), asserted separately from (1).
      3. ROUNDTRIP  each emitted pair is re-read and must return its own entries, by name and by body.
    """
    src = os.path.join(OUTDIR, "ALL" + EXT)
    ref = os.path.join(OUTDIR, "ALL.ref")
    if not (os.path.isfile(src) and os.path.isfile(ref)):
        sys.stderr.write("REFUSED: --split-write needs an existing rungs pair at %s / ALL.ref -- this is a\n"
                         "  RUNGS-TO-RUNGS verb, not a rebuild. Build the rungs first.\n" % src)
        raise SystemExit(2)
    if lang == "snobol4":
        entries = h.read_suite(src, ref, in_path=h.sidecar_in_path(src), x_path=h.sidecar_xfail_path(src))
    else:
        entries = h.read_block_suite(src, ref, h.banner_re_for(_CO, _CC),
                                     in_path=h.sidecar_in_path(src), x_path=h.sidecar_xfail_path(src))
    if not entries:
        sys.stderr.write("REFUSED: rungs at %s read back ZERO entries -- an empty split is not a split you\n"
                         "  can verify, and it would silently retire the whole floor.\n" % src)
        raise SystemExit(2)
    one   = [e for e in entries if e.kind == "line"]
    multi = [e for e in entries if e.kind != "line"]
    n_one, n_multi, n_all = len(one), len(multi), len(entries)
    # (2) count, asserted independently of (1)
    if n_one + n_multi != n_all:
        sys.stderr.write("FAILED: count disagreement %d + %d != %d\n" % (n_one, n_multi, n_all))
        raise SystemExit(1)
    # (1) partition by NAME identity, not arithmetic
    s_one, s_multi, s_all = {e.name for e in one}, {e.name for e in multi}, {e.name for e in entries}
    if (s_one | s_multi) != s_all or (s_one & s_multi):
        sys.stderr.write("FAILED: partition is not exact (union/intersection check)\n")
        raise SystemExit(1)
    print("rungs  : %s (%d entries)" % (src, n_all))
    print("one-liners  (kind=line ) : %d" % n_one)
    print("multi-liners(kind=block) : %d" % n_multi)
    print("\u2705 partition exact, counts agree")
    if not do_write:
        print("\nVERIFY-ONLY. Nothing written. Add --write to emit the two pairs.")
        return 0
    out = []
    for tag, subset in (("ONE", one), ("MULTI", multi)):
        o_src = os.path.join(OUTDIR, tag + EXT)
        o_ref = os.path.join(OUTDIR, tag + ".ref")
        if lang == "snobol4":
            # ⛔⭐ THE SIDECARS ARE NOT OPTIONAL, AND OMITTING THEM COST NINE ENTRIES ON THE FIRST RUN.
            # write_suite() emits only .sno/.ref; stdin and xfail live in ALL.in / ALL.xfail and the
            # rungs build writes them SEPARATELY (see the snobol4 branch of the main write). Dropping
            # them here silently stripped stdin from every entry that had it -- MEASURED: the rungs
            # carries exactly 9 stdin entries, ALL of them kind=block, and MULTI graded 666/10 against
            # the combined rungs' contribution of 675/1. Nine entries in, nine entries lost.
            h.write_suite(subset, o_src, o_ref)
            # ⛔ sidecar_in_path()/sidecar_xfail_path() are DISCOVERY helpers -- they return the path
            # only if the file ALREADY EXISTS, else None. They answer "where is the sidecar", and I
            # used them as "where should the sidecar go": on a fresh output they return None and the
            # write crashed with `stat: path should be string ... not NoneType`. The rungs build
            # constructs these names directly (out_in = OUTDIR/ALL.in); do the same here.
            _oi = os.path.join(OUTDIR, tag + ".in")
            _ox = os.path.join(OUTDIR, tag + ".xfail")
            if not h.write_stdin_sidecar(subset, _oi, "*", "") and os.path.exists(_oi):
                os.remove(_oi)
            if not h.write_xfail_sidecar(subset, _ox, "*", "") and os.path.exists(_ox):
                os.remove(_ox)
        else:
            h.write_block_suite(subset, o_src, o_ref, _CO, _CC,
                                out_in=h.sidecar_in_path(o_src), out_x=h.sidecar_xfail_path(o_src))
        out.append((tag, o_src, o_ref, subset))
    # (3) ROUNDTRIP -- re-read what was just written and require it back, by name AND by body.
    for tag, o_src, o_ref, subset in out:
        if lang == "snobol4":
            back = h.read_suite(o_src, o_ref, in_path=h.sidecar_in_path(o_src), x_path=h.sidecar_xfail_path(o_src))
        else:
            back = h.read_block_suite(o_src, o_ref, h.banner_re_for(_CO, _CC),
                                      in_path=h.sidecar_in_path(o_src), x_path=h.sidecar_xfail_path(o_src))
        if len(back) != len(subset) or {e.name for e in back} != {e.name for e in subset}:
            sys.stderr.write("FAILED: %s did not round-trip -- wrote %d, read %d\n" % (tag, len(subset), len(back)))
            raise SystemExit(1)
        by = {e.name: e for e in subset}
        # ⛔⭐ COMPARE stdin AND xfail, NOT JUST THE BODY. The first version of this check compared
        # sno_lines alone and PASSED while the writer above was silently dropping stdin -- the check
        # tested a narrower property than the claim it was making, which is the exact defect class this
        # tool exists to guard against, committed inside the guard. A round trip that does not carry
        # every field the grader reads is not a round trip.
        for e in back:
            o = by[e.name]
            if list(e.sno_lines) != list(o.sno_lines):
                sys.stderr.write("FAILED: %s entry %s changed BODY across the round trip\n" % (tag, e.name))
                raise SystemExit(1)
            if (e.stdin or None) != (o.stdin or None):
                sys.stderr.write("FAILED: %s entry %s LOST OR CHANGED STDIN across the round trip -- the\n"
                                 "  .in sidecar was not carried. This silently turns a passing entry red.\n" % (tag, e.name))
                raise SystemExit(1)
            if bool(e.xfail) != bool(o.xfail):
                sys.stderr.write("FAILED: %s entry %s changed XFAIL across the round trip\n" % (tag, e.name))
                raise SystemExit(1)
        print("\u2705 %-5s round-trips: %d entries, bodies byte-identical -> %s" % (tag, len(back), o_src))
    print("\n\u26d4 WRITTEN, NOT ADOPTED. ALL.* is untouched and every consumer still reads it.")
    print("   Adoption is a SEPARATE commit gated on the per-entry named-set equality proof")
    print("   (row snobol4-floor-cutover-to-the-one-flat-suite-board-equality-first).")
    return 0


# ⛔⭐ REAL ARGUMENT PARSING (requirement 4). The previous shape hand-walked sys.argv per flag, with no
# catch-all: an unrecognized token -- including a plain typo -- fell through every `if`/`elif` untouched
# and the run proceeded on defaults (`--lang snobol4`). MEASURED: `python3 util_build_rungs_suite.py
# --help` REBUILT THE LIVE SNOBOL4 RUNGS (2335 insertions / 2344 deletions) because "--help" matched
# nothing and the default build ran anyway -- for this script, the universal "ask it what it does" gesture
# was a write to shared corpus. argparse (stdlib, no new dependency) refuses rc=2 on any unrecognized
# argument by construction, and its auto-added -h/--help prints usage and calls sys.exit(0) BEFORE a single
# line of build logic below ever runs -- both properties for free, rather than a second hand-rolled
# validator that could itself drift from the flags actually implemented.
def _build_arg_parser():
    p = argparse.ArgumentParser(
        prog="util_build_rungs_suite.py",
        description="Builds corpus/tests/<lang>/{ALL.<ext>, ALL.ref, ALL.csv} from every absorbable loose "
                     "suite pair under corpus/tests/<lang>/, merging into any existing rungs (merge-never-"
                     "replace). Never absorbs a file a KEEP.md declares a permanent keeper, or that a "
                     "PENDING.md defers to another row -- see corpus/tests/<lang>/**/{KEEP,PENDING}.md.")
    p.add_argument("--lang", default="snobol4", help="snobol4 (default) | icon | prolog | raku | snocone | rebus | pascal")
    p.add_argument("--absorb-only", default=None, metavar="F1,F2,...",
                    help="only ABSORB these families this run; every other absorbable family stays loose, "
                         "untouched (composes freely with --delete-absorbed/--family/--only, which still "
                         "govern deletion of whatever this run absorbs)")
    p.add_argument("--delete-absorbed", action="store_true",
                    help="after a successful, verified absorption, delete the now-redundant source pairs")
    p.add_argument("--family", default=None, metavar="PREFIX", help="scope --delete-absorbed to families starting with PREFIX")
    p.add_argument("--only", default=None, metavar="F1,F2,...", help="scope --delete-absorbed to exactly these families")
    p.add_argument("--allow-drop-origin", default=None, metavar="O1,O2,...",
                    help="name origin(s) whose deliberate retirement should not refuse the rebuild (surgical, never a blanket --force)")
    p.add_argument("--resort", action="store_true",
                   help="re-sort the EXISTING rungs into the builder's own order (xfail, feature count, line count, name) and rewrite "
                        "ALL.<ext>/ALL.ref/ALL.csv. Absorbs nothing; permutes entries and changes nothing else, verified before it commits. "
                        "A promotion must run this in the same commit or `rank <= N` stops selecting the greenest N.")
    p.add_argument("--reindex", action="store_true",
                   help="CSV-ONLY: recompute every ALL.csv column from the EXISTING ALL.<ext>/ALL.ref pair and write ONLY ALL.csv. "
                        "Absorbs nothing and reorders nothing -- rank is the entry's position in the rungs as it already stands. "
                        "REFUSES rc=2 if any loose absorbable pair is present, unless --absorb-only names it (under --reindex that "
                        "flag ACKNOWLEDGES a pair, it never absorbs it).")
    p.add_argument("--split-write", action="store_true",
                    help="rungs-to-rungs: emit ALL.* split into ONE.*/MULTI.* by entry kind; verify-only unless --write")
    p.add_argument("--write", action="store_true", help="with --split-write, actually write the split files")
    # -- THE BUILDER EXTENSION (task master-builder-absorbs-demos-benchmarks-programs-and-loose-pairs-
    # additively, Lon 2026-09-04): absorb corpus/demos/<lang> and corpus/benchmarks/<lang> into the SAME
    # rungs ADDITIVELY -- unlike every mode above, the source file and any committed .s artifact are
    # NEVER deleted or moved. See additive_absorb()'s own docstring for the full contract.
    p.add_argument("--additive", action="store_true",
                    help="absorb corpus/demos/<lang>/ and corpus/benchmarks/<lang>/ into ALL.<ext>/ALL.ref/ALL.csv "
                         "ADDITIVELY (see --from): sources and any committed .s artifacts are never touched or "
                         "deleted, unlike --delete-absorbed which is the ordinary loose-pair path's own verb. Each "
                         "candidate runs a small, sub-second, deterministic recipe; a pre-existing loose .ref is "
                         "RE-CONFIRMED against a fresh oracle run (never trusted blindly), else one is cut fresh "
                         "from the language's oracle through lib_oracle_flags.sh and cross-checked against scrip "
                         "m3 AND m4 -- the same three-way agreement cmd_capture_oracle_refs already uses, reused "
                         "rather than re-invented. A sibling <stem>.ast-only marker absorbs a parser-only fixture "
                         "via --dump-ast instead (never sent to the oracle). Anything that "
                         "cannot run with output -- module, non-deterministic (oracle/m3/m4 disagree), or over "
                         "budget -- is named in ALL.excluded.txt with a reason, never silently dropped.")
    p.add_argument("--from", dest="from_cats", default="demos,benchmarks", metavar="CAT1,CAT2,...",
                    help="with --additive: which source trees to absorb from this run -- demos, benchmarks, "
                         "programs, tests (comma list; default demos,benchmarks). `programs` is a real category "
                         "name but corpus/programs/ absorbs NOTHING yet: Lon 2026-09-04 excluded it from the "
                         "unabsorbed census (util_unabsorbed_census.py, verbatim 'Go ahead and exclude programs/* "
                         "folders'), and this builder honours the same ruling by recording it in ALL.excluded.txt "
                         "rather than walking it -- naming it here is truthful, not silently ignored. `tests` "
                         "absorbs corpus/tests/<lang>/'s OWN loose-noref/fixture sources (the ones "
                         "util_unabsorbed_census.py calls 'fixture'/'loose no-ref') -- unlike demos/benchmarks "
                         "this walks the rungs' own home directory, so it skips anything discover_pairs "
                         "already owns (a .ref/.expected/.std sibling) or that lives under config/. "
                         "`scrip_test`/`snocone_ladder` are the same tests-shaped walk pointed at "
                         "corpus/tests/scrip_test/ and corpus/tests/snocone/ladder/ respectively -- fixed "
                         "trees outside corpus/tests/<lang>/ that still carry stray runnable sources by "
                         "extension (e.g. corpus/tests/snocone/ladder/prog/*.sno).")
    p.add_argument("--recipe-timeout", type=float, default=3.0, metavar="SECONDS",
                    help="with --additive: per-entry wall-clock budget for the oracle/m3/m4 recipe run; a program "
                         "still running past this is 'over budget' and excluded, never absorbed on a truncated result")
    p.add_argument("--selftest", action="store_true",
                    help="prove the --additive machinery end-to-end on an isolated scratch tree this process "
                         "builds itself (one demo, one benchmark reading its recipe off stdin, one parser-only "
                         "--dump-ast fixture, one non-terminating program) -- the real corpus and the real ALL.* "
                         "rungs are never opened. Prints SELFTEST PASS/FAIL as its last line.")
    return p



def rungs_sort_key(entry, flags):
    """THE ONE AUTHORITY for the rungs' order (Lon's level ruling: a level is a PREFIX of the list, so
    `rank <= N` must select the greenest N). Green before xfail, then fewer features, then shorter, then name.

    ⛔ EXTRACTED FROM main()'s inline lambda 2026-09-03 so the ORDER GATE can import it instead of re-typing
    it. A guard that keeps its own copy of the rule drifts from the thing it guards and then both are wrong
    together -- this project has already paid for that twice (util_oracle_flag_sweep.sh, test_gate_argnote_sweep.sh).
    """
    return (int(bool(entry.xfail)), sum(flags.values()), len(entry.sno_lines), entry.name)


def rungs_file_key(entry, flags):
    """THE ORDER THE RUNGS FILE CAN ACTUALLY STORE. write_suite() ALWAYS emits every kind="line"
    entry before every other entry, unconditionally (write_suite's own docstring: a format-(B) block
    ends only at the next banner or EOF, so a one-liner following a block would be silently swallowed
    into it -- measured, hq_C 2026-08-28, `ev_fn_beauty_shape` duplicated). That partition is therefore
    a hard structural fact about the file, not a policy choice, so anything that predicts or verifies
    the rungs' on-disk order must predict THIS order, not rungs_sort_key's alone.

    ⛔ MEASURED 2026-09-05: resort_rungs()'s own post-write round-trip check, and the order gate, both
    compared against plain rungs_sort_key order and disagreed with write_suite's actual output on the
    mixed-kind SNOBOL4 rungs (818 line + 1041 block entries) -- resort refused ("re-read order does
    not match the intended order") on a rung suite that was, by every other measure, internally consistent
    (its committed ALL.sno physical order and ALL.csv row order already agreed with each other).

    For every OTHER language's rungs, every entry shares one kind, so this is byte-identical to
    rungs_sort_key alone -- zero behaviour change there. Still "green before xfail, fewer features,
    shorter, then name" -- WITHIN each kind -- so `rank <= N` still selects the greenest N of a kind.
    """
    return (0 if entry.kind == "line" else 1,) + rungs_sort_key(entry, flags)


def resort_rungs(OUTDIR, EXT, lang, h, _CO, _CC, COLS, loose_families, acknowledged):
    """Re-sort the rungs already on disk into the builder's own order and rewrite ALL.<ext>/ALL.ref/ALL.csv.

    WHY (ceo ruling 2026-09-03 on hq_B's routed question): Lon's level law says a level is a PREFIX of the
    rungs, so `rank <= N` must select the greenest N. A PROMOTION CHANGES AN ENTRY'S SORT KEY -- flipping
    xfail moves it out of the xfail block -- so a promotion that rewrites only the three marker locations
    leaves the file sorted under the old key and the law quietly stops being true. Nothing looks wrong: the
    suite and its index still agree with each other and every marker gate is green.

    ⛔ THE CHURN IS THE POINT AND IT IS LARGE BY CONSTRUCTION. Re-sorting moves whole entry BLOCKS, so a
    commit that changes NO program text can rewrite most of the file. The commit must say so and prove
    content-invariance (same entry set, same per-entry bytes, order only) rather than leave a reviewer to
    infer it from a diff that looks like a rewrite.
    """
    out_sno = os.path.join(OUTDIR, "ALL" + EXT); out_ref = os.path.join(OUTDIR, "ALL.ref")
    out_in = os.path.join(OUTDIR, "ALL.in"); out_x = os.path.join(OUTDIR, "ALL.xfail")
    out_csv = os.path.join(OUTDIR, "ALL.csv")
    for _p in (out_sno, out_ref):
        if not os.path.isfile(_p):
            sys.stderr.write("REFUSED: --resort needs an existing rungs; %s is missing.\n" % _p); return 2
    unacknowledged = sorted(loose_families - acknowledged)
    if unacknowledged:
        sys.stderr.write("REFUSED: --resort found %d loose absorbable famil(y/ies); absorbing and re-sorting in one\n"
                         "   step would make an ordering change indistinguishable from an absorption in the diff:\n" % len(unacknowledged))
        for f in unacknowledged:
            sys.stderr.write("     %s\n" % f)
        sys.stderr.write("   Absorb them first, or name them with --absorb-only to proceed with the resort alone.\n")
        return 2
    if lang == "snobol4":
        entries = h.read_suite(out_sno, out_ref, in_path=h.sidecar_in_path(out_sno), x_path=h.sidecar_xfail_path(out_sno))
    else:
        entries = h.read_block_suite(out_sno, out_ref, h.banner_re_for(_CO, _CC),
                                     in_path=h.sidecar_in_path(out_sno), x_path=h.sidecar_xfail_path(out_sno))
    if not entries:
        sys.stderr.write("REFUSED: --resort read 0 entries -- refusing to rewrite a rung suite it could not read.\n"); return 2
    before = [e.name for e in entries]
    flags_of = {e.name: {c: fn2("\n".join(e.sno_lines)) for c, fn2 in COLS} for e in entries}
    ordered = sorted(entries, key=lambda e: rungs_file_key(e, flags_of[e.name]))
    after = [e.name for e in ordered]
    if before == after:
        print("--resort: %d entries already in the builder's order -- nothing written." % len(entries), file=sys.stderr)
        return 0
    if sorted(before) != sorted(after):
        sys.stderr.write("REFUSED: the sort changed the ENTRY SET (%d -> %d unique) -- that is not a reorder.\n"
                         % (len(set(before)), len(set(after)))); return 2
    csv_origin = {}
    # ⛔⭐ heap_kb IS CARRIED FORWARD, NEVER RE-DERIVED (Lon 2026-09-23 / CEO-1167). A declaration is a
    # MEASUREMENT a seat paid for with two readings; nothing in an entry's text can regenerate it, so a
    # rebuild or a resort that dropped the cell would silently return a 16384 KB program to the shipped
    # 128 and turn a cured row back into a capacity red with no diff naming the cause.
    csv_heap = {}
    csv_stack = {}    # stack_kb, carried forward on the same contract (CEO-1225)
    csv_cmd = {}      # compile_args and run_args, carried forward on the same contract (clause 8 (f), CEO-1281)
    cmd_cols = carried_cmd_cols(out_csv)
    if os.path.isfile(out_csv):
        for row in csv.DictReader(open(out_csv)):
            csv_origin[row["entry"]] = row.get("origin", "")
            csv_heap[row["entry"]] = (row.get("heap_kb") or "").strip()
            csv_stack[row["entry"]] = (row.get("stack_kb") or "").strip()
            csv_cmd[row["entry"]] = {c: (row.get(c) or "").strip() for c in CMD_COLS}
    _tag = ".tmp-%d" % os.getpid()
    tmp_sno, tmp_ref, tmp_in, tmp_x, tmp_csv = out_sno + _tag, out_ref + _tag, out_in + _tag, out_x + _tag, out_csv + _tag
    def _cleanup():
        for q in (tmp_sno, tmp_ref, tmp_in, tmp_x, tmp_csv):
            if os.path.exists(q):
                os.remove(q)
    try:
        for i, e in enumerate(ordered, 1):
            e.seq = i
        if lang == "snobol4":
            h.write_suite(ordered, tmp_sno, tmp_ref)
            wrote_in = h.write_stdin_sidecar(ordered, tmp_in, "*", "")
            wrote_x = h.write_xfail_sidecar(ordered, tmp_x, "*", "")
            reread = h.read_suite(tmp_sno, tmp_ref, in_path=(tmp_in if wrote_in else None), x_path=(tmp_x if wrote_x else None))
        else:
            h.write_block_suite(ordered, tmp_sno, tmp_ref, _CO, _CC)
            wrote_in = h.write_stdin_sidecar(ordered, tmp_in, _CO, _CC)
            wrote_x = h.write_xfail_sidecar(ordered, tmp_x, _CO, _CC)
            reread = h.read_block_suite(tmp_sno, tmp_ref, h.banner_re_for(_CO, _CC),
                                        in_path=(tmp_in if wrote_in else None), x_path=(tmp_x if wrote_x else None))
        # ⛔ CONTENT-INVARIANCE, CHECKED BEFORE ANYTHING REAL IS TOUCHED: a resort may permute entries and may
        # change NOTHING else. Same names, and the same body bytes under each name.
        if [x.name for x in reread] != after:
            sys.stderr.write("REFUSED: re-read order does not match the intended order -- not committing.\n"); _cleanup(); return 2
        body_before = {e.name: "\n".join(e.sno_lines) for e in entries}
        body_after = {e.name: "\n".join(e.sno_lines) for e in reread}
        if body_before != body_after:
            _bad = [n for n in body_before if body_before[n] != body_after.get(n)]
            sys.stderr.write("REFUSED: %d entr(y/ies) changed CONTENT during a reorder (first: %s) -- not committing.\n"
                             % (len(_bad), _bad[0] if _bad else "?")); _cleanup(); return 2
        with open(tmp_csv, "w", newline="") as f:
            w = csv.writer(f, lineterminator="\n")
            w.writerow(["rank", "entry", "origin", "family", "kind", "xfail", "n_lines", "heap_kb", "stack_kb"] + cmd_cols + [c for c, _ in COLS])
            for rank, e in enumerate(ordered, 1):
                origin = csv_origin.get(e.name) or ("rungs__%s" % e.name)
                fam = origin.split("__", 1)[0]
                w.writerow([rank, e.name, origin, fam, e.kind, int(bool(e.xfail)), len(e.sno_lines),
                            (csv_heap.get(e.name, "") or DEFAULT_HEAP_KB), (csv_stack.get(e.name, "") or DEFAULT_STACK_KB)] + [csv_cmd.get(e.name, {}).get(c, "") for c in cmd_cols] + [flags_of[e.name][c] for c, _ in COLS])
    except BaseException:
        _cleanup(); raise
    os.replace(tmp_sno, out_sno); os.replace(tmp_ref, out_ref); os.replace(tmp_csv, out_csv)
    if wrote_in:
        os.replace(tmp_in, out_in)
    elif os.path.exists(out_in):
        os.remove(out_in)
    if wrote_x:
        os.replace(tmp_x, out_x)
    elif os.path.exists(out_x):
        os.remove(out_x)
    moved = sum(1 for a, b in zip(before, after) if a != b)
    print("--resort: %d entries re-sorted into the builder's order (%d changed position); content invariant, order only."
          % (len(ordered), moved), file=sys.stderr)
    return 0

def reindex_csv_only(OUTDIR, EXT, lang, h, _CO, _CC, COLS, loose_families, acknowledged):
    """Recompute ALL.csv from the rungs pair already on disk. Writes ONE file and reorders nothing.

    WHY THIS EXISTS (row master-builder-needs-a-csv-only-reindex-path, hq_B 2026-09-02): a promotion that
    changes program text -- 55 `:- initialization(main).` additions, an xfail flip -- makes ALL.csv's derived
    columns stale, and the only rebuild path ALSO ABSORBED whatever happened to be loose that day (404 -> 408
    on the prolog tree). So the choice was hand-edit the index or take an unrelated absorption as a side
    effect of a re-index. Both are wrong for the same reason: the index is supposed to be a pure function of
    the suite, and neither route lets you SAY that.

    ⛔ IT DOES NOT REORDER, and that is a deliberate limit, not an oversight. The full builder sorts by
    (xfail, feature count, line count, name) so `rank` doubles as the level-ordering law -- green before
    xfail. Flipping an xfail therefore changes an entry's sort key, so a promotion arguably OWES a re-sort.
    Re-sorting here would churn ALL.pl and ALL.ref on every index rebuild and would break this row's own
    oracle (a correct hand-edited CSV must reproduce byte-identically). Rank is the entry's POSITION in the
    rungs as it stands; keeping the file and the index agreeing with each other is this function's whole
    job. Whether a promotion should re-sort the rungs is a corpus-policy question, routed, not decided here.
    """
    out_csv = os.path.join(OUTDIR, "ALL.csv")
    rungs_sno = os.path.join(OUTDIR, "ALL" + EXT)
    rungs_ref = os.path.join(OUTDIR, "ALL.ref")
    for _p in (rungs_sno, rungs_ref):
        if not os.path.isfile(_p):
            sys.stderr.write("REFUSED: --reindex needs an existing rungs; %s is missing -- there is nothing to index.\n" % _p)
            return 2
    unacknowledged = sorted(loose_families - acknowledged)
    if unacknowledged:
        sys.stderr.write("REFUSED: --reindex found %d loose absorbable famil(y/ies) under this tree -- nothing written:\n" % len(unacknowledged))
        for f in unacknowledged:
            sys.stderr.write("     %s\n" % f)
        sys.stderr.write("   Re-indexing a tree with unabsorbed sources produces an index that is current for the rungs and\n"
                         "   silent about the rest, which reads as 'everything is accounted for'. Absorb them with a normal\n"
                         "   run, or name them with --absorb-only to say you know they are there and still want CSV-only.\n")
        return 2
    if lang == "snobol4":
        entries = h.read_suite(rungs_sno, rungs_ref, in_path=h.sidecar_in_path(rungs_sno), x_path=h.sidecar_xfail_path(rungs_sno))
    else:
        entries = h.read_block_suite(rungs_sno, rungs_ref, h.banner_re_for(_CO, _CC),
                                     in_path=h.sidecar_in_path(rungs_sno), x_path=h.sidecar_xfail_path(rungs_sno))
    if not entries:
        sys.stderr.write("REFUSED: --reindex read 0 entries from %s -- refusing to write an empty index over a real one.\n" % rungs_sno)
        return 2
    csv_origin = {}
    # ⛔⭐ heap_kb IS CARRIED FORWARD, NEVER RE-DERIVED (Lon 2026-09-23 / CEO-1167). A declaration is a
    # MEASUREMENT a seat paid for with two readings; nothing in an entry's text can regenerate it, so a
    # rebuild or a resort that dropped the cell would silently return a 16384 KB program to the shipped
    # 128 and turn a cured row back into a capacity red with no diff naming the cause.
    csv_heap = {}
    csv_stack = {}    # stack_kb, carried forward on the same contract (CEO-1225)
    csv_cmd = {}      # compile_args and run_args, carried forward on the same contract (clause 8 (f), CEO-1281)
    cmd_cols = carried_cmd_cols(out_csv)
    if os.path.isfile(out_csv):
        for row in csv.DictReader(open(out_csv)):
            csv_origin[row["entry"]] = row.get("origin", "")
            csv_heap[row["entry"]] = (row.get("heap_kb") or "").strip()
            csv_stack[row["entry"]] = (row.get("stack_kb") or "").strip()
            csv_cmd[row["entry"]] = {c: (row.get(c) or "").strip() for c in CMD_COLS}
    tmp_csv = out_csv + ".tmp-%d" % os.getpid()
    try:
        with open(tmp_csv, "w", newline="") as f:
            w = csv.writer(f, lineterminator="\n")
            w.writerow(["rank", "entry", "origin", "family", "kind", "xfail", "n_lines", "heap_kb", "stack_kb"] + cmd_cols + [c for c, _ in COLS])
            for rank, e in enumerate(entries, 1):
                text = "\n".join(e.sno_lines)
                flags = {c: fn(text) for c, fn in COLS}
                origin = csv_origin.get(e.name) or ("rungs__%s" % e.name)
                fam = origin.split("__", 1)[0]
                w.writerow([rank, e.name, origin, fam, e.kind, int(bool(e.xfail)), len(e.sno_lines),
                            (csv_heap.get(e.name, "") or DEFAULT_HEAP_KB), (csv_stack.get(e.name, "") or DEFAULT_STACK_KB)] + [csv_cmd.get(e.name, {}).get(c, "") for c in cmd_cols] + [flags[c] for c, _ in COLS])
    except BaseException:
        if os.path.exists(tmp_csv):
            os.remove(tmp_csv)
        raise
    os.replace(tmp_csv, out_csv)
    print("--reindex: %d entries indexed from %s -- ALL.csv rewritten, nothing else touched." % (len(entries), os.path.basename(rungs_sno)), file=sys.stderr)
    return 0


# ============================================================ additive: demos/benchmarks (THE BUILDER EXTENSION) ===
# Row master-builder-absorbs-demos-benchmarks-programs-and-loose-pairs-additively (Lon 2026-09-04, verbatim in
# substance: "For every source from every language that we've generated or that existed in corpus which is not
# part of any third-party package, if you can get it to run and it has output then add that to the test suite
# list... keep the packages in their existing form and get them working and generate REF files and also add
# those to our test suites.")
#
# ⛔ THE ONE THING THAT MAKES THIS A DIFFERENT MODE, NOT A FLAG ON THE EXISTING ONE: nothing under corpus/demos/
# or corpus/benchmarks/ is ever deleted or moved. Those trees are read IN PLACE by other rows (the *_s_artifacts
# regen scripts, the benchmark/triangulation harnesses, DEMO-SCALE.tsv) -- "additive" is a safety property here,
# not a style choice, so this mode has no --delete-absorbed twin and never will.
#
# ⛔ corpus/programs/ IS NAMED (see --from) BUT NEVER WALKED. util_unabsorbed_census.py excludes it from its own
# OWED count as of 2026-09-04 ("Go ahead and exclude programs/* folders" -- Lon, the 2026-08-27 parser-only
# ruling on that tree stands); this builder honours the identical ruling rather than absorbing a tree the
# project's own census no longer treats as an obligation.
#
# ⭐ ORACLE REUSE, NOT REINVENTION: cmd_capture_oracle_refs (corpus_suite_harness.py) is this project's one
# existing "mint a ref from a live oracle" procedure, with a list of hard-won edge cases (the empty-agreement
# guard, bare-basename argv, the stdin-feed-changes-nothing control). _additive_classify_and_run below reuses
# resolve_oracle_bin/run_oracle/run_m3/run_m4 exactly as that function does; the only genuinely new things are
# per-FILE dispatch instead of per-family-glob, and a recipe expressed as stdin only (see its own docstring for
# why argv-extra recipes are deliberately out of scope here).
ADDITIVE_ORACLE_LANGS = {"snobol4", "prolog", "icon", "pascal", "raku"}   # resolve_oracle_bin's own known set (its own refuse())
_EXTRA_TEST_TREES = {"scrip_test": "scrip_test", "snocone_ladder": "snocone/ladder"}   # --from categories whose
# src_dir is a FIXED corpus/tests/<path> outside corpus/tests/<lang>/ and outside demos/benchmarks -- see the
# --from arg's category dispatch below for why these exist.


def _additive_walk(src_dir, ext):
    """Every <ext> file under src_dir (recursive, sorted), excluding the rungs itself and dotfiles. No pair
    discovery (unlike discover_pairs): a demo/benchmark is one program, not a suite family, and its companions
    (.ref, .input/.in/.recipe.in, .ast-only) are looked up by exact stem in the classifier, never walked as
    candidates in their own right."""
    if not os.path.isdir(src_dir):
        return []
    out = []
    for dirpath, _dn, filenames in os.walk(src_dir):
        for fn in filenames:
            if fn.endswith(ext) and not fn.startswith("ALL") and not fn.startswith("."):
                out.append(os.path.join(dirpath, fn))
    return sorted(out)


def _additive_walk_tests(src_dir, ext, skip_loose_pairs=True):
    """Like _additive_walk, but for the "tests" category ONLY: src_dir here IS corpus/tests/<lang>, the same
    directory the base (non-additive) loose-pair path (discover_pairs) already owns, and the same directory
    ALL.<ext>/ALL.ref/ALL.csv themselves live in -- so this walk must not re-offer a file that path already
    handles or that IS the rungs. Skipped, in addition to _additive_walk's ALL*/dotfile exclusions: anything
    already carrying a .ref/.expected/.std sibling (a loose pair -- discover_pairs's own job, not this one;
    re-offering it here would classify it fresh under a DIFFERENT origin naming scheme and duplicate it into
    the rungs under a second name), and anything inside a config/ directory (KEEP.md and other bookkeeping
    live there, never source under test -- see the KEEP.md convention util_unabsorbed_census.py's own OWED
    list does not know about: an -INCLUDE-only companion of an EXISTING rungs entry is not itself owed, and
    the correct fix for that census blind spot is naming it in ALL.excluded.txt with a reason, not walking it
    here at all -- config/ is excluded from the walk defensively, in case a future KEEP.md sibling is dropped
    beside its family rather than under config/).

    ⛔⭐⭐ skip_loose_pairs IS TRUE ONLY WHEN discover_pairs ACTUALLY OWNS THIS DIRECTORY (hq_S 2026-09-12, row
    raku-absorb-every-owed-source). The skip above is a DEFERRAL -- "not mine, the other path has it" -- and it
    is correct for the `tests` category, whose src_dir IS corpus/tests/<lang>/, the one tree discover_pairs
    walks. It was ALSO being applied to the _EXTRA_TEST_TREES categories (scrip_test, snocone_ladder), which
    discover_pairs NEVER walks -- so for those trees the deferral handed the file to nobody and every loose
    pair under corpus/tests/scrip_test/<lang>/ stayed owed permanently, deferred to a path that does not go
    there. ⭐ THE TELL WAS IN THE CENSUS ALL ALONG AND READ AS A BACKLOG INSTEAD OF A BUG: raku 15, prolog 4,
    snobol4 and icon their own share -- a residue that no number of absorption runs could ever move, because
    running the tool again re-made the same deferral. A file skipped by both halves of a two-part walk is
    invisible in exactly the way a file skipped by one half is not: each half is individually defensible.
    ⛔ The duplicate-origin hazard the paragraph above warns about does NOT apply to the extra trees for the
    same reason the deferral does not: discover_pairs cannot absorb what it never walks, so there is no second
    absorption to collide with. The hazard is real only where both paths reach the same file."""
    if not os.path.isdir(src_dir):
        return []
    out = []
    for dirpath, _dn, filenames in os.walk(src_dir):
        if os.path.basename(dirpath) == "config":
            continue
        for fn in filenames:
            if not (fn.endswith(ext) and not fn.startswith("ALL") and not fn.startswith(".")):
                continue
            stem = os.path.join(dirpath, fn)[: -len(ext)]
            if skip_loose_pairs and any(os.path.isfile(stem + s) for s in (".ref", ".expected", ".std")):
                continue
            out.append(os.path.join(dirpath, fn))
    return sorted(out)


def _additive_stdin_for(stem):
    """Declared recipe stdin, nearest-convention-first: a demo's own pre-existing .input/.in (the real
    convention already in use -- corpus/demos/snobol4/claws5/claws5.input) wins over a purpose-built
    .recipe.in, so absorption re-uses whatever stdin a demo already runs with rather than inventing a
    second, competing convention. Returns None (i.e. /dev/null) if neither exists -- the correct default
    for the common no-input demo/benchmark, and safe: /dev/null is immediate EOF, never a hang."""
    for suffix in (".input", ".in", ".recipe.in"):
        cand = stem + suffix
        if os.path.isfile(cand):
            return open(cand, encoding="utf-8", errors="replace").read(), cand
    return None, None


def _additive_classify_and_run(path, ext, oracle_bin, flags, paths, timeout):
    """-> ("ast", name, body_lines, ast_text) | ("run", name, body_lines, ref_text, stdin_text) | ("exclude", name, reason)

    A pre-existing loose .ref beside `path` is RE-CONFIRMED against a fresh oracle run (requirement 2: "confirm
    an existing loose .ref against the oracle before keeping it") -- never trusted just because it is present;
    a mismatch excludes rather than silently keeping stale committed text. Absent a .ref, one is cut fresh, with
    the identical three-way agreement (oracle + scrip m3 + scrip m4) cmd_capture_oracle_refs already requires,
    including its empty-agreement guard -- a vacuous ref is worse than none."""
    from pathlib import Path as _P
    name = os.path.splitext(os.path.basename(path))[0]
    stem = path[: -len(ext)]
    try:
        body_lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError as e:
        return ("exclude", name, "unreadable: %s" % e)
    if not body_lines:
        return ("exclude", name, "empty source")
    if os.path.basename(os.path.dirname(path)) in ("include", "library"):
        return ("exclude", name, "module (include/ or library/ dir -- no runnable top level, never absorbed alone)")

    if os.path.isfile(stem + ".ast-only"):
        # parser-only fixture (requirement 3): absorbed via --dump-ast, never executed, never sent to the oracle.
        v = h.run_ast(paths, _P(path), "", timeout=timeout)
        if v.kind in ("HANG", "UNPROVEN", "CRASH"):
            return ("exclude", name, "parser-only fixture (declared %s.ast-only) but --dump-ast %s"
                                       % (os.path.basename(stem), v.kind))
        # ⛔⭐ THE EMPTY-REF GUARD BELONGS ON THIS BRANCH TOO, AND ONLY THE RUN BRANCH HAD IT (hq_S 2026-09-12).
        # Twenty lines down, an oracle that prints nothing is refused as "a vacuous ref is worse than none".
        # --dump-ast printing nothing is the SAME defect and was absorbed happily: SCRIP writes its parse error
        # to STDERR and exits 1, so a fixture our own parser cannot read yields kind=PASS with EMPTY text, and
        # the entry lands with an empty ref it can never match. MEASURED: 13 raku parser-coverage
        # fixtures absorbed exactly that way in this row's first pass -- `QUIT { say "quit"; }` and friends,
        # where scrip answers "raku parse error line 1: syntax error" -- and
        # test_gate_ast_declared_refs_are_ast_dumps.sh caught every one ("graded by --dump-ast against nothing").
        # ⭐ THE ASYMMETRY IS THE WHOLE LESSON: the run branch's guard was written because an ORACLE can fail
        # quietly, and nobody transplanted it to the branch where OUR OWN TOOL fails quietly. There is no oracle
        # for SCRIP's AST (these refs are self-pins), so there is no second opinion to fall back on -- an empty
        # dump cannot be repaired here, only refused. The fixture stays visible on its own board either way:
        # test_raku_parser_fixtures.sh walks the tree from disk and grades all 97 by --dump-ast, so a parser gap
        # excluded here is still red there. Excluding does not hide it; absorbing it vacuously WOULD.
        if not v.text().strip():
            return ("exclude", name, "parser-only fixture (declared %s.ast-only) but --dump-ast emits NOTHING -- "
                                       "SCRIP's own parser cannot read it (the diagnostic goes to stderr and the "
                                       "dump is empty), and a vacuous ast ref is worse than none: there is no "
                                       "oracle for SCRIP's AST, so the ref would be a self-pin against emptiness. "
                                       "Still graded from disk by the language's parser-fixture board."
                                       % os.path.basename(stem))
        return ("ast", name, body_lines, v.text())

    stdin_text, stdin_src = _additive_stdin_for(stem)
    ora_text, ora_rc, ora_kind = h.run_oracle(oracle_bin, flags, _P(path), timeout, stdin_text=stdin_text)
    if ora_kind == "HANG":
        return ("exclude", name, "over budget (oracle exceeded %.1fs)" % timeout)
    if ora_kind != "RAN":
        return ("exclude", name, "oracle itself %s" % ora_kind)
    if not ora_text.strip():
        # ⛔⭐ NAME WHAT THE ORACLE SAID, NEVER A THEORY ABOUT IT (hq_S 2026-09-12, CEO-604). This reason used to
        # end at "a vacuous ref is worse than none", which is true and tells the next reader nothing about WHY
        # the oracle printed nothing -- so the reader supplies a cause, and a cause supplied once is then
        # generalized over every program the guard caught. It was: 13 raku fixtures carried one hand-written
        # explanation ("defines `sub main()` and never calls it") that was true of four of them, while five
        # were compile- or run-time REFUSALS whose cause rakudo printed on stderr on every run. One extra
        # sub-second oracle invocation on an exclusion path buys the measurement instead.
        _diag = h.oracle_diagnostic(oracle_bin, flags, _P(path), timeout, stdin_text=stdin_text)
        return ("exclude", name, "oracle produced EMPTY output at rc=%s -- a vacuous ref is worse than none (same "
                                   "guard as cmd_capture_oracle_refs). THE ORACLE'S OWN FIRST DIAGNOSTIC: %s"
                                   % (ora_rc, _diag or "(none on stderr)"))

    # ⛔ .expected AND .std COUNT AS A COMMITTED REF, NOT JUST .ref (hq_S 2026-09-12): util_unabsorbed_census.py
    # has always called any of the three a "loose pair" (_REF_EXTS), and corpus/tests/scrip_test/raku/ ships
    # .expected exclusively. Looking only for .ref here sent every one of those down the mint-a-fresh-ref path,
    # ignoring a committed ref that was sitting beside the source -- the two instruments disagreeing about what
    # a ref IS, which is the quieter half of why that tree never absorbed.
    existing_ref = next((stem + x for x in (".ref", ".expected", ".std") if os.path.isfile(stem + x)), stem + ".ref")
    ref_confirmed = False
    if os.path.isfile(existing_ref):
        committed = open(existing_ref, encoding="utf-8", errors="replace").read().rstrip("\n")
        if committed != ora_text:
            return ("exclude", name, "committed .ref disagrees with a fresh oracle run -- re-confirm by hand "
                                       "(stale ref, drifted oracle, or a scale/flag this recipe does not supply)")
        ref_confirmed = True

    v3 = h.run_m3(paths, _P(path), ora_text, timeout=timeout, stdin_text=stdin_text)
    with __import__("tempfile").TemporaryDirectory() as td:
        v4 = h.run_m4(paths, _P(path), ora_text, _P(td), timeout=timeout, stdin_text=stdin_text)
    if v3.kind == "HANG" or v4.kind == "HANG":
        return ("exclude", name, "over budget (m3/m4 exceeded %.1fs)" % timeout)
    agree3 = v3.kind == "PASS" and v3.returncode == ora_rc
    agree4 = v4.kind == "PASS" and v4.returncode == ora_rc
    # ⛔⭐⭐ TWO DIFFERENT QUESTIONS WERE BEING ANSWERED BY ONE GATE, AND THE WRONG ANSWER WAS UNFALSIFIABLE
    # (hq_S 2026-09-12, row raku-absorb-every-owed-source, on the ceo's CEO-591 re-cut and hq_V's standing
    # practice "a wrong exclusion costs more than a wrong cure, because a red stays visible and an excluded
    # name cannot be red"). Three-way agreement exists to keep us from PINNING A REF WE CANNOT TRUST when we
    # are minting one from scratch -- there, m3/m4 are the only second opinion available and the guard is
    # right. But when a COMMITTED .ref is already on disk and has just RE-CONFIRMED byte-for-byte against a
    # fresh oracle run (ref_confirmed, twenty lines up), the ref's correctness is ESTABLISHED BY THE ORACLE
    # and m3/m4 are no longer evidence about the ref at all -- they are evidence about US. Excluding there
    # does not protect a ref; it deletes one of OUR OWN REDS from the denominator and writes the false reason
    # "non-deterministic or diverges from the oracle" over it.
    # ⛔ MEASURED, and this is what makes it a defect rather than a preference: all 17 corpus/benchmarks/raku
    # loose pairs re-confirm against rakudo-local 2026.05 EXACTLY, and 11 of them were being excluded with that
    # sentence while the real cause was printed on stdout by our own compiler -- "[SMX] --run: mode-3 native
    # emitter does not yet cover this program: variable 'Inf' is read but never assigned". Nothing about those
    # programs is non-deterministic, and nothing about them diverges from the oracle; the oracle runs all 17 at
    # rc=0 and matches every committed ref. The reason string was not merely imprecise, it named the innocent
    # party, so anyone auditing the exclusion list would have gone looking at the programs instead of at us.
    # ⭐ RULES.md:214 (Lon 2026-09-03, "there is no such thing now as XFAIL... we are shooting for 100%") is the
    # law this restores: a program we fail is a FAIL on the board, never a name in a sidecar. The absorbed entry
    # is graded in both modes like any other, so it reads red until the emitter covers it, which is the entire point.
    if not (agree3 and agree4):
        if ref_confirmed:
            return ("run", name, body_lines, ora_text, stdin_text)
        # ⛔⭐ THE SECOND OPINION DOES NOT HAVE TO BE OUR OWN COMPILER, AND IT IS A BETTER ONE WHEN IT IS NOT.
        # With no committed .ref the three-way guard has a real job -- do not pin a ref from a single run of a
        # program that might be non-deterministic. But m3/m4 answer that question only by accident: they agree
        # when we are CORRECT, and a program we simply do not implement yet reads exactly like a program whose
        # output cannot be trusted. Asking the ORACLE TWICE separates the two cleanly -- it is the same question
        # the guard was always trying to ask ("is this output reproducible?"), asked of the authority that
        # defines the answer, and it costs one extra oracle run only on the path that was about to exclude.
        # Two identical runs -> the ref is the oracle's output and the entry is absorbed, reading RED until we
        # cover it (RULES.md:214, no XFAIL). Two different runs -> genuinely non-deterministic, and only NOW is
        # that word the truthful reason to exclude.
        # ⛔ THE RESIDUAL RISK, NAMED RATHER THAN PAPERED OVER: repetition catches a program that varies run to
        # run, not one that is stable within a sitting and varies across days (a DATE()/TIME() or locale
        # dependence). That exposure is identical for the committed-ref path directly above, which re-confirms
        # against exactly one fresh run, so this adds no new class of error -- it inherits an existing one.
        ora_text2, ora_rc2, ora_kind2 = h.run_oracle(oracle_bin, flags, _P(path), timeout, stdin_text=stdin_text)
        if ora_kind2 == "RAN" and ora_text2 == ora_text and ora_rc2 == ora_rc:
            return ("run", name, body_lines, ora_text, stdin_text)
        return ("exclude", name, "NON-DETERMINISTIC, proven by repetition: two oracle runs of this program "
                                   "disagree (rc %s then %s), so no ref can be cut from it -- m3=%s m4=%s"
                                   % (ora_rc, ora_rc2, v3.kind, v4.kind))
    return ("run", name, body_lines, ora_text, stdin_text)


def _additive_next_name(base, taken):
    if base not in taken:
        return base
    i = 2
    while ("%s_%d" % (base, i)) in taken:
        i += 1
    return "%s_%d" % (base, i)


EXCL_DIGEST_TAG = "# builder-digest:"


def _excl_digest(existing):
    """sha256 over the sorted `key<TAB>value` DATA lines of an exclusion sidecar. Comments and order are
    not part of it: the header is prose a human maintains, the data is what the builder owns."""
    body = "".join("%s\t%s\n" % (k, existing[k]) for k in sorted(existing))
    return hashlib.sha256(body.encode("utf-8")).hexdigest()


def _excl_guard(path, existing):
    """⛔⭐ REFUSE rc=2 IF ALL.excluded.txt HAS BEEN EDITED BY ANYTHING BUT THIS BUILDER (ceo CEO-545, on
    hq_V's 2026-09-10 measurement). THE DEFECT IT CLOSES, both arms measured in a scratch tree before this
    existed: (1) a hand DELETION of a line the builder still computes is SILENTLY REVERTED by the next full
    build -- `rung36_jcon_io` removed by hand came back with no word said, which is the ceo's phrase exactly,
    a generated artifact that can be edited but not honoured; (2) a hand-ADDED line the builder never
    computes SURVIVES FOREVER -- an invented `zzz_invented_family` was still there after two full builds,
    never challenged. The second is the worse half: it is how a WRONG EXCLUSION becomes permanent, and an
    excluded name cannot be red, so nobody looks (the jcon `kwds` shape, four cycles).
    ⛔ THE RULE IS THE CEO'S: a retraction is made where the exclusion is DECLARED -- KEEP.md, PENDING.md --
    and the generated file is then REBUILT. This function makes the file say so instead of absorbing the
    edit. A legacy file with no digest line is MIGRATED, not refused: refusing every tree on the first run
    after this lands would be a gate that fires on its own introduction."""
    if not os.path.isfile(path):
        return
    recorded = None
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.strip()
        if line.startswith(EXCL_DIGEST_TAG):
            recorded = line[len(EXCL_DIGEST_TAG):].strip()
    if recorded is None:
        return
    actual = _excl_digest(existing)
    if actual == recorded:
        return
    sys.stderr.write(
        "⛔ REFUSED rc=2: %s has been edited since this builder last wrote it (recorded %s..., actual %s...).\n"
        "   It is a GENERATED artifact and a hand edit to it is not honoured: a deletion is silently\n"
        "   reverted by the next full build, and an invention survives forever unchallenged.\n"
        "   CEO-545: retract or add the exclusion WHERE IT IS DECLARED -- the language's KEEP.md or\n"
        "   PENDING.md -- then re-run this builder so the generated file is rebuilt from the declaration.\n"
        "   To adopt the current file as the new baseline (only if you know the edit is right), delete the\n"
        "   %s line and re-run.\n" % (path, recorded[:16], actual[:16], EXCL_DIGEST_TAG))
    raise SystemExit(2)


def _additive_write_sidecar_merge(path, new_lines, digest=False, fresh_wins=False, retract=()):
    """Merge {key: value} into a TAB-separated sidecar (ALL.excluded.txt), keyed on column 1 --
    new/changed keys win, everything else already on disk survives. Never a blind overwrite: a second
    --additive run (a different --lang, a different --from) must not erase the first run's lines.
    ⛔⭐ THE HEADER IS DATA TOO. This used to drop every line without a TAB, which is every comment line,
    so each --additive run silently deleted the sidecar's own governing text, and nothing in it said that
    anything had been removed. Comments are preserved verbatim, in place.
    ⛔⭐⭐ `fresh_wins` AND `retract` EXIST BECAUSE CEO-545 CHANGED WHAT THE NEVER-OVERWRITE RULE PROTECTS, AND
    NOBODY MOVED THE RULE (hq_S 2026-09-12, measured on raku scrip_test). The `if k not in existing` below was
    written to protect A HAND-WRITTEN DECLARATION AND ITS EVIDENCE. But CEO-545 made ALL.excluded.txt GENERATED and _excl_guard now REFUSES a hand edit to it,
    so in that file there is no hand-written line left to protect: the only thing never-overwrite preserves
    there is THIS TOOL'S OWN STALE TEXT. Both arms measured on the same 15 rows: (1) eight programs absorbed
    into the rungs stayed NAMED AS EXCLUDED FROM IT -- the exact contradiction the non-additive writer's own
    retraction arm exists to stop ("the two readings cannot both be true, and the file that contradicts the
    rungs is the one every census reads"), which that path has and this one did not; (2) the five still
    unabsorbable rows kept a reason that had become FALSE -- it said appending one `main();` line would make
    them gradeable and that the question was open with the ceo, when the line had been appended, the ceo had
    ruled, and the real cause was five different constructs rakudo refuses. A stale reason is worse than a
    blunt one: it names the wrong cause with the authority of a measurement. So for the generated sidecar the
    current run's measurement REPLACES the old one (`fresh_wins`) and a key now in the graded denominator is
    DELETED (`retract`); a caller passing neither keeps never-overwrite."""
    existing, header = {}, []
    if os.path.isfile(path):
        seen_data = False
        for line in open(path, encoding="utf-8", errors="replace"):
            line = line.rstrip("\n")
            if not line or "\t" not in line:
                if not seen_data:
                    header.append(line)
                continue
            seen_data = True
            k, v = line.split("\t", 1)
            existing[k] = v
    if digest:
        _excl_guard(path, existing)
    for k in retract:                    # ⛔ in the graded denominator: it cannot also be named as excluded from it
        existing.pop(k, None)
    for k, v in new_lines.items():
        if fresh_wins or k not in existing:   # ⛔ never overwrite a hand-written line; a GENERATED
            existing[k] = v                   #    reason is replaced by this run's measurement (ALL.excluded.txt)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        for line in header:
            f.write("%s\n" % line)
        for k in sorted(existing):
            f.write("%s\t%s\n" % (k, existing[k]))
        if digest:
            f.write("%s %s\n" % (EXCL_DIGEST_TAG, _excl_digest(existing)))


def _additive_write_excluded(outdir, absorbed, excluded_rows):
    """Write ALL.excluded.txt for an --additive run: this run's reasons REPLACE their predecessors, and a
    program that reached the rungs is RETRACTED rather than named as excluded from it (see
    _additive_write_sidecar_merge's own docstring for the two measured arms and why CEO-545 requires it).
    ⛔ A PROGRAM ALREADY IN THE RUNGS IS IN `absorbed` AND IN `excluded_rows` AT THE SAME TIME, by design --
    the absorb loop pushes an "already in the rungs (origin ...) -- not re-appended" row so the run's printed
    accounting still balances. That bookkeeping note is NOT an exclusion, so the retraction wins over it: the
    key is dropped from what is written, which is the same two-condition rule the non-additive writer applies
    (in the denominator AND not excluded by the live tree this run), reached from the additive side."""
    absorbed_keys = {("%s[%s]" % (row[0], row[1])) for row in absorbed}
    fresh = {("%s[%s]" % (n, c)): r for n, c, r in excluded_rows if ("%s[%s]" % (n, c)) not in absorbed_keys}
    _additive_write_sidecar_merge(os.path.join(outdir, "ALL.excluded.txt"), fresh,
                                   digest=True, fresh_wins=True, retract=absorbed_keys)


def additive_absorb(lang, categories, root, timeout, write, cols):
    """Run THE BUILDER EXTENSION for one language: absorb corpus/demos/<lang> and corpus/benchmarks/<lang>
    additively into corpus/tests/<lang>/ALL.*. Returns (absorbed, excluded_rows, programs_named) where
    absorbed is [(name, cat, kind, body_lines, ref_or_ast_text), ...] and excluded_rows is [(name, cat,
    reason), ...]. write=False computes and reports without touching disk (used by nothing today, kept
    because every other mode in this file offers the same dry-run shape for free). A write verifies the
    round trip in a temp sibling BEFORE any os.replace, same discipline as resort_rungs/reindex_csv_only."""
    if lang not in LANG_TABLES:
        h.refuse("--additive --lang %r has no attribute table -- see LANG_TABLES" % lang)
    if lang in h.NO_RIVAL_LANGS:
        # ⛔⭐ THIS ARM RUNS BEFORE THE "not wired yet" ONE ON PURPOSE (CEO-607, 2026-09-12). This check sits
        # ahead of resolve_oracle_bin and would otherwise hand a no-rival language the backlog-shaped refusal
        # below, which the caller can only read as "someone will wire it later" -- and hq_C measured exactly
        # that reading costing a row a full sitting before the ruling. resolve_oracle_bin carries the same
        # named refusal for the callers that reach IT first; the two must not diverge, which is why both read
        # the one NO_RIVAL_LANGS set in corpus_suite_harness rather than spelling the membership twice.
        h.refuse("--additive --lang %r: no rival: refs are derived, see KEEP.md -- %s has no independent rival "
                 "implementation, so ABSORPTION WITH AN ORACLE-CUT REF IS NOT PENDING, IT IS IMPOSSIBLE. Its "
                 "kernels stay in corpus/benchmarks/%s (CEO-609: a kernel tree never enters a rung suite) carrying a "
                 "ref DERIVED from a rival program in another language under THAT language's oracle, the "
                 "derivation recorded in a .derivation beside the ref and re-performed on every run by "
                 "test_gate_rebus_derived_refs_match_their_rival_oracle.sh" % (lang, lang, lang))
    if lang not in ADDITIVE_ORACLE_LANGS:
        h.refuse("--additive --lang %r: no oracle wired in resolve_oracle_bin yet (only %s) -- prove-on-one-"
                 "then-widen means widening THAT function first, never skipping the oracle cut"
                 % (lang, ", ".join(sorted(ADDITIVE_ORACLE_LANGS))))
    EXT = LANG_EXT[lang]
    OUTDIR = os.path.join(root, "corpus", "tests", lang)
    os.makedirs(OUTDIR, exist_ok=True)
    _CO = h.LANG_CONFIGS[lang]["comment_open"] if lang in h.LANG_CONFIGS else "*"
    _CC = h.LANG_CONFIGS[lang].get("comment_close", "") if lang in h.LANG_CONFIGS else ""
    paths = h.resolve_paths()
    if str(paths["corpus"]) != os.path.join(root, "corpus"):
        paths = dict(paths)
        paths["corpus"] = __import__("pathlib").Path(root) / "corpus"   # scratch-tree override for --selftest
    h.check_scrip(paths)
    oracle_bin, flags = h.resolve_oracle_bin(paths, lang)

    excluded_rows, absorbed, programs_named = [], [], False
    for cat in categories:
        if cat == "programs":
            programs_named = True
            excluded_rows.append(("*", "programs", "corpus/programs/ out of scope this run (Lon 2026-09-04 "
                                                     "excluded it from util_unabsorbed_census.py's OWED count; "
                                                     "this builder honours the same ruling) -- named, not walked"))
            continue
        if cat not in ("demos", "benchmarks", "tests") and cat not in _EXTRA_TEST_TREES:
            h.refuse("--from names an unknown category %r (known: demos, benchmarks, programs, tests, %s)"
                     % (cat, ", ".join(sorted(_EXTRA_TEST_TREES))))
        # ⭐ "tests" is the ONE category whose src_dir is the SAME directory as OUTDIR (the rungs' own
        # home) -- see _additive_walk_tests's docstring for why that walk excludes what discover_pairs and
        # the rungs files themselves already own. The _EXTRA_TEST_TREES categories are siblings of that same
        # shape (a fixed tree outside corpus/<cat>/<lang>/, walked with the identical dedup-against-existing-
        # ref rule) for stray runnable sources census found living outside both corpus/tests/<lang>/ and the
        # demos/benchmarks trees (row snobol4-every-non-package-source-...-oracle-refs, 2026-09-05: 3 of 9
        # remaining owed sources -- 1113_table.sno, datatype.oracle_ref.sno, lit_real.oracle_ref.sno -- run
        # fine with real output but live under corpus/tests/scrip_test/ and corpus/tests/snocone/ladder/,
        # which nothing else walks).
        if cat in _EXTRA_TEST_TREES:
            src_dir = os.path.join(root, "corpus", "tests", _EXTRA_TEST_TREES[cat])
        elif cat == "tests":
            src_dir = os.path.join(root, "corpus", "tests", lang)
        else:
            src_dir = os.path.join(root, "corpus", cat, lang)
        if cat in ("demos", "benchmarks"):
            walker = _additive_walk
        elif cat in _EXTRA_TEST_TREES:
            walker = lambda d, e: _additive_walk_tests(d, e, skip_loose_pairs=False)
        else:
            walker = _additive_walk_tests
        for path in walker(src_dir, EXT):
            result = _additive_classify_and_run(path, EXT, oracle_bin, flags, paths, timeout)
            if result[0] == "exclude":
                _kind, name, reason = result
                excluded_rows.append((name, cat, reason))
            elif result[0] == "run":
                # ⛔⭐ CARRY stdin_text THROUGH TO THE ENTRY (hq_P seat08 2026-09-04, row
                # snobol4-every-non-package-source-...): a candidate absorbed via a `.input` recipe was
                # VERIFIED against that stdin (oracle+m3+m4 three-way agreement above) but the entry landed
                # in the rungs with NO stdin recorded anywhere -- corpus_suite_harness.py's own grading
                # run then fed it none (immediate EOF) and got a DIFFERENT, wrong answer. MEASURED: 4 of the
                # 10 demos this row's first --additive run absorbed (json/porter/treebank/wordcount, every
                # one with a .input sidecar) read PASS at absorption and FAIL when the rungs was re-graded
                # -- a silent, self-contradicting green. See the write section below for the other half
                # (ALL.in must actually be written).
                kind, name, body_lines, ref_or_ast, stdin_text = result
                absorbed.append((name, cat, kind, body_lines, ref_or_ast, stdin_text))
            else:
                kind, name, body_lines, ref_or_ast = result
                absorbed.append((name, cat, kind, body_lines, ref_or_ast, None))

    if not write:
        return absorbed, excluded_rows, programs_named

    rungs_sno = os.path.join(OUTDIR, "ALL" + EXT)
    rungs_ref = os.path.join(OUTDIR, "ALL.ref")
    rungs_csv = os.path.join(OUTDIR, "ALL.csv")
    cmd_cols = carried_cmd_cols(rungs_csv)
    base_entries, csv_row_by_name = [], {}
    if os.path.isfile(rungs_sno) and os.path.isfile(rungs_ref):
        if lang == "snobol4":
            base_entries = h.read_suite(rungs_sno, rungs_ref, in_path=h.sidecar_in_path(rungs_sno), x_path=h.sidecar_xfail_path(rungs_sno))
        else:
            base_entries = h.read_block_suite(rungs_sno, rungs_ref, h.banner_re_for(_CO, _CC),
                                              in_path=h.sidecar_in_path(rungs_sno), x_path=h.sidecar_xfail_path(rungs_sno))
    if os.path.isfile(rungs_csv):
        for row in csv.DictReader(open(rungs_csv)):
            csv_row_by_name[row["entry"]] = row
    taken_names = {e.name for e in base_entries}
    base_origins = {(csv_row_by_name.get(e.name) or {}).get("origin") or ("rungs__%s" % e.name) for e in base_entries}

    new_entries = []
    for name, cat, kind, body_lines, ref_or_ast, stdin_text in absorbed:
        singular = cat[:-1] if cat.endswith("s") else cat
        fam = "%s_%s_%s" % (singular, lang, name)      # one family per additive entry -- see discover_pairs's
        origin = "%s__%s" % (fam, name)                 # own "plain" mode for the identical per-file convention
        if origin in base_origins:
            excluded_rows.append((name, cat, "already in the rungs (origin %s) -- not re-appended" % origin))
            continue
        entry_name = _additive_next_name("%s_%s" % (singular, name), taken_names)
        taken_names.add(entry_name)
        e = h.Entry("block", 0, entry_name, list(body_lines), ref_or_ast.splitlines(), xfail=False)
        if stdin_text:
            e.stdin = stdin_text
        e.origin = origin
        e.src_mode = "additive"
        new_entries.append(e)

    if not new_entries:
        print("--additive %s --from %s: 0 new entries (%d candidate(s) checked, %d excluded) -- nothing written."
              % (lang, ",".join(categories), len(absorbed) + len(excluded_rows), len(excluded_rows)), file=sys.stderr)
        _additive_write_excluded(OUTDIR, absorbed, excluded_rows)
        return absorbed, excluded_rows, programs_named

    all_entries = base_entries + new_entries
    for i, e in enumerate(all_entries, 1):
        e.seq = i
    _tag = ".tmp-additive-%d" % os.getpid()
    # ⛔ sidecar_in_path() is a DISCOVERY helper for reads -- it returns None when the candidate ".in" does
    # not exist YET, which is exactly the case the very first stdin-bearing additive entry hits. Construct
    # the candidate path directly for writing, same as the base (non-additive) path does at its own out_in.
    rungs_in = os.path.splitext(rungs_sno)[0] + ".in"
    tmp_sno, tmp_ref, tmp_csv, tmp_in = rungs_sno + _tag, rungs_ref + _tag, rungs_csv + _tag, rungs_in + _tag
    wrote_in = False
    try:
        # ⛔⭐ out_in=tmp_in (hq_P seat08 2026-09-04): a `.input`-recipe absorption sets e.stdin above, but
        # write_suite/write_block_suite only ever EMIT a stdin sidecar when TOLD to via out_in -- omitting it
        # (the shape this call had before this row) silently drops every additive entry's stdin on the floor,
        # so ALL.in never carries what the entry was actually verified against. MEASURED: 4 of this row's
        # first 10 absorbed demos (json/porter/treebank/wordcount, every stdin-needing one) passed at
        # absorption and failed the very next full-suite grading, fed /dev/null instead of their recipe.
        if lang == "snobol4":
            wrote_in = h.write_suite(all_entries, tmp_sno, tmp_ref, out_in=tmp_in)
            reread = h.read_suite(tmp_sno, tmp_ref, in_path=(tmp_in if wrote_in else None))
        else:
            wrote_in = h.write_block_suite(all_entries, tmp_sno, tmp_ref, _CO, _CC, out_in=tmp_in)
            reread = h.read_block_suite(tmp_sno, tmp_ref, h.banner_re_for(_CO, _CC), in_path=(tmp_in if wrote_in else None))
        if {r.name for r in reread} != {e.name for e in all_entries} or len(reread) != len(all_entries):
            sys.stderr.write("REFUSED: additive write did not round-trip (name set or count changed) -- nothing committed.\n")
            raise SystemExit(2)
        if any((r.stdin or None) != (e.stdin or None) for r, e in zip(
                sorted(reread, key=lambda x: x.name), sorted(all_entries, key=lambda x: x.name))):
            sys.stderr.write("REFUSED: additive write did not round-trip (stdin content changed) -- nothing committed.\n")
            raise SystemExit(2)
        with open(tmp_csv, "w", newline="") as f:
            w = csv.writer(f, lineterminator="\n")
            w.writerow(["rank", "entry", "origin", "family", "kind", "xfail", "n_lines", "heap_kb", "stack_kb"] + cmd_cols + [c for c, _ in cols])
            for rank, e in enumerate(all_entries, 1):
                text = "\n".join(e.sno_lines)
                flags_e = {c: fn(text) for c, fn in cols}
                old_row = csv_row_by_name.get(e.name) or {}
                origin = getattr(e, "origin", None) or old_row.get("origin") or ("rungs__%s" % e.name)
                fam = origin.split("__", 1)[0]
                w.writerow([rank, e.name, origin, fam, e.kind, int(bool(e.xfail)), len(e.sno_lines),
                            ((old_row.get("heap_kb") or "").strip() or DEFAULT_HEAP_KB), ((old_row.get("stack_kb") or "").strip() or DEFAULT_STACK_KB)]
                           + [(old_row.get(c) or "").strip() for c in cmd_cols]
                           + [flags_e[c] for c, _ in cols])
    except BaseException:
        for q in (tmp_sno, tmp_ref, tmp_csv, tmp_in):
            if os.path.exists(q):
                os.remove(q)
        raise
    os.replace(tmp_sno, rungs_sno)
    os.replace(tmp_ref, rungs_ref)
    if wrote_in:
        os.replace(tmp_in, rungs_in)
    elif os.path.exists(rungs_in):
        os.remove(rungs_in)
    os.replace(tmp_csv, rungs_csv)
    _additive_write_excluded(OUTDIR, absorbed, excluded_rows)
    print("--additive %s --from %s: %d new entries absorbed (%d candidate(s) checked, %d excluded) -- "
          "ALL%s/ALL.ref/ALL.csv updated." % (lang, ",".join(categories), len(new_entries),
          len(absorbed) + len(excluded_rows), len(excluded_rows), EXT), file=sys.stderr)
    return absorbed, excluded_rows, programs_named


def run_additive_selftest(timeout):
    """--selftest: prove --additive end-to-end on a throwaway scratch tree this process builds itself and
    deletes when done. Never opens the real corpus. All four fixtures are snobol4 -- the default --lang and
    one of the three languages resolve_oracle_bin actually wires an oracle for, so this proves the real
    oracle-cut path, never a mock:
      - demo_hello        no stdin, deterministic OUTPUT -- the common case.
      - bench_count       reads one value via INPUT; a .input sidecar supplies a small deterministic count
                          -- proves the stdin-recipe path (and the pre-existing .input convention, reused
                          from corpus/demos/snobol4/claws5/claws5.input rather than invented fresh).
      - parser_fixture_x  a sibling .ast-only marker -- absorbed via --dump-ast, never executed -- proves
                          requirement 3 (an --dump-ast ref).
      - hangs_forever     an unconditional backward branch that computes but never prints -- proves the
                          over-budget/HANG exclusion never absorbs a program that cannot finish, and never
                          blocks the run past its own timeout doing so.
    Fail-once, per the task's own GOAL line: any one of these four missing its expected outcome is SELFTEST
    FAIL. The deferral contract (KEEP.md/PENDING.md) is discover_pairs's own already-proven machinery
    (requirement 1's row) and is deliberately not re-proven here -- this selftest is scoped to what THIS row
    adds, not a re-proof of code that predates it.
    """
    import shutil as _shutil
    import tempfile as _tempfile
    scratch = _tempfile.mkdtemp(prefix="additive_selftest_")
    try:
        demos = os.path.join(scratch, "corpus", "demos", "snobol4")
        benches = os.path.join(scratch, "corpus", "benchmarks", "snobol4")
        os.makedirs(demos)
        os.makedirs(benches)
        os.makedirs(os.path.join(scratch, "corpus", "tests", "snobol4"))
        with open(os.path.join(demos, "demo_hello.sno"), "w") as f:
            f.write("      OUTPUT = \"HELLO FROM DEMO\"\nEND\n")
        with open(os.path.join(benches, "bench_count.sno"), "w") as f:
            f.write("      N = INPUT\n      OUTPUT = \"COUNT \" N\nEND\n")
        with open(os.path.join(benches, "bench_count.input"), "w") as f:
            f.write("5\n")
        with open(os.path.join(demos, "parser_fixture_x.sno"), "w") as f:
            f.write("      X = 1\nEND\n")
        open(os.path.join(demos, "parser_fixture_x.ast-only"), "w").close()
        with open(os.path.join(demos, "hangs_forever.sno"), "w") as f:
            f.write("LOOP      X = X + 1        :(LOOP)\nEND\n")

        cols, _names = LANG_TABLES["snobol4"]
        absorbed, excluded_rows, _named = additive_absorb("snobol4", ["demos", "benchmarks"], scratch,
                                                           min(timeout, 2.0), True, cols)
        absorbed_names = {a[0] for a in absorbed}
        excluded_names = {e[0] for e in excluded_rows}

        rungs_csv = os.path.join(scratch, "corpus", "tests", "snobol4", "ALL.csv")
        ast_row_ok = False
        if os.path.isfile(rungs_csv):
            for row in csv.DictReader(open(rungs_csv)):
                if row.get("origin", "").split("__")[-1] == "parser_fixture_x":
                    ast_row_ok = True

        # ⛔⭐ "ABSORBED" IS NOT "GRADES CORRECTLY" (hq_P seat08 2026-09-04): the check above only asks whether
        # bench_count's NAME appears in the in-memory `absorbed` list from THIS call -- it never re-reads the
        # rungs files a later, independent `corpus_suite_harness.py run` would actually use. That gap is
        # exactly how 4 of this row's first 10 real absorbed demos (every one needing stdin) passed this exact
        # selftest, landed, and then FAILED the next full-suite grading: verified against their .input recipe
        # at absorption time, but with no stdin at all recorded anywhere a later reader could find. Close the
        # loop for real: read back what's actually on disk, the same way a grading run would, and require the
        # recipe to have survived.
        rungs_sno = os.path.join(scratch, "corpus", "tests", "snobol4", "ALL.sno")
        rungs_ref = os.path.join(scratch, "corpus", "tests", "snobol4", "ALL.ref")
        stdin_roundtrip_ok = False
        if os.path.isfile(rungs_sno) and os.path.isfile(rungs_ref) and os.path.isfile(rungs_csv):
            reread = h.read_suite(rungs_sno, rungs_ref, in_path=h.sidecar_in_path(rungs_sno))
            origin_by_name = {row["entry"]: row.get("origin", "") for row in csv.DictReader(open(rungs_csv))}
            for e in reread:
                if origin_by_name.get(e.name) == "benchmark_snobol4_bench_count__bench_count" and (e.stdin or "") == "5\n":
                    stdin_roundtrip_ok = True

        checks = [
            ("demo (no stdin) absorbed",                        "demo_hello" in absorbed_names),
            ("benchmark (stdin recipe via .input) absorbed",     "bench_count" in absorbed_names),
            ("benchmark stdin recipe SURVIVES to ALL.in (grading-time reread, not just absorption)", stdin_roundtrip_ok),
            ("parser-only fixture absorbed via --dump-ast",      "parser_fixture_x" in absorbed_names and ast_row_ok),
            ("non-terminating program excluded, never absorbed", "hangs_forever" in excluded_names and "hangs_forever" not in absorbed_names),
        ]
        for label, ok in checks:
            print("  %s %s" % ("PASS" if ok else "FAIL", label), file=sys.stderr)
        failed = [label for label, ok in checks if not ok]
        if failed:
            print("SELFTEST FAIL: %s" % "; ".join(failed), file=sys.stderr)
            return 1
        print("SELFTEST PASS: %d/%d checks" % (len(checks), len(checks)), file=sys.stderr)
        return 0
    finally:
        _shutil.rmtree(scratch, ignore_errors=True)


def main():
    args = _build_arg_parser().parse_args()
    if args.selftest:
        # ⭐ Checked before ANY --lang-dependent setup below: the selftest hardcodes snobol4 fixtures on its
        # own throwaway tree regardless of what --lang was passed, so it must not be blockable by unrelated
        # validation (a bad --lang, a missing real corpus tree) that has nothing to do with what it proves.
        raise SystemExit(run_additive_selftest(args.recipe_timeout))
    # ⭐ --lang selects root, extension and attribute tables. Default snobol4 keeps the previous behaviour
    # exactly, so `util_build_rungs_suite.py` with no arguments rebuilds a byte-identical rungs.
    lang = args.lang
    if lang not in LANG_TABLES:
        sys.stderr.write("REFUSED: no attribute table for language %r. Known: %s\n"
                         "  A rung suite built with a fabricated column set is worse than no rungs -- add the\n"
                         "  language's own primitives deliberately rather than defaulting to another dialect's.\n"
                         % (lang, ", ".join(sorted(LANG_TABLES))))
        raise SystemExit(2)
    EXT = LANG_EXT[lang]
    _CO = h.LANG_CONFIGS[lang]["comment_open"] if lang in h.LANG_CONFIGS else "*"
    _CC = h.LANG_CONFIGS[lang].get("comment_close", "") if lang in h.LANG_CONFIGS else ""
    ROOT = os.path.join(S4E, "corpus", "tests", lang)
    OUTDIR = ROOT   # ⭐ ZERO SUBFOLDERS (Lon 2026-08-29): the rungs lives FLAT beside the residue -- ALL.* side by side, no rungs/ dir
    if not os.path.isdir(ROOT):
        sys.stderr.write("REFUSED: no corpus tree at %s -- nothing to build from.\n" % ROOT)
        raise SystemExit(2)
    global COLS, NAME_FEATURES
    COLS, NAME_FEATURES = LANG_TABLES[lang]
    os.makedirs(OUTDIR, exist_ok=True)
    delete_absorbed = args.delete_absorbed
    # ⛔ SURGICAL AND NAMED, never a blanket --force. A deliberate retirement is spelled out origin by
    # origin so it lands in the shell history and the commit that performs it, which is the floor doctrine's
    # own shape ("only an attributed retirement may lower it"). A single flag that switched the whole check
    # off would be used once in a hurry and never removed.
    allow_drop = {x for x in args.allow_drop_origin.split(",") if x} if args.allow_drop_origin else set()
    # ⭐ --family <prefix> / --only fam,fam SCOPE --delete-absorbed TO A SUBSET (row
    # master-builder-delete-absorbed-family-selector, ceo mint 2026-08-30, on hq_P's measurement:
    # --delete-absorbed is all-or-nothing per LANGUAGE while FLEET-16 splits one language's
    # consolidation across seats -- icon has 208 verified-deletable families of which 153 are
    # parser_* under a live seat lock, so the one authorized delete command would wipe another
    # seat's working set and nobody could safely run it). Filters the SAME-INVOCATION `verified`
    # list computed below -- never a second, independently-derived notion of "absorbed" -- so the
    # byte-equal-or-no-delete guarantee is identical to plain --delete-absorbed, just scoped.
    family_prefix = args.family
    only_families = set(args.only.split(",")) if args.only is not None else None
    # ⭐ --absorb-only <families> SCOPES ABSORPTION ITSELF, never deletion (requirement 2). --family/--only
    # above only ever scoped what --delete-absorbed removes -- MEASURED on tests/icon: asking (via --only,
    # the only selector that existed) for rung36_jcon_scan,rung36_jcon_scan2 absorbed coexpr_gc_stack_witness
    # and rung38_all instead, i.e. exactly the families that were NOT asked for, because nothing narrowed
    # what got read into all_entries in the first place -- only what got deleted afterward. Applied as a
    # filter on `pairs` below, right after discover_pairs, before any absorption happens.
    absorb_only_families = set(args.absorb_only.split(",")) if args.absorb_only is not None else None
    if family_prefix and only_families:
        sys.stderr.write("REFUSED: --family and --only are alternatives, not both at once -- ambiguous which one selects.\n")
        raise SystemExit(2)
    if (family_prefix or only_families) and not delete_absorbed:
        sys.stderr.write("REFUSED: --family/--only scope what --delete-absorbed deletes -- pass --delete-absorbed too, "
                          "or drop the selector for a plain build (a selector with nothing to delete is a no-op that "
                          "looks like a typo). \u26d4 NOT \"a dry run\": a plain build REWRITES the rungs pair -- the "
                          "only thing the selector was going to change is which loose source pairs get DELETED.\n")
        raise SystemExit(2)
    if args.split_write:
        raise SystemExit(split_write(OUTDIR, EXT, lang, _CO, _CC, args.write))
    if args.additive:
        for _flag, _val in (("--delete-absorbed", delete_absorbed), ("--family", family_prefix),
                             ("--only", only_families), ("--absorb-only", absorb_only_families),
                             ("--resort", args.resort), ("--reindex", args.reindex), ("--split-write", args.split_write)):
            if _val:
                sys.stderr.write("REFUSED: --additive is its own terminal mode (ADDITIVE, never DELETE/SCOPE/REORDER) -- drop %s.\n" % _flag)
                raise SystemExit(2)
        cats = [c.strip() for c in args.from_cats.split(",") if c.strip()]
        additive_absorb(lang, cats, S4E, args.recipe_timeout, True, COLS)
        raise SystemExit(0)
    included, all_entries, per_family = [], [], {}
    absorbed_files = []    # (fam, sno, ref, mode) for post-verification deletion
    companion_copies = {}  # basename -> source path; written into OUTDIR after the merge succeeds
    pairs, excluded = discover_pairs(ROOT, OUTDIR, EXT)
    if args.resort:
        for _flag, _val in (("--delete-absorbed", delete_absorbed), ("--family", family_prefix), ("--only", only_families), ("--split-write", args.split_write), ("--reindex", args.reindex)):
            if _val:
                sys.stderr.write("REFUSED: %s cannot be combined with --resort.\n" % _flag); raise SystemExit(2)
        raise SystemExit(resort_rungs(OUTDIR, EXT, lang, h, _CO, _CC, COLS,
                                       {fam for fam, _, _, _ in pairs}, absorb_only_families or set()))
    if args.reindex:
        # ⛔ --reindex is a TERMINAL mode: it never reaches the absorb machinery below, so --absorb-only here
        # can only ACKNOWLEDGE a loose pair, never absorb one. Refusing to combine it with the delete/scope
        # selectors is deliberate -- those all describe absorption, and a flag that silently means nothing is
        # how a caller ends up believing a run did something it never attempted.
        for _flag, _val in (("--delete-absorbed", delete_absorbed), ("--family", family_prefix), ("--only", only_families), ("--split-write", args.split_write)):
            if _val:
                sys.stderr.write("REFUSED: %s describes ABSORPTION and --reindex absorbs nothing -- drop one.\n" % _flag)
                raise SystemExit(2)
        raise SystemExit(reindex_csv_only(OUTDIR, EXT, lang, h, _CO, _CC, COLS,
                                          {fam for fam, _, _, _ in pairs}, absorb_only_families or set()))
    if absorb_only_families is not None:
        # ⛔ A SELECTOR NAMING SOMETHING THIS RUN CANNOT ABSORB REFUSES rc=2 -- never silently absorbs a
        # different subset instead (the exact measured bug this flag exists to cure). Cross-references
        # `excluded` for a precise reason (KEEPER/DEFERRED/companion-dependent/etc.) when one is on record.
        _have = {fam for fam, _, _, _ in pairs}
        _missing = sorted(absorb_only_families - _have)
        if _missing:
            _excl_reason = dict(excluded)
            sys.stderr.write("REFUSED: --absorb-only names %d famil(y/ies) this run cannot absorb -- nothing written:\n" % len(_missing))
            for m in _missing:
                sys.stderr.write("     %s -- %s\n" % (m, _excl_reason.get(m, "no absorbable pair under this exact family name (check spelling / --lang)")))
            raise SystemExit(2)
        _n_before = len(pairs)
        pairs = [p for p in pairs if p[0] in absorb_only_families]
        print("--absorb-only %s: scoped to %d of %d absorbable pairs this run" % (",".join(sorted(absorb_only_families)), len(pairs), _n_before), file=sys.stderr)
    # ⛔⭐ MERGE, NEVER REPLACE (measured the hard way: an incremental run on a post-retirement tree rebuilt the
    # rungs from ONLY the new pairs and overwrote 1495 entries with 98 -- caught and restored from the index).
    # If a rung suite already exists, its entries are the BASE: loaded with their names KEPT (names are stable
    # identifiers), origins re-attached from the CSV, and new absorptions appended with counters seeded PAST
    # the existing names so nothing collides. No new pairs + an existing rungs = "current", clean exit.
    rungs_sno_path = os.path.join(OUTDIR, "ALL" + EXT)
    rungs_csv_path = os.path.join(OUTDIR, "ALL.csv")
    _cmd_cols = carried_cmd_cols(rungs_csv_path)
    base_entries = []
    # ⛔⭐⭐ ALL.csv IS READ UNCONDITIONALLY, AND THAT IS THE WHOLE POINT OF READING IT HERE. It used to be
    # loaded inside the `if the suite pair exists` block below, which made the provenance record exactly as
    # deletable as the thing it is provenance FOR. MEASURED (hq_B 2026-08-30, on hq_P's partial-cutover
    # report): `rm ALL.icn ALL.ref` on tests/icon while ALL.csv SURVIVES rebuilds the rungs at 437 entries
    # from 209 families over a committed 534/308, exits 0, calls it "RUNGS SUITE: 437 entries", and
    # overwrites ALL.csv in the same act -- so the only record of the 97 destroyed entries is destroyed by
    # the write that destroyed them.
    # ⭐ A record that dies with its subject cannot testify about it. Loading it here, before any branch on
    # whether the suite pair still exists, is what lets the origin check below survive a partial deletion.
    def _origins_from_csv_text(_text):
        import io as _io
        return {(_r.get("origin") or "").strip() for _r in csv.DictReader(_io.StringIO(_text))} - {""}
    csv_origins = set()
    if os.path.isfile(rungs_csv_path):
        csv_origins = _origins_from_csv_text(open(rungs_csv_path).read())
    else:
        # ⛔⭐⭐ THE THIRD RECORD, AND IT IS THE ONLY ONE THE DESTRUCTIVE COMMAND CANNOT REACH (ceo's routing
        # on hq_P's report, 2026-08-30). The two records above -- the suite pair and ALL.csv -- both live INSIDE
        # the tree being rebuilt, so `rm ALL.*` destroys BOTH IN ONE GESTURE and leaves nothing to compare
        # against: measured, a full wipe rebuilt icon at 437 entries over a committed 534 and exited 0. Reading
        # the committed CSV out of git closes exactly that case, because git's copy is not on the path the
        # command deletes.
        # ⭐ SAME PRINCIPLE AS READING ALL.csv UNCONDITIONALLY, TAKEN ONE STEP FURTHER: a record that dies with
        # its subject cannot testify about it. The first two records die together; the third is outside the
        # write path entirely, which is the whole reason it is worth a subprocess.
        # ⛔ HEAD, DELIBERATELY, NOT origin/main: the question is "what am I about to destroy on THIS tree".
        # A committed retirement is already reflected in HEAD, so an intentional removal produces no false
        # refusal; an UNCOMMITTED deletion does, correctly, and --allow-drop-origin names it one by one.
        # ⛔ Absent git, absent file in HEAD, or any git failure -> silently no third record. This arm can only
        # ever ADD origins to KNOWN, so failing open leaves the previous behaviour exactly as it was.
        try:
            _top = subprocess.run(["git", "-C", OUTDIR, "rev-parse", "--show-toplevel"],
                                  capture_output=True, text=True).stdout.strip()
            if _top:
                _rel = os.path.relpath(rungs_csv_path, _top)
                _r = subprocess.run(["git", "-C", OUTDIR, "show", "HEAD:%s" % _rel],
                                    capture_output=True, text=True)
                if _r.returncode == 0 and _r.stdout.strip():
                    csv_origins = _origins_from_csv_text(_r.stdout)
                    print("NOTE: ALL.csv is absent from disk; recovered %d committed origin(s) from git HEAD "
                          "as the collapse-check baseline." % len(csv_origins), file=sys.stderr)
        except Exception:
            pass
    _csv_stack = {}   # per-entry `stack_kb` carried forward on the same contract (CEO-1225)
    _csv_cmd = {}     # per-entry compile_args and run_args, carried forward on the same contract (clause 8 (f), CEO-1281)
    _csv_heap = {}    # per-entry `heap_kb` carried forward, same contract and for the sharper reason: see
                      # the carried-forward note above -- a dropped declaration is a silent capacity red
    if os.path.isfile(rungs_sno_path) and os.path.isfile(os.path.join(OUTDIR, "ALL.ref")):
        if lang == "snobol4":
            base_entries = h.read_suite(rungs_sno_path, os.path.join(OUTDIR, "ALL.ref"),
                                        in_path=h.sidecar_in_path(rungs_sno_path), x_path=h.sidecar_xfail_path(rungs_sno_path))
        else:
            base_entries = h.read_block_suite(rungs_sno_path, os.path.join(OUTDIR, "ALL.ref"), h.banner_re_for(_CO, _CC),
                                              in_path=h.sidecar_in_path(rungs_sno_path), x_path=h.sidecar_xfail_path(rungs_sno_path))
        _csv_origin = {}
        if os.path.isfile(rungs_csv_path):
            for _row in csv.DictReader(open(rungs_csv_path)):
                _csv_origin[_row["entry"]] = _row.get("origin", "")
                _csv_heap[_row["entry"]] = (_row.get("heap_kb") or "").strip()
                _csv_stack[_row["entry"]] = (_row.get("stack_kb") or "").strip()
                _csv_cmd[_row["entry"]] = {c: (_row.get(c) or "").strip() for c in CMD_COLS}
        for e in base_entries:
            e.origin = _csv_origin.get(e.name) or ("rungs__%s" % e.name)
            e.src_mode = "base"
    # THE DANGEROUS CONDITION IS pairs << base, NOT pairs == 0 (hq_P 2026-08-30, reproduced by seat14;
    # both reverted). Measured on snobol4, which is CUT OVER -- sources retired, the rungs IS the source:
    # 21 loose pairs remain, 19 correctly refused, leaving TWO absorbable. This guard fired only at ZERO, so
    # 2 walked past and the rebuild produced a rung suite of 2 entries where 1576 had been -- the floor's own
    # input, destroyed by a build that reported success.
    # AND IT WAS hq_B's LAW THAT AIMED PEOPLE AT IT: "a guard change requires a CLEAN rebuild" is right for a
    # language with live sources and catastrophic for a cut-over one, because "clean" means deleting ALL.*
    # and THE SAFETY NET IS THE RUNGS ITSELF. hq_P: clobber-by-guard-rebuild is clobber wearing the law as
    # cover.
    # Same shape as the dedupe/clobber pair: ONE AXIS, a correct point in the middle, BOTH ENDS SHIPPING
    # SILENTLY -- too many entries (accumulation) and too few (collapse) each read as an ordinary success.
    # A predicate that tests only one end of an axis is half a guard.
    # ⭐⭐ ORDER MATTERS AND IT IS THE WHOLE FIX (hq_P 2026-08-30, on seat06's measurement): ZERO PAIRS OVER A
    # HEALTHY RUNGS IS THE *SUCCESS* STATE OF CONSOLIDATION, not a collapse. Every lane reaches it the moment
    # its last loose pair is absorbed and deleted -- i.e. exactly when the all-hands work succeeds. With the
    # collapse test first, `0 * 4 < 97` refused raku, prolog and eventually every language, and the message
    # told them not to delete ALL.* -- correct advice for a disaster, addressed to a success.
    # ⛔ The two states ARE distinguishable and the discriminator is not a ratio: with ZERO pairs the builder
    # has nothing to write FROM, so it cannot produce a smaller rungs -- `not pairs` exits without writing a
    # byte. The dangerous case is strictly `0 < pairs << base_entries`: something to write, far too little of
    # it. So the benign branch is checked FIRST and the collapse test now only ever sees pairs > 0.
    if not pairs:
        if base_entries:
            print("RUNGS CURRENT: %d entries, zero new absorbable pairs under %s -- nothing to do." % (len(base_entries), ROOT), file=sys.stderr)
            raise SystemExit(0)
        sys.stderr.write("REFUSED: zero absorbable pairs under %s and no rungs present -- nothing to build from.\n" % ROOT)
        raise SystemExit(2)
    # ⭐⭐ THE COLLAPSE TEST ITSELF MOVED DOWN, past the pair->entries materialization loop -- see the
    # `len(all_entries) * 4 < len(base_entries)` check just before the base merge. It used to stand here
    # and compare PAIRS to ENTRIES, which are different units (hq_B guard, seat06 found the false
    # positive on raku, hq_P swept the rest and named the cause).
    # ⛔⛔ DEDUPE BY ORIGIN AT MERGE TIME (hq_B, measured on rebus: every rebuild DOUBLED the rungs, 174->348,
    # every origin exactly twice -- the exact opposite failure of the clobber merge-mode was added to fix, and the
    # more dangerous one: a bigger board reads as progress). An absorbed pair whose origins ALREADY exist in the
    # base is the SAME entry rebuilt (its source should have been deleted after absorption): skip it LOUDLY, never
    # append a twin. Origin is the ready-made key -- unique per source entry by construction.
    base_origins = {e.origin for e in base_entries}
    for fam, sno, ref, dir_companions in pairs:
        entries = None
        mode = "suite"
        if lang == "snobol4":
            try:
                entries = h.read_suite(sno, ref, in_path=h.sidecar_in_path(sno), x_path=h.sidecar_xfail_path(sno))
                # ⛔ THE seqN DISCRIMINATOR: read_suite names a TAGLESS line `seqN` -- a PLAIN PROGRAM whose line
                # count happens to match its ref's would silently absorb as N bogus entries. Any seqN name means
                # this pair is NOT a suite; fall through to plain-program absorption instead.
                if any(re.fullmatch(r"seq\d+", e.name) for e in entries):
                    entries = None
            except Exception:
                entries = None
            if entries is None:  # plain program: ONE format-B block entry, body and ref VERBATIM
                mode = "plain"
                # ⛔⭐ ASK THE GRADER'S OWN FINDER, NEVER A LOCAL SPELLING LIST (hq_V 2026-09-11). This guard
                # knew `.input` alone and the generalised one below knew `.in/.input`, while the harness knew
                # `.stdin` too -- and `.stdin` is how all 8 icon companions in this corpus are spelled, so the
                # one question that decides whether a program is absorbed had three answers.
                _stdin_txt, _stdin_why = _stdin_text_for_absorption(sno)
                if _stdin_why:
                    excluded.append((fam, "stdin companion cannot be carried faithfully (%s): %s" % (_stdin_sidecar_names(sno), _stdin_why)))
                    continue
                sno_text = open(sno).read().splitlines()
                ref_text = open(ref).read().splitlines()
                if not sno_text:
                    excluded.append((fam, "empty source"))
                    continue
                if any(k in ln for ln in sno_text for k in ("&FILE", "&LASTFILE", "&LASTLINE", "&LASTNO")):
                    excluded.append((fam, "source-identity-sensitive keyword (&FILE/&LASTFILE/...) -- output depends on the source FILENAME, which absorption renames; stays as files (measured: k09/k11/k30/k32 went red in the rungs while green loose)"))
                    continue
                if os.path.basename(sno).startswith("probe_loose_fuzz_"):
                    excluded.append((fam, "fuzz nondeterministic-crash class -- a captured ref is one sample of a distribution; util_fuzz_witness_stability.sh owns these, stays as files"))
                    continue
                if any("../" in ln for ln in sno_text):
                    excluded.append((fam, "scratch-escaping relative reference (../) -- semantics cannot survive isolated-entry grading; stays as files"))
                    continue
                if any(h._is_entry_start(ln) for ln in sno_text):
                    excluded.append((fam, "plain body carries suite-format markers (banner or ';* tag' line) -- a block would split on re-read; quarantined class, stays as files"))
                    continue
                # auto-XFAIL by source verdict -- convert_one's own law applied to plain absorption: a documented-red
                # witness never inflates the rungs' FAIL count, and XPASS polices the marker the day the bug is cured.
                import tempfile as _tf
                _paths = h.resolve_paths()
                _tmp = _tf.mkdtemp(prefix="mstr_")
                try:
                    from pathlib import Path as _P
                    # ⛔ THE PROBE IS FED WHAT THE ENTRY WILL BE FED, or its verdict is about a different run:
                    # an unfed probe on a stdin-reading program stops at EOF and marks the entry xfail for a
                    # starvation the absorbed entry will never experience -- a documented red that documents
                    # the instrument. Same argument, one line down, as carrying the stdin at all.
                    _v = h.run_all_modes(_paths, _P(sno), open(ref).read(), _P(_tmp), ["m3", "m4"], stdin_text=_stdin_txt)
                    _green = all(x.kind == "PASS" for x in _v.values())
                finally:
                    import shutil as _sh
                    _sh.rmtree(_tmp, ignore_errors=True)
                entries = [h.Entry("block", 1, os.path.basename(sno)[:-len(EXT)], sno_text, ref_text, stdin=_stdin_txt, xfail=not _green)]
        else:
            # ⛔⭐ READ EACH SOURCE PAIR WITH ITS OWN DIALECT READER (hq_B, measured: read_suite on a .pl pair returns
            # the whole file as one entry whose body still contains %--- banners -- content that looks like structure).
            # ⛔⭐ THE seqN DISCRIMINATOR ABOVE EXISTS FOR EXACTLY THIS CASE AND WAS SNOBOL4-ONLY, SO THE DIALECT
            # PATH HIT THE VERY BUG ITS COMMENT DESCRIBES. The old fallback handed a BANNERLESS pair to
            # `read_suite` -- SNOBOL4's LINE reader -- which split a 3-line Icon parser fixture into 3 one-line
            # entries and graded each against one line of its AST ref. Measured before the fix: 203 of 472 icon
            # entries carried n_lines=1 with bodies like `end`, and the rungs scored ast_pass=0/472.
            # ⭐ Decide by whether the file HAS a banner, never by whether a reader happened to raise: SNOBOL4 is
            # line-oriented so a bannerless .sno may legitimately be many one-line entries, but in every other
            # dialect a program is inherently multi-line and a bannerless pair is ONE program.
            _bre = h.banner_re_for(_CO, _CC)
            try:
                _slines = open(sno, encoding="utf-8", errors="replace").read().splitlines()
                _rlines = open(ref, encoding="utf-8", errors="replace").read().splitlines()
            except Exception as e:
                excluded.append((fam, "dialect read refused: %s" % str(e)[:140]))
                continue
            if not any(_bre.match(_l) for _l in _slines):
                # ⛔⭐ STDIN GUARD, GENERALISED (ceo amendment on seat04's finding, 2026-08-30). This check
                # existed ONLY on the snobol4 path, so every dialect absorbed a stdin-reading program with NO
                # sidecar -- seat04 measured pascal read1-4 absorbed and grading against /dev/null. An entry
                # that silently reads nothing where it should read its input does not fail loudly; it produces
                # a WRONG ANSWER that looks like a verdict. Checks BOTH sidecar spellings and the config/
                # folder the flat layout puts companions in.
                # ⛔⭐ Same one-finder rule as the plain-program guard above: the spellings live in
                # corpus_suite_harness.STDIN_COMPANION_SUFFIXES and nowhere else, because this list and that
                # one drifted apart by exactly `.stdin` and that gap absorbed 8 icon programs unfed.
                _stdin_txt, _stdin_why = _stdin_text_for_absorption(sno)
                if _stdin_why:
                    excluded.append((fam, "stdin companion cannot be carried faithfully (%s): %s" % (_stdin_sidecar_names(sno), _stdin_why)))
                    continue
                mode = "plain"
                # ⛔ NO AUTO-XFAIL ON THE DIALECT PATH (CEO-753: there is no xfail, and a builder that mints one is the defect;
                # CEO-1230: the modes sweep must not WIDEN the probing). The probe here used to run only for a family declared
                # in MODES.tsv; with the declaration gone, the undeclared path it always took is the one left: xfail stays False,
                # and a pair that does not reproduce its ref reads red on the board, which is where a defect belongs.
                entries = [h.Entry("block", 1, os.path.basename(sno)[:-len(EXT)], _slines, _rlines, stdin=_stdin_txt, xfail=False)]
            else:
                # ⛔⭐ READ THE SIDECARS, exactly as the snobol4 path does. This call passed no in_path/x_path,
                # so a dialect SUITE pair's stdin and xfail sidecars were silently DROPPED -- the entries
                # absorbed and then graded against /dev/null. My first patch guarded only the PLAIN path, and
                # the positive control caught it: planting a .input beside a rebus source excluded NOTHING,
                # and snocone/rebus already carried three real sidecars the build had absorbed regardless.
                # ⭐ A guard that cannot be made to fire is not a guard -- the excluded-count of 0 was the tell,
                # and it was only visible because the count was checked against a planted case rather than read.
                try:
                    entries = h.read_block_suite(sno, ref, _bre,
                                                 in_path=h.sidecar_in_path(sno), x_path=h.sidecar_xfail_path(sno))
                except Exception as e:
                    excluded.append((fam, "dialect read refused: %s" % str(e)[:140]))
                    continue
        for e in entries:
            # ⛔ A BANNERLESS SINGLE-ENTRY FILE HAS e.name == fam (both are the file's own stem, see the
            # "plain" branch above): the naive "fam__name" formula then degenerates to "fam__fam", a
            # self-doubled origin carrying zero extra information (measured: this exact bug was already
            # silently baked into pre-existing entries, e.g. the committed
            # "smoke__role_attr_on_consumer__smoke__role_attr_on_consumer" origin -- found 2026-09-04,
            # row raku-ladder-every-feature-in-isolation-with-variations, seat12 round 6, while absorbing
            # 5 new bannerless rung13 witnesses and seeing every one of their origins doubled the same way).
            # A multi-entry banner-block family still needs "fam__name" to disambiguate WHICH entry within
            # the family, so only the degenerate equal case collapses to the bare name.
            e.origin = _origin_key(fam, e.name)
            e.src_mode = mode
        _dup = [e.origin for e in entries if e.origin in base_origins]
        if _dup:
            if len(_dup) == len(entries):
                # ⭐ FULL-DUPLICATE FAMILIES ARE ELIGIBLE FOR DELETE, NOT JUST EXCLUSION (seat05, 2026-08-30,
                # on the prolog verify+delete row). Every one of THIS family's origins already lives in the
                # base -- not appended a second time (all_entries/included/per_family untouched, so the
                # written rungs and its entry count are unaffected) -- but the source pair is still a
                # deletion CANDIDATE: fed into absorbed_files exactly like a fresh absorption, so the
                # existing BYTE-EQUAL-OR-NO-DELETE loop below re-reads it fresh and compares against the
                # ALREADY-PRESENT base entry (by_origin resolves to that entry either way, since nothing new
                # was added under the same origin). A rebuild that matches deletes; one that doesn't stays,
                # loudly, same failure-closed guarantee as a fresh absorption -- this never trusts the origin
                # match alone as proof of identical content.
                absorbed_files.append((fam, sno, ref, mode))
                excluded.append((fam, "already in the rungs (%d of %d origins present) -- rebuild of an existing entry, not a new one; NOT re-appended to the output, ELIGIBLE for deletion below once its content re-verifies against the existing entry" % (len(_dup), len(entries))))
            else:
                # Mixed family: some origins new, some already present. Not absorbed (would silently drop
                # the already-present half) and not a deletion candidate (would silently drop the new half)
                # -- stays exactly as excluded families always have, needs per-entry handling this pass
                # doesn't build.
                excluded.append((fam, "PARTIAL origin overlap (%d of %d origins already in the rungs) -- mixed new/existing family, left untouched; needs per-entry handling, not this pass's shape" % (len(_dup), len(entries))))
            continue
        per_family[fam] = len(entries)
        all_entries.extend(entries)
        absorbed_files.append((fam, sno, ref, mode))
        included.append(fam)
        # ⛔ COMPANIONS RIDE ALONG (the v3 board's fail-delta root cause): run_suite_entry copies the SUITE FILE'S OWN
        # DIR into each entry's scratch, so an absorbed family whose dir carried companion files (crosscheck's .in,
        # beauty's .inc) would grade a DIFFERENT program from rungs/ unless those companions move with it. Copy them
        # in, refusing on basename collision with different content -- never silently shadowed.
        src_dir = os.path.dirname(sno)
        if os.path.abspath(src_dir) != os.path.abspath(OUTDIR):
            for cf in sorted(os.listdir(src_dir)):
                cext = os.path.splitext(cf)[1]
                if cext in (EXT, ".ref", ".md", ".txt", ".csv", ".s", ".expected") or not os.path.isfile(os.path.join(src_dir, cf)):
                    continue
                if cext in (".in", ".xfail") and os.path.isfile(os.path.join(src_dir, os.path.splitext(cf)[0] + EXT)):
                    continue  # a SIDECAR of some suite in this dir -- its content threads through read/write sidecars, never a raw copy
                dst = os.path.join(OUTDIR, cf)
                srcf = os.path.join(src_dir, cf)
                if os.path.exists(dst) and open(dst, "rb").read() != open(srcf, "rb").read():
                    h.refuse("companion basename collision with different content: %s (from %s)" % (cf, src_dir))
                companion_copies[cf] = srcf
    # feature scan first (names are DERIVED from features), then the descriptive rename with numbered uniqueness
    # ⛔⭐⭐ THE COLLAPSE REFUSAL IS AN ORIGIN-SET CHECK, NOT A COUNT. It was `len(pairs)*4 < len(base)`,
    # then `len(all_entries)*4 < len(base)` with a non-empty guard, and BOTH were wrong in both directions.
    # The count era is worth keeping in view because each fix looked complete and each one was a calibration:
    #   · pairs vs entries -- different UNITS. snobol4's one-liner tree runs ~1:1 so a pair count proxies
    #     fine THERE and nowhere else; in the banner-block format one pair carries a whole family. False
    #     refusals: raku 15 pairs/97 entries, snocone 34/264. (seat06 found it, hq_P swept it.)
    #   · then zero-new read as a collapse -- but `all_entries = base + []` rewrites the rungs AS ITSELF.
    #   · and even fixed, it FALSE-REFUSED icon's ordinary merge rebuild: 209 pairs, 208 already absorbed,
    #     1 genuinely new over a 534-entry rungs. 1*4 < 534. Benign growth, refused. Measured, not argued.
    #   · while STILL missing the real thing: hq_P's partial cutover. 209 surviving pairs materialize 437
    #     entries against a committed 534 -- not `<<` by any ratio anyone would dare set, because the
    #     surviving sources keep the RATIO healthy while a disjoint SUBSET has no source at all.
    # ⭐⭐ THE DURABLE FORM, AND IT IS hq_P's: A COUNT CANNOT DETECT A SUBSTITUTION. 437 vs 534 happens to
    # differ; absorb 100 while another seat adds 100 elsewhere and the totals MATCH while the content is
    # entirely different. Identity is the question, so identity is the check: any origin the rungs is known
    # to hold must still be in the rungs about to be written. No threshold, nothing to calibrate per
    # language, and it names what it lost instead of reporting a ratio nobody can act on.
    # ⛔ KNOWN comes from TWO independent records deliberately -- ALL.csv (read above, survives deleting the
    # suite pair) and the base entries read back out of the suite itself. Their union means a LOSSY SUITE
    # READ is caught too: if read_suite ever swallows entries again (it has), base is short, the CSV is not,
    # and the rebuild refuses instead of quietly writing the smaller rungs.
    # ⛔ STILL NOT COVERED, and no in-process check can cover it: a FULL `rm ALL.*` destroys both records at
    # once, so there is nothing left to compare against. That is why the builder must own its own deletion
    # (hq_P's --clean; row snobol4-master-guard-sync-and-builder-shrink-refusal, hq_C). This check shrinks
    # that hole from "any clean rebuild" to "a full ALL.* wipe", it does not close it.
    written_origins = {e.origin for e in base_entries} | {e.origin for e in all_entries}
    known_origins = csv_origins | {e.origin for e in base_entries}
    dropped = sorted(known_origins - written_origins - allow_drop)
    if dropped:
        _shown = dropped[:15]
        sys.stderr.write(
            "\u26d4 REFUSED: this rebuild would DROP %d origin(s) the rungs already holds.\n"
            "   Nothing has been written; the existing rungs is untouched.\n"
            "   An origin present in ALL.csv or in the current rungs, with no source under %s that\n"
            "   rebuilds it, means those entries exist ONLY in the rungs -- absorbed from outside this\n"
            "   tree, or their sources retired. Rebuilding writes a rung suite without them.\n"
            "   Dropped origin(s)%s:\n%s\n"
            "   \u26d4 Do NOT 'fix' this by deleting ALL.* -- that destroys the CSV too, and the CSV is the\n"
            "      only reason this refusal was possible. Rebuild into a scratch tree and diff.\n"
            "   \u2705 If a retirement is DELIBERATE, name each one: --allow-drop-origin=<a>[,<b>...]\n"
            "      Surgical and attributable, per the floor doctrine -- never a blanket override.\n"
            % (len(dropped), ROOT,
               "" if len(dropped) <= 15 else " (first 15 of %d)" % len(dropped),
               "\n".join("     " + o for o in _shown)))
        raise SystemExit(2)
    counters = {}
    all_entries = base_entries + all_entries
    for e in base_entries:  # seed the counters PAST every existing name so new names never collide
        m = re.fullmatch(r"(.*)_(\d+)", e.name)
        if m:
            counters[m.group(1)] = max(counters.get(m.group(1), 0), int(m.group(2)))
    rows = []
    for e in all_entries:
        text = "\n".join(e.sno_lines)
        flags = {c: fn(text) for c, fn in COLS}   # == attrs_for_text(text, lang); COLS is the same table, rebound by main()
        if getattr(e, "src_mode", "") == "base":
            rows.append((e, flags, text))   # a BASE entry keeps its name -- names are stable identifiers (merge-never-replace)
            continue
        base = descriptive_name(text, flags)
        counters[base] = counters.get(base, 0) + 1
        new = "%s_%d" % (base, counters[base])
        old = e.name
        if e.kind == "line":  # a format-A entry carries its name IN the line's trailing `;* <name>` tag -- rename BOTH or read_suite re-derives the old name from the tag and the round-trip check refuses (measured, first build)
            ln = e.sno_lines[0]
            tag = ";* %s" % old
            if ln.endswith(tag):
                e.sno_lines[0] = ln[: -len(tag)] + ";* %s" % new
        e.name = new
        rows.append((e, flags, text))
    # -- LEVEL ORDERING (Lon 2026-08-29, third ruling same session, verbatim in substance: "the concept of smoke, regression,
    # rungs, pattern, feature specific, these ideas all go away and are replaced by a list of tests with as many attributes as
    # you need... Then a smoke test would be say the first 20-50 tests. Then you can extend another level at 100-200. Then the
    # last level all 1200+ being the full regression.") -- the list is ORDERED simple-green-first so a level is a PREFIX of it:
    # green before xfail (a smoke set must be expected-green), fewer features before more, shorter before longer. The CSV's
    # `rank` column is the position; a runner takes level N by taking rank <= N.
    order = sorted(range(len(rows)), key=lambda i: rungs_file_key(rows[i][0], rows[i][1]))
    all_entries = [rows[i][0] for i in order]
    rows = [rows[i] for i in order]
    names = [e.name for e in all_entries]
    dup = {n for n in names if names.count(n) > 1}
    if dup:
        h.refuse("rungs merge name collision(s): %s" % sorted(dup)[:5])
    # -- BYTE-EQUAL-OR-NO-DELETE (the house law, applied to absorption): every absorbed source pair is re-read FRESH
    # from disk and compared entry-by-entry against the written rungs. A family that does not verify is NEVER deleted.
    # ⭐ GENERALISED PAST SNOBOL4 (seat05, 2026-08-30, on the ceo all-hands consolidation directive): this used to gate
    # on `ok = lang == "snobol4"`, so EVERY non-snobol4 family landed in `unverified` unconditionally, regardless of
    # whether it actually matched -- --delete-absorbed could never delete a single prolog/raku/snocone/rebus file, not
    # because anything failed to verify, but because verification was never attempted for them at all. That silent
    # short-circuit is now gone: every language re-reads its pair with the SAME dialect reader `main()` used to absorb
    # it in the first place (read_block_suite, falling back to read_suite for a genuine one-line-dialect pair -- the
    # identical fallback used at absorption time above) and compares entry-by-entry, same fields, same failure-closed
    # `except Exception: ok = False`. snobol4's own "plain" (whole-file, non-suite) absorption keeps its dedicated
    # whole-file comparison unchanged -- that shape does not exist for any other language (mode is always "suite"
    # outside the snobol4 branch, see main()'s absorption loop above), so it is untouched, not generalised.
    # ⛔⭐ COMPUTED HERE, BEFORE ANY WRITE (requirement 3, extended): this loop and the selector refusal right after
    # it only ever READ the original source files plus in-memory `rows` -- nothing here depends on the rungs
    # having been written. MEASURED why that matters: `--only <fams> --delete-absorbed` on a tree where <fams>
    # themselves aren't absorbable (see below) still legitimately absorbs OTHER, unrelated undeclared pairs first
    # -- a real, valid write -- and only then discovers the selector matches zero VERIFIED families and refuses.
    # Computing the verified/selected set before the rungs is even staged means that refusal now precedes any
    # write at all, so the "REFUSED, nothing written" guarantee covers the selector check too, not only the
    # round-trip check below.
    by_origin = {}
    for e, flags, text in rows:
        by_origin[e.origin] = e
    verified, unverified = [], []
    for fam, sno, ref, mode in absorbed_files:
        ok = True
        try:
            if mode == "plain":
                # ⛔⭐ HALF-GENERALIZED CONTRACT, THE FOURTH INSTANCE (seat07 2026-08-30, on the task file's
                # own newly-adopted law naming this exact class): this branch used to read
                # `lang == "snobol4" and mode == "plain"`, but mode=="plain" stopped being SNOBOL4-only the
                # moment hq_P's bannerless-dialect-as-ONE-entry fix landed (absorption above sets mode="plain"
                # for ANY language's bannerless single-file family, not just SNOBOL4's own historic plain-file
                # class) -- the ABSORPTION half of the contract generalized, the VERIFICATION half's language
                # guard did not. MEASURED: a from-scratch rebus rebuild under this exact tree read "VERIFIED: 1
                # families; UNVERIFIED: 33" -- every one of the 33 bannerless AST-drift stems fell through to
                # the `else` branch below, which has no banner to find, so its read_block_suite/read_suite
                # fallback fragmented each file into seqN one-line entries matching no origin in `by_origin`.
                # The comparison body itself was ALREADY language-agnostic (EXT is already the resolved
                # extension for whichever --lang is running, os.path.basename/sidecar_in_path assume nothing
                # SNOBOL4-specific) -- only the gate needed to drop the language check.
                # ⛔⭐⭐ A CHECK THAT DOES NOT CARRY EVERY FIELD THE GRADER READS IS NOT A CHECK (hq_C, 2026-08-30,
                # from their own --split-write round trip which PASSED while dropping stdin for all 9
                # stdin-bearing snobol4 entries -- it compared bodies only). This comparison authorizes
                # DELETING the source, so a field it does not check is a field that can be silently lost
                # forever. It compared sno_lines and ref only: an absorbed entry whose stdin or xfail was
                # dropped verified CLEAN and its source became deletable.
                # ⛔ AND rc CANNOT SUBSTITUTE FOR THE FIELD CHECK. hq_C measured snobol4
                # arb_capture_alt_replace_branch_1: WITH stdin rc=0 and 9 bytes "cat/house"; WITHOUT stdin
                # rc=0 and ZERO bytes. IDENTICAL EXIT CODE. A stdin-starved program exits perfectly cleanly
                # and simply produces nothing, so only comparing the FIELD detects it.
                e = by_origin.get(_origin_key(fam, os.path.basename(sno)[:-len(EXT)]))
                _src_in = h.sidecar_in_path(sno)
                _want_stdin = open(_src_in).read() if (_src_in and os.path.isfile(str(_src_in))) else None
                ok = e is not None and e.sno_lines == open(sno).read().splitlines() and \
                    (e.ref if isinstance(e.ref, list) else str(e.ref).split("\n")) == open(ref).read().splitlines() and \
                    (e.stdin or None) == (_want_stdin or None)
            else:
                if lang == "snobol4":
                    reread = h.read_suite(sno, ref, in_path=h.sidecar_in_path(sno), x_path=h.sidecar_xfail_path(sno))
                else:
                    # ⛔⭐ RE-READ WITH THE SAME BANNER-PRESENCE DISCRIMINATOR ABSORPTION USES, NOT A TRY/EXCEPT
                    # FALLBACK (seat05, 2026-08-30 -- this was the try/read_block_suite/except/read_suite shape
                    # absorption ITSELF used when this verification code was first written; hq_B's 13c186ea
                    # rewrote absorption to decide by banner presence instead, and this comparison silently went
                    # stale against it -- the two-independent-copies-of-one-decision class RULES.md's TRANSCRIPTION
                    # rule warns about, just inside one file instead of across two). MEASURED, not assumed: a
                    # genuinely byte-identical banner-less block family (rung05_backtrack_backtrack, content
                    # confirmed identical by hand) read WRONG under the old try/except -- read_block_suite raising
                    # on a bannerless file, the except then handing a multi-line prolog program to read_suite
                    # (SNOBOL4's ONE-LINE reader), producing garbage that never matched. Mirrors main()'s own
                    # discriminator exactly. ⛔ SIDECARS TOO (hq_C, same night, in-conflict with this rewrite --
                    # folded in rather than reverted): the dialect re-read must load what the grader loads, or
                    # `se.stdin` is always None and a real stdin mismatch compares None==None and passes. The
                    # banner-PRESENT arm below passes in_path/x_path exactly as hq_C's fix does; the banner-
                    # ABSENT arm needs no sidecar load at all, because absorption's own STDIN GUARD above
                    # (search "STDIN GUARD, GENERALISED") already refuses any bannerless file that HAS one
                    # before it can ever reach absorbed_files -- there is structurally nothing to load.
                    _bre_v = h.banner_re_for(_CO, _CC)
                    _slines_v = open(sno, encoding="utf-8", errors="replace").read().splitlines()
                    _rlines_v = open(ref, encoding="utf-8", errors="replace").read().splitlines()
                    if not any(_bre_v.match(_l) for _l in _slines_v):
                        reread = [h.Entry("block", 1, os.path.basename(sno)[:-len(EXT)], _slines_v, _rlines_v)]
                    else:
                        reread = h.read_block_suite(sno, ref, _bre_v,
                                                    in_path=h.sidecar_in_path(sno), x_path=h.sidecar_xfail_path(sno))
                for se in reread:
                    e = by_origin.get(_origin_key(fam, se.name))
                    if e is None or e.kind != se.kind or (e.stdin or None) != (se.stdin or None):
                        ok = False
                        break
                    if e.kind == "line":
                        strip = lambda ln, nm: ln[: -len(";* %s" % nm)] if ln.endswith(";* %s" % nm) else ln
                        if strip(e.sno_lines[0], e.name) != strip(se.sno_lines[0], se.name) or e.ref != se.ref:
                            ok = False
                            break
                    else:
                        if e.sno_lines != se.sno_lines or e.ref != se.ref or bool(e.xfail) != bool(se.xfail):
                            ok = False
                            break
        except Exception:
            ok = False
        (verified if ok else unverified).append((fam, sno, ref))
    # ⭐ FILTER, NEVER RE-DERIVE: to_delete is a SUBSET of this same run's `verified` list, computed
    # by the identical byte-equal-or-no-delete loop above -- a family excluded by the selector is
    # left exactly as untouched as an UNVERIFIED one, never a second, weaker verification path.
    if family_prefix is not None:
        to_delete = [t for t in verified if t[0].startswith(family_prefix)]
        selector_label = "--family %r" % family_prefix
    elif only_families is not None:
        to_delete = [t for t in verified if t[0] in only_families]
        selector_label = "--only %s" % ",".join(sorted(only_families))
    else:
        to_delete = verified
        selector_label = None
    # ⛔ A SELECTOR MATCHING ZERO VERIFIED FAMILIES REFUSES rc=2 (DONE-WHEN, this row) -- a typo'd
    # prefix or a misspelled name would otherwise silently delete nothing while --delete-absorbed
    # still exits 0, which reads exactly like success. Checked even in dry-run mode (no --delete-
    # absorbed cannot reach here at all per the refusal above, so this only ever gates a real delete).
    if selector_label is not None and not to_delete:
        sys.stderr.write("REFUSED: %s matches zero of the %d verified families this run -- nothing to delete.\n" % (selector_label, len(verified)))
        raise SystemExit(2)
    out_sno = os.path.join(OUTDIR, "ALL" + EXT)   # ⭐ per-language: ALL.sno / ALL.pl / ALL.raku / ALL.sc / ALL.reb
    out_ref = os.path.join(OUTDIR, "ALL.ref")
    out_in = os.path.join(OUTDIR, "ALL.in")
    out_x = os.path.join(OUTDIR, "ALL.xfail")
    out_csv = os.path.join(OUTDIR, "ALL.csv")
    out_excl = os.path.join(OUTDIR, "ALL.excluded.txt")
    for e_i, e in enumerate(all_entries, 1):
        e.seq = e_i
    # ⛔⭐ VALIDATE BEFORE IT WRITES (requirement 3). MEASURED: the previous shape wrote ALL.sno/ALL.ref (and
    # copied companions into config/) directly to their real paths, THEN re-read the REAL files to verify the
    # round trip -- so a failing verification had already mutated the real rungs (534 -> 536 entries on one
    # observed run) and the only undo was `git checkout`. A refusal that has already mutated shared state is
    # not a refusal.
    # ⭐ Fix: every file this function writes lands on a PID-suffixed temp sibling first (companions under
    # config/<name><tag>). Only after the re-read confirms the round trip do the temp files replace the real
    # ones, via os.replace -- always same-directory-as-target here, so each replace is atomic. A validation
    # failure, or any exception during the write/verify phase, now leaves the real tree byte-for-byte as it
    # was when main() started; _cleanup_tmp() removes the scratch copies and the exception propagates.
    _tag = ".tmp-%d" % os.getpid()
    tmp_sno, tmp_ref, tmp_in, tmp_x = out_sno + _tag, out_ref + _tag, out_in + _tag, out_x + _tag
    tmp_csv, tmp_excl = out_csv + _tag, out_excl + _tag
    _cfg = os.path.join(OUTDIR, "config")
    tmp_companions = {cf: os.path.join(_cfg, cf + _tag) for cf in companion_copies}

    def _cleanup_tmp():
        for p in [tmp_sno, tmp_ref, tmp_in, tmp_x, tmp_csv, tmp_excl] + list(tmp_companions.values()):
            if os.path.exists(p):
                os.remove(p)

    try:
        if lang == "snobol4":
            h.write_suite(all_entries, tmp_sno, tmp_ref)
            wrote_in = h.write_stdin_sidecar(all_entries, tmp_in, "*", "")
            if not wrote_in and os.path.exists(tmp_in):
                os.remove(tmp_in)
            wrote_x = h.write_xfail_sidecar(all_entries, tmp_x, "*", "")
            if not wrote_x and os.path.exists(tmp_x):
                os.remove(tmp_x)
            reread = h.read_suite(tmp_sno, tmp_ref,
                                  in_path=(tmp_in if wrote_in else None), x_path=(tmp_x if wrote_x else None))
        else:
            # ⛔⭐ THE SIDECAR WRITERS WERE SNOBOL4-ONLY TOO (ceo amendment). A dialect rungs got no ALL.in and no
            # ALL.xfail, so any absorbed stdin-carrying entry lost its input and any xfail lost its marker -- both
            # silently. The writers are already parameterised by comment leader; the dialect branch simply never
            # called them. Re-read WITH the sidecars, or the round-trip check verifies a file the grader will not
            # actually use.
            h.write_block_suite(all_entries, tmp_sno, tmp_ref, _CO, _CC)
            wrote_in = h.write_stdin_sidecar(all_entries, tmp_in, _CO, _CC)
            if not wrote_in and os.path.exists(tmp_in):
                os.remove(tmp_in)
            wrote_x = h.write_xfail_sidecar(all_entries, tmp_x, _CO, _CC)
            if not wrote_x and os.path.exists(tmp_x):
                os.remove(tmp_x)
            reread = h.read_block_suite(tmp_sno, tmp_ref, h.banner_re_for(_CO, _CC),
                                        in_path=(tmp_in if wrote_in else None), x_path=(tmp_x if wrote_x else None))
        if len(reread) != len(all_entries):
            h.refuse("re-read count %d != written %d -- NOT trusting the merge; validated in a scratch copy "
                     "first, so the real tree was never touched" % (len(reread), len(all_entries)))
        # ⛔ ORDER, NOT JUST COUNT (measured 2026-09-05, row three-master-builder-gates-are-red-at-head):
        # the writer (write_suite) silently re-partitions kind="line" entries before every other kind, so
        # `all_entries`' own order can disagree with what actually landed on disk while this check stayed
        # silent -- exactly the "silently mis-paired ALL.sno/ALL.ref/ALL.csv" failure mode this builder
        # exists to prevent. `all_entries` is already in rungs_file_key order (see `order` above), which
        # IS the order write_suite produces, so this should always hold; a refusal here means the two have
        # drifted apart, which the CSV's rank column (assigned from `rows` below) would otherwise get wrong.
        if [r.name for r in reread] != [e.name for e in all_entries]:
            h.refuse("re-read ORDER does not match the written order -- the rungs' physical file and its "
                     "CSV rank would silently disagree; NOT trusting the merge (validated in a scratch copy, "
                     "the real tree was never touched)")
        with open(tmp_csv, "w", newline="") as f:
            w = csv.writer(f, lineterminator="\n")
            w.writerow(["rank", "entry", "origin", "family", "kind", "xfail", "n_lines", "heap_kb", "stack_kb"] + _cmd_cols + [c for c, _ in COLS])
            for rank, (e, flags, text) in enumerate(rows, 1):
                fam = e.origin.split("__", 1)[0]
                w.writerow([rank, e.name, e.origin, fam, e.kind, int(bool(e.xfail)), len(e.sno_lines), (_csv_heap.get(e.name, "") or DEFAULT_HEAP_KB), (_csv_stack.get(e.name, "") or DEFAULT_STACK_KB)] + [_csv_cmd.get(e.name, {}).get(c, "") for c in _cmd_cols] + [flags[c] for c, _ in COLS])
        # ⛔⭐ MERGE, NEVER OVERWRITE (hq_P seat08 2026-09-04, row snobol4-every-non-package-source-...): this
        # run only ever discovers tests/<lang>/ loose-pair exclusions -- it has no opinion on additive
        # (demos/benchmarks) exclusions a DIFFERENT run of this same builder (--additive) already wrote, and a
        # blind overwrite here silently erased every one of them the instant this path next ran. MEASURED: 24
        # additive-mode lines (14 demos + 10 benchmarks) destroyed by one plain `--lang snobol4` run, with no
        # warning from either run -- only util_unabsorbed_census.py's OWED count noticed, and only because it
        # was re-checked immediately after. Same merge discipline as _additive_write_sidecar_merge, inlined
        # here because that helper couples its read-path and write-path (this call reads the REAL out_excl but
        # must stage to tmp_excl, same as every other file in this transaction).
        _excl_existing = {}
        if os.path.isfile(out_excl):
            for _line in open(out_excl, encoding="utf-8", errors="replace"):
                _line = _line.rstrip("\n")
                if _line and "\t" in _line:
                    _k, _v = _line.split("\t", 1); _excl_existing[_k] = _v
        # ⛔ CEO-545: this file is GENERATED and a hand edit to it is not honoured -- see _excl_guard's own
        # docstring for the two measured arms. Refuse here rather than absorb the edit silently.
        _excl_guard(out_excl, _excl_existing)
        _excl_existing.update({fam: why for fam, why in excluded})
        # ⛔⭐ AN ABSORBED FAMILY LEAVES THIS FILE, AND THE MERGE ALONE WOULD NEVER LET IT (hq_V 2026-09-11,
        # measured on rung36_jcon_others). The merge above is right to never delete a line it did not write --
        # that is what protects another run's additive exclusions -- but it made an exclusion PERMANENT: the
        # moment a family is released and absorbed, its old row survives and the same program is BOTH in the
        # graded denominator AND named as "never absorbed (deferral contract)". The two readings cannot both
        # be true, and the file that contradicts the rungs is the one every census reads.
        # ⛔ IT IS NOT A HAND EDIT AND MUST NOT BE ONE: CEO-545 makes this file GENERATED and _excl_guard
        # REFUSES rc=2 on an edit, correctly -- which leaves the builder itself as the only thing that can
        # retract a row. The retraction is still DECLARED where the ceo's rule says (KEEP.md/PENDING.md); this
        # only stops the generated file from outliving the declaration it was generated from.
        # ⛔⭐⭐ TWO CONDITIONS, AND THE SECOND ONE IS THE WHOLE CURE -- MY FIRST VERSION HAD ONLY THE FIRST AND
        # WOULD HAVE DELETED 191 ROWS INSTEAD OF 1, WHICH I FOUND BY READING WHAT IT PROPOSED TO DELETE RATHER
        # THAN BY TRUSTING THE RULE. "The family is in the rungs" DOES NOT MEAN "this row is stale": 153 of
        # those rows are `parser_*` loose pairs that are deliberate KEEPERS in parser/KEEP.md while entries of
        # the same family name were absorbed from elsewhere long ago. Both readings were true at once, and the
        # naive rule would have silently retired 153 live declarations -- the origin-keyed-guard trap this
        # corpus already paid for once (corpus/tests/icon/KEEP.md's own double-count note).
        #   (1) IN THE DENOMINATOR: the family's origin appears in the entries being written.
        #   (2) AND NOT EXCLUDED BY THE LIVE TREE THIS RUN: `excluded` is recomputed from scratch every run, so
        #       a row that this run did NOT re-emit is a row whose declaration is GONE, while every still-live
        #       keeper re-emits itself and is kept. This is also what protects another run's --additive rows:
        #       a demo excluded by an --additive run is absent from the rungs, so (1) already spares it.
        _absorbed_fams = {e.origin.split("__", 1)[0] for e in all_entries}
        _live_excl = {fam for fam, _why in excluded}
        _retracted = sorted(k for k in _excl_existing if k in _absorbed_fams and k not in _live_excl)
        for _k in _retracted:
            del _excl_existing[_k]
        if _retracted:
            sys.stderr.write("⭐ EXCLUSION RETRACTED for %d absorbed famil(y/ies) -- now in the graded denominator, "
                             "so they cannot also be named as excluded from it: %s\n" % (len(_retracted), ", ".join(_retracted)))
        with open(tmp_excl, "w", encoding="utf-8", newline="\n") as f:
            for fam in sorted(_excl_existing):
                f.write("%s\t%s\n" % (fam, _excl_existing[fam]))
            f.write("%s %s\n" % (EXCL_DIGEST_TAG, _excl_digest(_excl_existing)))
        if companion_copies:
            os.makedirs(_cfg, exist_ok=True)
            for cf, srcf in sorted(companion_copies.items()):
                shutil.copy2(srcf, tmp_companions[cf])
    except BaseException:
        _cleanup_tmp()
        raise
    # -- VALIDATED: commit every staged file over its real path now, and only now. ---------------------------
    # ⛔⭐⭐ EVERY COMMITTED PATH IS RECORDED HERE SO THE SIGN-OFF CAN NAME IT (hq_V 2026-09-10, measured, to
    # hq_T's instruments lane). This tool's last line used to read "(dry run: pass --delete-absorbed …)" — true
    # of the DELETION step, and eighty lines of output after the write, so it was read as a verdict on the whole
    # run. It is not: by the time it prints, ALL.<ext>/ALL.ref/ALL.csv (and ALL.in) have already been replaced
    # on disk. hq_V ran `--absorb-only FAMILY` with no `--write` to ASK A QUESTION, took the words at face
    # value, and kept using entry line numbers read beforehand: the rungs had gone 912 → 913 entries, every
    # banner had moved 39–50 lines, a line-sliced extract silently became the wrong text, and the grading then
    # raised a banner-mismatch ValueError that reads exactly like a corrupt rungs pair. A cycle went on
    # suspecting the corpus. ⭐ THE GENERAL FORM: a tool's LAST LINE is read as its verdict on the run, whatever
    # earlier lines said — so a true statement about one step, placed last, is a false statement about the whole.
    # ⛔ And the exposure is not one seat's afternoon: CEO-452 gives the Icon rungs exactly ONE writer because
    # it is a built artifact two seats cannot merge, so an INSPECTION-SHAPED invocation that rewrites all four
    # files can leave an uncommitted, unmeasured rungs under any seat that ran it to ask a question.
    _committed = []
    os.replace(tmp_sno, out_sno); _committed.append(out_sno)
    os.replace(tmp_ref, out_ref); _committed.append(out_ref)
    if wrote_in:
        os.replace(tmp_in, out_in); _committed.append(out_in)
    elif os.path.exists(out_in):
        os.remove(out_in); _committed.append(out_in + " (removed)")
    if wrote_x:
        os.replace(tmp_x, out_x); _committed.append(out_x)
    elif os.path.exists(out_x):
        os.remove(out_x); _committed.append(out_x + " (removed)")
    os.replace(tmp_csv, out_csv); _committed.append(out_csv)
    os.replace(tmp_excl, out_excl); _committed.append(out_excl)
    # ⭐⭐ COMPANIONS GO IN config/, NOT THE FLAT DIR (hq_P 2026-08-30, ceo routed the cure to the finder).
    # Lon's end state is tests/<lang>/ FLAT with ALL.* plus ONE config/ folder holding runtime companions.
    # The harness READ side already implements it -- _copy_companions searches <dir> AND <dir>/config
    # (corpus_suite_harness.py:1105) -- but this WRITER still dropped them in OUTDIR, so the law was
    # half-implemented and moving them by hand was undone by the next rebuild. Sixth instance this week of one
    # half of a contract moving while the other stayed behind; the standing check (grep the other side of the
    # pair in the same commit) is exactly what would have caught it.
    # ⛔ MOVE semantics matter: the reader lets a name in the FLAT dir WIN over config/, so a stale top-level
    # copy would silently shadow the config/ one. The build writes only to config/ and clears any flat twin.
    for cf, srcf in sorted(companion_copies.items()):
        os.replace(tmp_companions[cf], os.path.join(_cfg, cf))
        _stale = os.path.join(OUTDIR, cf)
        if os.path.isfile(_stale) and os.path.abspath(_stale) != os.path.abspath(srcf):
            os.remove(_stale)
    # ⛔⭐⭐ AND THEN THE CLOSURE THE ENTRIES THEMSELVES NAME, WHICH THE LOOP ABOVE STRUCTURALLY CANNOT SEE
    # (hq_T 2026-09-05; FINDING-2026-09-05-hq_T-companions-live-outside-the-master-directory-so-26-of-31-entries-
    # cannot-resolve-them.md, ceo routed the instrument half here). The copy above rides along with an ABSORPTION:
    # it takes the files sitting in the absorbed family's OWN directory at the moment it is absorbed. Two whole
    # classes escape that, and both were live in the snobol4 rungs:
    #   · an entry whose companion never lived beside it -- `-INCLUDE 'global.inc'` naming corpus/include/global.inc,
    #     the shared include tree the beauty-suite drivers were written against (their headers still say -Idemo/inc);
    #   · EVERY entry already in the rungs on a rebuild that absorbs nothing -- `companion_copies` is empty then, so
    #     a gap that exists today is never repaired by any number of future rebuilds.
    # ⛔ THE "25 companions, 26 entries graded against absent dependencies" FIGURE IS RETRACTED (hq_T, 2026-09-05):
    # the harness sets SNO_LIB=<corpus>/include, where those companions live, so they resolved. What survives is the
    # narrower true statement -- a companion reachable only via an env var is an UNDECLARED dependency of the entry --
    # and the reason below, which never depended on the count. ⭐ And it never announced
    # itself -- a missing include is not a special error, the entry just fails and the diff reads as a semantic
    # divergence in SCRIP. Two lanes reached "SCRIP is wrong" from this class in one day.
    # ⭐ WHY HERE AND NOT IN THE GRADER: the grader's isolation -- an entry sees exactly the files the corpus put
    # beside it -- is what makes a board reproducible. Teaching it to reach back into corpus/include/ at run time
    # would buy the same files at the price of that property. So the closure is resolved at BUILD time against a
    # DECLARED path (tests/<lang>/config/COMPANION_PATH) and materialized where the grader already looks.
    # ⛔ NEVER A CORPUS-WIDE BASENAME SCAN: `VBGinTASA.dat` names three different files in this corpus and one of
    # them is another language's (md5 48c78061 vs 98e80802). lib_companion_closure REFUSES an ambiguous basename
    # rather than picking by walk order; here that refusal is printed and the file is left alone -- the rungs is
    # already committed above, and a bookkeeping copy must never be able to undo a validated write.
    try:
        sys.path.insert(0, HERE)
        import lib_companion_closure as _lcc
        _clo = _lcc.closure(["\n".join(e.sno_lines) for e in all_entries], OUTDIR, os.path.join(S4E, "corpus"))
        for _n, _a, _b in _clo["ambiguous"]:
            print("⛔ COMPANION AMBIGUOUS, NOT COPIED: %s resolves to %s and %s (different content) -- declare a "
                  "narrower dir in config/%s" % (_n, _a, _b, _lcc.PATH_DECL_BASENAME), file=sys.stderr)
        if _clo["materializable"]:
            os.makedirs(_cfg, exist_ok=True)
            for _n, _src in sorted(_clo["materializable"].items()):
                _dst = os.path.join(_cfg, _n)
                os.makedirs(os.path.dirname(_dst) or _cfg, exist_ok=True)
                shutil.copy2(_src, _dst)
            print("COMPANION CLOSURE: materialized %d file(s) into %s/config -> %s"
                  % (len(_clo["materializable"]), os.path.relpath(OUTDIR, S4E), ", ".join(sorted(_clo["materializable"]))),
                  file=sys.stderr)
        else:
            print("COMPANION CLOSURE: %d name(s) named, all already reachable beside the rungs (%d unresolvable -- see "
                  "util_rungs_companion_closure.py --lang %s for the list)"
                  % (len(_clo["reachable"]), len(_clo["unresolvable"]), lang), file=sys.stderr)
    except Exception as _e:   # ⛔ LOUD, NEVER FATAL: the rungs pair is committed above and is correct; a companion
        # bookkeeping failure must not make a good build look like a failed one. The gate
        # (test_gate_rungs_companions_resolve.sh) is what turns an unrepaired gap red.
        print("⛔ COMPANION CLOSURE FAILED (the rungs itself is written and valid): %r" % (_e,), file=sys.stderr)
    # ⛔⭐ SEPARATE "ALREADY PRESENT" FROM "CANNOT ABSORB" (hq_P, 2026-08-30, on the dedupe landing; the
    # confusing case measured by hq_B on rebus). After dedupe, an idempotent no-op rebuild records every
    # already-absorbed family as an exclusion -- so it printed "48 entries from 0 FAMILIES" with
    # "EXCLUDED: 34", which is self-contradictory on its face and reads as a total absorption failure. The
    # real absorption run had written EXCLUDED: 0.
    # ⭐ THIS IS THE DOUBLING TELL POINTING THE OTHER WAY, and that makes it more expensive rather than less:
    # a summary number moving for a benign reason. The doubling moved the REASSURING way and hid a bug; this
    # moves the ALARMING way and will cost a seat an investigation. Sixteen of them are running this builder
    # right now, so the two exclusion CLASSES must not share one count.
    _already = [(f, w) for f, w in excluded if w.startswith("already in the rungs")]
    _cannot  = [(f, w) for f, w in excluded if not w.startswith("already in the rungs")]
    if included:
        print("RUNGS SUITE: %d entries from %d families -> %s" % (len(all_entries), len(included), OUTDIR), file=sys.stderr)
    else:
        print("RUNGS SUITE: %d entries, NOTHING NEW ABSORBED (idempotent rebuild) -> %s" % (len(all_entries), OUTDIR), file=sys.stderr)
    if _already:
        print("ALREADY PRESENT (not a failure -- the same entries rebuilt): %d family(ies)" % len(_already), file=sys.stderr)
    print("CANNOT ABSORB (loud, see ALL.excluded.txt): %d" % len(_cannot), file=sys.stderr)
    excluded = _cannot + _already   # file keeps both, cannot-absorb first so the real problems read first
    for fam, why in excluded:
        print("  ⛔ %s: %s" % (fam, why), file=sys.stderr)
    print("attribute columns: %d" % (6 + len(COLS)), file=sys.stderr)
    # -- BYTE-EQUAL-OR-NO-DELETE verification and the selector refusal already ran, BEFORE the write above
    # (requirement 3, extended) -- `verified`/`unverified`/`to_delete`/`selector_label` are in scope from there.
    if selector_label is not None:
        print("VERIFIED for deletion: %d families; UNVERIFIED (kept): %d; SELECTED by %s: %d (of the %d verified -- the rest stay, verified but out of scope this run)"
              % (len(verified), len(unverified), selector_label, len(to_delete), len(verified)), file=sys.stderr)
    else:
        print("VERIFIED for deletion: %d families; UNVERIFIED (kept): %d" % (len(verified), len(unverified)), file=sys.stderr)
    if delete_absorbed:
        n = 0
        touched_dirs = set()
        for fam, sno, ref in to_delete:
            os.remove(sno)
            os.remove(ref)
            for sc in (sno[:-len(EXT)] + ".in", sno[:-len(EXT)] + ".xfail"):
                if os.path.isfile(sc):
                    os.remove(sc)
                    n += 1
            touched_dirs.add(os.path.dirname(sno))
            n += 2
        for d in sorted(touched_dirs):
            if os.path.abspath(d) == os.path.abspath(OUTDIR):
                continue
            if not any(f.endswith(EXT) for f in os.listdir(d)):
                for cf in sorted(os.listdir(d)):
                    if os.path.splitext(cf)[1] in COMPANION_EXTS or cf.endswith(".ref"):
                        os.remove(os.path.join(d, cf))
                        n += 1
        for dirpath, dirnames, filenames in list(os.walk(ROOT, topdown=False)):
            if not dirnames and not filenames and os.path.abspath(dirpath) != os.path.abspath(ROOT):
                os.rmdir(dirpath)
        print("DELETED %d absorbed source files (verified families only; fully-absorbed dirs' companions included); empty dirs pruned" % n, file=sys.stderr)
    elif verified:
        # ⛔ THE PHRASE "dry run" IS RESERVED FOR A RUN THAT WROTE NOTHING, and this run wrote the rungs.
        # Naming the files is not politeness: it is the difference between a seat that knows its tree is dirty
        # and one that goes on reading line numbers from a file that moved underneath it.
        print("⛔ NOT A DRY RUN -- the rungs was REWRITTEN by this run. Nothing was DELETED: pass "
              "--delete-absorbed to remove the %d verified families' loose source pairs." % len(verified),
              file=sys.stderr)
    # ⭐ THE LAST WORD NAMES WHAT IS NOW ON DISK, unconditionally, because the last word is the one that is
    # read. Every path here was recorded at its own os.replace above, so this line cannot claim a write that
    # did not happen or miss one that did -- it is not a second opinion about the write, it is the write's
    # own receipt.
    print("WROTE %d file(s) under %s (%d entries): %s"
          % (len(_committed), OUTDIR, len(all_entries),
             ", ".join(os.path.basename(f) for f in _committed)), file=sys.stderr)


if __name__ == "__main__":
    main()
