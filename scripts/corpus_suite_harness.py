#!/usr/bin/env python3
"""corpus_suite_harness.py -- the ONE Python 3 (stdlib-only) harness for corpus-suites-consolidation.

Converts a family directory of loose NNN_name.sno + NNN_name.ref pairs into two parallel suite
text files (family.sno / family.ref) and can run/validate either the loose files or the suite
files, keeping a PASS/FAIL/CRASH/HANG/UNPROVEN/SKIP verdict ladder distinct throughout (the
CRASH-collapsed-into-DIVERGE lesson from SCRIP 5ad95ab1 -- see
.github/FINDING-2026-08-24-hq_P-icon-bench-0-of-8-is-one-defect-suspend-procedures-get-no-activation-frame.md).

⛔⭐ A SUITE FILE IS NEVER RUN WHOLE. IT IS NOT A PROGRAM -- IT IS A CONTAINER OF PROGRAMS.
Every entry is extracted and run ALONE, in its own fresh temp dir, by run_suite_entry(). Under format
(B) each block is an independently complete program carrying its OWN `END` statement, and entries
freely reuse label names (`e001`, `e002`, ...) because they never share a namespace. So compiling
`family.sno` directly -- `./scrip family.sno`, or `sbl -bf family.sno` -- is a CATEGORY ERROR, and it
fails in two ways that look exactly like real defects:
    * scrip  -> a pile of "duplicate label" parse errors (entries' labels collide)
    * sbl -bf -> runs the FIRST entry only, then stops at its embedded `END`, so a 34-line .ref
                 appears to "mismatch" a 1-line oracle result
⛔ BOTH ARE ARTIFACTS OF THE WRONG INVOCATION, NOT FINDINGS. Measured 2026-08-27 (hq_C): I read
exactly those two symptoms as a broken consolidation and escalated it as a live coverage regression,
telling the seat converting the family to stop work. It cost them a session interruption and cost me
two false reports. ⭐ THE CHECK THAT WOULD HAVE CAUGHT ME IN ONE COMMAND is the one that seat08 ran
and I did not -- A CONTROL ARM: run the SAME whole-file compile on `patterns.sno`, the pilot family
that has been green for days. It produces the IDENTICAL failure shape. A symptom that reproduces on
a known-good sibling is a property of the format, never a defect in the file under suspicion.
To grade a suite for real, use the mechanism the board uses:
    python3 ../harness/scripts/corpus_suite_harness.py run <family>.sno <family>.ref --modes m3,m4

Format spec: .github postoffice task corpus-suites-consolidation.task.md.
  (A) ONE-LINE entry:  "<stmt1>;<stmt2>;...;* <name>"            family.sno line N
                        "<expected, \\n-escaped if multi-line>"    family.ref line N
  (B) MULTI-LINE (banner) entry, used when a join exceeds 200 chars or changes behaviour, OR when the
      original source carries column-1 '*' comments (SNOBOL4 has no inline-comment syntax, so a
      comment cannot survive a one-line join -- see has_comment_lines()), OR when the original was
      already non-green at conversion time (an XFAIL witness -- see below):
                        "*----...---- <seq> <name>[ XFAIL]"  (banner, 80 chars, SNOBOL4 comment syntax)
                        <original statement lines, verbatim, one per physical line>
                        (block runs until the next banner or EOF)
                        Same banner + expected output VERBATIM (no escaping) in family.ref.
      A comment/blank-preserving block uses the ORIGINAL file's lines verbatim (not the
      statement-reconstructed form multiline_block() produces for the plain length/behaviour
      fallback) -- simpler and lossless, with no dependence on the goto-merge heuristic.

⭐ XFAIL/XPASS (added corpus-crosscheck-probe-total-conversion, probe-consolidate-passthru): a
family may contain witnesses that are DELIBERATELY red at conversion time -- an active correctness
campaign's documented, known-bad state (e.g. probe/passthru's ARCH-PASSTHRU.md witnesses, "a red row
is never denied"). Lon's 2026-08-28 total-conversion ruling forbids leaving these as permanent loose-
file exceptions, but converting one must not silently inflate a caller's FAIL count. convert_one()
never refuses a non-green original; it marks the resulting block Entry `xfail=True` (banner carries
a trailing " XFAIL") and byte-equal-or-no-delete still requires the candidate to reproduce the
ORIGINAL's exact verdict, whatever it is. `run`/cmd_run then buckets an XFAIL entry's non-PASS
verdict as XFAIL (not FAIL) and a surprising PASS as XPASS (not PASS) in the SUITE_BOARD line's
<mode>_xfail/<mode>_xpass fields -- a caller that only reads <mode>_fail/<mode>_pass (like
test_corpus_snobol4.sh's probe/ auto-discovery loop) is unaffected by a witness it was never told
to expect green. XPASS is surfaced exactly as loudly as FAIL: the bug got fixed and nobody promoted
the marker, which is exactly as actionable as a fresh failure, just in the opposite direction.
`list <sno> <ref>` lists every entry name (one per line) for a bash gate that needs to enumerate a
suite's contents before extract()-ing each one -- same read_suite()-is-the-only-authority precedent
as `extract`, this file's established idiom for a gate script that needs standalone per-witness
files with custom env-var arms or output handling (see test_gate_udc.sh, util_board_m4_gva_seed_probe.sh).

⭐ THE JOIN RULE (empirically derived+verified against scrip and the SPITBOL oracle -- SPITBOL manual
"each semicolon ... behaves like a new column one for the statement which follows"): a label must be
IMMEDIATELY adjacent to its preceding ';' (no space); an unlabeled statement needs a SPACE immediately
after ';' (mirrors blank-column-1 = no label); the very FIRST statement on the line needs a leading
space too, if unlabeled, since there is no preceding ';' to carry it. A bare goto-only continuation
line (e.g. a lone ":(END)" on its own physical line, common in this corpus for column alignment) is
MERGED into the immediately preceding statement rather than becoming its own ';'-joined entry --
control flow is identical either way (a goto-only statement does no work of its own), and joining it
standalone is what causes SPITBOL's "ERROR 214 bad label or misplaced continuation line".

Byte-equal-or-no-delete: every entry is validated by actually RUNNING both the original file and
the converted entry (both modes) and comparing full verdicts (not just stdout text) before it is
trusted; the whole point of the empirical validate+fallback loop is that this file does not need to
be a perfect SNOBOL4/SPITBOL grammar -- a wrong guess just falls back to the always-safe multi-line
block shape instead of silently producing a bad conversion.

⛔ THE WHOLE-PROGRAM BOUND IS A HANG CATCHER, NEVER A SPEED GRADER, so it lives an ORDER OF
MAGNITUDE above the slowest thing it grades -- 120s, raised from 10s on 2026-09-13 by the coo
(THE ONE RUNNER, whose bound this is) after hq_T measured the two raku kernels this board had
been calling HANG: benchmark_point_class_add and benchmark_point_class_add1 terminate rc=0 with
the byte-correct answer in 9-11s warm and 21-42s cold on a loaded box. A bound tuned near a job's
measured duration is not a tight bound, it is a FLAKY one: its verdict is then decided by what
else the box was doing rather than by the tree, which is exactly why the pair moved together and
why the slowest of the four gradings was the one already reading HANG on the earlier tree. An
rc=124 cannot distinguish needs-more-time from never-finishes, so the only honest place for the
line is far above every honest program. COST, measured rather than assumed: across every board
pass on 2026-09-13 exactly two entries exceeded the old bound, so a true hang now costs 120s
instead of 10s and nothing else on any board pays anything.
"""
import argparse
import hashlib
import os
import re
import subprocess
import sys
import shutil
import time
import tempfile
import threading
from pathlib import Path
HARNESS_SCRIPTS = Path(__file__).resolve().parent
# ⛔ EVERY CHILD RUNS HEADLESS (the ceo 2026-10-23, after the coo's oracle re-measure opened "Hello, world" and "Click me !" windows on
# Lon's desktop at 11:09: rosetta-pascal's hello-world-graphical and simple-windowed-application inherited the session's display). A graded
# program, an oracle and every helper this harness or util_build_package_suite.py starts inherit this process's environment, so the two
# display variables leave it here, once: an X or Wayland client finds no display and fails, never opens a window. A unit that needs one
# is NEEDS_DISPLAY, never graded.
for _dv in ("DISPLAY", "WAYLAND_DISPLAY"):
    os.environ.pop(_dv, None)

BANNER_WIDTH = 80
ONE_LINE_CAP = 200
BANNER_RE = re.compile(r"^\*-+ (?P<seq>\d+) (?P<name>\S+)(?P<xfail> XFAIL)?$")
# ⭐ DIALECT-BLIND BANNER SNIFFER -- "does this file LOOK like a suite sidecar", asked without knowing
# which language wrote it. banner_re_for() needs the comment syntax up front; this one is for the single
# question loose_stdin_companion() has to answer about a file it found by NAME, before any language is
# known. Deliberately loose on the left (any run of comment-open punctuation) and strict on the right
# (dashes, seq, name) -- the shape no real stdin content has, which is the whole point.
ANY_BANNER_RE = re.compile(r"^[*#%{/][*#%{/ ]*-{3,} \d+ \S+")

# ============================================================ language configs ===
# Per-language config for the format-(B)-ONLY (banner-block) conversion path -- convert_blocks
# below. Format (A)'s one-line statement join stays SNOBOL4-specific (parse_statements /
# join_one_line / _has_goto_field): a parser-ladder family never attempts it (format B is the
# task spec's design for these families, not a join-failure fallback), so a new dialect only
# needs its source extension, its comment syntax for the banner (open/close -- close is "" for a
# line-comment language), and its grading mode. Add an entry for a language only once you have
# actually run --dump-ast (or whatever mode) against a real sample and confirmed the banner
# round-trips -- do not add a config for a language nobody has exercised.
LANG_CONFIGS = {
    "raku": {"ext": ".raku", "comment_open": "#", "comment_close": "", "modes": "m3,m4"},
    "rebus": {"ext": ".reb", "comment_open": "#", "comment_close": "", "modes": "m3,m4"},
    "pascal": {"ext": ".pas", "comment_open": "{", "comment_close": "}", "modes": "m3,m4", "expected_refusal_re": r"ISO 7185 [0-9.]+ violation"},
    "prolog": {"ext": ".pl", "comment_open": "%", "comment_close": "", "modes": "m3,m4"},
    "icon": {"ext": ".icn", "comment_open": "#", "comment_close": "", "modes": "m3,m4"},
    "snocone": {"ext": ".sc", "comment_open": "/*", "comment_close": " */", "modes": "m3,m4"},
}

# ⛔⭐ A SUITE IS GRADED IN m3 AND m4 AND NOTHING ELSE, AND ANY OTHER --modes REFUSES BEFORE A ROW IS WRITTEN (coo 2026-09-25,
# row instruments-the-harness-defaults-rebus-raku-prolog-and-snocone-to-the-dead-ast-mode-..., ceo CEO-1269). raku, rebus,
# prolog and snocone defaulted to "ast" here after the ast entries left the rung suites (corpus a6646f04c), so `run --lang rebus`
# with no --modes graded --dump-ast against run refs: SUITE_BOARD ast_n=43 ast_pass=0, exit 1, and 43 FAIL rows in the
# progress record -- three times in five days (coo 09-21, ceo 09-24 and 09-25) -- while --modes m3,m4 read 43/43 FAIL 0.
# A plausible, entirely false 0 of N. Every entry is graded in both media (CEO-1218), so the defaults are m3,m4 and a mode
# outside them is a could-not-measure, never a grade. run_ast stays: util_build_rungs_suite.py's classifier calls it.
GRADED_MODES = ("m3", "m4")
def rr_request_waits(queue):
    """A request a round-robin run yields to (CEO-1806): a SCRIP request file in the loop's queue, one carrying no engine= line. A port request
    (engine=dotnet|jvm, CEO-1872) waits its turn -- the loop serves at most one a turn, after every SCRIP request -- so it never stops a rotation part:
    with thirty port requests queued, every part yielded at its first test (10-21 20:34, testpgms core). Mirrored by lib_rr.sh rr_yield."""
    for p in Path(queue).glob("*.req"):
        try:
            if not any(line.startswith("engine=") for line in p.read_text(errors="replace").splitlines()):
                return True
        except OSError:
            continue
    return False


def parse_modes(spec, where):
    modes = [m for m in (spec or "").split(",") if m]
    bad = [m for m in modes if m not in GRADED_MODES]
    if not modes or bad:
        refuse(f"{where}: --modes {spec!r} names {', '.join(bad) if bad else 'no mode'} -- a suite is graded in m3 and m4 only "
               f"(CEO-1218: every entry in both media). Mode ast (--dump-ast) grades a parse against a run ref and recorded "
               f"0 of 43 FAIL rows for the Rebus rungs three times; nothing was graded and no progress row was written.")
    if _engine() != "scrip" and "m4" in modes:
        refuse(f"{where}: --modes {spec!r} names m4 under S4E_ENGINE={_engine()} -- m4 is SCRIP's compiled binary and the port has "
               f"none (CEO-1822); grade --modes m3, the port's one run")
    return modes


# ⛔⭐ `snobol4` IS AN ACCEPTED SPELLING OF THE DEFAULT, AND LEAVING IT OUT COST TWO SESSIONS. The default
# is the empty string, so `--lang snobol4` -- the obvious thing to type, and the spelling this file itself
# uses internally (`lang = args.lang or "snobol4"`) -- was rejected by ARGPARSE, which exits 2 with its own
# usage text. GOAL-TEST-SUITE-CONSISTENCY.md lists that exact confusion as measured shape #1 of HOW A
# CRITERION LIES: a caller reads rc=2 as THE TOOL refusing to measure, when the tool never ran at all.
# Normalised to "" immediately after parsing (see main), because `if args.lang:` is load-bearing in six
# places downstream and a truthy synonym for the default would change which reader parses the suite.
LANG_CHOICES = [""] + sorted(LANG_CONFIGS) + ["snobol4"]


# ============================================================ paths / env ===
# ⛔⭐ THE ENGINE IS A RUNNER SETTING (Lon 2026-10-17, ceo CEO-1822): S4E_ENGINE names the program a board grades -- scrip, the
# default and every board before CEO-1822, or dotnet, snobol4dotnet's executable (hq_dotnet's own board, Lon: "hq_dotnet runs
# them"). An unknown name refuses: a board graded on a guessed engine would print a plausible table about the wrong program.
sys.path.insert(0, str(Path(__file__).resolve().parent))  # the one engine map lives beside this file; python3 -I prepends no script folder
from util_progress_append import ENGINE_RUNNERS, engine_binaries  # noqa: E402 -- (CEO-1822)
ENGINES = ("scrip",) + tuple(ENGINE_RUNNERS)
def _engine():
    e = os.environ.get("S4E_ENGINE", "").strip() or "scrip"
    if e not in ENGINES:
        refuse(f"S4E_ENGINE={e!r} names no engine this harness drives ({', '.join(ENGINES)})")
    return e


def resolve_paths():
    here = Path(__file__).resolve().parent            # harness/scripts
    scrip_root = (here.parent.parent / "SCRIP")                           # SCRIP/
    s4e_home = Path(os.environ.get("S4E_HOME", str(scrip_root.parent)))
    return {
        "scrip_bin": Path(os.environ.get("SCRIP", str(scrip_root / "scrip"))),
        "rt_dir": Path(os.environ.get("RT_DIR", str(scrip_root / "out"))),
        "corpus": s4e_home / "corpus",
        "inc": Path(os.environ.get("INC", str(s4e_home / "corpus" / "include"))),
        "scrip_root": scrip_root,
        "engine": _engine(),
        "timeout": float(os.environ.get("TIMEOUT", "120")),
        "stdbuf_bin": _which("stdbuf"),
    }


def _which(name):
    for d in os.environ.get("PATH", "").split(os.pathsep):
        p = Path(d) / name
        if p.is_file() and os.access(p, os.X_OK):
            return str(p)
    return None


def refuse(msg):
    """⛔ ONE REFUSAL CODE, AND IT IS rc=2 (ceo CEO-233, row harness-refusal-exit-code-unified-on-rc-2, 2026-09-04).

    ⛔ THIS EXITED 3 FOR MONTHS, by this file's own local convention, while every bash gate and lib_gate.sh's
    three-code ladder said a refusal is rc=2 -- 0 measured-and-clean · 1 measured-and-red · 2 COULD NOT MEASURE.
    The divergence became untenable when the stale-binary preflight landed here (row harness-and-ladder-runner-
    refuse-on-a-stale-binary-...): it follows the law and exits 2, so ONE tool carried TWO refusal codes and a
    caller could not ask "did it refuse?" without knowing WHICH refusal it hit. ⭐ The old convention was not
    silly -- it wanted to distinguish "could not measure" from a red board -- but rc=1 already carries the red
    board, so the third code bought nothing the law did not already give, and cost the one question every caller
    actually asks. A local convention that disagrees with a fleet law is a trap even when its reasoning is sound,
    because the reasoning lives here and the callers live everywhere."""
    print(f"⛔ REFUSING: {msg}", file=sys.stderr)
    sys.exit(2)


def require_population(paths, count, floor, label):
    """⛔ REFUSE rc=2 when a verdict is about to be computed over fewer than `floor` graded rows.

    ⭐ THIS FUNCTION DELIBERATELY CONTAINS NO FLOOR LOGIC. It shells out to
    ../harness/scripts/util_require_population.sh, which sources gate_floor() from lib_gate.sh -- the SAME
    function every bash suite runner calls, for the same reason require_fresh() above shells out to
    util_require_fresh.sh rather than reimplementing staleness: a second copy of a rule is how a cured
    defect class comes back the moment nobody is looking at the copy that got missed.

    THE DEFECT: `cmd_run`'s verdict is `sys.exit(0 if not fails else 1)` -- a suite whose `entries` list
    is empty (a malformed or emptied ALL.sno/ALL.ref pair, with no --shard involved to trip the sibling
    check just above) never enters the grading loop, `fails` stays [], and this exits 0. A run that
    graded nothing must never read as a run that graded everything and found it clean (row every-board-
    wrapper-refuses-on-a-zero-population-instead-of-passing-vacuously, hq_T 2026-09-04)."""
    shim = HARNESS_SCRIPTS / "util_require_population.sh"
    if not shim.is_file():
        print(f"⛔ REFUSED-TO-GRADE rc=2: {shim} missing -- cannot establish that this run graded "
              f"anything (the ONE population-floor authority, never reimplemented here)", file=sys.stderr)
        sys.exit(2)
    r = subprocess.run(["bash", str(shim), "--gate", "corpus_suite_harness", str(count), str(floor), label],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stdout)
        sys.stderr.write(r.stderr)
        sys.exit(2)


def check_scrip(paths):
    if paths["engine"] != "scrip":
        runner = HARNESS_SCRIPTS / ENGINE_RUNNERS[paths["engine"]]
        if not runner.is_file():
            refuse(f"S4E_ENGINE={paths['engine']} has no runner at {runner} -- its arm has not landed")
        # --binaries is the runner's one check, before the first entry (agreed with hq_jvm): a missing or stale build, a missing host, or a
        # language the engine has no front end for refuses the board here with the runner's own line, never as one red per entry
        r = subprocess.run(["bash", str(runner), "--binaries", "--lang", paths.get("lang") or "snobol4"], capture_output=True, text=True)
        if r.returncode != 0 or not r.stdout.strip():
            refuse(f"the {paths['engine']} engine cannot grade this board: {(r.stderr or r.stdout).strip()}")
        missing = [f for f in r.stdout.splitlines() if f.strip() and not os.path.isfile(f)]
        if missing:
            refuse(f"the {paths['engine']} runner names files that are not there: {', '.join(missing)}")
        return
    if not (paths["scrip_bin"].is_file() and os.access(paths["scrip_bin"], os.X_OK)):
        refuse(f"scrip is not built/executable at {paths['scrip_bin']}")
    require_fresh(paths)


def require_fresh(paths):
    """⛔ REFUSE rc=2 when the binary about to be graded predates the tree it will be labelled with.

    ⭐ THIS FUNCTION DELIBERATELY CONTAINS NO STALENESS LOGIC. It shells out to
    ../harness/scripts/util_require_fresh.sh, which sources gate_require_fresh() from lib_gate.sh -- the SAME
    function every bash runner calls (hq_B, SCRIP 4c7253e99). Row harness-and-ladder-runner-refuse-on-
    a-stale-binary-like-the-artifact-regen-does (ceo -> hq_T 2026-09-04).

    ⛔ WHY IT IS NOT A PYTHON REIMPLEMENTATION, WHICH WOULD HAVE BEEN SHORTER AND IS THE WHOLE POINT OF
    THE ROW: this exact idea already existed TWICE in bash (gate_require_fresh and lib_build_currency's
    assert_binary_current). ceo cured a wrong staleness basis in one of them (3d12ca54 -- "IT IS NOT A
    SUPERSET, IT IS WRONG"); the cure never reached the other, so the identical defect regenerated and
    was cured a second time nine days later. A third copy -- in a second LANGUAGE, where no grep for the
    bash symbol would ever find it -- is how that class survives its own cure a third time. The cost of a
    copy is never the duplicated lines; it is that fixing one copy makes everybody believe the class is
    dead.

    THE WITNESS (ceo, 2026-09-04): two false-red audits in one day -- a fetched-not-merged clone at 12:23,
    and a 10:57 binary at 14:03 that read RED and then GREEN after an incremental make. Nothing the board
    printed could distinguish "the tree is broken" from "you are grading last morning's binary".

    ⛔ SCOPE NOTE -- the .so is checked for STALENESS but a MISSING .so is left alone on purpose. This
    harness already has documented behaviour for that case (run_m4 -> Verdict("SKIP", "libscrip_rt.so not
    built")), and turning another instrument's SKIP into a REFUSE is a different row's ruling, not this
    one's. A stale .so, though, is squarely this class and the dangerous half of it: an older runtime
    still exports what source deleted, so m4 grades a program nobody is shipping."""
    shim = HARNESS_SCRIPTS / "util_require_fresh.sh"
    if not shim.is_file():
        print(f"⛔ REFUSED-TO-GRADE rc=2: {shim} missing -- cannot establish that the binary about to be "
              f"graded is current (the ONE stale-binary authority, never reimplemented here)", file=sys.stderr)
        sys.exit(2)
    arts = [str(paths["scrip_bin"])]
    so = paths["rt_dir"] / "libscrip_rt.so"
    if so.is_file():
        arts.append(str(so))
    r = subprocess.run(["bash", str(shim), "--gate", "corpus_suite_harness"] + arts,
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stdout)
        sys.stderr.write(r.stderr)
        sys.exit(2)


# ⛔⭐ LANGUAGES WITH NO INDEPENDENT RIVAL IMPLEMENTATION (CEO-607, 2026-09-12). Membership here is a MEASURED
# property of the language, never a convenience: a language is in this set only when no second implementation of
# it exists to be an oracle at all, so "cannot cut a ref" is permanent rather than pending. ⛔ It is NOT a way to
# opt out of an oracle cut -- adding a language that HAS a rival would silently downgrade every one of its refs
# from measured to authored, which is the exact circularity CEO-607 closes. Rebus is the only member measured so
# far; Snocone is NOT one (SPITBOL grades it, lib_oracle_flags.sh sbl_correctness_bin).
NO_RIVAL_LANGS = {"rebus"}


def resolve_oracle_bin(paths, lang=""):
    """Resolve the correctness oracle's binary+flags via lib_oracle_flags.sh -- the ONE authority
    (RULES.md Oracles section): never hand-assemble an oracle path/flag pair in a second copy.
    Shells out to the real bash accessors so a future change to a shared oracle's location or
    capability check is picked up automatically, same as every bash caller gets. Used only by
    cmd_capture_oracle_refs -- no other command in this file talks to a live oracle at all, since
    every other family already ships a committed .ref.

    lang="" or "snobol4" (the original, only path until 2026-08-29): sbl_correctness_bin +
    sbl_lang_flags, i.e. SPITBOL `-bf`. lang="prolog": swipl_bin() from the same lib, invoked
    `-q` alone. lang="icon"/"raku": the one-step driver, no flags. lang="pascal": the fpc wrapper. lang="snocone":
    snocone_oracle_run.sh, scrip --transpile then sbl -bf on the SNOBOL4 text (SPITBOL grades Snocone).
    No other --lang has an oracle wired here yet; refuses rather than guessing one.

    ⛔ WAS `-q -g halt` until 2026-09-05 (row prolog-every-non-package-source-...-with-oracle-refs,
    seat07) -- `-g halt` runs as a -g GOAL, which fires BEFORE swipl's deferred `initialization(Goal,
    main)` hook (that hook runs at the point the interactive top level would otherwise start, which
    `-g halt` preempts by exiting first). Every file using the `:- initialization(main, main).` idiom
    -- the modern, recommended SWI entry-point form, and the one every corpus/tests/scrip_test/prolog/
    demo file uses -- therefore ran, printed nothing, and got excluded as "oracle produced EMPTY
    output" or (worse, via the loose-pair path, which has no empty-output guard) silently merged a
    vacuous ref. Witness: corpus/tests/scrip_test/prolog/hello.pl prints "Hello, World!" under `swipl
    -q hello.pl` and nothing under `swipl -q -g halt hello.pl`. Bare `-q` is the documented way to run
    a swipl script non-interactively: a registered main-goal fires and auto-halts with Goal's own
    success/fail exit code (the OLD flags always forced exit 0, masking a failing main-goal); a file
    with no entry point at all falls through to the toplevel, hits EOF on `/dev/null` stdin, and exits
    0 with at most a trailing newline -- already stripped by this function's own `.rstrip("\n")`,
    verified empirically against a no-directive witness before this change landed."""
    lib = HARNESS_SCRIPTS / "lib_oracle_flags.sh"
    if not lib.is_file():
        refuse(f"lib_oracle_flags.sh missing at {lib} -- the ONE oracle-flag authority (RULES.md)")
    if lang in ("", "snobol4"):
        r = subprocess.run(["bash", "-c", f". '{lib}' && sbl_correctness_bin && sbl_lang_flags"],
                            capture_output=True, text=True)
        if r.returncode != 0:
            refuse(f"lib_oracle_flags.sh refused (sbl_correctness_bin/sbl_lang_flags): {r.stderr.strip()}")
        lines = r.stdout.strip("\n").splitlines()
        if len(lines) != 2 or not lines[0] or not lines[1]:
            refuse(f"unexpected output from sbl_correctness_bin/sbl_lang_flags: {r.stdout!r}")
        return lines[0], lines[1]  # oracle binary path, language flags (e.g. "-bf")
    if lang == "snocone":
        # ⭐ SPITBOL GRADES SNOCONE (the grade side's mapping, _fatal_render_voice_for, says so too); snocone_oracle_run.sh is the one-step driver that
        # transpiles the entry to SNOBOL4 text in a tmpdir and runs sbl -bf on it, so the ref is SPITBOL's answer to the faithful SNOBOL4 twin, never SCRIP's
        # own run. sbl_correctness_bin is called here so a missing oracle refuses with lib_oracle_flags.sh's message rather than inside the wrapper.
        r = subprocess.run(["bash", "-c", f". '{lib}' && sbl_correctness_bin"], capture_output=True, text=True)
        if r.returncode != 0:
            refuse(f"lib_oracle_flags.sh refused (sbl_correctness_bin): {r.stderr.strip()}")
        wrapper = HARNESS_SCRIPTS / "snocone_oracle_run.sh"
        if not wrapper.is_file():
            refuse(f"snocone_oracle_run.sh missing at {wrapper} -- the transpile-then-SPITBOL driver")
        return str(wrapper), ""   # no flags: the wrapper takes sbl's from sbl_lang_flags
    if lang == "prolog":
        r = subprocess.run(["bash", "-c", f". '{lib}' && swipl_bin"], capture_output=True, text=True)
        if r.returncode != 0:
            refuse(f"lib_oracle_flags.sh refused (swipl_bin): {r.stderr.strip()}")
        bin_path = r.stdout.strip()
        if not bin_path:
            refuse(f"unexpected empty output from swipl_bin: {r.stdout!r}")
        return bin_path, "-q"
    if lang == "icon":
        # ⭐ THE ONE-STEP DRIVER, NOT icont/iconx (hq_P 2026-08-30). run_oracle()'s contract is a SINGLE
        # invocation -- `[bin] + flags + [name]` in the file's own directory -- and Icon is classically a
        # two-step compile-then-run, which is why this language could not be wired here before. The shared
        # tree ships `icon`, which compiles and runs in one shot, so it fits the existing contract with no
        # change to run_oracle. Resolved through lib_oracle_flags.sh's icon_bin(), never a hand-built path:
        # every oracle in this project lives OFF PATH by design, so `command -v icon` would answer the wrong
        # question and under-report silently.
        r = subprocess.run(["bash", "-c", f". '{lib}' && icon_bin"], capture_output=True, text=True)
        if r.returncode != 0:
            refuse(f"lib_oracle_flags.sh refused (icon_bin): {r.stderr.strip()}")
        bin_path = r.stdout.strip()
        if not bin_path:
            refuse(f"unexpected empty output from icon_bin: {r.stdout!r}")
        return bin_path, ""   # no flags: `icon <file>` is the whole invocation
    if lang == "pascal":
        # ⭐ hq_C's ruling (2026-08-28, KEEP.md § FPC-oracle regen exceptions): `fpc -Miso` is the Pascal
        # correctness oracle. Unlike icon, FPC has no one-step compile-and-run mode, so the "binary" handed
        # to run_oracle() is fpc_oracle_run.sh -- a thin wrapper that compiles to a private tmpdir (never the
        # source directory) and execs the result, matching run_oracle()'s single-process contract exactly
        # the way icon_bin's real one-step binary does. `-Miso` is passed as this resolver's own flags, same
        # shape as snobol4's `-bf`/prolog's `-q` -- never hand-assembled a second time at a call site.
        wrapper = HARNESS_SCRIPTS / "fpc_oracle_run.sh"
        if not wrapper.is_file():
            refuse(f"fpc_oracle_run.sh missing at {wrapper} -- the one-step FPC oracle driver")
        return str(wrapper), "-Miso"
    if lang == "raku":
        # ⭐ Rakudo is one-step like icon: `raku <file>` compiles and runs in a single invocation, so it fits
        # run_oracle()'s contract with no change to it and needs no wrapper of pascal's shape. Resolved through
        # lib_oracle_flags.sh's rakudo_bin(), never a hand-built path or a bare `raku` on PATH -- that accessor
        # deliberately PREFERS /home/resources/rakudo-local/bin/raku (v2026.05) over the apt /usr/bin/raku
        # (v2022.12) and refuses rather than falling through to PATH, and the two differ by four years of the
        # language. `command -v raku` answers the narrower question "is a raku on PATH" and would silently cut
        # every ref in this corpus against the older rival. LABEL DUTY (lib_oracle_flags.sh's own FACT RULE):
        # any grid quoting a rakudo arm names the version it resolved.
        r = subprocess.run(["bash", "-c", f". '{lib}' && rakudo_bin"], capture_output=True, text=True)
        if r.returncode != 0:
            refuse(f"lib_oracle_flags.sh refused (rakudo_bin): {r.stderr.strip()}")
        bin_path = r.stdout.strip()
        if not bin_path:
            refuse(f"unexpected empty output from rakudo_bin: {r.stdout!r}")
        # ⛔ THE WRAPPER, NOT THE BARE BINARY -- it re-resolves rakudo_bin() itself and adds
        # `-I<staged> -Mprelude_rakudo` for the self-timed benchmark kernels whose wall_us()/wall_ms() are
        # SCRIP builtins. Without it rakudo refuses those at compile time with EMPTY stdout, which the
        # builder's empty-output guard launders into a per-program "vacuous ref" exclusion -- see that
        # script's own header for the four programs it silently cost. rakudo_bin() is still called above so
        # a missing oracle refuses HERE, with lib_oracle_flags.sh's own message, rather than inside a wrapper.
        wrapper = HARNESS_SCRIPTS / "raku_oracle_run.sh"
        if not wrapper.is_file():
            refuse(f"raku_oracle_run.sh missing at {wrapper} -- the prelude-staging rakudo driver")
        return str(wrapper), ""   # no flags: `raku <file>` is the whole invocation
    if lang in NO_RIVAL_LANGS:
        # ⛔⭐ NOT "NOT WIRED YET" -- NOT WIREABLE, EVER, AND THE TWO REFUSALS MUST NOT READ ALIKE (CEO-607,
        # 2026-09-12, on hq_C's ASK; option (a)). The bare refusal below says "no oracle wired ... yet", which
        # every reader correctly parses as a backlog item someone will close by widening this function. For a
        # language with NO INDEPENDENT RIVAL IMPLEMENTATION there is nothing to widen it TO: CEO-391's one
        # oracle per language has no binary to name, and the honest remedy is a different one -- the runtime
        # ref is DERIVED and the derivation is RECORDED beside it, the strongest derivation being a CROSS-
        # LANGUAGE computation of the same kernel under a real oracle (the rival program and its oracle
        # output), with the hand arithmetic as the second witness. ⭐ A refusal that names the wrong remedy
        # costs more than a silent one: it sends the next seat to widen a function that cannot be widened,
        # and the seat that fails to widen it concludes the SOURCES are the problem. This message names the
        # remedy that exists, and the gate that re-performs it on every run is
        # test_gate_rebus_derived_refs_match_their_rival_oracle.sh -- the derivation is re-computed, never
        # believed, because a static record of a measurement is a claim and rots like any other prose here.
        refuse(f"--lang {lang!r}: no rival: refs are derived, see KEEP.md -- {lang} has no independent rival "
               f"implementation, so there is no oracle to cut a ref FROM and nothing for resolve_oracle_bin to be "
               f"widened TO (CEO-607). Its kernels carry a ref DERIVED from a rival program in another language "
               f"run under THAT language's oracle, with the derivation recorded in a .derivation file beside the "
               f"ref and re-performed by test_gate_rebus_derived_refs_match_their_rival_oracle.sh. ⛔ Do NOT cut a "
               f"ref from SCRIP's own output: a ref cut from the implementation it grades proves only that the "
               f"implementation is deterministic")
    refuse(f"no oracle wired for --lang {lang!r} in capture-oracle-refs yet (only snobol4/snocone/prolog/icon/pascal/raku so far)")


def _size_switches(heap_kb, stack_kb):
    """A program's DECLARED heap and stack reach the run as SPITBOL's switches, not as environment variables (Lon
    2026-09-23, CEO-1225: SCRIP sizes the heap with -d and -i and the stack with -s, as SPITBOL does; an environment knob
    is invisible in a transcript, a switch is recorded with the run). heap_kb is the program's MAXIMUM heap, SPITBOL's -d,
    and nothing else: the initial window stays SPITBOL's -i1m or the tiny arena of `make test-arena`, which a -i here would
    silently override for every declared program (ceo CEO-1261; every program declares since Lon's word of 2026-09-25); stack_kb
    is -s. They go before the source for scrip --run and lead the compiled binary's own command line, which reads them at its
    first allocation. None = the shipped default, so an undeclared program's command line is byte-identical to before."""
    sw = []
    if heap_kb: sw += ["-d%dk" % heap_kb]
    if stack_kb: sw += ["-s%dk" % stack_kb]
    return sw


def _compile_switches(paths, compile_args):
    """scrip's switches before the source at the COMPILE step, the same list in both modes (scrip --run in m3, scrip
    --compile in m4): the caller's scrip_extra (capture-oracle-refs --compile-args alone, since clause 8 (f) retired the
    harness's own typing), then the unit's declared compile_args, a switch both carry passed once."""
    typed = list(paths.get("scrip_extra", []))
    return typed + [w for w in (compile_args or []) if w not in typed]


def _host_u_switch(sno_path, prog_args):
    """SPITBOL's HOST(0) is the -u string and nothing else (sbl -h; Lon 2026-09-23, CEO-1224), so a SNOBOL4 entry's
    DECLARED argv reaches HOST(0) the way CSNOBOL4-targeted programs read it (aisnobol HSORT, ATN) by being passed as
    `-u "<argv joined by spaces>"` before the source -- to sbl, to scrip --run, and to the mode-4 binary alike -- while
    the same tokens still follow the file for HOST(2,n). Other languages, and entries with no argv, get nothing."""
    if not prog_args: return []
    if not str(sno_path).lower().endswith((".sno", ".spt", ".sbl")): return []
    return ["-u", " ".join(str(a) for a in prog_args)]


def oracle_diagnostic(oracle_bin, flags, sno_path, timeout, stdin_text=None, prog_args=None):
    """ONE extra oracle invocation whose ONLY product is the oracle's OWN first diagnostic line, for a caller
    that is about to EXCLUDE a program and must name the measured cause rather than a theory about it.
    ⛔⭐ WHY IT IS A SEPARATE FUNCTION AND NOT A WIDER run_oracle() RETURN: run_oracle's (text, rc, kind) triple
    has many callers across the runners, and widening it to carry stderr would touch every one of them for the
    benefit of one path. This is additive -- nothing that grades anything calls it, and it is invoked only on
    an exclusion path, where one more sub-second oracle run costs nothing.
    ⛔⭐⭐ THE DEFECT IT CLOSES, MEASURED (hq_S 2026-09-12, raku scrip_test, CEO-604): an exclusion reason is the
    ONLY record of why a program left the denominator, and an excluded name cannot be red, so nobody re-reads
    it. Thirteen raku fixtures were excluded as "rakudo prints NOTHING: the file defines `sub main()` and never
    calls it" -- true of four of them, GENERALIZED FROM ONE WITNESS onto the other nine, of which five are not
    that shape at all: rakudo REFUSES them at compile time (two constructs SCRIP accepts and Raku does not, one
    SCRIP builtin that is not a Raku routine, one Perl5 `/g`) or at run time (`$*STDOUT`). The oracle said so,
    in one line, on stderr, every single run -- and the guard that excluded them threw that line away and kept
    a human sentence instead. ⭐ THE GENERAL FORM: when an instrument excludes something, the excluder's prose is
    a hypothesis and the tool's own stderr is the measurement; write down the measurement."""
    sno_path = Path(sno_path)
    argv = [oracle_bin] + flags.split() + _host_u_switch(sno_path, prog_args) + [sno_path.name] + (list(prog_args) if prog_args else [])
    _kind, _out, err, _rc = _run_raw(argv, timeout, cwd=str(sno_path.parent), stdin_text=stdin_text)
    err = (err or b"").decode("utf-8", "replace")   # ⛔ _run_raw returns BYTES on all four arms, never str
    for line in err.splitlines():
        line = line.strip()
        if line and not line.startswith("==="):     # rakudo's "===SORRY!===" banner names no cause; the next line does
            return line
    return ""


def run_oracle(oracle_bin, flags, sno_path, timeout, stdin_text=None, prog_args=None, out_files=None, merge_stderr=False):
    """One live oracle invocation. stdin is `/dev/null` unless the caller passes stdin_text -- the
    one caller that does is cmd_capture_oracle_refs, feeding a loose companion resolved by
    loose_stdin_companion(); every other oracle/scrip call in this file
    and in test_one_witness.sh is unfed (whose exact contract this mirrors: stdout text AND returncode both
    matter -- a witness testing a deliberate error exit is not 'wrong' for exiting non-zero, it is
    wrong only if scrip's rc/text pair disagrees with the oracle's).
    ⛔⭐ ARGV IS THE BARE BASENAME, CWD IS THE FILE'S OWN DIRECTORY (row suite-harness-argv-echoes-a-
    mktemp-path-so-diagnostic-programs-cannot-be-graded). A diagnostic that echoes its own argv (a
    SPITBOL ERROR NNN line naming the file being compiled, e.g.) echoes it VERBATIM -- a full path
    changes every run (mktemp), and even a stable full path differs from what run_m3/run_suite_entry
    will echo later for the SAME witness. Passing just the name, from the right cwd, is what makes
    that echoed text reproducible and comparable to a frozen .ref at all."""
    sno_path = Path(sno_path)
    argv = [oracle_bin] + flags.split() + _host_u_switch(sno_path, prog_args) + [sno_path.name] + (list(prog_args) if prog_args else [])
    _out_files_clear(sno_path.parent, out_files)
    kind, out, _err, rc = _run_raw(argv, timeout, cwd=str(sno_path.parent), stdin_text=stdin_text, merge_stderr=merge_stderr)
    out = _out_files_append(out, sno_path.parent, out_files) if out_files else out
    # ⛔⭐ AN ORACLE KILLED BY A SIGNAL IS A CRASH, NOT A RUN -- and until 2026-09-04 this returned "RAN" for one
    # (row every-ref-cutting-path-refuses-when-the-oracle-dies-mid-cut, ceo -> hq_T, on seat07's finding that
    # `sbl -bf` SIGSEGVs on about half its ERROR 212 runs WHILE PRINTING the diagnostic). _run_raw's "RAN" means
    # only "the process was launched and did not time out"; the signal shows up as a NEGATIVE returncode, which
    # cmd_capture_oracle_refs -- whose whole guard is `if ora_kind != "RAN"` -- never looked at. So the one
    # command in this file that mints ground truth from a live oracle would have written a TRUNCATED ref, and a
    # truncated ref is the worst artifact here: a plausible-looking pin that grades every future run against a
    # lie, indistinguishable downstream from a good one.
    # ⛔⛔ THE DEFECT SURVIVED A SOURCE-LEVEL CENSUS THAT DECLARED THIS PATH SAFE, done by hq_T hours earlier and
    # written into the row's own GOAL. Reading the code proved "_run_raw returns CRASH on a signal" -- which is
    # true of classify(), a DIFFERENT function, and not of this one. It was found only when the gate ran the
    # thing with a synthetic oracle that prints output and then segfaults. ⭐ A census of what code SAYS is not a
    # measurement of what it DOES, and the two disagree exactly where it matters most.
    # ⭐ Fixed HERE rather than in cmd_capture_oracle_refs, because util_build_package_suite.py caught this only
    # by independently re-deriving the same test (`ora_rc < 0`) at its own call site -- two copies of one rule,
    # one of which was missing. Callers now inherit the classification from the single reader.
    if kind == "RAN" and rc is not None and rc < 0:
        kind = "CRASH"
    return out.decode("utf-8", "replace").rstrip("\n"), rc, kind


def xsb_oracle_bin():
    """THE XSB ORACLE (ceo CEO-1927; RULES.md § Oracles, FACT RULE XSB IS THE THIRD PROLOG ORACLE, FOR THE XSB PACKAGE), reached
    through lib_oracle_flags.sh's xsb_bin() alone -- a missing launcher refuses rc=2 with the accessor's own words."""
    lib = HARNESS_SCRIPTS / "lib_oracle_flags.sh"
    r = subprocess.run(["bash", "-c", f". '{lib}' && xsb_bin"], capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        refuse(f"lib_oracle_flags.sh refused (xsb_bin): {r.stderr.strip() or r.stdout!r}")
    return r.stdout.strip()


def xsb_answer_lines(raw):
    """XSB's answer as gentest.sh compares it and as the vendored driver xsb_sorted_output prints SCRIP's: the non-empty lines of the
    temp file, sorted (code-point order, the standard order msort gives strings), duplicates kept."""
    return sorted(ln for ln in raw.decode("utf-8", "replace").split("\n") if ln != "")


def run_xsb_gentest(xsb_bin, upstream, run, timeout):
    """ONE XSB RUN AS XSB'S OWN TEST SCRIPTS MAKE IT (ceo CEO-1927, 2026-10-23). `run` is a row of the package's ORACLE_RUNS.tsv, recorded from
    XSB's own test.sh (util_xsb_oracle_runs.py): dir (the upstream directory the script runs in, below `upstream`), kind, file, cmd, emu_args.
    A fresh copy of the run's TOP-LEVEL test directory (its stale *.xwam, *_new and temp left out, so every source compiles here), cwd the
    run's dir inside it; stdin as the script writes it -- kind gentest (gentest.sh, the stest.sh testall.sh runs): `[FILE].\\ntell(temp).\\nCMD\\ntold.`,
    kind wfs (wfs_tests/gentest.sh, whose test/1 opens temp itself): `[wfs_test].\\nCMD\\ntold.` -- to `xsb <emu_args>` (testall.sh's -e
    segfault_handler(warn).). The answer is the file temp the run wrote. Returns (kind, answer_bytes or None, stderr_bytes, rc): kind is
    _run_raw's (RAN, HANG, OVERFLOW, UNPROVEN), CRASH for a signal."""
    import shlex
    top = run["dir"].split("/")[0]
    src = Path(upstream) / top
    if not src.is_dir():
        refuse(f"ORACLE_RUNS.tsv names {run['dir']!r}, and {src} is no directory -- the upstream tree the package's CONTRACT.tsv names is not there")
    with tempfile.TemporaryDirectory(prefix="xsb_gentest_") as t:
        dst = Path(t) / top
        shutil.copytree(src, dst, ignore=shutil.ignore_patterns("*.xwam", "*_new", "temp"))
        cwd = Path(t) / run["dir"]
        stdin = (f"[{run['file']}].\ntell(temp).\n{run['cmd']}\ntold.\n" if run["kind"] == "gentest" else f"[wfs_test].\n{run['cmd']}\ntold.\n")
        kind, out, err, rc = _run_raw([xsb_bin] + shlex.split(run["emu_args"]), timeout, cwd=str(cwd), stdin_text=stdin)
        if kind == "RAN" and rc is not None and rc < 0:
            kind = "CRASH"
        tp = cwd / "temp"
        return kind, (tp.read_bytes() if tp.is_file() else None), err, rc


def run_icon_built_oracle(paths, src_path, timeout, stdin_text=None, prog_args=None, out_files=None):
    """THE ICON ORACLE AS THE ICON PACKAGES' OWN HARNESS RUNS IT, for a package whose CONTRACT.tsv merges stderr (the coo
    2026-10-01, measured on jcon_tests): `icont -s -o <stem> <name>` in the file's own directory, its stderr kept apart, then
    `iconx <stem> args < in > out 2>&1` (iconx handed the bare icode name, so &progname reads the stem; exec'd through PATH
    it read the full path). The one-step `icon` driver run_oracle() uses for Icon is
    right for a stdout-only ref and wrong for a merged one in two measured ways: its translator's warnings ("checkfpx.icn: "i":
    undeclared identifier") land in the merged stream, 17 of 78 jcon refs; and it names the program kwds.icn where upstream's
    harness ran the built kwds, so &progname read kwds.icn against a shipped ref reading kwds. Returns (text, rc, kind) as
    run_oracle does; a translation that fails returns kind "TRANSLATE" and the translator's first line as text."""
    src_path = Path(src_path)
    d, stem = src_path.parent, src_path.stem
    lib = HARNESS_SCRIPTS / "lib_oracle_flags.sh"
    r = subprocess.run(["bash", "-c", f". '{lib}' && icont_bin"], capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        refuse(f"lib_oracle_flags.sh refused (icont_bin): {r.stderr.strip()}")
    kind, out, err, rc = _run_raw([r.stdout.strip(), "-s", "-o", stem, src_path.name], timeout, cwd=str(d))
    if kind != "RAN" or rc != 0:
        first = ((err or b"") + (out or b"")).decode("utf-8", "replace").strip().split("\n")[0]
        return first, rc, ("TRANSLATE" if kind == "RAN" else kind)
    r = subprocess.run(["bash", "-c", f". '{lib}' && iconx_bin"], capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        refuse(f"lib_oracle_flags.sh refused (iconx_bin): {r.stderr.strip()}")
    _out_files_clear(d, out_files)
    kind, out, _err, rc = _run_raw([r.stdout.strip(), stem] + [str(a) for a in (prog_args or [])], timeout, cwd=str(d),
                                   stdin_text=stdin_text, merge_stderr=True)
    out = _out_files_append(out, d, out_files) if out_files else out
    if kind == "RAN" and rc is not None and rc < 0:
        kind = "CRASH"
    return out.decode("utf-8", "replace").rstrip("\n"), rc, kind


def run_unicon_built_oracle(paths, src_path, timeout, stdin_text=None, prog_args=None, out_files=None):
    """THE UNICON ORACLE AS UNICON'S OWN tests/Makefile.test RUNS IT (hq_unicon, CEO-2072): the translator with -s -o <stem> <name> in the file's own
    directory through unicon_bin() (never a bare name, never -E), then `./<stem> args < in > out 2>&1`. Returns (text, rc, kind) as
    run_icon_built_oracle does; a translation that fails returns kind "TRANSLATE" and the translator's first line as text. A compile that
    returns rc 0 and leaves no executable (a library module linking sibling .u files) is also "TRANSLATE"."""
    src_path = Path(src_path)
    d, stem = src_path.parent, src_path.stem
    lib = HARNESS_SCRIPTS / "lib_oracle_flags.sh"
    r = subprocess.run(["bash", "-c", f". '{lib}' && unicon_bin"], capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        refuse(f"lib_oracle_flags.sh refused (unicon_bin): {r.stderr.strip()}")
    kind, out, err, rc = _run_raw([r.stdout.strip(), "-s", "-o", stem, src_path.name], timeout, cwd=str(d))
    if kind != "RAN" or rc != 0:
        first = ((err or b"") + (out or b"")).decode("utf-8", "replace").strip().split("\n")[0]
        return first, rc, ("TRANSLATE" if kind == "RAN" else kind)
    if not (d / stem).is_file():
        first = ((err or b"") + (out or b"")).decode("utf-8", "replace").strip().split("\n")[0]
        return first or "the translator left no executable", rc, "TRANSLATE"
    _out_files_clear(d, out_files)
    kind, out, _err, rc = _run_raw(["./" + stem] + [str(a) for a in (prog_args or [])], timeout, cwd=str(d), stdin_text=stdin_text, merge_stderr=True)
    out = _out_files_append(out, d, out_files) if out_files else out
    if kind == "RAN" and rc is not None and rc < 0:
        kind = "CRASH"
    return out.decode("utf-8", "replace").rstrip("\n"), rc, kind


# ==================================================================== exec ===
# ⭐⭐ OOM IS ITS OWN OUTCOME (ceo CEO-1229 (2), 2026-09-23 20:2x, on the coo's row
# instruments-suite-attribute-files-declare-stack-and-heap-per-program-and-every-runner-honours-both, verbatim: "THE PROGRESS WORD IS
# OOM: a run that ends in a properly reported out-of-memory at the heap it ran under, recorded with that heap. It is not PASS and it is
# not FAIL or CRASH (Lon: a properly reported out of memory is not a failure); the suite table counts it outside the numerator, and the
# harness lists every OOM program by name so each one gets its heap declaration, or a leak cure if its live set is garbage.").
# THE REPORT IS THE RUNTIME'S OWN, landed by the cto at SCRIP dc739c38a (CTO-164): a live set past the hard cap ends rc 1 with
# `scrip: error <code>: <text> (the GC heap's hard cap is <cap> KB, -d; <committed> KB committed; this request <n> bytes)` -- 204
# "memory overflow" in every voice but Icon's, which says 306/307. MEASURED 2026-09-24 07:1x by the coo at the default cap, mode 3, one
# witness each: SNOBOL4 204, Icon 307 (a list) and 307 (a string table), Prolog 204, Pascal 204 -- every one rc 1 and every one this
# line. ⛔ THE PARENTHESIS IS THE MATCH, NEVER THE ERROR NUMBER: 204 is also Icon's "real overflow, underflow, or division by zero",
# so a number alone would call an Icon wrong answer an OOM. ⛔ AND ONLY A POSITIVE rc: a signal is a CRASH whatever stderr says (the
# start-up refusals -- an out-of-range SCRIP_HEAP_KB, a bad -d or -i, a failed mmap -- still abort, by the cto's design), and a run
# that trapped the error with SETEXIT and went on to end rc 0 answered, so it is graded on its output like any other run.
_OOM_REPORT_RE = re.compile(rb"^scrip: error (\d+): [^\n]*\(the GC heap's hard cap is (\d+) KB, -d; (\d+) KB committed; "
                            rb"this request (\d+) bytes\)", re.M)


def oom_report(err):
    """(code, cap_kb, committed_kb, request_bytes) of the FIRST properly reported out-of-memory in a run's stderr, else None."""
    m = _OOM_REPORT_RE.search(err or b"")
    return tuple(int(g) for g in m.groups()) if m else None


def _oom_verdict(out, err, rc, masked_n=0):
    """An OOM Verdict when the run ended rc > 0 with the runtime's own report on stderr, else None."""
    if rc is None or rc <= 0:
        return None
    r = oom_report(err)
    if r is None:
        return None
    code, cap, committed, req = r
    v = Verdict("OOM", out, err, rc, detail=f"out of memory: error {code} at the GC heap's hard cap of {cap} KB (-d), {committed} KB "
                                          f"committed, a request of {req} bytes -- declare heap_kb above {cap}, or cure a leak")
    v.masked_lines = masked_n
    return v


class Verdict:
    __slots__ = ("kind", "stdout", "stderr", "returncode", "detail", "masked_lines", "retry", "secs")

    def __init__(self, kind, stdout=b"", stderr=b"", returncode=None, detail=""):
        self.kind = kind  # PASS FAIL CRASH HANG UNPROVEN SKIP OOM
        self.stdout = stdout
        self.stderr = stderr
        self.returncode = returncode
        self.detail = detail
        self.masked_lines = 0
        self.retry = ""   # "retried=1 load1=<first>/<second> nproc=<n>" when a timeout under load was re-run (CEO-1335)
        self.secs = 0.0   # the program's own wall seconds in this mode (m4: compile, link and run), set by run_all_modes (CEO-1676 row (c))

    def text(self):
        return self.stdout.decode("utf-8", "replace")

    def behaviorally_equal(self, other):
        """Same shape of outcome -- used for old-vs-new byte-equal validation. CRASH must match
        the exact signal; HANG/UNPROVEN/SKIP just need the same kind; PASS/FAIL need matching text."""
        if self.kind != other.kind:
            return False
        if self.kind == "CRASH":
            return self.returncode == other.returncode
        if self.kind in ("PASS", "FAIL"):
            return self.text().rstrip("\n") == other.text().rstrip("\n")
        return True

    def __repr__(self):
        return f"Verdict({self.kind}, rc={self.returncode}, detail={self.detail!r})"


_MEM_SCOPE_MOD = None
def _mem_scope_wanted(args, paths):
    # True when cmd_run grades a corpus population -- a board by the one-runner guard's own test (CEO-547).
    return args.sno is None or _suite_is_a_board(args.sno, paths["corpus"])
class _NoMemScope:
    # A copy of this harness with no util_mem_scope.py beside it (a gate's scratch tree): no scope, no reclassification.
    @staticmethod
    def enter(kind, argv): sys.stderr.write("\u26a0 [mem_scope] no util_mem_scope.py beside this harness -- no memory scope\n")
    @staticmethod
    def oom_kills(d=None): return None
def _mem_scope():
    global _MEM_SCOPE_MOD
    if _MEM_SCOPE_MOD is None:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        try:
            import util_mem_scope as _m
        except ImportError:
            _m = _NoMemScope
        _MEM_SCOPE_MOD = _m
    return _MEM_SCOPE_MOD
# ⛔⭐ A CHILD'S OUTPUT IS BOUNDED, AND A CHILD DIES WITH ITS HARNESS (the coo 2026-10-22, COO-394; the ceo's ask at CEO-1883): a port
# entry printing in a loop through its 600 s timeout retry grew this harness to 8.15 GB anon RSS inside its 8192 MB mem scope; the kernel
# killed the HARNESS (oom-kill 03:36:05, pid 1099808 python3, request 20261022T004850-hq_jvm-sno-rungs-jvm read 59 of 100 and REFUSED rc 2),
# and the java it ran lost its reader and spun 3 h 55 min at 100% CPU with no parent until the ceo killed it. Each stream now keeps at most
# S4E_OUTPUT_CAP_MB (256, ninety times the corpus's largest ref, packages/prolog/puzzles/ALL.ref at 2.8 MB) and the child is killed the
# moment one passes it: kind OVERFLOW, a FAIL for a graded program (never retried, since no ref can match it) and no answer for an oracle,
# whose callers take every kind but RAN as none. Every child runs under setpriv --pdeathsig KILL, which execs, so the program keeps its pid
# and dies with the harness however the harness dies; setpriv's own exec failure (rc 127) is the FileNotFoundError arm it always was.
_OUTPUT_CAP = int(float(os.environ.get("S4E_OUTPUT_CAP_MB", "256")) * 1048576)
_SETPRIV = shutil.which("setpriv")
# ⭐ ONE POOL OF RUN SLOTS FOR THE WHOLE BOX (Lon 2026-10-22: "You are meant to fix the load not hurt it" · "don't flag things, fix things."; ceo
# CEO-1894): every seat may now run its own programs, so every child this harness starts takes one of S4E_RUN_SLOTS (default 8) flock slots
# under /tmp/s4e-run-slots, taken HERE before the child starts -- a wait for a slot is never counted against the child's timeout, so it can
# never read as a HANG -- and released when the child ends. A child inherits S4E_RUN_SLOT_HELD, so a harness run under another harness's slot
# takes none of its own (no nested wait, no deadlock). A full pool is WAITED ON BY RESCANNING EVERY SLOT, never by blocking on one: a harness
# that queued on slot pid%N sat 17 minutes behind a serial script holding that slot for its whole run while five other slots stood free
# (coo 2026-10-30 12:4x, the loop's xsb request; test_gate_the_run_slot_wait_rescans_every_slot_and_never_pins_one.sh). S4E_RUN_SLOT_DIR is
# the gate fixture's seam.
def _run_slot():
    if os.environ.get("S4E_RUN_SLOT_HELD"):
        return None
    import fcntl, random, time
    try:
        n = max(1, int(os.environ.get("S4E_RUN_SLOTS", "8"))); d = os.environ.get("S4E_RUN_SLOT_DIR") or "/tmp/s4e-run-slots"; os.makedirs(d, exist_ok=True)
        while True:
            for i in range(n):
                f = open(os.path.join(d, "slot%d" % i), "a")
                try:
                    fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB); return f
                except OSError:
                    f.close()
            time.sleep(0.25 + random.random() * 0.25)
    except OSError:
        return None
def _bounded_run(argv, timeout, cwd, env, stdin_bytes, merge_stderr):
    """(rc, stdout, stderr, why): why is None, "HANG" (the timeout passed, or a pipe stayed open past it) or "OVERFLOW"."""
    slot = _run_slot()
    try:
        return _bounded_run_in_slot(argv, timeout, cwd, dict(env if env is not None else os.environ, S4E_RUN_SLOT_HELD="1") if slot else env, stdin_bytes, merge_stderr)
    finally:
        if slot:
            slot.close()
def _bounded_run_in_slot(argv, timeout, cwd, env, stdin_bytes, merge_stderr):
    p = subprocess.Popen(([_SETPRIV, "--pdeathsig", "KILL", "--"] if _SETPRIV else []) + list(argv), cwd=cwd, env=env,
                         stdin=subprocess.DEVNULL if stdin_bytes is None else subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT if merge_stderr else subprocess.PIPE)
    over = threading.Event()
    def drain(f, keep):
        n = 0
        for b in iter(lambda: f.read1(1 << 16), b""):
            if n < _OUTPUT_CAP:
                keep.append(b[:_OUTPUT_CAP - n])
            n += len(b)
            if n > _OUTPUT_CAP and not over.is_set():
                over.set()
                p.kill()
        f.close()
    def feed(f):
        try:
            f.write(stdin_bytes)
            f.close()
        except (BrokenPipeError, OSError):
            pass
    outs, errs = [], []
    drains = [threading.Thread(target=drain, args=(f, k), daemon=True) for f, k in ((p.stdout, outs), (p.stderr, errs)) if f is not None]
    ts = drains + ([threading.Thread(target=feed, args=(p.stdin,), daemon=True)] if p.stdin is not None else [])
    for t in ts:
        t.start()
    deadline = time.monotonic() + timeout
    # a timer kills at the limit while the wait blocks: p.wait(timeout=) polls, and its sleeps cost 0.9 ms a run (true: 0.64 ms bare, 1.53 polled)
    fired = threading.Event()
    def expire():
        fired.set()
        p.kill()
    timer = threading.Timer(timeout, expire)
    timer.daemon = True
    timer.start()
    try:
        rc = p.wait()
    except BaseException:
        p.kill()
        p.wait()
        raise
    finally:
        timer.cancel()
    hung = fired.is_set()
    for t in ts:
        t.join(max(0.0, deadline - time.monotonic()) if not hung else 5)
    hung = hung or any(t.is_alive() for t in drains)
    return rc, b"".join(outs), b"".join(errs), ("OVERFLOW" if over.is_set() else "HANG" if hung else None)
def _run_raw(argv, timeout, cwd=None, env=None, stdin_text=None, merge_stderr=False):
    # ⛔ A PROGRAM THE CGROUP MEMORY CAP KILLED IS UNPROVEN, NEVER A CRASH (row instrument-698-runners-..., the ceo's clause): a
    # SIGKILL alone cannot say who sent it, so the enclosing scope's own oom_kill count is read on both sides of the run and only
    # a rise converts the kill. Outside any s4e-mem scope the count is None and nothing changes.
    _ms = _mem_scope()
    _k0 = _ms.oom_kills()
    # ⭐ merge_stderr: the unit's answer is stdout and stderr as ONE stream, interleaved as the shell's `> out 2>&1` writes it --
    # the contract of a package whose own harness cut its refs that way (ALL.csv's stderr column, read_command_line_columns).
    try:
        rc, out, err, why = _bounded_run(argv, timeout, cwd, env, None if stdin_text is None else stdin_text.encode(), merge_stderr)
    except FileNotFoundError as e:
        return "UNPROVEN", b"", str(e).encode(), None
    if why == "OVERFLOW":
        return "OVERFLOW", out, err + b"\n[harness] output passed the S4E_OUTPUT_CAP_MB bound of %d bytes; the child was killed\n" % _OUTPUT_CAP, None
    if why == "HANG":
        return "HANG", out, err, None
    if rc == 127 and _SETPRIV and (err or out)[:200].startswith(b"setpriv: failed to execute"):
        return "UNPROVEN", b"", (err or out).split(b"\n")[0], None
    if rc == -9 and _k0 is not None:
        _k1 = _ms.oom_kills()
        if _k1 is not None and _k1 > _k0:
            return "UNPROVEN", out, _ms.kill_detail(_k1 - _k0).encode(), None
    return "RAN", out, err, rc


# ============================================================ CEO-409 line masks ===
# ⛔⭐ AN IMPLEMENTATION-DEFINED LINE IS MASKED AT THE LINE, NEVER AT THE PROGRAM (ceo CEO-409, 2026-09-08;
# RULES.md, on the coo and hq_V reaching the same fixture from opposite directions and both refusing to move a
# denominator alone). A fixture whose ONLY divergence is a value belonging to the IMPLEMENTATION -- a clock
# reading, an allocator's free-space count -- is neither outside the baseline (the oracle runs it perfectly)
# nor a permanent red (there is no defect, and it can never go green, which is a criterion that cannot say YES).
# It stays in the denominator and is graded on every line that carries language semantics.
#
# ⛔ THIS IS A MACHINE FOR HIDING REDS AND IS BUILT ACCORDINGLY. Four guardrails, all mechanical here:
#   (1) EARNED BY MEASUREMENT, never by assertion -- the mask lives in a sidecar a human wrote after showing the
#       ORACLE'S OWN value moves between runs; this code cannot check that, so the sidecar carries the REASON
#       and the record is auditable. A mask with an empty reason is REFUSED below rather than silently honoured.
#   (2) NAMED BESIDE THE DATA -- `ALL.mask` sits next to `ALL.ref`, never inside a runner.
#   (3) COUNTED AND PRINTED -- masked_lines rides on the Verdict so every board can print what it declined to
#       grade. An invisible mask is the hiding mechanism; a printed one is a measurement.
#   (4) NEVER THE MAJORITY -- if a mask would cover half a fixture's lines or more, that fixture is ungradable
#       and belongs outside the baseline instead, named. Enforced as a FAIL with its own detail, not a pass.
#
# ⭐ THE SUBSTITUTION REPLACES, IT NEVER DELETES. A deleted line would let a MISSING line pass as a masked one --
# the fixture that prints nothing would match the fixture that prints a clock. Line count and position are
# preserved by rewriting the matched line to a canonical marker in BOTH streams.
def read_mask_sidecar(ref_path):
    """<stem>.mask beside the ref: `entry<TAB>python-regex<TAB>reason[<TAB>engine=NAME[,NAME]]` (the qualifier, CEO-1864 (1), keeps a
    row from every engine it does not name), or `entry<TAB>L<n><TAB>reason` for a
    fixed OUTPUT line number (1-indexed), when content alone cannot reach the value (CEO-1167 ruling on
    gc2.icn): apply_line_mask sees one line at a time, with no neighbor and no position, so a value sharing
    its digit alphabet with legitimate surrounding output cannot be isolated by a content regex without also
    matching most of the file, which guardrail 4 correctly refuses. Missing file -> no masks, and that is
    the overwhelmingly common case: seven rung suites and every package carry none today."""
    mp = Path(str(ref_path).rsplit(".", 1)[0] + ".mask")
    if not mp.is_file():
        return {}
    out = {}
    for ln in mp.read_text(encoding="utf-8").splitlines():
        if not ln.strip() or ln.lstrip().startswith("#"):
            continue
        parts = ln.split("\t")
        if len(parts) < 3 or not parts[1].strip() or not parts[2].strip():
            # ⛔⭐ refuse(), NOT raise SystemExit(<string>) -- THE SENTENCE SAID rc=2 AND THE PROCESS EXITED 1
            # (hq_T 2026-09-08, found by calling this from a bash runner that keys on the code). SystemExit with a
            # STRING argument prints it and exits ONE, so this refusal was indistinguishable from a measured RED to
            # every caller that reads the status instead of the text -- and the status is what a gate reads.
            # ⭐ THE GENERAL FORM: a diagnostic that NAMES its own exit code is not evidence it uses that code, and
            # it is the most convincing possible evidence to a reader, because the number is right there. This file's
            # refuse() is the one authority (CEO-233, one refusal code and it is 2); the local raise bypassed it.
            refuse("%s: every mask row needs entry<TAB>regex-or-L<n><TAB>reason, and a reason that "
                   "is empty is a mask nobody can audit -- got %r" % (mp, ln))
        # ⭐ THE ENGINE QUALIFIER (ceo CEO-1864 (1), 2026-10-21, to hq_dotnet; landed by the coo on CEO-1872): an optional fourth column
        # engine=NAME[,NAME] offers the row only to the engines it names (S4E_ENGINE, scrip by default); a row without one is every engine's.
        # testpgms test1's six CEO-1293 rows are SCRIP's (SCRIP keeps VALUE, sbl and snobol4dotnet raise error 22, CEO-1858 (3)), so they carry
        # engine=scrip and a port that answers as sbl does is graded on the oracle's whole stream. A name no engine has, or any other fourth
        # column, is refused: a typo would silently offer a mask to nobody, or to everybody.
        if len(parts) > 3 and parts[3].strip():
            em = re.match(r"^engine=([a-z0-9]+(?:,[a-z0-9]+)*)$", parts[3].strip())
            if not em or any(n not in ENGINES for n in em.group(1).split(",")):
                refuse("%s: a mask row's fourth column is engine=NAME[,NAME] with each NAME one of %s (ceo CEO-1864 (1)) -- got %r"
                       % (mp, ", ".join(ENGINES), ln))
            if _engine() not in em.group(1).split(","):
                continue
        pat = parts[1].strip()
        m = re.match(r"^L(\d+)$", pat)
        # ⭐ ORACLE-ONLY:<exact line> (ceo CEO-1316 (2), 2026-09-27, on Lon's "I want to see TPgm go to 8/8"): the one mask kind that
        # REMOVES a line, and only from the ORACLE's stream -- a line the oracle prints and we never do, because we keep an enhancement
        # the oracle lacks (CEO-1293: Lon's "Keep the VALUE function we like new features"; testpgms test1's statement-137 trap).
        # Replace-never-delete cannot reach a line one side lacks. Matched by EXACT text (never a regex), ONE occurrence, counted like
        # every mask; our side is never touched, so a missing or extra line of ours still reds. Scoped to the CEO-1293 class: a row
        # whose reason does not cite CEO-1293 is refused, and the never-delete guardrail binds every other kind.
        # ⭐ ORACLE-IDENTITY (ceo CEO-1344/CEO-1351, 2026-09-28): a row whose reason cites CEO-1344 masks a line naming the ORACLE ITSELF
        # (HOST()'s "x86-64:unix :Macro SPITBOL 15.01"), the same class as the memory lines -- no program computes it and SCRIP does not
        # impersonate it. Its lines do not count toward guardrail 4's half (mask_majority), so it must be a content regex: a positional
        # L<n> or an ORACLE-ONLY deletion could reach a line of the program's own output, which is what the half exists to protect.
        if ORACLE_IDENTITY_RULING in parts[2] and (pat.startswith("ORACLE-ONLY:") or re.match(r"^L\d+$", pat)):
            refuse("%s: a row citing %s is an ORACLE-IDENTITY mask, exempt from guardrail 4, and is admitted only as a content regex "
                   "over the identity line -- never L<n> or ORACLE-ONLY (ceo CEO-1351); got %r" % (mp, ORACLE_IDENTITY_RULING, ln))
        if pat.startswith("ORACLE-ONLY:"):
            if "CEO-1293" not in parts[2]:
                refuse("%s: an ORACLE-ONLY row removes a line from the oracle's stream and is admitted only for a kept "
                       "enhancement the oracle lacks (ceo CEO-1293, CEO-1316 (2)) -- its reason must cite CEO-1293; got %r" % (mp, ln))
            key = ("oracle_only", parts[1][len("ORACLE-ONLY:"):].rstrip("\r"))
        else:
            key = ("line", int(m.group(1))) if m else ("regex", re.compile(pat))
        out.setdefault(parts[0].strip(), []).append((key, parts[2].strip()))
    return out
ORACLE_IDENTITY_RULING = "CEO-1344"
def mask_guard_patterns(patterns):
    """The rows guardrail 4 counts: every row but an ORACLE-IDENTITY one (reason cites CEO-1344, ceo CEO-1351)."""
    return [p for p in (patterns or []) if ORACLE_IDENTITY_RULING not in p[1]]
def mask_majority(lines, masked_n, guard_n):
    """⛔ CEO-409 GUARDRAIL 4, THE ONE RULE (classify here, and the bash runners through util_apply_ceo409_mask.py's .major): a fixture is
    UNGRADABLE when the rows guardrail 4 counts mask half its lines or more, or when every line is masked by any row. With no
    ORACLE-IDENTITY row guard_n == masked_n and this is exactly the old `masked_n * 2 >= lines`. ⭐ CEO-1351: an ORACLE-IDENTITY line
    is the oracle's own state, so it does not count toward the half -- host.spt's two lines grade on host(0) with the HOST() line
    masked -- but at least one line must stay unmasked, or nothing is graded at all."""
    return bool(lines) and (guard_n * 2 >= lines or masked_n >= lines)
def masks_for(masks, name):
    """⛔⭐ THE ONE PLACE THE ENTRY COLUMN IS RESOLVED, so the python harness and the bash runners (through
    util_apply_ceo409_mask.py) cannot disagree about which rows apply to an entry.  `*` in the entry column means
    EVERY entry of the suite, which is what a suite-wide sidecar needs: the csnobol4 ALL.mask masks SPITBOL's own
    allocator bookkeeping, a quantity no program in the suite can compute, so naming 93 programs one per row would
    be a census that goes stale on the next program added -- and a mask that has silently stopped covering a new
    entry is the same unauditable shape CEO-409 exists against.
    ⛔ THE WILDCARD DOES NOT WEAKEN A GUARDRAIL. Every masked line is still counted per entry, the majority rule
    still fails a fixture that would be mostly masked, and the reason column is still mandatory -- `*` widens WHICH
    entries a row is offered to, never WHAT a row is allowed to hide."""
    return list(masks.get("*", [])) + list(masks.get(name, []))
def apply_line_mask(text, patterns, side="both"):
    """Rewrite every line matching any pattern to a canonical marker. A ("regex", rx) pattern matches by
    content against the line; a ("line", n) pattern matches by OUTPUT POSITION against line n (1-indexed),
    regardless of content -- see read_mask_sidecar's L<n> form. An ("oracle_only", text) pattern REMOVES the first
    line exactly equal to text, and only when side == "oracle" -- the stream is the oracle's; on our side, or when a
    caller names no side, it does nothing (see read_mask_sidecar). Positional L<n> rows are applied before any
    removal, so a line number always means the stream as the engine printed it. Returns (text, masked_line_count)."""
    if not patterns or text is None:
        return text, 0
    n = 0
    lines = text.split("\n")
    for i, ln in enumerate(lines):
        for key, _reason in patterns:
            kind, val = key
            if kind == "oracle_only":
                continue
            if val.search(ln) if kind == "regex" else (val == i + 1):
                lines[i] = "<<CEO-409 MASKED IMPLEMENTATION-DEFINED LINE>>"
                n += 1
                break
    if side == "oracle":
        for key, _reason in patterns:
            kind, val = key
            if kind == "oracle_only" and val in lines:
                del lines[lines.index(val)]
                n += 1
    return "\n".join(lines), n
# ⛔⭐ A SPITBOL FATAL IS GRADABLE (hq_snobol4's measurement 2026-09-27, the cfo seconding, ceo CEO-1344, the coo's row
# instruments-a-spitbol-fatal-is-gradable-...): x64 sbl -bf prints its FATAL BLOCK ON STDOUT as well as stderr, so a ref cut from
# the oracle for a program that ends in a fatal carries the block, and SCRIP -- whose ONE error voice goes to stderr -- could never
# match it: every such program (Budne tab.sno, rewind1.sno; Dotnet 1brc.sno, asgn1.sno; SnoRungs simple_output_62,
# user_function_arbno_rpos_1) was ungradable by construction. THE ONE READER renders SCRIP's stderr error block through
# util_render_error_voice.py's spitbol list into sbl's block shape and appends it to SCRIP's stdout BEFORE the compare; the runtime
# keeps its one voice (no SPITBOL text enters src/), the ref stays the oracle's word, and the run-summary lines sbl prints after
# the block (stmts executed, execution time msec, REGENERATIONS, memory used, memory left) are oracle-internal state masked by
# the suite's ALL.mask beside the data. The voice is set by the suite reader from the suite's language (the SNOBOL4 family:
# snobol4, snocone -- rebus has no oracle); S4E_FATAL_RENDER=0 is the gate's fail-once seam and nothing else's.
FATAL_RENDER = {"voice": None}
FATAL_REF_LINE = re.compile(r"^.*\(\d+\) : ERROR \d{3} -- ", re.M)   # the oracle's fatal line as sbl -bf prints it


def _fatal_render_voice_for(lang):
    return "spitbol" if lang in ("", "snobol4", "snocone") else None


# ⭐ A MERGED ENTRY IS RENDERED AS ITS BOARD RENDERS IT (the coo 2026-10-01, measured on jcon traceback and loadfunc): an entry whose
# stderr cell reads "merged" carries SCRIP's ONE error voice inside the graded stream itself, and its ref pins the oracle's shape;
# test_icon_jcon_suite.sh pipes the merged capture through util_render_error_voice.py icon before its diff, so the harness renders
# the same stream through the same list -- icon: render(), every SCRIP block in the oracle's shape; the SNOBOL4 family:
# replace_fatal_in_text(merged=True), as a merged 2>&1 capture of sbl -bf reads. Unrendered, both programs read FAIL here while
# the board read them PASS. Set beside the fatal voice from the suite's language; S4E_FATAL_RENDER=0 turns both off.
def _merged_render_voice_for(lang):
    return "icon" if lang == "icon" else ("spitbol" if lang in ("", "snobol4", "snocone") else None)


def _render_merged_stream(got):
    voice = FATAL_RENDER.get("merged_voice")
    if not voice or os.environ.get("S4E_FATAL_RENDER") == "0":
        return got
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import util_render_error_voice as _rv
    except Exception as e:
        refuse(f"util_render_error_voice.py is not importable ({e}) -- the equivalence list is the ONE renderer, never reimplemented here")
    lines = got.split("\n")
    return "\n".join(_rv.replace_fatal_in_text(lines, voice, True) if voice == "spitbol" else _rv.render(lines, voice))


def _render_fatal_into_stdout(got, err_bytes):
    """Append SCRIP's rendered error block (if stderr holds one) to the graded stdout text. Returns (text, n_lines_appended)."""
    voice = FATAL_RENDER.get("voice")
    if not voice or os.environ.get("S4E_FATAL_RENDER") == "0":
        return got, 0
    err_lines = err_bytes.decode("utf-8", "replace").split("\n")
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import util_render_error_voice as _rv
    except Exception as e:
        refuse(f"util_render_error_voice.py is not importable ({e}) -- the equivalence list is the ONE renderer, never reimplemented here")
    i = 0; block = []
    while i < len(err_lines):
        if _rv.HEAD.match(err_lines[i]):
            j = i + 1
            while j < len(err_lines) and err_lines[j].startswith("  "):
                j += 1
            block = err_lines[i:j]
            break
        i += 1
    if not block:
        return got, 0
    rendered = _rv.render_fatal_block(block, voice) if hasattr(_rv, "render_fatal_block") else _rv.render(block, voice)
    if not rendered:
        return got, 0
    text = (got + "\n" if got else "") + "\n".join(rendered)
    return text, len(rendered)


def _timeout_load():
    """(the 1-minute load, the cores) as the fan-out reads them -- lib_fanout's FANOUT_PROC seam plants a loadavg for the gate."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    try:
        import lib_fanout as _lf
        return _lf.fanout_load1(), _lf.fanout_cores()
    except Exception:
        return 0.0, os.cpu_count() or 1


def classify(argv, timeout, expected_text, cwd=None, env=None, stdin_text=None, want_rc=0, mask=None, out_files=None, merge_stderr=False, ws_blind=False, answer_file=None):
    # ⛔ A TIMEOUT UNDER LOAD MEASURED THE SCHEDULER, NOT THE PROGRAM (ceo CEO-1335; the coo 2026-10-09): at load 39 two Prolog rung
    # entries that run in 0.1 to 0.6 s read m4 TIMEOUT, and at load ~25 pass 42's RakBench lost point_class_add's iter angle the same
    # way. When a program times out while the 1-minute load exceeds the cores, the reading is COULD NOT MEASURE: the program is run
    # ONCE more (this harness runs one child at a time, so the retry is serial within it), and only a second timeout grades HANG.
    # The verdict carries retried=1 and the load at both attempts into its progress row. A timeout at or under the cores is graded
    # as before -- a timeout scaled by load is NOT the cure (it would hide a real hang at high load). S4E_TIMEOUT_RETRY=0 disables
    # the retry (the gate's fail-once arm).
    v = _classify_run(argv, timeout, expected_text, cwd=cwd, env=env, stdin_text=stdin_text, want_rc=want_rc, mask=mask,
                      out_files=out_files, merge_stderr=merge_stderr, ws_blind=ws_blind, answer_file=answer_file)
    # ⛔⭐ SUPERSEDED IN PART (Lon 2026-10-15 15:3x CDT, in-chat to the coo, verbatim: "So timeout SHOULD NOT count as valid." and "The
    # strategy should be to accumulate a list of timeouts, and do a retry with longer timeouts."): EVERY timeout is retried once,
    # whatever the load, at lib_timeout_retry.longer(timeout) -- six times the first limit, capped at 600 s -- and only a timeout at
    # that longer limit grades HANG. Measured: the logtalk_iso pass on 52f822b69 graded 344 m4 timeouts red at load 19-21 on 16 cores.
    if v.kind != "HANG" or os.environ.get("S4E_TIMEOUT_RETRY", "1") == "0":
        return v
    l1, n = _timeout_load()
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import lib_timeout_retry as _ltr
    at = _ltr.longer(timeout)
    v2 = _classify_run(argv, at, expected_text, cwd=cwd, env=env, stdin_text=stdin_text, want_rc=want_rc, mask=mask,
                       out_files=out_files, merge_stderr=merge_stderr, ws_blind=ws_blind, answer_file=answer_file)
    l2, _n = _timeout_load()
    v2.retry = "retried=1 load1=%.2f/%.2f nproc=%d at=%gs" % (l1, l2, n, at)
    if v2.kind == "HANG":
        v2.detail = "timed out twice: exceeded %ss, then %gs on the retry (load %.2f then %.2f on %d cores)" % (timeout, at, l1, l2, n)
    return v2


def _classify_run(argv, timeout, expected_text, cwd=None, env=None, stdin_text=None, want_rc=0, mask=None, out_files=None, merge_stderr=False, ws_blind=False, answer_file=None):
    _out_files_clear(cwd, out_files)
    if answer_file:
        _out_files_clear(cwd, [answer_file])
    kind, out, err, rc = _run_raw(argv, timeout, cwd=cwd, env=env, stdin_text=stdin_text, merge_stderr=merge_stderr)
    out = _out_files_append(out, cwd, out_files) if out_files else out
    if answer_file:
        # ⭐ THE ANSWER IS A FILE THE PROGRAM WRITES, SORTED (ceo CEO-1927; XSB's gentest.sh: `[FILE]. tell(temp). CMD. told.`, then `sort temp`):
        # ALL.csv's answer column reads temp-sorted for an entry whose own harness grades the file it writes (wfs_tests' test/1 opens temp
        # itself). The file is deleted before every run (m3, m4) and its non-empty lines, sorted, are the graded output; stdout is not.
        _af = Path(cwd) / answer_file
        out = (("\n".join(sorted(l for l in _af.read_bytes().decode("utf-8", "replace").split("\n") if l != "")) + "\n").encode()
               if _af.is_file() else f"<<answer file {answer_file} was not written>>\n".encode())
    if kind == "HANG":
        return Verdict("HANG", out, err, None, detail=f"exceeded {timeout}s")
    if kind == "OVERFLOW":
        return Verdict("FAIL", out, err, None, detail=f"output passed the S4E_OUTPUT_CAP_MB bound of {_OUTPUT_CAP} bytes; the child was killed")
    if kind == "UNPROVEN":
        return Verdict("UNPROVEN", out, err, None, detail=err.decode("utf-8", "replace"))
    if rc is not None and rc < 0:
        return Verdict("CRASH", out, err, rc, detail=f"signal {-rc}")
    return _grade_output(out, err, rc, expected_text, want_rc=want_rc, mask=mask, merge_stderr=merge_stderr, ws_blind=ws_blind)


FRESH_VAR_RX = re.compile(r"(?<![A-Za-z0-9_])_[A-Za-z]?[0-9]+(?![A-Za-z0-9_])")
def _mask_error_context(ln):
    """Every error(E, C) on the line with C replaced by `_CTX`, brackets balanced, quoted atoms skipped; E is kept verbatim."""
    out, i, n = [], 0, len(ln)
    while True:
        j = ln.find("error(", i)
        if j < 0:
            out.append(ln[i:])
            return "".join(out)
        if j > 0 and (ln[j - 1].isalnum() or ln[j - 1] == "_"):
            out.append(ln[i:j + 6]); i = j + 6
            continue
        k, depth, comma, q = j + 6, 1, -1, ""
        while k < n and depth > 0:
            c = ln[k]
            if q:
                if c == "\\": k += 1
                elif c == q: q = ""
            elif c in "'\"`": q = c
            elif c in "([{": depth += 1
            elif c in ")]}": depth -= 1
            elif c == "," and depth == 1 and comma < 0: comma = k
            k += 1
        if comma < 0 or depth:
            out.append(ln[i:k]); i = k
            continue
        out.append(ln[i:comma + 1] + "_CTX)"); i = k
def _grade_output(out, err, rc, expected_text, want_rc=0, mask=None, merge_stderr=False, ws_blind=False):
    """The grade of a process that ended (no hang, no signal): its stdout against the ONE ref through the masks and the one error voice,
    its rc against the declared want_rc. Shared by every run and by a mode-4 compile refusal (CEO-1354), so the two cannot disagree."""
    got = out.decode("utf-8", "replace").rstrip("\n")
    if merge_stderr:
        got = _render_merged_stream(got)
    # ⛔ RENDER ONLY WHAT THE REF CARRIES: the block is appended when the oracle's ref itself holds a fatal line (`<file>(<n>) : ERROR
    # nnn -- ...`). A ref cut without one (snocone ladder__rung23_..._stlimit_halts_a_loop_body: ref `before`, want_rc 1, the halt
    # graded by rc alone) must not gain a block it never had -- the first rung suites pass after the render landed read that entry
    # FAIL and wrote SncRungs 337/338 on 8c81190b7, a false red of this instrument (coo 2026-09-28 11:0x), restored the same hour.
    if rc is not None and rc != 0 and expected_text is not None and FATAL_REF_LINE.search(expected_text):
        got, _fatal_n = _render_fatal_into_stdout(got, err)
        # THE rc CLAUSE OF THE SAME LIST (measured 2026-09-28): sbl -bf EXITS 0 after a run-time fatal, SCRIP's one voice exits 1;
        # an entry whose ref was cut from the oracle declares want_rc 0, so a rendered fatal at rc 1 is the declared rc.
        if _fatal_n and rc == 1 and want_rc == 0:
            want_rc = 1
    exp = expected_text.rstrip("\n") if expected_text is not None else None
    masked_n = 0
    if mask:
        exp_lines = len(exp.split("\n")) if exp is not None else 0
        _gp = mask_guard_patterns(mask)
        guard_n = max(apply_line_mask(got, _gp, side="scrip")[1], apply_line_mask(exp, _gp, side="oracle")[1])
        got, mg = apply_line_mask(got, mask, side="scrip")
        exp, me = apply_line_mask(exp, mask, side="oracle")
        masked_n = max(mg, me)
        if mask_majority(exp_lines, masked_n, guard_n):
            return Verdict("FAIL", out, err, rc, detail="mask covers %d of %d ref lines -- a majority-masked fixture is "
                           "UNGRADABLE and belongs outside the baseline, named, not masked (CEO-409 guardrail 4)"
                           % (masked_n, exp_lines))
    # ⛔⭐ A POSITIVE NONZERO rc IS NOT A PASS UNLESS IT WAS DECLARED (hq_C ruling 2026-08-30, on seat15's
    # find; corpus-suites-consolidation.task.md § VACUOUS PASS ON POSITIVE rc). Until now only a NEGATIVE rc
    # was inspected (the CRASH arm above) and a positive one fell straight through to the text compare. The
    # witness: snobol4 `simple_output_63` ends in lowercase `end`, SCRIP rejects it rc=1 with the diagnostic
    # on STDERR, stdout is empty, and its .ref is EMPTY -- so got == exp == "" and it scored PASS on every
    # run since it was absorbed, reported as a promotable XPASS. A program that cannot compile was passing.
    # ⛔ A BLANKET rc==0 REQUIREMENT WOULD BE WRONG, and that is why this is declared and not inferred:
    # prolog's assertz_directive_2/3/4 and asserta_assertz_directive_1 PASS with NON-EMPTY matching refs and
    # rc=1 BY DESIGN -- the failure-driven-loop family (ARCH-LANGUAGES.md § FAILURE-DRIVEN LOOP WITH NO
    # FALLBACK CLAUSE). Blanket-gating turns four correct entries red. Blast radius censused before landing:
    # snobol4 1 (the defect), prolog 4 (declared below), and ZERO in icon/raku/rebus/snocone/pascal (seat15).
    # ⭐ Declared-not-derived, same principle as the `modes` column: "rc!=0 plus an empty ref" is a heuristic
    # that is right on today's two languages and silently wrong on the next one.
    # ⭐ A PACKAGE WHOSE OWN HARNESS COMPARES IGNORING WHITESPACE IS GRADED THAT WAY (ceo CEO-1927; RULES.md § Oracles, FACT RULE XSB IS THE THIRD
    # PROLOG ORACLE): XSB's gentest.sh diffs its sorted answer with `diff -w`, all white space within a line ignored (XSB writes `p06 : p` where
    # SCRIP writes `p06:p`). ALL.csv's compare column reads ignore-all-space for such an entry (read_command_line_columns); lines still count.
    # ⭐ A FRESH VARIABLE'S PRINTED NAME IS THE IMPLEMENTATION'S (ISO/IEC 13211-1 7.10.5: `_` followed by an implementation-dependent name):
    # swipl writes `_5292`, XSB `_h5292`, SCRIP `_G0`. ALL.csv's compare column carries fresh-vars for an entry whose ref prints such a name; each
    # line's names are renamed `_V1`, `_V2`, ... in order of first appearance in both streams, so two distinct variables still read distinct and
    # one variable printed twice on a line still reads the same.
    # ⭐ AN ERROR TERM'S CONTEXT IS THE IMPLEMENTATION'S (ISO/IEC 13211-1 7.12.1: error(E, Imp_def)): swipl's names its own frames --
    # context(system:catch/3,_), context('$bags':findall_loop/4,_), the caller left after last-call optimisation -- which no other system
    # reproduces. error-context grades every error(E, C) with C replaced by one marker in both streams; E is still compared exactly.
    _toks = set(ws_blind.split("+")) if isinstance(ws_blind, str) else ({"ignore-all-space"} if ws_blind is True else set())
    _vars, _ectx, _ws = "fresh-vars" in _toks, "error-context" in _toks, "ignore-all-space" in _toks
    def _norm(t):
        out = []
        for ln in t.split("\n"):
            if _vars:
                seen = {}
                ln = FRESH_VAR_RX.sub(lambda m: seen.setdefault(m.group(0), "_V%d" % (len(seen) + 1)), ln)
            if _ectx:
                ln = _mask_error_context(ln)
            out.append("".join(ln.split()) if _ws else ln)
        return out
    _same = exp is not None and (got == exp or (bool(ws_blind) and _norm(got) == _norm(exp)))
    if _same:
        if rc is not None and rc != want_rc:
            return _oom_verdict(out, err, rc, masked_n) or Verdict("FAIL", out, err, rc,
                           detail=f"output matched but rc={rc}, expected {want_rc} (declare want_rc if this is correct)")
        v = Verdict("PASS", out, err, rc)
        v.masked_lines = masked_n
        return v
    # ⭐ OOM BEFORE FAIL (CEO-1229 (2)): a run that did not answer and ended in the runtime's own out-of-memory report is that report.
    oom = _oom_verdict(out, err, rc, masked_n)
    if oom is not None:
        return oom
    v = Verdict("FAIL", out, err, rc, detail="output mismatch" if exp is not None else "no expected text")
    v.masked_lines = masked_n
    return v


def stdbuf_wrap(paths, argv):
    if paths["stdbuf_bin"]:
        return [paths["stdbuf_bin"], "-o0", "-e0"] + argv
    return argv


def run_m3(paths, sno_path, expected_text, timeout=None, stdin_text=None, want_rc=0, prog_argv=None, mask=None, heap_kb=None, stack_kb=None, compile_args=None, out_files=None, merge_stderr=False, ws_blind=False, answer_file=None):
    timeout = timeout or paths["timeout"]
    # ⛔⭐ ARGV IS THE BARE NAME, NOT THE FULL PATH (row suite-harness-argv-echoes-a-mktemp-path-so-
    # diagnostic-programs-cannot-be-graded) -- a diagnostic that echoes its own argv (e.g. a SPITBOL
    # ERROR NNN line naming the file) would otherwise embed this run's own ever-changing mktemp
    # directory, which no frozen .ref can ever match. cwd (set below) is what makes the bare name
    # still resolve to the right file.
    if paths["engine"] != "scrip":
        return classify(_engine_argv(paths, sno_path, prog_argv, heap_kb, stack_kb), timeout, expected_text, cwd=str(Path(sno_path).parent),
                        env=dict(os.environ, SNO_LIB=str(paths["inc"])), stdin_text=stdin_text, want_rc=want_rc, mask=mask,
                        out_files=out_files, merge_stderr=merge_stderr, ws_blind=ws_blind, answer_file=answer_file)
    argv = stdbuf_wrap(paths, [str(paths["scrip_bin"]), "--run"] + _compile_switches(paths, compile_args) + _size_switches(heap_kb, stack_kb) + _host_u_switch(sno_path, prog_argv) + [Path(sno_path).name])
    # ⛔⭐ THE `--` SEPARATOR IS MANDATORY AND IS WHAT MAKES THIS SAFE. The driver has NO unknown-flag
    # diagnostic: any unrecognised argument falls through to being treated as a FILENAME, so a declared
    # program argument spelled like a flag (`-n10`, the exact shape the first witness used) would be
    # eaten by the driver as a second source file rather than reaching the program. Everything after
    # `--` is the program's own argv -- verified live: `scrip p.icn -- -n10 foo` -> argc=2, both args in
    # order. Empty/None prog_argv appends NOTHING, not a bare `--`, so every existing caller's argv is
    # byte-identical to what it was before this parameter existed.
    if prog_argv:
        argv = argv + ["--"] + [str(a) for a in prog_argv]
    env = dict(os.environ, SNO_LIB=str(paths["inc"]))
    # ⛔⭐ THE DECLARED ARENA IS EXPORTED HERE, FOR THIS PROGRAM ONLY (Lon 2026-09-23, "each test
    # should have the needed amount of memory in the attribute TSV/CSV files"; CEO-1167). heap_kb
    # None means the cell was empty, and an empty cell is the SHIPPED DEFAULT -- so the env of an
    # undeclared program is byte-identical to what it was before this parameter existed, which is
    # what keeps this from being a fleet-wide re-grade wearing a reader's name.
    # ⭐ THE DECLARED HEAP AND STACK ARE ON THE COMMAND LINE (-d -i -s, _size_switches above), no longer in env: the cto's switch
    # row (CEO-1225) made SCRIP read them as SPITBOL does, and a switch is recorded with the run where an env knob is not.
    # ⛔⭐ cwd IS THE SOURCE FILE'S OWN DIRECTORY, NOT THE HARNESS'S. A corpus program's relative
    # opens (Icon `open("X")`, and any read of a data companion) resolve against the RUNNING file's
    # directory -- that is how a loose file is run by hand and by test_corpus_snobol4.sh. Without
    # this the harness ran every original from wherever the caller happened to stand, so a program
    # with a data companion FAILED the convert-blocks "original not green" pre-check and could never
    # be converted. ⛔ AND THE MESSAGE BLAMED THE WRONG THING: "original file itself is not green"
    # points the reader at the corpus file, which is green -- measured on rung36_jcon_fncs1.icn,
    # byte-identical to its .ref when run from its own directory in BOTH modes, FAIL in both from
    # anywhere else. Consistent for suite entries too: run_suite_entry materializes the entry into a
    # temp dir and passes THAT path, so parent is the temp dir -- exactly where it copies companions.
    return classify(argv, timeout, expected_text, cwd=str(Path(sno_path).parent), env=env, stdin_text=stdin_text, want_rc=want_rc, mask=mask, out_files=out_files, merge_stderr=merge_stderr, ws_blind=ws_blind, answer_file=answer_file)


def _engine_argv(paths, sno_path, prog_argv, heap_kb, stack_kb):
    """THE PORT ARM OF run_m3 (CEO-1822): a port engine's program runs through its own runner script beside this file, called the way scrip
    --run is: bash run_<engine>.sh [-dNk] [-sNk] [-u STR] <name> [-- argv]. The runner maps the SPITBOL-shaped switches onto its engine and
    adds the language flags the refs were cut under; the unit's compile_args are SCRIP's own switches (--stlimit, clause 8 (f)) and are not
    passed, since SPITBOL and the ports always count statements. cwd, stdin, masks, want_rc and the refs are run_m3's, shared with SCRIP."""
    argv = ["bash", str(HARNESS_SCRIPTS / ENGINE_RUNNERS[paths["engine"]])] + _size_switches(heap_kb, stack_kb) \
        + _host_u_switch(sno_path, prog_argv) + [Path(sno_path).name]
    if prog_argv:
        argv = argv + ["--"] + [str(a) for a in prog_argv]
    return stdbuf_wrap(paths, argv)


def compile_m4(paths, sno_path, out_bin, tmp_dir, compile_args=None):
    """Mirrors compile_mode4() in test_corpus_snobol4.sh exactly. Returns None on success, or a
    Verdict("SKIP", ...) describing where it failed."""
    s_path = tmp_dir / "p.s"
    env = dict(os.environ, SNO_LIB=str(paths["inc"]))
    sno_path = Path(sno_path)
    # ⛔⭐ SAME FIX AS run_m3, AND THIS CALL HAD NO cwd AT ALL BEFORE (ran from the harness's own cwd,
    # only "working" because argv carried a full path) -- row suite-harness-argv-echoes-a-mktemp-path-
    # so-diagnostic-programs-cannot-be-graded. Bare name in argv, explicit cwd so it still resolves
    # and so a -INCLUDE (compile-time, unlike run_m3's runtime open() concern) resolves relative to
    # the file's own directory too, not wherever the caller happened to stand.
    with open(s_path, "wb") as f:
        r = subprocess.run([str(paths["scrip_bin"]), "--compile"] + _compile_switches(paths, compile_args) + [sno_path.name],
                            stdout=f, stderr=subprocess.PIPE, env=env, cwd=str(sno_path.parent))
    if r.returncode != 0:
        return Verdict("SKIP", stderr=r.stderr or b"", returncode=r.returncode, detail="scrip --compile failed")
    o_path = tmp_dir / "p.o"
    r = subprocess.run(["gcc", "-c", str(s_path), "-o", str(o_path)],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd=str(paths["scrip_root"]))
    if r.returncode != 0:
        return Verdict("SKIP", detail="gcc -c failed")
    rt_dir = str(paths["rt_dir"])
    # ⛔⭐ RULED -- -no-pie STAYS OUT, DELIBERATELY, NOT AN OVERSIGHT (row `m4-pie-vs-no-pie-changes-behaviour-
    # not-just-signal`, seat10 2026-08-28, full analysis + evidence in .github/ARCH-ENGINE.md § "Mode-4 Link
    # Mode"). -no-pie looked like a free determinism fix (it does stabilize a crashing SIGNAL, e.g. fz_segv_09:
    # 4xSIGILL+1xSIGSEGV under PIE -> 5/5 stable SIGSEGV under -no-pie) but gdb on the faulting RSP proved it is
    # not free: fz_red_m2a_fence_cap_gen and fz_segv_10 are NOT crash-expected (.ref = "match") and PIE runs
    # them clean 20/20 -- -no-pie SIGSEGVs them 20/20, RSP == 0x0 at fault under -no-pie, a normal valid stack
    # address at the identical program point under PIE. -no-pie is the arm that is wrong, not a measurement
    # artifact. Do not re-add it here without re-opening that ruling.
    r = subprocess.run(["gcc", str(o_path), "-L", rt_dir, "-lscrip_rt", "-lm",
                         "-Wl,-rpath," + rt_dir, "-o", str(out_bin)],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd=str(paths["scrip_root"]))
    if r.returncode != 0:
        return Verdict("SKIP", detail="gcc link failed")
    return None


def run_m4(paths, sno_path, expected_text, tmp_dir, timeout=None, stdin_text=None, want_rc=0, prog_argv=None, mask=None, bin_dir=None, heap_kb=None, stack_kb=None, compile_args=None, out_files=None, merge_stderr=False, ws_blind=False, answer_file=None):
    timeout = timeout or paths["timeout"]
    if not (paths["rt_dir"] / "libscrip_rt.so").is_file():
        return Verdict("SKIP", detail="libscrip_rt.so not built")
    # ⛔⭐ THE m4 BINARY IS NAMED AFTER ITS OWN SOURCE AND INVOKED BY BARE NAME (ceo CEO-569, on the
    # coo's COO-56 ask; the same cure hq_B landed for the arizona runner, one level up). It was "t.bin"
    # for every entry of every rung suite suite in seven languages, so &progname / &pgname answered a name
    # NO .ref was ever cut from and every entry answered the SAME one -- the mode-4 half of hq_B's finding
    # that no single ref can be right for both modes on a program that prints its own name. Entry 924
    # (jcon kwds.icn, absorbed) STAYS RED by that ruling: its ref is a one-step cut naming the .icn source,
    # which no m4 invocation can produce. This pin is what stops the NEXT absorbed entry inheriting it.
    # ⛔ CONDITIONAL BY NECESSITY, NOT BY TASTE: a suite entry is materialized INTO tmp_dir (run_suite_entry
    # writes cand = tmp_dir/name.ext), so tmp_dir IS the cwd below and "./name" resolves; a discover_pairs
    # family's source lives in the CORPUS and tmp_dir does not, so a bare name would not resolve there and
    # writing the binary beside the source would litter the corpus tree. Absolute path preserved for that
    # case -- same behaviour as before this change, which is why no pair-graded board moves.
    # ⛔⭐⭐ THE PIN ABOVE WAS TRUE OF THE LINE AND FALSE OF THE RUN, AND ONLY A LIVE MEASUREMENT SAID SO
    # (hq_V 2026-09-11, grading entry 924 through this very function). The comment asserts "a suite entry is
    # materialized INTO tmp_dir ... so tmp_dir IS the cwd below" -- and run_suite_entry materializes the entry
    # into ITS OWN tempdir and then calls run_all_modes, which opens A SECOND, NESTED tempdir and passes THAT
    # as tmp_dir. So out_bin.parent was never run_dir for a suite entry, _same was always False, and every
    # rungs entry in seven languages was still invoked BY ITS ABSOLUTE MKTEMP PATH -- the exact ungradability
    # CEO-569 named, surviving a cure that had been checked by reading the source and by grepping for the
    # spelling. ⛔ A SOURCE-LEVEL ASSERTION IS NOT A MEASUREMENT OF BEHAVIOUR: the gate's own clause 1 greps
    # this file for the pinned form and went green throughout, because the form is right here and the caller
    # defeats it one frame up. bin_dir is how the caller that KNOWS it owns the run directory says so.
    # ⛔ DECLARED, NEVER INFERRED, and the default is byte-identical to the behaviour before it existed: a
    # discover_pairs family's source lives in the CORPUS, writing a binary beside it would litter the tracked
    # tree, and that caller passes no bin_dir and keeps the absolute invocation it has always had.
    # ⛔ ONLY THE BINARY MOVES. The .s/.o intermediates stay in tmp_dir, so the run directory gains exactly one
    # file -- the same discipline test_icon_jcon_suite.sh keeps for its rundir, and for the same measured
    # reason: a program that lists its own directory grades what is in it (jcon io.icn). Censused across all
    # seven rung suites before landing: no entry lists or globs its run directory; three print their own argv[0]
    # (icon 414 prints only its TYPE and length, icon 924 is this row, snobol4 104 prints HOST(0)).
    out_bin = (Path(bin_dir) if bin_dir else tmp_dir) / (Path(sno_path).stem or "t")
    skip = compile_m4(paths, sno_path, out_bin, tmp_dir, compile_args=compile_args)
    if skip is not None:
        # ⛔⭐ A COMPILE REFUSAL IS A VERDICT, NOT A SKIP (ceo CEO-1354, the coo's ask of 2026-09-28 on hq_snobol4's witness; hq_raku
        # 2026-10-11 on RakRungs class_method_range_replace_6 and class_method_say_replace_49): a program whose correct behaviour IS a
        # compile-time refusal -- the oracle refuses it, its ref is the refusal, its want_rc the refusal's -- read PASS in mode 3 and SKIP
        # in mode 4 forever, because every m4 compile failure was a SKIP. A refusal that ended (rc > 0, no signal) is graded exactly as
        # mode 3 grades the same refusal from --run: no stdout (the .s took it), the compiler's stderr through the one error voice, the
        # rc against the declared want_rc -- so a refusal the oracle shares is PASS and one it does not is FAIL. A compiler that died on a
        # signal, gcc and the link stay SKIP. S4E_M4_COMPILE_REFUSAL_SKIP=1 restores the old SKIP (the gate's fail-once arm only).
        if (skip.detail == "scrip --compile failed" and skip.returncode is not None and skip.returncode > 0
                and os.environ.get("S4E_M4_COMPILE_REFUSAL_SKIP", "") != "1"):
            v = _grade_output(skip.stderr if merge_stderr else b"", skip.stderr, skip.returncode, expected_text, want_rc=want_rc,
                              mask=mask, merge_stderr=merge_stderr, ws_blind=ws_blind)
            v.detail = "compile refusal, graded as mode 3 grades it" + (": " + v.detail if v.detail else "")
            return v
        return skip
    # ⭐ NO `--` HERE, AND THE ASYMMETRY WITH run_m3 IS THE POINT: a mode-4 binary IS the program, so
    # its argv is the program's argv directly -- there is no driver in front of it to shield. Same
    # declared list, two spellings, one observable result (verified: identical argc/args in m3 and m4).
    run_dir = Path(sno_path).parent
    _same = out_bin.parent.resolve() == run_dir.resolve()
    argv = stdbuf_wrap(paths, [out_bin.name]) + _size_switches(heap_kb, stack_kb) + _host_u_switch(sno_path, prog_argv) + (["--"] + [str(a) for a in prog_argv] if prog_argv else [])
    env = dict(os.environ, SNO_LIB=str(paths["inc"]), PATH=str(out_bin.parent) + os.pathsep + os.environ.get("PATH", ""))
    # ⛔⭐ EXPORTED AT THE RUN AND DELIBERATELY NOT AT THE COMPILE. `scrip --compile` runs the COMPILER
    # in this same process image, so setting the arena there would grade the compiler at the test's
    # declared window instead of the test -- a number wearing the wrong subject's name. The declaration
    # is about the program's live set, so it is applied where the program lives.
    # the declared heap and stack ride the binary's command line as -d -i -s (see _size_switches), read at its first allocation
    # Same rule as run_m3 above: the compiled binary's relative opens must resolve against the
    # SOURCE's directory, not the harness's cwd. out_bin is an absolute path, so moving cwd is safe.
    return classify(argv, timeout, expected_text, cwd=str(Path(sno_path).parent), env=env, stdin_text=stdin_text, want_rc=want_rc, mask=mask, out_files=out_files, merge_stderr=merge_stderr, ws_blind=ws_blind, answer_file=answer_file)


# ⛔⭐ run_ast TAKES NO prog_argv AND MUST NOT -- NOT AN OVERSIGHT. `--dump-ast` never executes the
# program, so declared arguments cannot change its output; accepting them would let an ast-mode family
# declare an argv that silently grades nothing, which is the "criterion that lies" shape. A language
# whose LANG_CONFIGS modes are "ast" (raku, rebus, prolog, snocone today) therefore cannot USE the argv
# sidecar even though it may legally carry one -- read_argv_sidecar refuses that combination wherever the
# modes are known (cmd_run passes them) rather than accepting a declaration it would then ignore.
def run_ast(paths, src_path, expected_text, timeout=None, want_rc=0):
    """Grading mode for parser-ladder families: `scrip --dump-ast`, diffed as text -- same
    classify() used by run_m3/run_m4, just a different argv. No compile/link step, so it is fast
    and language-agnostic (dispatch is by src_path's own extension, same as scrip --run/--compile)."""
    timeout = timeout or paths["timeout"]
    argv = stdbuf_wrap(paths, [str(paths["scrip_bin"]), "--dump-ast", str(src_path)])
    return classify(argv, timeout, expected_text, want_rc=want_rc)


# ============================================================= discovery ===
def discover_pairs(family_dir, ext=".sno"):
    """(src, .ref) pairs, sorted by filename. A src file without a matching .ref is skipped
    (mirrors test_corpus_snobol4.sh's own [ ! -f "$ref" ] && continue). Any file whose extension
    is not `ext`/.ref (dead-backend litter: .il/.j/.js/.wat/.s/.asm.ref etc) is never matched by
    this glob pairing and is silently ignored, which is the point -- it is not a test."""
    family_dir = Path(family_dir)
    pairs = []
    for src in sorted(family_dir.glob(f"*{ext}")):
        ref = src.with_suffix(".ref")
        if ref.is_file():
            pairs.append((src, ref))
    return pairs


# ============================================================= statement parse ===
def _has_goto_field(raw):
    """Does this statement's text already carry a :S()/:F()/bare :() goto field? A bare-colon
    continuation line may only merge into a statement that has NONE -- merging onto one that
    already has its own conditional goto (e.g. 'GT(N, 5) :S(DONE)' followed by a fall-through-only
    ':(LOOP)') produces a single statement with two conflicting goto specs, not the original's
    real semantics (test-then-conditional-jump, THEN a separate unconditional-jump statement for
    the fall-through path). Ignores colons inside quoted string literals."""
    in_str = None
    for ch in raw:
        if in_str:
            if ch == in_str:
                in_str = None
        elif ch in "'\"":
            in_str = ch
        elif ch == ":":
            return True
    return False


def parse_statements(sno_text):
    """Original source -> list of {"labeled": bool, "raw": text} statements. Drops column-1 '*'
    comments and blank lines; merges a bare goto-only continuation line (e.g. a lone ':(END)')
    into the immediately preceding statement instead of treating it as its own entry -- but only
    when that statement has no goto field of its own (see _has_goto_field); otherwise the bare
    goto is a genuine separate statement (the fall-through path after a failed conditional test)
    and must stay its own entry."""
    statements = []
    for line in sno_text.splitlines():
        if not line.strip():
            continue
        if line[:1] == "*":
            continue
        stripped = line.strip()
        if stripped.startswith(":") and statements and not _has_goto_field(statements[-1]["raw"]):
            statements[-1]["raw"] = statements[-1]["raw"] + " " + stripped
            continue
        labeled = not line[:1].isspace()
        statements.append({"labeled": labeled, "raw": stripped})
    return statements


def join_one_line(statements):
    """The empirically-verified join: no space before a label, a space before an unlabeled
    statement (including the very first, which has no preceding ';' to carry it)."""
    pieces = []
    for i, s in enumerate(statements):
        text = re.sub(r"\s+", " ", s["raw"]).strip()
        sep = "" if i == 0 else ";"
        pad = "" if s["labeled"] else " "
        pieces.append(sep + pad + text)
    return "".join(pieces)


def multiline_block(statements):
    """The always-safe fallback: original per-statement text, one per physical line, comments and
    blank lines already stripped, continuations already merged -- verified byte-identical to the
    unmodified original file's behaviour (see corpus-suites-consolidation session notes). Column-1
    still matters per physical line here (same rule as the one-line join): a labeled statement's
    label must start at true column 1, and an unlabeled statement must NOT -- parse_statements()
    stored both as .strip()'d text, so indentation must be restored for unlabeled statements."""
    return [s["raw"] if s["labeled"] else ("        " + s["raw"]) for s in statements]


def make_banner(seq, name, xfail=False):
    suffix = f"{seq} {name}" + (" XFAIL" if xfail else "")
    dash_count = max(1, BANNER_WIDTH - 1 - 1 - len(suffix))
    banner = "*" + ("-" * dash_count) + " " + suffix
    return banner


def make_banner_cfg(seq, name, comment_open, comment_close, xfail=False):
    """Generalized make_banner() for LANG_CONFIGS dialects: comment_open="*"/comment_close=""
    reproduces make_banner() exactly (verified: same dash_count formula, open+dashes+' '+suffix).
    A non-empty comment_close (e.g. Snocone's " */") is pinned at the right margin, same as the
    open side's dash-fill -- open + dashes + ' ' + suffix + close, total BANNER_WIDTH.
    ⛔ THE `xfail` PARAMETER IS LOAD-BEARING AND WAS MISSING UNTIL 2026-08-28 (row
    suite-harness-xfail-extract-round-trip). make_banner() had it from the start; this generalized
    twin did not, so for EVERY LANG_CONFIGS dialect the flag was silently dropped on write and had
    no group to be read back into -- an XFAIL block-suite entry round-tripped to a plain entry, and
    the next `run` scored a documented, expected red as a genuine FAIL. ⭐ The two writers diverged
    because the flag was added to one and the other was never asked to prove it agreed: a
    generalization that quietly drops a parameter of the thing it generalizes."""
    suffix = f"{seq} {name}" + (" XFAIL" if xfail else "")
    fixed = len(comment_open) + 1 + len(suffix) + len(comment_close)
    dash_count = max(1, BANNER_WIDTH - fixed)
    return comment_open + ("-" * dash_count) + " " + suffix + comment_close


def banner_re_for(comment_open, comment_close):
    close = comment_close.strip()
    close_pat = (r"\s*" + re.escape(close)) if close else ""
    return re.compile(r"^" + re.escape(comment_open) + r"-+ (?P<seq>\d+) (?P<name>\S+)"
                      + r"(?P<xfail> XFAIL)?" + close_pat + r"$")


# ============================================================= conversion ===
class Entry:
    def __init__(self, kind, seq, name, sno_lines, ref_text_or_lines, stdin=None, xfail=False,
                 xfail_reason=None, want_rc=0, argv=None):
        self.kind = kind          # "line" or "block"
        self.seq = seq
        self.name = name
        self.sno_lines = sno_lines        # list[str]: 1 line for "line", N for "block"
        self.ref = ref_text_or_lines      # str for "line" (unescaped), list[str] for "block"
        self.stdin = stdin                # str fed to the entry's stdin, or None = /dev/null (see STDIN below)
        self.xfail = xfail        # block-only: original was already non-green at conversion time
                                   # (byte-equal-or-no-delete still holds -- the candidate reproduces
                                   # the ORIGINAL's verdict exactly, whatever it is, never just PASS).
                                   # cmd_run buckets these as XFAIL/XPASS instead of FAIL, so a
                                   # pre-existing, documented-red witness doesn't poison a caller's
                                   # FAIL=0 gate. See corpus-suites-consolidation.task.md amendment log.
        self.argv = argv          # list[str] passed to the entry as its program arguments, or None = none at
                                   # all (identical to pre-sidecar behaviour). DECLARED in <family>.argv,
                                   # never inferred -- an entry's own text cannot say what it should be RUN
                                   # with. See sidecar_argv_path() for why discovery beats a flag.
        self.mask = None          # list[(compiled regex, reason)] from <family>.mask, or None. CEO-409: a line
                                   # whose value belongs to the IMPLEMENTATION (a clock reading, an allocator's
                                   # free-space count) is masked AT THE LINE so the rest of the fixture keeps
                                   # grading. DECLARED beside the data, never inferred, never in a runner.
        self.want_rc = want_rc    # int: the exit code a CORRECT run of this entry produces. 0 unless the
                                   # family declares otherwise in <family>.wantrc. DECLARED, never inferred.
        self.compile_args = None  # list[str] of scrip switches this entry DECLARES for its compile step, both modes, or None =
                                   # none (clause 8 (f), CEO-1281): ALL.csv's compile_args column, read by read_command_line_columns.
        self.out_files = None     # list[str] of files this entry WRITES whose bytes are its answer, or None (Lon 2026-09-27, in-chat to
                                   # hq_snobol4, picking "Out-file attribute" for aisnobol BUILDLIB.sno, which prints nothing and writes
                                   # spitlib.idx): ALL.csv's out_files column. Each is deleted before every run (oracle, m3, m4) and its
                                   # bytes appended to the graded output after it, so a staged copy can never answer for the program.
        self.merge_stderr = False # True when the entry's answer is stdout and stderr as ONE stream (ALL.csv's stderr column reads
                                   # "merged"): the contract of a package whose own harness cut its refs as `prog < in > out 2>&1`
                                   # (the Icon packages, CEO-445), applied alike to the oracle's ref cut and to m3 and m4.
        self.compare_ws = False   # True when ALL.csv's compare column reads ignore-all-space: each line graded with its white space removed (CEO-1927)
        self.stage_upstream = False   # True when ALL.csv's stage column reads upstream: the run directory is the entry's upstream test directory (CEO-1927)
        self.answer_file = None       # "temp" when ALL.csv's answer column reads temp-sorted: the graded output is that file's lines, sorted (CEO-1927)
        self.stack_kb = None      # int KB of STACK this entry declares (CEO-1225), or None = the runtime's 64 MB floor.
        self.heap_kb = None       # int KB this entry DECLARES it needs, or None = the shipped default.
                                   # Lon 2026-09-23 / CEO-1167. DECLARED in ALL.csv's heap_kb column (or a
                                   # travelling <stem>.heap sidecar), never inferred -- a program's own text
                                   # cannot say how much live set it has, and a runner that guessed would be
                                   # pinning an arena, which is the one thing this column exists to replace.
        self.xfail_reason = xfail_reason  # str: WHY this entry is expected red, or None. Carried in the
                                   # family.xfail sidecar, NEVER in the banner -- boolean and reason live in
                                   # different layers (see the reason-sidecar section). ⛔ DOCUMENTATION ONLY:
                                   # nothing in cmd_run reads it, so a reason can never change a verdict.


def has_comment_lines(text):
    """True if the source carries any column-1 '*' comment line. SNOBOL4 has no inline-comment
    syntax, so a comment cannot survive a one-line join, and parse_statements()/multiline_block()
    silently drop them -- harmless when a comment carries no information, but not for
    probe/passthru's witnesses, which carry dated research rationale cited by ARCH-PASSTHRU.md and
    ~10 FINDINGs. A conversion that launders that away just because byte-equal-or-no-delete only
    checks RUN OUTPUT would be exactly the transcription-kills-provenance class RULES.md warns about."""
    return any(line[:1] == "*" for line in text.splitlines())


def convert_one(paths, sno_path, ref_path, seq, tmp_root, modes, companion_dir=None, stdin_text=None):
    """Returns (Entry, report_dict). report_dict always has "ok": bool and "reason": str.
    ⛔⭐⭐ stdin_text IS NOT OPTIONAL POLISH -- WITHOUT IT A GREEN WITNESS IS LAUNDERED INTO A PERMANENT
    XFAIL AND THE RUN STILL PRINTS ✅ (measured 2026-08-30, hq_B, on a two-entry scratch family).
    A loose stem with a stdin companion whose .ref was minted FED, re-run here UNFED, produces empty
    output, so orig_green goes False -- and convert does not refuse a non-green original by design
    (probe/passthru's deliberately-red witnesses). It converts it verbatim as XFAIL, the candidate is
    ALSO unfed so it reproduces the same empty output, byte-equal-or-no-delete is satisfied, and the
    command exits "✅ ON-DISK RE-VALIDATION PASSED ... Safe to delete the originals" -- including the
    .input file that was the entry's whole meaning. ⭐ Every individual check behaved exactly as
    specified; the defect is that all of them were asked about the same unfed program. Feeding is what
    makes them questions about the real witness."""
    name = sno_path.stem
    original_text = sno_path.read_text()
    # ⛔⭐ CONVERT MUST BE IDEMPOTENT — STRIP OUR OWN `;* <name>` SENTINEL BEFORE RE-PROCESSING.
    # A format-(A) one-liner ends with a MANDATORY `;* <name>` tag. Feed such a line back through convert
    # (which is exactly what merging new witnesses into an EXISTING suite does: extract all, add new,
    # re-convert) and parse_statements() keeps that tag as a trailing comment statement, join_one_line()
    # preserves it, and then `joined + f";* {name}"` appends a SECOND one -- `;* ev_fn_literal;* ev_fn_literal`.
    # Every re-conversion adds another. MEASURED (hq_C 2026-08-28, root-causing seat02's report): re-converting
    # probe/eval's 21 entries doubled the tag on 17 of them in a single pass.
    # Stripping is safe and precise: the tag is only removed when the file is a SINGLE line whose trailing tag
    # names THIS entry, which is our own writer's output and never a hand-authored witness's real last statement.
    _stripped = original_text.strip("\n")
    if "\n" not in _stripped:
        _m = ONE_LINE_TAG_RE.search(_stripped)
        if _m and _m.group(1) == name:
            original_text = _stripped[: _m.start()] + "\n"
    expected_text = ref_path.read_text()
    statements = parse_statements(original_text)

    orig_verdicts = run_all_modes(paths, sno_path, expected_text, tmp_root, modes, stdin_text=stdin_text)
    orig_green = all(v.kind == "PASS" for v in orig_verdicts.values())
    # ⛔ A non-green original is NOT refused. probe/passthru's law-0d witnesses are DELIBERATELY red
    # ("a red row is never denied" -- board_passthru_combo.sh's own header, ARCH-PASSTHRU.md): this
    # active correctness campaign's whole point is documenting a known-bad state until it's cured, so
    # refusing to convert a red witness would either strand it as a permanent loose-file exception
    # (voided by Lon's 2026-08-28 total-conversion ruling) or force it to be silently fixed/altered by
    # a mechanical conversion pass, which is not this row's call to make. byte-equal-or-no-delete still
    # holds in full: the candidate must reproduce the ORIGINAL's verdict exactly, whatever it is, never
    # just "PASS" -- see corpus-crosscheck-probe-total-conversion.task.md's xfail/xpass extension and
    # cmd_run's XFAIL/XPASS bucketing, which keeps a pre-existing red from inflating a caller's FAIL count.
    # ⛔ A STDIN-BEARING ENTRY IS BLOCK-ONLY, and that is the suite format's rule, not a preference here:
    # write_stdin_sidecar() keys every stdin block by banner, and a format-(A) one-liner has no banner to
    # key on -- it raises rather than dropping the stdin silently. Forcing the block form at the point the
    # stdin is known keeps that from ever becoming a late crash after a whole family has converted.
    force_verbatim = has_comment_lines(original_text) or not orig_green or stdin_text is not None

    # --- attempt (A): one-line join --- skipped for a comment-bearing or non-green original: comments
    # have no one-line syntax to survive in, and a red witness is safest preserved byte-for-byte rather
    # than re-derived through the join's statement-merge heuristic.
    if not force_verbatim:
        joined = join_one_line(statements)
        one_line = joined + f";* {name}"
        if len(one_line) <= ONE_LINE_CAP:
            with tempfile.TemporaryDirectory(dir=tmp_root) as td:
                # ⛔⭐ THE WITNESS'S OWN NAME, NOT A "cand.sno" PLACEHOLDER (row suite-harness-argv-
                # echoes-a-mktemp-path-so-diagnostic-programs-cannot-be-graded) -- run_suite_entry
                # (every future regrade of this same entry, once converted) already names its own
                # temp candidate f"{entry.name}{ext}"; using a DIFFERENT name here would make this
                # one-time conversion-verification step echo something ongoing grading never will,
                # even after the argv/cwd fix above makes the echoed text otherwise reproducible.
                cand = Path(td) / f"{name}.sno"
                cand.write_text(one_line + "\n")
                _copy_companions(one_line + "\n", companion_dir, Path(td))
                cand_verdicts = run_all_modes(paths, cand, expected_text, Path(td), modes, stdin_text=stdin_text)
            if all(cand_verdicts[m].behaviorally_equal(orig_verdicts[m]) for m in modes):
                entry = Entry("line", seq, name, [one_line], expected_text.rstrip("\n"))
                return entry, {"ok": True, "reason": "one-line", "len": len(one_line)}

    # --- fallback (B): multi-line banner block --- verbatim original text (comments/blanks/indentation
    # intact) when forced (see has_comment_lines()/force_verbatim above): simpler AND lossless -- no
    # dependence on the goto-merge heuristic, no re-derivation at all. Otherwise unchanged: the existing
    # statement-reconstructed form every already-converted family was proven against.
    block_lines = original_text.splitlines() if force_verbatim else multiline_block(statements)
    with tempfile.TemporaryDirectory(dir=tmp_root) as td:
        # ⛔⭐ THE WITNESS'S OWN NAME, NOT A "cand.sno" PLACEHOLDER (row suite-harness-argv-echoes-a-
        # mktemp-path-so-diagnostic-programs-cannot-be-graded) — matches run_suite_entry's convention.
        cand = Path(td) / f"{name}.sno"
        block_text = "\n".join(block_lines) + "\n"
        cand.write_text(block_text)
        _copy_companions(block_text, companion_dir, Path(td))
        cand_verdicts = run_all_modes(paths, cand, expected_text, Path(td), modes, stdin_text=stdin_text)
    if all(cand_verdicts[m].behaviorally_equal(orig_verdicts[m]) for m in modes):
        entry = Entry("block", seq, name, block_lines, _lf_lines(expected_text.rstrip("\n")),
                       stdin=stdin_text, xfail=not orig_green)
        if not orig_green:
            reason = "multi-line-block-verbatim(XFAIL: original already non-green)"
        elif force_verbatim:
            reason = "multi-line-block-verbatim(comments preserved)"
        else:
            reason = "multi-line-block"
        return entry, {"ok": True, "reason": reason}

    return None, {"ok": False, "reason": f"NEITHER form reproduced the original's behavior: orig={orig_verdicts}"}


def run_all_modes(paths, sno_path, expected_text, tmp_root, modes, stdin_text=None, want_rc=0, prog_argv=None, mask=None, where="", bin_dir=None, heap_kb=None, stack_kb=None, compile_args=None, out_files=None, merge_stderr=False, ws_blind=False, answer_file=None):
    """Every mode is graded against the ONE ref: the two modes are one machine in two media (Lon 2026-09-23, CEO-1218/1230)."""
    out = {}
    # ⭐ A TRACE PER ENTRY AND MODE (the coo 2026-10-09, the cfo's ask for the rank-0 row gc-rt-c-c-to-bb-...): rt_c2bb_hit appends every
    # C-entered box to the ONE path SCRIP_C2BB_TRACE names, so a suite run under one path loses which entry fired. With
    # S4E_ENTRY_TRACE_DIR set, each mode of each entry gets its own <dir>/<entry>.<mode>.trace; run_m3 and run_m4 inherit it through
    # os.environ (this harness grades one entry at a time, in one thread). util_c2bb_trace_census.py counts the directory by mark.
    _trd = os.environ.get("S4E_ENTRY_TRACE_DIR", "")
    if _trd:
        os.makedirs(_trd, exist_ok=True)
    if "m3" in modes:
        if _trd:
            os.environ["SCRIP_C2BB_TRACE"] = os.path.join(_trd, "%s.m3.trace" % Path(sno_path).stem)
        _t0 = time.monotonic()
        out["m3"] = run_m3(paths, sno_path, expected_text, stdin_text=stdin_text, want_rc=want_rc, prog_argv=prog_argv, mask=mask, heap_kb=heap_kb, stack_kb=stack_kb, compile_args=compile_args, out_files=out_files, merge_stderr=merge_stderr, ws_blind=ws_blind, answer_file=answer_file)
        out["m3"].secs = time.monotonic() - _t0
    if "m4" in modes:
        if _trd:
            os.environ["SCRIP_C2BB_TRACE"] = os.path.join(_trd, "%s.m4.trace" % Path(sno_path).stem)
        with tempfile.TemporaryDirectory(dir=tmp_root) as td:
            _t0 = time.monotonic()
            out["m4"] = run_m4(paths, sno_path, expected_text, Path(td), stdin_text=stdin_text, want_rc=want_rc, prog_argv=prog_argv, mask=mask, bin_dir=bin_dir, heap_kb=heap_kb, stack_kb=stack_kb, compile_args=compile_args, out_files=out_files, merge_stderr=merge_stderr, ws_blind=ws_blind, answer_file=answer_file)
            out["m4"].secs = time.monotonic() - _t0
    if _trd:
        os.environ.pop("SCRIP_C2BB_TRACE", None)
    return out


# ========================================================== suite writer ===
def write_suite(entries, out_sno, out_ref, out_in=None, lang=""):
    """Returns True iff a stdin sidecar was written (out_in given AND at least one entry carries stdin) --
    same contract and same write_stdin_sidecar() call as write_block_suite(), which had this parameter from
    the start while this SNOBOL4 twin did not: a stdin-bearing snobol4 family had nowhere to put its input,
    so the loose companion was simply stranded by conversion (hq_B 2026-08-30).
    ⛔⭐ FORMAT-(B) BLOCKS ARE EMITTED LAST, ALWAYS — THIS ORDERING IS A CORRECTNESS INVARIANT, NOT A STYLE CHOICE.
    A banner block ends only at the NEXT BANNER OR EOF (see read_suite()'s scanner). So any format-(A) one-line entry
    written AFTER a block is silently swallowed into that block's body: the file stops round-tripping, and the swallowed
    entries either vanish or come back duplicated. MEASURED (hq_C 2026-08-28, on seat02's convert-corrupts-eval report):
    re-converting probe/eval's 21 entries wrote 21 and read back 22, with `ev_fn_beauty_shape` appearing twice, because
    alphabetical order put that one block in the MIDDLE and it absorbed the nine one-liners after it.
    ⛔ Suites written before this fix were correct only BY ACCIDENT OF ORDERING — probe/eval survived because its two
    blocks happened to be appended last. Do not "simplify" this back into a single loop over `entries`.
    ⛔⭐ `lang` PICKS THE BANNER'S COMMENT SYNTAX (row every-vendored-package-..., first Icon package via
    util_build_package_suite.py) -- the hardcoded '*' below is SNOBOL4's comment char, not a suite-format
    constant; a '*'-banner in a non-SNOBOL4 block is not a comment in that language at all (Icon's is '#'),
    so the container stops being valid source in its own language. LANG_CONFIGS already carries the right
    comment_open/close (make_banner_cfg/banner_re_for already existed for this, used by
    util_build_rungs_suite.py -- this writer just never took a lang param to reach them). Blank/"snobol4"
    keeps the exact prior '*' behaviour (every already-built package is lang="" and is unaffected).
    ⛔ The round-trip self-check below MUST use the same convention it just wrote with, or it silently
    validates against its own SNOBOL4-flavored default reader while the real bug (wrong comment char for
    the target language) sails through undetected -- exactly how this shipped unnoticed across 4 SNOBOL4
    packages before the first non-SNOBOL4 one (jcon_tests) hit it."""
    lc = LANG_CONFIGS.get(lang) if lang else None
    lines = [e for e in entries if e.kind == "line"]
    blocks = [e for e in entries if e.kind != "line"]
    if lines and lc:
        raise ValueError(f"write_suite: lang={lang!r} produced {len(lines)} format-A 'line' entries -- "
                          f"make_banner_cfg/read_block_suite is untested for anything but a pure-block suite")
    sno_lines, ref_lines = [], []
    for seq, e in enumerate(lines + blocks, 1):
        # ⛔ RENUMBER THE ENTRY ITSELF, not just the banner being printed. This writer reorders
        # (lines then blocks) AND renumbers, while write_stdin_sidecar() banners its blocks from
        # e.seq -- so leaving e.seq at its pre-reorder value writes a .in banner numbered
        # differently from the .sno banner naming the same entry. read_stdin_sidecar attaches BY
        # NAME and would still work, which is precisely why the inconsistency could sit there
        # unnoticed and confuse the next person to read the two files side by side.
        e.seq = seq
        if e.kind == "line":
            sno_lines.append(e.sno_lines[0])
            ref_lines.append(e.ref.replace("\n", "\\n"))
        else:
            banner = (make_banner_cfg(seq, e.name, lc["comment_open"], lc["comment_close"], xfail=e.xfail)
                      if lc else make_banner(seq, e.name, xfail=e.xfail))
            sno_lines.append(banner)
            sno_lines.extend(e.sno_lines)
            ref_lines.append(banner)
            ref_lines.extend(e.ref)
    Path(out_sno).write_text("\n".join(sno_lines) + "\n")
    Path(out_ref).write_text("\n".join(ref_lines) + "\n")
    # ⛔ AFTER the .sno/.ref write, and keyed by the SAME seq the banners just got (write_suite reorders
    # lines-then-blocks and renumbers, so a sidecar written from the pre-reorder seq would banner its
    # blocks with numbers that no longer name the same entries), and BEFORE the round-trip check below --
    # a check that runs before the sidecar exists cannot verify the sidecar. ⛔ SAME '*'-HARDCODE BUG AS
    # THE MAIN BANNER, ONE FUNCTION OVER: write_stdin_sidecar() already takes comment_open/close as
    # params (it was already lang-agnostic on its own), but this call site never threaded `lc` through --
    # only surfaced once a real Icon package needed BOTH the main banner fix AND a stdin sidecar
    # (jcon_tests, after teaching stdin_for() about .dat: 60->70 absorbed, 17 of them stdin-fed) --
    # `run --lang icon` failed reading ALL.in with the exact same "expected a banner, found '*...'" error.
    wrote_in = False
    if out_in is not None:
        wrote_in = write_stdin_sidecar(lines + blocks, out_in,
                                        lc["comment_open"] if lc else "*", lc["comment_close"] if lc else "")
    # ⛔ ROUND-TRIP OR REFUSE. A writer that cannot be read back is the "lying test" class: it reports success while
    # having destroyed entries. Cheap to check, and it is the only thing standing between an ordering bug and a
    # silently-corrupted permanent suite. ⛔ MUST re-read with the SAME banner convention just written (lc's
    # comment chars via read_block_suite), never the SNOBOL4-flavored read_suite() default -- otherwise this
    # check "passes" by reading back its own wrong assumption instead of the file it actually wrote.
    # ⛔ MUST ALSO PASS in_path WHEN A SIDECAR WAS WRITTEN -- "A CHECK THAT DOES NOT CARRY EVERY FIELD THE
    # GRADER READS IS NOT A CHECK" (hq_C): a round-trip
    # that never re-reads the .in file it just wrote cannot catch a defect in it, which is exactly how the
    # stdin-sidecar banner bug above shipped past this same self-check undetected.
    _in_for_check = str(out_in) if wrote_in else None
    back = (read_block_suite(out_sno, out_ref, banner_re_for(lc["comment_open"], lc["comment_close"]), in_path=_in_for_check)
            if lc else read_suite(out_sno, out_ref, in_path=_in_for_check))
    if len(back) != len(entries) or [e.name for e in back] != [e.name for e in lines + blocks]:
        raise ValueError(f"⛔ SUITE DID NOT ROUND-TRIP: wrote {len(entries)} entries, read back {len(back)}. "
                         f"wrote={[e.name for e in lines + blocks]!r} read={[e.name for e in back]!r}")
    return wrote_in


def write_block_suite(entries, out_src, out_ref, comment_open, comment_close, out_in=None, out_x=None):
    """write_suite() for a format-(B)-ONLY family: every entry is ALWAYS a banner block (no
    one-line join is ever attempted -- parser-ladder families are format-B by task-spec design,
    not by join-failure fallback), and the banner uses the dialect's own comment syntax.
    Returns True iff a stdin sidecar was written (out_in given AND at least one entry carries
    stdin) -- lets a caller report accurately without re-deriving write_stdin_sidecar's own check."""
    src_lines, ref_lines = [], []
    for e in entries:
        banner = make_banner_cfg(e.seq, e.name, comment_open, comment_close, xfail=e.xfail)
        src_lines.append(banner)
        src_lines.extend(e.sno_lines)
        ref_lines.append(banner)
        ref_lines.extend(e.ref)
    Path(out_src).write_text("\n".join(src_lines) + "\n")
    Path(out_ref).write_text("\n".join(ref_lines) + "\n")
    wrote_in = False
    if out_in is not None:
        wrote_in = write_stdin_sidecar(entries, out_in, comment_open, comment_close)
    if out_x is not None:
        write_xfail_sidecar(entries, out_x, comment_open, comment_close)
    return wrote_in


# =========================================================== stdin sidecar ===
# ⭐ STDIN IS CARRIED OUT-OF-BAND, IN A THIRD PARALLEL FILE (family.in), NEVER IN THE PROGRAM TEXT.
# The suite format already runs on parallel files keyed by an identical banner line (family.sno /
# family.ref); stdin is simply the third rail of that same design, and an entry with no stdin gets
# no banner in the .in file at all (absent = /dev/null, which is exactly the pre-stdin behaviour,
# so every existing suite keeps its current verdicts byte-for-byte).
# ⛔ THE ALTERNATIVE -- an in-band "*<<<STDIN" marker inside the source block -- WAS REJECTED ON
# MEASURED GROUNDS, not taste. In-band signalling over a channel that does not reserve its signal
# byte is fragile by construction: SCRIP a01fe9f6 prepended a port marker to label lines, and
# x86_internal_resolve then ate two bytes of any Pascal record descriptor that legitimately carried
# that byte in its own .string data -- silent, m4-only, and it read as an output mismatch rather
# than a crash (hq_C 2026-08-28, cure 840d05f7). A test program's stdin is ARBITRARY USER BYTES;
# reserving any line shape inside it would recreate that exact class here. Out-of-band cannot collide.
# ⛔ BLOCK ENTRIES ONLY. A format-(A) one-line entry cannot carry stdin -- write it as a block.
# The writer REFUSES such an entry rather than dropping it silently ("a test that cannot measure
# REFUSES; never skip-as-success").
def sidecar_in_path(src_path):
    """The stdin sidecar for a suite is ALWAYS <family>.in beside <family>.sno/.ref -- discovered,
    never passed as a flag. ⭐ That is deliberate: every existing consumer (boards, gates, runners)
    then picks stdin up with ZERO changes to its own argv, so a converted stdin-bearing family
    cannot silently run without its input just because one caller was not updated. Absent file ->
    None -> /dev/null, identical to pre-stdin behaviour."""
    cand = Path(src_path).with_suffix(".in")
    return str(cand) if cand.is_file() else None


# ⛔⭐⭐ ONE RESOLVER FOR THE LOOSE PER-STEM COMPANION -- THERE WERE THREE, AND THEY DISAGREED ABOUT
# WHICH SPELLINGS EXIST (measured 2026-08-30, hq_B, while feeding capture-oracle-refs):
#     sidecar_in_path()        suite level, knew .in and .input, NOT .stdin
#     cmd_convert_blocks()     loose level, knew .stdin ONLY -- a loose .in/.input never reached an entry
#     cmd_capture_oracle_refs() loose level, knew all three, but only in order to REFUSE on them
# All three spellings are LIVE in the corpus (corpus/tests/icon/rung36_jcon_*.stdin, and .input under
# demos/, benchmarks/, packages/), so each resolver was blind to real files the others could see.
# ⭐ AND A PARTIAL RESOLVER NEVER SAYS SO. It resolves to None, None means /dev/null, and the program
# then runs WITH THE WRONG INPUT while its output is graded as a genuine verdict -- a wrong answer
# wearing a verdict, exactly the class sidecar_in_path's own `.input` amendment records. The cure is
# not a fourth list: it is that there is only ever one list, here.
STDIN_COMPANION_SUFFIXES = (".stdin", ".in", ".input")


def stdin_companion_candidates(src):
    """Every stdin companion that EXISTS for a loose source: <stem><suffix> beside it and in `config/`.
    ⛔⭐ THIS IS THE ONE PLACE THE SPELLINGS ARE WRITTEN DOWN, and it exists because they were written
    down THREE times with THREE different answers (hq_V 2026-09-11, measured): this finder knew
    `.stdin/.in/.input`, util_build_rungs_suite.py's generalised stdin guard knew `.in/.input`, and its
    snobol4 plain-program guard knew `.input` alone. All 8 icon stdin companions in the corpus are spelled
    `config/<stem>.stdin` -- the one spelling the BUILDER did not know -- so the builder absorbed each of
    them as an ordinary pair, the rungs graded a stdin-reading program against /dev/null, and the
    auto-xfail path filed the starved run as a documented red. THERE IS NO XFAIL: every one of those is a
    FAIL on the board. Proved both directions on scratch corpora one byte apart: `config/w.stdin`
    ABSORBED (0 excluded), `config/w.in` EXCLUDED BY NAME, same program, same input, same ref.
    ⭐ The builder and the grader must ask the SAME question about a file, so they ask it through the same
    function rather than through two lists that agreed on the day they were written."""
    _stem = src.stem
    _cfg = src.parent / "config"
    return [c for c in [src.with_suffix(x) for x in STDIN_COMPANION_SUFFIXES]
            + [_cfg / (_stem + x) for x in STDIN_COMPANION_SUFFIXES] if c.is_file()]


def loose_stdin_companion(src):
    """stdin companion for a LOOSE corpus file: <stem>.stdin / <stem>.in / <stem>.input beside it.
    Returns (text, path, refusal); at most one of text/refusal is ever meaningful --
        (None, None, None)     no companion -> stdin is /dev/null, identical to pre-stdin behaviour
        (str,  Path, None)     feed this text to EVERY arm
        (None, Path|None, str) cannot feed faithfully -- the caller REFUSES, never guesses
    ⛔ AMBIGUITY IS A REFUSAL, NOT A PRECEDENCE RULE. Two companions beside one stem means nobody can
    say which is the program's input, and picking the first is the vacuous-ref failure with one extra
    step: it mints a ref that LOOKS fed and then grades that file against the wrong bytes forever.
    ⛔ NON-UTF-8 IS A REFUSAL TOO. This path feeds text; a byte sequence it cannot carry faithfully
    must stop the mint rather than be lossily re-encoded into a permanent .ref."""
    # ⛔⭐ SEARCH `config/` TOO, NOT ONLY BESIDE THE SOURCE (hq_U 2026-09-08, measured). The Icon ladder
    # keeps its inputs in a `config/` subdirectory, so this function answered "no companion" for a program
    # that plainly has one, and the documented `no companion -> /dev/null` path minted the entry UNFED.
    # rung36_jcon_recogn was absorbed into the Icon rungs that way and its .ref recorded the STARVED run
    # (one newline, against the standalone witness's 8 lines) -- a green cell inside a 704/704 board that
    # was grading a program which exits at EOF before reaching any `suspend`. It also hid a real by-name
    # scanning defect underneath it for three sittings. 9 such companions are live (8 icon, 1 snobol4).
    # ⭐ The bug was never in the caller: this finder answers "is there a companion BESIDE this file" and
    # was read as "does this program have stdin" -- the narrower-question class, same shape as `command -v`
    # answering "is it on PATH" when asked "does it exist". Widening the search is the whole cure: every
    # guarantee below (one-candidate-or-refuse, UTF-8-or-refuse, banner-sniff-or-refuse) then applies to
    # the combined set unchanged, so a stem carrying BOTH a loose and a config/ companion is AMBIGUOUS and
    # refuses, which is the correct answer rather than a precedence rule invented here.
    cands = stdin_companion_candidates(src)
    if not cands:
        return None, None, None
    if len(cands) > 1:
        # ⛔ Name each candidate by its path RELATIVE TO THE SOURCE'S DIRECTORY, never by `.name` alone:
        # since config/ joined the search, `w.stdin` and `config/w.stdin` both render as "w.stdin" and the
        # diagnostic whose entire job is to say WHICH files collide printed the same word twice (hq_U
        # 2026-09-08, caught by this function's own both-directions test, not in the field).
        _rel = lambda c: str(c.relative_to(src.parent)) if src.parent in c.parents else c.name
        return None, None, ("AMBIGUOUS stdin companion -- %s all exist for %s; which one is the "
                            "program's input cannot be decided here, keep exactly one"
                            % (", ".join(_rel(c) for c in cands), src.name))
    try:
        text = cands[0].read_bytes().decode("utf-8")
    except UnicodeDecodeError as e:
        return None, cands[0], ("stdin companion %s is not valid UTF-8 (%s) -- this path feeds text and "
                                "will not lossily re-encode a program's own input into a permanent .ref"
                                % (cands[0].name, e))
    # ⛔⭐ A SUITE SIDECAR IS NOT A LOOSE COMPANION, AND THE TWO SPELL THEMSELVES IDENTICALLY. <family>.in
    # beside <family>.sno is the CONVERTED suite's banner-keyed sidecar (sidecar_in_path); <stem>.in beside
    # <stem>.sno is one loose program's raw stdin. Same name shape, same directory, completely different
    # file -- and 6 of them are live in the corpus right now (tests/{snobol4,icon,snocone}/ALL.in,
    # icon/rung36_all.in, icon/rung27_read.in, snocone/crosscheck_rungA14.in).
    # ⭐ Feeding one as raw stdin would not error -- it would quietly push banner lines into the program
    # and grade whatever came out. So the check is on the CONTENT, not the name: real stdin does not open
    # with a banner. Refusing here also says something true and useful, which "wrong output" never would.
    _first = next((ln for ln in text.splitlines() if ln.strip()), "")
    if ANY_BANNER_RE.match(_first):
        return None, cands[0], ("%s is a SUITE .in SIDECAR (its first line is an entry banner), not this "
                                "stem's raw stdin -- feeding it would push banner lines into the program; "
                                "read it with read_stdin_sidecar(), never as loose stdin" % cands[0].name)
    return text, cands[0], None


# A stdin block is lines, and the reader ends it with a newline; a stdin that ends WITHOUT one (ProRosetta
# universal-lambda-machine.in, 8 bytes, its ref cut from those 8; with a ninth byte swipl and SCRIP both halt silent;
# hq_runtime 2026-10-24) closes its block with this line, diff's own words for the same fact, which the writer emits
# and the reader drops. test_gate_stdin_block_keeps_a_missing_final_newline.sh holds both sides.
STDIN_NO_FINAL_NEWLINE = "\\ No newline at end of file"


def read_stdin_sidecar(in_path, banner_re, entries):
    """Attach .in blocks to entries BY NAME. Absent file, or an entry with no block, leaves
    entry.stdin as None (= /dev/null). Refuses on a block naming no entry -- the shape a rename or
    a half-finished conversion produces -- because silence there would run the entry with the WRONG
    stdin (none) and score the result as a genuine FAIL."""
    if in_path is None or not Path(in_path).is_file():
        return
    lines = Path(in_path).read_text().splitlines()
    by_name, i = {}, 0
    while i < len(lines):
        m = banner_re.match(lines[i])
        if not m:
            raise ValueError(f"expected a banner at {in_path} line {i + 1}: {lines[i]!r}")
        name = m.group("name")
        if name in by_name:
            raise ValueError(f"{in_path}: duplicate stdin block for entry {name!r}")
        i += 1
        seg = []
        while i < len(lines) and not banner_re.match(lines[i]):
            seg.append(lines[i]); i += 1
        if seg and seg[-1] == STDIN_NO_FINAL_NEWLINE:
            by_name[name] = "\n".join(seg[:-1])
        else:
            by_name[name] = ("\n".join(seg) + "\n") if seg else ""
    unknown = sorted(set(by_name) - {e.name for e in entries})
    if unknown:
        raise ValueError(f"{in_path}: stdin blocks with no matching entry: {unknown}")
    for e in entries:
        if e.name in by_name:
            e.stdin = by_name[e.name]


def write_stdin_sidecar(entries, out_in, comment_open, comment_close):
    """Write family.in iff at least one entry carries stdin. Returns True if written."""
    withio = [e for e in entries if e.stdin is not None]
    if not withio:
        return False
    # ⛔⭐ ONE-LINERS CARRY STDIN TOO (Lon 2026-09-08, in-chat to hq_T: "Ensure all has sister (side cars)
    # files for the ONE-LINERS and MULTI-LINERS such that they have command-line args and an input file for
    # each test along with the ref and source files"). This function used to raise
    # "stdin is block-entries-only; convert these to blocks first", which put 818 SNOBOL4 one-line entries
    # -- every one-liner in the corpus -- permanently out of reach of an input file.
    # ⭐ THE RESTRICTION WAS WRITER-SIDE ONLY, AND NOTHING ELSE IN THE PIPELINE AGREED WITH IT. Measured
    # both directions on a two-entry scratch suite before this line was deleted: a one-line entry
    # ` OUTPUT = INPUT;END;* oneliner_reads_stdin` with a banner-keyed block in ALL.in grades PASS in BOTH
    # m3 and m4 through the real runner, and FAILs both modes with the same file removed. read_stdin_sidecar
    # attaches BY NAME and never looks at e.kind; run_suite_entry/pin-ref write e.sno_lines to a temp file
    # and pass stdin_text=e.stdin whatever the kind. So the format, the reader and both graders already
    # supported this -- only the writer refused, and a refusal nothing downstream needs is a capability
    # withdrawn for no measured reason.
    # ⭐ Keyed by name and out-of-band, which is exactly why this is safe for a one-liner: the hazard the
    # xfail-sidecar note below records -- in-band ";* <name>" metadata being indistinguishable from program
    # text once a one-liner is promoted to a block -- cannot arise in a file that holds no program text.
    out = []
    for e in withio:
        out.append(make_banner_cfg(e.seq, e.name, comment_open, comment_close))
        if e.stdin:
            out.extend(e.stdin.splitlines())
            if not e.stdin.endswith("\n"):
                out.append(STDIN_NO_FINAL_NEWLINE)
    Path(out_in).write_text("\n".join(out) + "\n")
    return True



# ========================================================== reason sidecar ===
# ⭐ THE XFAIL *REASON* IS CARRIED OUT-OF-BAND, IN A FOURTH PARALLEL FILE (family.xfail), KEYED BY
# ENTRY NAME EXACTLY LIKE family.in. The BOOLEAN stays in the banner (" XFAIL", seat08, SCRIP
# 3987d9ba) and remains the sole grading signal; this file carries only the human-readable WHY.
# ⛔ THE TWO LIVE IN DIFFERENT LAYERS ON PURPOSE, AND THE SPLIT IS THE WHOLE DESIGN. The banner
# boolean is read by cmd_run to bucket a verdict; the reason is read by a PERSON deciding whether a
# red is still expected. Fusing them -- a banner suffix carrying prose -- would put arbitrary text
# into the one line every reader of the format must parse, and BANNER_RE's own (?P<name>\S+) would
# then be one space away from swallowing it.
# ⛔ WHY KEYED-BY-NAME AND NOT IN-BAND, measured rather than preferred: the loose-file convention
# this replaces put the reason in a sidecar FILE (assign_014_...xfail, 126-164 bytes each), and the
# one-line ";* <name>" tag is INDISTINGUISHABLE FROM PROGRAM TEXT once a one-liner is promoted to a
# block -- the root of two of the three harness defects fixed on 2026-08-28. Entry metadata placed
# inside the entry is the recurring bug here; family.in got this right and this is its third rail.
# ⭐ ABSENT = NO REASON, NEVER AN ERROR. An XFAIL entry with no reason is legal (seat08's 154
# comment-free witnesses converted that way and must keep converting that way), so every existing
# suite keeps its current verdicts byte-for-byte. The refusals below are for the INCOHERENT cases
# only: a reason naming no entry, and a reason on an entry that is not marked XFAIL.
def sidecar_wantrc_path(src_path):
    """The declared-exit-code sidecar for a suite is ALWAYS <family>.wantrc beside <family>.sno/.ref --
    discovered, never passed as a flag, identical to sidecar_in_path()/sidecar_xfail_path(). Absent -> None
    -> every entry expects rc 0. ⭐ Discovery rather than a flag is the whole point: every existing consumer
    -- boards, gates, runners -- picks the declaration up with ZERO changes to its own argv, so an entry that
    legitimately exits nonzero cannot silently be graded by a caller nobody remembered to update."""
    cand = Path(src_path).with_suffix(".wantrc")
    return str(cand) if cand.is_file() else None


def read_wantrc_sidecar(w_path, entries):
    """Attach declared exit codes to entries BY NAME. Format is one `name<TAB>rc` per line; blank lines and
    `#` comments ignored. ⛔ REFUSES on a declaration naming no entry -- the shape a rename or a half-finished
    conversion produces, and the same refusal read_xfail_sidecar makes for the same reason: a declaration that
    matches nothing is either a typo or a stale leftover, and both silently withdraw a guarantee.
    ⛔ REFUSES on rc 0 declared explicitly: 0 is the default, so an explicit 0 is either a misunderstanding of
    the format or a no-op someone will later read as meaningful."""
    if not w_path or not os.path.isfile(w_path):
        return
    by_name = {e.name: e for e in entries}
    unknown = []
    for raw in open(w_path, encoding="utf-8"):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 2:
            raise ValueError(f"{w_path}: expected 'name<TAB>rc', got: {line!r}")
        name, rc_s = parts[0].strip(), parts[1].strip()
        try:
            rc = int(rc_s)
        except ValueError:
            raise ValueError(f"{w_path}: rc must be an integer for {name!r}, got {rc_s!r}")
        if rc == 0:
            raise ValueError(f"{w_path}: {name!r} declares rc=0, which is already the default -- "
                             f"remove the line rather than restating it")
        if name not in by_name:
            unknown.append(name)
            continue
        by_name[name].want_rc = rc
    if unknown:
        raise ValueError(f"{w_path}: declarations with no matching entry: {unknown}")


def sidecar_argv_path(src_path):
    """The program-arguments sidecar for a suite is ALWAYS <family>.argv beside <family>.sno/.ref --
    discovered, never passed as a flag, identical to sidecar_in_path()/sidecar_wantrc_path(). Absent ->
    None -> every entry runs with NO arguments, byte-identical to the behaviour before this sidecar
    existed. ⭐ Discovery rather than a flag is the same argument sidecar_wantrc_path() makes and it is
    the load-bearing one here: boards, gates and runners pick the declaration up with ZERO changes to
    their own argv, so a witness whose behaviour depends on its arguments cannot silently be graded
    along its no-arguments path by a caller nobody remembered to update. ⛔⭐ THAT SILENT PATH IS THE
    DEFECT THIS CLOSES, and it does not announce itself: an Icon witness written `n := integer(args[1])
    | 6` runs GREEN today on the `| 6` default, so the suite reports a pass for a program whose
    argument handling was never executed at all -- a green that documents nothing (row
    icon-suite-format-has-no-argv-sidecar-so-argv-taking-witnesses-are-ungradable, census 2026-09-06:
    51 such entries over 445 suites / 7317 entries)."""
    cand = Path(src_path).with_suffix(".argv")
    return str(cand) if cand.is_file() else None


def read_argv_sidecar(a_path, entries, modes=None):
    """Attach declared program arguments to entries BY NAME. Format is one `name<TAB>arg<TAB>arg...`
    per line; blank lines and `#` comments ignored. ⭐ TAB-SEPARATED, WITH NO QUOTING LANGUAGE AT ALL:
    an argument may contain spaces, quotes or backslashes and arrives at the program byte-for-byte, so
    there is no shell-word-splitting layer for a declaration to be misread through -- the same reason
    read_wantrc_sidecar parses `name<TAB>rc` rather than a free-form line.
    ⛔ REFUSES on a declaration naming no entry -- the shape a rename or a half-finished conversion
    produces, and the same refusal read_wantrc_sidecar/read_xfail_sidecar make for the same cause: a
    declaration matching nothing is either a typo or a stale leftover, and both silently withdraw the
    very guarantee the file was written to add.
    ⛔ REFUSES on a name declared with NO arguments: no arguments is already the default, so an empty
    declaration is either a misunderstanding of the format or a no-op a later reader will take for
    something meaningful -- exactly the refusal read_wantrc_sidecar makes for an explicit rc=0.
    ⛔ REFUSES when the family is graded in ast mode ONLY: `--dump-ast` never runs the program, so the
    arguments could not possibly reach it, and a declaration that cannot be executed is a criterion
    that lies. modes is None for callers that do not know them (pin-ref, convert), and those attach
    without the check rather than guessing."""
    if not a_path or not os.path.isfile(a_path):
        return
    if modes is not None and not ({"m3", "m4"} & set(modes)):
        raise ValueError(f"{a_path}: this family is graded in {sorted(modes)} only, and --dump-ast never "
                         f"RUNS the program -- declared arguments could not reach it. Either grade the "
                         f"family in m3/m4 or delete the sidecar; do not keep a declaration nothing executes")
    by_name = {e.name: e for e in entries}
    unknown = []
    for raw in open(a_path, encoding="utf-8"):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        name, args = parts[0].strip(), parts[1:]
        if not args or all(a == "" for a in args):
            raise ValueError(f"{a_path}: {name!r} declares no arguments, which is already the default -- "
                             f"remove the line rather than restating it")
        if name not in by_name:
            unknown.append(name)
            continue
        by_name[name].argv = args
    if unknown:
        raise ValueError(f"{a_path}: declarations with no matching entry: {unknown}")


def sidecar_xfail_path(src_path):
    """The reason sidecar for a suite is ALWAYS <family>.xfail beside <family>.sno/.ref --
    discovered, never passed as a flag, identical to sidecar_in_path(). Absent -> None."""
    cand = Path(src_path).with_suffix(".xfail")
    return str(cand) if cand.is_file() else None


def read_xfail_sidecar(x_path, banner_re, entries):
    """Attach family.xfail blocks to entries BY NAME. Absent file, or an entry with no block, leaves
    entry.xfail_reason as None. ⛔ REFUSES on a block naming no entry (the shape a rename or a
    half-finished conversion produces) and on a reason attached to an entry NOT marked XFAIL. The
    second refusal is the one that earns its keep: when an XPASS is promoted, the ' XFAIL' comes off
    the banner, and a reason left behind would be a stale explanation for a red that no longer
    exists -- documentation that lies is worse than none, and this makes the promotion prove it is
    complete instead of merely looking complete."""
    if x_path is None or not Path(x_path).is_file():
        return
    lines = Path(x_path).read_text().splitlines()
    by_name, i = {}, 0
    while i < len(lines):
        m = banner_re.match(lines[i])
        if not m:
            raise ValueError(f"expected a banner at {x_path} line {i + 1}: {lines[i]!r}")
        name = m.group("name")
        if name in by_name:
            raise ValueError(f"{x_path}: duplicate reason block for entry {name!r}")
        i += 1
        seg = []
        while i < len(lines) and not banner_re.match(lines[i]):
            seg.append(lines[i]); i += 1
        by_name[name] = "\n".join(seg).strip()
    by_entry = {e.name: e for e in entries}
    unknown = sorted(set(by_name) - set(by_entry))
    if unknown:
        raise ValueError(f"{x_path}: reason blocks with no matching entry: {unknown}")
    stale = sorted(n for n in by_name if not by_entry[n].xfail)
    if stale:
        raise ValueError(f"{x_path}: reason given for entries not marked XFAIL: {stale} -- either the "
                         f"' XFAIL' banner suffix was dropped (restore it) or the entry was promoted "
                         f"after an XPASS (delete its reason block in the same commit)")
    for n, reason in by_name.items():
        by_entry[n].xfail_reason = reason


def write_xfail_sidecar(entries, out_x, comment_open, comment_close):
    """Write family.xfail iff at least one entry carries a reason. Returns True if written.
    ⛔ Refuses a reason on a non-XFAIL entry for the same cause read_xfail_sidecar() refuses it --
    a writer that can emit a file its own reader rejects is not a round trip."""
    withreason = [e for e in entries if e.xfail_reason]
    if not withreason:
        return False
    bad = [e.name for e in withreason if not e.xfail]
    if bad:
        raise ValueError(f"reason given for entries not marked XFAIL: {bad}")
    out = []
    for e in withreason:
        out.append(make_banner_cfg(e.seq, e.name, comment_open, comment_close, xfail=e.xfail))
        out.extend(e.xfail_reason.splitlines())
    Path(out_x).write_text("\n".join(out) + "\n")
    return True


# ========================================================== suite reader ===
ONE_LINE_TAG_RE = re.compile(r";\* (\S+)$")


def _is_entry_start(line):
    """True at a banner (block start) or a one-line entry (which always ends in the mandatory ;* tag --
    format spec: 'the tag is standard on every line, not optional'). A block's own body lines are raw,
    unjoined original statement text and do not end this way in practice, so this is what lets the block
    reader below know when to STOP without needing a banner on the far side."""
    if line[:1] == "*" and BANNER_RE.match(line):
        return True
    return bool(ONE_LINE_TAG_RE.search(line))


def _lf_lines(text):
    """⛔⭐ LF IS THE ONLY LINE BREAK IN A CONTAINER (the coo 2026-09-28, on hq_snobol4's csnobol4_suite/alph): str.splitlines() also
    breaks on CR, VT, FF, FS, GS, RS, NEL, LS and PS, and Path.read_text() turns every CR into LF before it -- so a ref whose oracle
    output carries one of those bytes (alph prints &ALPHABET; ipl progs/puzz prints a form feed, progs/filexref a CR) was read back
    as more lines than the program wrote, and the entry read FAIL against output equal to sbl -bf byte for byte. One trailing LF is
    not a line, exactly splitlines()'s convention: "a\\n\\nb\\n" -> ["a", "", "b"], "" -> []."""
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return lines


def _read_lf_lines(path):
    """A container read as bytes (no newline translation), decoded strictly as UTF-8 exactly as read_text() did, split on LF only."""
    return _lf_lines(Path(path).read_bytes().decode("utf-8"))


def read_suite(sno_path, ref_path, in_path=None, x_path=None, w_path=None, a_path=None, modes=None):
    """⛔ FOUND AND FIXED (corpus-suites-consolidation, gc family): a block used to be read as running to
    the NEXT banner -- correct only when the next entry is ALSO a block. A block immediately followed by
    one or more one-line entries (no banner of their own, e.g. gc.sno's 210_gc_deep_nesting -> 211/212/213
    one-liners -> 214's banner) had its .sno-side reader swallow those one-liners' raw text as more of the
    block's body (fixed by stopping at _is_entry_start, not just a banner) -- but that alone still leaves
    the .ref side ambiguous, because a one-liner's ref line carries no marker of its own (only the .sno
    side tags it). So the .ref side is read in a SEPARATE pass once the .sno side has produced the
    ordered, correctly-kinded item list: a block's ref segment runs from its banner to the next ref banner
    (or EOF) exactly as before, but one ref line is peeled off the END of that segment for each consecutive
    one-line item known (from the .sno pass) to follow it before the next block -- order preserved, since
    the .ref file's line order for those trailing one-liners is unchanged from write_suite's -- and
    whatever remains is the block's own output. A pure block-to-block or line-to-line run degenerates to
    the original (correct) behaviour: zero trailing one-liners peeled, block gets the whole segment.
    Verified against both existing suites: patterns.sno (all-block) and strings.sno (all ten one-liners
    first, then all three blocks) never exercise the peel path and re-read byte-identically to before this
    fix; gc.sno (the interleaved case) is what exposed it."""
    sno_lines = _read_lf_lines(sno_path)
    ref_lines = _read_lf_lines(ref_path)

    items = []
    si = 0
    while si < len(sno_lines):
        line = sno_lines[si]
        m = BANNER_RE.match(line) if line[:1] == "*" else None
        if m:
            banner_line, name, xfail = line, m.group("name"), bool(m.group("xfail"))
            si += 1
            body = []
            # ⛔⭐ THE FIRST LINE AFTER A BANNER IS ALWAYS BODY — NEVER TESTED AGAINST _is_entry_start.
            # _is_entry_start()'s docstring assumes a block's body lines "do not end this way IN PRACTICE".
            # That assumption holds only until an ALREADY-CONVERTED ONE-LINER IS PROMOTED TO A BLOCK, which is
            # exactly what re-converting an existing suite does: the promoted line still carries its own
            # mandatory `;* <name>` tag, _is_entry_start() fires on it, the block gets an EMPTY body, and the
            # very same line is then re-read as a one-line entry -- so the entry comes back TWICE.
            # MEASURED (hq_C 2026-08-28, root-causing seat02's convert-corrupts-eval report): re-converting
            # probe/eval wrote 21 entries and read back 22, `ev_fn_beauty_shape` duplicated, block body empty.
            # A format-(B) block ALWAYS has at least one body line, so consuming one unconditionally is safe
            # for every suite -- interleaved ones included -- and is what makes promotion round-trip.
            if si < len(sno_lines):
                body.append(sno_lines[si])
                si += 1
            while si < len(sno_lines) and not _is_entry_start(sno_lines[si]):
                body.append(sno_lines[si])
                si += 1
            items.append(("block", name, banner_line, body, xfail))
        else:
            tag_m = ONE_LINE_TAG_RE.search(line)
            name = tag_m.group(1) if tag_m else f"seq{len(items) + 1}"
            items.append(("line", name, line, None, False))
            si += 1

    entries = []
    ri = 0
    seq = 0
    i = 0
    while i < len(items):
        kind, name, a, b, xfail = items[i]
        seq += 1
        if kind == "line":
            if ri >= len(ref_lines):
                raise ValueError(f"family.ref is shorter than family.sno at seq {seq} ({name})")
            entries.append(Entry("line", seq, name, [a], ref_lines[ri].replace("\\n", "\n")))
            ri += 1
            i += 1
            continue
        banner_line, block_sno = a, b
        if ri >= len(ref_lines) or ref_lines[ri] != banner_line:
            raise ValueError(f"family.ref banner mismatch at seq {seq}: sno={banner_line!r} ref={ref_lines[ri] if ri < len(ref_lines) else None!r}")
        ri += 1
        seg_start = ri
        while ri < len(ref_lines) and not (ref_lines[ri][:1] == "*" and BANNER_RE.match(ref_lines[ri])):
            ri += 1
        seg = ref_lines[seg_start:ri]
        trailing = 0
        j = i + 1
        while j < len(items) and items[j][0] == "line":
            trailing += 1
            j += 1
        if trailing > len(seg):
            raise ValueError(f"family.ref segment after seq {seq} ({name}) has {len(seg)} line(s), too short to hold {trailing} trailing one-line entrie(s)")
        split = len(seg) - trailing
        entries.append(Entry("block", seq, name, block_sno, seg[:split], xfail=xfail))
        for k, ref_line in enumerate(seg[split:]):
            _, lname, lraw, _, _ = items[i + 1 + k]
            seq += 1
            entries.append(Entry("line", seq, lname, [lraw], ref_line.replace("\\n", "\n")))
        i = j
    read_stdin_sidecar(in_path, BANNER_RE, entries)
    read_xfail_sidecar(x_path, BANNER_RE, entries)
    read_wantrc_sidecar(w_path, entries)
    read_argv_sidecar(a_path, entries, modes)
    read_command_line_columns(sno_path, entries, modes)
    return entries


def read_block_suite(src_path, ref_path, banner_re, in_path=None, x_path=None, w_path=None, a_path=None, modes=None):
    """read_suite() for a format-(B)-ONLY family: every entry is a banner-delimited block, so
    there is no one-line/block interleaving to detect (unlike read_suite() above, which also
    carries SNOBOL4's format-A one-line entries and BANNER_RE). Written separately rather than
    parameterizing read_suite() itself, to avoid coupling a second dialect's reading to
    ONE_LINE_TAG_RE / _is_entry_start, which are SNOBOL4-format-A-specific and meaningless here."""
    src_lines = _read_lf_lines(src_path)
    ref_lines = _read_lf_lines(ref_path)
    entries = []
    si = ri = seq = 0
    while si < len(src_lines):
        m = banner_re.match(src_lines[si])
        if not m:
            raise ValueError(f"expected a banner at {src_path} line {si + 1}: {src_lines[si]!r}")
        banner_line, name = src_lines[si], m.group("name")
        xfail = bool(m.groupdict().get("xfail"))
        si += 1
        body = []
        while si < len(src_lines) and not banner_re.match(src_lines[si]):
            body.append(src_lines[si])
            si += 1
        if ri >= len(ref_lines) or ref_lines[ri] != banner_line:
            got = ref_lines[ri] if ri < len(ref_lines) else None
            raise ValueError(f"{ref_path} banner mismatch at seq {seq + 1} ({name}): sno={banner_line!r} ref={got!r}")
        ri += 1
        seg_start = ri
        while ri < len(ref_lines) and not banner_re.match(ref_lines[ri]):
            ri += 1
        seq += 1
        entries.append(Entry("block", seq, name, body, ref_lines[seg_start:ri], xfail=xfail))
    read_stdin_sidecar(in_path, banner_re, entries)
    read_xfail_sidecar(x_path, banner_re, entries)
    read_wantrc_sidecar(w_path, entries)
    read_argv_sidecar(a_path, entries, modes)
    read_command_line_columns(src_path, entries, modes)
    return entries


_INCLUDE_PATTERNS = [
    # A QUOTED LITERAL THAT NAMES A FILE (row aisnobol-all-eight-..., cto 2026-09-07): the SPITBOL core opens its
    # library by a name held in a variable (LOADEX...IDX. = "spitlib.idx" then INPUT(.F, 15, LOADEX...IDX.)), so no
    # directive names it; a quoted token shaped like a file name is queued and, like every other name here, copied
    # ONLY if it exists beside the suite -- a literal that is not a file is a silent no-op, as before.
    re.compile(r'["\']([A-Za-z0-9_][A-Za-z0-9_.-]*\.[A-Za-z0-9]{1,4})["\']'),
    re.compile(r'\$include\s+"([^"]+)"'),   # Icon
    re.compile(r"-INCLUDE\s+'([^']+)'"),    # SNOBOL4 / Snocone
    re.compile(r'-INCLUDE\s+"([^"]+)"'),    # SNOBOL4 / Snocone, double-quote form
    # ⭐ AN INCLUDE DIRECTIVE IS NOT THE ONLY WAY A PROGRAM NAMES A COMPANION FILE, and the other way
    # fails SILENTLY rather than loudly. Icon's open("X") reads a data file relative to the RUNNING
    # file's directory exactly as $include does, but a missing one does not error -- open() simply
    # fails, the program keeps going, and the entry grades as wrong-output with rc=0. Measured on
    # rung36_jcon_fncs1.icn (tests-consolidate-icon): run from its own directory it is byte-identical
    # to its .expected in BOTH modes; run from an isolated temp dir it prints `----> none` and drops
    # 15 lines of file content, rc=0 throughout. That is the same false-green this whole mechanism
    # exists to stop (the `prepro` $include case, cured one file-reference form over), caught here
    # BEFORE a conversion shipped rather than after one silently failed.
    # ⛔ Safe by construction for write-opens: open("foo.baz","w") names a file that does not exist in
    # the family dir, and the caller only copies a name for which `src_companion.is_file()` holds, so
    # a write target is skipped rather than manufactured.
    re.compile(r'\bopen\s*\(\s*"([^"]+)"'),  # Icon open("X") data companion
    # ⛔⭐ SNOBOL4's INPUT/OUTPUT file-association functions name a companion as a quoted ARGUMENT, not
    # via a directive keyword -- INPUT(.holder, 10, , "name.dat") -- so none of the patterns above ever
    # matched this form at all (row suite-harness-argv-echoes-a-mktemp-path-so-diagnostic-programs-
    # cannot-be-graded, probe/csnobol4_triage/input_eof_hang.sno: convert_one's own candidate ran
    # companion-less in a fresh temp dir and got a DIFFERENT bug -- INPUT() on a MISSING file hangs
    # forever, where the original's genuinely-present-but-empty .dat fails cleanly -- measured, not
    # assumed). Matches either quote style; SNOBOL4 accepts both interchangeably.
    # ⛔⭐ BOTH CHARACTER CLASSES MUST EXCLUDE NEWLINE, AND THE PREFIX MUST BE NON-GREEDY (hq_P seat08
    # 2026-09-04, row snobol4-every-non-package-source-...): the original `[^)]*["\']([^"\']+)["\']` let a
    # SHORT quoted non-filename argument earlier in the same call -- e.g. INPUT(.INPUT, 9, '[-f0 -r4194304]')
    # (a scale/mode-flags string, not a companion file, on a benchmark's INPUT association) -- backtrack PAST
    # its own closing quote, since neither class excludes ')' beyond the immediate one nor '\n': with the
    # flags string's own trailing quote reinterpreted as an OPENING quote, `[^"\']+` then happily swallowed
    # every ')' and newline between it and the NEXT quote anywhere later in the entry (a `TERMINAL = '...'`
    # literal, lines away), capturing hundreds of characters of source as a "companion filename" --
    # OSError: File name too long, the whole board dies. MEASURED: benchmark_calculator-1's absorption
    # (this row) is the first entry to combine this common INPUT(...,'flags') idiom with a later string
    # literal in the same body; excluding '\n' bounds the match to one line (a real filename argument never
    # spans lines) and non-greedy `*?` stops at the FIRST quote pair instead of backtracking past it.
    re.compile(r'\b(?:INPUT|OUTPUT)\s*\([^)\n]*?["\']([^"\'\n]+)["\']'),
    # ⭐ PROLOG'S LOAD DIRECTIVES NAME A COMPANION BY AN UNQUOTED ATOM, USUALLY WITHOUT .pl (the coo 2026-10-10, row
    # instruments-the-harness-stages-a-prolog-companion-...-ceo-1603; hq_prolog's report through the ceo: puzzles' farmer loads bplan.pl
    # by use_module(bplan) and ran without it). use_module/ensure_loaded/consult/include/reexport/load_files take the name as their first
    # argument; library(...) never matches (the name must be followed by , or ), not by a parenthesis). The quoted forms with an
    # extension were already caught by the first pattern. An extension-less name resolves to NAME.pl in _copy_companions.
    re.compile(r"\b(?:use_module|ensure_loaded|consult|include|reexport|load_files)\s*\(\s*'?([a-z][A-Za-z0-9_]*(?:\.pl)?)'?\s*[,)]"),
]
# ⭐ AND THE LIST FORM, :- [a, b]. -- consult as a list, each element a name (split in _companion_files, not one capture)
_PROLOG_CONSULT_LIST = re.compile(r"^\s*:-\s*\[([^\]\n]+)\]\s*\.", re.M)


def _companion_files(text):
    """Filenames an entry names as a companion -- an include directive (Icon `$include "X"`,
    SNOBOL4/Snocone `-INCLUDE 'X'`) or a literal data open (Icon `open("X")`). All of these resolve
    relative to the RUNNING file's directory, which a suite entry materialized into an isolated temp
    dir does not share with its original family_dir unless a caller copies the referenced file in
    first (see run_suite_entry's companion_dir). ⛔ The two kinds fail DIFFERENTLY when the companion
    is absent: an include errors out loudly, a data open just fails and lets the program run on to a
    wrong answer with rc=0 -- so the open case is the one that silently manufactures a green."""
    names = []
    for pat in _INCLUDE_PATTERNS:
        names.extend(pat.findall(text))
    for group in _PROLOG_CONSULT_LIST.findall(text):
        for el in group.split(","):
            el = el.strip().strip("'")
            if re.fullmatch(r"[a-z][A-Za-z0-9_]*(?:\.pl)?", el):
                names.append(el)
    return names


def _copy_companions(text, companion_dir, dest_dir):
    # ⭐ COMPANION $include/-INCLUDE/open()/INPUT()/OUTPUT() FILES (tests-consolidate-icon,
    # rung36_jcon_prepro; extended probe-consolidate-m1-and-small, gim_double_include_once_control;
    # extended again, row suite-harness-argv-echoes-a-mktemp-path-so-diagnostic-programs-cannot-be-
    # graded): a candidate runs from a FRESH temp dir, never the family_dir its original loose file
    # lived in, so an include/open/INPUT()/OUTPUT() directive naming a real, present companion file
    # fails to resolve there even though the file exists and the entry is otherwise green. Concretely:
    # probe/csnobol4_triage/input_eof_hang.sno's empty .dat companion -- present, its INPUT() fails
    # cleanly (rc=0, no output); absent, INPUT() never signals failure and the SAME program HANGS
    # (its own original, pre-reclassification defect, back in full, silently, inside convert_one's own
    # candidate-verification). A caller that knows where the family's companion files live (family_dir
    # at conversion time, or the suite file's own directory at grading time -- they are the same
    # directory by convention) passes companion_dir; a missing or unreferenced companion is a silent
    # no-op here and surfaces as an ordinary run FAILURE downstream, not a special error -- the same as
    # any other missing dependency a program tries to open. Shared by every caller that materializes a
    # candidate into an isolated temp dir (run_suite_entry, convert_one) so the copy logic -- including
    # the two guards below, each hardened by a real prior failure -- never drifts between them.
    if not companion_dir:
        return
    # ⭐ config/ SUBFOLDER (Lon 2026-08-29 zero-subfolders + "make a config folder for those files"): the flat
    # test dir keeps ONLY test sources; runtime companions (includes, .dat/.in data, tracepoint .conf) live in
    # <dir>/config. Search BOTH -- a name found in the flat dir wins (older layouts unchanged).
    # ⛔⭐⭐ AND THE FAILURE MODE OF GETTING THIS WRONG IS A HANG, NOT A RED ENTRY (hq_C, measured 2026-08-29).
    # probe/csnobol4_triage/input_eof_hang.sno exits rc=0 cleanly with its .dat present; with the .dat ABSENT,
    # INPUT() never signals failure and THE SAME PROGRAM HANGS. So a companion the search cannot find does not
    # produce four red entries somebody notices -- it produces a board that STOPS, which reads as
    # infrastructure trouble and sends the next person to the runner instead of to the corpus.
    # ⭐ The measurement behind this branch is hq_C's controlled A/B on the snobol4 rungs, one variable
    # (companion location): companions BESIDE -> m3 1421 pass / 0 fail; the same 16 in config/ WITHOUT this
    # search -> 1417 / 4 fail; WITH it -> 1421 / 0, re-run independently by hq_B with the beside-arm
    # reproducing 1421/0 first as the positive control for the experiment itself.
    _cfg = Path(companion_dir) / "config"
    companion_dirs = [Path(companion_dir)] + ([_cfg] if _cfg.is_dir() else [])
    import shutil
    # ⭐ TRANSITIVE CLOSURE, NOT ONE LEVEL (row harness-copies-companions-to-closure-not-just-the-first-
    # level, hq_T 2026-09-05, on seat06's FINDING-2026-09-04-seat06-corpus-suite-harness-transitive-
    # include-companions-not-copied.md): a companion this function just copied may itself -INCLUDE/open()
    # a companion of its own -- entry includes A, A includes B -- and a single pass over the entry's own
    # text only ever resolved A, leaving B absent from the isolated dest_dir. `queue` is a worklist seeded
    # from the entry's own text and grown by re-scanning each newly-copied file's own text for ITS
    # companions, to a fixed point (closure) -- a 2-level, 3-level or N-level chain all resolve the same
    # way, not just depth-2 (picking a fixed depth would leave depth-3 to be found the same way a month
    # later). `seen` is the cycle guard: a name is popped and dispositioned AT MOST ONCE, so a file that
    # includes itself, or two files that include each other, terminate on the repeat name instead of
    # spinning forever.
    # ⛔ REFUSAL-SAFE AT EVERY LEVEL: a name that resolves to no file in companion_dirs is the same silent
    # no-op it always was (the entry's own run surfaces the miss downstream as an ordinary missing-
    # dependency failure) -- this loop never invents a substitute and never skips scanning a reachable
    # level just because an earlier level's file was missing, so an unresolvable second-level include
    # cannot manufacture a false green one level down the way a naive "stop at the first miss" would.
    seen = set()
    queue = list(_companion_files(text))
    while queue:
        name = queue.pop(0)
        if name in seen:
            continue
        seen.add(name)
        # an ABSOLUTE reference is the program's own scratch path (e.g. /tmp/rung37_fh_test.txt),
        # not a companion in the family dir -- Path(dir)/absolute RETURNS the absolute path for
        # both src and dst, so the copy is file-onto-itself: SameFileError, suite dies boardless
        # (witness: rung37_all after the icon suite conversion, false FAIL on the icon board)
        if Path(name).is_absolute():
            continue
        # ⛔⭐ SEARCH <dir>/config TOO, FOR THE FLAT END STATE (Lon via ceo, 2026-08-29): tests/<lang>/ becomes
        # FLAT -- ALL.{ext,ref,in,csv} side by side, with ZERO subdirectories except ONE `config/` folder
        # holding runtime companions (.inc/.dat/.in/.conf) and docs. Once a family's own directory is gone,
        # its companions live there and NOWHERE ELSE, so a copier that only looks beside the suite file finds
        # nothing and the entry fails as an ordinary missing-dependency error -- indistinguishable from a real
        # defect. Additive and beside-first (the loop breaks on the first hit), so a tree that has NOT
        # flattened yet behaves exactly as before. (merged: hq's config search + ceo's ..-guard/mkdir/loop)
        if ".." in Path(name).parts:
            continue  # a scratch-escaping relative reference (e.g. ../../benchmarks/x.inc) cannot be a companion of an isolated entry; the entry's own run surfaces the miss
        for _cd in companion_dirs:
            src_companion = _cd / name
            dst_companion = Path(dest_dir) / name
            # an extension-less name a Prolog load directive gave resolves as the loader resolves it: NAME.pl beside the entry
            if not src_companion.is_file() and not Path(name).suffix and (_cd / (name + ".pl")).is_file():
                src_companion = _cd / (name + ".pl"); dst_companion = Path(dest_dir) / (name + ".pl")
            if src_companion.is_file() and not (dst_companion.exists() and src_companion.samefile(dst_companion)):
                dst_companion.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(src_companion, dst_companion)
                try:
                    queue.extend(_companion_files(src_companion.read_text()))
                except (OSError, UnicodeDecodeError):
                    pass
                break


def run_suite_entry(paths, entry, tmp_root, modes, ext=".sno", companion_dir=None):
    with tempfile.TemporaryDirectory(dir=tmp_root) as td:
        cand = Path(td) / f"{entry.name}{ext}"
        if getattr(entry, 'stage_upstream', False) and companion_dir:
            _sd = stage_upstream(companion_dir, entry.name, Path(td) / "u", ext)
            if _sd is None:
                refuse(f"{entry.name}: ALL.csv stages it upstream and {companion_dir}/SOURCES.tsv names no upstream file for it")
            cand = _sd / f"{entry.name}{ext}"
        if entry.kind == "line":
            text = entry.sno_lines[0] + "\n"
            expected = entry.ref
        else:
            text = "\n".join(entry.sno_lines) + "\n"
            expected = "\n".join(entry.ref)
        # ⛔⭐ entry.name CAN CARRY A '/' (util_build_package_suite.py qualifies a nested source as
        # "parentdir/stem", e.g. arizona_tests' "general/args") -- the first package whose entries are
        # actually EXECUTED through this exact function to carry one (csnobol4_suite's nested-name
        # collision fix only touched CSV/naming, never grading, since its own nested file was excluded).
        # Without this, cand.write_text() raises FileNotFoundError: the intermediate directory under the
        # fresh tempdir was never created. A no-op for every flat entry name (parents=True on an
        # already-existing Path(td) is a safe no-op), so nothing already grading through this function
        # can regress.
        cand.parent.mkdir(parents=True, exist_ok=True)
        # ⭐ A PACKAGE'S PRELUDE (hq_prolog's ask on CEO-1632, the coo 2026-10-11): ALL.prelude beside the container holds the text every
        # entry runs after -- the package's contract with the oracle that cut its refs (rosetta-prolog: swipl read a double-quoted text
        # as a string, so `:- set_prolog_flag(double_quotes, string).`), as util_logtalk_grade.py prepends the iso flag. Its non-blank
        # lines that are not `#` notes are joined and PREFIXED TO THE ENTRY'S FIRST LINE, never a line of their own, so a message that
        # names a line still names the entry's own. No ALL.prelude: the entry is byte-identical to before.
        _pre = (Path(companion_dir) / "ALL.prelude") if companion_dir else None
        if _pre is not None and _pre.is_file():
            _pt = " ".join(l.strip() for l in _pre.read_text().splitlines() if l.strip() and not l.lstrip().startswith("#"))
            if _pt:
                text = _pt + " " + text
        cand.write_text(text)
        # ⛔⭐ A NESTED ENTRY'S COMPANIONS LIVE BESIDE IT, AND LAND BESIDE IT (the coo 2026-10-01, measured on the regenerated arizona_tests
        # container): the entry runs in cand.parent (td/general for "general/fncs1"), but its companions were looked up in the suite's
        # own directory and copied into td -- so fncs1's open("gc1.icn"), prepro's prepro.dat and recent's data files were never
        # there, and three programs that match their refs when staged beside the source read FAIL here. The lookup directory is the
        # suite directory plus the entry's own subdirectory (the subdirectory's copy wins, the suite directory's is kept as a fallback),
        # and the copy lands where the program runs; a flat entry is unchanged.
        _sub = Path(entry.name).parent
        _cdir = (Path(companion_dir) / _sub) if (companion_dir and str(_sub) not in ("", ".")) else companion_dir
        if _cdir != companion_dir:
            _copy_companions(text, companion_dir, cand.parent)   # the suite directory first, as before, so nothing a nested entry found there is lost
        _copy_companions(text, _cdir, cand.parent)               # then the entry's own directory, which wins where both hold the name
        # PROGRAM ARGUMENTS THAT NAME A COMPANION (AIS HSORT: its input file name arrives in HOST(0)): an argv token
        # that is a file beside the suite travels with the entry the same way a named include does.
        for _tok in (getattr(entry, 'argv', None) or []):
            if _cdir and _tok and '/' not in _tok and (Path(_cdir) / _tok).is_file() and not (cand.parent / _tok).exists():
                (cand.parent / _tok).write_bytes((Path(_cdir) / _tok).read_bytes())
        return run_all_modes(paths, cand, expected, Path(td), modes, stdin_text=entry.stdin,
                             want_rc=getattr(entry, 'want_rc', 0), prog_argv=getattr(entry, 'argv', None),
                             mask=getattr(entry, 'mask', None),
                             where=entry.name, bin_dir=Path(td), heap_kb=getattr(entry, 'heap_kb', None), stack_kb=getattr(entry, 'stack_kb', None),
                             compile_args=getattr(entry, 'compile_args', None), out_files=getattr(entry, 'out_files', None),
                             merge_stderr=getattr(entry, 'merge_stderr', False), ws_blind=getattr(entry, 'compare_ws', False),
                             answer_file=getattr(entry, 'answer_file', None))


# ================================================================== CLI ===
def cmd_capture_oracle_refs(args):
    """For a family with NO committed .ref files at all (oracle-graded loose files, e.g.
    probe/conformance -- see corpus-suites-consolidation task, probe-consolidate-conformance):
    synthesizes a .ref for every source file whose CURRENT m3 AND m4 output+returncode both agree
    with a FRESH live run of the correctness oracle (SPITBOL `-bf` by default, or --lang prolog's
    swipl), mirroring test_one_witness.sh's exact contract. Writes nothing for a stem that
    disagrees, that already has a .ref (unless --force), or where the oracle itself doesn't run
    cleanly -- those stay exactly as they are on disk, never touched. This is a ONE-TIME bootstrap
    step: once a .ref exists, the family behaves exactly like every other suite family (cmd_convert/
    convert-blocks reads a static .ref, same as always) -- grading never re-invokes the oracle after
    this point, matching how every other family's .ref is a frozen snapshot, not a live re-check on
    every run. --lang defaults to snobol4 (unchanged behavior, glob *.sno) for every existing
    caller; passing --lang prolog globs *.pl and captures against swipl instead (2026-08-29, see
    tests-consolidate-prolog's ~77-file no-.ref backlog -- the gap this parameter closes)."""
    paths = resolve_paths()
    check_scrip(paths)
    lang = args.lang or "snobol4"
    # ⛔ A LOOSE-FILE BOOTSTRAP HAS NO ATTRIBUTE ROW TO READ, SO ITS CALLER DECLARES (clause 8 (f), CEO-1281): scrip's compile switches
    # come from --compile-args and from nothing else. It typed --stlimit for snobol4, snocone, rebus and icon until 2026-09-26.
    paths["scrip_extra"] = validate_args_cell(args.compile_args, "compile_args", "capture-oracle-refs --compile-args") or []
    ext = LANG_CONFIGS[lang]["ext"] if lang != "snobol4" else ".sno"
    oracle_bin, flags = resolve_oracle_bin(paths, lang)
    print(f"oracle: {oracle_bin} {flags}", file=sys.stderr)
    modes = parse_modes(args.modes, "capture-oracle-refs")
    family_dir = Path(args.family_dir).resolve()   # ⛔ ABSOLUTE, ALWAYS (ceo s283h): run_m3/run_ast set subprocess cwd to the FILE'S OWN PARENT while argv carries this path -- a caller-relative path then resolves against the wrong dir, scrip cannot open it (rc=1), and every 'original' baseline is silently garbage: convert then REFUSES green families ('NEITHER form reproduced') or, worse, validates a candidate against the broken baseline. Measured on probe/kw (15/15 false FAIL) and probe/define (false-validated) 2026-08-29.
    srcs = sorted(family_dir.glob(f"*{ext}"))
    if not srcs:
        refuse(f"no {ext} files found under {family_dir}")

    green, red = [], []
    # ⛔⭐ A SCRIP-RULED PIN IS NOT THE ORACLE'S TO OVERWRITE (row/ask hq_C -> hq_T 2026-09-04). `pin-ref`
    # records, in ALL.refpins.tsv beside the rungs, every entry whose ref disagrees with the oracle ON A
    # STATED RULING -- the witness being Lon's lambda-deferred-target sugar, which SPITBOL fails and always
    # will. Without this consultation `--force` would faithfully restore the oracle's answer and silently undo
    # a decision nobody remembers making; the refusal is what turns the ledger from documentation into a
    # mechanism. ⭐ It refuses rather than skipping quietly, because "I left this alone" and "I never looked"
    # are the same output otherwise.
    _pins = read_refpins(getattr(args, "family_dir", "") and Path(args.family_dir) / "ALL.sno" or "")
    for i, src in enumerate(srcs, 1):
        ref_path = src.with_suffix(".ref")
        _xr = read_extension_refs(src.parent / "EXTENSIONS.tsv")
        if src.name in _xr or src.stem in _xr:
            _r = _xr.get(src.name) or _xr[src.stem]
            refuse(f"{src.name} carries an EXTENSION REF cut by {_r['oracle']} ({_r['feature']}; {_r['ruling']!r}) -- this suite's oracle "
                   f"does not answer that extension, so capturing its answer would overwrite the ruled ref. Exclude this stem from the capture.")
        if src.stem in _pins:
            refuse(f"{src.stem} carries a SCRIP-RULED ref pin ({_pins[src.stem]['ruling']!r}, "
                   f"{_pins[src.stem]['measurer']} {_pins[src.stem]['date']}) -- capturing the oracle's answer "
                   f"here would undo that ruling. Re-rule it with `pin-ref` if it is wrong, or exclude this "
                   f"stem from the capture.")
        if ref_path.is_file() and not args.force:
            print(f"[{i}/{len(srcs)}] {src.stem}: SKIP (already has a .ref)", file=sys.stderr)
            continue
        # ⛔⭐⭐ THE STDIN COMPANION IS FED TO ALL THREE ARMS -- IT USED TO BE A FLAT REFUSAL, AND THE REASON
        # THE REFUSAL EXISTED IS THE REASON THE FEED HAS TO BE PROVEN (ceo freeze 2026-08-30 on hq_P's catch;
        # freeze lifted with this one edge, cured here). This gate's whole safety argument is THREE-WAY
        # AGREEMENT -- m3, m4 and the oracle producing the same bytes. That argument COLLAPSES when the
        # disagreement-producing input is missing from all three arms at once: rung36_jcon_recogn ran with no
        # stdin, ALL THREE ARMS AGREED ON EMPTY, and a 1-byte vacuous oracle was minted that would have passed
        # forever (withdrawn, corpus 705cd7ad1).
        # ⭐ THE GENERAL FORM, AND IT IS WHY N ARMS DID NOT HELP: AGREEMENT IS ONLY EVIDENCE WHEN THE ARMS CAN
        # DISAGREE. Three instruments sharing one missing input are one instrument reported three times, and
        # the unanimity reads as MORE confidence rather than less. A fourth arm would not have helped.
        # ⛔ SO FEEDING IS NOT ENOUGH -- AN UNPROVEN FEED IS THE SAME DEFECT WITH BETTER MANNERS. If the text
        # never reaches the program (a plumbing regression here, a dialect whose runner drops stdin, a
        # companion that is really a by-name data file), all three arms are once again sharing one missing
        # input and once again agreeing. The unfed control run below is what makes the feed FALSIFIABLE, and
        # it is the only part of this block that can detect a future regression in the feed itself.
        # ⛔ The old REFUSAL survives, unchanged in spirit, for every path that CANNOT feed -- see
        # loose_stdin_companion(): ambiguity and non-UTF-8 mint nothing and say why. A vacuous ref is worse
        # than a missing one: a missing ref leaves a file ungraded and VISIBLE, while a vacuous ref grades it
        # against nothing forever and reads as coverage.
        stdin_text, stdin_path, stdin_refusal = loose_stdin_companion(src)
        if stdin_refusal:
            red.append((src.stem, "REFUSED: " + stdin_refusal))
            print(f"[{i}/{len(srcs)}] {src.stem}: ⛔ REFUSED ({stdin_refusal.split(' -- ')[0]})", file=sys.stderr)
            continue
        ora_text, ora_rc, ora_kind = run_oracle(oracle_bin, flags, src, paths["timeout"], stdin_text=stdin_text)
        if ora_kind != "RAN":
            red.append((src.stem, f"oracle itself {ora_kind}"))
            print(f"[{i}/{len(srcs)}] {src.stem}: RED (oracle {ora_kind})", file=sys.stderr)
            continue
        # ⭐ THE CONTROL ARM (format Law 4: agreement only counts when the arms CAN disagree). One extra
        # oracle run, unfed, on stdin-bearing stems only -- rare, so the cost is noise. If feeding the
        # companion changes NOTHING about the oracle's kind/text/rc, then this stem's stdin is not reaching
        # the program and the three-way agreement about to be computed is agreement on a shared missing
        # input all over again. Two real causes, one signature: the feed is broken, or the file named
        # <stem>.in/.input is not stdin at all but a by-name data file that merely collides with the stdin
        # spelling. ⛔ Both want a human, and neither wants a minted ref. A HANG or a different rc counts as
        # a difference -- a program that blocks unfed and runs fed is exactly a stem that IS stdin-dependent.
        if stdin_text is not None:
            unfed_text, unfed_rc, unfed_kind = run_oracle(oracle_bin, flags, src, paths["timeout"])
            if (unfed_kind, unfed_text, unfed_rc) == (ora_kind, ora_text, ora_rc):
                red.append((src.stem, "REFUSED: feeding %s changed NOTHING in the oracle (same kind/text/rc "
                                      "fed and unfed) -- either stdin is not reaching this program or that "
                                      "file is a by-name data companion, not stdin; agreement here would "
                                      "again be agreement on a shared missing input" % stdin_path.name))
                print(f"[{i}/{len(srcs)}] {src.stem}: ⛔ REFUSED (feeding {stdin_path.name} changed nothing)", file=sys.stderr)
                continue
        agreements = []
        all_agree = True
        for m in modes:
            if m == "m3":
                v = run_m3(paths, src, ora_text, stdin_text=stdin_text)
            elif m == "m4":
                with tempfile.TemporaryDirectory() as td:
                    v = run_m4(paths, src, ora_text, Path(td), stdin_text=stdin_text)
            else:
                refuse(f"unknown mode {m!r} (this command supports m3/m4 only, never ast)")
            agree = (v.kind == "PASS") and (v.returncode == ora_rc)
            agreements.append(f"{m}={'AGREE' if agree else f'{v.kind}(rc={v.returncode} vs oracle {ora_rc})'}")
            all_agree = all_agree and agree
        # ⛔⭐⭐ REFUSE TO MINT AN EMPTY REF, WHATEVER THE REASON. Two independent routes to the same failure
        # were found on 2026-08-30, hours apart, by two different seats:
        #   hq_P  -- rung36_jcon_recogn ran with NO STDIN; all three arms agreed on empty.
        #   seat05 -- swipl's `-g halt` fires before/instead of a `:- initialization(main,main)` goal, so the
        #             ORACLE produces empty for a whole class of prolog programs that run fine bare.
        # Different causes, IDENTICAL SIGNATURE: every arm agrees, and what they agree on is NOTHING.
        # ⭐ So the guard belongs on the SIGNATURE, not on either cause. An existence check for a stdin
        # companion cannot see seat05's case (there is no companion), and a swipl-flag fix cannot see hq_P's.
        # Empty-agreement is the observable both share, and it will be the observable of the third route
        # nobody has found yet. It is ALSO the backstop for the feed above: if a future change breaks the
        # plumbing on a path the unfed control does not cover, this is what still refuses to write the ref.
        # ⛔ A legitimately-silent program is the acceptable cost: its ref is one line to author deliberately,
        # whereas a vacuous ref grades its file against nothing FOREVER and reads as coverage. Refusing costs
        # a human a minute; minting costs a suite its meaning, silently and permanently.
        # ⛔⭐ RESTORED 2026-08-30 (hq_B) AFTER BEING DELETED WITH NO REPLACEMENT by d67c0f6c, whose subject
        # and body describe three unrelated builder fixes and never mention removing a guard. It came back
        # only because a rebase conflict one hunk ABOVE forced someone to read this function -- the deletion
        # itself merged perfectly clean. ⭐ That is the durable lesson: a removed check has no failing test
        # to announce it. Nothing goes red, the tool gets quieter, and the loss is only visible to a reader
        # who already knew the check was supposed to be here.
        if all_agree and not ora_text.strip():
            red.append((src.stem, "REFUSED: all arms agreed on EMPTY output -- agreement on nothing is not "
                                  "agreement; mint a ref by hand if this program is genuinely silent"))
            print(f"[{i}/{len(srcs)}] {src.stem}: ⛔ REFUSED (all arms agree, but on EMPTY output)", file=sys.stderr)
            continue
        if all_agree:
            ref_path.write_text(ora_text + "\n")
            green.append(src.stem)
            _fed = f" [stdin: {stdin_path.name}]" if stdin_text is not None else ""
            print(f"[{i}/{len(srcs)}] {src.stem}: GREEN ({' '.join(agreements)}){_fed} -- .ref written", file=sys.stderr)
        else:
            red.append((src.stem, " ".join(agreements)))
            print(f"[{i}/{len(srcs)}] {src.stem}: RED ({' '.join(agreements)})", file=sys.stderr)

    print(f"\n{len(green)} green (.ref written, ready for `convert`) -- {len(red)} red (untouched, no .ref):",
          file=sys.stderr)
    for name, reason in red:
        print(f"   RED {name}: {reason}", file=sys.stderr)
    # ⛔⭐⭐ ANY RED EXITS NON-ZERO. This printed a full RED summary and exited 0 until 2026-08-30 (measured by
    # ceo on a scratch family; hq_B's row capture-feed-stdin-and-red-exit) -- which is format Law 3's exact
    # two-audiences shape, "could not measure" and "measured fine" sharing one exit code, sitting on the very
    # tool that carries Law 4. ⭐ A HUMAN reading the terminal sees the ⛔ lines and is fine; a SCRIPT sees
    # rc=0 and marches on, and `capture-oracle-refs D && convert D ...` then converts a family whose refusals
    # it never learned about. The two audiences do not read the same channel, so the channel BOTH read -- the
    # exit code -- is the one that has to carry the verdict.
    # rc=1 -- ran fine, some stems are RED and were left untouched. rc=2 (refuse()) is could-not-measure-AT-ALL,
    # ⛔ UNIFIED FROM rc=3 on 2026-09-04 (ceo CEO-233, row harness-refusal-exit-code-unified-on-rc-2) onto the
    # fleet's one refusal code -- see refuse()'s own docstring. The distinction this comment was defending is
    # intact: rc=1 still means "measured, some stems red", rc=2 now means "could not measure", and they are still
    # different codes. Only the NUMBER moved, onto the one every bash caller and lib_gate.sh already test for.
    sys.exit(1 if red else 0)


def cmd_convert(args):
    paths = resolve_paths()
    check_scrip(paths)
    modes = parse_modes(args.modes, "convert")
    family_dir = Path(args.family_dir).resolve()   # ⛔ ABSOLUTE, ALWAYS (ceo s283h): run_m3/run_ast set subprocess cwd to the FILE'S OWN PARENT while argv carries this path -- a caller-relative path then resolves against the wrong dir, scrip cannot open it (rc=1), and every 'original' baseline is silently garbage: convert then REFUSES green families ('NEITHER form reproduced') or, worse, validates a candidate against the broken baseline. Measured on probe/kw (15/15 false FAIL) and probe/define (false-validated) 2026-08-29.
    pairs = discover_pairs(family_dir)
    if not pairs:
        refuse(f"no .sno/.ref pairs discovered under {family_dir}")
    print(f"discovered {len(pairs)} pairs in {family_dir}", file=sys.stderr)

    # ⛔ DELIBERATE SKIP, NEVER SILENT DROP (Snocone removed-syntax precedent, task ## NEXT / ## SNOCONE):
    # a stem named here is loudly excluded from THIS conversion run and left as a loose file pair --
    # not deleted, not converted. Reason is mandatory and printed so a skip can never be mistaken for
    # a file the harness simply failed to notice.
    skip_names = set(n for n in (args.skip.split(",") if args.skip else []) if n)
    if skip_names:
        skipped = [p for p in pairs if p[0].stem in skip_names]
        pairs = [p for p in pairs if p[0].stem not in skip_names]
        for sno, ref in skipped:
            print(f"⛔ SKIPPING (deliberate): {sno.stem} -- {args.skip_reason or 'no reason given'}", file=sys.stderr)
        unmatched = skip_names - {p[0].stem for p in skipped}
        if unmatched:
            refuse(f"--skip named stem(s) not found in {family_dir}: {sorted(unmatched)}")
        if not pairs:
            refuse(f"--skip excluded every discovered pair under {family_dir} -- nothing left to convert")


    entries = []
    failures = []
    # ⭐ Resolved ONCE, up front, through the single loose-companion authority -- and kept, because the
    # same text has to reach three separate places that would otherwise each re-derive it: convert_one's
    # original+candidate runs, the .in sidecar, and the on-disk re-validation below.
    stdin_by_stem = {}
    for sno, _ref in pairs:
        _text, _path, _refusal = loose_stdin_companion(sno)
        if _refusal:
            refuse(f"{sno.name}: {_refusal}")
        stdin_by_stem[sno.stem] = _text
    _fed_n = sum(1 for v in stdin_by_stem.values() if v is not None)
    if _fed_n:
        print(f"{_fed_n} of {len(pairs)} pairs carry a stdin companion -- fed to every arm and written to the .in sidecar", file=sys.stderr)
    tmp_root = Path(tempfile.mkdtemp(prefix="csh_"))
    try:
        for seq, (sno, ref) in enumerate(pairs, start=1):
            entry, report = convert_one(paths, sno, ref, seq, tmp_root, modes, companion_dir=sno.parent,
                                        stdin_text=stdin_by_stem[sno.stem])
            status = "OK" if report["ok"] else "FAIL"
            print(f"[{seq}/{len(pairs)}] {sno.stem}: {status} ({report['reason'][:80]})", file=sys.stderr)
            if entry is not None:
                entries.append(entry)
            else:
                failures.append((sno.stem, report["reason"]))
    finally:
        import shutil
        shutil.rmtree(tmp_root, ignore_errors=True)

    if failures:
        print(f"⛔ {len(failures)} entries FAILED byte-equal validation -- NOTHING WRITTEN, NOTHING DELETED:", file=sys.stderr)
        for name, reason in failures:
            print(f"   {name}: {reason}", file=sys.stderr)
        sys.exit(1)

    one_line_n = sum(1 for e in entries if e.kind == "line")
    block_n = sum(1 for e in entries if e.kind == "block")
    # out_in is DERIVED, never a flag -- sidecar_in_path()'s own doctrine: every downstream consumer
    # (boards, gates, cmd_run) discovers <family>.in by convention, so a suite cannot silently run
    # without its input just because one caller was not taught a new argv.
    out_in = str(Path(args.out_sno).with_suffix(".in"))
    wrote_in = write_suite(entries, args.out_sno, args.out_ref, out_in=out_in)
    print(f"✅ wrote {args.out_sno} / {args.out_ref}{' / ' + out_in if wrote_in else ''}: {len(entries)} entries "
          f"({one_line_n} one-line, {block_n} multi-line-block)", file=sys.stderr)

    # close the loop: re-read the WRITTEN files and re-validate every entry against the originals
    # ⛔ MATCH BY NAME, NEVER BY POSITION (seat06 2026-08-29): write_suite() deliberately reorders
    # entries (all format-A lines first, then all format-B blocks -- see its own docstring) for a
    # real, previously-fixed correctness reason, so `reread`'s order does not track `pairs`'
    # discovery order (alphabetical) whenever a batch mixes line and block entries. A positional
    # `zip(pairs, reread)` then silently cross-compares UNRELATED entries -- two genuinely-correct
    # conversions can each get reported as a false "ON-DISK RE-VALIDATION FAILED" simply because a
    # third entry's kind shuffled the read-back order. Confirmed on a 3-entry repro (fence_arbno_top
    # [line], ident_differ_inline [block], os1_runtime_k [line] -- discovery order != reread order,
    # and the loop below used to compare ident's own orig output against os1's suite output).
    # ⛔ READ THE .in BACK TOO (sidecar_in_path, not out_in: if no entry carried stdin the file was never
    # created and is_file() correctly degrades to None -> /dev/null). Re-validating without it would run
    # every suite entry unfed against a ref minted fed -- the re-validation would then be measuring a
    # different program than the one just written, which is the whole failure this parameter closes.
    reread = read_suite(args.out_sno, args.out_ref, in_path=sidecar_in_path(args.out_sno))
    by_name = {e.name: e for e in reread}
    tmp_root = Path(tempfile.mkdtemp(prefix="csh_verify_"))
    mismatches = []
    try:
        for sno, ref in pairs:
            written = by_name[sno.stem]
            orig_verdicts = run_all_modes(paths, sno, ref.read_text(), tmp_root, modes,
                                           stdin_text=stdin_by_stem[sno.stem])
            suite_verdicts = run_suite_entry(paths, written, tmp_root, modes, companion_dir=sno.parent)
            if not all(suite_verdicts[m].behaviorally_equal(orig_verdicts[m]) for m in modes):
                mismatches.append((sno.stem, orig_verdicts, suite_verdicts))
    finally:
        import shutil
        shutil.rmtree(tmp_root, ignore_errors=True)

    if mismatches:
        print(f"⛔ ON-DISK RE-VALIDATION FAILED for {len(mismatches)} entries -- the WRITTEN suite "
              f"files diverge from a fresh re-read/re-run. DO NOT delete originals.", file=sys.stderr)
        for name, o, s in mismatches:
            print(f"   {name}: orig={o} suite={s}", file=sys.stderr)
        sys.exit(1)

    # ⛔ THE COUNT NAMES THE COMPANIONS TOO. A stdin-bearing stem is THREE loose files, not two, and its
    # companion's content is only safe to delete because it now lives in the .in sidecar just written and
    # re-validated. Saying "N*2" while a third file sits there is how a companion gets left behind as
    # orphaned litter -- or, worse, read as still-load-bearing and the conversion reverted.
    print(f"✅ ON-DISK RE-VALIDATION PASSED: all {len(entries)} entries byte-equal, both directions, "
          f"modes={modes}. Safe to delete the {len(pairs)*2 + _fed_n} original files "
          f"({len(pairs)} .sno + {len(pairs)} .ref"
          f"{f' + {_fed_n} stdin companion(s), now carried by ' + Path(out_in).name if _fed_n else ''}).",
          file=sys.stderr)
    sys.exit(0)


def cmd_convert_blocks(args):
    """convert, but for a LANG_CONFIGS dialect and format-(B)-ONLY: never attempts a one-line
    join (parser-ladder families are format-B by task-spec design, not by join-failure fallback).
    Same byte-equal-or-no-delete law as cmd_convert: after --skip filtering, ANY remaining
    original that is not green refuses the WHOLE run, nothing written/deleted -- deliberately NOT
    an auto-skip-if-red behavior, so every excluded fixture is a named, reasoned --skip, same
    discipline as the SNOBOL4 side's stdin-bearing-tests and Snocone-removed-syntax precedents."""
    paths = resolve_paths()
    check_scrip(paths)
    if args.lang not in LANG_CONFIGS:
        refuse(f"unknown --lang {args.lang!r} -- known: {sorted(LANG_CONFIGS)}")
    cfg = LANG_CONFIGS[args.lang]
    ext, comment_open, comment_close = cfg["ext"], cfg["comment_open"], cfg["comment_close"]
    modes = parse_modes(args.modes or cfg["modes"], "convert-blocks")
    family_dir = Path(args.family_dir).resolve()   # ⛔ ABSOLUTE, ALWAYS (ceo s283h): run_m3/run_ast set subprocess cwd to the FILE'S OWN PARENT while argv carries this path -- a caller-relative path then resolves against the wrong dir, scrip cannot open it (rc=1), and every 'original' baseline is silently garbage: convert then REFUSES green families ('NEITHER form reproduced') or, worse, validates a candidate against the broken baseline. Measured on probe/kw (15/15 false FAIL) and probe/define (false-validated) 2026-08-29.
    pairs = discover_pairs(family_dir, ext=ext)
    if not pairs:
        refuse(f"no {ext}/.ref pairs discovered under {family_dir}")
    print(f"discovered {len(pairs)} pairs in {family_dir}", file=sys.stderr)

    skip_names = set(n for n in (args.skip.split(",") if args.skip else []) if n)
    if skip_names:
        skipped = [p for p in pairs if p[0].stem in skip_names]
        pairs = [p for p in pairs if p[0].stem not in skip_names]
        for src, ref in skipped:
            print(f"⛔ SKIPPING (deliberate): {src.stem} -- {args.skip_reason or 'no reason given'}", file=sys.stderr)
        unmatched = skip_names - {p[0].stem for p in skipped}
        if unmatched:
            refuse(f"--skip named stem(s) not found in {family_dir}: {sorted(unmatched)}")
        if not pairs:
            refuse(f"--skip excluded every discovered pair under {family_dir} -- nothing left to convert")

    entries = []
    # ⭐ --xfail (hq_P 2026-08-29, row corpus-crosscheck-probe-total-conversion): format (B) had NO way to
    # carry a KNOWN-RED witness into a suite, while format (A)'s convert_one() has marked xfail=not orig_green
    # since the xfail/xpass extension landed. That asymmetry was not a policy against XFAIL -- this function's
    # own docstring only rules out an AUTOMATIC skip-if-red -- but it collided head-on with Lon's 2026-08-28
    # total-conversion ruling: crosscheck/ must GO, convert-blocks refused every red, so 20 real witnesses had
    # no path into a suite and no path out of the tree. An explicit, named, reasoned --xfail is the same
    # discipline --skip already enforces, and it restores parity with the format law, which names an
    # "XFAIL witness" as a first-class format-(B) block.
    xfail_names = set(n for n in (args.xfail.split(",") if getattr(args, "xfail", "") else []) if n)
    if xfail_names:
        unmatched_x = xfail_names - {p[0].stem for p in pairs}
        if unmatched_x:
            refuse(f"--xfail named stem(s) not found among convertible pairs in {family_dir}: {sorted(unmatched_x)}")
    failures = []
    tmp_root = Path(tempfile.mkdtemp(prefix="csh_blocks_"))
    try:
        for seq, (src, ref) in enumerate(pairs, start=1):
            name = src.stem
            expected_text = ref.read_text()
            # ⭐ .stdin SIDECAR (hq_C 2026-08-28 ruling, q-harness-gap-lang-convert-blocks-no-stdin):
            # a loose <stem>.stdin beside <stem>.icn/.expected feeds that one entry's stdin, mirroring
            # the family-level .in sidecar this same content becomes once written (write_block_suite's
            # out_in= below) -- discovered by convention, never a flag, same principle as
            # sidecar_in_path(). Absent file -> None -> /dev/null, identical to pre-stdin behaviour.
            # ⛔ THROUGH THE ONE RESOLVER (hq_B 2026-08-30). This read `.stdin` and only `.stdin`, so a
            # loose `.in`/`.input` -- the spelling the snobol4 corpus actually uses -- resolved to None,
            # ran the entry against /dev/null, and scored the result as a genuine verdict.
            stdin_text, stdin_path, _stdin_refusal = loose_stdin_companion(src)
            if _stdin_refusal:
                refuse(f"{src.name}: {_stdin_refusal}")
            orig = run_all_modes(paths, src, expected_text, tmp_root, modes, stdin_text=stdin_text)
            orig_green = all(v.kind == "PASS" for v in orig.values())
            want_xfail = name in xfail_names
            # ⛔ AN --xfail STEM THAT IS ACTUALLY GREEN IS AN XPASS, AND XPASS IS AS ACTIONABLE AS A FAILURE
            # (RULES; and measured -- 3 of the 4 .xfail markers in crosscheck/snocone were STALE, their bugs
            # long fixed and nobody promoted the marker). Refusing here is what stops a stale claim being
            # laundered into a suite banner where it would then be believed.
            if want_xfail and orig_green:
                failures.append((name, "--xfail names this stem but the ORIGINAL IS GREEN (XPASS) -- the marker is stale; drop it from --xfail"))
                print(f"[{seq}/{len(pairs)}] {name}: FAIL (XPASS -- --xfail names a green original)", file=sys.stderr)
                continue
            if not orig_green and not want_xfail:
                failures.append((name, f"original file itself is not green: {orig}"))
                print(f"[{seq}/{len(pairs)}] {name}: FAIL (original not green)", file=sys.stderr)
                continue
            body = src.read_text().splitlines()
            # ⛔⭐ NOT .rstrip("\n").splitlines() (row icon-construct-ladder-from-rung-0, seat01): rstrip("\n")
            # deletes EVERY trailing newline, not just the file-ending one, so an entry whose real expected
            # output ends in a genuine blank line (e.g. Icon `write(&subject)` after &subject reverts to "")
            # silently loses it here even though orig_green above was computed against the FULL expected_text
            # and validated correctly -- a green witness materializes into the suite with a truncated .ref.
            # Caught on rung05_scan_scan_nested: real oracle output "second\n\n", this line wrote "second\n".
            # splitlines() alone (no rstrip) is the correct one-trailing-newline-is-not-a-line convention:
            # "second\n\n".splitlines() == ["second", ""] (blank line preserved), "x\n".splitlines() == ["x"]
            # (no phantom blank), matching body's own convention two lines above.
            ref_body = _lf_lines(expected_text)   # LF only: a ref carrying CR/VT/FF/FS/GS/RS keeps them (_lf_lines)
            entries.append(Entry("block", len(entries) + 1, name, body, ref_body, stdin=stdin_text, xfail=want_xfail))
            print(f"[{seq}/{len(pairs)}] {name}: OK{' XFAIL' if want_xfail else ''}{' (stdin)' if stdin_text is not None else ''}", file=sys.stderr)
    finally:
        import shutil
        shutil.rmtree(tmp_root, ignore_errors=True)

    if failures:
        print(f"⛔ {len(failures)} entries FAILED (original not green) -- NOTHING WRITTEN, NOTHING DELETED:", file=sys.stderr)
        for name, reason in failures:
            print(f"   {name}: {reason[:120]}", file=sys.stderr)
        sys.exit(1)

    out_in = str(Path(args.out_src).with_suffix(".in"))
    wrote_in = write_block_suite(entries, args.out_src, args.out_ref, comment_open, comment_close,
                      out_in=out_in,
                      out_x=str(Path(args.out_src).with_suffix(".xfail")) if any(e.xfail_reason for e in entries) else None)
    print(f"✅ wrote {args.out_src} / {args.out_ref}"
          f"{' / ' + out_in if wrote_in else ''}: {len(entries)} entries", file=sys.stderr)

    banner_re = banner_re_for(comment_open, comment_close)
    # sidecar_in_path (not out_in directly): if wrote_in is False -- no entry carried stdin -- the file
    # was never created, and sidecar_in_path's is_file() check correctly degrades to None (-> /dev/null),
    # same auto-discovery cmd_run's --lang path already uses (ZERO argv changes for any caller).
    reread = read_block_suite(args.out_src, args.out_ref, banner_re,
                              in_path=sidecar_in_path(args.out_src), x_path=sidecar_xfail_path(args.out_src), w_path=sidecar_wantrc_path(args.out_src),
                              a_path=sidecar_argv_path(args.out_src))
    # ⛔ MATCH BY NAME, NEVER BY POSITION -- same fix as cmd_convert, applied defensively here too
    # (format-B-only means this path is not currently exposed to write_suite's line-then-block
    # reorder, but a positional zip between two independently-built lists is the same latent class
    # of bug regardless; see cmd_convert's comment for the confirmed repro).
    by_name = {e.name: e for e in reread}
    tmp_root = Path(tempfile.mkdtemp(prefix="csh_blocks_verify_"))
    mismatches = []
    try:
        for src, ref in pairs:
            written = by_name[src.stem]
            # ⛔ hq_C 2026-08-28: diff STDOUT, never verdict kind alone -- re-derive the ORIGINAL's
            # stdin independently from its own loose .stdin sidecar (not from `written.stdin`), so a
            # round-trip that silently lost or corrupted the sidecar produces a genuine behavioral
            # mismatch here instead of two coincidentally-identical verdicts.
            # ⛔ THE FOURTH COPY OF THE SPELLING LIST LIVED HERE, AND ONLY A CONTROL FOUND IT (hq_B
            # 2026-08-30). This re-derivation is deliberately independent of `written.stdin` -- that is
            # hq_C's design above and it is kept exactly -- but it knew `.stdin` alone, so a `.input`-bearing
            # entry converted correctly, wrote a correct .in sidecar, and was then re-validated against an
            # UNFED original: orig FAIL vs suite PASS, reported as "the written suite diverges" when the
            # written suite was right and the check was wrong. ⭐ A false ⛔ is not the harmless direction of
            # this bug -- it tells a seat to distrust a good conversion and go re-derive a correct .ref.
            # Independence is preserved by reading the loose file FRESH, not by keeping a private list.
            orig_stdin_text, _osp, _osr = loose_stdin_companion(src)
            if _osr:
                refuse(f"{src.name}: {_osr}")
            orig_verdicts = run_all_modes(paths, src, ref.read_text(), tmp_root, modes, stdin_text=orig_stdin_text)
            suite_verdicts = run_suite_entry(paths, written, tmp_root, modes, ext=ext, companion_dir=src.parent)
            if not all(suite_verdicts[m].behaviorally_equal(orig_verdicts[m]) for m in modes):
                mismatches.append((src.stem, orig_verdicts, suite_verdicts))
    finally:
        import shutil
        shutil.rmtree(tmp_root, ignore_errors=True)

    if mismatches:
        print(f"⛔ ON-DISK RE-VALIDATION FAILED for {len(mismatches)} entries -- the WRITTEN suite "
              f"files diverge from a fresh re-read/re-run. DO NOT delete originals.", file=sys.stderr)
        for name, o, s in mismatches:
            print(f"   {name}: orig={o} suite={s}", file=sys.stderr)
        sys.exit(1)

    _fed_n = sum(1 for e in entries if e.stdin is not None)
    print(f"✅ ON-DISK RE-VALIDATION PASSED: all {len(entries)} entries byte-equal, both directions, "
          f"modes={modes}. Safe to delete the {len(pairs) * 2 + _fed_n} original files "
          f"({len(pairs)} {ext} + {len(pairs)} .ref"
          f"{f' + {_fed_n} stdin companion(s), now carried by ' + Path(out_in).name if _fed_n else ''}) "
          f"({len(failures)} left as loose, not green, not deleted).", file=sys.stderr)
    sys.exit(0)


def require_lang_for_suite(subcmd, src_path, args):
    """⛔⭐ A READER CHOSEN BY OMISSION IS NOT A CHOICE (row corpus-suite-harness-run-without-lang-silently-
    regrades-the-suite-one-entry-per-line-instead-of-refusing, minted by the cfo 2026-09-08, cured by hq_T 2026-09-10).

    `run` and `pin-ref` take a suite pair and an OPTIONAL --lang, and --lang is what selects the comment syntax
    that DELIMITS ENTRIES. Omitted, they fell back to the SNOBOL4 grammar (`*` banners), which over a Pascal or
    Rebus rungs parses EVERY SOURCE LINE as its own entry -- a completely different population -- and then
    reports failures about that imaginary population with total confidence.
    ⛔ MEASURED on two committed, UNCORRUPT rung suites: `run` on the pascal rungs without --lang printed
    `family.ref is shorter than family.sno at seq 904` for a pair whose ALL.pas and ALL.ref BOTH carry exactly
    251 entry markers, and the rebus rungs printed `ALL.wantrc: declarations with no matching entry` naming
    four entries that DO exist.
    ⛔⭐ THE DEFECT IS THE SILENT FALLBACK, NOT THE MISSING FLAG: both messages ACCUSE THE DATA, so the reader is
    sent to edit a corpus that is fine. The cfo was one step from filing two rung suites as unrunnable and telling
    Lon so; what stopped it was hand-counting the markers and finding that 251 and 251 did not fit the story.
    A tool that changes its POPULATION SEMANTICS on an omitted argument owes its user a refusal, not a verdict.
    ⭐ This is the same fault class, and deliberately the same wording, as the suffix refusal cmd_list has
    carried since 2026-09-02; `run` and `pin-ref` were simply never given it. pin-ref is the worse of the two,
    because a pin REWRITES the whole pair from whatever the reader thought it read.
    ⭐ THE LINE-PER-ENTRY READER STAYS REACHABLE -- but only when ASKED FOR, spelled `--lang snobol4` (an
    accepted synonym of the default since LANG_CHOICES), never by omission. Explicit is a choice; blank is an
    accident, and only one of the two should be able to re-grade a suite into a population nobody wrote."""
    if getattr(args, "lang", ""):
        return
    if getattr(args, "lang_explicit", False):
        return                          # `--lang snobol4`: the SNOBOL4 grammar was ASKED FOR, not defaulted into
    suffix = Path(src_path).suffix
    if not suffix or suffix == ".sno":
        return
    owner = [k for k, c in LANG_CONFIGS.items() if c["ext"] == suffix]
    hint = f" -- pass --lang {owner[0]}" if owner else " -- no LANG_CONFIGS dialect claims that suffix"
    refuse(f"{subcmd}: {src_path} has suffix {suffix!r}, but with no --lang this reads the SNOBOL4 suite grammar "
           f"(`*` banners), which parses every line as its own one-line entry{hint}. Refusing rather than grading "
           f"a population that is not this suite's and then blaming the .ref file for being short -- the fault "
           f"would be the READER, not the data. To read this pair with the SNOBOL4 grammar deliberately, pass "
           f"--lang snobol4.")


SHARED_CORPUS_REMOTE = "snobol4ever/corpus"


def _corpus_is_the_shared_population(corpus_root):
    """⛔⭐ WHOSE corpus IS IT? (coo 2026-09-18, row instruments-the-progress-fingerprint-gate-appends-no-rows-arms-1-
    and-2-red-and-arm-4-vacuous). CEO-547 part 1 says a gate's own mktemp fixture is not a board because it grades no
    corpus population -- but the test written for it asked a PATH question, "is the suite under the corpus root", and
    the corpus root is whatever S4E_HOME/corpus resolves to. A hermetic fixture that builds its own two-repo world and
    points S4E_HOME at it therefore lands INSIDE its own corpus tree and is judged a board, which is how
    test_gate_progress_rows_carry_the_start_fingerprint.sh came to be DARK on origin for a day: its eight-entry scratch
    rungs was refused rc=2, the harness appended nothing, and arms 1 and 2 read FAIL for a reason that was never about
    fingerprints. ⭐ THE FACT ASKED HERE IS THE ONE CEO-547 ACTUALLY NAMES -- is this the population every seat has? --
    and it is asked of the remote: a real checkout carries origin snobol4ever/corpus, a `git init` scratch world carries
    no remote at all. ⛔ UNREADABLE ANSWERS TRUE: a guard that cannot tell must refuse, never wave through."""
    try:
        r = subprocess.run(["git", "-C", str(corpus_root), "remote", "-v"],
                           capture_output=True, text=True, timeout=10)
    except Exception:
        return True
    if r.returncode != 0:
        return True
    return SHARED_CORPUS_REMOTE in r.stdout


def _writes_the_live_progress_table():
    """Does this run append to the shared record, or to a scratch table of its own? The second half of CEO-547's
    definition ("publishes no row, writes no score"), asked of the file that would actually be written. Unreadable
    answers TRUE, for the same reason as above."""
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import util_progress_append as _upa
        return os.path.realpath(_upa.db_path()) == os.path.realpath(_upa.DB_DEFAULT)
    except Exception:
        return True


def _in_a_shared_checkout(sp):
    """⛔⭐ OUTSIDE THE CONFIGURED ROOT IS NOT OUTSIDE THE SHARED CORPUS (coo 2026-09-23; lib_one_runner.sh's
    one_runner_in_a_shared_checkout, the same rule). paths["corpus"] is S4E_HOME/corpus, so pointing S4E_HOME at a scratch
    directory made every real corpus suite read "outside the corpus tree, not a board" and admitted a seat no lane names.
    The suite's OWN checkout answers instead: inside a checkout of the shared corpus it is a board, whatever S4E_HOME says.
    A directory outside every checkout (a gate's mktemp fixture) is not; git that cannot run at all answers TRUE."""
    d = sp if sp.is_dir() else sp.parent
    try:
        r = subprocess.run(["git", "-C", str(d), "remote", "-v"], capture_output=True, text=True, timeout=10)
    except Exception:
        return True
    return r.returncode == 0 and SHARED_CORPUS_REMOTE in r.stdout


def _suite_is_a_board(suite_path, corpus_root):
    """⛔⭐ WHAT MAKES A RUN A BOARD IS THE POPULATION IT GRADES, NOT THE ENTRY POINT (ceo CEO-547 part 1, on the cfo's
    measurement). A suite living under the corpus tree is a board: it grades a shared population, publishes rows and writes a
    score. A gate's own two-entry mktemp fixture publishes no row, writes no score, grades no corpus population and costs about
    a second -- it is not a board by the definition CEO-523 itself uses. The guard used to fire before it knew which of the two
    it was holding, so make test -- THE blocking set -- was red on a clean origin tree for twelve of thirteen seats. An
    unreadable or unresolvable path answers TRUE: a guard that cannot tell must refuse, never wave through.
    ⛔ AMENDED 2026-09-18 (coo): PATH CONTAINMENT ALONE CANNOT SEE A FIXTURE THAT BUILT ITS OWN corpus/ AND POINTED
    S4E_HOME AT IT -- see _corpus_is_the_shared_population. A suite under a directory named corpus is still judged a board
    unless BOTH remaining facts say fixture: the tree is not a checkout of the shared corpus AND this run writes to a
    scratch progress table rather than the live one. ⭐ BOTH, never either: a real board that merely redirected its
    progress writes is still a board, and a checkout that merely lost its remote is still the shared population. To reach
    the fixture branch dishonestly a caller must both break its corpus remote and write its rows where nobody reads them,
    which is not an escape from the rule -- it is the rule's own description of a run that publishes nothing."""
    try:
        sp = Path(suite_path).resolve()
        cr = Path(corpus_root).resolve()
    except Exception:
        return True
    try:
        sp.relative_to(cr)
    except ValueError:
        return _in_a_shared_checkout(sp)
    if not _corpus_is_the_shared_population(cr) and not _writes_the_live_progress_table():
        print("ONE-RUNNER: FIXTURE, not a board -- %s is under %s, which is not a checkout of %s, and this run appends "
              "to a scratch progress table. No row reaches the shared record (CEO-547 part 1)." % (sp, cr, SHARED_CORPUS_REMOTE),
              flush=True)
        return False
    return True


def _one_runner_lang(suite_path=None, lang=None):
    """The LANGUAGE a board grades, from its corpus path (tests|packages|benchmarks|demos/<lang>/) else --lang."""
    if suite_path:
        parts = os.path.abspath(str(suite_path)).split(os.sep)
        for i, part in enumerate(parts[:-1]):
            if part == "corpus" and i + 2 < len(parts) and parts[i + 1] in ("tests", "packages", "benchmarks", "demos"):
                return parts[i + 2]
    return lang or "unknown"

def _one_runner_who(lang=None):
    """WHO may run a board comes from the LAW, never from a name baked in here (ceo CEO-756, CEO-775).
    NO CENTRAL RUNNER (Lon 2026-09-16 10:5x, verbatim: "So do not have a centralized runner at all. Let's each HQ run its
    language test and benchmark suites."): the seat is the one MODE's LANES: line names for the board's language; a
    MODE with no LANES line falls back to the pre-DECTET single runner (ceo under CEO, coo otherwise). Mirrors
    lib_one_runner.sh:one_runner_who word for word in its rule."""
    post = os.environ.get("S4E_POST", "/home/resources/postoffice")
    mode, lanes = "", ""
    try:
        with open(os.path.join(post, "MODE"), encoding="utf-8") as fh:
            for i, line in enumerate(fh):
                if i == 0:
                    mode = line.strip()
                if line.startswith("LANES:"):
                    lanes = line[len("LANES:"):].strip(); break
    except Exception:
        pass
    if not lanes:
        return ["ceo" if mode == "CEO" else "coo"]
    table = dict(kv.split("=", 1) for kv in lanes.split() if "=" in kv)
    # ⛔⭐ THE ENGINE IS A RUNNER SETTING (CEO-1822), word for word lib_one_runner.sh:one_runner_who: under a port engine the lane is
    # <lang>@<engine> and the bare key does not admit it; "all" is the bare keys only, so a port HQ is never a runner of every board.
    # A lane may name several seats, comma-separated (CEO-1893: the language's HQs beside the coo); each is admitted.
    if lang == "all":
        return sorted(set(s for k, v in table.items() if "@" not in k for s in v.split(",") if s))
    key = lang if _engine() == "scrip" else f"{lang}@{_engine()}"
    return [s for s in table[key].split(",") if s] if key in table else []

def _one_runner_guard(suite_path=None, corpus_root=None, lang=None):
    """ONE RUNNER PER LANGUAGE (Lon 2026-09-10 CEO-523 partitioned by Lon 2026-09-16 CEO-775): a run of a suite UNDER THE CORPUS
    TREE is a board; refused rc=2 to any seat but the one the LANES line names for that language, unless the bus computed done
    (S4E_DONE_WHEN_RUN=1) or a loud S4E_ONE_RUNNER_OVERRIDE is set. A suite outside the corpus tree -- a gate's own mktemp
    fixture -- is not a board and is never refused (CEO-547 part 1). Called with no path it judges the run a board, so a new
    caller that forgets to say what it is graded is refused, not waved through. Mirrors ../harness/scripts/lib_one_runner.sh exactly."""
    if suite_path is not None and corpus_root is not None and not _suite_is_a_board(suite_path, corpus_root):
        return
    seat = os.environ.get("S4E_SEAT") or ""
    if not seat:
        try:
            import util_score_row
            seat = util_score_row.derive_measurer() or ""
        except Exception:
            seat = ""
    blang = _one_runner_lang(suite_path, lang)
    who = _one_runner_who(blang)
    if seat and seat in who:
        return
    # THE ceo AND THE coo ARE NEVER REFUSED (Lon 2026-10-25, CEO-1976; lib_one_runner.sh:one_runner_seat_admitted carries the words): the
    # ceo on every board, the coo on every SCRIP board, whatever LANES: names.
    if seat == "ceo" or (seat == "coo" and _engine() == "scrip"):
        return
    # ⛔⭐ ONE SEAT, ONE LANGUAGE (Lon 2026-09-24, verbatim: "Just have each seat run only their own test suites." / "We can not have
    # all 5 HQ's deciding to run all seven test suites simultaneously. Fix that."): an hq_* seat the LANES: line names gets neither
    # exemption below and falls through to the refusal. Mirrors lib_one_runner.sh:one_runner_seat_is_language_hq.
    # ⛔⭐ THE FIXTURE EXEMPTION HOLDS ONLY FOR A POPULATION OUTSIDE THE SHARED CORPUS (ceo CEO-1302 (c), 2026-09-27; lib_one_runner.sh
    # carries the why): a suite reaching this line is a board -- a scratch one returned at the top -- so the exemption, which admitted
    # exactly this case, now names it and falls through to the checks below, which end in the refusal.
    if os.environ.get("S4E_ONE_RUNNER_FIXTURE"):
        sys.stderr.write("\u26d4 ONE-RUNNER FIXTURE NOT ADMITTED: %s is the shared corpus or a population a board reads -- the exemption "
                         "admits a scratch population only (ceo CEO-1302 (c)); point the fixture at one with a scratch "
                         "S4E_PROGRESS_DB\n" % (suite_path or "a run naming no suite"))
    if seat.startswith("hq_"):
        sys.stderr.write("\u26d4 ONE SEAT, ONE LANGUAGE: %s is a language HQ -- no S4E_ONE_RUNNER_OVERRIDE and no DONE-WHEN admits it to "
                         "a %s board (Lon 2026-09-24: \"Just have each seat run only their own test suites.\")\n" % (seat, blang))
    else:
        if os.environ.get("S4E_DONE_WHEN_RUN") == "1":
            # DONE RUNS NO BOARD FOR ANY SEAT (ceo CEO-1342 clause 5, the coo 2026-09-28): the exemption is retired; mirrors lib_one_runner.sh
            sys.stderr.write("⛔ REFUSE(2) DONE RUNS NO BOARD FOR ANY SEAT (ceo CEO-1342 clause 5): a %s board under the bus computed done for seat %s "
                             "is refused -- a DONE-WHEN that needs a suite's verdict reads the coo's SUITE TABLE row at a tree at or after the "
                             "landing: ../harness/scripts/util_suite_row_at_or_after.sh <suite-key> <tree>\n" % (blang, seat or "?"))
            sys.exit(2)
        if os.environ.get("S4E_ONE_RUNNER_OVERRIDE"):
            print("\u26a0 ONE-RUNNER OVERRIDE by %s: %s" % (seat or "?", os.environ["S4E_ONE_RUNNER_OVERRIDE"])); return
    sys.stderr.write("\u26d4 REFUSE(2) ONE RUNNER, ONE BOARD -- ONE RUNNER PER LANGUAGE: a %s rungs/package run is a board and seat %s is not %s, the seat MODE LANES: names for %s. Every language HQ runs its OWN language suites, once per landing, on origin HEAD, and writes its own rows (Lon 2026-09-16 10:5x, RULES.md § ONE RUNNER PER LANGUAGE, CEO-775); another language board is an ASK to that language HQ.\n" % (blang, seat or "?", " or ".join(who) if who else "<no seat -- the LANES line names none>", blang))
    sys.exit(2)

def cmd_run(args):
    paths = resolve_paths()
    _dseat = os.environ.get("S4E_SEAT") or ""
    if not _dseat:
        try:
            import util_score_row
            _dseat = util_score_row.derive_measurer() or ""
        except Exception:
            _dseat = ""
    if _dseat == "cto" and not os.environ.get("S4E_DONE_WHEN_RUN"):
        sys.stderr.write("\u26d4 REFUSE(2) A DESIGN OFFICER RUNS NO TESTS: seat %s designs only (Lon 2026-10-30, CEO-2029, verbatim: \"Ensure that both CTO and CAO will only ever do design and never waste time with implementation or testing.\"). Put the witness and its expected answer in the step plan and let an executor or the coo run it.\n" % _dseat)
        sys.exit(2)
    # ⭐ A HANDFUL OF NAMED ENTRIES IS NOT A BOARD (Lon 2026-10-22: "An HQ knows it is done when the program it fixes fails before and passes
    # after a fix. And it can run a handful of related programs based on attributes to check for breakage."; ceo CEO-1893): a run whose
    # --partition names only entry:<name> parts, at most eight, is any seat's own test of its program and is admitted for every seat.
    _parts = [p.strip() for p in (getattr(args, "partition", None) or "").split(",") if p.strip()]
    # ⭐ A SMOKE'S CORE ARM IS NOT A BOARD (ceo CEO-1952; Lon 2026-10-24: "Let's get better smoke tests for SNOBOL4, it keeps missing a lot."):
    # test_smoke_snobol4.sh and test_smoke_snocone.sh grade their language's PARTITION core plus named entries under S4E_SMOKE_CORE_ARM with
    # progress off. A smoke is open to every seat (CEO-1893) and a fix smokes every language its diff touches before the push (CEO-1928), so
    # the arm is admitted for every seat; it writes no progress row and no score row, and it names nothing but core and entry: parts.
    _smoke = bool(os.environ.get("S4E_SMOKE_CORE_ARM")) and os.environ.get("S4E_PROGRESS_OFF") == "1" and _parts.count("core") == 1 and all(p == "core" or p.startswith("entry:") for p in _parts)
    if _smoke:
        print("ONE-RUNNER SMOKE CORE ARM by %s: %s, no progress row and no score row" % (os.environ.get("S4E_SEAT") or "?", os.environ["S4E_SMOKE_CORE_ARM"]))
    elif not (_parts and len(_parts) <= 8 and all(p.startswith("entry:") for p in _parts)):
        _one_runner_guard(args.sno, paths["corpus"], getattr(args, "lang", None))
    # ⛔⭐ ONE MEMORY SCOPE AT THE OUTERMOST RUN (row instrument-698-runners-..., the coo 2026-09-23; util_mem_scope.py): an
    # ADMITTED run over a corpus population -- the guard's own test, just above -- re-runs itself once inside ONE cgroup scope at
    # the board cap unless it is already inside one; a gate's mktemp fixture is not a board and is left alone (CEO-547). After the
    # guard, not before, so a refused seat spends no scope and the guard stays the first thing cmd_run does.
    if _mem_scope_wanted(args, paths):
        _mem_scope().enter("board", sys.orig_argv)
    if not os.environ.get("S4E_MEM_OOM_AT_START", "").strip():
        os.environ["S4E_MEM_OOM_AT_START"] = str(_mem_scope().oom_kills() or 0)
    _progress_pin(paths)
    _pl = _one_runner_lang(args.sno, None)   # the board's language: --lang, else its corpus path, else this harness's default, snobol4
    paths["lang"] = getattr(args, "lang", None) or (_pl if _pl != "unknown" else "snobol4")
    check_scrip(paths)
    # ⛔⭐ THE STATEMENT INSTRUMENTATION IS EACH UNIT'S OWN DECLARATION (clause 8 (f), CEO-1281): every snobol4, snocone and rebus rungs
    # row declares --stlimit in its compile_args (corpus d57d1ae81), which read_command_line_columns attaches and _compile_switches
    # applies. This harness typed it here for those three languages from 2026-09-25 (hq_snocone: SncRungs graded 335/338 without it,
    # SPITBOL always counts) until 2026-09-26, when the rows took it over; a row without the cell compiles without the switch.
    # ⛔ THE BINARY IS STAMPED AT THE START AND CHECKED BEFORE ANY BOARD LINE IS PRINTED (coo 2026-09-16; hq_raku's RakRungs 764/927 graded
    # across a mid-run make). An outer runner's S4E_BIN_AT_START is kept; otherwise this run stamps its own.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import util_progress_append as _upa_bin
    if not os.environ.get("S4E_BIN_AT_START", "").strip():
        os.environ["S4E_BIN_AT_START"] = _upa_bin.bin_fingerprint().strip()
    # the baseline is STATED, like the tree stamp: a reader (and the gate's mid-run arm) can see what this run will be held to
    _bin_names = ", ".join(os.path.basename(f) for f in engine_binaries(paths["engine"])) if paths["engine"] != "scrip" else "scrip, libscrip_rt.so"
    print(f"BINARY_AT_START {os.environ['S4E_BIN_AT_START']} (md5/12 of {_bin_names}; engine {paths['engine']}; a rebuild under this run refuses the board)", flush=True)
    # ⛔⭐ A BOARD NAMES THE ARENA IT RAN UNDER (Lon 2026-09-19, ceo CEO-931/934/938; RULES.md batch 28 CLAUSE 2).  The
    # tiny arena is the default of all GC testing, so the SAME suite legitimately reads two different populations on one
    # binary -- SnoRungs 1963/1974 at the shipped 512 MB window and 1959/1974 at 1 MB -- and a reader who cannot see which
    # one a board is has no measurement.  Reported, never defaulted here: the knob comes from the environment (the
    # Makefile exports 1 for everything run through make), because a harness that silently changed every existing
    # board's arena would change what every published number MEANS with no line of evidence anywhere.
    _arena_kb = os.environ.get("SCRIP_HEAP_KB", "").strip()
    _arena_mb = os.environ.get("SCRIP_HEAP_MB", "").strip()
    if not _arena_kb: _arena_kb = str(int(_arena_mb) * 1024) if _arena_mb.isdigit() else str(GC_HEAP_KB_DEFAULT)
    if not _arena_mb: _arena_mb = "0"
    _arena_cap = os.environ.get("SCRIP_HEAP_MAX_MB", "").strip()
    print("ARENA SCRIP_HEAP_KB=%s%s%s" % (_arena_kb, (" SCRIP_HEAP_MAX_MB=" + _arena_cap) if _arena_cap else "",
          " (THE INITIAL WINDOW in KB, SPITBOL's -i; unset means the shipped %d KB, SPITBOL's -i1m (ceo CEO-1261). THE HARD CAP is each"
          " program's declared heap_kb, passed as -d<kb>k on its own command line, else the shipped %d KB, SPITBOL's -d128m; SCRIP_HEAP_CAP_KB"
          " or SCRIP_HEAP_MAX_MB in the environment names it for an undeclared program. Since ceo CEO-1101 the heap does not extend past its cap"
          " -- memory inside it is committed page-granular as the heap grows and nothing above it is mapped -- and since CEO-1264 a window is"
          " spent before it is collected and a collection that leaves it under 15 percent free grows it, as SPITBOL does. A SMALL CAP CAN"
          " REFUSE A LIVE SET, and that refusal is a row, never a reason to raise the default; the run's own report carries capped= grew="
          " cap_kb=, and grew>0 disqualifies a point as arena evidence)" % (GC_HEAP_KB_DEFAULT, GC_HEAP_CAP_KB)), flush=True)
    def _bin_unmoved_or_refuse():
        _mv = _upa_bin.binary_moved_since_start()
        if _mv:
            sys.stderr.write("⛔ REFUSE(rc=2) [corpus_suite_harness]: THE BINARY MOVED UNDER THIS BOARD -- start [%s] end [%s]. ./scrip or "
                             "out/libscrip_rt.so was rebuilt while this run graded: no board is printed and no progress row is recorded, "
                             "because the verdicts describe no single binary. Re-run on a quiet tree.\n" % _mv)
            sys.exit(2)
    # ⛔⭐ A SUITE FILE THAT IS NOT THERE IS A REFUSAL, NEVER A CRASH (row harness-refusal-exit-code-unified-on-
    # rc-2, hq_T 2026-09-04, found by that row's OWN gate while it was being written). Until now a missing
    # ALL.<ext> or ALL.ref reached Path.read_text() and died with a FileNotFoundError TRACEBACK, which Python
    # exits **1** for -- and rc=1 in this harness means "ran fine, some entries are RED". So the one case where
    # nothing whatsoever was graded returned the code for a measured red board, to a caller that cannot tell
    # them apart. That is the exact shape this row was minted to remove, one layer below where it was looking.
    # ⛔ CHECKED HERE, BEFORE ANY READER: read_suite/read_block_suite each open BOTH files at different depths,
    # so a guard inside either one would have to be written twice and would still miss the sidecars' own reads.
    # ⛔⭐ A BOARD NAMES THE RUNTIME IT ACTUALLY LOADED, NOT THE ONE ITS TREE IMPLIES (coo, ceo CEO-1097).
    # out/libscrip_rt.so is a SINGLE MUTABLE SYMLINK whose target name is keyed on the TREE PATH, not on the build
    # configuration, and scrip's RUNPATH is that absolute out directory.  So two builds of one tree at different
    # RT_OPT overwrite each other silently, and a board that spans a rebuild grades two different runtimes under one
    # row.  The coo found this by building an -O2 arm beside an -O0 arm at the same tree and watching the -O0 arm
    # resolve to the -O2 runtime.  Printing the md5 makes the substitution VISIBLE in the board line instead of
    # invisible: two rows that disagree can be told apart, and two rows that agree can be PROVEN to.
    _rt_md5 = "unknown"
    try:
        import hashlib
        _rt_so = os.path.join(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP"), "out", "libscrip_rt.so")
        if paths["engine"] != "scrip":
            _rt_so = (engine_binaries(paths["engine"]) + ["", ""])[1]
        with open(os.path.realpath(_rt_so), "rb") as _f: _rt_md5 = hashlib.md5(_f.read()).hexdigest()[:12]
    except Exception: _rt_md5 = "unreadable"
    print(("RUNTIME " + os.path.basename(_rt_so) if paths["engine"] != "scrip" else "RUNTIME libscrip_rt.so") + " md5=%s -- the runtime this pass ACTUALLY loaded; out/libscrip_rt.so is one mutable symlink per TREE, not per CONFIGURATION (CEO-1097)" % _rt_md5)
    for _label, _p in (("suite", args.sno), ("ref", args.ref)):
        if not Path(_p).is_file():
            refuse(f"{_label} file does not exist: {_p} -- nothing was graded, and a run that graded nothing is "
                   f"UNMEASURED, never a red board (check the path, or build the rungs first)")
    if args.lang:
        cfg = LANG_CONFIGS[args.lang]
        ext = cfg["ext"]
        modes = parse_modes(args.modes or cfg["modes"], "run")
        banner_re = banner_re_for(cfg["comment_open"], cfg["comment_close"])
        entries = read_block_suite(args.sno, args.ref, banner_re, in_path=sidecar_in_path(args.sno),
                                   x_path=sidecar_xfail_path(args.sno), w_path=sidecar_wantrc_path(args.sno),
                                   a_path=sidecar_argv_path(args.sno), modes=modes)
    else:
        require_lang_for_suite("run", args.sno, args)
        ext = ".sno"
        modes = parse_modes(args.modes or "m3,m4", "run")
        entries = read_suite(args.sno, args.ref, in_path=sidecar_in_path(args.sno),
                             x_path=sidecar_xfail_path(args.sno), w_path=sidecar_wantrc_path(args.sno),
                             a_path=sidecar_argv_path(args.sno), modes=modes)
    FATAL_RENDER["voice"] = _fatal_render_voice_for(args.lang)
    FATAL_RENDER["merged_voice"] = _merged_render_voice_for(args.lang)
    _masks = read_mask_sidecar(args.ref)
    if _masks:
        _seen = set()
        for _e in entries:
            _p = masks_for(_masks, _e.name)
            if _p:
                _e.mask = _p
                _seen.add(_e.name)
        # ⛔ `*` is a name this suite always "contains" once it has any entry at all, so it must not be reported as
        # an entry the suite does not have -- otherwise a suite-wide sidecar refuses on its own wildcard.
        _unknown = sorted(set(_masks) - _seen - {"*"})
        if _unknown:
            refuse("the .mask sidecar names entries this suite does not contain: %s -- a mask that matches nothing "
                   "is a mask nobody notices has stopped applying, and CEO-409 is auditable or it is not a mask"
                   % ", ".join(_unknown))
        print("CEO-409 MASKS ACTIVE: %d of %d entries carry a declared implementation-defined line mask (%s)"
              % (len(_seen), len(entries), ", ".join(sorted(_seen))))
    require_population(paths, len(entries), 1, f"entries read from {args.sno} (a suite pair that names zero entries cannot be graded)")
    # ⛔ THE SUITE'S NAMES ARE TAKEN BEFORE THE SHARD CUTS THEM: the outside list's presence check below asks whether a name is in
    # THIS SUITE, never in this shard -- read from the sharded list, every outside name graded by another shard read as a stale row
    # and 6 of 6 SnoRungs shards refused rc=2 (hq_snobol4 2026-09-24; row instruments-the-harness-shard-filter-cuts-the-entry-list-
    # before-the-outside-list-presence-check-so-every-sharded-run-of-a-suite-with-an-outside-list-refuses).
    _suite_names = {e.name for e in entries}
    _all_entries = list(entries)
    shard_tag = ""
    if getattr(args, "shard", ""):
        _m = re.fullmatch(r"(\d+)/(\d+)", args.shard.strip())
        if not _m or int(_m.group(2)) < 1 or not (1 <= int(_m.group(1)) <= int(_m.group(2))):
            refuse(f"--shard wants k/N with 1 <= k <= N, got {args.shard!r}")
        _k, _n = int(_m.group(1)), int(_m.group(2))
        _all = len(entries)
        entries = [e for i, e in enumerate(entries) if i % _n == _k - 1]
        if not entries:
            refuse(f"--shard {args.shard} selects zero of the {_all} entries -- N exceeds the suite; a shard that grades nothing is not a board")
        shard_tag = f"shard={_k}/{_n}"
    if getattr(args, "partition", ""):
        if shard_tag:
            refuse("--partition and --shard together: a partition is already a bounded subset; grade one or the other")
        # ⭐ <part>@<entry> RESUMES a part at that entry (CEO-1806): the round robin yields to a waiting request between two tests and picks the
        # chunk up again where it stopped, by name, so a request waits at most one test.
        _ppart, _, _pfrom = args.partition.partition("@")
        _pname, _psel, _pn, _ppath = select_partition(args.sno, _ppart)
        if _pfrom:
            if _pfrom not in _psel:
                refuse(f"--partition {args.partition}: {_pfrom!r} is not an entry of {_pname}")
            _psel = _psel[_psel.index(_pfrom):]
            print(f"PARTITION_RESUME {_pname} at {_pfrom}: {len(_psel)} entr(ies) left")
        _by = {e.name: e for e in entries}
        _gone = [n for n in _psel if n not in _by]
        if _gone:
            refuse(f"--partition {_pname}: {len(_gone)} of its {len(_psel)} entries are not in {args.sno} ({', '.join(_gone[:5])}) -- "
                   f"{_ppath} is stale; rebuild it with ../harness/scripts/util_suite_partition.py build")
        entries = [_by[n] for n in _psel]
        shard_tag = f"partition={_pname}"
        PARTITION_RUN["name"] = _pname
        print(f"PARTITION {_pname}: {len(entries)} of {_pn} entries ({_ppath}) -- a subset, never the suite's row")
    # ⛔⭐⭐ HONOUR THE heap_kb COLUMN -- UNCONDITIONALLY, AND THAT IS THE WHOLE DESIGN (Lon 2026-09-23,
    # verbatim: "Well, each test should have the needed amount of memory in the attribute TSV/CSV files.";
    # CEO-1167). There is deliberately NO --by-heap-column flag: `heap_kb` says what the entry NEEDS IN ORDER TO RUN AT ALL: a
    # declared need is an attribute of the test, so it IS the shipped configuration for that test, and a
    # board that could be asked to ignore it would be a board that can be asked to grade a program at an
    # arena its own suite says is too small. That is not a second opinion, it is a known-false reading.
    # ⛔ A SUITE WITH NO COLUMN, OR A COLUMN THAT IS EMPTY EVERYWHERE, CHANGES NOTHING: heap_declarations()
    # returns {} and every entry keeps heap_kb=None, so the env of every existing run is byte-identical.
    _heap_decl, _heap_src = heap_declarations(args.sno)
    if _heap_decl:
        for _e in entries:
            if _e.name in _heap_decl:
                _e.heap_kb = _heap_decl[_e.name]
        _named = sum(1 for _e in entries if _e.heap_kb)
        print(f"DECLARED ARENA: {_named} of {len(entries)} entr(y/ies) carry a heap_kb declaration from "
              f"{_heap_src} and run at it; the rest run at the shipped default. "
              + ", ".join(f"{_e.name}={_e.heap_kb}KB" for _e in entries if _e.heap_kb), file=sys.stderr)
    # ⭐ AND THE stack_kb COLUMN, the same way and for the same reason (CEO-1225): what the entry needs in order to run at all.
    _stack_decl, _stack_src = stack_declarations(args.sno)
    if _stack_decl:
        for _e in entries:
            if _e.name in _stack_decl:
                _e.stack_kb = _stack_decl[_e.name]
        _nst = sum(1 for _e in entries if _e.stack_kb)
        print(f"DECLARED STACK: {_nst} of {len(entries)} entr(y/ies) carry a stack_kb declaration from "
              f"{_stack_src} and run at it; the rest run at the runtime's {GC_STACK_FLOOR_KB} KB floor. "
              + ", ".join(f"{_e.name}={_e.stack_kb}KB" for _e in entries if _e.stack_kb), file=sys.stderr)
    # ⛔ A MISSING DECLARATION IS NAMED ON THIS RUN'S OWN OUTPUT (Lon 2026-09-28, ceo CEO-1353 gap 5: "a missing declaration runs silently
    # at the default"): the counts above went to stderr and said nothing at all when the column or the table was absent. Every entry that
    # declares no heap_kb or no stack_kb is NAMED on stdout, with where the declaration was looked for, so a board's transcript shows it.
    _no_heap = [_e.name for _e in entries if not _e.heap_kb]
    _no_stack = [_e.name for _e in entries if not _e.stack_kb]
    if _no_heap or _no_stack:
        _where = str(Path(args.sno).parent / "ALL.csv") + (" (present)" if (Path(args.sno).parent / "ALL.csv").is_file() else " (ABSENT)")
        _nm = lambda xs: " ".join(xs[:20]) + (" ... and %d more" % (len(xs) - 20) if len(xs) > 20 else "")
        print("UNDECLARED heap_kb on %d of %d entr(y/ies), stack_kb on %d -- run at the shipped default, named (CEO-1353; the declaration "
              "is looked for in %s and a travelling <stem>.heap / <stem>.stack): heap: %s%s" % (len(_no_heap), len(entries), len(_no_stack), _where,
              _nm(_no_heap) or "none", ("; stack: " + _nm(_no_stack)) if _no_stack else ""))
    # ⭐ AND THE COMMAND LINE (clause 8 (f), CEO-1281): compile_args and run_args were attached by the suite reader itself
    # (read_command_line_columns), so every caller of it sees them; the count is printed here so a transcript records them.
    _nca = [_e for _e in entries if _e.compile_args]
    if _nca:
        _by = {}
        for _e in _nca:
            _by.setdefault(" ".join(_e.compile_args), []).append(_e.name)
        print(f"DECLARED COMPILE SWITCHES: {len(_nca)} of {len(entries)} entr(y/ies) carry compile_args from ALL.csv, applied "
              f"at the compile step in both modes: "
              + "; ".join(f"{k} x{len(v)}" for k, v in sorted(_by.items())), file=sys.stderr)
    # ⛔⭐ THERE IS NO MODES COLUMN AND NO PER-ENTRY MODE (Lon 2026-09-23, in-chat to hq_prolog, verbatim: "Get rid of those m3 and
    # and m4 specific columns. We do not do that here." and "mode 3 and 4 are the same with only different MEDIA, binary versus
    # text"). Every entry is graded in every mode the caller asked for; nothing in a suite can narrow that.
    run_entries = entries
    # ⛔⭐ OUTSIDE THE BASELINE (ceo ruling 2026-09-08 on the cfo's find; the rungs half of the rule
    # OUTSIDE_SPITBOL_BASELINE.tsv already carries for a package). A RUNGS entry the language's ORACLE
    # CANNOT RUN is outside the rungs' baseline exactly as a package program is: it leaves the graded
    # denominator, it is NEVER masked per line, and the reason is recorded beside the suite with the
    # oracle's own words. The board then reads N/N honestly instead of carrying a permanent red nobody can
    # ever cure, and the denominator move is a CRITERION CHANGE, never a regression.
    # ⛔ WHY THIS IS NEEDED AT ALL, WHICH IS THE ACTUAL FINDING: rungs refs were cut from OUR OWN OUTPUT
    # rather than from the oracle, so a program the oracle cannot even compile came to sit in the graded
    # set asserting another implementation's answers as Icon's. A ref that pins us is not an oracle.
    # ⛔ THE LIST IS A RECORD, NOT A MASK: every name here is printed with its reason on every run. It is
    # NOT re-probed against the oracle by this harness -- the rungs grades SCRIP against a stored ref and
    # never invokes the oracle -- so a stale entry (one the oracle has since learned to run) is caught by a
    # re-probe elsewhere, not here, and the record carries the date its refusal was checked.
    outside = {}
    _outside_path = getattr(args, "outside", "") or ""
    _outside_none = bool(getattr(args, "outside_none", False))
    if _outside_none and _outside_path:
        refuse("--outside and --outside-none together: one names a baseline and the other refuses every baseline -- a run cannot be graded both ways")
    # ⛔⭐ THE SIBLING LIST RIDES WITHOUT THE FLAG (coo 2026-09-17, MEASURED: two boards, same corpus a6bcd8097,
    # 76 minutes apart, disagreed on the SAME SEVEN snobol4-rungs entries -- cfo 22:55:52Z read PASS, cto
    # 00:11:39Z read OUTSIDE -- and the accounting closed exactly: cfo PASS 3940 vs cto 3926 (+14 = 7 entries
    # x 2 modes), cfo FAIL 23 vs cto 21 (+2), 16 = the cto's whole OUTSIDE count. The difference was not the
    # tree and not the oracle: it was the FLAG. `test_corpus_snobol4.sh` and `board_icon_rungs.sh` pass
    # --outside; a direct `corpus_suite_harness.py run` -- the invocation this repo's own digest documents --
    # did not, so the eight entries the ONE ORACLE REFUSES TO RUN were graded against their stored .ref and
    # seven of them "passed" by agreeing with our own past output. A ref is evidence about a past oracle run,
    # never about the oracle (RULES.md), so those were fourteen PASS rows with no ground truth behind them,
    # appended to the progress DB, where they read as a +7 flip and then a -7 loss in util_progress_flips.
    # THE INSTRUMENT LAW THIS BREAKS: a declared fact sitting beside the data must not depend on a caller
    # remembering a flag -- `test_corpus_snobol4.sh` already says in its own comment that "a declared outside
    # list that no runner passes is INERT", and this closes the other half of that hole. The list is DERIVED
    # from the suite's own directory whenever the suite is a rung suite (`ALL.<ext>`) with `ALL.outside.tsv`
    # beside it, and the provenance is PRINTED either way, so no board can be read without knowing which
    # baseline it was graded against. --outside-none is the loud, printed escape for a run that deliberately
    # wants the shipped set; it is never the default and never silent.
    _outside_derived = ""
    if not _outside_path and not _outside_none:
        _sib = Path(args.sno).with_name("ALL.outside.tsv")
        if Path(args.sno).name.startswith("ALL.") and _sib.is_file():
            _outside_path = str(_sib)
            _outside_derived = _outside_path
    if _outside_none:
        _sib = Path(args.sno).with_name("ALL.outside.tsv")
        if Path(args.sno).name.startswith("ALL.") and _sib.is_file():
            print(f"OUTSIDE_BASELINE_LIST NONE --outside-none was given and {_sib} EXISTS: this run grades the SHIPPED set, "
                  f"declared-outside entries included, and its pass count is NOT comparable to a board graded against the baseline")
        else:
            print("OUTSIDE_BASELINE_LIST NONE --outside-none was given (no sibling ALL.outside.tsv beside this suite anyway)")
    if _outside_path:
        _flag = "--outside" if not _outside_derived else "the sibling outside list"
        _op = Path(_outside_path)
        if not _op.is_file():
            refuse(f"{_flag} {_outside_path}: no such file -- a declared outside list that is not there would silently grade the whole set")
        for _ln in _op.read_text(encoding="utf-8").splitlines():
            if not _ln.strip() or _ln.lstrip().startswith("#"):
                continue
            _f = _ln.split("\t")
            if len(_f) < 3:
                refuse(f"{_flag} {_outside_path}: line is not name<TAB>CLASS<TAB>reason: {_ln[:80]}")
            outside[_f[0].strip()] = (_f[1].strip(), _f[2].strip())
        _named = set(outside)
        _absent = sorted(_named - _suite_names)
        if _absent:
            refuse(f"{_flag} {_outside_path}: declares entries that are not in this suite: {_absent} -- a stale outside list silently shrinks nothing and hides that it is stale")
        print(f"OUTSIDE_BASELINE_LIST {_outside_path} ({'DERIVED from the suite directory -- --outside was not given' if _outside_derived else 'passed with --outside'}), "
              f"{len(outside)} entr(ies) declared")
        # ⛔⭐ THE OUTSIDE ENTRIES LEAVE THE GRADED DENOMINATOR AND STAY IN THE SHIPPED ONE (CEO-749; Lon 2026-09-16 "Get those
        # fixed" -- OUTSIDE is debt; coo 2026-09-16, row snobol4-master-runner-publishes-over-the-graded-population-1972-not-
        # the-shipped-1980-with-outside-named). Counted HERE, per shard, as the entries this run actually removed -- never
        # len(outside) -- so board_combine's field sum across shards reads the true count once, and the SUITE_BOARD prints
        # total= (graded) shipped= (graded + outside) outside= (removed) side by side. Each removed entry is also recorded in
        # the progress DB as OUTSIDE with the oracle's own class and reason, so the CEO-749 identity is checkable from the DB.
        _out_run = [e.name for e in run_entries if e.name in outside]
        run_entries = [e for e in run_entries if e.name not in outside]
        for _n in sorted(_out_run):
            print(f"OUTSIDE_BASELINE {_n} {outside[_n][0]}: {outside[_n][1]}")
        print(f"OUTSIDE_BASELINE_COUNT {len(_out_run)} entr(ies) out of the graded denominator and IN the shipped one, named above with the oracle's own reason")
    else:
        _out_run = []
        if not _outside_none:
            print("OUTSIDE_BASELINE_LIST NONE (no ALL.outside.tsv beside this suite, and --outside was not given)")
    _ext_rows = {}
    if Path(args.sno).name.startswith("ALL."):
        _ext_rows = report_extension_refs(args.sno, _all_entries, set(outside))
    # ⛔⭐ THE AND PER PROGRAM (ceo-372, 2026-09-06): a suite row's single number states the entries green in
    # EVERY mode they were graded in -- never one mode alone, and never min(m3_pass, m4_pass), which is not a count
    # of anything: two entries, one red only in m3 and one red only in m4, give min()=1 while the AND is 0, so the
    # min hides a program that is red somewhere. It is computed HERE, where one entry's verdicts are all in hand,
    # because it CANNOT be recovered from the per-mode aggregates a board line carries -- that is the whole reason
    # the callers could not do it themselves. `all_n` is its denominator: entries graded in at least one mode.
    all_pass = 0
    all_n = 0
    # ⛔⭐ THE XFAIL BUCKET IS SPLIT BY OUTCOME (ceo CEO-432 item 2, on hq_U's census: an xfail marker is a CHECK
    # THAT CANNOT FAIL -- a SIGSEGV reads xfail, a hang reads xfail, a silently wrong answer reads xfail, and a
    # mode-4 that produces no binary at all reads xfail). Four different repairs behind one identical count, and
    # hq_U measured three SNOBOL4 entries that CRASH in m3 and merely answer WRONG in m4 -- so the single number
    # hides a PER-MODE split as well as a per-debt one. XFAIL stays as the total, so every existing reader is
    # untouched; the split rides beside it and costs one dict key per kind.
    _XK = ("PASS", "FAIL", "CRASH", "HANG", "UNPROVEN", "SKIP")
    # ⭐⭐ OOM ON THE BOARD LINE (CEO-1229 (2); the verdict is _oom_verdict's). The PROGRESS ROW says OOM. The SUITE_BOARD line keeps
    # an OOM inside <m>_fail and prints how many of them were OOM beside it as <m>_fail_oom, the way the xfail split rides beside
    # xfail (CEO-432 item 2) -- because 89 files under ../harness/scripts/ name this line on 2026-09-24, the boards among them read fail (+crash)
    # as their red (test_corpus_snobol4.sh FAIL = m3_fail + m3_crash, board_icon_rungs.sh, the Pascal gates' bad sums), and none of
    # them knows the new word: folding OOM OUT of fail would turn each such board green on a program that did not answer, silently. Since dc739c38a an OOM already read as fail here (rc 1, output mismatch), so no reader's verdict moves by a unit.
    # Whether a landing gate should stop counting an OOM as red is a ruling, asked of the ceo, not taken here.
    _OOMK = "OOM"
    def _fresh():
        d = {k: 0 for k in _XK}; d["XFAIL"] = 0; d["XPASS"] = 0
        d.update({"XFAIL_" + k: 0 for k in _XK})
        d[_OOMK] = 0
        return d
    oom_named = []
    counts = {m: _fresh() for m in modes}
    # ⭐ AN EXPECTED REFUSAL (CEO-1228, CEO-1657): ISO_EXPECTED_REFUSALS.tsv beside the container names each entry the oracle's mode runs while
    # the language's standard refuses it (Pascal: fpc -Miso runs it, ISO 7185 refuses it). Such an entry PASSes in a mode when that mode
    # refuses it with the language's standard diagnostic (LANG_CONFIGS expected_refusal_re) and is red otherwise; its ref is never compared
    # and the denominator is unchanged. A listed name the suite does not carry refuses rc 2, as a stale outside row does.
    _xr_re = LANG_CONFIGS.get(getattr(args, "lang", "") or "", {}).get("expected_refusal_re")
    _xr_path = Path(args.sno).with_name("ISO_EXPECTED_REFUSALS.tsv")
    expected_refusals = set()
    if _xr_re and _xr_path.is_file():
        for _l in _xr_path.read_text(encoding="utf-8", errors="replace").splitlines():
            _c = _l.split("\t")[0].strip()
            if _c and not _c.startswith("#"):
                expected_refusals.add(_c[:-len(ext)] if _c.endswith(ext) else _c)
        _stale = sorted(expected_refusals - _suite_names)
        if _stale:
            refuse(f"{_xr_path} names {len(_stale)} entr(ies) this suite does not carry: {', '.join(_stale[:10])}")
        print(f"EXPECTED_REFUSALS n={len(expected_refusals)} from {_xr_path} -- each PASSes in a mode only when refused with /{_xr_re}/ (CEO-1228)")
    _xr_rx = re.compile(_xr_re.encode()) if expected_refusals else None
    tmp_root = Path(tempfile.mkdtemp(prefix="csh_run_"))
    fails = []
    _progress_rows = []
    for _n in _out_run:
        for _m in modes:
            _progress_rows.append((_n, _m, "OUTSIDE", 0, f"{outside[_n][0]}: {outside[_n][1][:160]}"))
    # ⛔⭐ ONE TEST AT A TIME, EACH ROW WRITTEN AS ITS TEST FINISHES (ceo CEO-1805; Lon 2026-10-15, verbatim: "Basically the COO should run one test at
    # a time and update the test-suite database. Round robin, done and done."): under S4E_RR=1 (the coo's round-robin loop) the rows graded so far are
    # appended before the next entry starts, so results.tsv holds every finished test while the chunk still runs; the rest go at the end as before.
    _rr_stream = os.environ.get("S4E_RR") == "1"
    _rr_done = [0, 0]   # rows already appended, of which recorded
    try:
        _rr_yield = Path(os.environ["S4E_RR_YIELD_DIR"]) if _rr_stream and os.environ.get("S4E_RR_YIELD_DIR") and not os.environ.get("S4E_REQ") else None
        for _ei, e in enumerate(run_entries):
            # ⭐ A WAITING REQUEST GOES FIRST (CEO-1806): before each next test of a round-robin run, a request file in the loop's queue stops the run here;
            # the tests already graded are recorded, and the loop serves the request and resumes the part at this entry (RR_YIELD names it).
            if _rr_yield is not None and _ei > 0 and rr_request_waits(_rr_yield):
                print(f"RR_YIELD next={e.name} graded={_ei} of {len(run_entries)} -- a test request waits (CEO-1806); resume with --partition {PARTITION_RUN['name'] or '?'}@{e.name}")
                break
            if _rr_stream and len(_progress_rows) > _rr_done[0]:
                _rr_done[1] += _progress_record(args.sno, paths, _progress_rows[_rr_done[0]:], quiet=True) or 0
                _rr_done[0] = len(_progress_rows)
            verdicts = run_suite_entry(paths, e, tmp_root, modes, ext=ext, companion_dir=Path(args.sno).parent)
            if e.name in expected_refusals:
                for m in modes:
                    _v = verdicts[m]
                    _refused = _v.kind != "PASS" and (_v.kind == "SKIP" or (_v.returncode or 0) != 0) and _xr_rx.search(_v.stderr or b"")
                    verdicts[m] = Verdict("PASS", _v.stdout, _v.stderr, _v.returncode, detail="expected-refusal") if _refused else \
                        Verdict("FAIL", _v.stdout, _v.stderr, _v.returncode, detail="expected-refusal-not-refused-with-the-standard-diagnostic")
                    verdicts[m].secs = _v.secs
            for m in modes:
                kind = verdicts[m].kind
                # ⭐ secs: the program's own wall in this mode (CEO-1676 row (c)) -- util_suite_partition.py build --secs sizes chunks by it
                _progress_rows.append((e.name, m, kind, getattr(verdicts[m], "secs", 0) or 0, _entry_note(e.xfail, verdicts[m], shard_tag)))
                if kind == _OOMK:
                    oom_named.append((e.name, m, verdicts[m], e.xfail))
                ck = "FAIL" if kind == _OOMK else kind   # the board line's fail keeps an OOM (see _OOMK above)
                # ⛔ An XFAIL entry (probe/passthru's law-0d witnesses: non-green at conversion time,
                # see convert_one()) is EXPECTED to stay red -- bucketing it as XFAIL/XPASS instead of
                # FAIL/PASS keeps a documented, pre-existing defect from inflating a caller's FAIL count
                # (test_corpus_snobol4.sh's probe/ auto-discovery loop reads m3_fail/m4_fail and would
                # otherwise regress a green gate the moment such a witness converts). An XPASS -- the
                # bug got fixed and nobody updated the marker -- is surfaced just as loudly as a FAIL:
                # it is exactly as actionable, only in the opposite direction.
                if e.xfail:
                    if kind == "PASS":
                        counts[m]["XPASS"] += 1
                        fails.append((e.name, m, verdicts[m]))
                    else:
                        counts[m]["XFAIL"] += 1
                        # ⛔ the OUTCOME, not merely the exemption: the marker says "expected red" and says nothing
                        # about WHICH red, and a crash, a hang, a wrong answer and a compile refusal are four
                        # different repairs. Bucketed by the verdict's own kind so a new kind cannot go uncounted.
                        counts[m]["XFAIL_" + ck] = counts[m].get("XFAIL_" + ck, 0) + 1
                else:
                    counts[m][ck] += 1
                    if kind == _OOMK:
                        counts[m][_OOMK] += 1
                    if kind != "PASS":
                        fails.append((e.name, m, verdicts[m]))
            # ⛔ AN XFAIL ENTRY IS NOT GREEN. It is EXPECTED red, which is why it is kept out of every mode's
            # PASS bucket above -- so counting it here would let the AND exceed the per-mode counts it summarises.
            all_n += 1
            if not e.xfail and all(verdicts[m].kind == "PASS" for m in modes):
                all_pass += 1
    finally:
        import shutil
        shutil.rmtree(tmp_root, ignore_errors=True)

    family = Path(args.sno).stem
    # total= is the GRADED denominator; shipped= adds the outside entries back, outside= is their count. A row quotes all_pass over shipped with OUTSIDE named.
    fields = [f"family={family}"] + ([shard_tag] if shard_tag else []) + [f"total={len(run_entries)} shipped={len(run_entries) + len(_out_run)} outside={len(_out_run)}"]
    for m in modes:
        c = counts[m]
        fields.append(f"{m}_n={len(run_entries)} "
                       f"{m}_pass={c['PASS']} {m}_fail={c['FAIL']} {m}_crash={c['CRASH']} "
                       f"{m}_hang={c['HANG']} {m}_unproven={c['UNPROVEN']} {m}_skip={c['SKIP']} "
                       f"{m}_xfail={c['XFAIL']} {m}_xpass={c['XPASS']} "
                       f"{m}_xfail_wrong={c['XFAIL_FAIL']} {m}_xfail_crash={c['XFAIL_CRASH']} "
                       f"{m}_xfail_hang={c['XFAIL_HANG']} {m}_xfail_unproven={c['XFAIL_UNPROVEN']} "
                       f"{m}_xfail_skip={c['XFAIL_SKIP']}")
    # ⛔⭐ all_pass IS THE FIELD A SUITE ROW QUOTES (ceo-372). It sits beside the per-mode counts, never
    # instead of them: the cell carries both so the split stays readable, and a reader who wants one mode still
    # has it. Shards partition the entries, so these two sum across shards exactly as every other field does.
    fields.append(f"all_pass={all_pass} all_n={all_n}")
    fields.append(f"rt_md5={_rt_md5} arena_kb={_arena_kb} arena_mb={_arena_mb}" + (f" arena_cap_mb={_arena_cap}" if _arena_cap else ""))
    # ⭐ <m>_fail_oom: how many of <m>_fail were a properly reported out-of-memory (CEO-1229 (2)) -- INSIDE fail, never beside it
    # (see _OOMK), and at the end of the line, after every field a reader already knows, so none meets a new one between two it knows.
    fields.append(" ".join(f"{m}_fail_oom={counts[m][_OOMK]}" for m in modes))
    # ⭐ extension= (CEO-1416): the graded entries of THIS run whose ref an extension oracle cut, not the suite's -- counted over the
    # run's own entries so shards sum to the ledger's count, last on the line so no reader meets it between two fields it knows.
    fields.append(f"extension={sum(1 for e in run_entries if e.name in _ext_rows)}")
    _bin_unmoved_or_refuse()
    print("SUITE_BOARD " + " ".join(fields))
    # ⭐⭐ THE HARNESS LISTS EVERY OOM PROGRAM BY NAME (CEO-1229 (2): "so each one gets its heap declaration, or a leak cure if its
    # live set is garbage"), each with the hard cap the runtime ITSELF named in its report -- the heap the run had, never re-derived
    # from the attribute file, because the report is the measurement and the file is only the request. Printed on EVERY board, with
    # n=0 stated, so a reader can tell "no program ran out" from "this harness predates the word".
    _oom_items = []
    for _n, _m, _v, _xf in oom_named:
        _r = oom_report(_v.stderr)
        _oom_items.append(f"{_n} {_m} cap={_r[1] if _r else '?'}KB" + (" xfail" if _xf else ""))
    print(f"OOM_PROGRAMS family={family} n={len(oom_named)}" + (": " + "; ".join(_oom_items) if _oom_items else "")
          + " (each a properly reported out-of-memory at the heap it ran under: outside the numerator, counted inside <mode>_fail on"
          " the SUITE_BOARD line and split out as <mode>_fail_oom; it wants a heap_kb declaration above its cap, or a leak cure)")
    _progress_record(args.sno, paths, _progress_rows[_rr_done[0]:], already=_rr_done[1])
    # ⛔ the 40-line sample is a SUMMARY, not a listing: the 5 FAIL / 8 XPASS / 10 HANG entries of a 371-entry
    # board never appeared in it, so nothing could be rowed from names. SUITE_LIST_ALL=1 lists every non-PASS
    # entry (opt-in; the default output is unchanged).
    import os as _os
    for name, m, v in (fails if _os.environ.get('SUITE_LIST_ALL') else fails[:40]):
        tag = "XPASS(marker stale, promote it)" if v.kind == "PASS" else v.kind
        # the fingerprint of OUR stdout beside every red (see _entry_note): a red that moved is a diff, not a silence
        # SUITE_STDERR_HEAD=1 (opt-in, the coo 2026-10-14 for the ceo's empty-output census, CEO-1709): the run's first non-empty stderr
        # line rides beside each red, so a class of FAIL that prints nothing names what it said instead; the default output is unchanged
        _e1 = ""
        if _os.environ.get('SUITE_STDERR_HEAD'):
            _e1 = next((l.strip() for l in (v.stderr or b'').decode('utf-8', 'replace').splitlines() if l.strip()), "")
            _e1 = " err1=" + (_e1[:160].replace("\t", " ") if _e1 else "(none)")
        print(f"  {tag} {m} {name}: {v.detail} [fp={hashlib.md5(v.stdout or b'').hexdigest()[:8]} rc={'-' if v.returncode is None else v.returncode}]{_e1}", file=sys.stderr)
    # a cut sample says it is cut (the coo 2026-10-24, COO-422: D3's 5 m3 crashes printed 4, the fifth past line 40 with no word)
    if len(fails) > 40 and not _os.environ.get('SUITE_LIST_ALL'):
        print(f"  (sample: 40 of {len(fails)} non-PASS lines shown, {len(fails) - 40} not shown; SUITE_LIST_ALL=1 lists every one)", file=sys.stderr)
    sys.exit(0 if not fails else 1)


PARTITION_RUN = {"name": ""}   # the --partition this run grades, read by _progress_record into each row's config (CEO-1676 row (d))


def _entry_note(xfail, v, shard_tag=""):
    # ⛔ A RED IS A BUCKET, NOT A VERDICT (hq_snobol4 2026-09-16, row instruments-a-red-is-a-bucket-every-board-prints-a-fingerprint-
    # beside-each-red-and-the-denominator-of-its-comparison): SnoRungs read 1962/1981 with a defect and 1962/1981 without it while
    # testpgms test1 was red on base AND head with a DIFFERENT first diff each time -- every board compared counts, the careful
    # ones red NAME SETS, and both treat reds as interchangeable.  So every non-PASS row carries a FINGERPRINT of OUR OWN stdout
    # for that entry (md5/8) and its rc, beside the xfail marker and the shard tag (row instruments-a-sharded-harness-run-appends-
    # progress-rows-wearing-a-full-boards-suite-name: a --shard k/N run used to append rows a reader could not tell from a
    # full board's).  The note column is SPACE-SEPARATED TOKENS from here on; every reader splits it (xfail is a token, a
    # criterion label is a token, fp=/rc=/shard= are tokens).
    toks = []
    if xfail:
        toks.append("xfail")
    if v is not None and v.kind != "PASS":
        toks.append("fp=%s" % hashlib.md5(v.stdout or b"").hexdigest()[:8])
        toks.append("rc=%s" % ("-" if v.returncode is None else v.returncode))
    if v is not None and v.kind == "OOM":
        # ⭐ "recorded with that heap" (CEO-1229 (2)): the hard cap the runtime named in its own report, and the error it raised.
        _r = oom_report(v.stderr)
        if _r:
            toks.append("heap_cap_kb=%d" % _r[1])
            toks.append("oom_error=%d" % _r[0])
    if v is not None and getattr(v, "retry", ""):
        toks.extend(v.retry.split())   # retried=1 load1=<first>/<second> nproc=<n> (CEO-1335)
    if shard_tag:
        toks.append(shard_tag)
    return " ".join(toks)


PROGRESS_PACKAGE_KEYS = {"arizona_tests": "arizona", "jcon_tests": "jcon", "unicon_tests": "unitests", "ipl": "ipl", "csnobol4_suite": "csnobol4", "gimpel": "gimpel",
                         "snoflake_suite": "snoflake", "aisnobol": "aisnobol", "dotnet": "dotnet", "swi_tests": "swi", "gnu_prolog": "gnu",
                         "inriasuite": "inria", "fpc_tests": "fpc", "pat": "pat", "spitbol_testpgms": "testpgms", "roast": "roast",
                         "trealla_tests": "trealla", "xsb_tests": "xsb"}   # the coo 2026-10-10: TreallaTests' row key is trealla; without this its 658 graded rows went in as trealla_tests and the writer read 0 PASS


def progress_suite_for(sno_path, paths):
    """(class, suite, lang) when sno_path is a CANONICAL suite -- corpus/tests/<lang>/ALL.<ext> or
    corpus/packages/<lang>/<pkg>/ALL.<ext> under this tree's corpus root (or under any root when S4E_PROGRESS_DB
    redirects the table, which is how the gate proves the arm) -- else None. A scratch copy of a rung suite grades
    exactly as before and records nothing: the live table only ever sees the real suites."""
    p = Path(sno_path).resolve()
    parts = p.parts
    redirected = bool(os.environ.get("S4E_PROGRESS_DB"))
    corpus_root = str(Path(paths["corpus"]).resolve())
    under_corpus = str(p).startswith(corpus_root + os.sep)
    if not (under_corpus or redirected):
        return None
    if p.stem != "ALL":
        return None
    # ⛔ A PORT ENGINE'S ROWS ARE KEYED <suite>@<engine> AND NEVER LAND IN SCRIP'S (CEO-1822): snobol4-rungs is SCRIP's series,
    # snobol4-rungs@dotnet is snobol4dotnet's, so a dotnet board can neither move nor be mistaken for a SCRIP reading.
    at = "" if paths["engine"] == "scrip" else "@" + paths["engine"]
    if len(parts) >= 3 and parts[-3] == "tests":
        return ("rungs", f"{parts[-2]}-rungs{at}", parts[-2])
    if len(parts) >= 4 and parts[-4] == "packages":
        return ("package", PROGRESS_PACKAGE_KEYS.get(parts[-2], parts[-2]) + at, parts[-3])
    return None


def _progress_pin(paths):
    """Read the tree hashes and the scrip+libscrip_rt.so digest BEFORE the first program is graded, so the rows this
    run appends name the ground it ACTUALLY graded. ⛔ util_progress_append.context() used to run rev-parse at APPEND
    time: seat10's board pulled twice and rebuilt once under a 79-minute run and its 3736 rows were stamped with the
    tree that existed when the run ENDED (CEO-338). The runner's own binary-moved refusal fired at 14:23 -- after the
    harness had already written them."""
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import util_progress_append as _pa
        # under a port engine the graded binary is the driver its runner names (CEO-1822): its own checkout's git toplevel is the port's
        # (snobol4dotnet), so the rows' tree column names the port commit that graded them, never a SCRIP one
        _bins = engine_binaries(paths["engine"]) if paths["engine"] != "scrip" else []
        if _bins:
            _pa.pin_context(_bins[0], os.path.dirname(_bins[0]))
        else:
            _pa.pin_context(str(paths["scrip_bin"]), str(paths["rt_dir"]))
    except Exception as e:
        print(f"⛔ PROGRESS PIN FAILED ({e.__class__.__name__}: {e}) -- this run's rows cannot be proven to name the "
              f"tree they graded, so the append will not be guarded. Fix the pin; never silence it.", file=sys.stderr)


def _progress_record(sno_path, paths, rows, quiet=False, already=0):
    """Append one row per (entry, mode) graded to THE PROGRESS DATABASE through the ONE writer (util_progress_append.py).
    Loud on refusal: a board that could not be recorded is printed AND exits 2 -- progress/README.md, CEO-319."""
    where = progress_suite_for(sno_path, paths)
    if where is None or (not rows and not already):
        return 0
    cls, suite, lang = where
    if not rows:
        print(f"PROGRESS_RECORDED suite={suite} class={cls} rows={already} db=(streamed, one test at a time)")
        return 0
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import util_progress_append as _pa
    try:
        # ⛔⭐ THE RUNNER DECLARES WHAT IT EXERCISED, BECAUSE IT IS THE ONLY PARTY THAT KNOWS (coo 2026-09-21,
        # ceo rank 0 at CEO-1047/CEO-1050). The progress database refuses a row that declares no configuration
        # while a GC axis is set, and the harness is the site that actually ran the programs -- so it states the
        # axis instead of letting a board discover the refusal. `shipped` is a POSITIVE STATEMENT that this run
        # used the shipped configuration, which the harness can make and the writer cannot: the writer sees only
        # its own environment and a runner may set the axis per-child.
        _axis = _pa.gc_axis_env()
        _config = ",".join(f"{k}={v}" for k, v in _axis.items()) if _axis else "shipped"
        # ⭐ a partition run says so in its config (CEO-1676 row (d): "every chunk run stamps its progress rows' config with partition=chunk:NN")
        # -- the shape of the run, never a configuration of the program: util_progress_flips.py drops the token from its series key.
        if PARTITION_RUN["name"]:
            _config += f",partition={PARTITION_RUN['name']}"
        # ⛔ THE KEY IS THE BOARD'S (the coo 2026-10-09, CEO-1366 (b) under CEO-1269): an Icon package entry graded through its driver
        # is recorded under the LIBRARY, the key the package's board writes, through the one rule both sides import.
        from lib_package_keys import board_key as _bk
        _pkg = Path(sno_path).resolve().parent
        n = _pa.append_rows([{"class": cls, "suite": suite, "lang": lang, "program": _bk(_pkg, lang, name), "mode": m, "outcome": kind, "secs": secs or 0, "note": note, "config": _config} for name, m, kind, secs, note in rows])
    except _pa.ProgressUnwritable:
        sys.exit(2)
    except _pa.ProgressGroundMoved as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)
    if n and not quiet:
        print(f"PROGRESS_RECORDED suite={suite} class={cls} rows={n + already} db={_pa.db_path()}")
    return n


def refpins_path(src_path):
    """The pin ledger beside a rung suite pair: ALL.refpins.tsv for ALL.sno."""
    return Path(src_path).parent / (Path(src_path).stem + ".refpins.tsv")


def read_refpins(src_path):
    """{entry: {"sha": ..., "ruling": ..., "measurer": ..., "date": ...}} -- {} when there is no ledger."""
    p = refpins_path(src_path)
    out = {}
    if not p.is_file():
        return out
    for raw in p.read_text().splitlines():
        if not raw.strip() or raw.startswith("#"):
            continue
        f = raw.split("\t")
        if len(f) >= 5:
            out[f[0]] = {"sha": f[1], "measurer": f[2], "date": f[3], "ruling": f[4]}
    return out


# ⛔⭐⭐ THE EXTENSION REF (Lon 2026-10-02 15:5x CDT, in-chat to the coo, verbatim: "So mark it passing. We need a concept now of
# extensions which will NOT have their REF generated by oracle. But generated by us here." · "In this case use CSNOBOL4 to gen the ORD
# tests. Mark the test as not generated by the SPITBOL oracle."). A program that exercises an EXTENSION the language's one oracle lacks
# (ORD, which sbl -bf answers with ERROR 022) is graded against a ref cut by a NAMED other oracle, and stays in the denominator. The
# mark is a ledger beside the data -- ALL.extensions.tsv beside a rung suite, EXTENSIONS.tsv beside a package -- one row per entry:
#   name<TAB>ref_oracle<TAB>feature<TAB>sha256-16<TAB>measurer<TAB>date<TAB>ruling
# ref_oracle is a lib_oracle_flags.sh accessor in EXTENSION_ORACLES, never the suite's own oracle. The sha is of the entry's ref text
# exactly as pin-ref hashes it, so a ref edited after the ruling no longer matches its row and every reader refuses until it is re-cut.
# Every run prints the rows (EXTENSION_REF ...), so no reader can take the entry for one the SPITBOL oracle graded; capture-oracle-refs
# refuses to overwrite one; a name both here and in an outside list refuses. `extension-ref` is the one writer.
EXTENSION_ORACLES = {"csnobol4_bin": ""}   # accessor -> the flags it runs with; extend only on a ruling naming the oracle


def extension_refs_path(src_path):
    """The extension ledger for a suite: ALL.extensions.tsv beside a rung suite ALL.<ext>, EXTENSIONS.tsv in a package directory."""
    sp = Path(src_path)
    if sp.name.startswith("ALL."):
        return sp.parent / "ALL.extensions.tsv"
    return (sp if sp.is_dir() else sp.parent) / "EXTENSIONS.tsv"


def read_extension_refs(ledger):
    """{name: {"oracle", "feature", "sha", "measurer", "date", "ruling"}} -- {} when there is no ledger; refuses a malformed row or an
    oracle accessor this file does not know, because a ledger row nobody can re-run is a claim and not a mark."""
    p = Path(ledger)
    out = {}
    if not p.is_file():
        return out
    for raw in p.read_text(encoding="utf-8").splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        f = raw.split("\t")
        if len(f) < 7 or not all(x.strip() for x in f[:7]):
            refuse(f"{p}: an extension row is name<TAB>ref_oracle<TAB>feature<TAB>sha256-16<TAB>measurer<TAB>date<TAB>ruling, all seven filled: {raw[:100]}")
        if f[1].strip() not in EXTENSION_ORACLES:
            refuse(f"{p}: {f[0]} names ref_oracle {f[1]!r}, not one of {sorted(EXTENSION_ORACLES)} -- an extension ref is re-cut by a named accessor or it is not evidence")
        if f[0].strip() in out:
            refuse(f"{p}: {f[0]} is declared twice")
        out[f[0].strip()] = {"oracle": f[1].strip(), "feature": f[2].strip(), "sha": f[3].strip(),
                             "measurer": f[4].strip(), "date": f[5].strip(), "ruling": "\t".join(f[6:]).strip()}
    return out


def ref_sha16(ref_lines):
    """The one hash of a ref, shared by pin-ref and the extension ledger."""
    return hashlib.sha256(("\n".join(ref_lines) + "\n").encode()).hexdigest()[:16]


def resolve_extension_oracle(paths, accessor):
    """(binary, flags) for an EXTENSION_ORACLES accessor, through lib_oracle_flags.sh -- never a hand-built path."""
    if accessor not in EXTENSION_ORACLES:
        refuse(f"extension oracle {accessor!r} is not one of {sorted(EXTENSION_ORACLES)}")
    lib = HARNESS_SCRIPTS / "lib_oracle_flags.sh"
    r = subprocess.run(["bash", "-c", f". '{lib}' && {accessor}"], capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        refuse(f"lib_oracle_flags.sh refused ({accessor}): {r.stderr.strip()}")
    return r.stdout.strip(), EXTENSION_ORACLES[accessor]


def report_extension_refs(src_path, entries, outside_names):
    """Print the extension rows a run grades and refuse a stale or contradictory one. Returns the {name: row} it read."""
    led = extension_refs_path(src_path)
    rows = read_extension_refs(led)
    if not rows:
        print(f"EXTENSION_REF_LIST NONE (no {led.name} beside this suite)")
        return rows
    by_name = {e.name: e for e in entries}
    absent = sorted(set(rows) - set(by_name))
    if absent:
        refuse(f"{led}: declares entries that are not in this suite: {absent}")
    both = sorted(set(rows) & set(outside_names))
    if both:
        refuse(f"{led}: {both} also stand in the outside list -- an entry is graded against its extension ref or it is outside, never both")
    for n in sorted(rows):
        e = by_name[n]
        lines = e.ref.split("\n") if isinstance(e.ref, str) else list(e.ref)
        if ref_sha16(lines) != rows[n]["sha"]:
            refuse(f"{led}: {n}'s ref no longer hashes to its ruled sha {rows[n]['sha']} (reads {ref_sha16(lines)}) -- re-cut it with "
                   f"`extension-ref`, never re-bless it by hand")
    print(f"EXTENSION_REF_LIST {led} -- {len(rows)} entr(ies) graded against a ref NOT cut by this suite's oracle")
    for n in sorted(rows):
        r = rows[n]
        print(f"EXTENSION_REF {n} ref_oracle={r['oracle']} feature={r['feature']} sha={r['sha']} ({r['measurer']} {r['date']}): {r['ruling']}")
    print(f"EXTENSION_REF_COUNT {len(rows)} entr(ies) in the denominator whose ref the suite's oracle did not cut, named above")
    return rows


def cmd_extension_check(args):
    """The extension ledger of a PACKAGE directory (EXTENSIONS.tsv), checked and printed for a bash runner: every row names a program
    with a .ref beside it whose text still hashes to the row's sha, and no row also stands in the package's outside, EXCLUDED,
    UNGRADABLE, UNGRADED or CONTAINERS list. Prints EXTENSION_REF lines and EXTENSION_REF_COUNT k; --names prints only the names."""
    d = Path(args.package)
    if not d.is_dir():
        refuse(f"extension-check: {d} is not a package directory")
    led = d / "EXTENSIONS.tsv"
    rows = read_extension_refs(led)
    listed = _smoke_outside_names(d / "ALL.sno")
    for n, r in sorted(rows.items()):
        prog, ref = d / n, (d / n).with_suffix(".ref")
        if not prog.is_file() or not ref.is_file():
            refuse(f"{led}: {n} names no program with a .ref beside it in {d}")
        if n in listed or prog.stem in listed:
            refuse(f"{led}: {n} also stands in an outside/EXCLUDED/UNGRADABLE/UNGRADED/CONTAINERS list beside it -- graded against its extension ref or left out, never both")
        got = ref_sha16(ref.read_text(encoding="utf-8", errors="replace").rstrip("\n").split("\n"))
        if got != r["sha"]:
            refuse(f"{led}: {n}.ref no longer hashes to its ruled sha {r['sha']} (reads {got}) -- re-cut it with `extension-ref`, never by hand")
    if args.names:
        for n in sorted(rows):
            print(n)
        return
    for n in sorted(rows):
        r = rows[n]
        print(f"EXTENSION_REF {n} ref_oracle={r['oracle']} feature={r['feature']} sha={r['sha']} ({r['measurer']} {r['date']}): {r['ruling']}")
    print(f"EXTENSION_REF_COUNT {len(rows)} program(s) in the denominator whose ref the suite's oracle did not cut{', named above' if rows else ''}")

def cmd_extension_ref(args):
    """⛔⭐ CUT ONE ENTRY'S REF FROM A NAMED NON-SPITBOL ORACLE AND MARK IT IN THE EXTENSION LEDGER (Lon 2026-10-02, above).

    The suite's own oracle is asked first and its answer printed and recorded: when it prints exactly what the extension oracle prints,
    the entry needs no extension and this refuses. Without --apply it prints the before/after and writes nothing. With --apply it writes
    the ref (a rung suite's entry block, or a package program's NAME.ref) and the ledger row, sha and ruling included."""
    paths = resolve_paths()
    led = extension_refs_path(args.suite)
    if not args.ruling or not args.ruling.strip() or not args.feature.strip():
        refuse("extension-ref needs --feature and a non-empty --ruling naming who ruled it")
    ob, of = resolve_extension_oracle(paths, args.oracle)
    sp = Path(args.suite)
    if sp.name.startswith("ALL."):
        cfg = LANG_CONFIGS[args.lang] if args.lang else None
        ref_path = sp.with_suffix(".ref")
        if cfg:
            co, cc = cfg["comment_open"], cfg["comment_close"]
            entries = read_block_suite(sp, ref_path, banner_re_for(co, cc), in_path=sidecar_in_path(sp), x_path=sidecar_xfail_path(sp),
                                       w_path=sidecar_wantrc_path(sp), a_path=sidecar_argv_path(sp))
        else:
            require_lang_for_suite("extension-ref", sp, args)
            co, cc = "*", ""
            entries = read_suite(sp, ref_path, in_path=sidecar_in_path(sp), x_path=sidecar_xfail_path(sp),
                                 w_path=sidecar_wantrc_path(sp), a_path=sidecar_argv_path(sp))
        hit = [e for e in entries if e.name == args.entry]
        if not hit:
            refuse(f"no entry named {args.entry!r} in {sp} ({len(entries)} entries)")
        e = hit[0]
        old_ref = e.ref.split("\n") if isinstance(e.ref, str) else list(e.ref)
        prog_text, stdin_text, stem = "\n".join(e.sno_lines) + "\n", e.stdin, args.entry
        ext = sp.suffix
    else:
        prog = sp.parent / args.entry if sp.is_file() else sp / args.entry
        if not prog.is_file():
            refuse(f"no program {prog}")
        ref_path = prog.with_suffix(".ref")
        old_ref = ref_path.read_text(encoding="utf-8", errors="replace").rstrip("\n").split("\n") if ref_path.is_file() else [""]
        prog_text, stdin_text, stem, ext, e = prog.read_text(encoding="latin-1"), None, prog.stem, prog.suffix, None
        entries = None
    answers = {}
    for who, (b, f) in (("extension", (ob, of)), ("suite", resolve_oracle_bin(paths, args.lang or ""))):
        t = Path(tempfile.mkdtemp(prefix="extension_ref."))
        try:
            if e is None:
                for x in prog.parent.iterdir():
                    if x.is_file():
                        shutil.copy2(x, t / x.name)
            one = t / (stem + ext)
            one.write_text(prog_text, encoding="latin-1")
            answers[who] = run_oracle(b, f, one, paths["timeout"], stdin_text=stdin_text)
        finally:
            shutil.rmtree(t, ignore_errors=True)
        print(f"--- {who} oracle ({b} {f}): {answers[who][2]} rc={answers[who][1]}")
        for l in (answers[who][0].split("\n") if answers[who][0] else [])[:20]:
            print("    o " + l)
    xt, xrc, xk = answers["extension"]
    if xk != "RAN":
        refuse(f"the extension oracle came back {xk} rc={xrc} -- a ref is what an oracle ANSWERED")
    if answers["suite"][2] == "RAN" and answers["suite"][0] == xt:
        refuse(f"the suite's own oracle prints exactly what {args.oracle} prints -- {args.entry} needs no extension ref; grade it against its own oracle")
    new_ref = xt.split("\n") if xt else [""]
    print(f"--- {args.entry}: ref BEFORE ({len(old_ref)} line(s))")
    for l in old_ref[:20]:
        print("    - " + l)
    print(f"--- {args.entry}: ref AFTER, cut by {args.oracle} ({len(new_ref)} line(s))")
    for l in new_ref[:20]:
        print("    + " + l)
    if not args.apply:
        print("\nDRY RUN -- nothing written. Re-run with --apply to write the ref and the ledger row.")
        return
    if e is not None:
        e.ref = "\n".join(new_ref) if isinstance(e.ref, str) else new_ref
        if cfg:
            write_block_suite(entries, sp, ref_path, co, cc, out_in=sidecar_in_path(sp), out_x=sidecar_xfail_path(sp))
        else:
            write_suite(entries, sp, ref_path, out_in=sidecar_in_path(sp))
    else:
        ref_path.write_text("\n".join(new_ref) + "\n", encoding="latin-1")
    rows = read_extension_refs(led)
    st = answers["suite"]
    rows[args.entry] = {"oracle": args.oracle, "feature": args.feature.strip(), "sha": ref_sha16(new_ref),
                        "measurer": args.measurer or os.environ.get("S4E_SEAT", "unknown"),
                        "date": time.strftime("%Y-%m-%dT%H:%MZ", time.gmtime()),
                        "ruling": args.ruling.strip() + f"  [THE SUITE'S OWN ORACLE AT CUT TIME: {st[2]} rc={st[1]}: "
                                  + (st[0].strip().split("\n")[0][:120] if st[0].strip() else "no output") + "]"}
    with open(led, "w", encoding="utf-8") as f:
        f.write("# EXTENSION REFS for this suite (Lon 2026-10-02: a test of an extension the suite's one oracle lacks gets its REF from a\n"
                "# NAMED other oracle and is marked here as NOT generated by the suite's oracle). Each entry stays in the denominator and is\n"
                "# graded against that ref; every run prints these rows; capture-oracle-refs refuses to overwrite one; a ref edited\n"
                "# after its row was cut no longer matches its sha and refuses. Written by `corpus_suite_harness.py extension-ref`.\n"
                "# name\tref_oracle\tfeature\tsha256-16\tmeasurer\tdate\truling\n")
        for k in sorted(rows):
            r = rows[k]
            f.write(f"{k}\t{r['oracle']}\t{r['feature']}\t{r['sha']}\t{r['measurer']}\t{r['date']}\t{r['ruling']}\n")
    print(f"\n✅ EXTENSION REF {args.entry} cut by {args.oracle} · ledger {led} now carries {len(rows)} row(s) · sha256/16 {ref_sha16(new_ref)}")
    print("   ⛔ Commit the ref AND the ledger together, and take the entry out of any outside or EXCLUDED list in the same commit.")

def cmd_pin_ref(args):
    """⛔⭐ RE-ANCHOR ONE ENTRY'S REF TO SCRIP'S OWN RULED OUTPUT, WITH PROVENANCE AND A LEDGER.

    THE GAP THIS FILLS (hq_C -> hq_T, 2026-09-04, blocking the SNOBOL4 rungs control arm): an entry whose
    correct answer is a SCRIP RULING rather than the oracle's answer had NO supported way to be re-anchored.
    The witness is `p = LEN(1) . *(n = n + 1)` (entry user_function_len_defer_branch_6): Lon ruled the
    lambda-deferred-target sugar in, SCRIP now prints `before / after n=1 dummy=[]`, SPITBOL fails the
    construct and always will -- so `capture-oracle-refs` would faithfully re-record the OLD answer, which is
    exactly what seat08 warned must never be run on that row. The rungs' loose source pair no longer exists
    (one-flat-suite), so there was no upstream to fix either: the only remaining option was hand-editing a
    generated 1753-entry file, which hq_C correctly refused to do.

    ⛔ THE PIN IS NOT THE POINT -- THE LEDGER IS. Any tool can overwrite a ref. What makes this safe is that
    every pin is recorded in ALL.refpins.tsv with the entry, a sha256 of the exact pinned text, who ruled it,
    when, and WHY; and capture-oracle-refs consults that ledger and REFUSES to touch a pinned entry rather
    than silently restoring the oracle's answer. A ref that disagrees with the oracle ON PURPOSE and a ref
    that disagrees BY ACCIDENT look identical in the file -- the ledger is the only thing that tells them
    apart, and without it the next oracle capture quietly undoes a ruling nobody remembers.

    ⛔ --ruling IS MANDATORY AND IS NOT DECORATION. A pin with no stated authority is indistinguishable from
    a ref cut while the compiler was broken, which is the precise failure this project spends its gates on.
    ⛔ THE PINNED TEXT COMES FROM A RUN, NEVER FROM TYPING: --from-scrip runs the entry through the mode the
    caller names and pins what actually came out. Text typed by hand is a claim about behaviour; output from
    a run is evidence of it.
    ⭐ Everything except the one entry's ref block is rewritten BYTE-IDENTICALLY -- the writer is the same
    write_block_suite the builder uses, fed the same entries, so the pin cannot smuggle in a reindex."""
    paths = resolve_paths()
    src_path, ref_path = Path(args.sno), Path(args.ref)
    for label, p_ in (("suite", src_path), ("ref", ref_path)):
        if not p_.is_file():
            refuse(f"{label} file does not exist: {p_}")
    if not args.ruling.strip():
        refuse("--ruling is mandatory: a pinned ref with no stated authority cannot be told from a ref cut "
               "while the compiler was broken")
    # ⛔ THE READER IS CHOSEN THE WAY `run` CHOOSES IT, never assumed. The SNOBOL4 rungs is MIXED -- one-line
    # entries and banner blocks in one file -- and read_block_suite dies on its very first line. Getting this
    # wrong is not a crash you can ignore: a pin is a rewrite of the whole pair, so a reader that mis-parses
    # would rewrite 1753 entries into whatever it thought it read.
    cfg = LANG_CONFIGS[args.lang] if args.lang else None
    if cfg:
        co, cc = cfg["comment_open"], cfg["comment_close"]
        entries = read_block_suite(src_path, ref_path, banner_re_for(co, cc), in_path=sidecar_in_path(src_path),
                                   x_path=sidecar_xfail_path(src_path), w_path=sidecar_wantrc_path(src_path),
                                   a_path=sidecar_argv_path(src_path))
    else:
        require_lang_for_suite("pin-ref", src_path, args)
        co, cc = "*", ""
        entries = read_suite(src_path, ref_path, in_path=sidecar_in_path(src_path),
                             x_path=sidecar_xfail_path(src_path), w_path=sidecar_wantrc_path(src_path),
                             a_path=sidecar_argv_path(src_path))
    hit = [e for e in entries if e.name == args.entry]
    if not hit:
        refuse(f"no entry named {args.entry!r} in {src_path} ({len(entries)} entries) -- `list` prints them")
    e = hit[0]
    # ⭐ Entry.ref is a STRING for a one-line entry and a LIST for a block -- normalise for the diff, and put
    # the entry's own shape back before writing, or a one-line entry would be rewritten as a list of chars.
    old_ref = e.ref.split("\n") if isinstance(e.ref, str) else list(e.ref)
    check_scrip(paths)
    tmp = Path(tempfile.mkdtemp(prefix="pin_ref."))
    try:
        ext = cfg["ext"] if cfg else ".sno"
        one = tmp / (args.entry + ext)
        one.write_text("\n".join(e.sno_lines) + "\n")
        stdin_text = e.stdin
        if args.mode == "m3":
            v = run_m3(paths, one, "\n".join(old_ref), stdin_text=stdin_text, want_rc=e.want_rc, prog_argv=e.argv, compile_args=e.compile_args)
        else:
            v = run_m4(paths, one, "\n".join(old_ref), tmp, stdin_text=stdin_text, want_rc=e.want_rc, prog_argv=e.argv, compile_args=e.compile_args)
        if v.kind in ("CRASH", "HANG", "UNPROVEN", "SKIP", "OOM"):
            refuse(f"{args.mode} on {args.entry} came back {v.kind} ({v.detail}) -- a pin records what the "
                   f"compiler DOES, and a run that crashed or could not be made says nothing about that")
        # ⭐ Verdict.text is a METHOD here, not a property -- and the whole file calls it as one. Reading the
        # class as if it were a dataclass is how `v.text.split` became "'function' object has no attribute".
        _txt = v.text().rstrip("\n")
        new_ref = _txt.split("\n") if _txt else [""]
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    # ⛔⛔⭐ THE ORACLE IS ASKED, ALWAYS, AND ITS ANSWER IS RECORDED -- BECAUSE THE FIRST USE OF THIS VERB
    # BLESSED A REGRESSION (hq_T, 2026-09-04, reverted in corpus 33e747c2c). The pin was applied on a REPORTED
    # premise -- "SPITBOL fails this construct too, so it can never be graded against an oracle-captured ref"
    # -- and the premise was false: `sbl -bf` runs that program cleanly, rc=0, and prints exactly what the ref
    # already held. The ref was oracle-valid, SCRIP diverged from it, and the pin turned a CORRECT red gate
    # green by rewriting the expectation to match the compiler. That is the ICN4 false green in mirror image.
    # ⭐ THE CURE IS NOT "BE MORE CAREFUL", IT IS TO MAKE THE PREMISE A MEASUREMENT. "The oracle cannot grade
    # this" is a claim about a program, and this tool can settle it in one run, so it does -- and it records
    # the oracle's own answer in the ledger, so a later reader can check the ruling instead of trusting it.
    # ⛔ A CLEAN ORACLE ANSWER THAT DISAGREES WITH THE PIN REFUSES. Overriding needs --oracle-disagrees-and-i-
    # mean-it, which exists so the override is a sentence someone had to type, not a flag they might miss.
    ora_line, ora_rc, ora_kind, ora_text = "not consulted", None, "", ""
    if not args.lang:
        # resolve_oracle_bin returns (binary, flags) -- the ONE authority, never re-derived here.
        _ob, _of = resolve_oracle_bin(paths, args.lang)
        if _ob:
            _t2 = Path(tempfile.mkdtemp(prefix="pin_oracle."))
            try:
                one2 = _t2 / (args.entry + ".sno")
                one2.write_text("\n".join(e.sno_lines) + "\n")
                ora_text, ora_rc, ora_kind = run_oracle(_ob, _of, one2, paths["timeout"], stdin_text=e.stdin)
            finally:
                shutil.rmtree(_t2, ignore_errors=True)
            ora_line = f"{ora_kind} rc={ora_rc}"
            print(f"--- the ORACLE's own answer for {args.entry}: {ora_line}")
            for l in (ora_text.split("\n") if ora_text else [])[:20]:
                print("    o " + l)
            if ora_kind == "RAN" and ora_rc == 0:
                _ol = ora_text.split("\n") if ora_text else [""]
                if _ol != new_ref and not args.oracle_disagrees_and_i_mean_it:
                    refuse(f"the oracle RAN {args.entry} cleanly (rc=0) and its answer differs from what you are "
                           f"about to pin -- so this entry CAN be oracle-graded, and pinning SCRIP's output over "
                           f"it would turn a correct red into a green. If the oracle is genuinely wrong here, say "
                           f"so with --oracle-disagrees-and-i-mean-it and the ledger will record BOTH answers.")
    if new_ref == old_ref:
        print(f"⭐ NO CHANGE: {args.entry}'s ref already matches {args.mode} output -- nothing pinned, nothing written.")
        return
    print(f"--- {args.entry}: ref BEFORE ({len(old_ref)} line(s))")
    for l in old_ref[:20]:
        print("    - " + l)
    print(f"--- {args.entry}: ref AFTER, from a live {args.mode} run ({len(new_ref)} line(s))")
    for l in new_ref[:20]:
        print("    + " + l)
    if not args.apply:
        print("\nDRY RUN -- nothing written. Re-run with --apply to pin it and record the ledger line.")
        return
    e.ref = "\n".join(new_ref) if isinstance(e.ref, str) else new_ref
    if cfg:
        write_block_suite(entries, src_path, ref_path, co, cc,
                          out_in=sidecar_in_path(src_path), out_x=sidecar_xfail_path(src_path))
    else:
        write_suite(entries, src_path, ref_path, out_in=sidecar_in_path(src_path))
    led = refpins_path(src_path)
    sha = hashlib.sha256(("\n".join(new_ref) + "\n").encode()).hexdigest()[:16]
    rows = read_refpins(src_path)
    rows[args.entry] = {"sha": sha, "measurer": args.measurer or os.environ.get("S4E_SEAT", "unknown"),
                        "date": time.strftime("%Y-%m-%dT%H:%MZ", time.gmtime()),
                        "ruling": args.ruling.strip() + f"  [ORACLE AT PIN TIME: {ora_line}]"}
    with open(led, "w") as f:
        f.write("# SCRIP-RULED REF PINS for this rung suite. ⛔ An entry listed here has a ref that DISAGREES WITH THE\n"
                "# ORACLE ON PURPOSE, on a stated ruling -- capture-oracle-refs REFUSES to touch these, because\n"
                "# restoring the oracle's answer would silently undo a decision nobody remembers making.\n"
                "# ⛔ A pin is evidence only while its sha matches: if the ref has been edited since, the pin no\n"
                "# longer describes the file and the entry must be re-ruled, not re-blessed.\n"
                "# entry\tsha256-16\tmeasurer\tdate\truling\n")
        for k in sorted(rows):
            r = rows[k]
            f.write(f"{k}\t{r['sha']}\t{r['measurer']}\t{r['date']}\t{r['ruling']}\n")
    print(f"\n✅ PINNED {args.entry} from a live {args.mode} run · ledger {led.name} now carries {len(rows)} pin(s)")
    print(f"   sha256/16 {sha} · ruling: {args.ruling.strip()}")
    print("   ⛔ Commit the rungs pair AND the ledger together -- a pin whose ledger line is unpushed is a ref "
          "that disagrees with the oracle for no recorded reason.")


def cmd_extract(args):
    """Materialize ONE suite entry back into a standalone .sno (+ optional .ref) file. For consumers that
    need per-witness standalone access a shared suite file cannot give them directly -- e.g. a gate script
    compiling one named witness under several env-var arms with custom stdout/stderr handling. Reuses
    read_suite() (ONE AUTHORITY for the suite grammar) rather than re-parsing the format a second time."""
    # ⛔⭐ TWO READERS EXIST AND THIS ONE PICKED THE WRONG ONE FOR BLOCK-ONLY FAMILIES (hq_B 2026-08-29).
    # read_suite() handles the one-line dialect and one-line/block INTERLEAVING; read_block_suite() handles a
    # format-(B)-ONLY family, where every entry is a banner-delimited block. cmd_extract called read_suite()
    # unconditionally, so on a block-only family it compared sno LINES to ref LINES 1:1 -- a correspondence
    # multi-line procedure bodies legitimately break -- and died with
    #     ValueError: family.ref is shorter than family.sno at seq N
    # MEASURED: rung10_augop (5 entries) and rung36_all (36 entries) both FAIL under read_suite and both read
    # CLEANLY under read_block_suite. rung10_augop's ref is 11 lines for 5 entries = 5 banners + 6 output
    # lines, which is exactly right; its .icn is 37 because the bodies are procedures.
    # ⛔⭐ THE ERROR TEXT NAMES ONLY ONE OF ITS TWO CAUSES, which is why this cost a wrong diagnosis before it
    # cost a fix: "family.ref is shorter than family.sno" is emitted BOTH when a ref is genuinely truncated AND
    # when the one-line reader is pointed at a block family. The first reading sends you to regenerate a
    # correct .ref against the oracle -- destructive work on a good file. Prefer the block reader and keep the
    # one-line reader as the fallback, and if BOTH fail report BOTH errors rather than the last one, so the
    # next reader is never handed a single cause for a two-cause signal.
    if getattr(args, "origin", ""):
        _csv = Path(args.sno).with_name("ALL.csv")
        if not _csv.is_file():
            refuse(f"--origin needs the rungs index beside the suite ({_csv}) and it is not there -- extract by name, or point at the rungs")
        import csv as _csvmod
        _hits = [r["entry"] for r in _csvmod.DictReader(open(_csv, encoding="utf-8")) if r.get("origin") == args.origin]
        if not _hits:
            _fam = args.origin.split("__", 1)[0]
            _near = sorted({r["origin"] for r in _csvmod.DictReader(open(_csv, encoding="utf-8")) if r.get("origin", "").startswith(_fam + "__")})[:8]
            refuse(f"no entry with origin {args.origin!r} in {_csv}" + (f" (same family has: {', '.join(_near)}{'...' if len(_near) == 8 else ''})" if _near else " (no origin of that family at all)"))
        if args.name and args.name != _hits[0]:
            refuse(f"--origin {args.origin} resolves to entry {_hits[0]!r} but the positional name says {args.name!r}; give one or the other")
        args.name = _hits[0]
    if not args.name:
        refuse("extract needs the entry NAME (positional) or --origin <origin>")
    _ext = Path(args.sno).suffix
    _copen, _cclose = "*", ""
    for _lc in LANG_CONFIGS.values():
        if _lc.get("ext") == _ext:
            _copen, _cclose = _lc.get("comment_open", "*"), _lc.get("comment_close", "")
            break
    # ⛔⭐⭐ A ROUND TRIP THAT DOES NOT CARRY EVERY FIELD THE GRADER READS IS NOT A ROUND TRIP (row
    # suite-harness-xfail-extract-round-trip, hq_P finding 2026-08-30, seat15 landing). Neither reader was
    # ever given in_path/x_path here, so e.stdin and e.xfail_reason came back None for EVERY extracted
    # entry regardless of what the suite actually carries -- exactly the same hole 4cc1ccbb closed in
    # util_build_rungs_suite.py's deletion verifier, one consumer over. MEASURED live and dangerous:
    # snobol4's ALL.in has 9 stdin-bearing entries; a stdin-starved program routinely exits rc=0 with
    # EMPTY output (identical exit code to a fed run), so nothing about the run distinguishes the two --
    # only carrying the field does. 21 scripts route through lib_rungs_extract.sh -> this function.
    _in_path = sidecar_in_path(args.sno)
    _x_path = sidecar_xfail_path(args.sno)
    try:
        entries = read_block_suite(args.sno, args.ref, banner_re_for(_copen, _cclose), in_path=_in_path, x_path=_x_path)
    except Exception as _block_err:
        try:
            entries = read_suite(args.sno, args.ref, in_path=_in_path, x_path=_x_path)
        except Exception as _line_err:
            print(f"⛔ REFUSED: {args.sno} reads as neither dialect.\n"
                  f"   as a BLOCK-only family : {type(_block_err).__name__}: {_block_err}\n"
                  f"   as a ONE-LINE family   : {type(_line_err).__name__}: {_line_err}\n"
                  f"   Both causes are shown deliberately: 'ref is shorter than sno' is reachable BOTH from a\n"
                  f"   genuinely truncated .ref AND from reading a block family with the one-line reader.",
                  file=sys.stderr)
            raise SystemExit(2)
    for e in entries:
        if e.name != args.name:
            continue
        # ⛔ REFUSE, never silently drop: an entry that needs stdin and is materialized without it is not
        # the witness the suite graded -- it is a DIFFERENT program that happens to share source text. A
        # stdin-starved SNOBOL4 program typically still exits rc=0 (INPUT read failure is not fatal by
        # default), so the caller gets a clean-looking run of the wrong thing, not a loud error.
        # The refusal comes BEFORE any write (the coo 2026-10-03, on the ceo's report that SncM's
        # trim_size_keyword_replace_1 would not extract): it wrote the program and its .ref first, so an rc=2
        # left exactly that stdin-starved witness on disk for a caller that read the files and not the rc.
        if e.stdin is not None and not args.out_in:
            refuse(f"{args.name!r} carries stdin ({len(e.stdin)} byte(s)) but --out-in was not given -- "
                   f"materializing it without stdin would silently grade a DIFFERENT witness than the "
                   f"one the suite actually graded (a stdin-starved run commonly still exits rc=0). "
                   f"Pass --out-in <path> and feed it to whatever runs {args.out_sno!r}.")
        text = e.sno_lines[0] if e.kind == "line" else "\n".join(e.sno_lines)
        Path(args.out_sno).write_text(text + "\n")
        if args.out_ref:
            ref_text = e.ref if e.kind == "line" else "\n".join(e.ref)
            Path(args.out_ref).write_text(ref_text + "\n")
        if e.stdin is not None:
            Path(args.out_in).write_text(e.stdin)
        if args.out_xfail and e.xfail_reason:
            Path(args.out_xfail).write_text(e.xfail_reason + "\n")
        _write_extracted_unit_sidecars(args.sno, e.name, args.out_sno)
        return
    refuse(f"no entry named {args.name!r} in {args.sno} (have: {', '.join(sorted(e.name for e in entries))})")


# ====================================================== declared arena ===
# ⛔⭐ THESE THREE MIRROR src/runtime/rt/gc_heap.c AND A GATE HOLDS THEM TO IT. They are not a style
# choice and they are not a guess: GC_HEAP_CAP_KB is the SHIPPED HARD CAP, GC_HEAP_KB_FLOOR the lowest
# window the runtime will accept, and GC_HEAP_KB_MAX the highest. A copy of a runtime constant that
# nothing checks is the false-label class this whole column exists to close, so
# test_gate_suite_runners_honour_the_tests_declared_memory.sh re-reads the #defines and reds on drift.
GC_HEAP_CAP_KB = 131072        # #define GC_HEAP_CAP_KB 131072 (SPITBOL -d128m, ceo CEO-1261)
GC_HEAP_KB_DEFAULT = 1024      # #define GC_HEAP_KB 1024 (SPITBOL -i1m): a declared maximum below the initial window is refused
GC_HEAP_KB_FLOOR = 64          # #define GC_HEAP_KB_FLOOR 64
GC_HEAP_KB_MAX = 4096 * 1024   # the ceiling SCRIP_HEAP_KB itself refuses past
GC_STACK_FLOOR_KB = 4 * 1024   # src/runtime/rt/rt_stack_overflow.c RT_STACK_DEFAULT_BYTES: SPITBOL's -s4m, the stack an undeclared program gets
GC_STACK_KB_MIN = 64           # the least stack a declaration may name
GC_STACK_KB_MAX = 4096 * 1024  # a declared stack past 4 GB is refused as a typo, never honoured


def heap_sidecar_path(sno_path):
    """The WRITE target for an extracted suite's arena declaration: <stem>.heap beside the pair, named the
    same way .in/.xfail are. ⛔⭐ THE SIDECAR IS NOT OPTIONAL POLISH. CEO-1127's evidence bar has every
    seat grading ENTRIES EXTRACTED STANDALONE, and an extracted entry has no sibling ALL.csv -- so a
    declaration that lived only in the csv would be silently dropped by exactly the workflow the fleet uses
    to cure, and a program that needs 16384 KB would abort in its own cure loop while passing on the board.
    Declaration travels with the entry or it is not a declaration."""
    return str(Path(sno_path).with_suffix(".heap"))


def validate_heap_kb(raw, where):
    """Parse ONE heap_kb cell into an int, or refuse rc=2 naming the cell. Returns None for the empty
    cell, which is the documented "absent means the shipped default" and is never an error.

    ⛔⭐⭐ A DECLARATION IS A NUMBER ABOVE THE COMPILED CAP OR IT IS NOT A DECLARATION (ceo CEO-1171, 2026-09-23, ruling on the coo's ask).
    Asked as a ruling rather than taken as one, because refusing is criterion-shaped and criterion-writing is
    not this seat's verb; it came back as law, so the floor below is not a local choice and may not be
    softened to a warning. The ruling's own words: warn-and-pass "would mint the false label CEO-1101 exists
    against."

    ⛔⭐⭐ A DECLARATION AT OR BELOW THE SHIPPED CAP IS REFUSED, AND THE REASON IS MEASURED, NOT REASONED.
    gc_heap.c reads `cap_kb = GC_HEAP_CAP_KB; if (cap_kb < kb) cap_kb = kb;` -- so SCRIP_HEAP_KB moves the
    INITIAL WINDOW always and the HARD CAP only once it climbs past GC_HEAP_CAP_KB. Measured by the coo
    2026-09-23 on one binary and one 60000-element Icon witness: SCRIP_HEAP_KB at 128, 2048 and 4096 all
    die rc=134 at a cap the runtime itself prints as 4096 KB, 4097 moves it to 4100, and 8192 completes
    rc=0. So a cell reading 2048 declares NOTHING ABOUT CAPACITY -- the program it names can reach 4096 KB
    with or without it -- while looking exactly like a capacity declaration to every reader downstream.
    That is the pin-the-runtime-overrides class COO-151 caught one instrument ago, and the baton's own
    guardrail (matched at that arena, NOT matched one step below) is unprovable for such a cell: one step
    below has the same cap, so both arms read the same and the "evidence" is vacuous. The cell is refused
    with this sentence rather than accepted as a silent no-op. A run that wants a SMALLER window than the
    default is asking for collection pressure, and CEO-1158's first clause already names the knob for
    that: STRESS, never the arena."""
    if raw is None:
        return None
    t = str(raw).strip()
    if not t:
        return None
    if not re.fullmatch(r"[0-9]+", t):
        refuse(f"{where}: heap_kb={t!r} is not a plain integer count of KB -- a declaration is a "
               f"measurement, and a cell this reader cannot parse is not one")
    v = int(t)
    if v < GC_HEAP_KB_DEFAULT:
        refuse(f"{where}: heap_kb={v} is below the {GC_HEAP_KB_DEFAULT} KB initial window and is REFUSED: heap_kb is the "
               f"program's MAXIMUM heap (SPITBOL -d, passed as -d{v}k) and a maximum under the window cannot be honoured. "
               f"CEO-1171's refusal of a cell at or below the shipped cap is retired on Lon's word of 2026-09-25 -- every "
               f"program declares its settings, and a declaration equal to the default is a setting (ceo CEO-1261)")
    if v > GC_HEAP_KB_MAX:
        refuse(f"{where}: heap_kb={v} is above the {GC_HEAP_KB_MAX} KB ceiling SCRIP_HEAP_KB itself "
               f"refuses -- the runtime would abort on this value rather than run at it")
    return v


def heap_declarations(sno_path):
    """{entry: declared arena in KB} for the suite at `sno_path`, plus the name of the evidence used.

    ⛔⭐ TWO SOURCES IN ONE ORDER, AND THE ORDER IS THE POINT: a `<stem>.heap` sidecar TRAVELS with an extracted family, a sibling `ALL.csv` only exists
    for a suite still sitting in the corpus. Returns ({}, None) when neither is reachable, which is an
    honest "nobody declared" and never a guess -- and an undeclared program runs at the shipped default,
    which is the whole point of the column being sparse.
    ⛔ AN ALL.csv WITH NO heap_kb COLUMN IS NOT AN ERROR HERE. It is a suite nobody has converted yet, and
    every one of its entries takes the shipped default -- the same verdict it got before this column
    existed. Only --by-heap-column, which asks to be graded BY the declaration, refuses on its absence."""
    _p = Path(heap_sidecar_path(sno_path))
    if _p.is_file():
        out = {}
        for ln, line in enumerate(_p.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            name, _, kb = line.partition("\t")
            v = validate_heap_kb(kb, f"{_p}:{ln}")
            if v is not None:
                out[name.strip()] = v
        if out:
            return out, _p.name
    _csv_path = Path(sno_path).parent / "ALL.csv"
    if _csv_path.is_file():
        import csv as _csvm
        out = {}
        try:
            with open(_csv_path, newline="") as _f:
                rdr = _csvm.DictReader(_f)
                if not rdr.fieldnames or "heap_kb" not in rdr.fieldnames:
                    return {}, None
                for _n, _row in enumerate(rdr, 2):
                    v = validate_heap_kb(_row.get("heap_kb"), f"{_csv_path}:{_n}")
                    if v is not None:
                        out[_row.get("entry")] = v
        except OSError:
            return {}, None
        if out:
            return out, _csv_path.name
    return {}, None



def stack_sidecar_path(sno_path):
    """<stem>.stack beside an extracted pair, the stack's twin of heap_sidecar_path (CEO-1225): the declaration travels with the
    entry, one line NAME<TAB>KB, or it is not a declaration."""
    return str(Path(sno_path).with_suffix(".stack"))


def validate_stack_kb(raw, where):
    """Parse ONE stack_kb cell into an int, or refuse rc=2 naming the cell; None for the empty cell (the shipped floor).

    ⛔⭐ THE FLOOR IS CEO-1171's RULE APPLIED TO THE STACK, AND HERE IT IS SHARPER THAN FOR THE HEAP. core.c raises RLIMIT_STACK at
    init to SCRIP_STACK when it is set and to 64 MB when it is not -- the variable REPLACES the floor -- so a cell at 16384 would
    run the program on a SMALLER stack than an undeclared neighbour, and a cell at 65536 changes nothing while reading as a
    declaration. Either way the label is false, so a declaration is a number above the runtime's floor or it is refused."""
    if raw is None:
        return None
    t = str(raw).strip()
    if not t:
        return None
    if not t.isdigit():
        refuse(f"{where}: stack_kb={t!r} is not a plain integer count of KB -- a declaration is a measurement, and a cell "
               f"no reader can parse is not one")
    v = int(t)
    if v < GC_STACK_KB_MIN:
        refuse(f"{where}: stack_kb={v} is below the {GC_STACK_KB_MIN} KB least stack a declaration may name. The default is "
               f"SPITBOL's -s4m ({GC_STACK_FLOOR_KB} KB) and a declaration equal to it is a setting, not a no-op -- every "
               f"program declares its settings on Lon's word of 2026-09-25 (ceo CEO-1261)")
    if v > GC_STACK_KB_MAX:
        refuse(f"{where}: stack_kb={v} is above the {GC_STACK_KB_MAX} KB ceiling a stack declaration may name")
    return v


def stack_declarations(sno_path):
    """{entry: declared stack in KB} for the suite at `sno_path`, and the name of the evidence -- heap_declarations' twin
    (CEO-1225), in the same order for the same reason: a travelling <stem>.stack sidecar first, then the sibling ALL.csv's
    stack_kb column. ({}, None) when neither declares anything: every entry runs at the runtime's floor, as before."""
    _p = Path(stack_sidecar_path(sno_path))
    if _p.is_file():
        out = {}
        for ln, line in enumerate(_p.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            name, _, kb = line.partition("\t")
            v = validate_stack_kb(kb, f"{_p}:{ln}")
            if v is not None:
                out[name.strip()] = v
        if out:
            return out, _p.name
    _csv_path = Path(sno_path).parent / "ALL.csv"
    if _csv_path.is_file():
        import csv as _csvm
        out = {}
        try:
            with open(_csv_path, newline="") as _f:
                rdr = _csvm.DictReader(_f)
                if not rdr.fieldnames or "stack_kb" not in rdr.fieldnames:
                    return {}, None
                for _n, _row in enumerate(rdr, 2):
                    v = validate_stack_kb(_row.get("stack_kb"), f"{_csv_path}:{_n}")
                    if v is not None:
                        out[_row.get("entry")] = v
        except OSError:
            return {}, None
        if out:
            return out, _csv_path.name
    return {}, None


# ⛔ A CLOSED ENUMERATION: the ORACLE's own size knobs a unit may declare beside itself (ceo CEO-1353, RULES.md clause 8 (g)(3): where the
# oracle needs more than its own default to answer a unit, the unit declares the oracle's knob verbatim, because the engines' needs and
# units differ). iconx reads MSTKSIZE BLKSIZE STRSIZE COEXPSIZE, gprolog GLOBALSZ LOCALSZ TRAILSZ CSTRSZ; a knob joins when an oracle
# is measured needing it. MEASURED 2026-09-28 (hq_icon): the Arizona-built JCON jtran dies run-time error 302 / rc 139 on 18 of the
# package's 20 modules at iconx's default co-expression size and runs all 20 under jcont's own COEXPSIZE=1000000.
ORACLE_ENV_ADMITTED = ("MSTKSIZE", "BLKSIZE", "STRSIZE", "COEXPSIZE", "GLOBALSZ", "LOCALSZ", "TRAILSZ", "CSTRSZ")


def oracle_env_sidecar_path(src_path):
    """<stem>.oracle_env beside a standalone unit: one line NAME<TAB>VAR=VALUE[ VAR=VALUE] -- the oracle's environment for that unit."""
    return str(Path(src_path).with_suffix(".oracle_env"))


def oracle_env_declarations(src_path):
    """The VAR=VALUE words the unit at `src_path` declares for its ORACLE's run, [] when it declares none (the oracle runs at its own
    defaults). Refuses rc=2 on a line naming another unit, a knob outside ORACLE_ENV_ADMITTED, a value that is not a positive
    integer, or a sidecar that declares nothing for this unit -- a declaration no reader can honour is not one."""
    _p = Path(oracle_env_sidecar_path(src_path))
    if not _p.is_file():
        return []
    stem = Path(src_path).stem
    words, seen = [], False
    for ln, line in enumerate(_p.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        name, _, rest = line.partition("\t")
        if name.strip() != stem:
            refuse(f"{_p}:{ln}: names {name.strip()!r}, not {stem!r} -- the sidecar's format is one line NAME<TAB>VAR=VALUE with "
                   f"NAME the unit's stem; another unit's line is not a declaration for this one")
        seen = True
        for w in rest.split():
            var, eq, val = w.partition("=")
            if not eq or var not in ORACLE_ENV_ADMITTED:
                refuse(f"{_p}:{ln}: {w!r} is not one of the oracle knobs a unit may declare ({' '.join(ORACLE_ENV_ADMITTED)}) -- "
                       f"a knob joins the list when an oracle is measured needing it")
            if not val.isdigit() or int(val) <= 0:
                refuse(f"{_p}:{ln}: {w!r} -- the value must be a positive integer in the engine's own unit")
            words.append(w)
    if not seen or not words:
        refuse(f"{_p}: declares no oracle environment for {stem!r} -- an empty declaration is not one")
    return words


# ⛔ A CLOSED ENUMERATION: the ORACLE's own size SWITCHES a unit may declare beside itself -- oracle_env's twin for an oracle sized on its
# command line (ceo CEO-1353, RULES.md clause 8 (g)(3): "oracle_args for sbl -d/-s, swipl --stack-limit, fpc -Cs/-Ch"). A switch joins
# when an oracle is measured needing it, as a knob joins ORACLE_ENV_ADMITTED. MEASURED 2026-10-03 (the coo, sbl md5 fd9b552b): the
# transpiled bootstrap parser chain dies ERROR 246 under sbl -bf at its default stack on the snocone, icon and pascal workhorse
# inputs and answers at -s8m, -s12m and -s12m; and sbl refuses -s128m and above alone ("Stack memory unavailable") and runs it beside a
# larger -d, so -d is the stack's room as well as the heap. sbl reads a size as digits with an optional k or m.
ORACLE_ARGS_ADMITTED = (("-s", "sbl stack"), ("-d", "sbl heap"))
# ...and the ORACLE's semantic FLAGS a unit may declare, matched whole with no size: an oracle MODE the ceo rules a unit is graded under
# (CEO-1540, 2026-10-07: the Prolog demo prolog_recognizer is graded against swipl --traditional, because SWI-7's distinct '[]' is the one
# difference and SCRIP keeps ISO and GNU's '[]' == []; its ref is cut from that run). A flag joins only on such a ruling, named here.
ORACLE_FLAGS_ADMITTED = (("--traditional", "swipl SWI-7 extensions off, CEO-1540"),)


def oracle_args_sidecar_path(src_path):
    """<stem>.oracle_args beside a standalone unit: one line NAME<TAB>SWITCH[ SWITCH] -- the oracle's command-line sizes (and any ruled flag) for that unit."""
    return str(Path(src_path).with_suffix(".oracle_args"))


def oracle_args_declarations(src_path):
    """The switches the unit at `src_path` declares for its ORACLE's command line, placed before the program, [] when it declares none
    (the oracle runs at its own defaults). Refuses rc=2 on a line naming another unit, a switch outside ORACLE_ARGS_ADMITTED, a size
    that is not digits with an optional k or m, a switch named twice, or a sidecar that declares nothing for this unit."""
    _p = Path(oracle_args_sidecar_path(src_path))
    if not _p.is_file():
        return []
    stem = Path(src_path).stem
    words, seen, named = [], False, set()
    for ln, line in enumerate(_p.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        name, _, rest = line.partition("\t")
        if name.strip() != stem:
            refuse(f"{_p}:{ln}: names {name.strip()!r}, not {stem!r} -- the sidecar's format is one line NAME<TAB>SWITCH with "
                   f"NAME the unit's stem; another unit's line is not a declaration for this one")
        seen = True
        for w in rest.split():
            if any(w == f for f, _ in ORACLE_FLAGS_ADMITTED):
                if w in named:
                    refuse(f"{_p}:{ln}: {w!r} is named a second time -- one declaration per flag")
                named.add(w)
                words.append(w)
                continue
            sw = next((p for p, _ in ORACLE_ARGS_ADMITTED if w.startswith(p)), None)
            if sw is None:
                refuse(f"{_p}:{ln}: {w!r} is not one of the oracle switches a unit may declare "
                       f"({' '.join(p for p, _ in ORACLE_ARGS_ADMITTED)} with a size, or the flag(s) {' '.join(f for f, _ in ORACLE_FLAGS_ADMITTED)}) "
                       f"-- a size switch joins the list when an oracle is measured needing it, a flag on a ceo ruling")
            if not re.fullmatch(r"[1-9][0-9]*[km]?", w[len(sw):]):
                refuse(f"{_p}:{ln}: {w!r} -- the size must be a positive integer with an optional k or m, as the oracle reads it")
            if sw in named:
                refuse(f"{_p}:{ln}: {w!r} names {sw} a second time -- one size per switch")
            named.add(sw)
            words.append(w)
    if not seen or not words:
        refuse(f"{_p}: declares no oracle switches for {stem!r} -- an empty declaration is not one")
    return words


# ⛔ A CLOSED ENUMERATION: the compile switches a unit may declare. A switch joins it when a unit needs it and the switch is
# proven honoured at the COMPILE step in both modes (hq_snobol4 2026-09-26 on 6974ab821: scrip --compile --stlimit and
# SCRIP_SNO_STMTKW=1 scrip --compile emit byte-identical .s, and neither turns counting on at a mode-4 binary's run).
# A runtime switch (-d -i -s -m -u) placed at the compile step would reach mode 3 and never a mode-4 binary.
# --dialect=gnu joins 2026-10-17 (cfo, row prolog-gnu-semantics-leak-...-ceo-1810): scrip --run --dialect=gnu and a binary from scrip --compile
# --dialect=gnu both read current_prolog_flag('$dialect', gnu) -- the lowerer bakes the directive into the program -- and the GNU tables declare it.
COMPILE_ARGS_ADMITTED = ("--stlimit", "--dialect=gnu")


def validate_out_files_cell(raw, where):
    """Parse ONE out_files cell into bare file names, or refuse rc=2 naming the cell; None for the empty cell. A name is a file
    in the unit's own run directory: no '/', no leading '.', no ALL.* container, so the run can only delete and read files the
    staging directory owns."""
    words = validate_args_cell(raw, "out_files", where)
    for w in words or []:
        if "/" in w or w.startswith(".") or w.startswith("ALL."):
            refuse(f"{where}: out_files names {w!r} -- a bare file name in the unit's own run directory only")
    return words


def validate_compare_cell(raw, where):
    """ONE compare cell: empty = byte for byte (every table before the column existed); "ignore-all-space" = each line compared with its white
    space removed, as `diff -w` compares (XSB's gentest.sh, CEO-1927). Anything else refuses rc=2 naming the cell."""
    v = (raw or "").strip()
    if v == "":
        return False
    if v == "ignore-all-space":
        return True
    if v and set(v.split("+")) <= {"fresh-vars", "error-context", "ignore-all-space"}:
        return v
    refuse(f"{where}: compare cell {v!r} -- the column admits the empty cell or a '+'-joined set of ignore-all-space, fresh-vars, error-context")


def validate_stage_cell(raw, where):
    """ONE stage cell: empty = the entry runs alone in a fresh directory with its named companions (every table before the column existed);
    "upstream" = the run directory is staged as the entry's upstream test directory (stage_upstream, CEO-1927). Anything else refuses rc=2."""
    v = (raw or "").strip()
    if v == "":
        return False
    if v == "upstream":
        return True
    refuse(f"{where}: stage cell {v!r} -- the column admits the empty cell or 'upstream' only")


def validate_answer_cell(raw, where):
    """ONE answer cell: empty = stdout is the answer; "temp-sorted" = the file temp the program writes, its non-empty lines sorted, as XSB's
    gentest.sh grades it (CEO-1927). Anything else refuses rc=2."""
    v = (raw or "").strip()
    if v == "":
        return False
    if v == "temp-sorted":
        return True
    refuse(f"{where}: answer cell {v!r} -- the column admits the empty cell or 'temp-sorted' only")


def stage_upstream(companion_dir, name, td, ext):
    """THE RUN DIRECTORY AS THE PROGRAM'S UPSTREAM TEST DIRECTORY (the coo 2026-10-23, ceo CEO-1927): a flat package vendors each upstream file under a
    prefixed name (xsb_tests: <dir>_<path>_<stem>.pl), so a program that loads a sibling by its UPSTREAM name -- `:- [fd].`, wfs_test.P's consult(P),
    load_dyn('type0_testdir/initialization_file.P') -- finds nothing beside it. SOURCES.tsv maps each vendored name to its upstream path; every vendored
    file of the entry's top-level test directory is written under td at its path below that directory, as <stem>.pl (SCRIP's consult finds a .pl,
    not XSB's .P) and under its own upstream name, its vendoring's appended driver cut off (it would run again on a load). Returns the directory,
    below td, the entry runs in: its own upstream directory, so relative paths resolve as they do upstream. None when SOURCES.tsv does not name it."""
    src = {}
    for ln in (Path(companion_dir) / "SOURCES.tsv").read_text(encoding="utf-8", errors="replace").splitlines():
        c = ln.split("\t")
        if len(c) >= 3 and "/" in c[2]:
            src[c[0]] = c[2]
    mine = src.get(name)
    if not mine:
        return None
    parts = mine.split("/")
    pre = "/".join(parts[:3])            # xsb/xsbtests/<top>
    for n, up in src.items():
        if not up.startswith(pre + "/"):
            continue
        f = Path(companion_dir) / f"{n}{ext}"
        if not f.is_file():
            continue
        t = f.read_text(encoding="utf-8", errors="replace")
        cut = t.find("\n% DRIVER (appended by the vendoring")
        if cut >= 0:
            t = t[:cut + 1]
        rel = up[len(pre) + 1:]
        for dst in {Path(td) / rel, (Path(td) / rel).with_suffix(".pl")}:
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_text(t, encoding="utf-8")
    # ⭐ THE DATA A PROGRAM READS BY ITS UPSTREAM PATH (the coo 2026-10-23, CEO-1926): a file that is no Prolog source -- json_tests' data/*.json,
    # prolog_tests' format_tests/format.tst and utf8.txt -- is vendored under the package's upstream/<top>/ at its path below the test directory
    # and written there byte for byte (a CR-LF fixture keeps its CRs), so parse_json('data/test1.json') opens it as XSB's own run does.
    dd = Path(companion_dir) / "upstream" / parts[2]
    if dd.is_dir():
        for f in sorted(dd.rglob("*")):
            if f.is_file():
                dst = Path(td) / f.relative_to(dd)
                dst.parent.mkdir(parents=True, exist_ok=True)
                dst.write_bytes(f.read_bytes())
    return Path(td) / Path(mine[len(pre) + 1:]).parent


def validate_stderr_cell(raw, where):
    """ONE stderr cell: empty = stdout alone is the answer (every table before the column existed); "merged" = stdout and stderr
    as one stream. Anything else refuses rc=2 naming the cell -- a contract word the reader does not know is never guessed."""
    v = (raw or "").strip()
    if v == "":
        return False
    if v == "merged":
        return True
    refuse(f"{where}: stderr cell {v!r} -- the column admits the empty cell or 'merged' only")


def _out_files_clear(cwd, names):
    for n in names or []:
        (Path(cwd) / n).unlink(missing_ok=True)


def _out_files_append(out, cwd, names):
    for n in names or []:
        f = Path(cwd) / n
        out += f.read_bytes() if f.is_file() else f"<<out_files: {n} was not written>>\n".encode()
    return out


def validate_args_cell(raw, col, where):
    """Parse ONE compile_args or run_args cell into its words, or refuse rc=2 naming the cell; None for the empty cell
    (nothing declared: byte-identical to the run before the column existed). RULES.md hard-cap rule clause 8 (f), ceo
    CEO-1281: the command line a test unit needs is stored with it, and the runner types none of its own.
    ⛔ SPACE-SEPARATED WORDS, NO QUOTING LANGUAGE: a comma, a quote or a tab is refused, because the positional readers
    (lib_rungs_extract.sh, board_denominators.sh) split rows on commas. Censused 2026-09-26 over the 68 argv declarations
    in 63 sidecars: no argument holds a space, a comma or a quote, so the rule loses nothing today, and an argument that
    ever needs one is refused here rather than split wrong."""
    if raw is None:
        return None
    t = str(raw).strip()
    if not t:
        return None
    for c in (",", '"', "'", "\t"):
        if c in t:
            refuse(f"{where}: {col}={t!r} holds {c!r} -- a cell is space-separated words with no quoting language, "
                   f"and a cell no reader can split one way is not a declaration")
    words = t.split()
    if col == "compile_args":
        for w in words:
            if w not in COMPILE_ARGS_ADMITTED:
                refuse(f"{where}: compile_args word {w!r} is not a compile switch a unit may declare "
                       f"({', '.join(COMPILE_ARGS_ADMITTED)}) -- heap and stack are heap_kb and stack_kb, the program's own "
                       f"arguments are run_args, and a switch joins the list once it is proven honoured at the compile step "
                       f"in both modes")
    return words


def cmdline_sidecar_path(sno_path):
    """<stem>.cmdline beside an extracted pair or a standalone program: the command line's twin of heap_sidecar_path (clause 8 (f),
    CEO-1281, landing 4 of 5). One line per unit, NAME<TAB>compile_args<TAB>run_args, either cell empty, each cell in
    validate_args_cell's grammar. A unit with no ALL.csv row -- a demo, a benchmark kernel, an extracted entry -- carries its
    command line here or it declares none. ⛔ NOT .args, WHICH WAS TAKEN: Icon's <name>.args is already a program's argv (the jcon
    runner, bench_triangulate_demos_icon.sh, util_icon_ref_provenance.sh; CEO-609 moves argv to .argv), and a second format under
    one name would hand an argv reader a declaration and this reader an argv (coo 2026-09-26, found by landing 5's corpus census:
    jcon_tests/link1.args holds `a b c`)."""
    return str(Path(sno_path).with_suffix(".cmdline"))


def cmdline_declarations(sno_path):
    """({unit: (compile_args words or None, run_args words or None)}, the sidecar's name) from the <stem>.cmdline beside `sno_path`;
    ({}, None) when there is none or it declares nothing. ⛔ A LINE WITH NO NAME, OR ONE UNIT NAMED TWICE, IS REFUSED rc=2: a
    declaration no reader can attribute is not a declaration, and two lines for one unit are two answers to one question."""
    _p = Path(cmdline_sidecar_path(sno_path))
    if not _p.is_file():
        return {}, None
    out = {}
    for ln, line in enumerate(_p.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        where = f"{_p}:{ln}"
        name, _, rest = line.partition("\t")
        ca_raw, _, ra_raw = rest.partition("\t")
        name = name.strip()
        if not name:
            refuse(f"{where}: a command-line declaration names no unit")
        if name in out:
            refuse(f"{where}: {name} is declared twice in {_p.name} -- one unit, one command line")
        out[name] = (validate_args_cell(ca_raw, "compile_args", where), validate_args_cell(ra_raw, "run_args", where))
    return out, (_p.name if out else None)


def read_command_line_columns(src_path, entries, modes=None):
    """Attach the compile_args and run_args columns of the ALL.csv beside a suite to its entries BY NAME: the ONE reader of
    a test unit's command line for the rung suites and the package tables (clause 8 (f), CEO-1281). compile_args are applied at
    the compile step in both modes (scrip --run in m3, scrip --compile in m4); run_args are the program's own argv after
    `--`, both modes, carried in entry.argv exactly as a <family>.argv declaration is.
    ⛔ AN ENTRY DECLARED IN BOTH PLACES IS REFUSED: the column is the declaration and the argv sidecars fold into it, so two
    declarations of one entry are two answers to one question. ⛔ run_args on a family graded in ast mode only is refused
    for the reason read_argv_sidecar gives: --dump-ast never runs the program. An ALL.csv with neither column, or empty
    cells, changes nothing.
    ⭐ AN EXTRACTED PAIR HAS NO ALL.csv, SO ITS COMMAND LINE TRAVELS IN <stem>.cmdline (extract-family writes it, heap_declarations'
    order for heap_kb's reason, CEO-1127): read first, by name; a unit it names that ALL.csv also declares is refused."""
    by_name = {e.name: e for e in entries}
    side, side_name = cmdline_declarations(src_path)
    for name, (ca, ra) in side.items():
        e = by_name.get(name)
        if e is None:
            continue
        where = f"{cmdline_sidecar_path(src_path)}:{name}"
        if ca:
            e.compile_args = ca
        if ra:
            if e.argv:
                refuse(f"{where}: {name} declares run_args {ra} in {side_name} AND {e.argv} in its argv sidecar -- one declaration")
            if modes is not None and not ({"m3", "m4"} & set(modes)):
                refuse(f"{where}: {name} declares run_args, and this family is graded in {sorted(modes)} only -- "
                       f"--dump-ast never RUNS the program, so the arguments could not reach it")
            e.argv = ra
    csv_path = Path(src_path).parent / "ALL.csv"
    if not csv_path.is_file():
        return
    import csv as _csvm
    with open(csv_path, newline="") as f:
        rdr = _csvm.DictReader(f)
        cols = [c for c in ("compile_args", "run_args", "out_files", "stderr") if rdr.fieldnames and c in rdr.fieldnames]
        if not cols:
            return
        rows = [(n, r) for n, r in enumerate(rdr, 2)]
    for n, row in rows:
        e = by_name.get(row.get("entry"))
        if e is None:
            continue
        where = f"{csv_path}:{n}"
        if e.name in side and (validate_args_cell(row.get("compile_args"), "compile_args", where) or validate_args_cell(row.get("run_args"), "run_args", where)):
            refuse(f"{where}: {e.name} declares its command line in ALL.csv AND in {side_name} -- two answers to one question")
        ca = validate_args_cell(row.get("compile_args"), "compile_args", where)
        if ca:
            e.compile_args = ca
        ra = validate_args_cell(row.get("run_args"), "run_args", where)
        if ra:
            if e.argv:
                refuse(f"{where}: {e.name} declares run_args {ra} in ALL.csv AND {e.argv} in its argv sidecar -- the column "
                       f"is the declaration; delete the sidecar line")
            if modes is not None and not ({"m3", "m4"} & set(modes)):
                refuse(f"{where}: {e.name} declares run_args, and this family is graded in {sorted(modes)} only -- "
                       f"--dump-ast never RUNS the program, so the arguments could not reach it")
            e.argv = ra
        of = validate_out_files_cell(row.get("out_files"), where)
        if of:
            e.out_files = of
        if validate_stderr_cell(row.get("stderr"), where):
            e.merge_stderr = True
        _cmp = validate_compare_cell(row.get("compare"), where)
        if _cmp:
            e.compare_ws = _cmp
        if validate_stage_cell(row.get("stage"), where):
            e.stage_upstream = True
        if validate_answer_cell(row.get("answer"), where):
            e.answer_file = "temp"


def cmd_extract_family(args):
    """Materialize every entry of ONE family back out as a standalone SUITE PAIR (still banner-block or
    one-line, matching the rungs' own format) rather than loose individual files -- the bridge for a
    gate that grades a whole suite via `run` the way an old per-family suite file did, before the
    one-flat-suite cutover retired per-family files (corpus-suites-consolidation.task.md, THE ONE-FLAT-
    SUITE RULING). Family membership comes from the rungs' OWN CSV (the `family` column), never
    re-derived from a name convention -- entries carry no origin/family field once round-tripped through
    plain suite text, and the family-prefix-in-the-name shape is a naming CONVENTION this row's own
    output uses, not a guarantee every consumer may assume (a descriptive rename could break it silently
    -- see util_build_rungs_suite.py's own descriptive_name(), which never consults the CSV either).
    ⛔⭐ CARRIES STDIN + XFAIL, BOTH WAYS (seat07 2026-08-30, on hq_C's law: "a check that does not carry
    every field the grader reads is not a check"). The first version of this command read and wrote body
    text only, silently dropping any entry's stdin sidecar -- the identical hole hq_C found and fixed in
    util_build_rungs_suite.py's deletion verifier the same night (SCRIP 4cc1ccbb), independently hit here
    because extraction is its own round trip with its own read and its own write."""
    import csv as _csv
    with open(args.csv, newline="") as f:
        wanted = {row["entry"] for row in _csv.DictReader(f) if row["family"] == args.family}
    if not wanted:
        refuse(f"no rows with family=={args.family!r} in {args.csv}")
    _ext = Path(args.sno).suffix
    _copen, _cclose = "*", ""
    for _lc in LANG_CONFIGS.values():
        if _lc.get("ext") == _ext:
            _copen, _cclose = _lc.get("comment_open", "*"), _lc.get("comment_close", "")
            break
    # ⛔ sidecar_in_path()/sidecar_xfail_path() are DISCOVERY functions -- they return None unless the
    # candidate file ALREADY EXISTS, which is right for locating an existing sidecar to READ and wrong
    # for naming one to WRITE (at this point args.out_sno has not been created yet, so the candidate
    # can never exist and the discovery form would always hand back None). Compute the WRITE targets
    # the same way those functions do internally (<stem>.in / <stem>.xfail beside the output), not via
    # the discovery wrapper.
    _in, _x = sidecar_in_path(args.sno), sidecar_xfail_path(args.sno)
    try:
        entries = read_block_suite(args.sno, args.ref, banner_re_for(_copen, _cclose), in_path=_in, x_path=_x)
        is_block = True
    except Exception:
        entries = read_suite(args.sno, args.ref, in_path=_in, x_path=_x)
        is_block = False
    sel = [e for e in entries if e.name in wanted]
    if len(sel) != len(wanted):
        got = {e.name for e in sel}
        refuse(f"family {args.family!r}: CSV names {len(wanted)} entries, matched {len(sel)} in {args.sno} "
               f"(missing: {sorted(wanted - got)[:5]})")
    out_in, out_x = str(Path(args.out_sno).with_suffix(".in")), str(Path(args.out_sno).with_suffix(".xfail"))
    if is_block:
        write_block_suite(sel, args.out_sno, args.out_ref, _copen, _cclose)
    else:
        write_suite(sel, args.out_sno, args.out_ref)
    # ⭐ SAME PATTERN AS util_build_rungs_suite.py's main() write path, deliberately not
    # write_block_suite's own out_in=/out_x= parameters: mirroring the one place this sidecar-write-
    # plus-cleanup dance is already proven correct, rather than trusting write_block_suite's internal
    # handling (which writes when told to but does not clean up a stray existing file if nothing new
    # needs writing) to behave identically.
    if not write_stdin_sidecar(sel, out_in, _copen, _cclose) and os.path.exists(out_in):
        os.remove(out_in)
    if not write_xfail_sidecar(sel, out_x, _copen, _cclose) and os.path.exists(out_x):
        os.remove(out_x)
    # ⛔⭐⭐ AND SO DOES heap_kb. CEO-1127's evidence bar has every one of the
    # ten seats grading ENTRIES EXTRACTED STANDALONE -- that is the whole reason a seat can clear its lane
    # without taking the box from the other nine. An extracted pair has no sibling ALL.csv, so a declaration
    # left behind here would mean a program that needs 16384 KB runs at the shipped 128 in EXACTLY the
    # workflow the fleet cures in, while passing on the board it is published from. The two arms would then
    # disagree for a reason neither arm names, and the seat would be handed a phantom capacity red in its own
    # cure loop. Written for the SELECTED entries only, same population as the modes sidecar above, and only
    # when at least one of them actually declares -- an all-empty sidecar is noise that reads like evidence.
    _heap_sel = {}
    with open(args.csv, newline="") as _cf:
        for _r in _csv.DictReader(_cf):
            _v = (_r.get("heap_kb") or "").strip()
            if _v:
                _heap_sel[_r["entry"]] = _v
    _mine = [(_e.name, _heap_sel[_e.name]) for _e in sel if _e.name in _heap_sel]
    if _mine:
        with open(heap_sidecar_path(args.out_sno), "w", encoding="utf-8") as _hf:
            _hf.write("# heap_kb declaration carried out of %s by extract-family (family=%s). entry<TAB>KB.\n"
                      % (Path(args.csv).name, args.family))
            for _n, _v in _mine:
                _hf.write("%s\t%s\n" % (_n, _v))
    elif os.path.exists(heap_sidecar_path(args.out_sno)):
        os.remove(heap_sidecar_path(args.out_sno))
    # ⭐ AND stack_kb TRAVELS THE SAME WAY (CEO-1225): an extracted pair carries its stack declaration in <stem>.stack.
    _stack_sel = {}
    with open(args.csv, newline="") as _cf:
        for _r in _csv.DictReader(_cf):
            _v = (_r.get("stack_kb") or "").strip()
            if _v:
                _stack_sel[_r["entry"]] = _v
    _mine = [(_e.name, _stack_sel[_e.name]) for _e in sel if _e.name in _stack_sel]
    if _mine:
        with open(stack_sidecar_path(args.out_sno), "w", encoding="utf-8") as _sf:
            _sf.write("# stack_kb declaration carried out of %s by extract-family (family=%s). entry<TAB>KB.\n"
                      % (Path(args.csv).name, args.family))
            for _n, _v in _mine:
                _sf.write("%s\t%s\n" % (_n, _v))
    elif os.path.exists(stack_sidecar_path(args.out_sno)):
        os.remove(stack_sidecar_path(args.out_sno))
    # ⭐ AND THE COMMAND LINE (clause 8 (f), CEO-1281): compile_args and run_args travel in <stem>.cmdline, NAME<TAB>compile_args<TAB>
    # run_args, which read_command_line_columns reads first for a pair with no ALL.csv.
    _cmd_sel = {}
    with open(args.csv, newline="") as _cf:
        for _n, _r in enumerate(_csv.DictReader(_cf), 2):
            _ca = validate_args_cell(_r.get("compile_args"), "compile_args", f"{args.csv}:{_n}")
            _ra = validate_args_cell(_r.get("run_args"), "run_args", f"{args.csv}:{_n}")
            if _ca or _ra:
                _cmd_sel[_r["entry"]] = (" ".join(_ca or []), " ".join(_ra or []))
    _mine = [(_e.name, _cmd_sel[_e.name]) for _e in sel if _e.name in _cmd_sel]
    if _mine:
        with open(cmdline_sidecar_path(args.out_sno), "w", encoding="utf-8") as _af:
            _af.write("# command line carried out of %s by extract-family (family=%s). entry<TAB>compile_args<TAB>run_args.\n"
                      % (Path(args.csv).name, args.family))
            for _n, (_ca, _ra) in _mine:
                _af.write("%s\t%s\t%s\n" % (_n, _ca, _ra))
    elif os.path.exists(cmdline_sidecar_path(args.out_sno)):
        os.remove(cmdline_sidecar_path(args.out_sno))


def _write_extracted_unit_sidecars(suite_sno, entry_name, out_sno):
    """The four attributes of ONE extracted unit, written beside it under the name the standalone readers look up -- the
    output's own stem, since lib_declared_arena.sh's *_beside readers key a sidecar by the program beside it: <stem>.heap and
    <stem>.stack (NAME<TAB>KB) and <stem>.cmdline (NAME<TAB>compile_args<TAB>run_args), each only when the unit's ALL.csv row
    declares it. ⛔⭐ CEO-1127: an entry extracted standalone is how every seat cures, and a declaration left behind grades a
    different program -- rungs entry 1991 declares --stlimit, 131072 KB and 4096 KB, and extract carried none of the three
    (coo 2026-09-26, measured). A stale sidecar is removed only when an extract wrote it (its first line says so)."""
    import csv as _csvm
    csv_path = Path(suite_sno).parent / "ALL.csv"
    row, where = None, ""
    if csv_path.is_file():
        with open(csv_path, newline="") as f:
            for n, r in enumerate(_csvm.DictReader(f), 2):
                if r.get("entry") == entry_name:
                    row, where = r, f"{csv_path}:{n}"
                    break
    stem = Path(out_sno).stem
    kb = validate_heap_kb(row.get("heap_kb"), where) if row else None
    st = validate_stack_kb(row.get("stack_kb"), where) if row else None
    ca = validate_args_cell(row.get("compile_args"), "compile_args", where) if row else None
    ra = validate_args_cell(row.get("run_args"), "run_args", where) if row else None
    mark = "# carried out of %s by extract (entry %s)." % (csv_path.name, entry_name)
    for path, body in ((heap_sidecar_path(out_sno), None if kb is None else "%s\t%s" % (stem, kb)),
                       (stack_sidecar_path(out_sno), None if st is None else "%s\t%s" % (stem, st)),
                       (cmdline_sidecar_path(out_sno), None if not (ca or ra) else "%s\t%s\t%s" % (stem, " ".join(ca or []), " ".join(ra or [])))):
        if body is not None:
            Path(path).write_text(mark + "\n" + body + "\n", encoding="utf-8")
        elif os.path.exists(path) and Path(path).read_text(encoding="utf-8", errors="replace").startswith("# carried out of "):
            os.remove(path)


# ====================================================== stored partitions ===
# ⛔⭐⭐ A SUBSET IS LOOKED UP BY NAME, NEVER QUERIED (Lon 2026-10-11 13:0x CDT, in-chat to the ceo, verbatim: "subsets need to be identified
# independent of a query against the attribute file for the long running test suites. So to partition them as major cores, and shells around
# that core with each major feature broken out."; ceo CEO-1676; RULES.md ONE TESTING OFFICER clause 9; ARCH-SUITE-PARTITIONS.md). Every suite
# table carries PARTITION.tsv beside it (util_suite_partition.py build, gated current): entry, part (core | chunk:NN), cluster, shells (the
# distinctive features the entry marks). These read it and nothing else: `run --partition NAME` grades exactly that subset, and the
# `partition` verb prints the selection and runs nothing. A partition is never the suite: its SUITE_BOARD carries partition=NAME, which the
# score writer refuses as a suite row, and each progress row carries it in its note and its config (row (d): the record shows the loop's shape).
def partition_path_for(suite_path):
    """The stored partition beside a suite file (ALL.<ext> or ALL.csv): the same directory's PARTITION.tsv."""
    return Path(suite_path).resolve().parent / "PARTITION.tsv"


def read_partition(suite_path):
    """(path, [(entry, part, cluster, [shell features])]) in file order; refuses rc=2 when there is no partition or its header is not
    util_suite_partition.py's."""
    p = partition_path_for(suite_path)
    if not p.is_file():
        refuse(f"no stored partition beside {suite_path}: {p} is missing -- build it with ../harness/scripts/util_suite_partition.py build <ALL.csv> "
               f"(CEO-1676)")
    hdr, rows = None, []
    for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        f = line.split("\t")
        if hdr is None:
            hdr = f
            continue
        rows.append((f[0], f[1] if len(f) > 1 else "", f[2] if len(f) > 2 else "", f[3].split() if len(f) > 3 else []))
    if not hdr or hdr[:2] != ["entry", "part"]:
        refuse(f"{p}: the header is {hdr!r}, not util_suite_partition.py's (entry, part, cluster, shells) -- rebuild it")
    if not rows:
        refuse(f"{p} names no entry")
    return p, rows


def select_partition(suite_path, name):
    """A comma-separated list of names is their UNION in partition order, its canonical name the parts joined by '+' (the loop's tier 2
    grades core plus each shell a landing's diff marks in one run: partition=core+shell:FENCE+shell:SPAN)."""
    names = [n for n in (name or "").split(",") if n.strip()]
    if len(names) > 1:
        canons, want, n_all, path = [], set(), 0, None
        for nm in names:
            c, sel, n_all, path = select_one_partition(suite_path, nm)
            canons.append(c)
            want.update(sel)
        _p, rows = read_partition(suite_path)
        canon = "entries:%d" % len(canons) if all(c.startswith("entry:") for c in canons) else "+".join(canons)
        return canon, [r[0] for r in rows if r[0] in want], n_all, path
    return select_one_partition(suite_path, name)


def select_one_partition(suite_path, name):
    """(canonical name, [entry names in partition order], n entries in the partition, path) for core | shell:<feature> | chunk:NN.
    A chunk is named by its number (chunk:3 and chunk:03 are one chunk; the canonical spelling is the file's). A shell names a DISTINCTIVE
    feature as the attribute table spells it; a feature no entry's shells carry refuses with the vocabulary (a ubiquitous feature is the
    core's by definition, ARCH-SUITE-PARTITIONS.md section 2). An empty selection refuses: a subset that grades nothing is not a run."""
    p, rows = read_partition(suite_path)
    nm = (name or "").strip()
    if nm == "core":
        canon, sel = "core", [r[0] for r in rows if r[1] == "core"]
    elif nm.startswith("chunk:"):
        try:
            k = int(nm[len("chunk:"):])
        except ValueError:
            refuse(f"--partition {nm!r}: a chunk is named chunk:NN")
        chunks = sorted({r[1] for r in rows if r[1].startswith("chunk:")}, key=lambda c: int(c[len("chunk:"):] or 0))
        hit = [c for c in chunks if int(c[len("chunk:"):] or 0) == k]
        if not hit:
            refuse(f"--partition {nm}: {p} has {len(chunks)} chunk(s): {', '.join(chunks)}")
        canon, sel = hit[0], [r[0] for r in rows if r[1] == hit[0]]
    elif nm.startswith("entry:"):
        # ⭐ ONE NAMED TEST (ceo CEO-1806, Lon 2026-10-15: "The COO will have two work inputs, the round-robin and the recently requested from other
        # officers and HQ's."): a seat's request names its tests, and each is one entry of the stored partition (so a stale name refuses here).
        ent = nm[len("entry:"):]
        if ent not in {r[0] for r in rows}:
            refuse(f"--partition {nm}: {p} has no entry {ent!r}")
        canon, sel = nm, [ent]
    elif nm.startswith("shell:"):
        feat = nm[len("shell:"):]
        canon, sel = f"shell:{feat}", [r[0] for r in rows if feat in r[3]]
        if not sel:
            vocab = sorted({f for r in rows for f in r[3]})
            refuse(f"--partition {nm}: no entry of {p} carries {feat!r} in its shells; the distinctive features ({len(vocab)}): "
                   f"{' '.join(vocab)}")
    else:
        refuse(f"--partition wants core | shell:<feature> | chunk:NN | entry:<name>, got {name!r}")
    if not sel:
        refuse(f"--partition {canon}: {p} selects zero of its {len(rows)} entries")
    return canon, sel, len(rows), p


def cmd_partition(args):
    """THE SELECTION VERB (CEO-1676 row (a)): print PARTITION <name>: <k> of <n> entries for a suite's stored partition, and with --list
    the names one per line; runs nothing, appends nothing, writes nothing. Without --name it prints every part: the core, each chunk, and
    the shells' sizes. The entry set is checked against the suite's own ALL.csv when one sits beside it, so a stale partition refuses here
    as the gate (test_gate_suite_partitions_are_current.sh) refuses it."""
    import collections
    p, rows = read_partition(args.suite)
    csvp = Path(args.suite).resolve().parent / "ALL.csv"
    if csvp.is_file():
        import csv as _csv
        with open(csvp, encoding="utf-8", errors="replace", newline="") as f:
            names = [r.get("entry", "") for r in _csv.DictReader(f)]
        a, b = set(names) - {""}, {r[0] for r in rows}
        if a != b:
            refuse(f"{p} is STALE against {csvp}: {len(a - b)} entr(y/ies) of the table are in no part ({', '.join(sorted(a - b)[:5])}), "
                   f"{len(b - a)} in the partition are not in the table ({', '.join(sorted(b - a)[:5])}) -- run ../harness/scripts/util_suite_partition.py "
                   f"build {csvp} (CEO-1676: a landing that changes a suite table rebuilds its partition)")
    if not args.name:
        parts = collections.Counter(r[1] for r in rows)
        for part in sorted(parts, key=lambda c: (c != "core", int(c[len("chunk:"):]) if c.startswith("chunk:") else 0)):
            print(f"PARTITION {part}: {parts[part]} of {len(rows)} entries")
        shells = collections.Counter(f for r in rows for f in r[3])
        print(f"PARTITION_SHELLS {len(shells)}: " + " ".join(f"{f}={n}" for f, n in sorted(shells.items())))
        return
    canon, sel, n, _p = select_partition(args.suite, args.name)
    print(f"PARTITION {canon}: {len(sel)} of {n} entries ({p})")
    if args.list:
        for e in sel:
            print(e)


# ================================================================ area smoke ===
# THE AREA SMOKE (Lon 2026-09-27, verbatim: "So if you change the SPAN function, then run every program that has SPAN as a
# reference. That is one of the columns in the attribute file."; ceo CEO-1342; RULES.md section ONE TESTING OFFICER, ONE SCORE
# BOARD, THE AREA SMOKE clause 4; the coo's row instruments-the-area-smoke-...-ceo-1342). The per-landing arm every seat runs
# INSTEAD of a suite: the rungs and package entries whose ATTRIBUTE ROW marks a named feature, read through THIS one reader,
# run in both modes with each entry's declared heap_kb / stack_kb / compile_args / run_args / out_files, the population
# printed by name beside the verdict.
# ⛔ IT IS NOT A BOARD AND IT NEVER BECOMES ONE: it calls no one-runner guard because it needs none -- it appends NO progress
# row and writes NO score cell (CEO-547's definition of a run that publishes nothing), and the code below has no path to
# _progress_record. A seat that wants a suite number reads the coo's SUITE TABLE row (clause 2).
# ⛔ THE VOCABULARY IS THE TABLES' OWN COLUMN NAMES, no taxonomy of this file's: a feature column is a 0/1 column of ALL.csv
# past the attribute columns (a text column such as inriasuite's section/kind/err is an attribute, not a feature). A named
# feature no table knows REFUSES rc=2 naming it; a selection of zero entries REFUSES rc=2 (a smoke that grades nothing is
# not a verdict); a table with feature columns but no suite file beside them is PRINTED as not runnable, never silently
# skipped. An xfail entry and an entry on the sibling ALL.outside.tsv are excluded from the run and named as excluded.
_SMOKE_ATTRIBUTE_COLUMNS = frozenset(("rank", "entry", "origin", "family", "kind", "xfail", "n_lines", "package", "stdin",
                                      "want_rc", "heap_kb", "stack_kb", "compile_args", "run_args", "out_files", "stderr"))


def smoke_tables(corpus_root):
    """Every attribute table the smoke can see, in a fixed order: [(key, csv_path, suite_path_or_None, lang)]. key is the
    table's directory relative to corpus/ (tests/icon, packages/snobol4/gimpel). lang is the corpus directory name; the
    SNOBOL4 family (snobol4 tables, whose suite is ALL.sno) reads through read_suite, every other through read_block_suite."""
    out = []
    cr = Path(corpus_root)
    dirs = sorted(cr.glob("tests/*")) + sorted(cr.glob("packages/*/*"))
    for d in dirs:
        csv_path = d / "ALL.csv"
        if not csv_path.is_file():
            continue
        rel = d.relative_to(cr).as_posix()
        lang = rel.split("/")[1]
        ext = ".sno" if lang not in LANG_CONFIGS else LANG_CONFIGS[lang]["ext"]
        suite = d / ("ALL" + ext)
        out.append((rel, csv_path, suite if suite.is_file() else None, lang))
    return out


def smoke_feature_columns(csv_path):
    """(feature_columns, rows) of one attribute table: the columns past the attribute set whose every cell is 0, 1 or empty."""
    import csv as _csvm
    with open(csv_path, newline="") as f:
        rdr = _csvm.DictReader(f)
        fields = list(rdr.fieldnames or [])
        rows = list(rdr)
    feats = []
    for c in fields:
        if not c or c in _SMOKE_ATTRIBUTE_COLUMNS:
            continue
        if all((r.get(c) or "").strip() in ("0", "1", "") for r in rows):
            feats.append(c)
    return feats, rows


def smoke_select(corpus_root, features, only_tables=None):
    """The selection: {key: {"csv":..., "suite":..., "lang":..., "features": [known here], "entries": [names], "xfail": [names],
    "rows": N}} for every table, plus the set of features no table knows. Pure reading -- nothing runs."""
    # ⭐ A FEATURE MAY BE QUALIFIED BY ITS LANGUAGE, <lang>:<column> (hq_prolog 2026-09-28: a Prolog landing's `write`, `sort`, `list`
    # and `read` selected Icon's and Raku's columns of the same name and read their standing reds -- one word, two languages, two
    # meanings). A qualified token selects that column only in the tables of that language (tests/<lang>, packages/<lang>/*); a
    # plain token selects it in every table that carries it -- right for a box several frontends share (SPAN in SNOBOL4, Snocone,
    # Rebus). test_area_smoke.sh expands a lang:<x> carrier row to qualified tokens.
    want = list(dict.fromkeys(features))
    plain = [f for f in want if ":" not in f]
    qual = [tuple(f.split(":", 1)) for f in want if ":" in f]
    known = set()
    sel = {}
    for key, csv_path, suite, lang in smoke_tables(corpus_root):
        if only_tables and not any(t in key for t in only_tables):
            continue
        feats, rows = smoke_feature_columns(csv_path)
        known.update(feats)
        known.update("%s:%s" % (lang, c) for c in feats)
        here = list(dict.fromkeys([f for f in plain if f in feats] + [c for (l, c) in qual if l == lang and c in feats]))
        names, xf = [], []
        for r in rows:
            if not any((r.get(f) or "").strip() == "1" for f in here):
                continue
            n = (r.get("entry") or "").strip()
            if not n:
                continue
            if (r.get("xfail") or "").strip() == "1":
                xf.append(n)
            else:
                names.append(n)
        sel[key] = {"csv": csv_path, "suite": suite, "lang": lang, "features": here, "entries": names, "xfail": xf,
                    "rows": len(rows), "columns": feats}
    unknown = [f for f in want if f not in known]
    return sel, unknown


def _smoke_outside_names(suite):
    """The entries the suite's own declarations keep out of the graded denominator -- excluded from the smoke, named (the cfo
    2026-09-28: the first smoke selected arizona's cfuncs, extlvals, env, checkc, fncs1 and kwds, each declared beside the package,
    and read six reds the board never counts). A rung suite declares ALL.outside.tsv; a package declares UNGRADED.tsv, UNGRADABLE.tsv,
    OUTSIDE_*_BASELINE.tsv, EXCLUDED.tsv and CONTAINERS.tsv (lib_inventory.sh's buckets), first column a file name whose extension
    the entry name drops. The smoke reads the same files the board reads and grades the same denominator."""
    out = set()
    d = Path(suite).parent
    files = [d / "ALL.outside.tsv", d / "UNGRADED.tsv", d / "UNGRADABLE.tsv", d / "EXCLUDED.tsv", d / "CONTAINERS.tsv"] + sorted(d.glob("OUTSIDE_*_BASELINE.tsv"))
    for p in files:
        if not p.is_file():
            continue
        for ln in p.read_text(encoding="utf-8", errors="replace").splitlines():
            if ln.strip() and not ln.lstrip().startswith("#"):
                name = ln.split("\t")[0].strip()
                out.add(name)
                out.add(name.rsplit(".", 1)[0] if "." in name.rsplit("/", 1)[-1] else name)
    return out


# ⭐ A TABLE WHOSE BOARD GRADES EACH PROGRAM UNDER PER-PROGRAM SIDECARS IS SMOKED THROUGH THAT BOARD'S RUNNER (the coo 2026-10-02, row
# instruments-the-area-smoke-grades-ipl-entries-without-their-sidecars-and-reads-nine-false-reds): the IPL board runs each program
# under its NAME.pin clock-and-entropy shim, NAME.dat stdin, NAME.argv, NAME.outfiles and fixtures, in an isolation directory, against
# its own NAME.ref; the generated ALL.icn/ALL.ref pair carries none of them and no runner maintains it, so grading the container read
# nine false reds (webimage based cwd declchck farb hebcalen parens puzz xtable) against board PASS readings. The runner's smoke mode
# (S4E_AREA_SMOKE_ENTRIES) grades the named entries by the board's own loop and writes no progress row and no score row.
# a table whose board grades shipped programs the generated container does not hold: gimpel's ALL.sno is the 120-entry cut from before
# CEO-1269, its ALL.csv the 145 drivers the board grades, and the smoke selected 79 and ran 0 (hq_snobol4 to the coo, 2026-10-03)
SMOKE_DELEGATES = {"packages/icon/ipl": "test_icon_ipl_suite.sh", "packages/snobol4/gimpel": "test_snobol4_gimpel_suite.sh"}
_SMOKE_DELEGATE_KIND = {"PASS": "PASS", "FAIL": "FAIL", "CRASH": "CRASH", "HANG": "HANG", "REFUSE": "UNPROVEN", "NONE": "SKIP"}


def _smoke_delegate(paths, runner, names):
    """{entry: {"m3": kind, "m4": kind}} from the board runner's smoke mode; an entry the board does not run-grade maps to None.
    Refuses rc=2 when the runner refuses or answers for fewer entries than it was asked."""
    env = dict(os.environ, S4E_AREA_SMOKE_ENTRIES=" ".join(names), S4E_PROGRESS_OFF="1")
    r = subprocess.run(["bash", str(HARNESS_SCRIPTS / runner)], capture_output=True, text=True, env=env,
                       timeout=180 + 90 * len(names), stdin=subprocess.DEVNULL)
    out = {}
    for ln in r.stdout.splitlines():
        m = re.match(r"(?:IPL|GIMPEL)_SMOKE_ENTRY (\S+) (.*)$", ln)
        if not m:
            continue
        if "NOT_RUN-GRADED" in m.group(2):
            out[m.group(1)] = None
            continue
        out[m.group(1)] = {k: _SMOKE_DELEGATE_KIND.get(v, "UNPROVEN") for k, v in re.findall(r"(m[34])=(\S+)", m.group(2))}
    if r.returncode != 0 or set(out) != set(names):
        tail = "\n".join((r.stdout + r.stderr).strip().splitlines()[-6:])
        refuse(f"smoke: {runner}'s smoke mode answered rc={r.returncode} for {len(out)} of {len(names)} entr(ies) -- the table cannot be "
               f"graded the board's way and is never graded another way:\n{tail}")
    return out


def _smoke_names(names, cap):
    if len(names) <= cap:
        return " ".join(names)
    return " ".join(names[:cap]) + f" ... and {len(names) - cap} more"


def cmd_smoke(args):
    paths = resolve_paths()
    features = [f for tok in args.features for f in tok.replace(",", " ").split() if f]
    only = [t for t in (args.tables or "").replace(",", " ").split() if t]
    if args.vocabulary:
        # THE VOCABULARY, printed from the tables themselves: test_area_smoke.sh expands a carrier map's `*` and `lang:<x>` rows
        # through this, so the 0/1-column rule lives here once and the wrapper never re-derives it.
        n = 0
        for key, csv_path, suite, lang in smoke_tables(paths["corpus"]):
            if only and not any(t in key for t in only):
                continue
            feats, _rows = smoke_feature_columns(csv_path)
            if feats:
                n += 1
                print(f"AREA_SMOKE_VOCAB table={key} runnable={'yes' if suite else 'no'} {' '.join(feats)}")
        if n == 0:
            refuse("smoke --vocabulary: no attribute table with feature columns under %s%s" % (paths["corpus"], f" matching {only}" if only else ""))
        return
    if not features:
        refuse("smoke: no feature named -- the area is the feature columns of ALL.csv (FENCE, SPAN, scan, suspend, cut ...); "
               "test_area_smoke.sh derives them from a landing's diff through ../harness/scripts/area_map.tsv")
    modes = parse_modes(args.modes or "m3,m4", "smoke")
    if not paths["corpus"].is_dir():
        refuse(f"smoke: corpus root {paths['corpus']} is not a directory (S4E_HOME={os.environ.get('S4E_HOME', '<unset>')})")
    sel, unknown = smoke_select(paths["corpus"], features, only)
    if not sel:
        refuse("smoke: no attribute table found under %s%s" % (paths["corpus"], f" matching {only}" if only else ""))
    only_entries = [t for t in (getattr(args, "entries", "") or "").replace(",", " ").split() if t]
    if only_entries:
        # a gate's witness set: the feature selection narrowed to these names, and a name the selection did not reach refuses
        for s_ in sel.values():
            s_["entries"] = [n for n in s_["entries"] if n in only_entries]
        _reached = {n for s_ in sel.values() for n in s_["entries"]}
        if set(only_entries) - _reached:
            refuse("smoke --entries: %s not selected by the feature(s) %s in the table(s) read" % (sorted(set(only_entries) - _reached), " ".join(features)))
    if unknown:
        vocab = sorted({c for s in sel.values() for c in s["columns"]})
        refuse("smoke: feature(s) no attribute table knows: %s -- the vocabulary is the tables' own column names (%d known: %s)"
               % (" ".join(unknown), len(vocab), " ".join(vocab[:60]) + (" ..." if len(vocab) > 60 else "")))
    cap = int(args.max_names)
    total = 0
    for key, s in sel.items():
        if not s["entries"] and not s["xfail"]:
            continue
        run_note = "" if s["suite"] else " NOT RUNNABLE: no suite file beside the table"
        print(f"AREA_SMOKE_SELECT table={key} features={','.join(s['features'])} selected={len(s['entries'])} of {s['rows']} "
              f"xfail_excluded={len(s['xfail'])}{run_note}: {_smoke_names(s['entries'], cap)}")
        if s["suite"]:
            total += len(s["entries"])
    if total == 0:
        refuse("smoke: the feature(s) %s select ZERO runnable entries across %d table(s) -- a smoke that grades nothing is not "
               "a verdict; name the feature the landing touches" % (" ".join(features), len(sel)))
    if args.list_only:
        print(f"AREA_SMOKE_LIST features={' '.join(features)} runnable_entries={total} (nothing run: --list-only)")
        return
    check_scrip(paths)
    # EVERY TABLE IS READ AGAINST ITS SUITE BEFORE ANY ENTRY RUNS (the cto 2026-09-28: a table that named three entries its suite
    # lacked refused the smoke AFTER twelve minutes of entries) -- a refusal that could have been read in a second is read first.
    plans = []
    for key, s in sel.items():
        if not s["entries"] or not s["suite"]:
            continue
        suite, lang = s["suite"], s["lang"]
        ref = suite.with_name("ALL.ref")
        if not ref.is_file():
            refuse(f"smoke: {suite} has no ALL.ref beside it -- nothing to grade against")
        if lang in LANG_CONFIGS:
            cfg = LANG_CONFIGS[lang]
            ext = cfg["ext"]
            entries = read_block_suite(str(suite), str(ref), banner_re_for(cfg["comment_open"], cfg["comment_close"]),
                                       in_path=sidecar_in_path(str(suite)), x_path=sidecar_xfail_path(str(suite)),
                                       w_path=sidecar_wantrc_path(str(suite)), a_path=sidecar_argv_path(str(suite)), modes=modes)
        else:
            ext = ".sno"
            entries = read_suite(str(suite), str(ref), in_path=sidecar_in_path(str(suite)), x_path=sidecar_xfail_path(str(suite)),
                                 w_path=sidecar_wantrc_path(str(suite)), a_path=sidecar_argv_path(str(suite)), modes=modes)
        by_name = {e.name: e for e in entries}
        outside = _smoke_outside_names(suite)
        wanted = [n for n in s["entries"] if n not in outside]
        skipped_outside = [n for n in s["entries"] if n in outside]
        # a delegated table is graded by its board from the shipped programs, so the container's membership is not asked
        missing = [] if key in SMOKE_DELEGATES else [n for n in wanted if n not in by_name]
        if missing:
            # ⛔ A TABLE THAT DISAGREES WITH ITS SUITE IS ITS BUILDER'S DEFECT, NOT EVERY SEAT'S PREFLIGHT (hq_pascal 2026-09-28: ipl's ALL.csv
            # named progs/kwic, procs/ichartp, progs/concord that ALL.icn lacks, and the smoke refused every template-touching landing
            # fleet-wide). The entries that cannot be run are NAMED, left out of this run, and the rest of the table runs; the
            # disagreement itself is the package board's and the builder's to read (the loop names it to the owner).
            print(f"AREA_SMOKE_TABLE_SUITE_DISAGREEMENT table={key}: {s['csv']} names {len(missing)} entr(y/ies) the suite {suite.name} "
                  f"does not contain, left out of this run and named for the table's builder: {_smoke_names(missing, 10)}")
            wanted = [n for n in wanted if n in by_name]
        plans.append((key, s, suite, lang, ext, by_name, wanted, skipped_outside, ref))
    standing, suite_of, base_note = _smoke_standing(plans, paths)
    print(base_note)
    tmp_root = Path(tempfile.mkdtemp(prefix="csh_smoke_"))
    reds = []
    stand = []
    skipped = []
    graded = 0
    all_pass = 0
    per_table = []
    try:
        for key, s, suite, lang, ext, by_name, wanted, skipped_outside, ref in plans:
            FATAL_RENDER["voice"] = _fatal_render_voice_for(lang if lang in LANG_CONFIGS else "")
            FATAL_RENDER["merged_voice"] = _merged_render_voice_for(lang if lang in LANG_CONFIGS else "")
            masks = read_mask_sidecar(str(ref))
            heap, _ = heap_declarations(str(suite))
            stack, _ = stack_declarations(str(suite))
            t_pass, t_red = 0, []
            delegated = _smoke_delegate(paths, SMOKE_DELEGATES[key], wanted) if key in SMOKE_DELEGATES and wanted else None
            if delegated is not None:
                print(f"AREA_SMOKE_DELEGATED table={key} runner={SMOKE_DELEGATES[key]} entries={len(wanted)}: graded by the board's own loop "
                      f"and sidecars, not the generated container")
            for n in wanted:
                if delegated is not None and delegated[n] is None:
                    print(f"AREA_SMOKE_ENTRY table={key} entry={n} NOT RUN-GRADED by its board (no NAME.ref): not graded here either")
                    continue
                if delegated is not None:
                    verdicts = None
                    kinds = {m: delegated[n].get(m, "SKIP") for m in modes}
                else:
                    e = by_name[n]
                    if masks:
                        pm = masks_for(masks, e.name)
                        if pm:
                            e.mask = pm
                    if n in heap:
                        e.heap_kb = heap[n]
                    if n in stack:
                        e.stack_kb = stack[n]
                    verdicts = run_suite_entry(paths, e, tmp_root, modes, ext=ext, companion_dir=suite.parent)
                    kinds = {m: verdicts[m].kind for m in modes}
                graded += 1
                # a SKIP (mode 4 could not compile or link) is a could-not-measure for that mode, never a red (the cfo 2026-09-28):
                # the entry is green when every MEASURED mode passed and at least one was measured; it is named as skipped
                measured = {m: k for m, k in kinds.items() if k != "SKIP"}
                if len(measured) < len(kinds):
                    skipped.append((key, n, [m for m, k in kinds.items() if k == "SKIP"]))
                ok = bool(measured) and all(k == "PASS" for k in measured.values())
                was = {}
                if ok:
                    t_pass += 1
                    all_pass += 1
                else:
                    # ⭐ A STANDING RED IS NOT THE LANDING'S (the cto, hq_prolog, the cfo, 2026-09-28: every seat's preflight read the
                    # smoke red on entries the loop's own last reading already had red). An entry whose every red mode read non-PASS at
                    # its latest reading in the progress record is STANDING: named, never charged to this landing. An entry that read
                    # PASS there, or was never read (a new witness), is the landing's red.
                    reds_here = [m for m, k in measured.items() if k != "PASS"] or list(kinds)
                    sname = suite_of.get(key)
                    was = {m: standing.get((sname, n, m)) for m in reds_here}
                    if sname and all(v and v != "PASS" for v in was.values()):
                        stand.append((key, n, kinds, was))
                    else:
                        t_red.append(n)
                        reds.append((key, n, kinds))
                tag = ""
                if not ok and stand and stand[-1][1] == n and stand[-1][0] == key:
                    tag = " STANDING (the last reading: %s)" % ", ".join(f"{m}={v}" for m, v in was.items())
                elif not ok:
                    # ⭐ A RED THE LANDING IS CHARGED WITH SAYS WHICH KIND IT IS (the cfo, 2026-09-30: eleven Icon package reds read "no
                    # reading" when the record held a board PASS for each -- the smoke grades the package's generated container, the
                    # board the shipped program): PASS at the last reading, or never read under this table's progress suite name.
                    seen = {m: v for m, v in was.items() if v}
                    if seen:
                        tag = " NEW RED (the last reading: %s%s)" % (", ".join(f"{m}={v}" for m, v in seen.items()),
                                                                     "; %s never read" % ",".join(m for m in was if not was[m]) if len(seen) < len(was) else "")
                    else:
                        tag = (" NEW RED (never read in the progress record as %s/%s)" % (suite_of.get(key), n) if suite_of.get(key)
                               else " NEW RED (this table maps to no progress suite, so no reading can exist)")
                print("AREA_SMOKE_ENTRY table=%s entry=%s %s%s" % (key, n, " ".join(f"{m}={kinds[m]}" for m in modes), tag))
                for m in modes:
                    if kinds[m] != "PASS" and verdicts is not None and verdicts[m].detail:
                        print(f"    {m}: {verdicts[m].detail[:300]}")
            per_table.append((key, len(wanted), t_pass, t_red, skipped_outside))
    finally:
        import shutil
        shutil.rmtree(tmp_root, ignore_errors=True)
    for key, n, p, red, outs in per_table:
        print(f"AREA_SMOKE_TABLE table={key} run={n} pass={p} red={len(red)} outside_excluded={len(outs)}"
              + (f" reds: {_smoke_names(red, cap)}" if red else "")
              + (f" outside: {_smoke_names(outs, cap)}" if outs else ""))
    if skipped:
        print("AREA_SMOKE_SKIPPED %d entr(y/ies) had a mode that could not be measured (SKIP: mode 4 did not compile or link), graded on the "
              "other mode and named: %s" % (len(skipped), _smoke_names(["%s:%s[%s]" % (k, n, ",".join(ms)) for k, n, ms in skipped], cap)))
    if stand:
        print("AREA_SMOKE_STANDING %d entr(y/ies) red here and red at their last reading in the progress record -- standing debt of "
              "their lanes, not this landing's: %s" % (len(stand), _smoke_names(["%s:%s" % (k, n) for k, n, _kk, _w in stand], cap)))
    print(f"AREA_SMOKE_TOTAL features={' '.join(features)} modes={','.join(modes)} tables={len(per_table)} entries={graded} "
          f"all_pass={all_pass} red={len(reds)} standing={len(stand)} skipped_modes={len(skipped)} -- no progress row appended, no score cell written: an area smoke is not a board "
          f"(CEO-547, CEO-1342 clause 4); the suite number is the coo's SUITE TABLE row")
    if graded == 0:
        # the selection found runnable entries and the run graded none (gimpel's 79 of 145 against a stale container, exit 0)
        refuse("smoke: %d entr(y/ies) selected and NONE graded -- a smoke that grades nothing is not a verdict; the lines above name "
               "what was left out" % total)
    sys.exit(1 if reds else 0)


def _smoke_standing(plans, paths):
    """({(suite, program, mode): latest outcome}, {table key: progress suite name}, note) for the tables a smoke will run, read from
    the progress record (util_progress_append's db_path, S4E_PROGRESS_DB honoured) with a fixed-string grep on the suite names first
    -- the record is ~840 MB and append-only, so the last line for a key is its latest reading. An unreadable record yields an
    empty baseline and says so: every red is then the landing's, which is the conservative reading, never a hidden one."""
    suite_of = {}
    for key, s, suite, lang, *_rest in plans:
        try:
            suite_of[key] = progress_suite_for(str(suite), paths)[1]
        except Exception:
            pass
    names = sorted(set(v for v in suite_of.values() if v))
    if not names:
        return {}, suite_of, "AREA_SMOKE_BASELINE none: no table maps to a progress suite name -- every red is the landing's"
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import util_progress_append as _upa
        db = _upa.db_path()
    except Exception as e:
        return {}, suite_of, f"AREA_SMOKE_BASELINE unreadable ({type(e).__name__}) -- every red is the landing's"
    if not os.path.isfile(db):
        return {}, suite_of, f"AREA_SMOKE_BASELINE none: no progress record at {db} -- every red is the landing's"
    args = ["grep", "-F"]
    for n in names:
        args += ["-e", "\t%s\t" % n]
    try:
        r = subprocess.run(args + [db], capture_output=True, text=True, errors="replace", timeout=120, env=dict(os.environ, LC_ALL="C"))
    except Exception as e:
        return {}, suite_of, f"AREA_SMOKE_BASELINE unreadable ({type(e).__name__}: {e}) -- every red is the landing's"
    out = {}
    want = set(names)
    for ln in r.stdout.splitlines():
        f = ln.split("\t")
        if len(f) < 10 or f[5] not in want:
            continue
        out[(f[5], f[7], f[8])] = f[9]
    return out, suite_of, f"AREA_SMOKE_BASELINE the progress record {db}: {len(out)} (program, mode) latest readings over {len(names)} suite(s) -- a red that was red there is STANDING"


def cmd_list(args):
    """Print every entry name in a suite, one per line, in file order. For consumers that need to
    enumerate a suite's members -- a board denominator, a tool that materializes every entry into a
    scratch directory -- without re-deriving the suite grammar a second time (same rationale as
    cmd_extract, ONE AUTHORITY: read_suite()).

    ⛔⭐ --lang ADDED 2026-09-02 (hq_P, on hq_B's report from the rung-6 witness landing). THIS SUBCOMMAND
    COULD NOT READ ANY NON-SNOBOL4 RUNGS AT ALL. read_suite() hardcodes SNOBOL4's `*` banner marker, so a
    Prolog rungs (`%` comments) parsed as thousands of one-line entries and died on the UNMODIFIED committed
    ALL.pl/ALL.ref with `family.ref is shorter than family.sno at seq NNNN` -- cmd_run has taken --lang and
    dispatched to read_block_suite() since 2026-08-29, and cmd_list was simply never given the same dispatch.
    ⛔⭐ THE ERROR MESSAGE WAS THE EXPENSIVE HALF: it names the REF FILE as short, so it reads as a corpus
    defect. hq_B hit it while promoting the rung-6 witnesses and had to go and re-check the committed baseline
    to establish that their own edit had not broken it. A WRONG-READER FAULT THAT ACCUSES THE DATA COSTS THE
    NEXT READER A BISECTION THEY DID NOT NEED. Hence the explicit suffix refusal below: it names the reader,
    the suffix and the exact flag to pass, and it fires BEFORE the grammar can produce a misleading message.
    ⭐ AND IT MADE A DOCUMENTED PROCEDURE UNFOLLOWABLE: lib_rungs_extract.sh's INTERIM PROMOTION PROTOCOL
    tells a promoter to prove the promotion with `list`, which for .pl could not be done at all."""
    if args.lang:
        cfg = LANG_CONFIGS[args.lang]
        entries = read_block_suite(args.sno, args.ref, banner_re_for(cfg["comment_open"], cfg["comment_close"]))
    else:
        suffix = Path(args.sno).suffix
        if suffix and suffix != ".sno":
            owner = [k for k, c in LANG_CONFIGS.items() if c["ext"] == suffix]
            hint = f" -- pass --lang {owner[0]}" if owner else " -- no LANG_CONFIGS dialect claims that suffix"
            refuse(f"list: {args.sno} has suffix {suffix!r}, but with no --lang this reads the SNOBOL4 suite grammar "
                   f"(`*` banners){hint}. Refusing rather than parsing every line as a one-line entry and then blaming "
                   f"the .ref file for being short -- the fault would be the READER, not the data.")
        entries = read_suite(args.sno, args.ref)
    for e in entries:
        print(e.name)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    o = sub.add_parser("capture-oracle-refs", help="bootstrap missing .ref files for an oracle-graded, no-.ref family from a live SPITBOL (or --lang dialect) run (m3+m4 must both agree, rc and text)")
    o.add_argument("family_dir")
    o.add_argument("--modes", default="m3,m4")
    o.add_argument("--force", action="store_true", help="re-capture even stems that already have a .ref (default: leave them alone)")
    o.add_argument("--lang", default="", choices=LANG_CHOICES, help="capture against a LANG_CONFIGS dialect's own oracle instead of SPITBOL (only 'prolog' has an oracle wired as of 2026-08-29; default '' means snobol4, unchanged behavior)")
    o.add_argument("--compile-args", default="", help="scrip's compile switches for every stem, space-separated (e.g. --stlimit): a loose family has no attribute row, so the caller declares them (clause 8 (f)); default none")
    o.set_defaults(func=cmd_capture_oracle_refs)

    c = sub.add_parser("convert", help="convert a loose-file family into suite .sno/.ref, validating byte-equal before writing")
    c.add_argument("family_dir")
    c.add_argument("out_sno")
    c.add_argument("out_ref")
    c.add_argument("--modes", default="m3,m4")
    c.add_argument("--skip", default="", help="comma-separated .sno stems to deliberately exclude from this run (left as loose files, never deleted)")
    c.add_argument("--skip-reason", default="", help="mandatory-in-spirit reason printed for every --skip name")
    c.set_defaults(func=cmd_convert)

    b = sub.add_parser("convert-blocks", help="convert a format-(B)-only banner-block family for a LANG_CONFIGS dialect (non-SNOBOL4)")
    b.add_argument("lang", choices=sorted(LANG_CONFIGS))
    b.add_argument("family_dir")
    b.add_argument("out_src")
    b.add_argument("out_ref")
    b.add_argument("--modes", default="", help="default: LANG_CONFIGS[lang]['modes']")
    b.add_argument("--skip", default="", help="comma-separated stems to deliberately exclude from this run (left as loose files, never deleted)")
    b.add_argument("--xfail", default="", help="comma-separated stems whose original is KNOWN-RED: convert them as XFAIL witnesses instead of refusing. Byte-equal-or-no-delete is UNCHANGED -- the candidate must still reproduce the ORIGINAL's exact verdict. REFUSES if a named stem is actually green (that is an XPASS, as actionable as a failure).")
    b.add_argument("--skip-reason", default="", help="mandatory-in-spirit reason printed for every --skip name")
    b.set_defaults(func=cmd_convert_blocks)

    r = sub.add_parser("run", help="run a suite .sno/.ref pair (or --lang dialect pair) and print PASS/FAIL/CRASH/HANG/UNPROVEN/SKIP counts, OOM split out of FAIL")
    r.add_argument("sno")
    r.add_argument("ref")
    r.add_argument("--modes", default="", help="default: m3,m4 (or LANG_CONFIGS[lang]['modes'] if --lang given)")
    r.add_argument("--lang", default="", choices=LANG_CHOICES, help="read/grade as a LANG_CONFIGS dialect instead of the default SNOBOL4 suite format")
    r.add_argument("--outside", default="", help="TSV of entries OUTSIDE this suite's baseline (name<TAB>CLASS<TAB>reason), each dropped from the graded denominator and printed with its reason -- for a program the language's own oracle refuses to run")
    r.add_argument("--outside-none", action="store_true", dest="outside_none",
                   help="grade the SHIPPED set: do NOT pick up the sibling ALL.outside.tsv that a rung suite suite would otherwise "
                        "ride with. Prints OUTSIDE_BASELINE_LIST NONE loudly, naming the list it skipped, because such a run's "
                        "pass count is not comparable to a board graded against the baseline. Incompatible with --outside.")
    r.add_argument("--shard", default="", help="k/N: grade only every N-th entry starting at the k-th (1-based, interleaved), so the N shards partition the suite exactly once and their boards SUM to the monolithic board; the SUITE_BOARD line carries shard=k/N and total=<this shard's entries> (row corpus-runner-master-suite-exceeds-single-call-cap, hq_B 2026-09-02)")
    r.add_argument("--partition", default="", help="core | shell:<feature> | chunk:NN, or a comma-separated union of them: grade exactly that subset of the suite's stored PARTITION.tsv (CEO-1676), both modes, progress rows per program carrying partition=NAME in their note and config; the SUITE_BOARD carries partition=NAME, which util_score_row.py refuses as a suite row (a partition is never the suite). Incompatible with --shard")
    r.set_defaults(func=cmd_run)

    pt = sub.add_parser("partition", help="THE SELECTION VERB (CEO-1676): print PARTITION <name>: <k> of <n> entries from the suite's stored PARTITION.tsv (core | shell:<feature> | chunk:NN; every part without --name); runs nothing, records nothing")
    pt.add_argument("suite", help="the suite file (ALL.<ext> or ALL.csv); its PARTITION.tsv sits beside it")
    pt.add_argument("--name", default="", help="core | shell:<feature> | chunk:NN, or a comma-separated union of them")
    pt.add_argument("--list", action="store_true", help="also print the selected entry names, one per line, in partition order")
    pt.set_defaults(func=cmd_partition)

    e = sub.add_parser("extract", help="materialize ONE suite entry back into a standalone .sno (+ optional .ref/.in/.xfail) file")
    e.add_argument("sno")
    e.add_argument("ref")
    e.add_argument("name", nargs="?", default="", help="the entry's CURRENT name (the builder renames entries: directive_82); or give --origin instead")
    e.add_argument("out_sno")
    e.add_argument("--origin", default="", help="resolve the entry by its ORIGIN (the durable provenance key, e.g. ladder__rung00_hello) through the ALL.csv beside the rungs; REFUSES if the CSV or the origin is absent (hq_C ask 2026-09-02, rung 0)")
    e.add_argument("--out-ref", default="", dest="out_ref")
    e.add_argument("--out-in", default="", dest="out_in", help="required if the entry carries stdin -- REFUSES rather than silently materializing a stdin-bearing entry without it")
    e.add_argument("--out-xfail", default="", dest="out_xfail", help="optional: write the entry's xfail reason here if it has one (documentation only, never affects grading)")
    e.set_defaults(func=cmd_extract)

    ef = sub.add_parser("extract-family", help="materialize one family's entries back into a standalone suite pair (banner-block or one-line, matching the source's own format) -- family membership comes from the source's own CSV, never re-derived from names")
    ef.add_argument("sno")
    ef.add_argument("ref")
    ef.add_argument("csv")
    ef.add_argument("family")
    ef.add_argument("out_sno")
    ef.add_argument("out_ref")
    ef.set_defaults(func=cmd_extract_family)

    pr = sub.add_parser("pin-ref", help="re-anchor ONE entry's ref to SCRIP's own ruled output, with a mandatory ruling and a provenance ledger that capture-oracle-refs then refuses to overwrite")
    pr.add_argument("sno"); pr.add_argument("ref"); pr.add_argument("entry")
    pr.add_argument("--ruling", required=True, help="WHY this entry's answer is SCRIP's to decide and not the oracle's (mandatory: an unexplained pin cannot be told from a ref cut while the compiler was broken)")
    pr.add_argument("--mode", default="m3", choices=["m3", "m4"], help="which mode's live output to pin (default m3)")
    pr.add_argument("--measurer", default="", help="who ruled it (defaults to $S4E_SEAT)")
    pr.add_argument("--lang", default="", choices=LANG_CHOICES)
    pr.add_argument("--oracle-disagrees-and-i-mean-it", action="store_true", help="pin even though the oracle RAN this entry cleanly and gave a different answer -- the ledger records both. Spelled out in full because the first use of this verb blessed a regression on an unmeasured claim that the oracle could not grade the entry")
    pr.add_argument("--apply", action="store_true", help="write it (without this the diff is printed and nothing changes)")
    pr.set_defaults(func=cmd_pin_ref)

    xr = sub.add_parser("extension-ref", help="cut ONE entry's ref from a NAMED non-SPITBOL oracle (an extension the suite's oracle lacks) and mark it in the suite's extension ledger (Lon 2026-10-02)")
    xr.add_argument("suite", help="a rung suite ALL.<ext> (its ref beside it), or a package directory")
    xr.add_argument("entry", help="the rung entry's name, or the package program's file name (ord.sno)")
    xr.add_argument("--oracle", required=True, choices=sorted(EXTENSION_ORACLES), help="the lib_oracle_flags.sh accessor that cuts the ref")
    xr.add_argument("--feature", required=True, help="the extension the entry exercises (ORD)")
    xr.add_argument("--ruling", required=True, help="who ruled it and when (mandatory)")
    xr.add_argument("--measurer", default="", help="who cut it (defaults to $S4E_SEAT)")
    xr.add_argument("--lang", default="", choices=LANG_CHOICES)
    xr.add_argument("--apply", action="store_true", help="write the ref and the ledger row (without this the diff is printed and nothing changes)")
    xr.set_defaults(func=cmd_extension_ref)

    xc = sub.add_parser("extension-check", help="check and print a package directory's EXTENSIONS.tsv for a bash runner (refuses a stale sha or a program also excluded)")
    xc.add_argument("package")
    xc.add_argument("--names", action="store_true", help="print only the program names, one per line")
    xc.set_defaults(func=cmd_extension_check)

    l = sub.add_parser("list", help="print every entry name in a suite, one per line, in file order")
    l.add_argument("sno")
    l.add_argument("ref")
    l.add_argument("--lang", default="", choices=LANG_CHOICES, help="read as a LANG_CONFIGS dialect instead of the default SNOBOL4 suite format (a non-.sno suffix without this REFUSES rather than misreading)")
    l.set_defaults(func=cmd_list)

    sm = sub.add_parser("smoke", help="THE AREA SMOKE (CEO-1342 clause 4): run, in both modes, every rung suite and package entry whose ALL.csv attribute row marks any named feature column; population printed by name; appends no progress row and writes no score cell -- not a board")
    sm.add_argument("features", nargs="*", help="feature column names as the tables spell them (FENCE SPAN scan suspend cut ...); a name no table knows REFUSES rc=2")
    sm.add_argument("--modes", default="", help="default m3,m4")
    sm.add_argument("--entries", default="", help="narrow the feature selection to these entry names (a gate's witness set); a name it does not reach refuses")
    sm.add_argument("--tables", default="", help="restrict to tables whose key (tests/<lang>, packages/<lang>/<pkg>) contains any of these tokens")
    sm.add_argument("--list-only", action="store_true", dest="list_only", help="print the selection per table and run nothing")
    sm.add_argument("--vocabulary", action="store_true", help="print each table's feature columns (AREA_SMOKE_VOCAB lines) and exit; no feature needed")
    sm.add_argument("--max-names", default="40", dest="max_names", help="names printed per line before '... and K more'")
    sm.set_defaults(func=cmd_smoke)

    args = ap.parse_args()
    # ⛔⭐ EXPLICITNESS IS RECORDED BEFORE THE SYNONYM IS NORMALISED AWAY, because the next line destroys the
    # only evidence that the SNOBOL4 grammar was CHOSEN rather than defaulted into: `--lang snobol4` and an
    # omitted --lang both arrive downstream as "". require_lang_for_suite() needs to tell them apart -- one is
    # a caller asking for the line-per-entry reader, the other is the omission that re-grades a suite into a
    # population nobody wrote. Read after normalisation, this flag would always be False.
    args.lang_explicit = bool(getattr(args, "lang", None))
    if getattr(args, "lang", None) == "snobol4":
        args.lang = ""      # the accepted synonym for the default -- see LANG_CHOICES
    args.func(args)


if __name__ == "__main__":
    import signal as _sg; _sg.signal(_sg.SIGTERM, lambda *_: sys.exit(143)); _sg.signal(_sg.SIGHUP, lambda *_: sys.exit(129))
    main()
