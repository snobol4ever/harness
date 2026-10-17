#!/usr/bin/env python3
"""util_gen_library_driver.py -- THE DRIVER GENERATOR (ceo CEO-706 -> hq_B, rank 0, 2026-09-13).

WHY THIS EXISTS. 1,223 rows fleet-wide were filed as "cannot be graded" and only ~130 genuinely are.
The largest class is CONTAINER_OR_LIBRARY -- a library module with no entry point, which no runner can
execute and every runner therefore reports as SKIPPED. Lon's ruling: there is no such thing as
UNGRADABLE. The cure is a DRIVER: a small program that links the module, calls its documented
procedures, and is graded against a ref cut from the oracle. The technique is already proven in the
tree -- corpus/packages/snobol4/gimpel ships 144 hand-written drivers -- but 987 hand-written drivers
across four lanes is the wrong shape, so this tool builds the skeleton and cuts the ref.

WHAT IT IS NOT. It is NOT an author. `skeleton` emits a driver whose argument values are GUESSED from
the formal parameter names, and that guess is weak by measurement, not by accident: across the 336
DEFINEs in gimpel the formal names are S(65) X(29) L(29) A(28) N(21) Y(18) P(12) I(11) -- S/N/I/A/T
carry a real convention, X/L/Y/P carry none. So a guessed driver is a FIRST DRAFT A HUMAN FINISHES,
every guess is recorded in the driver's own header with the basis that produced it, and the thing that
makes the tool safe is not the guess, it is the REFUSAL below.

⛔⭐ THE REF IS CUT FROM THE ORACLE ALONE, AND THAT IS A DELIBERATE DIFFERENCE FROM THE TOOL NEXT DOOR.
corpus_suite_harness.py's `capture-oracle-refs` is the tree's other ref-minting authority and it is
more careful than this one in every respect but one: it mints only on THREE-WAY AGREEMENT (oracle text
== m3 text == m4 text). That contract is right for its own job (bootstrapping a family that is already
green) and WRONG for this one. A 987-program grading push whose refs exist only where SCRIP already
agrees with the oracle adds 987 green tests and ZERO information -- it cannot, by construction, show a
single gap. So this tool cuts from the oracle and from nothing else, per the standing law (a ref is cut
from the oracle, never from our output), and a driver whose oracle answer SCRIP gets wrong is exactly
the driver worth having.
⛔ AND THAT CHOICE IS WHAT MAKES THE DETERMINISM ARM LOAD-BEARING. With the three-way arm gone, the
self-diff below is the ONLY thing standing between a guessed driver and a permanently-red ref. hq_S's
witness, 2026-09-13: the AIS row could never have closed because ATN prints TIME deltas on 19 lines, so
two oracle runs of it differ on 38. A generator that cuts 900 refs without running the oracle twice
manufactures 900 permanently-red tests, each of which reads as a defect in the compiler.

THE FOUR ARMS, in the order the brief names them:
  1. `procs`     -- enumerate the procedures a module DEFINES (per-language, see enumerate_*)
  2. `skeleton`  -- emit a driver that links the module and calls each with plausible arguments
  3. `cut`       -- cut the ref BY RUNNING THE ORACLE, twice, and diffing it against itself
  4. REFUSE(2)   -- rather than emit a driver whose oracle run is empty, errors, or is nondeterministic
And the fifth, which the brief adds because a thin witness reports a thin denominator: every subcommand
prints COVERAGE -- procedures exercised over procedures defined -- so a driver exercising one procedure
of a twenty-procedure module is honest about being one twentieth of a witness.

⛔ THE ORACLE INVOCATION IS NEVER RE-DERIVED HERE. `cut` shells out to scorecard_snobol4.sh's `oracle`
verb, which exists precisely so a .ref can be minted through the same door the board grades through (a
ref minted under a different cwd, lib path, stdin or flag set than the board grades with is a pin that
can never match -- s191, seat5, twice in one session). See oracle_once() for the one wrinkle: that door
is currently shut to every seat but the coo, which is FINDING-2026-09-13-hq_B-the-one-ref-cut-door-is-
behind-the-one-runner-board-guard.md and a FLIP to the coo, not a re-implementation here.

Usage:
  util_gen_library_driver.py procs    <module>                     # TSV: name arity args locals origin
  util_gen_library_driver.py skeleton <module> [--out FILE] [--max-procs N]
  util_gen_library_driver.py cut      <driver> --suite SUITE [--ref FILE] [--force]
  util_gen_library_driver.py gen      <module> --suite SUITE --out DIR   # skeleton + cut + coverage
  util_gen_library_driver.py coverage <module> <driver>
  util_gen_library_driver.py classify  <module-or-DIR>              # the shape census of a TREE
  util_gen_library_driver.py inventory <package-DIR> [--cause C]    # the shape census of the ROWS -- FIRST
Exit: 0 = did the thing.  1 = a real failure.  2 = REFUSED, could not measure / would have minted a lie.
"""
import argparse, os, re, shutil, subprocess, sys, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SD = (HERE.parent.parent / "SCRIP")
ROOT = SD.parent

def refuse(msg, code=2):
    print(f"⛔ REFUSE(rc={code}): {msg}", file=sys.stderr)
    sys.exit(code)

class Proc:
    """One procedure a module DEFINES. `origin` is the file the definition was read from -- a module
    that -INCLUDEs another defines only its OWN procedures, and the included ones are reported but are
    NOT in the coverage denominator (a driver for AI.sno is not owed a witness for SEQ.sno)."""
    def __init__(self, name, args, locals_, origin, own):
        self.name, self.args, self.locals, self.origin, self.own = name, args, locals_, origin, own
    @property
    def arity(self):
        return len(self.args)
    def __repr__(self):
        return f"{self.name}/{self.arity}"

# ------------------------------------------------------------------ SNOBOL4
# ⛔ THE CONTINUATION LINE IS NOT OPTIONAL TO HANDLE. gimpel's FASTBAL.sno carries
# `DEFINE('FASTBAL(PARENS,QTS,S)NAME,IBAL,SPCHARS,ELEM'` with the closing paren on the NEXT line; a
# line-at-a-time scan reads its formals correctly and its locals as truncated, then emits a driver
# calling a procedure whose real arity it never saw. A '+' or '.' in column 1 continues the statement.
SNO_DEFINE = re.compile(r"\bDEFINE\.?\s*\(\s*'([^']*)'", re.IGNORECASE)
SNO_PROTO = re.compile(r"^\s*([A-Za-z][A-Za-z0-9_.]*)\s*(?:\(([^)]*)\))?\s*(.*)$")
SNO_INCLUDE = re.compile(r"^\s*-INCLUDE\s+'?\"?([^'\"\s]+)", re.IGNORECASE)

