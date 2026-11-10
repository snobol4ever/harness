#!/usr/bin/env python3
"""util_build_package_suite.py -- ONE CONTAINER PER VENDORED PACKAGE (task
every-vendored-package-absorbed-into-the-one-liner-or-multi-liner-python-harness-with-oracle-cut-refs,
hq_T doorbell 2026-09-04, Lon verbatim: "You make the programs run, you measure the output, make a REF
file, and place it into a ONE-LINER or a MULTI-LINER Python test harness.").

For corpus/packages/<lang>/<pkg>/, builds an ADDITIVE container beside the shipped files -- nothing in
the package is moved or rewritten: ALL.<ext> / ALL.ref / ALL.csv, plus ALL.in (only if some entry needs
stdin) and ALL.rc (only if some entry's correct exit code is non-zero). A shipped program not
absorbed is named, with a reason, in ALL.omit -- absorbed + excluded always equals the shipped
count (self-checked below; a mismatch REFUSES rather than silently shrinking the denominator).

REFS ARE CUT FROM THE PACKAGE'S OWN ORACLE, NEVER FROM SCRIP (hq_T's doorbell, verbatim) -- via
lib_oracle_flags.sh's resolve_oracle_bin()/run_oracle(), corpus_suite_harness's OWN authority, same as
every other oracle call in this project. This is deliberately NOT cmd_capture_oracle_refs's three-way
(oracle+m3+m4) agreement gate: that gate is a conservative bootstrap for suites that only want to freeze
currently-GREEN witnesses, and withholding a ref whenever SCRIP disagrees would quietly erase exactly the
defects this container exists to surface. The oracle's own answer is the ref, full stop; SCRIP's
agreement or disagreement with it is what grading measures, not a precondition for measuring at all.

Six ways a shipped program is excluded rather than absorbed, each named by reason in ALL.omit:
  1. a `-INCLUDE "X"` naming a file vendored in none of the dirs searched: the package dir, the source's own dir, and
     for SNOBOL4 the grader's include dir (corpus/include, the SNO_LIB the harness grades under) -- a corpus completeness
     gap, not gradable here; the exclusion reason names the dirs it searched, never "anywhere")
  2. the oracle itself cannot produce ground truth: crashes (signal), hangs past the timeout, or dies
     gracefully (SPITBOL's own "ERROR nnn -- ... / in statement N" fatal-report shape, ported from
     test_snobol4_aisnobol_suite.sh's sbl_died(), already measured correct on this exact package)
  3. the oracle's output is empty -- an empty ref grades a file against nothing forever and reads as
     coverage where there is none (same refusal cmd_capture_oracle_refs makes, same reason)
  4. (SNOBOL4 sources only -- lang in {"", "snobol4"}) the source carries a UTF-8 BOM -- checked
     structurally, BEFORE the oracle ever runs (measured on the dotnet package's 5 BOM-prefixed files: a
     BOM at byte 0 confuses SPITBOL's label lexer, producing either a segfault -- which the crash check
     in reason 2 would also catch -- or a compile-time-only fatal that never executes the program. That
     second shape is NOT text-matchable from here: its only footer, "No END statement found in source
     file(s).", prints to STDERR only, and h.run_oracle()/ora_text is STDOUT ONLY by this project's own
     convention -- see has_bom()'s docstring for the two dead ends tried first)
  5. (SNOBOL4 sources only -- lang in {"", "snobol4"}) more than one top-level END statement -- a
     textbook chapter's worth of separate example programs concatenated into one shipped file, not a
     single valid program (measured on the dotnet package's chap7.sno: 2 top-level END lines). SCRIP
     correctly REFUSES a duplicate 'END' label ("no code generated"); the oracle instead silently keeps
     going past it and produces real-looking output from a partial run -- grading SCRIP against that
     would blame it for being the stricter, arguably more correct, of the two engines, the same
     false-disagreement class as reason 2.
  6. the source is not valid UTF-8 (genuine 8-bit content -- measured on csnobol4_suite's 8bit2.sno, an
     ISO-8859-1 French-language test using accented identifiers, byte 0xC9). read_text_tolerant() can
     decode it (falls back to latin-1, which never raises), but h.write_suite()'s Path.write_text() has no
     encoding param and re-encodes as UTF-8 -- a latin-1 chr(0xC9) round-trips out as bytes 0xC3 0x89, two
     bytes where the vendored source had one. SCRIP is byte-oriented, so the container's copy would stop
     being byte-identical to what the ref was cut from: the same false-disagreement shape as reasons 4/5,
     just discovered one level down in the write path rather than the read path. Fixing write_suite itself
     (shared machinery other suites already depend on) is out of this tool's lane; flagged to hq_T.
Stdin: `<stem>.stdin` / `<stem>.IN` / `<stem>.in` / `<stem>.input` beside the source, tried in that order
(vendored packages ship the exact case they shipped in -- aisnobol's are `.IN` -- so this checks case
variants explicitly rather than relying on with_suffix()'s case-sensitive match).

THE SPLICE, --only NAME[,NAME...] (the cqo 2026-11-04, row corpus-the-twenty-programs-...-r-2029; a whole rebuild of rosetta-pascal
re-cut every ref and moved 30 of the 311 its rows had graded, measured 18:2xZ): only the named programs are cut from the oracle, by the
same checks as a whole build (--twice included), and every other entry stays byte-identical. A named program already in the container is
re-cut IN PLACE, keeping its banner number, its rank and its declared heap_kb, stack_kb, compile_args, run_args and mode_gap_s; one not in
it is appended after the last entry. ALL.csv, ALL.dialect, ALL.rc, ALL.argv and ALL.mask change only on the named entries' lines;
ALL.omit drops a named program absorbed now and names one excluded now. THE GATE (refuse rc 2, nothing written): the container as
it stands must read back byte-identically through its reader (read_suite for SNOBOL4, read_block_suite else) and write_suite; a named program in the container that this cut
excludes refuses (removing an entry renumbers every banner after it); the spliced container is staged and every untouched entry must
read back with the same banner number, source, ref and stdin, and every untouched ALL.csv line must be the same line.
The partition (util_suite_partition.py build) and the package's own tables (UNGRADED.tsv, EXCLUDED.tsv) are the lander's, as after a build.

Grading is unchanged machinery: python3 ../harness/scripts/corpus_suite_harness.py run ALL.<ext> ALL.ref --modes m3,m4
Stdlib only except corpus_suite_harness/util_build_rungs_suite, imported for the ONE suite-grammar and
ONE attribute-table authorities respectively -- never a second parser or a second column set.
"""
import os
import re
import sys
import csv
import argparse
import io
import math
import time
import tempfile
from pathlib import Path

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import corpus_suite_harness as h  # noqa: E402
import util_build_rungs_suite as m  # noqa: E402
import util_xsb_wfs_entry_is_the_driver as wfs_entry  # noqa: E402

LANG_EXT = {"": ".sno", "snobol4": ".sno", "prolog": ".pl", "raku": ".raku",
            "snocone": ".sc", "rebus": ".reb", "icon": ".icn", "pascal": ".pas"}

# ⭐ PORTED FROM test_snobol4_aisnobol_suite.sh's sbl_died(), MEASURED CORRECT ON THIS EXACT PACKAGE
# (BUILDLIB.sno, 2026-09-03): SPITBOL's graceful-fatal shape is a banner line containing " : ERROR nnn --
# " together with a following "in statement N" footer -- rc alone is not a liveness signal (SPITBOL exits
# 0 after printing this), so the text shape is the only thing that catches it. ⚠ seat15 2026-09-04 tried
# widening this to also catch SPITBOL's OTHER fatal shape, "No END statement found in source file(s).":
# MEASURED WRONG -- that footer prints to STDERR only (`sbl Test2.sno 2>/dev/null` vs `2>/tmp/e`, dotnet
# package's Test2.sno/SourceLines001.sno), and h.run_oracle()/ora_text is STDOUT ONLY by design (the same
# convention test_snobol4_aisnobol_suite.sh's header documents: merging streams manufactures false
# disagreements). A text-pattern check can never see a line that never reaches the stream it reads --
# see has_bom() below for the structural check that actually catches this class.
_SBL_DIED_RE1 = re.compile(r" : ERROR \d\d\d -- ")
_SBL_DIED_RE2 = re.compile(r"^in statement +\d+$", re.MULTILINE)


def sbl_died(text):
    return bool(_SBL_DIED_RE1.search(text)) and bool(_SBL_DIED_RE2.search(text))


# ⭐ ADDED (seat15, 2026-09-04, measured on the dotnet package's 5 BOM-prefixed files -- Test.sno,
# Test2.sno, SourceLines001-003.sno): a U+FEFF byte-order-mark at byte 0 confuses SPITBOL's label lexer.
# Two failure shapes result, NEITHER caught by sbl_died() (both proven by direct oracle invocation):
# (a) segfault mid-report, rc=139 -- IS caught, but only by the separate crash check in build() below,
#     coincidentally, not by anything BOM-aware; (b) a compile-time-only bail: stdout carries just the
# " : ERROR 214 -- bad label or misplaced continuation line" line (matches sbl_died's RE1) with NO
# footer on stdout at all (its footer, "No END statement found in source file(s).", is stderr-only --
# see the comment above) -- so sbl_died() returns False and the lexer-confusion artifact on stdout would
# be absorbed as if it were the program's real ground truth. Checking the SOURCE BYTES directly, before
# ever invoking the oracle, is unambiguous and sidesteps the stdout/stderr question entirely.
_BOM = chr(0xFEFF)  # spelled by codepoint, not a literal byte, so the source stays reviewable in plain ASCII


def has_bom(src_text):
    return src_text.startswith(_BOM)


# a CONTROL LINE only: -INCLUDE starts in column 1, so a comment that quotes one (gimpel frsort_driver.sno line 4, "* Catspaw's
# frsort.inc says -INCLUDE \"stringout.inc\" ...") names no dependency (the coo 2026-10-03: that comment excluded frsort_driver from
# the container as a missing dependency while the board graded it green)
_INCLUDE_RE = re.compile(r"^-INCLUDE\s+['\"]([^'\"]+)['\"]", re.M)


def find_include_gap(src_text, pkg_dir, src_dir=None, grader_inc=None):
    """The first -INCLUDE target this source names that resolves in NONE of the dirs searched, and the dirs that
    were searched. -> (name_or_None, [dirs]).
    ⛔⭐ THE RECORDED REASON USED TO OVERCLAIM, AND THE OVERCLAIM IS THE DEFECT (hq_T 2026-09-05, measured on the
    exclusions this function itself wrote). It searched ONE directory and the caller wrote "not vendored anywhere in
    corpus" into ALL.omit -- a sentence nobody had measured. Of the 8 exclusions on record, 3 are false by
    that sentence's own claim: `-INCLUDE '../modules/ndbm/ndbm.sno'` and `'../modules/time/time.sno'` name files that
    ARE vendored, as packages/snobol4/csnobol4_suite/{ndbm,time}.sno -- the vendored layout flattened the module
    tree and the sources kept naming the original path. A reason is evidence a later reader acts on; one that states
    a wider search than was performed sends them to look for a file they already have.
    ⛔ AND IT READ ONLY THE FIRST -INCLUDE (`.search`, not `.findall`), so a source whose first include resolved and
    whose second did not was absorbed and graded WITHOUT the second -- the same silent missing-dependency class this
    tool exists to keep out of a package suite.
    ⭐ src_dir is the SOURCE FILE'S OWN directory, which is pkg_dir only when the package is flat: build() globs
    `*/*{ext}` too, so a nested source's companion sitting beside it was reported as a gap while being right there."""
    # ⭐ grader_inc is the grader's SNO_LIB dir (corpus/include): the harness puts it on every SNOBOL4 run's include path, so a
    # -INCLUDE that resolves there is a vendored dependency, not a gap. Measured 2026-11-08: the 17 math units name math_chks.inc
    # or chks.inc, which live only there; excluded as missing beside the entry, while sbl -bf answers 616 of 616 with them staged.
    dirs = list(dict.fromkeys([d for d in (src_dir, pkg_dir, grader_inc) if d is not None]))
    for inc in _INCLUDE_RE.findall(src_text):
        # ⛔⭐ THE STRIPPED FORM COUNTS AS VENDORED, AND THIS IS NOT LENIENCY (measured on csnobol4_suite/line.sno and
        # include.sno, which the findall widening above newly caught). Both name `-INCLUDE "line2.sno "` WITH A
        # TRAILING SPACE, beside `-INCLUDE "line2.sno"` without one -- they are csnobol4's own tests OF include-name
        # handling, and line2.sno is vendored right there. This function answers ONE question: is the dependency in
        # the corpus. Whether the compiler trims the name is the very thing those programs test, and their .ref
        # records whichever answer the oracle gives -- so excluding them would drop the two entries that grade the
        # behaviour, on the grounds that they grade it.
        if not any((d / inc).is_file() or (d / inc.strip()).is_file() for d in dirs):
            return inc, dirs
    return None, dirs


_END_LINE_RE = re.compile(r"^END(?:[ \t]|$)")


