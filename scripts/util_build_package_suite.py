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
    here either. Absent file = stdout alone and every source a unit, as every package before the file existed. And `argv<TAB>name-first` (R-328;
    the grader 2026-11-11): every NAME.argv is one line NAME<TAB>arg..., the program's own name first, as the deleted IPL runner read it; the
    program is handed the fields after its name, and a sidecar whose first field is another name is excluded by name. Any other key or
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
    out = {"argv": "", "stdin": "", "stderr": "", "units": "", "dialect": "", "oracle": "", "upstream": "", "compare": "", "unmarked_compile_args": "", "ipath": "", "not_shipped": "", "prebuild": "", "fatal": "", "bom": "", "generator": ""}
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
        elif f[0] == "units" and f[1] == "tap":
            out["units"] = "tap"
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
        elif f[0] == "lpath":
            if not (pkg_dir / f[1]).is_dir(): h.refuse(f"{cf}:{n}: lpath {f[1]!r} names no directory (the grader could not find the package's $include files there)")
        elif f[0] == "prebuild":
            out["prebuild"] = f[1].strip()
        elif f[0] == "not_shipped":
            for x in f[1].split():
                if not (pkg_dir / x).is_dir():
                    h.refuse(f"{cf}:{n}: not_shipped {x!r} names no directory beside the package")
            out["not_shipped"] = f[1].strip()
        elif f[0] == "unmarked_compile_args" and f[1].startswith("--dialect="):
            out["unmarked_compile_args"] = f[1].strip()
        elif f[0] == "argv" and f[1] == "name-first":
            out["argv"] = "name-first"   # R-328: NAME.argv is one line NAME<TAB>arg..., the program's own name first, as the deleted test_icon_ipl_suite.sh read it (ipl_argv_read)
        elif f[0] == "road" and f[1] == "run-files":
            pass   # the cycle's own key (s4e_cycle.sh road_flag): the package is run by the package switch; the builder cuts the same answers either way
        elif f[0] == "stdin":
            if not (pkg_dir / f[1]).is_file(): h.refuse(f"{cf}:{n}: stdin {f[1]!r} names no file beside the package (every entry with no stem-named stdin of its own would read it)")
            out["stdin"] = f[1].strip()
        else:
            h.refuse(f"{cf}:{n}: contract {f[0]!r}={f[1]!r} -- this builder admits stderr=merged, stdin=FILE, argv=name-first, units=ref-beside,units=plunit,units=tap, units=iso-rejection, dialect=any-fpc-mode, fatal=gradable, bom=as-shipped, units=generated, generator=MODULE, "
                     f"oracle=xsb-gentest, oracle=unicon, upstream=<absolute dir>, compare=ignore-all-space, ipath=DIR, lpath=DIR and unmarked_compile_args=--dialect=NAME only")
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


ISO_REFUSALS_HEADER = "# ISO_EXPECTED_REFUSALS.tsv -- written by util_build_package_suite.py under units iso-rejection (CIO-16): entry<TAB>what the refusal must name"


def iso_rejection_want(src):
    """What an ISO rejection test's refusal must name (CIO-16, officer_04 2026-11-09), read as the deleted test_pascal_pat_suite.sh prt_want read
    it: "line N1 N2 ..." -- the marked lines of the .ecp beside the source (the first field of each line that opens with a number then ****),
    sorted and unique; else "clause X1 X2 ..." -- every clause number after "ISO 7185 reference:" on the source's lines, in order, or, with no such
    line, on a line that is "ISO 7185" and clause numbers alone (officer_04 2026-11-12, row pat-red-iso7185prt1758b: iso7185prt1839 and 1840 head
    their comment "ISO 7185 6.9.3" with no "reference:" and a .ecp that marks nothing); else "" (nothing a refusal can be checked against). A
    missing .ecp counts as no marked lines."""
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
    if not clauses:
        for ln in read_text_tolerant(src)[0].splitlines():
            m = re.fullmatch(r"[ \t]*ISO 7185((?:[ \t,]+[0-9]+(?:\.[0-9]+)+)+)[ \t]*", ln)
            if m:
                clauses += re.findall(r"[0-9]+(?:\.[0-9]+)+", m.group(1))
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


FX_STAGED = set()   # the entries whose cut ran over their NAME.fixtures/ tree (h.stage_fixtures): their ALL.csv fixtures cell reads staged, so stage_entry stages the same tree to grade