def sno_logical_lines(text):
    """Fold SNOBOL4 continuation lines and drop full-line comments, so a DEFINE that spans two physical
    lines is read as one statement."""
    out, buf = [], ""
    for raw in text.splitlines():
        if raw[:1] == "*":
            continue
        if raw[:1] in ("+", ".") and buf:
            buf += " " + raw[1:]
            continue
        if buf:
            out.append(buf)
        buf = raw
    if buf:
        out.append(buf)
    return out

def sno_strip_goto(line):
    """⛔⭐ A GOTO FIELD LOOKS EXACTLY LIKE A CALL, AND THIS COST A FALSE MEASUREMENT BEFORE IT WAS FOUND
    (hq_B, 2026-09-13, while proving this tool against gimpel's 144 hand drivers). SNOBOL4 transfers control
    with `:S(LABEL)`, `:F(LABEL)` or `:(LABEL)` in a trailing goto field, so `AGT_driver.sno` line 6 --
    `SHOW = A ' AGT ' B ' -> YES' AGT(A,B)  :S(RETURN)` -- reads to any name-followed-by-paren scan as a call
    to a procedure named S. And `L_ONE.sno` genuinely DEFINEs a procedure named S, so the two are
    indistinguishable by name alone: the proving ground reported 54 modules whose driver "called a procedure
    the enumerator missed" and a large share of them were this, not a miss at all.
    ⭐ THE GENERAL FORM: a scan that is right about its pattern and wrong about the LANGUAGE REGION it is
    scanning reports confidently and is never contradicted -- the same narrow-instrument shape as a $? after
    a pipeline. Cut the goto field at the first unquoted colon, then look for calls.
    ⛔ Quote tracking is not optional: a colon inside a literal is data, not a goto."""
    q = None
    for i, c in enumerate(line):
        if q:
            if c == q:
                q = None
        elif c in "'\"":
            q = c
        elif c == ":":
            return line[:i]
    return line

def enumerate_snobol4(path, own=True, seen=None):
    """DEFINE('NAME(A1,A2)L1,L2') is the whole contract. Also DEFINE. -- FTRACE.sno OPSYNs DEFINE over
    itself and issues `DEFINE.(...)`, and INSULATE.sno does the same; a scan for the bare spelling reads
    those modules as defining nothing at all, which is indistinguishable from a module with no
    procedures. REDEFINE(...) is deliberately NOT matched: it is a CALL, and counting it would put a
    procedure in the denominator that this file never defines."""
    seen = seen if seen is not None else set()
    rp = path.resolve()
    if rp in seen:
        return []
    seen.add(rp)
    procs = []
    try:
        text = rp.read_text(errors="replace")
    except OSError as e:
        refuse(f"cannot read module {path}: {e}")
    for line in sno_logical_lines(text):
        m = SNO_DEFINE.search(line)
        if m:
            pm = SNO_PROTO.match(m.group(1))
            if pm:
                name = pm.group(1)
                args = [a.strip() for a in (pm.group(2) or "").split(",") if a.strip()]
                locs = [a.strip() for a in (pm.group(3) or "").split(",") if a.strip()]
                procs.append(Proc(name, args, locs, rp.name, own))
        im = SNO_INCLUDE.match(line)
        if im:
            inc = rp.parent / im.group(1)
            if inc.is_file():
                procs.extend(enumerate_snobol4(inc, own=False, seen=seen))
    return procs

# ------------------------------------------------------------------ Icon
ICN_PROC = re.compile(r"^\s*procedure\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)")

def enumerate_icon(path, own=True, seen=None):
    """`procedure NAME(args)`. `main` is EXCLUDED and that exclusion is the point: a module with a main
    is not a container, it is a program, and it was never in this class to begin with."""
    procs = []
    for line in path.read_text(errors="replace").splitlines():
        if line.lstrip().startswith("#"):
            continue
        m = ICN_PROC.match(line)
        if m and m.group(1) != "main":
            args = [a.strip() for a in m.group(2).split(",") if a.strip()]
            procs.append(Proc(m.group(1), args, [], path.name, own))
    return procs

# ------------------------------------------------------------------ Prolog
PL_MODULE = re.compile(r":-\s*module\s*\(\s*[^,]+,\s*\[(.*?)\]\s*\)", re.S)
PL_EXPORT = re.compile(r"([a-z][a-zA-Z0-9_]*)\s*/\s*(\d+)")
PL_HEAD = re.compile(r"^([a-z][a-zA-Z0-9_]*)\s*(?:\(([^)]*)\))?\s*(?::-|\.)")

def enumerate_prolog(path, own=True, seen=None):
    """⭐ THE EXPORT LIST IS PREFERRED OVER CLAUSE HEADS, AND THE DIFFERENCE IS NOT COSMETIC. A clause-head
    scan reports every internal helper and reports a 40-clause predicate forty times; the module's own
    `:- module(M,[f/1,...])` declaration is the author's statement of what is callable. The head scan is
    the FALLBACK for a file with no module declaration -- GNU Prolog's BipsPl is exactly that shape --
    and when it runs, the arity set is deduplicated, because `foo/2` defined by eight clauses is one
    procedure to a driver."""
    text = path.read_text(errors="replace")
    mm = PL_MODULE.search(text)
    if mm:
        procs = []
        for name, ar in PL_EXPORT.findall(mm.group(1)):
            procs.append(Proc(name, [f"A{i+1}" for i in range(int(ar))], [], path.name, own))
        return procs
    seen_sig = set()
    procs = []
    for line in text.splitlines():
        if line.lstrip().startswith("%"):
            continue
        m = PL_HEAD.match(line)
        if m:
            args = [a.strip() for a in (m.group(2) or "").split(",") if a.strip()]
            sig = (m.group(1), len(args))
            if sig in seen_sig:
                continue
            seen_sig.add(sig)
            procs.append(Proc(m.group(1), [f"A{i+1}" for i in range(len(args))], [], path.name, own))
    return procs

# A SNOBOL4 include library ships as NAME.inc or NAME.INC (Lon 2026-09-14, "Change the *.sno to *.inc", CEO-1274/1315): gimpel's
# 120 libraries and include/'s four; since 2026-09-27 gimpel is Catspaw's SPITBOL form, name.inc libraries and name.spt programs (CEO-1319).
# lang_of lowers the suffix, so one key reads both spellings; the driver is still NAME_driver.sno.
LANGS = {".sno": ("snobol4", enumerate_snobol4), ".inc": ("snobol4", enumerate_snobol4), ".spt": ("snobol4", enumerate_snobol4), ".icn": ("icon", enumerate_icon),
         ".pl": ("prolog", enumerate_prolog), ".sc": ("snocone", enumerate_snobol4)}