def count_top_level_ends(src_text):
    """Number of un-indented 'END' statement lines -- SNOBOL4's own program terminator. More than one
    means the shipped file is several example programs concatenated under one name, not a single valid
    program (measured on the dotnet package's chap7.sno: a textbook chapter, 2 top-level END lines).
    Mirrors test_snobol4_dotnet_suite.sh's own check (`grep -cE '^END([[:space:]]|$)'`)."""
    # ⛔ AN END WITH NO STATEMENT SINCE THE LAST END ENDS NO SECOND PROGRAM (the cio 2026-11-10, measured on spitbol_x32_tests hi.spt: one
    # OUTPUT statement, END, END; sbl -bf and SCRIP both print the one line and the deleted runner graded it PASS, yet the whole build
    # excluded it as a multi-program file and the suite's denominator fell by one). Text after END is never program text; a second
    # PROGRAM is statements followed by their own END, which is what chap7 holds.
    n = stmts = 0
    for line in src_text.splitlines():
        if _END_LINE_RE.match(line):
            if stmts or n == 0:
                n += 1
            stmts = 0
        elif line.strip() and not line.startswith("*"):
            stmts += 1
    return n


def read_text_tolerant(path):
    """UTF-8 first (so a real UTF-8 BOM still decodes to U+FEFF for has_bom() to see); falls back to
    latin-1 -- which never raises -- for genuinely non-UTF-8 8-bit source (measured on csnobol4_suite's
    8bit2.sno: ISO-8859-1 French text using accented identifiers like Etude/francais, byte 0xC9 -- a
    deliberate 8-bit-character test, not corruption), so the whole run no longer crashes on the first such
    file. Returns (text, used_latin1) -- the caller EXCLUDES rather than absorbs when used_latin1 is True:
    measured (see enctest, this session) that h.write_suite's Path.write_text() re-encodes as UTF-8 with no
    encoding param exposed, so a latin-1 codepoint like chr(0xC9) round-trips out as the TWO bytes 0xC3 0x89
    -- the container's copy would silently stop being byte-identical to the vendored source the ref was cut
    from, the exact false-disagreement class BOM/multi-END are already excluded for. Fixing write_suite
    itself is out of this tool's lane -- it is shared machinery other suites already depend on."""
    raw = path.read_bytes()
    try:
        return raw.decode("utf-8"), False
    except UnicodeDecodeError:
        return raw.decode("latin-1"), True


def stdin_for(stem, pkg_dir):
    # ⭐ `.dat` ADDED (measured on arizona_tests' README.md: "16 with a matching .dat (fed as stdin..."
    # -- a DIFFERENT convention from jcon_tests' same-named extension, which feeds it as BOTH argv[1]
    # AND stdin (JCON's own addtest harness; this builder has no argv mechanism, see the .dat-companion
    # exclusion reason in build() below). Tried last, after every stdin-specific extension, so a package
    # that ships BOTH a real `.stdin` file and an unrelated `.dat` data companion still prefers the
    # explicit one. Safe for jcon_tests' own .dat-as-argv entries too, not just neutral: feeding the same
    # content as stdin can only help (a program that reads it via stdin as well as/instead of argv[1] now
    # gets real input, matching JCON's own "both at once" convention) or leave them exactly as excluded
    # as before (still empty if the program truly needs argv[1] specifically).
    # ⛔⭐ CORRECTION (seat14, same sitting): the ORIGINAL version of this comment claimed "verified
    # empirically... zero change to every absorbed entry... none of jcon's programs read their .dat via
    # stdin at all" -- THAT WAS WRONG, and it shipped in a pushed commit before the mistake was caught.
    # The "verification" piped the rebuild through `grep -E "argv|balanced|..."`, which printed nothing
    # because the build had actually REFUSED early (a stale-binary preflight, unrelated to this change)
    # -- silence from the filter was misread as "nothing changed" rather than "the command never ran the
    # part being checked." Same class of mistake as the tail-3-hides-a-refusal incident minutes earlier
    # in this same sitting (RULES.md's own INSTRUMENT LAWS: an instrument that cannot fail). Re-run with
    # full, unfiltered output once caught: jcon_tests actually goes 60 -> 70 absorbed with this change,
    # not 60 -> 60. Verified for real this time (full output inspected, no grep/tail between the command
    # and the read): 17 of jcon's .dat-stem entries end up stdin-fed and correct (spot-checked `btrees`
    # against its shipped .std under both the argv+stdin invocation JCON's own addtest convention uses
    # AND stdin-only -- identical, byte-for-byte, confirming the program reads via stdin regardless of
    # argv). Only 4 (geddump/htprep/prepro/tgrlink) still come back empty and stay excluded as
    # genuinely argv[1]-dependent. See the corrected corpus commit for the real numbers.
    for ext in ("stdin", "IN", "in", "input", "Input", "dat"):
        cand = pkg_dir / f"{stem}.{ext}"
        if cand.is_file():
            return cand
    return None