def build(pkg_dir, lang, out_prefix="ALL", twice=False, only=None, src_ext=None, any_fpc_mode=False):
    _c0 = read_contract(pkg_dir)
    if _c0["units"] == "generated":
        return build_generated(pkg_dir, lang, out_prefix, _c0, only)
    ext = LANG_EXT[lang]
    paths = h.resolve_paths()
    h.check_scrip(paths)
    oracle_bin, flags = h.resolve_oracle_bin(paths, lang)
    print(f"oracle: {oracle_bin} {flags}", file=sys.stderr)
    contract = read_contract(pkg_dir)
    pas_cells = {}
    _cf = pkg_dir / f"{out_prefix}.csv"
    if lang == "pascal" and _cf.is_file():
        with open(_cf, newline="") as _fh:
            for _r in csv.DictReader(_fh):
                _c = (_r.get("dialect") or "").strip()
                if _c:
                    if _c not in ("iso", "fpc", "objfpc", "delphi", "tp"):
                        h.refuse(f"{_cf}: entry {_r.get('entry')} names dialect {_c!r}, which is none of iso, fpc, objfpc, delphi, tp")
                    pas_cells[_r["entry"]] = _c
    # ⭐ A PROLOG ROW'S DIALECT CELL NAMES THE ORACLE THAT CUTS ITS REF (the cfo 2026-11-13, accepted by the coo; skill prolog, "The oracle of an unmarked
    # program in a suite table"): the builder cut every ref of gate_cases_prolog from swipl, and eleven entries are cases whose retired gate expected gprolog's
    # answer, so their refs were the wrong oracle's. An entry whose dialect cell is gnu is cut from GNU Prolog 1.6.0 through gprolog_oracle_run.sh (twice under
    # --twice, as every row is) and graded with scrip --dialect=gnu, which the reader adds from the same cell; any other cell, or none, is swipl's as before.
    gnu_cells = set()
    if lang == "prolog" and _cf.is_file():
        with open(_cf, newline="") as _fh:
            for _r in csv.DictReader(_fh):
                if (_r.get("dialect") or "").strip() == "gnu":
                    gnu_cells.add(_r["entry"])
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
    tap = contract["units"] == "tap"
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
                excluded.append((name, f"a library graded through its driver {src.stem}_driver, which is the entry "
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
            if prog_args and contract["argv"] == "name-first":
                # ⭐ THE NAME-FIRST SIDECAR (R-328; CONTRACT.tsv argv=name-first; the grader 2026-11-11, row packages-ipl-the-83-...): the line is NAME<TAB>arg...,
                # so the program is handed the fields after its own name; measured on progs/lam: handed all three it read a file named lam and its
                # ref a1b1 a2 a3 was cut as nothing; handed lam.in1 lam.in2 it answers its ref byte for byte. A first field naming another program, or no
                # argument after the name, is a sidecar arming the wrong program or stating nothing: excluded by name, as the deleted reader refused it.
                if prog_args[0] != src.stem or len(prog_args) < 2:
                    excluded.append((name, f"{argv_path.name} is not NAME<TAB>arg... under argv=name-first (first field {prog_args[0]!r}, {len(prog_args) - 1} argument(s)) -- "
                                                "a sidecar arming the wrong program or stating nothing (R-328)"))
                    print(f"[{i}/{len(srcs)}] {name}: EXCLUDED (argv sidecar not name-first)", file=sys.stderr)
                    continue
                prog_args = prog_args[1:]
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
                if h.stage_fixtures(src.parent, src.stem, Path(_iso_dir)):   # NAME.fixtures/ staged where the oracle runs; the fixtures cell tells stage_entry to stage it to grade
                    FX_STAGED.add(name)
                _iso_src.write_bytes(src.read_bytes())
                if lang == "icon" and merged and contract["oracle"] == "unicon" and contract["prebuild"]:
                    _unicon_prebuild(Path(_iso_dir), contract["ipath"], contract["prebuild"].split())
                if lang == "icon" and merged and contract["oracle"] == "unicon":
                    return h.run_unicon_built_oracle(paths, _iso_src, paths["timeout"], stdin_text=stdin_text,
                                                                         prog_args=prog_args, out_files=out_files)
                elif lang == "icon" and merged:
                    return h.run_icon_built_oracle(paths, _iso_src, paths["timeout"], stdin_text=stdin_text,
                                                                         prog_args=prog_args, out_files=out_files)
                elif lang == "prolog" and name in gnu_cells:
                    return h.run_oracle("bash", str(h.HARNESS_SCRIPTS / "gprolog_oracle_run.sh"), _iso_src, paths["timeout"], stdin_text=stdin_text,
                                                              prog_args=prog_args, out_files=out_files, merge_stderr=_ms)
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
        _ladder = [flags, "", "-Mobjfpc", "-Mdelphi", "-Mtp"] if (lang == "pascal" and (contract["dialect"] == "any-fpc-mode" or any_fpc_mode)) else [flags]
        if lang == "pascal" and name in pas_cells:
            _ladder = [{"iso": flags, "fpc": "", "objfpc": "-Mobjfpc", "delphi": "-Mdelphi", "tp": "-Mtp"}[pas_cells[name]]]
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
        return splice(pkg_dir, lang, ext, out_prefix, entries, excluded, dialects, contract, merged, staged, all_srcs,
                      iso_rej_names=iso_rej_names if iso_rej else None)

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
        (pkg_dir / "ISO_EXPECTED_REFUSALS.tsv").write_text(ISO_REFUSALS_HEADER + "\n" + "".join(f"{n}\t{w}\n" for n, w in iso_rej_names))
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
    _se_col = ["stderr"] if merged or any(d.get("stderr") for d in _decl.values()) else []
    _fx_col = ["fixtures"] if FX_STAGED else []   # the entries cut over their NAME.fixtures/ tree, read by corpus_suite_harness.py stage_entry   # from CONTRACT.tsv (every entry), else the table's own per-entry declaration
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
    _gr_col = ["grader", "cwd"] if plunit else (["grader"] if tap else [])   # CIO-15 (c): swi-cases for every entry; cwd is the entry directory (. at the top)
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
    _dl_col = []
    _old_dl = {}
    if out_csv.exists():
        with open(out_csv, newline="") as _f:
            _rdr = csv.DictReader(_f)
            _cmd_cols = [c for c in _cmd_cols if c in (_rdr.fieldnames or [])]
            _gap_col = ["mode_gap_s"] if "mode_gap_s" in (_rdr.fieldnames or []) else []
            _dl_col = ["dialect"] if lang == "prolog" and "dialect" in (_rdr.fieldnames or []) else []
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
                if _dl_col and (_row.get("dialect") or "").strip():
                    _old_dl[_row.get("entry")] = _row["dialect"].strip()
    with open(out_csv, "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["rank", "entry", "origin", "package", "n_lines", "stdin", "want_rc", "heap_kb", "stack_kb"] + _tmo_col + _cmd_cols + _of_col + _se_col + _cm_col + _sg_col + _gr_col + _gap_col + _dl_col + _fx_col + [c for c, _fn in cols])
        for e in entries:
            joined = "\n".join(e.sno_lines)
            flags_row = m.attrs_for_text(joined, table_lang)
            w.writerow([e.seq, e.name, f"{pkg_dir.name}__{e.name}", pkg_dir.name, len(e.sno_lines),
                        1 if e.stdin else 0, e.want_rc, _old_heap.get(e.name, m.DEFAULT_HEAP_KB), _old_stack.get(e.name, m.DEFAULT_STACK_KB)] + [_decl.get(e.name, {}).get("timeout_s", "") for c in _tmo_col] + [_old_cmd.get(e.name, {}).get(c, "") or (contract["unmarked_compile_args"] if c == "compile_args" and contract["unmarked_compile_args"] and not icn_marked("\n".join(e.sno_lines)) else "") for c in _cmd_cols] + [" ".join(getattr(e, "out_files", None) or []) for c in _of_col] + [("merged" if getattr(e, "decl_stderr", merged) else "") for c in _se_col] + [_cm_val(e) for c in _cm_col] + ((["upstream", "" if staged[e.name] == "stdout" else staged[e.name]] if e.name in staged else ["", ""]) if _sg_col else []) + ((["swi-cases", e.name.rsplit("/", 1)[0] if "/" in e.name else "."] if plunit else ["tap-cases"]) if _gr_col else []) + [_old_gap.get(e.name, "") for c in _gap_col] + [_old_dl.get(e.name, "") for c in _dl_col] + [("staged" if e.name in FX_STAGED else "") for c in _fx_col] + [flags_row[c] for c, _fn in cols])
        _rank = max([e.seq for e in entries] or [0])
        for _row in sorted(_carried, key=lambda r: r.get("entry") or ""):
            _rank += 1
            w.writerow([_rank, _row.get("entry"), _row.get("origin") or f"{pkg_dir.name}__{_row.get('entry')}", _row.get("package") or pkg_dir.name,
                        _row.get("n_lines") or "", _row.get("stdin") or "0", _row.get("want_rc") or "0",
                        (_row.get("heap_kb") or "").strip() or m.DEFAULT_HEAP_KB, (_row.get("stack_kb") or "").strip() or m.DEFAULT_STACK_KB] + [(_row.get(c) or "").strip() for c in _tmo_col] + [(_row.get(c) or "").strip() for c in _cmd_cols]
                       + [(_row.get(c) or "").strip() for c in _of_col] + [(_row.get(c) or "").strip() for c in _se_col] + ["" for c in _cm_col] + ["" for c in _sg_col] + ["" for c in _gr_col] + [(_row.get(c) or "").strip() for c in _gap_col] + [(_row.get(c) or "").strip() for c in _dl_col] + [(_row.get(c) or "").strip() for c in _fx_col] + ["" for c, _fn in cols])
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


def splice(pkg_dir, lang, ext, out_prefix, entries, excluded, dialects, contract, merged, staged, all_srcs, iso_rej_names=None):
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
             "compare", "stage", "answer", "mode_gap_s", "timeout_s", "fixtures", "dialect"} | {c for c, _fn in cols}
    if set(hdr) - known or "entry" not in ix or "rank" not in ix:
        h.refuse(f"splice gate: {f_csv}'s header is not one the splice can fill: unknown {sorted(set(hdr) - known)}")
    for e in entries:
        for _col, _need in (("out_files", getattr(e, "out_files", None)), ("compare", _cm_val(e)), ("stderr", merged), ("stage", e.name in staged), ("fixtures", e.name in FX_STAGED)):
            if _need and _col not in ix:
                h.refuse(f"splice gate: {e.name} needs a {_col} cell and {f_csv} has no {_col} column -- a whole rebuild adds it")
    dialect_cell = {n: ("fpc" if d == "fpc-default" else d) for n, d in dialects} if "dialect" in ix else {}
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
             "stage": "upstream" if e.name in staged else "", "fixtures": "staged" if e.name in FX_STAGED else "", "dialect": dialect_cell.get(e.name, ""), "answer": ("" if staged[e.name] == "stdout" else staged[e.name]) if e.name in staged else ""}
        v.update({c: flags_row[c] for c, _fn in cols})
        if e.name in row_at:
            prev = rows[row_at[e.name]]
            v["rank"] = prev[ix["rank"]]
            for c in ("heap_kb", "stack_kb", "compile_args", "run_args", "mode_gap_s", "timeout_s") + (() if e.name in dialect_cell else ("dialect",)):
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
    _keyed(f"{out_prefix}.dialect", ["# the fpc mode that cut each entry's ref (CONTRACT.tsv dialect=any-fpc-mode): name<TAB>mode"], [f"{n}\t{d}" for n, d in dialects if n not in dialect_cell], names)
    _keyed(f"{out_prefix}.rc", [], [f"{e.name}\t{e.want_rc}" for e in entries if e.want_rc], names)
    _keyed(f"{out_prefix}.argv", [], [e.name + "\t" + "\t".join(e.argv) for e in entries if getattr(e, "argv", None)], names)
    if iso_rej_names is not None:
        # A RE-CUT PAT REJECTION TEST CARRIES ITS REFUSAL'S WANT (officer_04 2026-11-12, row pat-red-iso7185prt1758b; MEASURED: --only of four
        # programs out of ISO_ACCEPTS.tsv re-cut them with empty refs and left ISO_EXPECTED_REFUSALS.tsv without them, so each graded rc 1 against
        # want 0): the named entries' lines of the refusal file are rewritten from this census, as a whole build writes the file.
        _keyed("ISO_EXPECTED_REFUSALS.tsv", [ISO_REFUSALS_HEADER], [f"{n}\t{w}" for n, w in iso_rej_names], names)
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


def _same_but_trailing_newlines(a, b):
    return a.rstrip(b"\n") == b.rstrip(b"\n")


def build_files_form(pkg_dir, lang, twice=False, only=None, src_ext=None):
    """A PACKAGE IN THE FILES FORM IS REBUILT IN THE FILES FORM, SO A REBUILD NEVER BRINGS THE CONTAINER BACK (the coo 2026-11-10, row
    packages-form-the-package-builder-writes-a-converted-package-in-its-files-form; CIO-59, CIO-113, CIO-116, CIO-117; Lon 2026-11-10: a
    package keeps the layout of its distribution, NAME.in, NAME.out and NAME.err beside each program). build() and splice() stay the one
    cutter: the package is packed to its container for the length of the cut, cut exactly as a container package is, and unpacked again by
    the grader's own verb (unpack_dir, which writes through write_package_dir), all three in place and behind a whole copy that is put back on any refusal or error, so a failed build changes
    nothing. What the cut reads beside a program and the files form no longer keeps is written for the cut and removed after it: NAME.argv
    from ALL.args, and NAME.ref from NAME.out where the contract's units are ref-beside or plunit (the unit's marker, and plunit's answer).
    A stream file whose new bytes equal the old but for trailing newlines keeps the old bytes: they are the oracle's own (CIO-117), and the
    container cannot hold a last blank line. An entry with a NAME.err is refused: the container this cutter writes has no place for it."""
    import shutil
    ext = LANG_EXT[lang]
    src = pkg_dir / f"ALL{ext}"
    if h.pkg_dir_of(str(src)) is None:
        h.refuse(f"{pkg_dir} is not a package in the files form (its ALL.csv has no path column)")
    try:
        entries = h.read_package_dir(pkg_dir, ext)
    except ValueError as _e:
        h.refuse(f"files form: {pkg_dir} does not read: {_e}")
    _err = [e.name for e in entries if getattr(e, "stderr_answer", None)]
    if _err:
        h.refuse(f"files form: {len(_err)} entr(ies) carry a NAME.err, which the cut's container cannot hold: {_err[:5]}")
    _ct = read_contract(pkg_dir)
    units, _nf = _ct["units"], _ct["argv"] == "name-first"
    fields, rows = h._fmt2_read_csv(pkg_dir)
    path_of = {r.get("entry"): r.get("path") for r in rows if r.get("path")}
    _bak_root = Path(tempfile.mkdtemp(prefix="pkgsuite_files_", dir=os.environ.get("TMPDIR") or None))
    bak = _bak_root / pkg_dir.name
    shutil.copytree(pkg_dir, bak, symlinks=True)
    made = []
    try:
        for seq, e in enumerate(entries, 1):
            e.seq = seq
        wrote_in = h.write_suite(entries, str(src), str(pkg_dir / "ALL.ref"), out_in=str(pkg_dir / "ALL.in"), lang=lang)
        if not wrote_in and (pkg_dir / "ALL.in").exists():
            (pkg_dir / "ALL.in").unlink()
        _av = [e.name + "\t" + "\t".join(e.argv) for e in entries if getattr(e, "argv", None)]
        if _av:
            (pkg_dir / "ALL.argv").write_text("\n".join(_av) + "\n", encoding="utf-8")
        if (pkg_dir / "ALL.args").exists():
            (pkg_dir / "ALL.args").unlink()
        for e in entries:
            prog = pkg_dir / path_of[e.name]
            if getattr(e, "argv", None) and not prog.with_suffix(".argv").exists():
                prog.with_suffix(".argv").write_text((prog.stem + "\t" if _nf else "") + "\t".join(e.argv) + "\n", encoding="utf-8")   # argv=name-first: the form build() reads back
                made.append(prog.with_suffix(".argv"))
            if units in ("ref-beside", "plunit") and not prog.with_suffix(".ref").exists():
                _out = prog.with_suffix(".out")
                prog.with_suffix(".ref").write_bytes(_out.read_bytes() if _out.is_file() else b"")
                made.append(prog.with_suffix(".ref"))
            for _suf in (".out", ".err"):
                if prog.with_suffix(_suf).is_file():
                    prog.with_suffix(_suf).unlink()
        h._fmt2_write_csv(pkg_dir, [c for c in fields if c != "path"], [{k: v for k, v in r.items() if k != "path"} for r in rows])
        print(f"files form: {pkg_dir.name} packed to its container for the cut ({len(entries)} entries, {len(made)} sidecar(s) written for it)", file=sys.stderr)
        result = build(pkg_dir, lang, twice=twice, only=only, src_ext=src_ext)
        for _p in made:
            if _p.exists():
                _p.unlink()
        try:
            counts, n = h.unpack_dir(pkg_dir)
        except ValueError as _e:
            h.refuse(f"files form: the cut container of {pkg_dir.name} does not take the files form again: {_e}")
        kept = 0
        for _old in bak.rglob("*"):
            if _old.suffix in (".out", ".err") and _old.is_file():
                _new = pkg_dir / _old.relative_to(bak)
                if _new.is_file() and _new.read_bytes() != _old.read_bytes() and _same_but_trailing_newlines(_new.read_bytes(), _old.read_bytes()):
                    _new.write_bytes(_old.read_bytes())
                    kept += 1
        _left = [x for x in ("ALL" + ext, "ALL.ref", "ALL.in", "ALL.argv") if (pkg_dir / x).exists()]
        if _left or h.pkg_dir_of(str(src)) is None:
            h.refuse(f"files form: {pkg_dir.name} did not come back to the files form (container files left: {_left})")
        print(f"files form: {pkg_dir.name} is in the files form again: {n} entries, in={counts['in']} out={counts['out']} err={counts['err']} "
              f"args={counts['args']}; {kept} stream file(s) kept the oracle's own trailing bytes", file=sys.stderr)
        return result
    except BaseException:
        for _c in list(pkg_dir.iterdir()):
            if _c.is_dir() and not _c.is_symlink():
                shutil.rmtree(_c)
            else:
                _c.unlink()
        shutil.copytree(bak, pkg_dir, symlinks=True, dirs_exist_ok=True)
        print(f"files form: {pkg_dir.name} is put back as it stood; nothing is changed", file=sys.stderr)
        raise
    finally:
        shutil.rmtree(_bak_root, ignore_errors=True)


MINE_KEYS = ("root", "origin", "version", "licence")
MINE_OPTIONAL = {"copy": ("root", "folder"), "cwd": ("root", "folder")}
MINE_EXTS = {"raku": (".raku", ".p6", ".pl6", ".t", ".rakutest"), "pascal": (".pas", ".pp", ".p", ".lpr"), "icon": (".icn",), "prolog": (".pl", ".pro"),
             "snobol4": (".sno", ".spt", ".sbl")}
MINE_ORACLE = {"raku": "rakudo", "prolog": "swipl", "pascal": "fpc", "snobol4": "sbl", "icon": "unicon"}
# PASCAL (the coo 2026-11-11, COO-508): fpc only compiles, so a Pascal program is run by fpc_oracle_run.sh (compile to a private folder, then run; exit 126 =
# fpc refuses the source). The dialect is found by the census: the first mode of the ladder in which fpc compiles the program cut its answer and is
# the row's dialect cell (SCRIP's own names: iso, fpc, objfpc, delphi, tp); --mine-dialects names another ladder (fpc alone for Free Pascal's own
# tests, which state their mode in the source).
MINE_LADDER = {"pascal": (("iso", "-Miso"), ("fpc", ""), ("objfpc", "-Mobjfpc"), ("delphi", "-Mdelphi"), ("tp", "-Mtp")),
               "prolog": (("swi", ""), ("xsb", "--xsb"))}
# PROLOG BY XSB (the grader 2026-11-11, row mining-a-test-suite-from-xsb-examples; RULES.md: XSB is the third Prolog oracle, for XSB's own programs):
# --mine-dialects xsb reads the collection's .P files and asks xsb, through util_oracle.sh, to consult the program and halt
# (xsb --noprompt --quietload --nobanner -e "consult('NAME'), halt."), the form the fleet's XSB gates use; the row's dialect cell is xsb and its
# language cell prolog (.P is not Prolog's own extension, CTO-591), so SCRIP reads it as XSB. With no --mine-dialects the ladder's first rung, swi,
# answers as before: swipl -q NAME, .pl and .pro. MEASURED (xsb 5.0.0): a program consulted by xsb -e does not see standard input (get_char
# answers -1, read answers end_of_file, whatever it holds), so the third run never differs and no XSB program reads NEEDS-INPUT.
MINE_DIALECT_EXTS = {("prolog", "xsb"): (".P",)}
MINE_XSB_FLAGS = ("--noprompt", "--quietload", "--nobanner")
MINE_FOUND = {}
MINE_SCRATCH = {}
# A MINED PROGRAM RUNS IN A SCRUBBED ENVIRONMENT (the coo 2026-11-11, COO-513 (4); MEASURED: Free Pascal's test/units/dos/tenv.pp prints its
# environment, and its answer held all 73 variables of the seat that cut it, a credential among them; GitHub refused the push): the oracle gets
# only what the box's own wrappers need, a scratch HOME, the user nobody, and a canary. A program whose answer holds the canary or any value of
# that environment reads READS-THE-ENVIRONMENT and is no entry: its answer is a fact about the machine, not about the program.
MINE_CANARY = "s4e-mine-canary-5d41402abc4b2a76"
MINE_ENV_KEEP = ("PATH", "TMPDIR", "S4E_HOME", "S4E_SEAT", "XDG_RUNTIME_DIR", "DBUS_SESSION_BUS_ADDRESS")


def _mine_env(work):
    env = {k: os.environ[k] for k in MINE_ENV_KEEP if k in os.environ}
    (work / "home").mkdir(exist_ok=True)
    env.update(HOME=str(work / "home"), USER="nobody", LOGNAME="nobody", TERM="dumb", LANG="C.UTF-8", LC_ALL="C.UTF-8", S4E_MINE_CANARY=MINE_CANARY)
    return env


def _mine_env_leak(out, work_home=b""):
    """The name of an environment variable whose value stands in OUT, or None: the canary first, then every value of eight bytes or more."""
    if MINE_CANARY.encode() in out:
        return "the canary"
    for k in MINE_ENV_KEEP:
        v = os.environ.get(k, "").encode()
        if len(v) >= 8 and v in out:
            return k
    return "HOME" if (b"/mine_" in out and b"/home" in out) else None
MINE_FLAGS = {"prolog": ("-q",), "snobol4": ("-bf",)}   # the oracle's own flags before the program's name: swipl -q and sbl -bf, as corpus_suite_harness.py resolve_oracle_bin gives them
MINE_DIALECT = {"prolog": "swi", "icon": "unicon"}   # the dialect cell of a mined row: the oracle that cut its answer (run-switches step 4; swipl answers, so SCRIP reads the program as SWI)
# ICON, BY THE UNICON TRANSLATOR (the coo 2026-11-11, COO-516, for Unicon's uni tree; the grader MEASURED the same day that the fleet's icont refuses
# text without semicolons, so the Icon arm of --mine is Unicon's: its translator reads both languages as the collections ship them). A program is
# translated INSIDE the scratch copy of its own folder (unicon_oracle_run.sh --here), so a file it links from that folder is found; a row's dialect
# cell is unicon. A file with no procedure main is a LIBRARY (_mine_one, the one verdict a pattern cannot give: it is an absence).
MINE_STATIC = {
    "icon": (("NEEDS-DISPLAY", r"(?m)^\s*import\s+gui\b|^\s*link\s+[^#\n]*\b(graphics|vidgets|vsetup|wopen|dialog|gpxop|gui)\b|\$include\s+\"(guih|keysyms)\.icn\"|\b(WOpen|WAttrib|WindowContents)\s*\(|&window\b|\bopen\s*\([^()]*,\s*\"[a-z]*g[a-z]*l?\"|^\s*class\s+\w+\s*:\s*(Dialog|Component)\b"),
             ("NEEDS-NETWORK", r"\bopen\s*\([^()]*,\s*\"(n|na|nl|nu|nau|m|ms)\"|^\s*import\s+(net|http|mail)\b")),
    "pascal": (("LIBRARY", r"(?i)^\s*unit\s+\w+\s*;"),
               ("LIBRARY", r"(?i)\buses\b[^;]*\bfpmkunit\b"),
               ("NEEDS-INPUT", r"(?i)\{\s*%INTERACTIVE"),
               ("NEEDS-NETWORK", r"(?i)\buses\b[^;]*\b(sockets|ssockets|fphttpclient|netdb|httpdefs)\b"),
               ("NEEDS-DISPLAY", r"(?i)\buses\b[^;]*\b(crt|graph|video|keyboard|mouse|wincrt|ptcgraph|ptccrt|ncurses)\b"),
               # CLOCK-SEEDED (the senior 2026-11-12, MEASURED on dsa Recursion/Zadanie4: randomize then the max of 50 random(101); fpc printed Max 99, 98, 100, 97, 100 on five runs
               # a second apart): randomize seeds from the wall clock, so the answer is a function of the clock and no two runs owe each other the same text. Two runs that agree
               # prove nothing (a narrow draw agrees by chance), so the source names it: a statement-level randomize, a line that opens no comment and no string before it.
               ("CLOCK-SEEDED", r"(?im)^[^'{/\n]*\brandomize\b")),
    "raku": (("LIBRARY", r"^\s*unit\s+(module|class|role|grammar|package)\b"),
             ("NEEDS-NETWORK", r"\b(IO::Socket|LWP::|HTTP::|Cro::|Net::|WWW|WebService::|DBIish)\b"),
             ("NEEDS-DISPLAY", r"\b(Term::|Terminal::|NCurses|GTK::|SDL2?::|NativeCall|Inline::)")),
    "prolog": (("NEEDS-DISPLAY", r"\blibrary\(\s*(pce|xpce|pce_\w+|plot/\w+)\s*\)|\b(send|new)\(\s*@\w"),
               ("NEEDS-NETWORK", r"\blibrary\(\s*(socket|ssl|http/\w+|http_open|www_browser)\s*\)|\btcp_(connect|socket|bind|open_socket)\(|\burl\(\s*'?https?://"),
               # XSB (the grader 2026-11-11, MEASURED on XSB's examples: the six programs that printed anything at load ran gcc, and their answers held
               # the compiler's command lines and this machine's paths): a program that asks XSB for its C compiler, or imports from an XSB package
               # written in C (compiled by gcc when first loaded), answers about the machine's C toolchain, not about the program.
               ("NEEDS-C-COMPILER", r"\bxsb_configuration\(\s*compiler\s*,|\bimport\b[^.]*\bfrom\s+(sgml|xpath|curl|pcre|libwww)\s*\.")),
}
MINE_OWN_EXT = {"raku": (".raku",), "pascal": (".pas", ".p", ".pp", ".lpr"), "icon": (".icn",), "prolog": (".pl",), "snobol4": (".sno",)}
MINE_HEADER = ("rank", "entry", "path", "language", "origin", "package", "n_lines", "want_rc", "heap_kb", "stack_kb", "timeout_s", "compile_args", "dialect")


def mine_read_source(pkg_dir):
    """ALL.source of a package read in place (CIO-92, CTO-583): four lines of key, a tab, value. -> {key: value}, refusing a malformed file."""
    f = Path(pkg_dir) / "ALL.source"
    if not f.is_file():
        h.refuse(f"{pkg_dir} holds no ALL.source; --mine builds a package whose programs are read in place from the collection it names")
    got = {}
    for ln in f.read_text().splitlines():
        if not ln.strip():
            continue
        k, tab, v = ln.partition("\t")
        if not tab or (k not in MINE_KEYS and k not in MINE_OPTIONAL) or k in got or not v.strip() or (k in MINE_OPTIONAL and v.strip() not in MINE_OPTIONAL[k]):
            h.refuse(f"{f} is malformed at the line {ln!r}: its keys are root, origin, version and licence, each once, a tab, a value; "
                     f"copy and cwd may follow, each root or folder (CTO-591)")
        got[k] = v.strip()
    lost = [k for k in MINE_KEYS if k not in got]
    if lost:
        h.refuse(f"{f} is malformed: no line for {', '.join(lost)}")
    if not Path(got["root"]).is_dir():
        h.refuse(f"{f} names the root {got['root']}, which is no folder on this box")
    if got.get("cwd") == "root" and got.get("copy") != "root":
        h.refuse(f"{f}: cwd root needs copy root (CTO-591)")
    return got


def _mine_snap(top):
    return sorted((os.path.relpath(os.path.join(d, n), top), os.lstat(os.path.join(d, n)).st_size, os.lstat(os.path.join(d, n)).st_mtime_ns)
                  for d, ds, ns in os.walk(top) for n in ns + [x for x in ds if os.path.islink(os.path.join(d, x))])


def mine_read_launch(pkg_dir, lang, dialects):
    """THE ORACLE'S LAUNCH LINE OF A MINED PACKAGE (CIO-83; the grader 2026-11-11 on Lon's word of 09:50 CST: "Make drivers for library ones, and run the
    others. Let's get these GRADED."): ALL.launch at the package root, written by a person before the census, may hold `oracle<TAB>around<TAB>BEFORE<TAB>AFTER`
    (a cell `-` for none): the oracle then runs BEFORE, the program and AFTER as one load, the shim files OUR OWN, held in the package and never in the
    collection, exactly as the package switch runs `scrip around BEFORE AFTER` (run-switches step 14). A collection whose programs define and do not run
    (XSB's examples) gets its answers through a driver consulted after each program. -> (before path or None, after path or None), or None when the
    package has no oracle line. Refuses a malformed line, a shim the package does not hold, the driver form (a row that is a data file handed to one
    program: not built for --mine), and a language whose oracle takes one file."""
    f = pkg_dir / "ALL.launch"
    if not f.is_file():
        return None
    got = None
    for n, raw in enumerate(f.read_text().split("\n"), 1):
        if not raw.strip() or raw.startswith("#"):
            continue
        c = raw.split("\t")
        if c[0] != "oracle":
            continue
        if got is not None or len(c) != 4 or c[1] != "around":
            h.refuse(f"{f}:{n}: --mine reads one line oracle, a tab, around, a tab, BEFORE, a tab, AFTER (a cell - for none); read {raw[:80]!r}")
        shims = []
        for cell in c[2:]:
            if cell == "-":
                shims.append(None)
                continue
            q = (pkg_dir / cell)
            if cell.startswith("/") or ".." in cell.split("/") or not q.is_file():
                h.refuse(f"{f}:{n}: the shim {cell!r} is no file of the package")
            shims.append(q.resolve())
        if shims == [None, None]:
            h.refuse(f"{f}:{n}: an oracle line with neither a BEFORE nor an AFTER launches nothing")
        got = tuple(shims)
    if got is not None and not (lang == "prolog"):
        h.refuse(f"{f}: --mine launches a program around shim files for Prolog (swipl loads the files in order; xsb consults them in order); "
                 f"{lang or 'snobol4'} is not built")
    return got


def _mine_run(lang, folder, name, cap, stdin_bytes, flags=(), launch=None, args=()):
    """One oracle run of NAME in a scratch copy of FOLDER (subfolders included; the collection is never written to), from the top of that
    copy: the program's own folder and its bare name, or under copy root and cwd root the whole collection and the path from its root (CTO-591).
    The copy is made once per worker and folder and made again after any run that changed a file in it (CTO-583 (2)), so a run always starts
    in the collection's own state and a folder of two thousand programs is not copied six thousand times. -> (rc, out, err)."""
    import shutil
    import subprocess
    import threading
    key = (threading.get_ident(), str(folder))
    if key not in MINE_SCRATCH:
        work = Path(tempfile.mkdtemp(prefix="mine_", dir=os.environ.get("TMPDIR") or None))
        shutil.copytree(folder, work / "f", symlinks=True)
        MINE_SCRATCH[key] = (work, _mine_snap(work / "f"))
    work, snap = MINE_SCRATCH[key]
    files = [name]
    if launch:
        # the shims are OURS: each is copied beside the scratch copy, never into it, so what an oracle writes next to a file it loads (XSB's .xwam)
        # lands in scratch and the copy of the collection's folder stays the collection's own
        (work / "launch").mkdir(exist_ok=True)
        staged = []
        for q in launch:
            if q is not None:
                shutil.copyfile(q, work / "launch" / q.name)
            staged.append(None if q is None else str(work / "launch" / q.name))
        files = [x for x in (staged[0], name, staged[1]) if x is not None]
    try:
        sin = work / "stdin"
        sin.write_bytes(stdin_bytes)
        if lang == "pascal":
            argv = ["bash", os.path.join(HERE, "util_run_slot.sh"), "timeout", "-k", "5", str(cap), "bash", os.path.join(HERE, "fpc_oracle_run.sh"), *flags, name]
            with open(sin, "rb") as fin:
                pr = subprocess.run(argv, cwd=str(work / "f"), stdin=fin, capture_output=True, env=_mine_env(work))
        elif lang == "icon":
            argv = ["bash", os.path.join(HERE, "util_run_slot.sh"), "timeout", "-k", "5", str(cap), "bash", os.path.join(HERE, "unicon_oracle_run.sh"), "--here", name]
            with open(sin, "rb") as fin:
                pr = subprocess.run(argv, cwd=str(work / "f"), stdin=fin, capture_output=True, env=_mine_env(work))
        elif lang == "prolog" and "--xsb" in flags:
            if args:
                h.refuse(f"{name}: ALL.args names arguments, and XSB's road runs one -e goal that passes none")
            goal = ", ".join("consult('" + str(x).replace("\\", "\\\\").replace("'", "\\'") + "')" for x in files) + ", halt."
            argv = ["bash", os.path.join(HERE, "util_oracle.sh"), "xsb", "--stdin", str(sin), "--timeout", str(cap), "--no-cache", "--", *MINE_XSB_FLAGS, "-e", goal]
            pr = subprocess.run(argv, cwd=str(work / "f"), stdin=subprocess.DEVNULL, capture_output=True, env=_mine_env(work))
        else:
            argv = ["bash", os.path.join(HERE, "util_oracle.sh"), MINE_ORACLE[lang], "--stdin", str(sin), "--timeout", str(cap), "--no-cache", "--", *MINE_FLAGS.get(lang, ()), *flags, *files, *args]
            pr = subprocess.run(argv, cwd=str(work / "f"), stdin=subprocess.DEVNULL, capture_output=True, env=_mine_env(work))
        here = (str(work / "f") + "/").encode()
        there = (str(work / "launch") + "/").encode()
        return pr.returncode, pr.stdout.replace(there, b""), pr.stderr.replace(here, b"").replace(there, b"")
    finally:
        if _mine_snap(work / "f") != snap:
            shutil.rmtree(work, ignore_errors=True)
            del MINE_SCRATCH[key]


def _mine_scratch_drop():
    import shutil
    for work, snap in list(MINE_SCRATCH.values()):
        shutil.rmtree(work, ignore_errors=True)
    MINE_SCRATCH.clear()


def _mine_one(lang, root, rel, cap, whole=False, ladder=None, feed=None, launch=None, args=None):
    """The census verdict of one program (the mining rows' classes). -> (verdict, note, rc, stdout bytes). FEED is (what it is, its bytes) when the
    package names the program's standard input (ALL.stdin, a file of the collection by its path; or our own NAME.in in the package): both runs are
    fed it, and the third run, which asks whether the answer changes with standard input, is not made."""
    fed = feed[1] if feed else b""
    args = tuple(args or ())
    if args and lang in ("pascal", "icon"):
        h.refuse(f"{rel}: ALL.args names arguments, which the mine road passes on the generic oracle road only, after the program and any launch shim (not {lang}'s own road)")
    src = root / rel
    at, name = (root, rel) if whole else (src.parent, src.name)
    text = src.read_text(errors="replace")
    if lang == "icon" and not re.search(r"^\s*procedure\s+main\s*\(", text, re.M):
        return "LIBRARY", "no procedure main", None, b""
    for verdict, pat in MINE_STATIC.get(lang, ()):
        mt = re.search(pat, text, re.M)
        if mt:
            return verdict, f"the source names {' '.join(mt.group(0).split())[:80]}", None, b""
    flags = ()
    for dialect, flag in (ladder or MINE_LADDER.get(lang) or (("", ""),)):
        flags = (flag,) if flag else ()
        rc1, out1, err1 = _mine_run(lang, at, name, cap, fed, flags, launch, args)
        t1 = time.time()
        if not (lang == "pascal" and rc1 == 126):
            if dialect:
                MINE_FOUND[rel] = dialect
            break
    first = (err1.decode("utf-8", "replace").strip().splitlines() or [""])[0][:160]
    if lang == "pascal" and rc1 == 126:
        why = next((ln for ln in err1.decode("utf-8", "replace").splitlines() if re.search(r"\b(Fatal|Error):", ln)), first)
        return "ORACLE-REFUSES", f"fpc compiles it in no mode of the ladder; the last says: {why.strip()[:140]}", None, b""
    if lang == "icon" and rc1 == 126:
        why = next((ln for ln in err1.decode("utf-8", "replace").splitlines() if ln.strip() and not ln.startswith("Parsing ")), first)
        return "ORACLE-REFUSES", f"unicon does not translate it: {why.strip()[:140]}", None, b""
    if rc1 in (124, 137):
        return "DOES-NOT-END", f"no answer inside {cap} s", None, b""
    leak = _mine_env_leak(out1)
    if leak:
        return "READS-THE-ENVIRONMENT", f"its answer holds {leak} of the process that runs it", None, b""
    if rc1 == 2 and first.startswith("REFUSE(2)"):
        h.refuse(f"the oracle wrapper refused on {rel}: {first}")
    if lang == "raku" and b"===SORRY!===" in err1:
        return "ORACLE-REFUSES", (err1.decode("utf-8", "replace").replace("===SORRY!===", "").strip().splitlines() or [""])[0][:160], None, b""
    if lang == "snobol4" and sbl_died(out1.decode("utf-8", "replace")):
        why = next((ln for ln in out1.decode("utf-8", "replace").splitlines() if _SBL_DIED_RE1.search(ln)), "")
        return "ORACLE-REFUSES", f"SPITBOL ends it with an error: {why.strip()[:140]}", None, b""
    if lang == "raku" and rc1 == 2 and first.startswith("Usage:"):
        return "NEEDS-INPUT", "it asks for arguments (rakudo prints its usage, exit 2)", None, b""
    time.sleep(max(0.0, math.floor(t1) + 1.05 - time.time()))
    rc2, out2, err2 = _mine_run(lang, at, name, cap, fed, flags, launch, args)
    if (rc2, out2) != (rc1, out1):
        return "DIFFERS-BETWEEN-RUNS", f"exit {rc1} and {rc2}, {len(out1)} and {len(out2)} bytes", None, b""
    if not feed:
        rc3, out3, err3 = _mine_run(lang, at, name, cap, b"1\n2\n3\n", flags, launch, args)
        if (rc3, out3) != (rc1, out1):
            return "NEEDS-INPUT", "its answer changes with what standard input holds", None, b""
    if not out1.strip():
        return "NO-OUTPUT", f"nothing on standard output, exit {rc1}; a dead engine would earn the same" + (f"; stderr: {first}" if first else ""), None, b""
    return "ENTRY", "; ".join(x for x in ((f"standard input is {feed[0]}" if feed else ""), (f"stderr not graded: {first}" if first else "")) if x), rc1, out1


def _mine_args(pkg_dir, root, stems, under):
    """THE ARGUMENTS THE PACKAGE NAMES FOR A PROGRAM (the cfo 2026-11-12, row packages-owed-raku-examples-thirty-one: wsg/advanced-2008/event010-dwhipp
    answers the same twice only under --computer-player, which deals a fixed hand). ALL.args at the package root, the form the grader reads
    (corpus_suite_harness.py _pkg_read_args): one line an entry, the entry's name (its path from the collection's root without the extension), then
    each argument after a tab; written by a person, never by the census, so a rebuild keeps it. Both runs and the stdin probe pass them after the
    program. -> {program's path from the root: [argument, ...]}. Refuses a malformed line, an entry named twice, and a name that is no program the
    census reads (under --mine-under a line for another folder is left alone)."""
    out = {}
    f = pkg_dir / "ALL.args"
    for n, raw in enumerate(f.read_text().split("\n") if f.is_file() else (), 1):
        if not raw.strip() or raw.startswith("#"):
            continue
        c = raw.split("\t")
        if len(c) < 2 or not all(c[1:]):
            h.refuse(f"{f}:{n}: a line of ALL.args is an entry and then each argument after a tab; read {raw[:80]!r}")
        if c[0] not in stems:
            if under and not c[0].startswith(under.rstrip("/") + "/"):
                continue
            h.refuse(f"{f}:{n}: {c[0]!r} is no program the census reads under {root} (an entry's name is its path from the root without the extension)")
        if stems[c[0]] in out:
            h.refuse(f"{f}:{n}: {c[0]!r} is named twice")
        out[stems[c[0]]] = c[1:]
    return out


def _mine_feeds(pkg_dir, root, stems, under):
    """THE STANDARD INPUT THE PACKAGE NAMES FOR A PROGRAM (COO-514 (3), the grader 2026-11-11; CIO-92 step 2: "a NEEDS-INPUT program becomes an
    entry when its input is a file of the collection, named ... as a copy only when the licence class is A, and by path otherwise"). Two homes,
    both written by a person before the census and never by it: ALL.stdin at the package root, one line an entry, a tab, the path from the
    collection's root of the file it is fed (read where it stands, never copied); and our own NAME.in in the package at the program's relative
    path (an input we wrote, or a copy the licence allows). -> {program's path from the root: (what feeds it, its bytes)}. Refuses a malformed
    line, an entry named twice, a path that leaves the root or names no file, a program with both homes, and a name that is no program the
    census reads (under --mine-under a line for another folder is left alone)."""
    feeds = {}
    f = pkg_dir / "ALL.stdin"
    for n, raw in enumerate(f.read_text().split("\n") if f.is_file() else (), 1):
        if not raw.strip() or raw.startswith("#"):
            continue
        c = raw.split("\t")
        if len(c) != 2 or not c[1]:
            h.refuse(f"{f}:{n}: a line of ALL.stdin is an entry, one tab and a path from the collection's root; read {raw[:80]!r}")
        if c[0] not in stems:
            if under and not c[0].startswith(under.rstrip("/") + "/"):
                continue
            h.refuse(f"{f}:{n}: {c[0]!r} is no program the census reads under {root} (an entry's name is its path from the root without the extension)")
        if stems[c[0]] in feeds:
            h.refuse(f"{f}:{n}: {c[0]!r} is named twice")
        if c[1].startswith("/") or ".." in c[1].split("/") or not (root / c[1]).is_file():
            h.refuse(f"{f}:{n}: {c[0]} is fed {c[1]!r}, which is no file under the root {root}")
        feeds[stems[c[0]]] = (f"the collection's {c[1]}", (root / c[1]).read_bytes())
    for stem, rel in stems.items():
        own = pkg_dir / (stem + ".in")
        if own.is_file():
            if rel in feeds:
                h.refuse(f"{pkg_dir.name}: {stem} has both a NAME.in in the package and a line of ALL.stdin")
            feeds[rel] = (f"the package's own {stem}.in", own.read_bytes())
    return feeds


def mine(pkg_dir, lang, census_path, cap=60, jobs=4, under=None, skip=None, dialects=None, add=False):
    """A PACKAGE WHOSE PROGRAMS ARE READ IN PLACE (CIO-92, CIO-96, COO-508): the census of the collection ALL.source names, one verdict a program,
    then the index of the ENTRY programs (path = the path from the root) and each one's NAME.out and exit status, cut from the oracle, at the
    same relative path in the package folder. No program file is written into the package."""
    from concurrent.futures import ThreadPoolExecutor
    if lang not in MINE_ORACLE:
        h.refuse(f"--mine knows the oracle of {', '.join(sorted(MINE_ORACLE))}; {lang or 'snobol4'} is not one yet")
    source = mine_read_source(pkg_dir)
    root = Path(source["root"]).resolve()
    if (source.get("copy") == "root") != (source.get("cwd") == "root"):
        h.refuse(f"{pkg_dir}/ALL.source: --mine runs a program from the top of the copied collection (copy root with cwd root) or inside the copy of "
                 f"its own folder (neither key); copy {source.get('copy', 'folder')} with cwd {source.get('cwd', 'folder')} is neither")
    whole = source.get("cwd") == "root"
    exts = MINE_DIALECT_EXTS.get((lang, dialects[0]), MINE_EXTS[lang]) if dialects and len(dialects) == 1 else MINE_EXTS[lang]
    rels = sorted(p.relative_to(root).as_posix() for e in exts for p in root.rglob(f"*{e}")
                  if p.is_file() and not any(part.startswith(".") for part in p.relative_to(root).parts))
    # ONE PROGRAM ALONE (the cfo 2026-11-12, packages-owed-prolog-raku-cfo: a folder re-cut on trealla_more's samples re-entered test_sockets on
    # its pre-socket line and dropped db-stress's goal, so three rows were spliced from a scratch mine): --mine-under names a folder or one
    # program of the root, and under --mine-add only what it names is cut again.
    one = under.strip("/") if under and (root / under.strip("/")).is_file() else None
    if one:
        rels = [r for r in rels if r == one]
    elif under:
        rels = [r for r in rels if r.startswith(under.rstrip("/") + "/")]
    if not rels:
        h.refuse(f"no {' '.join(exts)} program {'named ' + one if one else 'under ' + str(root / under) if under else 'under ' + str(root)}")
    held = {}
    if skip:
        for ln in Path(skip).read_text().splitlines():
            k, tab, why = ln.partition("\t")
            if not ln.strip() or ln.startswith("#"):
                continue
            if not tab or not why.strip() or k not in rels:
                h.refuse(f"{skip} is malformed at the line {ln!r}: a line is a program's path from the root (one --mine would census), a tab, and where it is graded already")
            held[k] = why.strip()
        rels = [r for r in rels if r not in held]
        if not rels:
            h.refuse(f"{skip} names every program under {root}: nothing is left to census")
    # TWO PROGRAMS OF ONE STEM (Free Pascal's tbs: tb0571.pp beside tb0571.pas) would share one NAME.out: the one whose extension the language
    # lists first is the candidate, the other reads SHARES-A-STEM in the census and is not run; it is not named in ALL.omit, where a name whose
    # extension-less form is an entry would drop that entry.
    stems, twin = {}, {}
    for r in sorted(rels, key=lambda r: (exts.index(os.path.splitext(r)[1]) if os.path.splitext(r)[1] in exts else 99, r)):
        if os.path.splitext(r)[0] in stems:
            twin[r] = stems[os.path.splitext(r)[0]]
        else:
            stems[os.path.splitext(r)[0]] = r
    rels = [r for r in rels if r not in twin]
    ladder = None
    if dialects:
        known = dict(MINE_LADDER.get(lang) or ())
        if not known or any(d not in known for d in dialects):
            h.refuse(f"--mine-dialects {','.join(dialects)}: the ladder of {lang or 'snobol4'} is {', '.join(known) or 'empty'}")
        ladder = tuple((d, known[d]) for d in dialects)
    feeds = _mine_feeds(pkg_dir, root, {k: v for k, v in stems.items() if v in rels}, under)
    margs = _mine_args(pkg_dir, root, {k: v for k, v in stems.items() if v in rels}, under)
    launch = mine_read_launch(pkg_dir, lang, dialects)
    try:
        with ThreadPoolExecutor(max_workers=jobs) as ex:
            got = list(ex.map(lambda r: _mine_one(lang, root, r, cap, whole, ladder, feeds.get(r), launch, margs.get(r)), rels))
    finally:
        _mine_scratch_drop()
    unfed = [f"{r} ({feeds[r][0] if r in feeds else 'ALL.args ' + ' '.join(margs[r])}): {v}: {note}" for r, (v, note, rc, out) in zip(rels, got) if (r in feeds or r in margs) and v != "ENTRY"]
    if unfed:
        h.refuse(f"{pkg_dir.name}: the package names a standard input for {len(unfed)} program(s) the oracle does not answer with it, and nothing is "
                 f"written: {'; '.join(unfed)[:600]}. Correct the input, or take its line out of ALL.stdin (or its NAME.in out of the package) and "
                 f"the census gives the program its verdict without it")
    # ONE FOLDER MORE (--mine-add with --mine-under, the coo 2026-11-11: Free Pascal's tree is cut one folder a landing): the rows, the answers,
    # the ALL.rc and ALL.omit lines and the census lines of every OTHER folder stand as they are; only what is under FOLDER is cut again.
    pre = (under.rstrip("/") + "/") if (add and under) else None

    def cut_again(k):
        return k in (one, os.path.splitext(one)[0]) if one else k.startswith(pre)
    census = Path(census_path)
    census.parent.mkdir(parents=True, exist_ok=True)
    kept_census = [ln + "\n" for ln in census.read_text().splitlines() if ln.strip() and not ln.startswith("#") and not cut_again(ln.split("\t", 1)[0])] if (pre and census.is_file()) else []
    # WHAT A PERSON WROTE IN ALL.csv STANDS (the cfo 2026-11-12: a folder re-cut set timeout_s to the cap on 87 entries; roast's 1464 compare
    # cells were one mine away from the same loss): a row cut again keeps its heap_kb, stack_kb, timeout_s, compile_args and every column the
    # census does not write; the census writes the rest.
    old_cols, old_rows = h._fmt2_read_csv(pkg_dir) if (pkg_dir / "ALL.csv").is_file() else ([], [])
    old_by_path = {x.get("path"): x for x in old_rows if x.get("path")}
    extra = [c for c in old_cols if c not in MINE_HEADER]
    kept_rows = []
    if pre:
        kept_rows = [x for x in old_rows if not cut_again(x.get("path") or "")]
        for old in (pkg_dir / pre).rglob("*.out") if (not one and (pkg_dir / pre).is_dir()) else ():
            old.unlink()
    census.write_text(f"# the census of {root} by {'xsb' if (lang == 'prolog' and dialects == ['xsb']) else MINE_ORACLE[lang]} ({source['version']}), {time.strftime('%Y-%m-%d')}: path from the root, verdict, note\n"
                      + "".join(kept_census) + "".join(f"{r}\t{v}\t{note}\n" for r, (v, note, rc, out) in zip(rels, got)))
    rows, rcs = [], []
    # A PROGRAM THAT IS NO ENTRY ANY MORE KEEPS NO ANSWER (the grader 2026-11-11, MEASURED on xsb_examples: six programs read ENTRY, the builder
    # gained the class that names them, and the second census left their six NAME.out in the package): the answer of every program this census
    # read is removed before the entries' answers are written. Under --mine-add the folder's answers went above; another folder's stand.
    for r in rels:
        (pkg_dir / (os.path.splitext(r)[0] + ".out")).unlink(missing_ok=True)
    for r, (v, note, rc, out) in zip(rels, got):
        if v != "ENTRY":
            continue
        name = os.path.splitext(r)[0]
        ans = pkg_dir / (name + ".out")
        ans.parent.mkdir(parents=True, exist_ok=True)
        ans.write_bytes(out)
        if rc:
            rcs.append(f"{name}\t{rc}\n")
        rows.append({"rank": len(rows) + 1, "entry": name, "path": r, "language": "" if r.endswith(MINE_OWN_EXT[lang]) else lang, "origin": f"{pkg_dir.name}__{name}", "package": pkg_dir.name,
                     "n_lines": len((root / r).read_text(errors="replace").splitlines()), "want_rc": rc, "heap_kb": 131072, "stack_kb": 4096,
                     "timeout_s": cap, "compile_args": ""})
        was = old_by_path.get(r) or {}
        rows[-1].update({c: was[c] for c in ("heap_kb", "stack_kb", "timeout_s", "compile_args", *extra) if (was.get(c) or "") != ""})
    if twin:
        with open(census, "a") as f:
            f.write("".join(f"{r}\tSHARES-A-STEM\tits answer would be the NAME.out of {twin[r]}, which is the candidate\n" for r in sorted(twin)))
    if held:
        with open(census, "a") as f:
            f.write("".join(f"{r}\tHELD-ELSEWHERE\t{held[r]}\n" for r in sorted(held)))
        print(f"MINE_HELD package={pkg_dir.name} held_elsewhere={len(held)} (in the census, not run, no entry, not in ALL.omit)")
    for x in rows:
        x["dialect"] = MINE_FOUND.get(x["path"]) or MINE_DIALECT.get(lang, "")
    if pre:
        rows = sorted(kept_rows + rows, key=lambda x: x["path"])
        for i, x in enumerate(rows):
            x["rank"] = i + 1
        rcs = [ln + "\n" for ln in ((pkg_dir / "ALL.rc").read_text().splitlines() if (pkg_dir / "ALL.rc").is_file() else []) if ln.strip() and not cut_again(ln.split("\t", 1)[0])] + rcs
    for x in rows:
        for c in (*MINE_HEADER, *extra):
            x.setdefault(c, "")
    cols = [c for c in MINE_HEADER if c not in ("language", "dialect") or any(x[c] for x in rows)] + [c for c in extra if any(x[c] for x in rows)]
    h._fmt2_write_csv(pkg_dir, cols, [{k: x[k] for k in cols} for x in rows])
    if rcs:
        (pkg_dir / "ALL.rc").write_text("".join(rcs))
    else:
        (pkg_dir / "ALL.rc").unlink(missing_ok=True)
    left = [f"{r}: {v}: {note}\n" for r, (v, note, rc, out) in zip(rels, got) if v != "ENTRY"]
    if pre and (pkg_dir / "ALL.omit").is_file():
        left = [ln + "\n" for ln in (pkg_dir / "ALL.omit").read_text().splitlines() if ln.strip() and not cut_again(ln.split(": ", 1)[0])] + left
    if left:
        (pkg_dir / "ALL.omit").write_text("".join(left))
    else:
        (pkg_dir / "ALL.omit").unlink(missing_ok=True)
    tally = {}
    for v, note, rc, out in got:
        tally[v] = tally.get(v, 0) + 1
    print(f"MINE package={pkg_dir.name} root={root} programs={len(rels)} entries={len(rows) - len(kept_rows)}" + (f" kept={len(kept_rows)}" if pre else "") + " " + " ".join(f"{k}={tally[k]}" for k in sorted(tally)))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("package_dir")
    ap.add_argument("--lang", default="", choices=sorted(set(LANG_EXT) - {""}),
                     help="default snobol4 (blank); selects extension + attribute table + oracle")
    ap.add_argument("--twice", action="store_true",
                    help="run the oracle twice per program and exclude one whose two answers differ (time, randomness, addresses)")
    ap.add_argument("--only", action="append", default=None, metavar="NAME[,NAME...]",
                    help="cut only these programs and splice them into the existing container, every other entry byte-identical (repeatable)")
    ap.add_argument("--any-fpc-mode", action="store_true",
                    help="pascal: a program fpc refuses under -Miso is cut again in fpc's default mode, then objfpc, delphi and tp, the first that compiles; with --only the mode lands in the entry's dialect cell of ALL.csv")
    ap.add_argument("--src-ext", default="", metavar=".EXT",
                    help="the extension the package's source programs carry, when it is not the lang's container extension "
                         "(SPITBOL's own suite ships .sbl; the container is still ALL.sno for snobol4)")
    ap.add_argument("--mine", default="", metavar="CENSUS.tsv",
                    help="the package holds ALL.source: take the census of the collection it names into CENSUS.tsv and write the index and the "
                         "answers of the programs the oracle answers the same twice; no program is copied into the package. A program whose standard input "
                         "the package names (a line of ALL.stdin: entry, tab, a file of the collection by its path from the root; or our own NAME.in "
                         "at the program's path) is fed it on both runs")
    ap.add_argument("--mine-cap", type=int, default=60, help="seconds the oracle has for one program under --mine (default 60)")
    ap.add_argument("--mine-jobs", type=int, default=4, help="oracle runs side by side under --mine (default 4, a seat's share of the run pool)")
    ap.add_argument("--mine-under", default="", metavar="FOLDER|PROGRAM", help="under --mine, only the programs under this folder of the root, or this one program (its path from the root)")
    ap.add_argument("--mine-add", action="store_true",
                    help="with --mine-under FOLDER|PROGRAM: cut what it names alone and keep the rows, answers and census lines of everything else")
    ap.add_argument("--mine-dialects", default="", metavar="NAME[,NAME...]",
                    help="under --mine, the dialect ladder to try in order (Pascal: iso, fpc, objfpc, delphi, tp; default all five, iso first. "
                         "Prolog: swi, the default, reads .pl and .pro by swipl; xsb alone reads .P by xsb)")
    ap.add_argument("--mine-skip", default="", metavar="FILE",
                    help="under --mine, programs another package grades already: a line is the path from the root, a tab, and where it is graded; "
                         "each reads HELD-ELSEWHERE in the census, is not run and is no entry")
    args = ap.parse_args()
    pkg_dir = Path(args.package_dir).resolve()
    if not pkg_dir.is_dir():
        h.refuse(f"not a directory: {pkg_dir}")
    if args.mine and args.mine_add and not args.mine_under:
        h.refuse("--mine-add adds one folder to a mined package: it needs --mine-under FOLDER")
    if args.mine:
        sys.exit(mine(pkg_dir, args.lang, args.mine, cap=args.mine_cap, jobs=args.mine_jobs, under=args.mine_under or None, skip=args.mine_skip or None,
                      dialects=[d.strip() for d in args.mine_dialects.split(",") if d.strip()] or None, add=args.mine_add))
    only = None
    if args.only is not None:
        only = [n.strip() for a in args.only for n in a.split(",") if n.strip()]
        if not only:
            h.refuse("--only names no program")
    if h.pkg_dir_of(str(pkg_dir / f"ALL{LANG_EXT[args.lang]}")) is not None:
        build_files_form(pkg_dir, args.lang, twice=args.twice, only=only, src_ext=args.src_ext or None)
        return
    build(pkg_dir, args.lang, twice=args.twice, only=only, src_ext=args.src_ext or None, any_fpc_mode=args.any_fpc_mode)


if __name__ == "__main__":
    main()