def lang_of(path):
    ext = path.suffix.lower()
    if ext not in LANGS:
        refuse(f"no enumerator for {ext!r} ({path.name}) -- known: {' '.join(sorted(LANGS))}. "
               f"A guess here would report a module as defining nothing, which is indistinguishable "
               f"from a module that genuinely defines nothing.")
    return LANGS[ext]

# ------------------------------------------------------------------ the argument guess
# ⛔ READ THE DOCSTRING AT THE TOP BEFORE TRUSTING ANY OF THIS. The convention below is MEASURED over
# gimpel's 336 DEFINEs and it covers roughly half the formal names in that package; the rest (X, L, Y,
# P, CW, LOC ...) carry no convention at all and fall through to the string default. Every guess is
# printed in the driver header with the rule that produced it, so a human finishing the skeleton can see
# what was assumed rather than reverse-engineering it from the values.
SNO_GUESS = [
    (re.compile(r"^(S|STR|STRING|TEXT)\d*$", re.I), "'alpha'", "name matches S/STR -- string by gimpel convention"),
    (re.compile(r"^(N|I|J|K|M|CNT|COUNT|LEN|SIZE)\d*$", re.I), "3", "name matches N/I/J/K/M -- integer by gimpel convention"),
    (re.compile(r"^(A|ARR|ARRAY)\d*$", re.I), "ARRAY(3)", "name matches A/ARR -- ARRAY by gimpel convention"),
    (re.compile(r"^(T|TBL|TABLE)\d*$", re.I), "TABLE()", "name matches T/TBL -- TABLE by gimpel convention"),
    (re.compile(r"^(B|BASE|RADIX)\d*$", re.I), "2", "name matches B/BASE -- integer radix by gimpel convention"),
]
ICN_GUESS = [
    (re.compile(r"^(s|str|line|name|fn|f)\d*$", re.I), '"alpha"', "name matches s/str/line -- string"),
    (re.compile(r"^(n|i|j|k|m|len|size|count)\d*$", re.I), "3", "name matches n/i/j/k -- integer"),
    (re.compile(r"^(L|lst|list)\d*$", re.I), '[1,2,3]', "name matches L/lst -- list"),
]

def guess_args(lang, proc):
    """-> (list of value strings, list of basis strings). A parameter whose name carries no convention
    gets the string default, and its basis says exactly that -- NOT a silent choice."""
    table = SNO_GUESS if lang in ("snobol4", "snocone") else ICN_GUESS if lang == "icon" else []
    vals, basis = [], []
    for a in proc.args:
        for rx, val, why in table:
            if rx.match(a):
                vals.append(val)
                basis.append(f"{a} -> {val}   ({why})")
                break
        else:
            default = "'alpha'" if lang in ("snobol4", "snocone") else '"alpha"'
            vals.append(default)
            basis.append(f"{a} -> {default}   (NO CONVENTION for this name -- string default, VERIFY THIS)")
    return vals, basis

# ------------------------------------------------------------------ skeleton emission
def skeleton_snobol4(module, procs, max_procs):
    own = [p for p in procs if p.own]
    chosen = own[:max_procs] if max_procs else own
    L = [f"*  {module.stem}_driver -- GENERATED SKELETON (util_gen_library_driver.py, CEO-706).",
         f"*  ⛔ THIS IS A FIRST DRAFT A HUMAN FINISHES. Every argument value below is GUESSED from the",
         f"*  formal parameter NAME, not from the module's contract. Read {module.name}'s own header,",
         f"*  fix the values, and widen the coverage line before this driver is called a witness.",
         f"*  COVERAGE: {len(chosen)} of {len(own)} procedure(s) this module defines are exercised here."]
    for p in chosen:
        vals, basis = guess_args("snobol4", p)
        L.append(f"*  {p.name}({','.join(p.args)}) -- " + ("no arguments" if not basis else "; ".join(basis)))
    L.append(f'-INCLUDE "{module.name}"')
    for p in chosen:
        vals, _ = guess_args("snobol4", p)
        call = f"{p.name}({', '.join(vals)})" if p.args else f"{p.name}()"
        L.append(f"        OUTPUT  =  '{p.name}: ' {call}")
    L.append("END")
    return "\n".join(L) + "\n", len(chosen), len(own)

def skeleton_icon(module, procs, max_procs):
    own = [p for p in procs if p.own]
    chosen = own[:max_procs] if max_procs else own
    L = [f"#  {module.stem}_driver -- GENERATED SKELETON (util_gen_library_driver.py, CEO-706).",
         f"#  ⛔ A FIRST DRAFT A HUMAN FINISHES -- argument values are guessed from formal names.",
         f"#  COVERAGE: {len(chosen)} of {len(own)} procedure(s) defined in {module.name} are exercised."]
    for p in chosen:
        _, basis = guess_args("icon", p)
        L.append(f"#  {p.name}({','.join(p.args)}) -- " + ("no arguments" if not basis else "; ".join(basis)))
    L.append(f'$include "{module.name}"')
    L.append("procedure main()")
    for p in chosen:
        vals, _ = guess_args("icon", p)
        L.append(f'    write("{p.name}: ", image({p.name}({", ".join(vals)})));')
    L.append("end")
    return "\n".join(L) + "\n", len(chosen), len(own)

def skeleton_prolog(module, procs, max_procs):
    own = [p for p in procs if p.own]
    chosen = own[:max_procs] if max_procs else own
    L = [f"%  {module.stem}_driver -- GENERATED SKELETON (util_gen_library_driver.py, CEO-706).",
         f"%  ⛔ A FIRST DRAFT A HUMAN FINISHES -- every argument below is an UNBOUND VARIABLE, which is",
         f"%  the honest guess for a predicate whose modes this tool cannot read. Bind them per the",
         f"%  module's own documentation before calling this a witness.",
         f"%  COVERAGE: {len(chosen)} of {len(own)} predicate(s) exported by {module.name} are exercised.",
         f":- ensure_loaded('{module.name}')."]
    L.append(":- initialization(main, main).")
    L.append("main :-")
    body = []
    for p in chosen:
        args = ", ".join(f"_{i+1}" for i in range(p.arity))
        goal = f"{p.name}({args})" if p.arity else p.name
        body.append(f"    (   catch({goal}, E, (print_message(error, E), fail))\n"
                    f"    ->  format(\"~w: yes~n\", ['{p.name}/{p.arity}'])\n"
                    f"    ;   format(\"~w: no~n\",  ['{p.name}/{p.arity}'])\n    )")
    L.append(",\n".join(body) + "." if body else "    true.")
    return "\n".join(L) + "\n", len(chosen), len(own)

SKELETONS = {"snobol4": skeleton_snobol4, "snocone": skeleton_snobol4,
             "icon": skeleton_icon, "prolog": skeleton_prolog}