def icn_marked(text):
    """True when an Icon source carries a Unicon marker the way icon_lex.c icn_source_is_unicon reads it: a declaration-level class, package or import header, or the
    word thread, critical or abstract (comments and string literals set aside). The ALL.csv compile_args of a UNMARKED entry then carries the contract's dialect switch."""
    code = re.sub(r'#[^\n]*', '', re.sub(r'"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'', '""', text))
    return bool(re.search(r'\b(?:thread|critical|abstract)\b', code) or re.search(r'(?m)^[ \t]*(?:class|import)[ \t]+\w', code) or re.search(r'(?m)^[ \t]*package[ \t]+[\w"]', code))


def _unicon_prebuild(iso, ipath, names):
    import subprocess
    r = subprocess.run(["bash", "-c", f". '{h.HARNESS_SCRIPTS / 'lib_oracle_flags.sh'}' && unicon_bin"], capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip(): h.refuse(f"lib_oracle_flags.sh refused (unicon_bin): {r.stderr.strip()}")
    for name in names:
        for f in sorted(p for d in ipath.split(os.pathsep) for p in Path(d).glob("*.icn")):
            if re.search(rf"(?m)^package[ \t]+{re.escape(name)}[ \t]*$", f.read_text(errors="replace")):
                (iso / f.name).write_bytes(f.read_bytes())
                subprocess.run([r.stdout.strip(), "-c", "-s", f.name], cwd=str(iso), capture_output=True, timeout=300)


def read_contract(pkg_dir):
    """The package's own run contract, CONTRACT.tsv beside its sources: key<TAB>value<TAB>evidence, '#' comments. What the
    package's OWN harness does to produce its refs, declared once with the package and read here, never typed by a runner.
    Admitted today: `stderr<TAB>merged` -- the package cut its refs as `prog < in > out 2>&1`, so the oracle's ref is stdout and
    stderr as one stream and every absorbed entry's ALL.csv stderr cell reads "merged" (corpus_suite_harness.py grades m3 and
    m4 the same way). And `units<TAB>ref-beside` -- the package's own harness grades a source only when a <stem>.ref sits beside
    it (the Icon packages' boards), so a source without one (a library graded through its driver, a spliced include) is no unit
    here either. Absent file = stdout alone and every source a unit, as every package before the file existed. Any other key or
    value refuses. ⭐ XSB's own contract (R-1927, 2026-10-23; RULES.md § Oracles, FACT RULE XSB IS THE THIRD PROLOG ORACLE, FOR THE XSB
    PACKAGE): `oracle<TAB>xsb-gentest` -- each ref is cut from XSB 5.0.0 (xsb_bin) as XSB's own test scripts run the program, the run each
    entry's row of ORACLE_RUNS.tsv records, in a copy of `upstream<TAB><dir>` (the upstream test tree, an absolute path), its answer the
    sorted temp file, checked against the upstream NAME_old (ALL.xsbold names each check); and `compare<TAB>ignore-all-space` -- the package's
    harness compares with diff -w, so every absorbed entry's ALL.csv compare cell reads ignore-all-space. And `oracle<TAB>unicon` (R-2072, hq_unicon): an Icon
    package whose refs are cut from the Unicon translator through unicon_bin() (the UniTests package), compiled by the translator with -s and -o and run as ./stem.
    ⭐ CIO-22 C (the coo 2026-11-10, on the cio's design): `fatal<TAB>gradable` -- a SPITBOL graceful fatal (sbl_died) is the program's answer and is
    absorbed with its fatal block as the ref and SPITBOL's exit code as want_rc (CEO-1344: a SPITBOL fatal is gradable; the package's ALL.mask carries the
    block's engine lines); and `bom<TAB>as-shipped` -- a source that carries a UTF-8 BOM is run on the oracle as shipped and absorbed with what it answers,
    graded by the harness's compile-refusal arm (harness 1764ac3c), instead of excluded before any run. Each key lifts exactly its one exclusion; an oracle
    crash, a hang, an empty answer or a two-run difference excludes as before.
    ⭐ CIO-22 D (the coo 2026-11-10, on the cio's design; CIO-15 d revised): `units<TAB>generated` with `generator<TAB><module>` -- a per-goal
    suite (INRIA's goals, Logtalk's cases) is a container of GENERATED programs: the module (harness/scripts/<module>.py) yields each case of the
    package's own table and the builder runs no oracle (see build_generated)."""
    out = {"stdin": "", "stderr": "", "units": "", "dialect": "", "oracle": "", "upstream": "", "compare": "", "unmarked_compile_args": "", "ipath": "", "not_shipped": "", "prebuild": "", "fatal": "", "bom": "", "generator": ""}
    cf = pkg_dir / "CONTRACT.tsv"
    if not cf.is_file():
        return out
    for n, line in enumerate(cf.read_text().splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        f = line.split("\t")
        if len(f) < 3 or not f[2].strip():
            h.refuse(f"{cf}:{n}: a contract row is key<TAB>value<TAB>evidence, and the evidence is not optional")
        if f[0] == "stderr" and f[1] == "merged":
            out["stderr"] = "merged"
        elif f[0] == "units" and f[1] == "ref-beside":
            out["units"] = "ref-beside"
        elif f[0] == "units" and f[1] == "plunit":
            out["units"] = "plunit"
        elif f[0] == "units" and f[1] == "iso-rejection":
            out["units"] = "iso-rejection"
        elif f[0] == "units" and f[1] == "generated":
            out["units"] = "generated"
        elif f[0] == "generator":
            out["generator"] = f[1].strip()
        elif f[0] == "dialect" and f[1] == "any-fpc-mode":
            out["dialect"] = "any-fpc-mode"
        elif f[0] == "oracle" and f[1] == "xsb-gentest":
            out["oracle"] = "xsb-gentest"
        elif f[0] == "fatal" and f[1] == "gradable":
            out["fatal"] = "gradable"
        elif f[0] == "bom" and f[1] == "as-shipped":
            out["bom"] = "as-shipped"
        elif f[0] == "oracle" and f[1] == "unicon":
            out["oracle"] = "unicon"
        elif f[0] == "upstream" and f[1].startswith("/"):
            out["upstream"] = f[1]
        elif f[0] == "compare" and f[1] == "ignore-all-space":
            out["compare"] = "ignore-all-space"
        elif f[0] == "ipath":
            if not (pkg_dir / f[1]).is_dir(): h.refuse(f"{cf}:{n}: ipath {f[1]!r} names no directory beside the package (the run cannot find its imports)")
            out["ipath"] = os.pathsep.join(x for x in (out["ipath"], str((pkg_dir / f[1]).resolve())) if x)
        elif f[0] == "prebuild":
            out["prebuild"] = f[1].strip()
        elif f[0] == "not_shipped":
            for x in f[1].split():
                if not (pkg_dir / x).is_dir():
                    h.refuse(f"{cf}:{n}: not_shipped {x!r} names no directory beside the package")
            out["not_shipped"] = f[1].strip()
        elif f[0] == "unmarked_compile_args" and f[1].startswith("--dialect="):
            out["unmarked_compile_args"] = f[1].strip()
        elif f[0] == "stdin":
            if not (pkg_dir / f[1]).is_file(): h.refuse(f"{cf}:{n}: stdin {f[1]!r} names no file beside the package (every entry with no stem-named stdin of its own would read it)")
            out["stdin"] = f[1].strip()
        else:
            h.refuse(f"{cf}:{n}: contract {f[0]!r}={f[1]!r} -- this builder admits stderr=merged, stdin=FILE, units=ref-beside,units=plunit, units=iso-rejection, dialect=any-fpc-mode, fatal=gradable, bom=as-shipped, units=generated, generator=MODULE, "
                     f"oracle=xsb-gentest, oracle=unicon, upstream=<absolute dir>, compare=ignore-all-space and unmarked_compile_args=--dialect=NAME only")
    if (out["units"] == "generated") != bool(out["generator"]):
        h.refuse(f"{cf}: units=generated and generator=<module> go together (got units={out['units']!r}, generator={out['generator']!r})")
    if out["oracle"] == "xsb-gentest" and not (out["upstream"] and Path(out["upstream"]).is_dir()):
        h.refuse(f"{cf}: oracle=xsb-gentest needs upstream=<the upstream test tree> naming a directory (got {out['upstream']!r})")
    return out


def _tsv_rows(path):
    """The tab-separated rows of a package table (CONTRACT-style: '#' comments and blank lines are not rows)."""
    if not path.is_file():
        return []
    return [ln.split("\t") for ln in path.read_text().splitlines() if ln.strip() and not ln.startswith("#")]


def iso_rejection_want(src):
    """What an ISO rejection test's refusal must name (CIO-16, officer_04 2026-11-09), read as the deleted test_pascal_pat_suite.sh prt_want read
    it: "line N1 N2 ..." -- the marked lines of the .ecp beside the source (the first field of each line that opens with a number then ****),
    sorted and unique; else "clause X1 X2 ..." -- every clause number after "ISO 7185 reference:" on the source's lines, in order; else "" (nothing a
    refusal can be checked against). A missing .ecp counts as no marked lines."""
    src = Path(src)
    ecp = src.with_suffix(".ecp")
    marked = []
    if ecp.is_file():
        for ln in read_text_tolerant(ecp)[0].splitlines():
            m = re.match(r"^[ \t]*([0-9]+)[ \t]+\*\*\*\*", ln)
            if m:
                marked.append(int(m.group(1)))
    if marked:
        return "line " + " ".join(str(n) for n in sorted(set(marked)))
    clauses = []
    for ln in read_text_tolerant(src)[0].splitlines():
        if "ISO 7185 reference:" in ln:
            clauses += re.findall(r"[0-9]+(?:\.[0-9]+)+", ln.rsplit("ISO 7185 reference:", 1)[1])
    if clauses:
        return "clause " + " ".join(clauses)
    return ""


def read_staged(pkg_dir):
    """STAGED.tsv (R-1927): name<TAB>stage<TAB>answer<TAB>evidence -- an entry whose SCRIP run needs its upstream test directory staged
    (stage=upstream: it loads a sibling by its upstream name) and whose answer is stdout or the file temp it writes (answer=stdout|temp-sorted, as
    wfs_tests' own harness grades it). Absent file: none. A malformed row refuses."""
    sf = pkg_dir / "STAGED.tsv"
    out = {}
    for n, line in enumerate(sf.read_text().splitlines() if sf.is_file() else [], 1):
        if not line.strip() or line.startswith("#"):
            continue
        f = line.split("\t")
        if len(f) < 4 or f[1] != "upstream" or f[2] not in ("stdout", "temp-sorted") or not f[3].strip():
            h.refuse(f"{sf}:{n}: a staged row is name, upstream, stdout|temp-sorted, evidence -- got {line[:120]!r}")
        out[f[0][:-3] if f[0].endswith(".pl") else f[0]] = f[2]
    return out


def read_oracle_runs(pkg_dir):
    """ORACLE_RUNS.tsv: one row per program XSB's own test scripts run, as util_xsb_oracle_runs.py recorded it from them --
    name<TAB>dir<TAB>kind<TAB>file<TAB>cmd<TAB>emu_args<TAB>script. A name twice, a kind other than gentest/wfs, or a short row refuses."""
    rf = pkg_dir / "ORACLE_RUNS.tsv"
    if not rf.is_file():
        h.refuse(f"{rf} missing -- oracle=xsb-gentest cuts each ref from the run XSB's own scripts make, and this file records them")
    runs = {}
    for n, line in enumerate(rf.read_text().splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        f = line.split("\t")
        if len(f) != 7 or f[2] not in ("gentest", "wfs") or not f[0] or not f[3]:
            h.refuse(f"{rf}:{n}: a run row is name, dir, kind (gentest|wfs), file, cmd, emu_args, script -- got {line[:120]!r}")
        if f[0] in runs:
            h.refuse(f"{rf}:{n}: {f[0]} has two runs -- one program, one recorded run")
        runs[f[0]] = dict(name=f[0], dir=f[1], kind=f[2], file=f[3], cmd=f[4], emu_args=f[5], script=f[6])
    return runs


def _load_generator(name):
    """The generator module a units=generated contract names: harness/scripts/<name>.py (one subdirectory allowed, for a gate's fixture),
    exposing cases(pkg_dir)."""
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*(/[A-Za-z_][A-Za-z0-9_]*)?", name or ""):
        h.refuse(f"generator {name!r} is not a module name under harness/scripts (letters, digits, _ and one /)")
    gp = Path(HERE) / f"{name}.py"
    if not gp.is_file():
        h.refuse(f"generator {name!r}: no {gp}")
    import importlib.util
    spec = importlib.util.spec_from_file_location("s4e_generator_" + name.replace("/", "_"), gp)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    if not callable(getattr(mod, "cases", None)):
        h.refuse(f"generator {gp} has no cases(pkg_dir)")
    return mod


def build_generated(pkg_dir, lang, out_prefix, contract, only):
    """⭐ A PER-GOAL SUITE IS A CONTAINER OF GENERATED PROGRAMS GRADED AS TEXT (CIO-22 D, the coo 2026-11-10 on the cio's design; CIO-15 d revised:
    no per-suite grader arm). The package's own table ALL.csv is the denominator (CIO-19): the generator named by CONTRACT generator=<module>
    yields, for every entry of that table and no other, one dict -- name (exactly the ALL.csv entry), program (the text a conforming run
    executes), ref (the suite's own expectation, the standard's, ONE line), cwd (the directory it runs from, relative to the package; "." the
    package; absent or empty: the grader's own scratch directory, where an oracle-cut entry runs, so a case that writes a file never writes
    beside the package) and, optionally, want_rc -- or, when it cannot plan the case, name and reason. NO ORACLE RUNS: the ref is the suite's, cut from no
    run. A case EXCLUDED_CASES.tsv, EXCLUDED.tsv or UNGRADABLE.tsv names, or one with a reason, is excluded by name; absorbed plus excluded equals
    the table. ALL.csv keeps every column and row it has and gains compare (verdict-line: corpus_suite_harness.py grades the first stdout line
    that begins with the ref's first word against the ref) and cwd for each absorbed entry; an excluded entry's two cells are blank."""
    if only is not None:
        h.refuse("--only splices oracle-cut entries into a container; a units=generated build runs no oracle and is rebuilt whole")
    ext = LANG_EXT[lang]
    gen = _load_generator(contract["generator"])
    out_csv = pkg_dir / f"{out_prefix}.csv"
    if not out_csv.is_file():
        h.refuse(f"{out_csv}: units=generated grades the package's own table (CIO-19: the package table is the denominator), and there is none")
    with open(out_csv, newline="", encoding="utf-8") as f:
        _rdr = csv.DictReader(f)
        header = list(_rdr.fieldnames or [])
        rows = list(_rdr)
    if "entry" not in header or not rows:
        h.refuse(f"{out_csv}: no entry column or no rows")
    table = [(r.get("entry") or "").strip() for r in rows]
    _dup = sorted({n for n in table if table.count(n) > 1})
    if "" in table or _dup:
        h.refuse(f"{out_csv}: an entry is blank or named twice ({', '.join(_dup[:5]) or 'blank'}) -- one row, one case")
    declared = {}
    for _tn in ("EXCLUDED_CASES.tsv", "EXCLUDED.tsv", "UNGRADABLE.tsv"):
        for _r in _tsv_rows(pkg_dir / _tn):
            _n = _r[0].strip() if _r else ""
            if _n:
                _n = _n[:-len(ext)] if _n.endswith(ext) else _n
                declared.setdefault(_n, f"{_tn} {(_r[1].strip() if len(_r) > 1 else '')}: {(_r[2].strip() if len(_r) > 2 else '')}")
    by = {}
    for c in gen.cases(pkg_dir):
        _n = c.get("name") if isinstance(c, dict) else None
        if not isinstance(_n, str) or not _n:
            h.refuse(f"generator {contract['generator']}: a case is not a dict with a name ({c!r:.120})")
        if _n in by:
            h.refuse(f"generator {contract['generator']}: case {_n!r} yielded twice")
        by[_n] = c
    _missing = [n for n in table if n not in by]
    _extra = sorted(set(by) - set(table))
    if _missing or _extra:
        h.refuse(f"generator {contract['generator']} and {out_csv.name} disagree: {len(_missing)} table entries it does not yield "
                 f"({', '.join(_missing[:5])}) and {len(_extra)} cases the table lacks ({', '.join(_extra[:5])}) -- the table is the denominator")
    print(f"contract: units generated (CONTRACT.tsv) -- generator {contract['generator']}, {len(by)} cases, no oracle run; "
          f"{len(declared)} names declared out by EXCLUDED_CASES.tsv, EXCLUDED.tsv and UNGRADABLE.tsv", file=sys.stderr)
    entries, excluded, cwd_of = [], [], {}
    for n in table:
        c = by[n]
        if n in declared:
            excluded.append((n, declared[n]))
            continue
        if c.get("reason"):
            excluded.append((n, f"the generator cannot plan it: {c['reason']}"))
            continue
        prog, ref, cwd = c.get("program"), c.get("ref"), (c.get("cwd") or "")
        if not isinstance(prog, str) or not prog.strip():
            h.refuse(f"generator case {n!r}: no program text and no reason")
        if not isinstance(ref, str) or not ref.strip() or "\n" in ref.strip("\n"):
            h.refuse(f"generator case {n!r}: the ref must be ONE non-empty line (the verdict line), got {ref!r:.120}")
        if cwd and (cwd.startswith("/") or ".." in cwd.split("/") or not (pkg_dir / cwd).is_dir()):
            h.refuse(f"generator case {n!r}: cwd {cwd!r} is not a directory beside the package (relative, no ..)")
        entries.append(h.Entry("block", len(entries) + 1, n, prog.splitlines(), [ref.strip("\n")], stdin=None, want_rc=int(c.get("want_rc") or 0)))
        cwd_of[n] = cwd
    if len(entries) + len(excluded) != len(table):
        h.refuse(f"population arithmetic broken: {len(entries)} absorbed + {len(excluded)} excluded != {len(table)} in the table")
    out_excl = pkg_dir / f"{out_prefix}.omit"
    if excluded:
        out_excl.write_text("\n".join(f"{n}: {r}" for n, r in sorted(excluded)) + "\n")
    elif out_excl.exists():
        out_excl.unlink()
    if not entries:
        h.refuse(f"{pkg_dir}: zero absorbable cases of {len(table)} -- a container that grades nothing is not a container ({out_excl.name} names them)")
    out_sno, out_ref, out_in, out_wantrc = (pkg_dir / f"{out_prefix}{x}" for x in (ext, ".ref", ".in", ".rc"))
    if not h.write_suite(entries, str(out_sno), str(out_ref), out_in=str(out_in), lang=lang) and out_in.exists():
        out_in.unlink()
    _wr = [f"{e.name}\t{e.want_rc}" for e in entries if e.want_rc]
    if _wr:
        out_wantrc.write_text("\n".join(_wr) + "\n")
    elif out_wantrc.exists():
        out_wantrc.unlink()
    _new = [c for c in ("compare", "cwd") if c not in header]
    _at = max([header.index(c) + 1 for c in ("timeout_s", "compile_args", "run_args", "out_files", "stderr") if c in header] or [len(header)])
    header = header[:_at] + _new + header[_at:]
    for r in rows:
        n = r["entry"].strip()
        if n in cwd_of:
            _t = [t for t in (r.get("compare") or "").split("+") if t and t != "verdict-line"]
            r["compare"], r["cwd"] = "+".join(_t + ["verdict-line"]), cwd_of[n]
        else:
            r["compare"], r["cwd"] = "", ""
    with open(out_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=header, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    print(f"{pkg_dir}: GENERATED {len(entries)} absorbed, {len(excluded)} excluded, {len(table)} in the table (balanced); "
          f"generator {contract['generator']}; no oracle run", file=sys.stderr)
    return 0


def build(pkg_dir, lang, out_prefix="ALL", twice=False, only=None, src_ext=None):
    _c0 = read_contract(pkg_dir)
    if _c0["units"] == "generated":
        return build_generated(pkg_dir, lang, out_prefix, _c0, only)
    ext = LANG_EXT[lang]
    paths = h.resolve_paths()
    h.check_scrip(paths)
    oracle_bin, flags = h.resolve_oracle_bin(paths, lang)
    print(f"oracle: {oracle_bin} {flags}", file=sys.stderr)
    contract = read_contract(pkg_dir)
    merged = contract["stderr"] == "merged"
    # ⛔⭐ THE TABLE'S ATTRIBUTE COLUMNS ARE THE ONE SPEC, READ BY THE BUILDER AS BY THE GRADER (Lon 2026-11-08 23:0x, verbatim: "Same spec on
    # attributes and environment."; the cio 2026-11-10). MEASURED on spitbol_x32_tests: its ALL.csv declared out_files=extract1.txt extract2.txt
    # and stderr=merged for arcget and timeout_s=300 for all 21; a whole build read none of the three, ran the oracle without them, excluded
    # arcget as EMPTY output (its answer is the two files and its TERMINAL lines) and wrote a table without the three columns. Nine tables
    # rebuilt on 2026-11-09 lost timeout_s the same way. So an entry's out_files (when no <stem>.outfiles sidecar speaks), stderr and timeout_s
    # in the table as it stands are read here, before any oracle run, used for the cut, and written back.
    _decl = {}
    _decl_cols = []
    if (pkg_dir / f"{out_prefix}.csv").is_file():
        with open(pkg_dir / f"{out_prefix}.csv", newline="") as _f:
            _rdr = csv.DictReader(_f)
            _decl_cols = [c for c in ("out_files", "stderr", "timeout_s") if c in (_rdr.fieldnames or [])]
            for _row in _rdr:
                _decl[_row.get("entry")] = {c: (_row.get(c) or "").strip() for c in _decl_cols}
    if merged:
        print("contract: stderr merged (CONTRACT.tsv) -- every ref is cut from stdout and stderr as one stream", file=sys.stderr)
    if contract["fatal"] == "gradable":
        print("contract: fatal gradable (CONTRACT.tsv) -- a SPITBOL graceful fatal is absorbed with its fatal block as the ref (CEO-1344)", file=sys.stderr)
    if contract["bom"] == "as-shipped":
        print("contract: bom as-shipped (CONTRACT.tsv) -- a source with a UTF-8 BOM runs on the oracle as shipped and is graded by what it answers", file=sys.stderr)
    ref_beside = contract["units"] == "ref-beside"
    plunit = contract["units"] == "plunit"
    iso_rej = contract["units"] == "iso-rejection"
    if lang == "icon" and contract["ipath"] and contract["oracle"] != "unicon":
        os.environ["IPATH"] = os.pathsep.join(x for x in (contract["ipath"], os.environ.get("IPATH", "")) if x)
    xsb = contract["oracle"] == "xsb-gentest"
    xsb_bin, xsb_runs, xsb_owed, xsbold = None, {}, set(), []
    staged = read_staged(pkg_dir)
    pkg_excl = {}
    for _r in _tsv_rows(pkg_dir / "EXCLUDED.tsv"):
        if len(_r) >= 2:
            _nm = _r[0].strip()
            _sx = src_ext or ext
            pkg_excl[_nm[:-len(_sx)] if _nm.endswith(_sx) else _nm] = (_r[1].strip(), _r[2].strip() if len(_r) >= 3 else "")
    xsb_excl = {}
    if xsb and (pkg_dir / "EXCLUDED.tsv").is_file():
        # ⭐ A MEASURED EXCLUSION HOLDS ACROSS BUILDS (the coo 2026-10-23): basic_tests/preproc-opt/preproc_test writes XSB's own load messages into its
        # answer, some carrying the cpu time ("[xsbbrat loaded, cpu time used: 0.001 seconds]"), so two runs agree on one build and differ on the next
        # -- a two-run check cannot hold it. A program EXCLUDED.tsv names (its measurement recorded) is not absorbed; the row is the declaration.
        xsb_excl = {_k: _v[0] for _k, _v in pkg_excl.items()}
    if xsb:
        xsb_bin = h.xsb_oracle_bin()
        xsb_runs = read_oracle_runs(pkg_dir)
        _ug = pkg_dir / "UNGRADED.tsv"
        for _ln in (_ug.read_text().splitlines() if _ug.is_file() else []):
            _f = _ln.split("\t")
            if len(_f) >= 2 and not _ln.startswith("#") and _f[1] == "NEEDS_RUNNER_WIRING":
                xsb_owed.add(_f[0][:-len(ext)] if _f[0].endswith(ext) else _f[0])
        print(f"contract: oracle xsb-gentest (CONTRACT.tsv) -- {xsb_bin}, each ref as XSB's own test scripts run the program "
              f"({len(xsb_runs)} runs in ORACLE_RUNS.tsv), in a copy of {contract['upstream']}; {len(xsb_owed)} UNGRADED NEEDS_RUNNER_WIRING held", file=sys.stderr)
    uni_excl = pkg_excl if contract["oracle"] == "unicon" else {}
    if contract["oracle"] == "unicon" and (pkg_dir / "EXCLUDED.tsv").is_file():
        print(f"contract: oracle unicon (CONTRACT.tsv) -- {len(uni_excl)} programs held out by EXCLUDED.tsv with their class and reason", file=sys.stderr)
    if ref_beside:
        print("contract: units ref-beside (CONTRACT.tsv) -- a source is a unit only with its <stem>.ref beside it", file=sys.stderr)
    if plunit:
        print("contract: units plunit (CONTRACT.tsv) -- every .pl under the package; a file with begin_tests and a <stem>.ref beside it is one entry "
              "(the entry text is the test file alone, CIO-21: the harness supplies the shim and the run_tests wrapper at run time; the ref read verbatim)", file=sys.stderr)
    # ⭐ ONE LEVEL OF SUBDIRS, MATCHING THE TASK'S OWN DONE-WHEN EXACTLY (`find "$d" -maxdepth 2 ...`,
    # seat15 2026-09-04, measured on corpus/packages/prolog/gnu_prolog: all 62 shipped .pl files sit one
    # level down, in BipsPl/ and Pl2Wam/, zero directly in gnu_prolog/ itself -- a bare `pkg_dir.glob`
    # found nothing and would have REFUSED a real, non-empty package). Matching DONE-WHEN's own depth is
    # what keeps "shipped" meaning the same count in both places; going deeper (rglob) would not (checked:
    # gnu_prolog has no depth-3 files, so this and unrestricted recursion agree here, but won't in general).
    # ⭐ THE SOURCES' EXTENSION MAY DIFFER FROM THE CONTAINER'S (measured 2026-11-08): SPITBOL's own test suite ships 36 .sbl programs,
    # and the container it grades is ALL.sno, the harness's SNOBOL4 extension. src_ext names what the package ships; ext names the container.
    src_ext = src_ext or ext
    def _name_of(s):
        if plunit:
            return s.relative_to(pkg_dir).with_suffix("").as_posix()
        return f"{s.parent.name}/{s.stem}" if s.parent != pkg_dir else s.stem
    if plunit:
        _ctn = pkg_dir / "CONTAINERS.tsv"
        _cont = {_ln.split("\t")[0] for _ln in (_ctn.read_text().splitlines() if _ctn.is_file() else []) if _ln.strip() and not _ln.startswith("#")}
        srcs = sorted(p for p in pkg_dir.rglob(f"*{src_ext}")
                      if not p.stem.startswith(out_prefix) and p.relative_to(pkg_dir).as_posix() not in _cont
                      and not any(str(p.relative_to(pkg_dir)).startswith(d + "/") for d in contract["not_shipped"].split()))
    else:
        srcs = sorted(p for p in list(pkg_dir.glob(f"*{src_ext}")) + list(pkg_dir.glob(f"*/*{src_ext}"))
                      if not p.stem.startswith(out_prefix) and not any(str(p.relative_to(pkg_dir)).startswith(d + "/") for d in contract["not_shipped"].split()))
    if not srcs:
        h.refuse(f"no {src_ext} files under {pkg_dir} (direct or one level down)")
    all_srcs = srcs
    if only is not None:
        _by_name = {(f"{s.parent.name}/{s.stem}" if s.parent != pkg_dir else s.stem): s for s in srcs}
        _unknown = sorted(set(only) - set(_by_name))
        if _unknown:
            h.refuse(f"--only names {len(_unknown)} program(s) {pkg_dir.name} does not ship: {', '.join(_unknown)}")
        srcs = [_by_name[n] for n in sorted(set(only))]
        print(f"splice: cutting only {len(srcs)} named program(s) of {len(all_srcs)} shipped; every other entry stays byte-identical", file=sys.stderr)
    entries, excluded, dialects = [], [], []
    iso_rej_names, iso_acc, iso_excl = [], set(), {}
    # ⭐ A PACKAGE'S OWN EXPECTED REFUSALS (officer_05, 2026-11-09, on pascal-fpc-container-in-the-one-layout): fpc_tests ships its
    # ISO_EXPECTED_REFUSALS.tsv (R-1225, R-1228: graded as an expected refusal, its fpc-cut ref never compared) outside units iso-rejection.
    # Such a program is absorbed with an EMPTY ref before any oracle run, as a PAT rejection is, and the table is read, never rewritten; the
    # harness refuses a container that misses one (14 missed in junior_10's build: fpc -Miso printed nothing, so the empty-output rule took them).
    pkg_refusals = set() if iso_rej else {_r[0].strip().removesuffix(".pas") for _r in _tsv_rows(pkg_dir / "ISO_EXPECTED_REFUSALS.tsv")}
    if iso_rej:
        print("contract: units iso-rejection (CONTRACT.tsv) -- an iso7185prt* program with a .ecp beside it is absorbed with an EMPTY ref and its "
              "refusal's expected naming (ISO_EXPECTED_REFUSALS.tsv), never sent to fpc (CIO-16)", file=sys.stderr)
        for _r in _tsv_rows(pkg_dir / "ISO_ACCEPTS.tsv"):
            iso_acc.add(_r[0].strip().removesuffix(".pas"))
        iso_excl = pkg_excl
    # ⭐ THE ENTRY'S OWN MASK ROWS (senior_01's ruling 2026-11-09, option B): the two-run check compares the oracle's two answers UNDER the
    # rows that mask them, so a program whose only difference is an implementation-defined line (gcbuster's COLLECT and HOST memory
    # statistics, CEO-1344) is absorbed on its run-1 output. The rows come from the package's ALL.mask through the harness's own reader,
    # keyed by entry name; ALL.mask is never edited here. An entry with no rows compares exactly as before.
    _entry_masks = h.read_mask_sidecar(pkg_dir / f"{out_prefix}.ref")
    for i, src in enumerate(srcs, 1):
        # ⭐ QUALIFY WITH PARENT DIR WHEN NESTED (measured on csnobol4_suite: aa.sno at pkg_dir root AND
        # aa/aa.sno one level down are BOTH real, byte-identical vendored fixtures -- bare name would
        # give both entries the identical name/origin ("aa"/"csnobol4_suite__aa"), which is exactly the
        # kind of collision THE RUNGS SUITE's CSV manifest exists to make queryable by name; a name that
        # means two different things defeats that).
        name = _name_of(src)
        if name in pkg_excl:
            _why = f"EXCLUDED.tsv names it {pkg_excl[name][0]} (a measured exclusion holds across builds)" if xsb else f"EXCLUDED.tsv {pkg_excl[name][0]}: {pkg_excl[name][1]}"
            excluded.append((name, _why))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED ({pkg_excl[name][0]}, EXCLUDED.tsv)", file=sys.stderr)
            continue
        if plunit:
            # ⭐ CIO-21 (the cio 2026-11-09): one entry per plunit file, and its entry text is the test file alone (the record equals the file, byte for
            # byte); the harness supplies the shim and the run_tests wrapper and runs the origin file as the test. Its ref is the beside .ref read verbatim, the
            # oracle's per-case verdicts, never cut here. No oracle runs, so --twice has nothing to re-run.
            _ptext = src.read_text(encoding="utf-8", errors="replace")
            if not re.search(r"^[ \t]*:-[ \t]*begin_tests\(", _ptext, re.M):
                excluded.append((name, "no plunit unit: not a case file"))
                print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (no plunit unit)", file=sys.stderr)
                continue
            if not src.with_suffix(".ref").is_file():
                excluded.append((name, f"no {src.stem}.ref beside it: the oracle's verdicts were not cut (util_swi_cut_refs.sh)"))
                print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (no .ref beside it)", file=sys.stderr)
                continue
            _prog = _ptext
            _ref = src.with_suffix(".ref").read_text(encoding="utf-8", errors="replace").splitlines()
            entries.append(h.Entry("block", len(entries) + 1, name, _prog.splitlines(), _ref, stdin=None, want_rc=0))
            print(f"[{i}/{len(srcs)}] {name}: ABSORBED (plunit, {len(_ref)} verdict lines)", file=sys.stderr)
            continue
        _drv = ref_beside and src.stem.endswith("_driver") and src.with_suffix(".ref").is_file()
        if _drv:
            _lib = src.stem[:-len("_driver")]
            if not (src.parent / (_lib + ".icn")).is_file():
                h.refuse(f"{src}: a driver's ref but its library {_lib}.icn is not shipped beside it -- a vehicle with nothing to carry (R-1269)")
            if (src.parent / (_lib + ".ref")).is_file():
                h.refuse(f"{src}: library {_lib} carries its own .ref AND a driver -- two grading vehicles for one library (R-1269)")
        if name in uni_excl:
            excluded.append((name, f"EXCLUDED.tsv {uni_excl[name][0]}: {uni_excl[name][1]}"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED ({uni_excl[name][0]}, EXCLUDED.tsv)", file=sys.stderr)
            continue
        if ref_beside and not src.with_suffix(".ref").is_file():
            if (src.parent / (src.stem + "_driver.ref")).is_file():
                excluded.append((src.relative_to(pkg_dir).as_posix(), f"a library graded through its driver {src.stem}_driver, which is the entry "
                                                                        f"{name}_driver (CONTRACT.tsv units=ref-beside, R-1269)"))
                print(f"[{i}/{len(srcs)}] {name}: GRADED THROUGH {src.stem}_driver (the driver is the entry)", file=sys.stderr)
                continue
            excluded.append((name, f"no {src.stem}.ref beside it -- the package grades it through another unit (a library through its "
                                   f"driver, an include through its includer) or not at all (CONTRACT.tsv units=ref-beside)"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (no .ref beside it, units=ref-beside)", file=sys.stderr)
            continue
        if src.with_suffix(".clib").is_file():
            # ⛔ A PROGRAM THAT LOADS C IS GRADED WHERE ITS LIBRARY IS BUILT (the coo 2026-10-01, measured on arizona_tests: cfuncs,
            # cfunc_driver, extlvals): its <stem>.clib names the vendored C sources, which test_icon_arizona_suite.sh builds through
            # declared_clib_beside and hands to both modes as FPATH; a container entry carries no FPATH contract, so cut here it
            # loaded nothing and its graded run could only fail. Excluded and named until an entry can carry its library.
            excluded.append((name, f"loads C through {src.stem}.clib -- the package's board builds that library and runs it with FPATH; "
                                   f"a container entry carries no FPATH contract yet, so it is graded by the board, not here"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (loads C through {src.stem}.clib)", file=sys.stderr)
            continue
        text, non_utf8 = read_text_tolerant(src)
        if non_utf8:
            excluded.append((name, "source is not valid UTF-8 (genuine 8-bit content, e.g. accented bytes) -- "
                                        "h.write_suite's writer has no encoding param and would re-encode it as UTF-8, "
                                        "silently changing the byte-oriented source's own byte count/content versus what "
                                        "the ref was cut from; excluded rather than absorbed-but-wrong until write_suite "
                                        "itself grows byte-faithful output (shared machinery, out of this tool's lane)"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (non-UTF-8 8-bit source)", file=sys.stderr)
            continue
        # ⛔ A PROGRAM THAT LINKS A MODULE SHIPPED BESIDE IT IS DECIDED BY THE ORACLE'S OWN TRANSLATOR, NEVER BY A SIBLING FILE'S NAME (the
        # coo 2026-10-01, measured on arizona_tests): icont links ucode, never an untranslated .icn beside the program, so Arizona's
        # `link options` / `link io` mean the IPL library even where general/options.icn is shipped -- a name test excluded 31 such
        # programs the oracle builds single-file. A genuinely local link (jcon link1 -> link2, the three drivers) fails the
        # two-step oracle's icont ("cannot resolve reference to file 'link2.u1'") and is excluded below as a translation failure.
        gap, gap_dirs = find_include_gap(text, pkg_dir, src.parent, paths["inc"] if lang in ("", "snobol4") else None)
        if gap:
            _where = ", ".join(str(d) for d in gap_dirs)
            excluded.append((name, f"missing corpus dependency: -INCLUDE {gap!r} resolves in none of {_where} "
                                        f"(searched exactly those dirs -- this reason names its own search, so a file "
                                        f"that IS vendored elsewhere under another path reads as what it is)"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (missing -INCLUDE {gap!r})", file=sys.stderr)
            continue
        if lang in ("", "snobol4") and has_bom(text) and contract["bom"] != "as-shipped":
            excluded.append((name, "source carries a UTF-8 BOM -- confuses the oracle's label lexer (segfault, or a "
                                        "compile-time-only fatal that never executes the program), so its output would be "
                                        "a lexer-confusion artifact, not the program's ground truth"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (UTF-8 BOM)", file=sys.stderr)
            continue
        if lang in ("", "snobol4"):
            n_end = count_top_level_ends(text)
            if n_end > 1:
                excluded.append((name, f"multi-program file: {n_end} top-level END statements -- not a single valid "
                                            "program (SCRIP correctly refuses a duplicate 'END' label; the oracle instead "
                                            "silently continues past it, so neither engine's output is a meaningful "
                                            "single-program comparison)"))
                print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (multi-program file, {n_end} END statements)", file=sys.stderr)
                continue
        stdin_path = stdin_for(src.stem, src.parent) or (pkg_dir / contract["stdin"] if contract["stdin"] else None)  # the file's OWN dir -- == pkg_dir when flat, matters once nested
        # ⭐ PROGRAM ARGUMENTS SIDECAR (row aisnobol-all-eight-..., cto 2026-09-07: HSORT reads its input file name
        # from HOST(0), never stdin): `<stem>.argv` beside the source holds ONE line of TAB-separated arguments,
        # the same tokens the container's ALL.argv then declares for the entry (corpus_suite_harness.py
        # read_argv_sidecar: `name<TAB>arg<TAB>arg`). Absent -> no arguments, byte-identical to before.
        argv_path = src.with_suffix(".argv")
        prog_args = None
        if argv_path.is_file():
            _al = [ln for ln in argv_path.read_text().split("\n") if ln.strip() and not ln.lstrip().startswith("#")]
            prog_args = _al[0].rstrip("\n").split("\t") if _al else None
        stdin_text, stdin_latin1 = read_text_tolerant(stdin_path) if stdin_path else (None, False)
        if stdin_latin1:
            excluded.append((name, f"stdin {stdin_path.name} is not valid UTF-8 (binary or 8-bit data) -- the container's stdin cell is text, "
                                        "so it would not be byte-identical to the file the ref was cut from (the same rule as a non-UTF-8 source)"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (non-UTF-8 stdin {stdin_path.name})", file=sys.stderr)
            continue
        _of_path = src.with_suffix(".outfiles")
        _of_cell = " ".join(ln.strip() for ln in _of_path.read_text().split("\n") if ln.strip() and not ln.lstrip().startswith("#")) if _of_path.is_file() else _decl.get(name, {}).get("out_files", "")
        _ms = merged or _decl.get(name, {}).get("stderr", "") == "merged"
        if any(w.startswith(".") for w in _of_cell.split()):
            _hid = [w for w in _of_cell.split() if w.startswith(".")]
            excluded.append((name, f"out_files names hidden file(s) {' '.join(_hid)} -- the staging rule admits a bare name with no leading '.' "
                                        "(validate_out_files_cell), so the run cannot own them; excluded rather than refused (the whole build would stop)"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (out_files names hidden files)", file=sys.stderr)
            continue
        out_files = h.validate_out_files_cell(_of_cell, str(_of_path) if _of_path.is_file() else f"{pkg_dir / (out_prefix + '.csv')}:{name}") if (_of_path.is_file() or _of_cell) else None
        # ⭐ ISOLATE THE ORACLE INVOCATION, ONE FILE PER THROWAWAY CWD (measured on
        # corpus/packages/icon/ipl/progs/: this project's own Icon oracle driver, run_oracle()'s
        # cwd=sno_path.parent contract landing it in a directory of `link`-directive .icn siblings, renames
        # EVERY .icn file in that cwd to an all-uppercase name as a side effect -- byte-identical content,
        # reproduced 3/3, confined to that one directory each time. Two failure shapes result if run in
        # place: a LATER src in this same loop can vanish out from under its own Path (FileNotFoundError,
        # first measured on progs/url2link.icn); and a program whose own output echoes its invocation name
        # (progs/what: "Usage: what.icn ..." unisolated vs "Usage: WHAT.ICN ..." once the cwd has already
        # been mutated by an earlier file in the loop) cuts a ref for a name this container never records the
        # entry under -- SCRIP would be blamed later for disagreeing with a ref that was never really this
        # program's own ground truth (measured: a first isolation attempt that only added a same-directory
        # case fallback, rather than isolating, produced exactly this ref/name mismatch on 3 of 4 spot-checked
        # absorbed entries). A one-file throwaway cwd sidesteps the mechanism rather than chasing it -- there
        # is nothing else present for the oracle to rename, the real corpus tree is never touched at all, and
        # it matches this package's own README's documented usage (`cp progs/hello.icn /tmp/t.icn && cd /tmp
        # && icont -s t.icn`) rather than inventing a new invocation contract.
        def _oracle_isolated(flags=flags):
            with tempfile.TemporaryDirectory(prefix="pkgsuite_oracle_") as _iso_dir:
                # ⛔ THE ORACLE READS THE NAME THE GRADER STAGES (the coo 2026-11-09, measured on x64tests gcbuster and testpgms test1 and test6):
                # stage_entry writes <name><ext> (ALL.sno's .sno), so a ref cut from the shipped .sbl or .spt name prints &FILE and &LASTFILE
                # the graded run can never print, and the three read FAIL on those two lines alone. Under --src-ext the source is staged as
                # <stem><ext>, byte for byte; with no --src-ext the name is unchanged.
                _iso_src = Path(_iso_dir) / (src.name if src_ext == ext else src.stem + ext)
                # ⭐ COMPANIONS TRAVEL WITH THE SOURCE (row aisnobol-all-eight-..., cto 2026-09-07): a program that
                # -INCLUDEs a vendored module (SIR/TEST -> SPITCORE.sno) or opens a vendored data file by name
                # (spitlib.spt / spitlib.idx) died in the one-file isolation and was filed "oracle died" for want of
                # the files beside it. Every regular file of the package's own directory is copied into the
                # throwaway cwd (a fresh copy per program, so the rename hazard the isolation exists for cannot
                # leak back), the container's own ALL.* excepted; the source itself is written last, verbatim.
                # ⭐ THE GRADER'S INCLUDES TRAVEL TOO (measured 2026-11-08 on the 17 math units): sbl opens -INCLUDE from its cwd (the
                # bench scripts' own note: "the oracles resolve -INCLUDE from their working directory"), so an include the gap check
                # resolved in the grader's include dir is staged beside the source here. Staged beside math_atan, sbl -bf answers
                # 616 of 616; unstaged, ERROR 285 and "No END statement found" -- the exact red the row names. The package's own
                # files are copied after, so a same-named package file wins.
                if lang in ("", "snobol4"):
                    h._copy_companions(src.read_text(errors="replace"), paths["inc"], Path(_iso_dir))
                if lang == "icon" and merged:
                    # ⛔ STAGED AS THE GRADER STAGES (the coo 2026-10-01, measured on jcon recent, which reports the files it finds:
                    # beside the whole package it printed "found file: recogn.dat", a line the shipped ref and the board's
                    # one-program run directory do not have). The ref and the grade must see the same directory, so this path
                    # stages through the harness's own _copy_companions plus the argv companions, as run_suite_entry does.
                    h._copy_companions(src.read_text(errors="replace"), src.parent, Path(_iso_dir))
                    for _tok in (prog_args or []):
                        if _tok and "/" not in _tok and (src.parent / _tok).is_file() and not (Path(_iso_dir) / _tok).exists():
                            (Path(_iso_dir) / _tok).write_bytes((src.parent / _tok).read_bytes())
                else:
                    for _cf in src.parent.iterdir():
                        if _cf.is_file() and not _cf.name.startswith("ALL.") and _cf.name != src.name:
                            (Path(_iso_dir) / _cf.name).write_bytes(_cf.read_bytes())
                _iso_src.write_bytes(src.read_bytes())
                if lang == "icon" and merged and contract["oracle"] == "unicon" and contract["prebuild"]:
                    _unicon_prebuild(Path(_iso_dir), contract["ipath"], contract["prebuild"].split())
                if lang == "icon" and merged and contract["oracle"] == "unicon":
                    return h.run_unicon_built_oracle(paths, _iso_src, paths["timeout"], stdin_text=stdin_text,
                                                                         prog_args=prog_args, out_files=out_files)
                elif lang == "icon" and merged:
                    return h.run_icon_built_oracle(paths, _iso_src, paths["timeout"], stdin_text=stdin_text,
                                                                         prog_args=prog_args, out_files=out_files)
                else:
                    return h.run_oracle(oracle_bin, flags, _iso_src, paths["timeout"], stdin_text=stdin_text,
                                                              prog_args=prog_args, out_files=out_files, merge_stderr=_ms)
        # ⭐ EVERY FPC DIALECT, ISO FIRST (Lon 2026-10-09, in-chat to the coo, verbatim: "I suspect you should ignore the compiler directives
        # suggesting and hinting at the dialect. Let's get all those rosetta programs working if they run and give reasonable results, REF
        # file, from the oracle."): under CONTRACT.tsv dialect=any-fpc-mode a Pascal program fpc refuses to compile under -Miso (the wrapper's
        # exit 126 with nothing on stdout) is compiled again in fpc's default mode (which honours the source's own {$mode}), then objfpc,
        # delphi and tp; the first that compiles cuts the ref, and ALL.dialect names the mode per entry.
        if xsb:
            _why = None
            _r = xsb_runs.get(name)
            if name in xsb_excl:
                _why = f"EXCLUDED.tsv names it {xsb_excl[name]} (a measured exclusion holds across builds)"
            elif _r is None:
                _why = ("XSB's own test scripts run it nowhere (no ORACLE_RUNS.tsv row): a library its loader opens (CONTAINERS.tsv LOADED_BY) "
                        "or a program no XSB script runs (EXCLUDED.tsv NO_ORACLE_ANSWER)")
            elif name in xsb_owed and name not in staged:
                _why = "UNGRADED NEEDS_RUNNER_WIRING: XSB answers it in its upstream directory, and SCRIP's run needs that directory staged (owed)"
            else:
                _k1, _a1, _e1, _rc1 = h.run_xsb_gentest(xsb_bin, contract["upstream"], _r, paths["timeout"])
                _L1 = h.xsb_answer_lines(_a1) if _a1 is not None else None
                if _k1 != "RAN":
                    _why = f"XSB's run ended {_k1} (rc {_rc1}) -- no answer"
                elif _L1 is None:
                    _why = f"XSB wrote no temp file (rc {_rc1}) -- no answer"
                elif twice:
                    _k2, _a2, _e2, _rc2 = h.run_xsb_gentest(xsb_bin, contract["upstream"], _r, paths["timeout"])
                    _L2 = h.xsb_answer_lines(_a2) if _a2 is not None else None
                    if (_k2, _L2) != (_k1, _L1):
                        _why = (f"XSB answers differently on two runs ({len(_L1)} lines, then " + (f"{len(_L2)} lines" if _L2 is not None else f"{_k2}, no temp")
                                + ") -- no one ground truth")
                if _why is None and not _L1:
                    _op0 = Path(contract["upstream"]) / _r["dir"] / f"{_r['file']}_old"
                    _n0 = len(h.xsb_answer_lines(_op0.read_bytes())) if _op0.is_file() else 0
                    _why = (f"XSB prints nothing where its NAME_old has {_n0} lines -- no answer (NO_ORACLE_ANSWER, R-1927 (3))" if _n0 else
                            "XSB's answer is empty, as its NAME_old is -- a silent engine passes it, so it measures nothing (FAKEABLE_NO_OBSERVABLE, R-1865)")
            if _why:
                excluded.append((name, _why))
                print(f"[{i}/{len(srcs)}] {name}: EXCLUDED ({_why[:90]})", file=sys.stderr)
                continue
            _op = Path(contract["upstream"]) / _r["dir"] / f"{_r['file']}_old"
            if _op.is_file():
                _o = h.xsb_answer_lines(_op.read_bytes())
                _w = lambda L: sorted("".join(x.split()) for x in L)
                _chk = "MATCH" if _o == _L1 else ("MATCH-w" if _w(_o) == _w(_L1) else f"DIFF {len(_o)} lines in NAME_old, {len(_L1)} in XSB's answer")
            else:
                _chk = "NO_OLD"
            xsbold.append((name, _chk))
            if _r["kind"] == "wfs":
                text = wfs_entry.wfs_entry_text(pkg_dir, name, _r["cmd"].rstrip().rstrip("."))
            e = h.Entry("block", len(entries) + 1, name, text.splitlines(), _L1, stdin=None, want_rc=0)
            entries.append(e)
            print(f"[{i}/{len(srcs)}] {name}: ABSORBED (XSB, {len(_L1)} lines, NAME_old {_chk.split(' ')[0]})", file=sys.stderr)
            continue
        if name in pkg_refusals:
            entries.append(h.Entry("block", len(entries) + 1, name, read_text_tolerant(src)[0].splitlines(), [""], stdin=stdin_text, want_rc=0))
            print(f"[{i}/{len(srcs)}] {name}: ABSORBED (expected refusal, ISO_EXPECTED_REFUSALS.tsv)", file=sys.stderr)
            continue
        if iso_rej and name.startswith("iso7185prt") and src.with_suffix(".ecp").is_file() and name not in iso_acc:
            # ⭐ CIO-16 (officer_04, 2026-11-09): a PAT rejection test is never asked of fpc, which accepts or refuses it by its own mode. The
            # program is absorbed with an EMPTY ref, and what its refusal must name is written beside the container (ISO_EXPECTED_REFUSALS.tsv).
            # A program EXCLUDED.tsv names is excluded with its reason here, as the EXCLUDED.tsv road does for the xsb and unicon oracles.
            if name in iso_excl:
                excluded.append((name, f"EXCLUDED.tsv {iso_excl[name][0]}: {iso_excl[name][1]}"))
                print(f"[{i}/{len(srcs)}] {name}: EXCLUDED ({iso_excl[name][0]}, EXCLUDED.tsv)", file=sys.stderr)
                continue
            _w = iso_rejection_want(src)
            if _w == "":
                excluded.append((name, "NO_ORACLE_ANSWER: no marked line in its .ecp and no ISO 7185 reference in its header (R-1696)"))
                print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (no marked line and no clause)", file=sys.stderr)
                continue
            entries.append(h.Entry("block", len(entries) + 1, name, read_text_tolerant(src)[0].splitlines(), [""], stdin=stdin_text, want_rc=0))
            iso_rej_names.append((name, _w))
            print(f"[{i}/{len(srcs)}] {name}: ABSORBED (iso-rejection, {_w})", file=sys.stderr)
            continue
        _ladder = [flags, "", "-Mobjfpc", "-Mdelphi", "-Mtp"] if (lang == "pascal" and contract["dialect"] == "any-fpc-mode") else [flags]
        for _fl in _ladder:
            ora_text, ora_rc, ora_kind = _oracle_isolated(_fl)
            _t_first = time.time()
            if not (lang == "pascal" and ora_rc == 126 and not ora_text.strip()):
                break
        if lang == "pascal" and ora_rc == 126 and not ora_text.strip():
            excluded.append((name, "fpc refuses to compile it" + (" in every mode (iso, default, objfpc, delphi, tp)" if len(_ladder) > 1 else " under -Miso")))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (fpc refuses to compile it)", file=sys.stderr)
            continue
        # ⭐ ONE GROUND TRUTH OR NONE (the coo 2026-10-09, --twice, built for the Rosetta packages on Lon's word "Graded against the
        # oracle."): a program that prints the time, a random draw or an address answers differently on every run, so a ref cut from
        # one run grades SCRIP against an accident. Under --twice the oracle runs again in a fresh directory and a program whose
        # output or exit code differs is excluded with that reason, never absorbed.
        # ⛔ THE SECOND RUN STARTS IN A LATER SECOND (the cqo 2026-11-04, measured on rosetta-pascal sleeping-beauty-problem: fpc's randomize
        # seeds from the wall clock in whole seconds, both runs of a sub-second compile-and-run drew the same seed and the program was absorbed
        # with a ref from one accident; three hand runs 2.5 s apart printed 1500363, 1498900, 1499633 wakings). A program seeded from time(NULL)
        # repeats itself inside one second, so the rerun waits until the clock has passed the second the first run ended in.
        if twice and ora_kind not in ("TRANSLATE", "HANG", "UNPROVEN", "OVERFLOW"):
            time.sleep(max(0.0, math.floor(_t_first) + 1.05 - time.time()))
        _run2 = _oracle_isolated(_fl)[:2] if twice and ora_kind not in ("TRANSLATE", "HANG", "UNPROVEN", "OVERFLOW") else (ora_text, ora_rc)
        _mrows = _entry_masks.get(name, [])
        if twice and ora_kind not in ("TRANSLATE", "HANG", "UNPROVEN", "OVERFLOW") and (h.apply_line_mask(_run2[0], _mrows, "oracle")[0], _run2[1]) != (h.apply_line_mask(ora_text, _mrows, "oracle")[0], ora_rc):
            excluded.append((name, "the oracle answers differently on two runs (time, randomness or addresses in its output) -- no one ground truth"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (oracle nondeterministic)", file=sys.stderr)
            continue
        if ora_kind == "TRANSLATE":
            excluded.append((name, f"the oracle's translator refused it: {ora_text}"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (oracle translation failed)", file=sys.stderr)
            continue
        if ora_kind == "HANG":
            excluded.append((name, "oracle timed out -- non-terminating or too slow for the grading timeout"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (oracle HANG)", file=sys.stderr)
            continue
        if ora_kind == "OVERFLOW":
            # ⛔ A RUN THE OUTPUT BOUND KILLED IS NO ANSWER (the coo 2026-10-23, measured on rosetta-pascal: seven interactive programs that loop at
            # EOF printing a prompt -- menu, nim-game, pig-the-dice-game -- each wrote exactly the bound, 268435457 bytes, twice, and were absorbed:
            # ALL.ref grew from 236 KB to 1.88 GB; R-1927 (5)). _run_raw hands back the truncated stream with kind OVERFLOW and no rc.
            excluded.append((name, f"the oracle's output passed the harness's bound (S4E_OUTPUT_CAP_MB, {h._OUTPUT_CAP} bytes) and the run was killed -- no answer"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (oracle output OVERFLOW)", file=sys.stderr)
            continue
        if ora_kind == "UNPROVEN":
            h.refuse(f"oracle binary not runnable at all: {oracle_bin}")
        if ora_rc is not None and ora_rc < 0:
            excluded.append((name, f"oracle crashed (signal {-ora_rc})"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (oracle crashed, signal {-ora_rc})", file=sys.stderr)
            continue
        if sbl_died(ora_text) and contract["fatal"] != "gradable":
            excluded.append((name, "oracle died: graceful fatal report (e.g. undefined function) -- no ground truth to grade against"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (oracle died)", file=sys.stderr)
            continue
        if re.search(r"cannot open display", ora_text, re.I):
            # ⛔ A DISPLAY REFUSAL IS NO ANSWER (the coo 2026-10-23, measured on rosetta-pascal window-creation-x11: its ref came out as
            # "[ModalShowX11Window] Cannot open display"): every child runs headless (harness e3856ca, DISPLAY and WAYLAND_DISPLAY unset), so a
            # program that opens a window can only print the oracle's refusal -- a fact about the box, never the program's answer (NEEDS_DISPLAY).
            excluded.append((name, "the oracle could not open a display (every run is headless) -- its output is the refusal, no answer (NEEDS_DISPLAY)"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (the oracle could not open a display)", file=sys.stderr)
            continue
        if not ora_text.strip():
            # ⛔⭐ AN EMPTY RUN IS NOT ALWAYS AN EMPTY PROGRAM (measured on jcon_tests, the first package
            # with argv-consuming entries: 14 of 91 files ship a same-stem `.dat` that JCON's own
            # `addtest` convention feeds as BOTH argv[1] AND stdin -- test_icon_jcon_suite.sh already
            # does this correctly. This builder/h.run_oracle() has no argv-passing mechanism at all
            # (ALL.in covers stdin only), so it invoked these with NEITHER, and several genuinely need
            # the file to produce anything -- a harness gap, not a fact about the program. ⚠ NOT every
            # .dat-stem file needs argv: 7 others (endetab/fncs1/io/mffsol/mindfa/others/recent)
            # produced correct non-empty output through this exact same bare invocation and are already
            # ABSORBED above, untouched by this branch -- so this reason is scoped to the empty-output
            # case specifically, never a blanket "has a .dat -> exclude" rule that would demote them.
            _dat = src.parent / f"{src.stem}.dat"
            if _dat.is_file():
                excluded.append((name, "oracle produced EMPTY output when run bare, but a same-stem .dat companion "
                                            "exists -- likely needs it as argv[1] (JCON addtest convention), and this "
                                            "builder has no argv-passing mechanism (ALL.in is stdin-only); needs an "
                                            "ALL.args extension or grading via the package's own dedicated runner, "
                                            "not a fact about the program's real output"))
                print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (empty output, has .dat -- likely needs argv, harness gap)", file=sys.stderr)
                continue
            excluded.append((name, "oracle produced EMPTY output -- refusing to mint a vacuous ref"))
            print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (empty oracle output)", file=sys.stderr)
            continue
        # ⭐ A CR IN THE ORACLE'S ANSWER IS THE PROGRAM'S OUTPUT BYTE (R-1926, ruled 2026-10-23, .github fda2eb592; withdraws the coo's
        # exclusion of 2026-10-09): the ref keeps it byte for byte -- the container is read back split on LF only (_read_lf_lines), so a CR
        # stays inside its line, and a container whose ref then carries a CR at end of line is declared in lf_gate_crlf_is_the_subject.tsv.
        want_rc = ora_rc if ora_rc else 0
        _exp = read_text_tolerant(src.with_suffix(".ref"))[0] if _drv else ora_text
        e = h.Entry("block", len(entries) + 1, name, text.splitlines(), _exp.split("\n"),
                     stdin=stdin_text, want_rc=want_rc)
        entries.append(e)
        if len(_ladder) > 1:
            # ⛔ THE LABEL IS THE MODE FPC COMPILED IN, NOT THE RUNG THAT ASKED (hq_pascal 2026-10-11, R-1657 clause 4): a source's own
            # {$mode X} overrides the command line, so 102 entries cut on the -Miso rung under {$mode delphi} or {$mode objfpc} read "iso"
            # and two delphi programs sat on ISO_EXPECTED_REFUSALS.tsv. The source's first {$mode X} names the mode; every directive in
            # rosetta-pascal sits in a branch fpc takes ({$ifdef fpc}, {$else} of {$ifndef fpc}), measured, so the first one is the one fpc obeys.
            _dm = re.search(r"\{\$mode\s+([a-z]+)", text, re.I)
            _dmode = {"fpc": "fpc-default", "delphiunicode": "delphi"}.get(_dm.group(1).lower(), _dm.group(1).lower()) if _dm else None
            dialects.append((name, _dmode or {"-Miso": "iso", "": "fpc-default", "-Mobjfpc": "objfpc", "-Mdelphi": "delphi", "-Mtp": "tp"}[_fl]))
        _fed = f" [stdin: {stdin_path.name}]" if stdin_text is not None else ""
        if prog_args: e.argv = list(prog_args)
        if out_files: e.out_files = list(out_files)
        e.decl_stderr = _ms
        _rc = f" [want_rc={want_rc}]" if want_rc else ""
        print(f"[{i}/{len(srcs)}] {name}: ABSORBED{_fed}{_rc}", file=sys.stderr)

    tot = len(srcs)
    if len(entries) + len(excluded) != tot:
        h.refuse(f"population arithmetic broken: {len(entries)} absorbed + {len(excluded)} excluded != {tot} shipped")
    if only is not None:
        return splice(pkg_dir, lang, ext, out_prefix, entries, excluded, dialects, contract, merged, staged, all_srcs)

    out_sno = pkg_dir / f"{out_prefix}{ext}"
    out_ref = pkg_dir / f"{out_prefix}.ref"
    out_in = pkg_dir / f"{out_prefix}.in"
    out_wantrc = pkg_dir / f"{out_prefix}.rc"
    out_csv = pkg_dir / f"{out_prefix}.csv"
    out_excl = pkg_dir / f"{out_prefix}.omit"

    if not entries:
        # ⭐ hq_T ruling 2026-09-04 (q-package-builder-zero-absorbable-policy, to seat15): refusing the
        # container is correct -- an ALL.csv with 0 rows would read as HARNESSED with a score of zero to
        # every downstream census -- but the honest state is OWED WITH A NAMED ACCOUNTING, not silence.
        # Land the excluded-reasons file even though no container follows; a zero-absorbable package is
        # NOT-HARNESS-SHAPED, and the reasons are exactly as real as they'd be beside a non-empty ALL.csv.
        if excluded:
            out_excl.write_text("\n".join(f"{name}: {reason}" for name, reason in sorted(excluded)) + "\n")
        h.refuse(f"{pkg_dir}: zero absorbable entries of {tot} shipped -- a container that grades nothing is not a "
                    f"container; NOT-HARNESS-SHAPED accounting written to {out_excl.name} ({tot} named, 0 absorbable)")

    wrote_in = h.write_suite(entries, str(out_sno), str(out_ref), out_in=str(out_in), lang=lang)
    if not wrote_in and out_in.exists():
        out_in.unlink()

    out_xsbold = pkg_dir / f"{out_prefix}.xsbold"
    if xsbold:
        out_xsbold.write_text("# each absorbed entry's XSB answer against the upstream NAME_old XSB ships, as gentest.sh compares (sorted; MATCH-w: equal once "
                              "white space is removed, diff -w): name<TAB>check. The ref is XSB's answer either way (R-1927 (1)).\n"
                              + "".join(f"{n}\t{c}\n" for n, c in xsbold))
    elif out_xsbold.exists():
        out_xsbold.unlink()
    out_dialect = pkg_dir / f"{out_prefix}.dialect"
    if dialects:
        out_dialect.write_text("# the fpc mode that cut each entry's ref (CONTRACT.tsv dialect=any-fpc-mode): name<TAB>mode\n"
                               + "".join(f"{n}\t{d}\n" for n, d in dialects))
    elif out_dialect.exists():
        out_dialect.unlink()
    if iso_rej and iso_rej_names:
        (pkg_dir / "ISO_EXPECTED_REFUSALS.tsv").write_text("# ISO_EXPECTED_REFUSALS.tsv -- written by util_build_package_suite.py under units iso-rejection (CIO-16): entry<TAB>what the refusal must name\n"
                                                           + "".join(f"{n}\t{w}\n" for n, w in iso_rej_names))
    wr_lines = [f"{e.name}\t{e.want_rc}" for e in entries if e.want_rc]
    if wr_lines:
        out_wantrc.write_text("\n".join(wr_lines) + "\n")
    elif out_wantrc.exists():
        out_wantrc.unlink()
    out_argv = pkg_dir / f"{out_prefix}.argv"
    av_lines = [e.name + "\t" + "\t".join(getattr(e, "argv", None) or []) for e in entries if getattr(e, "argv", None)]
    if av_lines:
        out_argv.write_text("\n".join(av_lines) + "\n")
    elif out_argv.exists():
        out_argv.unlink()

    table_lang = lang or "snobol4"
    cols, _ = m.LANG_TABLES[table_lang]
    # ⛔⭐⭐ READ THE OLD CSV BEFORE OVERWRITING IT, FOR heap_kb AND heap_kb ALONE (Lon 2026-09-23 /
    # R-1167). Every other column in this file is DERIVED -- re-run the builder and it regenerates
    # byte-identically from the package sources. heap_kb is the one column that is not: it is a
    # MEASUREMENT a seat paid for with two readings (matched at that arena, not matched one step below),
    # and nothing in a program's text can regenerate it. This builder overwrote out_csv unconditionally,
    # so without this read a routine rebuild would silently return a declared 65536 KB program to the
    # shipped default -- a capacity red reappearing with no diff naming the cause, which is precisely the
    # failure the rungs builder's own MERGE-NEVER-OVERWRITE note was written about one file over.
    # ⛔⭐ AN ENTRY WITH NO DECLARATION OF ITS OWN GETS THE SHIPPED DEFAULTS WRITTEN OUT (the coo 2026-10-02, measured: corpus 239502c47's
    # arizona_tests rebuild absorbed 18 drivers under names no old row carried, wrote their heap_kb/stack_kb blank, and
    # test_gate_the_default_stack_and_heap_are_spitbols arm 4 went red, blocking; R-1409): the rungs builder's DEFAULT_HEAP_KB /
    # DEFAULT_STACK_KB (SPITBOL's -d128m -s4m, the harness constants), never a blank cell -- a carried-forward measurement still wins.
    _old_heap = {}
    _old_stack = {}   # stack_kb: the same kind of paid-for measurement, carried forward the same way (R-1225)
    _old_cmd = {}     # compile_args and run_args: the unit's command line, carried forward the same way (clause 8 (f), R-1281)
    _cmd_cols = ["compile_args", "run_args"]   # a new table gets both; a rebuild keeps the ones the table has, never imposes one
    _of_col = ["out_files"] if any(getattr(e, "out_files", None) for e in entries) or any(d.get("out_files") for d in _decl.values()) else []   # from <stem>.outfiles, else the table's own declaration
    _se_col = ["stderr"] if merged or any(d.get("stderr") for d in _decl.values()) else []   # from CONTRACT.tsv (every entry), else the table's own per-entry declaration
    _tmo_col = ["timeout_s"] if "timeout_s" in _decl_cols else []   # the declared bound (test-cycle step 6), carried forward; a table that never declared one gains none here
    # ⭐ fresh-vars and error-context (corpus_suite_harness.py _grade_output): a Prolog ref prints a fresh variable as the oracle names it
    # (ISO/IEC 13211-1 7.10.5) and an error term's context as the oracle builds it (7.12.1), both the implementation's; each is derived
    # from the entry's own ref, every build.
    _fv_rx = re.compile(r"(?<![A-Za-z0-9_])_[A-Za-z]?[0-9]+(?![A-Za-z0-9_])")
    _ec_rx = re.compile(r"(?<![A-Za-z0-9_])error\(")
    def _ref_text(e):
        r = getattr(e, "ref", "") or ""
        return "\n".join(r) if isinstance(r, (list, tuple)) else str(r)
    def _cm_val(e):
        t = _ref_text(e) if lang == "prolog" else ""
        toks = (["fresh-vars"] if _fv_rx.search(t) else []) + (["error-context"] if _ec_rx.search(t) else []) + (["ignore-all-space"] if contract["compare"] == "ignore-all-space" else [])
        return "+".join(toks)
    _cm_col = ["compare"] if any(_cm_val(e) for e in entries) else []   # derived from CONTRACT.tsv and the refs, every build (R-1927)
    _sg_col = ["stage", "answer"] if staged else []   # derived from STAGED.tsv, every build (R-1927)
    _gr_col = ["grader", "cwd"] if plunit else []   # CIO-15 (c): swi-cases for every entry; cwd is the entry directory (. at the top)
    # ⛔⭐ A ROW THE BOARD LOOKS UP IS NOT THE BUILDER'S TO DROP (the coo 2026-10-01, measured on jcon_tests): this table is ALSO the
    # settings table the package's own runner reads each unit's heap_kb/stack_kb/compile_args from (RULES.md 8 (f); f8282e09c added
    # 657 such rows), and a unit this build does not absorb -- a library graded through its driver, a program whose oracle output
    # is empty here -- still has a row there. A rebuild that wrote only the absorbed entries dropped 11 of jcon_tests' 85 (cxtrace,
    # lgint, link1, link2, load1, load2, loadfunc, proto, toby, traceback, tracing), and the board would have graded those at the
    # runtime's defaults. So every old row whose unit is still SHIPPED and not absorbed now is carried forward as a settings row:
    # its declarations kept, its feature cells blank (it has no block, so it marks no feature for the area smoke).
    _shipped_names = {_name_of(src) for src in srcs}
    _absorbed_names = {e.name for e in entries}
    _carried = []
    _gap_col = []
    _old_gap = {}
    if out_csv.exists():
        with open(out_csv, newline="") as _f:
            _rdr = csv.DictReader(_f)
            _cmd_cols = [c for c in _cmd_cols if c in (_rdr.fieldnames or [])]
            _gap_col = ["mode_gap_s"] if "mode_gap_s" in (_rdr.fieldnames or []) else []
            for _row in _rdr:
                if _row.get("entry") in _shipped_names and _row.get("entry") not in _absorbed_names:
                    _carried.append(_row)
                _v = (_row.get("heap_kb") or "").strip()
                if _v:
                    _old_heap[_row.get("entry")] = _v
                _s = (_row.get("stack_kb") or "").strip()
                if _s:
                    _old_stack[_row.get("entry")] = _s
                _c = {c: (_row.get(c) or "").strip() for c in ("compile_args", "run_args")}
                if any(_c.values()):
                    _old_cmd[_row.get("entry")] = _c
                _g = (_row.get("mode_gap_s") or "").strip()
                if _g:
                    _old_gap[_row.get("entry")] = _g
    with open(out_csv, "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["rank", "entry", "origin", "package", "n_lines", "stdin", "want_rc", "heap_kb", "stack_kb"] + _tmo_col + _cmd_cols + _of_col + _se_col + _cm_col + _sg_col + _gr_col + _gap_col + [c for c, _fn in cols])
        for e in entries:
            joined = "\n".join(e.sno_lines)
            flags_row = m.attrs_for_text(joined, table_lang)
            w.writerow([e.seq, e.name, f"{pkg_dir.name}__{e.name}", pkg_dir.name, len(e.sno_lines),
                        1 if e.stdin else 0, e.want_rc, _old_heap.get(e.name, m.DEFAULT_HEAP_KB), _old_stack.get(e.name, m.DEFAULT_STACK_KB)] + [_decl.get(e.name, {}).get("timeout_s", "") for c in _tmo_col] + [_old_cmd.get(e.name, {}).get(c, "") or (contract["unmarked_compile_args"] if c == "compile_args" and contract["unmarked_compile_args"] and not icn_marked("\n".join(e.sno_lines)) else "") for c in _cmd_cols] + [" ".join(getattr(e, "out_files", None) or []) for c in _of_col] + [("merged" if getattr(e, "decl_stderr", merged) else "") for c in _se_col] + [_cm_val(e) for c in _cm_col] + ((["upstream", "" if staged[e.name] == "stdout" else staged[e.name]] if e.name in staged else ["", ""]) if _sg_col else []) + ((["swi-cases", e.name.rsplit("/", 1)[0] if "/" in e.name else "."]) if _gr_col else []) + [_old_gap.get(e.name, "") for c in _gap_col] + [flags_row[c] for c, _fn in cols])
        _rank = max([e.seq for e in entries] or [0])
        for _row in sorted(_carried, key=lambda r: r.get("entry") or ""):
            _rank += 1
            w.writerow([_rank, _row.get("entry"), _row.get("origin") or f"{pkg_dir.name}__{_row.get('entry')}", _row.get("package") or pkg_dir.name,
                        _row.get("n_lines") or "", _row.get("stdin") or "0", _row.get("want_rc") or "0",
                        (_row.get("heap_kb") or "").strip() or m.DEFAULT_HEAP_KB, (_row.get("stack_kb") or "").strip() or m.DEFAULT_STACK_KB] + [(_row.get(c) or "").strip() for c in _tmo_col] + [(_row.get(c) or "").strip() for c in _cmd_cols]
                       + [(_row.get(c) or "").strip() for c in _of_col] + [(_row.get(c) or "").strip() for c in _se_col] + ["" for c in _cm_col] + ["" for c in _sg_col] + ["" for c in _gr_col] + [(_row.get(c) or "").strip() for c in _gap_col] + ["" for c, _fn in cols])
    if _carried:
        print("    settings rows: %d unit(s) still shipped and not absorbed by this build carried forward, declarations kept, no block: %s"
              % (len(_carried), ", ".join(sorted(r.get("entry") or "" for r in _carried))), file=sys.stderr)
    if _old_heap:
        print("    heap_kb: %d declaration(s) carried forward across this rebuild: %s"
              % (len(_old_heap), ", ".join("%s=%sKB" % kv for kv in sorted(_old_heap.items()))), file=sys.stderr)
    if _old_stack:
        print("    stack_kb: %d declaration(s) carried forward across this rebuild: %s"
              % (len(_old_stack), ", ".join("%s=%sKB" % kv for kv in sorted(_old_stack.items()))), file=sys.stderr)
    if _old_cmd:
        print("    compile_args/run_args: %d declaration(s) carried forward across this rebuild: %s"
              % (len(_old_cmd), ", ".join("%s=[%s|%s]" % (k, v["compile_args"], v["run_args"]) for k, v in sorted(_old_cmd.items()))), file=sys.stderr)

    # ⭐ A PROGRAM'S <stem>.mask TRAVELS INTO ALL.mask UNDER ITS ENTRY NAME (the coo 2026-10-01, measured on arizona_tests: general/env
    # prints the host, the date and the clock, and its env.mask -- read by test_icon_arizona_suite.sh beside env.ref -- masks those
    # lines; the harness reads ONE ALL.mask beside ALL.ref, keyed by the entry, and a container cut without it graded env against
    # the hour its ref was cut). Each absorbed entry's sidecar rows are written with the entry's own name in column 1 (env ->
    # general/env). Rows an existing ALL.mask holds for entries no sidecar covers are kept as they stand (the SNOBOL4 packages'
    # masks are written there by hand); with no sidecar at all ALL.mask is not touched.
    out_mask = pkg_dir / f"{out_prefix}.mask"
    _mask_rows = []
    _src_of = {_name_of(src): src for src in srcs}
    for e in entries:
        _mp = _src_of[e.name].with_suffix(".mask") if e.name in _src_of else None
        if _mp is None or not _mp.is_file():
            continue
        for _ln in _mp.read_text(encoding="utf-8").splitlines():
            if not _ln.strip() or _ln.lstrip().startswith("#"):
                continue
            _f = _ln.split("\t")
            if len(_f) < 3 or not _f[1].strip() or not _f[2].strip():
                h.refuse(f"{_mp}: a mask row is entry<TAB>regex-or-L<n><TAB>reason -- got {_ln!r}")
            _mask_rows.append("\t".join([e.name] + _f[1:]))
    if _mask_rows:
        _covered = {r.split("\t", 1)[0] for r in _mask_rows}
        _kept = []
        if out_mask.exists():
            for _ln in out_mask.read_text(encoding="utf-8").splitlines():
                if _ln.strip() and not _ln.lstrip().startswith("#") and _ln.split("\t", 1)[0] in _covered:
                    continue
                _kept.append(_ln)
        if not _kept:
            _kept = ["# ALL.mask -- R-409 line masks for this container (entry<TAB>L<n>-or-python-regex<TAB>reason); the rows of an entry",
                     "# whose program ships a <stem>.mask are written from it by util_build_package_suite.py under the entry's name."]
        out_mask.write_text("\n".join(_kept + _mask_rows) + "\n", encoding="utf-8")
        print("    masks: %d row(s) from %d <stem>.mask sidecar(s) written into %s under the entry names"
              % (len(_mask_rows), len(_covered), out_mask.name), file=sys.stderr)

    if excluded:
        out_excl.write_text("\n".join(f"{name}: {reason}" for name, reason in sorted(excluded)) + "\n")
    elif out_excl.exists():
        out_excl.unlink()

    print(f"\n{pkg_dir}: {len(entries)} absorbed, {len(excluded)} excluded, {tot} shipped (balanced)", file=sys.stderr)
    return entries, excluded, tot


def _lines(path):
    if not path.is_file():
        return []
    t = path.read_text(encoding="utf-8")
    return t[:-1].split("\n") if t.endswith("\n") else t.split("\n")


def _is_row(ln):
    return bool(ln.strip()) and not ln.lstrip().startswith("#")


def _keyed_text(old, header, rows, names, sep):
    by = {r.split(sep, 1)[0]: r for r in rows}
    out, placed = [], set()
    for ln in old:
        k = ln.split(sep, 1)[0]
        if _is_row(ln) and k in names:
            if k in by and k not in placed:
                out.append(by[k])
                placed.add(k)
            continue
        out.append(ln)
    out += [r for r in rows if r.split(sep, 1)[0] not in placed]
    if not any(_is_row(ln) for ln in out):
        return None
    if not old:
        out = header + out
    return "\n".join(out) + "\n"


def splice(pkg_dir, lang, ext, out_prefix, entries, excluded, dialects, contract, merged, staged, all_srcs):
    sno = lang in ("", "snobol4")
    lc = None if sno else h.LANG_CONFIGS.get(lang)
    if lc is None and not sno:
        h.refuse(f"--only needs a container the harness reads (lang {lang!r} is neither SNOBOL4 nor in LANG_CONFIGS)")
    f_src, f_ref, f_in, f_csv = f"{out_prefix}{ext}", f"{out_prefix}.ref", f"{out_prefix}.in", f"{out_prefix}.csv"
    for _f in (f_src, f_ref, f_csv):
        if not (pkg_dir / _f).is_file():
            h.refuse(f"--only splices into an existing container: {_f} is missing in {pkg_dir}")
    bre = None if sno else h.banner_re_for(lc["comment_open"], lc["comment_close"])
    def _read(d):
        _i = d / f_in
        try:
            if sno:
                return h.read_suite(str(d / f_src), str(d / f_ref), in_path=str(_i) if _i.is_file() else None)
            return h.read_block_suite(str(d / f_src), str(d / f_ref), bre, in_path=str(_i) if _i.is_file() else None)
        except ValueError as _e:
            h.refuse(f"splice gate: the container in {d} does not read: {_e}")
    def _shape(es):
        return {e.name: (e.seq, list(e.sno_lines), list(e.ref), e.stdin) for e in es}
    names = {e.name for e in entries} | {n for n, _w in excluded}
    old = _read(pkg_dir)
    old_names = [e.name for e in old]
    before = _shape(old)
    gone = [(n, w) for n, w in excluded if n in before]
    if gone:
        h.refuse(f"splice gate: {len(gone)} named program(s) in the container are excluded by this cut, and removing an entry renumbers every "
                 f"banner after it -- a whole rebuild's business or an exclusion row's: {'; '.join(f'{n}: {w}' for n, w in gone)}")
    new_by = {e.name: e for e in entries}
    appended = [e for e in entries if e.name not in before]
    merged_entries = [new_by.get(e.name, e) for e in old] + appended
    staged_files = {}
    with tempfile.TemporaryDirectory(prefix="pkgsuite_splice_") as _td:
        _td = Path(_td)
        (_td / "as-is").mkdir()
        (_td / "spliced").mkdir()
        h.write_suite(list(old), str(_td / "as-is" / f_src), str(_td / "as-is" / f_ref), out_in=str(_td / "as-is" / f_in), lang=lang)
        for _f in (f_src, f_ref, f_in):
            _a = (pkg_dir / _f).read_bytes() if (pkg_dir / _f).is_file() else b""
            _b = (_td / "as-is" / _f).read_bytes() if (_td / "as-is" / _f).is_file() else b""
            if _a != _b:
                h.refuse(f"splice gate: {_f} as it stands does not read back byte-identically through its reader and write_suite "
                         f"({len(_a)} bytes on disk, {len(_b)} rewritten), so no splice can keep its other entries byte-identical")
        for seq, e in enumerate(merged_entries, 1):
            e.seq = seq
        wrote_in = h.write_suite(merged_entries, str(_td / "spliced" / f_src), str(_td / "spliced" / f_ref), out_in=str(_td / "spliced" / f_in), lang=lang)
        after = _shape(_read(_td / "spliced"))
        for n in old_names:
            if n not in names and after.get(n) != before[n]:
                h.refuse(f"splice gate: untouched entry {n} would change (banner number, source, ref or stdin) -- nothing written")
        for _f in (f_src, f_ref) + ((f_in,) if wrote_in else ()):
            staged_files[_f] = (_td / "spliced" / _f).read_bytes()
    if not wrote_in:
        staged_files[f_in] = None
    table_lang = lang or "snobol4"
    cols, _ = m.LANG_TABLES[table_lang]
    _fv_rx = re.compile(r"(?<![A-Za-z0-9_])_[A-Za-z]?[0-9]+(?![A-Za-z0-9_])")
    _ec_rx = re.compile(r"(?<![A-Za-z0-9_])error\(")
    def _cm_val(e):
        t = "\n".join(e.ref) if lang == "prolog" else ""
        toks = (["fresh-vars"] if _fv_rx.search(t) else []) + (["error-context"] if _ec_rx.search(t) else []) + (["ignore-all-space"] if contract["compare"] == "ignore-all-space" else [])
        return "+".join(toks)
    csv_lines = _lines(pkg_dir / f_csv)
    hdr = next(csv.reader([csv_lines[0]]))
    ix = {c: i for i, c in enumerate(hdr)}
    known = {"rank", "entry", "origin", "package", "n_lines", "stdin", "want_rc", "heap_kb", "stack_kb", "compile_args", "run_args", "out_files", "stderr",
             "compare", "stage", "answer", "mode_gap_s", "timeout_s"} | {c for c, _fn in cols}
    if set(hdr) - known or "entry" not in ix or "rank" not in ix:
        h.refuse(f"splice gate: {f_csv}'s header is not one the splice can fill: unknown {sorted(set(hdr) - known)}")
    for e in entries:
        for _col, _need in (("out_files", getattr(e, "out_files", None)), ("compare", _cm_val(e)), ("stderr", merged), ("stage", e.name in staged)):
            if _need and _col not in ix:
                h.refuse(f"splice gate: {e.name} needs a {_col} cell and {f_csv} has no {_col} column -- a whole rebuild adds it")
    rows = [next(csv.reader([ln])) for ln in csv_lines[1:]]
    row_at = {r[ix["entry"]]: k for k, r in enumerate(rows)}
    rank_max = max([int(r[ix["rank"]]) for r in rows if r[ix["rank"]].isdigit()] or [0])
    def _fmt(v):
        _s = io.StringIO()
        csv.writer(_s, lineterminator="\n").writerow([v[c] for c in hdr])
        return _s.getvalue()[:-1]
    out_lines = list(csv_lines)
    for e in entries:
        flags_row = m.attrs_for_text("\n".join(e.sno_lines), table_lang)
        v = {"entry": e.name, "origin": f"{pkg_dir.name}__{e.name}", "package": pkg_dir.name, "n_lines": len(e.sno_lines), "stdin": 1 if e.stdin else 0,
             "want_rc": e.want_rc, "heap_kb": m.DEFAULT_HEAP_KB, "stack_kb": m.DEFAULT_STACK_KB, "run_args": "", "mode_gap_s": "", "timeout_s": "",
             "compile_args": contract["unmarked_compile_args"] if contract["unmarked_compile_args"] and not icn_marked("\n".join(e.sno_lines)) else "",
             "out_files": " ".join(getattr(e, "out_files", None) or []), "stderr": "merged" if merged else "", "compare": _cm_val(e),
             "stage": "upstream" if e.name in staged else "", "answer": ("" if staged[e.name] == "stdout" else staged[e.name]) if e.name in staged else ""}
        v.update({c: flags_row[c] for c, _fn in cols})
        if e.name in row_at:
            prev = rows[row_at[e.name]]
            v["rank"] = prev[ix["rank"]]
            for c in ("heap_kb", "stack_kb", "compile_args", "run_args", "mode_gap_s", "timeout_s"):
                if c in ix and prev[ix[c]].strip():
                    v[c] = prev[ix[c]].strip()
            out_lines[row_at[e.name] + 1] = _fmt(v)
        else:
            rank_max += 1
            v["rank"] = rank_max
            out_lines.append(_fmt(v))
    for k, (a, b) in enumerate(zip(csv_lines, out_lines)):
        if a != b and (k == 0 or rows[k - 1][ix["entry"]] not in names):
            h.refuse(f"splice gate: untouched line {k + 1} of {f_csv} would change -- nothing written")
    staged_files[f_csv] = ("\n".join(out_lines) + "\n").encode()
    def _keyed(f, header, rows_, keys):
        t = _keyed_text(_lines(pkg_dir / f), header, rows_, keys, "\t")
        staged_files[f] = None if t is None else t.encode("utf-8")
    _keyed(f"{out_prefix}.dialect", ["# the fpc mode that cut each entry's ref (CONTRACT.tsv dialect=any-fpc-mode): name<TAB>mode"], [f"{n}\t{d}" for n, d in dialects], names)
    _keyed(f"{out_prefix}.rc", [], [f"{e.name}\t{e.want_rc}" for e in entries if e.want_rc], names)
    _keyed(f"{out_prefix}.argv", [], [e.name + "\t" + "\t".join(e.argv) for e in entries if getattr(e, "argv", None)], names)
    _src_of = {f"{s.parent.name}/{s.stem}" if s.parent != pkg_dir else s.stem: s for s in all_srcs}
    _mask_rows = []
    for e in entries:
        _mp = _src_of[e.name].with_suffix(".mask")
        for _ln in (_mp.read_text(encoding="utf-8").splitlines() if _mp.is_file() else []):
            if not _is_row(_ln):
                continue
            _f = _ln.split("\t")
            if len(_f) < 3 or not _f[1].strip() or not _f[2].strip():
                h.refuse(f"{_mp}: a mask row is entry<TAB>regex-or-L<n><TAB>reason -- got {_ln!r}")
            _mask_rows.append("\t".join([e.name] + _f[1:]))
    if _mask_rows:
        _keyed(f"{out_prefix}.mask", ["# ALL.mask -- R-409 line masks for this container (entry<TAB>L<n>-or-python-regex<TAB>reason); the rows of an entry",
                                      "# whose program ships a <stem>.mask are written from it by util_build_package_suite.py under the entry's name."],
               _mask_rows, {r.split("\t", 1)[0] for r in _mask_rows})
    _ex = [ln for ln in _lines(pkg_dir / f"{out_prefix}.omit") if ln.split(": ", 1)[0] not in names]
    _ex = sorted(_ex + [f"{n}: {w}" for n, w in excluded], key=lambda ln: (ln.split(": ", 1)[0], ln))
    staged_files[f"{out_prefix}.omit"] = ("\n".join(_ex) + "\n").encode() if _ex else None
    for _f, _b in staged_files.items():
        if _b is None:
            if (pkg_dir / _f).exists():
                (pkg_dir / _f).unlink()
        elif not (pkg_dir / _f).is_file() or (pkg_dir / _f).read_bytes() != _b:
            (pkg_dir / _f).write_bytes(_b)
    print(f"\n{pkg_dir}: SPLICED {len(entries)} absorbed ({len(entries) - len(appended)} re-cut in place, {len(appended)} appended) and {len(excluded)} "
          f"excluded of {len(names)} named; {len([n for n in old_names if n not in names])} untouched entries proved identical (banner, source, ref, stdin)", file=sys.stderr)
    for e in entries:
        print(f"    {'APPENDED' if e in appended else 'RE-CUT'} {e.name}", file=sys.stderr)
    for n, w in excluded:
        print(f"    EXCLUDED {n}: {w}", file=sys.stderr)
    return entries, excluded, len(names)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("package_dir")
    ap.add_argument("--lang", default="", choices=sorted(set(LANG_EXT) - {""}),
                     help="default snobol4 (blank); selects extension + attribute table + oracle")
    ap.add_argument("--twice", action="store_true",
                    help="run the oracle twice per program and exclude one whose two answers differ (time, randomness, addresses)")
    ap.add_argument("--only", action="append", default=None, metavar="NAME[,NAME...]",
                    help="cut only these programs and splice them into the existing container, every other entry byte-identical (repeatable)")
    ap.add_argument("--src-ext", default="", metavar=".EXT",
                    help="the extension the package's source programs carry, when it is not the lang's container extension "
                         "(SPITBOL's own suite ships .sbl; the container is still ALL.sno for snobol4)")
    args = ap.parse_args()
    pkg_dir = Path(args.package_dir).resolve()
    if not pkg_dir.is_dir():
        h.refuse(f"not a directory: {pkg_dir}")
    only = None
    if args.only is not None:
        only = [n.strip() for a in args.only for n in a.split(",") if n.strip()]
        if not only:
            h.refuse("--only names no program")
    build(pkg_dir, args.lang, twice=args.twice, only=only, src_ext=args.src_ext or None)


if __name__ == "__main__":
    main()