# ------------------------------------------------------------------ the oracle, twice
def oracle_once(suite, driver, outfile):
    """-> (status, rc, bytes). ⛔ ONE DOOR, NEVER A SECOND SPELLING: scorecard_snobol4.sh's `oracle` verb
    already carries the cwd / SETL4PATH / -bf / timeout facts and already classifies TIMEOUT, SIG,
    RC<n>, DEAD_REPORT (the oracle exits 0 while printing a fatal report -- seat2, s191), EMPTY and LIVE.
    ✅ THE DOOR IS OPEN AND THE OVERRIDE IS GONE (the coo, SCRIP 26b19872b, 2026-09-13). scorecard_snobol4.sh
    guards PER VERB now: `run` and `report` are boards and keep the refusal, while `one` and `oracle` grade ONE
    named program, write no results.tsv, publish no board and write no SCORE row -- so they pass. That is the
    guard's own criterion finally applied to itself (CEO-547 part 1, quoted in lib_one_runner.sh: WHAT MAKES A
    RUN A BOARD IS THE POPULATION IT GRADES, NOT THE ENTRY POINT).
    ⛔ WHY TAKING THE OVERRIDE OFF MATTERS MORE THAN THE TWO LINES IT DELETES: at CEO-706 scale this call runs
    hundreds of times, and A LOUD CHANNEL USED 900 TIMES IS A QUIET CHANNEL -- the next seat who genuinely
    overrides a BOARD would have been one indistinguishable line in the same stream. It also put a line on
    stdout AHEAD of the status TSV and so invented a parsing contract: every caller had to read the LAST
    status-shaped line instead of the only one. Both go away together, which is why the parse below now
    REFUSES on a second status line rather than quietly preferring one of them.
    ⭐ AND THE MEASUREMENT THE SHUT DOOR PRODUCED IS WORTH KEEPING, because it is the argument that opened it:
    of gimpel's 28 ref-less drivers a correct cut takes 12 and refuses 16, and EIGHT of those refusals are
    DEAD_REPORT -- sbl exiting 0 while printing a fatal report. A hand-rolled sbl line cut on "did it exit 0 and
    print something" agrees with the correct answer on 20 of 28 and disagrees on 8, minting a crash dump as the
    pinned correct answer. A closed door does not stop mandated work, it relocates it somewhere unobservable."""
    p = subprocess.run(["bash", str(HERE / "scorecard_snobol4.sh"), "oracle", suite, str(driver), str(outfile)],
                       capture_output=True, text=True)
    tsv = [l for l in p.stdout.splitlines() if l.count("\t") >= 3]
    if len(tsv) > 1:
        refuse(f"the oracle door printed {len(tsv)} status-shaped lines for {driver.name}; one program has ONE "
               f"status. Preferring the last one is how a preamble on this channel stayed invisible:\n   "
               + "\n   ".join(tsv[:4]))
    if not tsv:
        refuse(f"the oracle door produced no status line for {driver.name} (rc={p.returncode}).\n"
               f"   stdout: {p.stdout.strip()[:400]}\n   stderr: {p.stderr.strip()[:400]}")
    st, rc, nbytes = tsv[-1].split("\t")[:3]
    return st, int(rc), int(nbytes)

NONDET_SOURCES = {
    "snobol4": [(re.compile(r"\bDATE\s*\(", re.I), "DATE()"), (re.compile(r"\bTIME\s*\(", re.I), "TIME()"),
                (re.compile(r"\bCLOCK\s*\(", re.I), "CLOCK()"), (re.compile(r"\bHOST\s*\(", re.I), "HOST()"),
                (re.compile(r"\bRANDOM\s*\(", re.I), "RANDOM()")],
    "icon": [(re.compile(r"&clock\b"), "&clock"), (re.compile(r"&date\b"), "&date"),
             (re.compile(r"&time\b"), "&time"), (re.compile(r"&random\b"), "&random"),
             (re.compile(r"&host\b"), "&host")],
    "prolog": [(re.compile(r"\bget_time\s*\("), "get_time/1"), (re.compile(r"\brandom\s*[/(]"), "random"),
               (re.compile(r"\bstatistics\s*\("), "statistics/2")],
}

def nondet_sources(path, lang):
    """⛔⭐⭐ THE SELF-DIFF IS NECESSARY AND NOT SUFFICIENT, AND THAT WAS MEASURED HERE RATHER THAN REASONED
    (hq_B 2026-09-13, building this arm). Two witnesses, both genuinely nondeterministic, one oracle pair each:
        a TIME() delta around a 40,000-iteration loop -> run1 'elapsed 1860997', run2 'elapsed 1921230'. The
            self-diff CATCHES it. This is hq_S's ATN case, which prints TIME deltas on 19 lines.
        three lines of DATE() -> both runs printed '09/13/26 17:15:14' three times. IDENTICAL. The self-diff
            MISSES it completely, because two runs milliseconds apart fall inside the same second.
    ⭐ SO THE TWO RUNS CAN AGREE BY LUCK, and the luckier the box the likelier the agreement -- a ref cut on a
    fast machine at 17:15:14.9 is red for everyone who runs it at 17:15:15. A second run is a sample of size
    two, and a clock with one-second granularity is invisible to it. ⛔ THE ANSWER IS NOT A THIRD RUN, OR A
    SLEEP BETWEEN THEM: that buys a wider sample of the same instrument and still cannot see a field that
    changes once a day. It is a SECOND INSTRUMENT WITH A DIFFERENT BLIND SPOT -- read the source for the
    known nondeterministic primitives, which catches exactly the slow-clock case the self-diff cannot, and is
    itself blind to the ones the self-diff catches best (an unordered TABLE walk, an address, a PID inherited
    through a builtin). Agreement is only evidence when the arms CAN disagree.
    ⛔ It reads the module too, not only the driver: the clock is nearly always in the library, not in the
    ten-line driver that calls it."""
    found = []
    for rx, label in NONDET_SOURCES.get(lang, []):
        if rx.search(driver_call_text(path, lang)):
            found.append((label, path.name))
    return found

def nondet_scan_tree(driver, lang):
    """The driver plus every module it links, because the clock is usually in the library."""
    found = list(nondet_sources(driver, lang))
    text = driver.read_text(errors="replace")
    for m in re.finditer(r"(?:-INCLUDE|\$include|ensure_loaded)\s*\(?\s*['\"]([^'\"]+)['\"]", text, re.I):
        inc = driver.parent / m.group(1)
        if inc.is_file():
            found.extend(nondet_sources(inc, lang))
    return found

def dir_fingerprint(d):
    """Every file under d, with size and mtime. The falsifiable half of the overlay below."""
    out = []
    for root, _, names in os.walk(d):
        for n in sorted(names):
            f = Path(root) / n
            try:
                st = f.stat()
                out.append(f"{f} {st.st_size} {st.st_mtime}")
            except OSError:
                out.append(f"{f} ?")
    return sorted(out)

def cut_ref(suite, driver, ref_path, force):
    """Arms 3 and 4 of the brief. REFUSES rather than writing a ref that is empty, that records an error,
    or that two oracle runs of the same program do not agree on."""
    if ref_path.is_file() and not force:
        refuse(f"{ref_path.name} already exists -- refusing to overwrite a committed ref. "
               f"Pass --force only when you mean to re-cut it.")
    with tempfile.TemporaryDirectory() as td:
        o1, o2 = Path(td) / "run1", Path(td) / "run2"
        # ⛔⭐⭐ THE DRIVER RUNS ON AN OVERLAY, BECAUSE A DRIVER MAY WRITE FILES AND THIS TOOL DIRTIED THE
        # VENDORED TREE BEFORE THE OVERLAY EXISTED (hq_B 2026-09-13, caught by a `git status` at handoff and
        # not by any check of mine). Cutting refs for gimpel's 28 ref-less drivers left
        # `corpus/packages/snobol4/gimpel/asmtemp` behind: ASM.sno opens a DISK work file by the relative name
        # `asmtemp`, and the oracle door deliberately runs each program in the PROGRAM'S OWN DIRECTORY so a
        # relative -INCLUDE resolves -- so the work file lands in the vendored package.
        # ⭐ THIS IS NOT A NEW DEFECT, IT IS A KNOWN ONE I WALKED INTO: test_snobol4_gimpel_suite.sh carries
        # the identical cure and the identical reason (row snobol4-gimpel-runner-writes-asmtemp-into-the-
        # vendored-dir-and-blocks-its-own-score-write), and its consequence there was that util_score_row.py
        # correctly refused the leaderboard row, because a number measured on a dirty tree describes no tree
        # anyone can check out. ⛔ A grader that writes into what it grades is the same defect as a gate that
        # edits the artifact it measures -- and the lesson had been written down, in this tree, by someone
        # else, before I repeated it. Reading the runner I was calling would have cost a minute.
        # ⭐ WHY AN OVERLAY RATHER THAN A cwd CHANGE: the per-program cwd is load-bearing and it belongs to
        # the shared board runner, not to me. Copying the driver's directory leaves that contract untouched.
        ov = Path(td) / "overlay"
        try:
            shutil.copytree(driver.parent, ov, symlinks=True)
        except OSError as e:
            refuse(f"could not mint a scratch overlay of {driver.parent} ({e}) -- refusing to run a driver "
                   f"in the tree it was read from, because a driver that writes a work file dirties it.")
        run_driver = ov / driver.name
        if not run_driver.is_file():
            refuse(f"the overlay of {driver.parent.name} does not contain {driver.name} -- refusing rather "
                   f"than falling back to the real tree.")
        # ⛔ THE OVERLAY IS NOT TRUSTED, IT IS CHECKED, and that is the gimpel runner's own hard-won rule:
        # two seats could not reproduce a witnessed leak by argument, so the runner measures instead. A guard
        # that fires ONCE with the file named is worth more than an hour of reasoning about whether an
        # overlay can leak, and it costs two directory walks.
        real_before = dir_fingerprint(driver.parent)
        st1, rc1, b1 = oracle_once(suite, run_driver, o1)
        if st1 != "LIVE":
            refuse(f"{driver.name}: the oracle answered {st1} (rc={rc1}, {b1} bytes), not LIVE. "
                   f"A ref cut from a {st1} run pins an error report, a timeout or nothing at all as "
                   f"ground truth. Fix the driver -- the usual cause is a guessed argument of the wrong "
                   f"type -- or author it by hand.")
        # ⛔⭐ THE SELF-DIFF, AND IT IS THE ARM THE BRIEF CALLS NOT OPTIONAL (hq_S, 2026-09-13). Its
        # witness: ATN prints TIME deltas on 19 lines, so two oracle runs of it differ on 38. Every
        # other guard in this function passes that program -- it is LIVE, it is non-empty, its rc is 0 --
        # and the ref it would mint is red the moment it is committed and red forever after, reading as
        # a compiler defect. ⭐ THE GENERAL FORM: a byte-compare ref is a claim that the program is a
        # FUNCTION of its input, and that claim is never checked by looking at ONE output.
        st2, rc2, b2 = oracle_once(suite, run_driver, o2)
        t1, t2 = o1.read_text(errors="replace"), o2.read_text(errors="replace")
        if (st2, rc2) != (st1, rc1) or t1 != t2:
            a, b = t1.splitlines(), t2.splitlines()
            diffs = [i + 1 for i in range(max(len(a), len(b)))
                     if (a[i] if i < len(a) else None) != (b[i] if i < len(b) else None)]
            shown = ", ".join(str(d) for d in diffs[:12]) + (" ..." if len(diffs) > 12 else "")
            refuse(f"{driver.name} is NONDETERMINISTIC: two oracle runs of the same program disagree on "
                   f"{len(diffs)} line(s) (run1 {st1}/rc{rc1}/{b1}B, run2 {st2}/rc{rc2}/{b2}B; lines "
                   f"{shown}). A byte-compare ref cut from either run is permanently red. Make the "
                   f"driver deterministic -- a clock, a PID, an address or an unordered TABLE walk is "
                   f"the usual cause -- or grade this module some other way.")
        if not t1.strip():
            refuse(f"{driver.name}: the oracle ran clean and printed nothing. A 0-byte ref grades "
                   f"'produced no output' as correct forever and reads as coverage.")
        real_after = dir_fingerprint(driver.parent)
        if real_before != real_after:
            changed = sorted(set(x.split(" ")[0] for x in
                                 set(real_after) ^ set(real_before)))
            refuse(f"{driver.name}: the source tree CHANGED while cutting its ref, despite the overlay -- "
                   f"{len(changed)} path(s): {' '.join(Path(c).name for c in changed[:8])}. A ref measured "
                   f"by a run that writes into the tree it read describes no tree anyone can check out. "
                   f"Remove those files and find out how the write escaped the overlay before re-cutting.")
        # ⛔ THE SECOND INSTRUMENT (see nondet_sources). The two runs above agreed; that is necessary and it
        # is not sufficient, so a clock in the source refuses here even when the samples matched.
        nd = nondet_scan_tree(driver, lang_of(driver)[0])
        if nd:
            named = ", ".join(f"{lbl} in {fn}" for lbl, fn in sorted(set(nd)))
            refuse(f"{driver.name}: two oracle runs AGREED, but the source reaches a nondeterministic "
                   f"primitive -- {named}. Two runs milliseconds apart fall inside the same second, so a "
                   f"one-second clock is invisible to the self-diff and the agreement above is luck, not "
                   f"evidence. Cutting this ref pins today's wall clock as ground truth. Remove the clock "
                   f"from the witness, or grade this module by a driver that does not print it.")
        ref_path.write_text(t1)
    return t1

# ------------------------------------------------------------------ subcommands
def blank_literals(line, quotes="'\""):
    """⛔⭐ THE SECOND HALF OF THE SAME LESSON, AND IT SURVIVED THE FIRST FIX (hq_B 2026-09-13). With the goto
    field cut, exactly ONE of gimpel's 127 hand drivers still read as calling a procedure the enumerator had
    missed: SNOPUT_driver.sno line 6, which passes a line of SNOBOL4 SOURCE as DATA --
    SNOPUT('LBL  Y = X + 2  :S(LBL)') -- so the goto lives INSIDE a string literal, where sno_strip_goto
    correctly refuses to cut it, and the call scan then found S( in the quoted text.
    ⭐ Two different regions (the goto field, and the inside of a literal), one shape, and the second was
    hidden by the first: fixing the goto took the count from 54 to 1 and the remaining 1 read like a real
    enumerator miss rather than the same defect again. A measurement that improves a lot is the easiest place
    to stop looking. Blank the literals, keep the positions, and the scan sees only code."""
    out, q = [], None
    for c in line:
        if q:
            out.append(" ")
            if c == q:
                q = None
        elif c in quotes:
            q = c
            out.append(" ")
        else:
            out.append(c)
    return "".join(out)

def driver_call_text(driver, lang):
    """The region of a driver in which a CALL can appear: comments dropped, string literals blanked, and for
    SNOBOL4 the goto field cut (see sno_strip_goto and blank_literals). Anything that scans a driver for calls
    goes through here, so both lessons are held in ONE place rather than re-learned by the next scanner."""
    lines = []
    for raw in driver.read_text(errors="replace").splitlines():
        if lang in ("snobol4", "snocone"):
            if raw[:1] == "*":
                continue
            lines.append(blank_literals(sno_strip_goto(raw)))
        elif lang == "icon":
            lines.append(blank_literals(raw.split("#", 1)[0], '"\''))
        elif lang == "prolog":
            lines.append(blank_literals(raw.split("%", 1)[0], "'\""))
        else:
            lines.append(raw)
    return "\n".join(lines)

SHAPE_HELP = {
    "STANDALONE_PROGRAM": "already a complete program with its own entry point -- it needs RUNNING, not a "
                          "driver. If a row calls this ungradable, the row is wrong about the file",
    "PROCEDURES": "defines callable procedures -- `skeleton` can draft a driver for it",
    "PATTERN_FRAGMENT": "defines no procedure; it builds a PATTERN-valued variable. Driving it means "
                        "APPLYING the pattern to a subject, not calling anything -- hand-authored, not generated",
    "NO_EXECUTABLE_CONTENT": "nothing executable at all (all commented out, or pure data) -- NOT a container "
                             "awaiting a driver, and no driver will ever make it gradable",
}

def has_entry_point(path, lang):
    """Does this file start executing on its own? SNOBOL4/Snocone: a bare `END` statement. Icon: a `procedure
    main`. Prolog: an `initialization/1,2` directive or a `main` clause. See classify() for why this is the
    first question asked and how it was measured."""
    text = path.read_text(errors="replace")
    if lang in ("snobol4", "snocone"):
        return any(re.match(r"^[ \t]*END[ \t]*$", l) for l in text.splitlines() if l[:1] != "*")
    if lang == "icon":
        return re.search(r"^\s*procedure\s+main\s*\(", text, re.M) is not None
    if lang == "prolog":
        return (re.search(r":-\s*initialization\s*\(", text) is not None
                or re.search(r"^main\b", text, re.M) is not None)
    return False

def classify(path):
    """⛔⭐⭐ CONTAINER_OR_LIBRARY IS NOT ONE SHAPE, AND A PROCEDURE-ENUMERATING GENERATOR CAN ONLY DRIVE ONE
    OF THEM (hq_B 2026-09-13, measured against gimpel while proving this tool; the brief's 915-row class).
    Three shapes came out of 149 modules and the second two are invisible to `procs`:
      ASM360.sno  -- zero DEFINEs. It is a PATTERN FRAGMENT: it builds the pattern-valued variable ASM360 out
                     of LETTER / SP.CH / QLIT / ELEM and its driver APPLIES that pattern to a subject. There
                     is nothing to call. A procedure scan reports 0 and refuses, correctly and uselessly.
      BREAKX.sno  -- every line commented out, because BREAKX is a SPITBOL BUILTIN. Its hand driver exercises
                     the builtin, not the module. No driver will ever make this file gradable.
    ⭐ WHY THIS IS THE FIRST THING THE FOUR TARGET LANES ACTUALLY NEED, ahead of any generated driver: 915
    rows filed under one cause name are not 915 of one problem, and a lane that discovers this per-module,
    by hand, at the moment its generated driver refuses, pays the discovery 915 times. The refusal is honest
    but it arrives one module at a time and it says "cannot", not "and here is why, and here is the shape".
    ⛔ NOTE WHAT THIS DOES NOT CLAIM. A shape is not a verdict on gradability: a PATTERN_FRAGMENT is perfectly
    gradable by a hand-written driver (gimpel ships one for ASM360), it is only outside THIS tool's reach."""
    lang, fn = lang_of(path)
    # ⛔⭐⭐ THE ENTRY POINT IS TESTED FIRST, AND THIS SHAPE WAS MISSING UNTIL THE CENSUS OF A SECOND PACKAGE
    # CONTRADICTED IT (hq_B 2026-09-13). Read over gimpel alone the three shapes below looked complete, because
    # every non-driver .sno in gimpel really is an include. Run the same census over snoflake_suite and 140 of
    # 180 files came back PATTERN_FRAGMENT -- which is nonsense: they are complete standalone test programs.
    # They have executable statements and no DEFINE, which is all the old test looked at.
    # ⭐ THE DISCRIMINATOR IS THE ENTRY POINT, AND IT IS EXACT, AND IT WAS LEARNED FROM A BUG IN THIS TOOL'S OWN
    # GATE: a SNOBOL4 `END` statement ENDS THE PROGRAM, so a library module must NOT carry one (a driver that
    # includes such a module terminates at the include and prints nothing), while a standalone program MUST.
    # Measured: gimpel library modules 10 of 149 carry a bare END; snoflake_suite 178 of 180; csnobol4_suite
    # 101 of 131. ⛔ WHY IT MATTERS TO THE 915-ROW CLASS AND NOT ONLY TO THIS TOOL: a file with an entry point
    # filed as CONTAINER_OR_LIBRARY is not awaiting a driver at all -- it is awaiting a RUN, and the row that
    # called it ungradable is simply wrong about the file. Drafting a driver for it would be work with no
    # deliverable at the end, and the driver would be the second entry point in one program.
    if has_entry_point(path, lang):
        return "STANDALONE_PROGRAM", 0
    own = [p for p in fn(path) if p.own]
    if own:
        return "PROCEDURES", len(own)
    live = 0
    for raw in path.read_text(errors="replace").splitlines():
        t = raw.strip()
        if not t:
            continue
        if lang in ("snobol4", "snocone") and raw[:1] == "*":
            continue
        if lang == "icon" and t.startswith("#"):
            continue
        if lang == "prolog" and t.startswith("%"):
            continue
        if t.startswith("-"):
            continue
        live += 1
    return ("PATTERN_FRAGMENT" if live else "NO_EXECUTABLE_CONTENT"), 0

def cmd_classify(a):
    targets = []
    root = Path(a.target).resolve()
    if root.is_dir():
        # ⛔⭐ RECURSIVE, AND THE FLAT GLOB WAS WRONG IN A WAY THAT READ AS AN ANSWER (hq_B 2026-09-13). A
        # top-level-only glob censused icon/ipl as ONE module and prolog/gnu_prolog as ZERO, and printed both
        # as a completed census -- while ipl holds 853 .icn under procs/ incl/ progs/ gprocs/ gincl/ gprogs/
        # and gnu_prolog holds 45 under BipsPl/ alone. ⭐ The same unanchored-glob shape this tree has now
        # paid for three times (corpus/crosscheck's 1-of-401, src/templates' bb_*.cpp matching zero). A glob
        # that reports a smaller population than exists never says so.
        # ⛔ An `ALL.<ext>` file is the suite's own concatenation of the package, not a module: censusing it
        # would count the whole package twice, once as itself and once as one enormous entry.
        # The suffix is compared lowered, so NAME.INC is censused with NAME.inc (a glob per key is case-sensitive and missed it).
        targets = [f for f in sorted(root.rglob("*"))
                   if f.is_file() and f.suffix.lower() in LANGS and not f.stem.endswith("_driver") and f.stem != "ALL"]
    elif root.is_file():
        targets = [root]
    else:
        refuse(f"no such file or directory: {a.target}")
    if not targets:
        refuse(f"no library modules found under {root} -- a census that cannot see its population must "
               f"never print zero.")
    tally = {}
    for t in targets:
        shape, n = classify(t)
        tally[shape] = tally.get(shape, 0) + 1
        print(f"{shape}\t{n}\t{t.name}")
    print(f"\n# CENSUS of {len(targets)} module(s) under {root.name}:")
    for shape in ("STANDALONE_PROGRAM", "PROCEDURES", "PATTERN_FRAGMENT", "NO_EXECUTABLE_CONTENT"):
        if shape in tally:
            print(f"#   {shape:22} {tally[shape]:5}   {SHAPE_HELP[shape]}")
    drivable = tally.get("PROCEDURES", 0)
    print(f"# THIS TOOL CAN DRAFT A DRIVER FOR {drivable} of {len(targets)}. The rest are named above with "
          f"their shape, and are NOT this tool's refusal to be explained one module at a time.")
    return 0

def print_coverage(module, exercised, defined, label="COVERAGE"):
    pct = f"{100.0 * exercised / defined:.0f}%" if defined else "n/a"
    thin = "  ⚠ THIN WITNESS -- this driver speaks for a fraction of the module" if defined and exercised < defined else ""
    print(f"{label} {module.name}: exercised={exercised} defined={defined} ({pct}){thin}")

def cmd_procs(a):
    path = Path(a.module).resolve()
    if not path.is_file():
        refuse(f"no such module: {a.module}")
    lang, fn = lang_of(path)
    procs = fn(path)
    own = [p for p in procs if p.own]
    print("# name\tarity\targs\tlocals\torigin\town")
    for p in procs:
        print(f"{p.name}\t{p.arity}\t{','.join(p.args)}\t{','.join(p.locals)}\t{p.origin}\t{'own' if p.own else 'included'}")
    print(f"# lang={lang} own={len(own)} included={len(procs) - len(own)}")
    if not own:
        refuse(f"{path.name} defines NO procedures of its own. This is not a container needing a driver "
               f"-- either the enumerator does not understand this file's dialect, or the file is data. "
               f"Reporting zero and exiting 0 would make those two cases indistinguishable.")
    return 0

def cmd_skeleton(a):
    path = Path(a.module).resolve()
    if not path.is_file():
        refuse(f"no such module: {a.module}")
    lang, fn = lang_of(path)
    procs = fn(path)
    if not [p for p in procs if p.own]:
        refuse(f"{path.name} defines no procedures of its own -- nothing to drive.")
    text, ex, df = SKELETONS[lang](path, procs, a.max_procs)
    if a.out:
        Path(a.out).write_text(text)
        print(f"wrote {a.out}")
    else:
        sys.stdout.write(text)
    print_coverage(path, ex, df)
    return 0

def cmd_cut(a):
    driver = Path(a.driver).resolve()
    if not driver.is_file():
        refuse(f"no such driver: {a.driver}")
    ref = Path(a.ref).resolve() if a.ref else driver.with_suffix(".ref")
    text = cut_ref(a.suite, driver, ref, a.force)
    print(f"CUT {ref} ({len(text.splitlines())} lines) -- oracle LIVE and self-consistent across two runs")
    return 0

def cmd_coverage(a):
    module, driver = Path(a.module).resolve(), Path(a.driver).resolve()
    for p in (module, driver):
        if not p.is_file():
            refuse(f"no such file: {p}")
    lang, fn = lang_of(module)
    own = [p for p in fn(module) if p.own]
    dtext = driver_call_text(driver, lang)
    hit = [p for p in own if re.search(r"\b" + re.escape(p.name) + r"\s*\(", dtext)]
    print_coverage(module, len(hit), len(own))
    missed = [p.name for p in own if p not in hit]
    if missed:
        print("NOT EXERCISED: " + " ".join(missed))
    return 0

def cmd_inventory(a):
    """⛔⭐⭐ THE CENSUS THE FOUR TARGET LANES ACTUALLY NEED FIRST, and it is NOT a census of the tree -- it is
    a census of THE ROWS. A shape census over every file in a package answers "what is in here", which is a
    different question from "what are these 886 rows about", and answering the easier one and reporting it as
    the harder one is this tree's most-repeated defect. So this reads each package's own UNGRADABLE.tsv
    (name<TAB>CLASS<TAB>reason, the rulings hq_P/hq_S authored from measured oracle runs) and classifies the
    CONTAINER_OR_LIBRARY entries -- exactly the population the brief is about, and no other file.
    ⛔ A row whose file is GONE is reported, never skipped: a ruling about a file nobody can find is a row
    that can never close, and it is invisible to every count that silently drops it."""
    root = Path(a.package).resolve()
    # ⛔ THE LIBRARIES LIVE IN UNGRADED.tsv NOW (ceo CEO-1272, coo 2026-09-25): CONTAINER_OR_LIBRARY is retired, every row of it
    # split by measurement -- a library to UNGRADED.tsv as NEEDS_DRIVER, the population this generator exists to drive, and a
    # non-program to CONTAINERS.tsv. So the default cause is NEEDS_DRIVER, and the rows are read from both sidecars.
    invs = [p for p in (root / "UNGRADED.tsv", root / "UNGRADABLE.tsv") if p.is_file()]
    if not invs:
        refuse(f"no UNGRADED.tsv or UNGRADABLE.tsv under {root} -- this command censuses ROWS, and without the row files it "
               f"would silently fall back to censusing the tree, which answers a different question.")
    inv = " and ".join(str(p) for p in invs)
    want = a.cause
    rows, tally, missing, unknown_ext, unknown_exts = [], {}, [], 0, set()
    for line in "\n".join(p.read_text(errors="replace") for p in invs).splitlines():
        if line.startswith("#") or not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < 2 or parts[1] != want:
            continue
        f = root / parts[0]
        if not f.is_file():
            missing.append(parts[0])
            continue
        if f.suffix.lower() not in LANGS:
            unknown_ext += 1
            unknown_exts.add(f.suffix.lower())
            continue
        shape, n = classify(f)
        tally[shape] = tally.get(shape, 0) + 1
        rows.append((shape, n, parts[0]))
    # ⛔⭐ TWO DIFFERENT FACTS, AND THIS TOOL CONFLATED THEM UNTIL THE FLEET TOTAL DID NOT ADD UP (hq_B
    # 2026-09-13). logtalk_iso carries 208 CONTAINER_OR_LIBRARY rows, every one a `.lgt` file, and this
    # command refused with "no CONTAINER_OR_LIBRARY rows in ..." -- which is FALSE. There are 208; I cannot
    # READ any of them. ⭐ It was found only by adding the per-package numbers up against the fleet cause
    # census and refusing to let 208 be arithmetic: the refusal was loud, honest-looking, rc=2, and named
    # the wrong cause. "The population is empty" and "the population is invisible to me" are the same output
    # unless one of them says which, and the first reads as a finished package.
    if not rows and not missing and unknown_ext:
        refuse(f"{unknown_ext} {want} row(s) in {inv} name files with extension(s) "
               f"{' '.join(sorted(unknown_exts))}, for which this tool has NO enumerator -- so this package "
               f"is UNMEASURED by it, not empty of rows. Known: {' '.join(sorted(LANGS))}. Add an enumerator "
               f"for that dialect, or grade these rows another way; do not read this as zero.")
    if not rows and not missing:
        refuse(f"no {want} rows in {inv} -- a census that cannot see its population must never print zero.")
    for shape, n, name in rows:
        print(f"{shape}\t{n}\t{name}")
    print(f"\n# {len(rows)} {want} row(s) in {root.name}, classified:")
    for shape in ("STANDALONE_PROGRAM", "PROCEDURES", "PATTERN_FRAGMENT", "NO_EXECUTABLE_CONTENT"):
        if shape in tally:
            print(f"#   {shape:22} {tally[shape]:5}   {SHAPE_HELP[shape]}")
    if missing:
        print(f"#   ⛔ {len(missing)} row(s) name a file that is NOT ON DISK -- a ruling about a file nobody "
              f"can find can never close: {' '.join(missing[:8])}{' ...' if len(missing) > 8 else ''}")
    if unknown_ext:
        print(f"#   ⚠ {unknown_ext} row(s) have an extension this tool has no enumerator for, and are "
              f"counted in NEITHER column above rather than quietly in one of them.")
    print(f"# A DRIVER IS OWED FOR {tally.get('PROCEDURES', 0)} OF THEM. The STANDALONE_PROGRAM rows need a "
          f"RUN, not a driver -- those rows are wrong about their file. The rest need a hand-authored witness.")
    return 0

def cmd_gen(a):
    module = Path(a.module).resolve()
    if not module.is_file():
        refuse(f"no such module: {a.module}")
    outdir = Path(a.out).resolve()
    outdir.mkdir(parents=True, exist_ok=True)
    lang, fn = lang_of(module)
    procs = fn(module)
    if not [p for p in procs if p.own]:
        refuse(f"{module.name} defines no procedures of its own -- nothing to drive.")
    text, ex, df = SKELETONS[lang](module, procs, a.max_procs)
    driver = outdir / f"{module.stem}_driver{'.sno' if module.suffix.lower() in ('.inc', '.spt') else module.suffix}"
    driver.write_text(text)
    # ⛔ THE MODULE IS COPIED BESIDE THE DRIVER. -INCLUDE / $include resolve relative to the program's own
    # directory under the board's own lib spec (SELFDIR first), so a driver generated into a scratch dir
    # away from its module cannot be oracle-run at all -- and the failure would arrive as an oracle ERROR,
    # i.e. as a refusal blaming the driver for a plumbing fault.
    if not (outdir / module.name).exists():
        (outdir / module.name).write_bytes(module.read_bytes())
    print(f"wrote {driver}")
    cut_ref(a.suite, driver, driver.with_suffix(".ref"), a.force)
    print(f"CUT {driver.with_suffix('.ref').name}")
    print_coverage(module, ex, df)
    return 0

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd")
    p = sub.add_parser("procs"); p.add_argument("module"); p.set_defaults(f=cmd_procs)
    p = sub.add_parser("skeleton"); p.add_argument("module"); p.add_argument("--out")
    p.add_argument("--max-procs", type=int, default=0); p.set_defaults(f=cmd_skeleton)
    p = sub.add_parser("cut"); p.add_argument("driver"); p.add_argument("--suite", required=True)
    p.add_argument("--ref"); p.add_argument("--force", action="store_true"); p.set_defaults(f=cmd_cut)
    p = sub.add_parser("coverage"); p.add_argument("module"); p.add_argument("driver"); p.set_defaults(f=cmd_coverage)
    p = sub.add_parser("classify"); p.add_argument("target"); p.set_defaults(f=cmd_classify)
    p = sub.add_parser("inventory"); p.add_argument("package")
    p.add_argument("--cause", default="NEEDS_DRIVER"); p.set_defaults(f=cmd_inventory)
    p = sub.add_parser("gen"); p.add_argument("module"); p.add_argument("--suite", required=True)
    p.add_argument("--out", required=True); p.add_argument("--max-procs", type=int, default=0)
    p.add_argument("--force", action="store_true"); p.set_defaults(f=cmd_gen)
    a = ap.parse_args()
    if not a.cmd:
        ap.print_help()
        return 2
    return a.f(a)

if __name__ == "__main__":
    sys.exit(main())
