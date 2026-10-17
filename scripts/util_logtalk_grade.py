#!/usr/bin/env python3
"""util_logtalk_grade.py -- the grading engine behind test_prolog_logtalk_suite.sh.

Row prolog-logtalk-iso-3268-conformance-cases-have-no-runner (hq_R, 2026-09-12).

⛔⭐ WHAT THIS GRADES AGAINST, AND WHY IT IS NOT AN ORACLE DIFF. Every case in
corpus/packages/prolog/logtalk_iso carries its OWN expectation, taken from ISO/IEC 13211-1 and citing the
standard's section numbers in the comment above it. So this runner does not compare scrip to gprolog's
opinion or swipl's -- it compares scrip to the standard as the standard states it, which is a stronger
instrument than any oracle diff this repo owns, and it is why this row decides whether "100% of the
industry-standard language" can be said about Prolog at all.

THE BUCKETS ARE THE LEDGER'S, AND THE IDENTITY IS THE DELIVERABLE (ARCH-PROGRAM-LEDGER):
    PASS + FAIL + OUTSIDE + UNGRADABLE + UNGRADED + DEFERRED == the population globbed
⛔ A case this runner cannot set up, cannot express, or is told by its own `condition(...)` option to skip
is UNGRADED **and named with its reason** -- never dropped from the population and never counted as
passing. UNKNOWN is not ZERO. The population is printed on the board line and the identity is asserted
here, in code: if it does not hold the runner REFUSES rather than publishing four numbers that do not add
up, because four plausible independent counts with an invisible remainder is exactly the "never graded
business" the package lockdown exists to end.

⛔ THE VERDICT COMPARISON IS DONE IN PROLOG, NOT IN PYTHON TEXT. An expectation like
error(type_error(evaluable, foo/0)) is matched by UNIFYING the thrown ball against a '$lgt_want'/1 clause
inside the generated program. Comparing printed text instead would make quoting, variable naming and
operator spacing our problem, and each of those has its own way of being wrong -- _G0 vs _123 alone would
red every instantiation_error case in the suite.
"""
import io
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import glob
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import util_logtalk_extract as ex   # noqa: E402
import lib_timeout_retry as _ltr   # noqa: E402 -- a graded run's timeout under load is retried once (CEO-1335)

# ⛔ Helpers the shim implements. A helper NOT in this set makes its case UNGRADED and names the helper, so
# the work owed reads off the board instead of hiding inside a red count. Keep it in sync with
# lib_logtalk_lgtunit.pl by reading that file (below), never by retyping the list -- two lists that can
# disagree about what is implemented is the same defect as two counts that can disagree about a population.
SHIM = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib_logtalk_lgtunit.pl")

# Directives in a file's database section that are Logtalk/dialect scaffolding, not Prolog the case needs.
DROP_DIRECTIVES = ("if", "elif", "else", "endif", "import", "use_module", "ensure_loaded",
                   "set_logtalk_flag", "encoding", "include")


# ⛔⭐ A FILE'S DATABASE IS NOT ALL PROLOG, AND ONE CLAUSE THAT IS NOT TAKES THE WHOLE FILE DOWN. The
# clauses before `:- object(` and the helper clauses inside it travel with EVERY case of that file, so a
# single helper written in Logtalk's own message-sending syntax (`^^Goal`, `Obj::Goal`) makes every one of
# that file's generated programs a parse error -- and the case then reports `nooutput`, which reads as the
# construct under test failing. Measured 2026-09-12 against the ceo's independent emulation: 40 files and
# 1486 of 3617 cases were graded this way, is_2 and numbers among them, and every one was a verdict on
# `cleanup :- ^^clean_text_input.` rather than on arithmetic. ⭐ THE SHAPE OF THE DEFECT IS THE POINT: the
# harness was wrong in a way that could only ever produce reds, so it never looked like a harness bug --
# a board of failures is what a young frontend is expected to print.
LOGTALK_ONLY_SYNTAX = re.compile(r"\^\^|::")
# ⛔⭐ THE ORDER-DEPENDENT CASES -- NEITHER A RED NOR A DROPPED CASE. This runner generates ONE PROGRAM PER
# CASE, which is what makes a case's verdict a verdict on its construct instead of on its neighbours -- and a
# handful of cases in this suite are written against the database THEIR FILE'S EARLIER CASES leave behind.
# `predicates/retract_1` is the measured example (hq_C, FINDING-2026-09-13, claim 2): case 04 wants a
# three-entry findall from a legs/2 that cases 01 and 03 have already cut to three clauses, and case 05 wants
# retract/1 to FAIL on a legs/2 that only case 04 can drain. Standalone NEITHER CAN PASS WHATEVER THE ENGINE
# DOES, and they arrived as FAIL -- the one bucket that means *the engine got it wrong* and the one bucket a
# seat is expected to drive to zero, so they were picked up, ablated and handed back unsolved by everyone who
# inherited the row. ⭐ A FAIL NO CURE CAN CLEAR IS A DEFECT OF THE INSTRUMENT, and it is the
# flattering-direction error for an instrument: it makes the runner look like it is measuring the language
# when it is measuring its own harness.
# THE MECHANISM: a case NAMED in lib_logtalk_sequenced.tsv is graded with its file's earlier cases run first,
# IN FILE ORDER -- which is how lgtunit itself runs a tests.lgt, so this is fidelity and not a workaround.
# Each prefix goal becomes its OWN clause ('$lgt_preN') called inside ignore(catch(...)): its variables stay
# local (a textual splice would make case 03's X and case 04's X one variable, a silently different program)
# and its own outcome never grades anything.
# ⛔ THE DECLARATION IS POLICED ON EVERY RUN, NEVER TRUSTED. Every declared case is ALSO run standalone, and
# if it PASSES standalone the run REFUSES rc=2 and says to delete the line; so does a declaration naming a
# case that is FIRST in its file (no prefix to run) or a name its group does not have. Without those arms
# this table is a silencer -- one line per red, and every verdict it touches weaker than the suite supports.
SEQ_TABLE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib_logtalk_sequenced.tsv")


def load_sequenced(path=SEQ_TABLE, setups=None):
    """{(group, case): reason} read from the declaration table. A malformed line is NAMED, never skipped. A line may carry a fourth
    column, a SETUP goal (ceo CEO-1695): the case is then graded with that goal run inside it ahead of its own goal, instead of its
    file's prefix -- encodings' _03/_04 cases query facts their fixture defines, loaded through the adapter's '$lgt_load_prolog_file'/1
    as lgtunit's run would have loaded it at _02. `setups`, when given, is filled {(group, case): goal}."""
    out, bad = {}, []
    if not os.path.exists(path):
        return out, [(path, "the sequenced-case declaration table is missing -- it is data this runner reads, "
                            "never a default it invents")]
    for n, line in enumerate(io.open(path, encoding="utf-8"), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        f = line.rstrip("\n").split("\t")
        if len(f) not in (3, 4) or not all(x.strip() for x in f):
            bad.append((path, "line %d is not group<TAB>case<TAB>reason[<TAB>setup goal]: %r" % (n, line.rstrip()[:80])))
            continue
        out[(f[0].strip(), f[1].strip())] = f[2].strip()
        if len(f) == 4 and setups is not None:
            setups[(f[0].strip(), f[1].strip())] = f[3].strip()
    return out, bad


# ⛔⭐ THE EXCLUDED CASES ARE NAMED BESIDE THE SUITE, ONE ROW EACH WITH THE CASE'S OWN CONDITION (Lon 2026-10-05, in-chat to the ceo,
# verbatim: "Mark the Windows dependent tests as Excluded." and "Mark the bounded-integer tests as Excluded."; ceo CEO-1519, CEO-1520),
# the shape of a SNOBOL4 package's EXCLUDED=k. An excluded case is never run and never counted as pass or fail; every other case is
# in the denominator (Lon, CEO-1518: "We have NO expected failures."). The file is EXCLUDED_CASES.tsv, not EXCLUDED.tsv, because the
# package inventory reads EXCLUDED.tsv as excluded FILES and these are cases inside the files. Each class names the evidence the
# grader checks on the case itself, so a row cannot outlive the condition that justified it.
EXCLUDED_TABLE = "EXCLUDED_CASES.tsv"
EXCLUDED_CLASSES = {
    "WINDOWS_ONLY": "the :- if(...) branch this suite compiles only on Windows (its unix else-branch is graded)",
    "BOUNDED_INTEGERS_ONLY": "a condition(...) that holds only where integers are bounded (SCRIP is unbounded, like SWI)",
    # ceo CEO-1524 (2026-10-05): an if/else whose branches expect opposite outcomes of one goal, so no engine passes both; the ceo
    # decided FEATURE PRESENT (util_logtalk_extract.RULED) and the sibling branch is this row.
    "EXCLUSIVE_BRANCH": "the sibling branch of a ruled :- if(...)/else pair whose two branches expect opposite outcomes (the feature-present branch is graded)",
    # ceo CEO-1524 (2026-10-05): read of a dotless float (1e33) expecting syntax_error. SCRIP's default reads it as SWI does, which
    # 11 SWI suite programs depend on; the strict ISO reading is built under set_prolog_flag(iso, true) (the cfo's).
    "DOTLESS_FLOAT_READ": "reads a dotless float such as 1e33 expecting syntax_error; SCRIP's default reads it as SWI does (the strict ISO reading is set_prolog_flag(iso, true))",
    # ceo CEO-1540 (2026-10-07): max_arity is an integer (ISO, GNU); at SCRIP's 2147483647 a case written for a small max_arity asks for a
    # structure no declared heap holds, and expects a representation_error where an engine raises resource_error (the cfo, 4f612be5d).
    "BOUNDED_MAX_ARITY_ONLY": "a condition(...) that holds only where max_arity is not unbounded, written for a system whose max_arity is small",
    # Lon via the ceo, CEO-1696 (2026-10-11, RULES.md section Oracles): "Exclude any program in which we have no way to get output from an
    # oracle, or in which we do not know the answer." The evidence checked on the case, either form: its goal calls a Logtalk SYSTEM
    # predicate (LOGTALK_SYSTEM below), which the oracle answers with existence_error; or (ceo CEO-1697) it builds a term by functor/3
    # with an arity literal of 20 or more digits (beyond 2^64) -- unbounded's functor_01/02 and arg_02/03 assert that a term of arity
    # ~1.8e45 is built, and swipl, whose max_arity is unbounded, raises representation_error(size_t): no run reproduces the answer.
    "NO_ORACLE_ANSWER": "no oracle answers the case: its goal calls a Logtalk system predicate no Prolog oracle has, or builds a term of an arity beyond 2^64 that no run builds",
}


def load_excluded(root):
    """{group:case: (class, reason)} from <root>/EXCLUDED_CASES.tsv; absent means none. A malformed line is NAMED, never skipped."""
    path = os.path.join(root, EXCLUDED_TABLE)
    out, bad = {}, []
    if not os.path.exists(path):
        return out, bad
    for n, line in enumerate(io.open(path, encoding="utf-8"), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        f = line.rstrip("\n").split("\t")
        if len(f) != 3 or ":" not in f[0] or f[1] not in EXCLUDED_CLASSES or not f[2].strip():
            bad.append((path, "line %d is not group:case<TAB>CLASS<TAB>condition with CLASS one of %s: %r"
                        % (n, "/".join(sorted(EXCLUDED_CLASSES)), line.rstrip()[:80])))
            continue
        if f[0] in out:
            bad.append((path, "line %d names %s a second time" % (n, f[0])))
            continue
        out[f[0]] = (f[1], f[2].strip())
    return out, bad


def _dotless_float_read(case):
    """The case reads a numeral with an exponent and no fraction (1e33, 1E33) and expects a syntax error."""
    return bool(re.search(r"set_text_input\('\d+[eE][+-]?\d+\. '\)", case.goal or "")) and "syntax_error" in (case.expect or "")


def _no_oracle_answer(case):
    g = case.goal or ""
    return any(k in LOGTALK_SYSTEM for k in called_predicates(g)) or bool(re.search(r"(?<![A-Za-z0-9_])functor\s*\([^()]*,\s*\d{20,}\s*\)", g))


def _bounded_max_arity_only(case):
    o = "".join((case.options or "").split())
    return "condition(\\+current_prolog_flag(max_arity,unbounded))" in o


def _bounded_only(case):
    o = "".join((case.options or "").split())
    return "condition(current_prolog_flag(bounded,true))" in o or "condition(verify_min_max_integers)" in o


def _clause_head_name(clause):
    """The functor a database clause defines, or None -- `foo(X) :- ...`, `foo :- ...`, `'q'(X).`"""
    m = re.match(r"\s*('(?:[^']|'')*'|[a-z][A-Za-z0-9_]*)", clause)
    return m.group(1) if m else None


def express_helper_clause(cl, supported):
    """A helper clause in Logtalk syntax as plain Prolog, or None. The SAME three rewrites a case's goal takes (action_goal):
    ^^helper -> the shim's lgt_helper, {Goal} -> (Goal), a LIB_MESSAGES message -> its shim predicate; anything left over (an
    unsupported ^^helper, any other Obj::Goal) keeps the clause unexpressible. cfo 2026-10-11 (CEO-1689): open_4's condition
    helpers create_no_read_permission_file and kin are written with os::operating_system_type, os::shell and ^^file_path, and
    were dropped whole, so lgt_open_4_27..30 read UNGRADED logtalk-only-helper-clause."""
    goal, bad = _rewrite_helpers(cl, supported)
    if bad is not None:
        return None
    goal, msg = _rewrite_messages(_braces_to_parens(goal))
    if msg is not None or LOGTALK_ONLY_SYNTAX.search(goal):
        return None
    return goal


def split_db(db, supported=None):
    """(plain-Prolog clauses, names dropped). A helper clause in Logtalk-only syntax that the case-goal rewrites cannot express
    (express_helper_clause; never tried when `supported` is None) is DROPPED rather than emitted -- and its name is returned,
    because a case that calls it must become UNGRADED-and-named rather than a silent existence_error red. The file's setup/0 and
    cleanup/0 hooks are expressed the same way (cfo 2026-10-14, the coo's ruling on CEO-1689: running them is upstream lgtunit
    behaviour): fifteen files define cleanup/0 with ^^clean_text_input and kin, and until this landing every one was dropped, so
    lgtunit's cleanup never ran after their cases."""
    keep, dropped = [], set()
    for cl in db:
        if LOGTALK_ONLY_SYNTAX.search(cl):
            g = express_helper_clause(cl, supported) if supported is not None else None
            if g is not None:
                keep.append(g)
                continue
            n = _clause_head_name(cl)
            if n:
                dropped.add(n)
            continue
        keep.append(cl)
    return keep, dropped


def dropped_in(text, dropped):
    """The dropped helper this goal TEXT would call, or None. Text-level so a PREFIX goal -- which never
    reaches plan.goal, only its '$lgt_preN' call does -- is tested by the same rule as the case's own goal."""
    for n in sorted(dropped):
        if text and re.search(r"(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % re.escape(n.strip("'")), text):
            return n
    return None


def calls_dropped(plan, dropped):
    """The dropped helper this plan would call, or None. Checked against the goal AS FINISHED, so a
    setup(...)/cleanup(...) option folded into the goal is covered by the same test."""
    return dropped_in(plan.goal or "", dropped) or dropped_in(plan.condition or "", dropped)


def shim_helpers(path=SHIM):
    """The helper names lib_logtalk_lgtunit.pl actually defines, read from the file itself."""
    out = set()
    for m in re.finditer(r"^lgt_([a-z_]+)\(", open(path, encoding="utf-8").read(), re.M):
        out.add(m.group(1))
    for m in re.finditer(r"^lgt_([a-z_]+) :-", open(path, encoding="utf-8").read(), re.M):
        out.add(m.group(1))
    return out


def lgtunit_aliases(path, supported):
    """Alias clauses for the names a file imports with `:- uses(lgtunit, [Name/Arity, ...])` (hq_prolog 2026-09-24).
    In Logtalk that directive makes a bare assertion(...) or variant(...) a call to lgtunit's own predicate; the extractor
    drops the directive with the rest of the object's scaffolding, so the bare call reached SCRIP as an undefined procedure
    and read as existence_error(procedure, assertion/2) -- 40 of the operators group's 44 reds were this, and none was the
    engine's. Each imported name the shim implements becomes `Name(A0,..) :- lgt_Name(A0,..)` beside the file's database:
    the call the directive routes, scoped to the file that declares it. An op(...) item is a declaration, not a predicate."""
    m = re.search(r":-\s*uses\(\s*lgtunit\s*,\s*\[(.*?)\]\s*\)", open(path, encoding="utf-8").read(), re.S)
    out = []
    for name, ar in (re.findall(r"(?<![\w(])([a-z_]+)/(\d+)", m.group(1)) if m else ()):
        if name in supported:
            a = ", ".join("A%d" % i for i in range(int(ar)))
            out.append("%s(%s) :- lgt_%s(%s)" % (name, a, name, a) if a else "%s :- lgt_%s" % (name, name))
    return out


def _braces_to_parens(s):
    """Logtalk's {Goal} escape -> plain (Goal). Quote-aware: a brace inside a quoted atom is data.
    ⛔ ONLY THE OUTERMOST BRACES ARE AN ESCAPE. Inside {Goal} the text is already plain Prolog, so a nested {a,b} is the curly TERM
    '{}'((a,b)) and must reach the engine as written -- rewriting it too turned {arg(1, {1,2,3}, A)} into arg(1, (1,2,3), A) and
    {write_canonical({a})} into write_canonical((a)), five curly_terms cases and arg_3 20 red on the harness's own edit (hq_prolog 2026-09-25)."""
    out = []
    i = 0
    n = len(s)
    depth = 0
    while i < n:
        j = ex._skip_token(s, i)
        if j != i:
            out.append(s[i:j])
            i = j
            continue
        ch = s[i]
        # ⛔ `{}` IS A TERM, NOT AN EMPTY ESCAPE. Logtalk's escape is {Goal}; the empty braces are the atom
        # `{}`, and rewriting them to `()` hands the parser a clause that cannot parse -- the case then reports
        # nooutput, which reads as the builtin under test failing rather than as the harness eating its argument.
        if ch == "{" and i + 1 < n and s[i + 1] == "}":
            out.append("{}")
            i += 2
            continue
        if ch == "{":
            out.append("(" if depth == 0 else "{")
            depth += 1
        elif ch == "}" and depth > 0:
            depth -= 1
            out.append(")" if depth == 0 else "}")
        else:
            out.append(ch)
        i += 1
    return "".join(out)


# Logtalk library messages a case sends as a HELPER (never as the subject under test), and the plain-Prolog
# shim predicate each becomes. Anything else of the form Obj::Goal cannot be expressed here, so the case is
# UNGRADED-and-named -- the alternative, emitting `list::member(...)` into a Prolog file, is a parse error that
# reads as the builtin under test failing (the harness-made-red class this runner's header is about).
# cfo 2026-10-11 (CEO-1689, the coo's terms: upstream only): os::, lgtunit::deterministic/2 and integer::between/3, each answered
# in lib_logtalk_lgtunit.pl by the clause upstream writes for the GNU Prolog backend (the shim names the files).
LIB_MESSAGES = (("list::member", "lgt_member"), ("os::operating_system_type", "lgt_os_operating_system_type"), ("os::shell", "lgt_os_shell"),
                ("os::file_exists", "lgt_os_file_exists"), ("os::ensure_file", "lgt_os_ensure_file"),
                ("lgtunit::deterministic", "lgt_lgtunit_deterministic"), ("integer::between", "lgt_integer_between"))


def _rewrite_messages(goal):
    """(goal with library messages rewritten, the first message left over or None)."""
    for k, v in LIB_MESSAGES:
        goal = re.sub(r"(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % re.escape(k), v, goal)
    m = re.search(r"([a-zA-Z0-9_]+\s*::\s*[a-zA-Z0-9_]+)", goal)
    return goal, (" ".join(m.group(1).split()) if m else None)


def _rewrite_helpers(goal, supported):
    """^^name(Args) -> lgt_h(lgt_name(Args)). Returns (goal, unsupported_helper_or_None)."""
    out = []
    i = 0
    n = len(goal)
    while i < n:
        j = ex._skip_token(goal, i)
        if j != i:
            out.append(goal[i:j])
            i = j
            continue
        if goal.startswith("^^", i):
            m = re.match(r"\^\^([a-z_]+)", goal[i:])
            name = m.group(1)
            if name not in supported:
                return None, name
            k = i + m.end()
            if k < n and goal[k] == "(":
                e = ex._close_paren(goal[k + 1:])
                if e is None:
                    return None, name
                args = goal[k + 1:k + 1 + e]
                out.append("lgt_h(lgt_%s(%s))" % (name, args))
                i = k + 1 + e + 1
            else:
                out.append("lgt_h(lgt_%s)" % name)
                i = k
            continue
        out.append(goal[i])
        i += 1
    return "".join(out), None


def _split_option(options):
    """Parse a test/3 option list into {condition,setup,cleanup}; unknown options are reported."""
    got = {}
    unknown = []
    if not options:
        return got, unknown
    t = options.strip()
    if not (t.startswith("[") and t.endswith("]")):
        return got, [t]
    for item in ex.split_args(t[1:-1]):
        item = item.strip()
        if not item:
            continue
        m = re.match(r"([a-z_]+)\s*\(", item)
        if not m:
            unknown.append(item)
            continue
        name = m.group(1)
        e = ex._close_paren(item[m.end():])
        if e is None:
            unknown.append(item)
            continue
        arg = item[m.end():m.end() + e]
        if name in ("condition", "setup", "cleanup"):
            got[name] = arg
        else:
            unknown.append(name)
    return got, unknown


class Plan(object):
    """How one case will be graded, or why it will not be."""
    __slots__ = ("case", "want", "goal", "balls", "weaker", "skip_reason", "condition", "prefix", "sequenced",
                 "outside_reason", "setup")

    def __init__(self, case, want=None, goal=None, balls=(), weaker=None, skip_reason=None):
        self.case = case
        self.want = want
        self.goal = goal
        self.balls = list(balls)
        self.weaker = weaker
        self.skip_reason = skip_reason
        self.outside_reason = None
        self.condition = None
        self.prefix = []          # earlier cases' goals, run before this one (see SEQ_TABLE above)
        self.sequenced = None     # the declared reason it needs them
        self.setup = None         # a declared SETUP goal run ahead of the case's own goal (CEO-1695), instead of the prefix


def action_goal(c, supported):
    """One case's GOAL as plain Prolog, with no expectation attached: (goal, None) or (None, why not).
    Shared with the prefix builder, which needs an earlier case's ACTION and never its check -- two copies of
    these three rewrites would be two places for the meaning to drift."""
    goal, bad = _rewrite_helpers(c.goal or "", supported)
    if bad is not None:
        return None, "lgtunit helper ^^%s is not implemented by lib_logtalk_lgtunit.pl" % bad
    goal = _braces_to_parens(goal)
    goal, msg = _rewrite_messages(goal)
    if msg is not None:
        return None, "Logtalk message %s in the goal is not expressible in plain Prolog" % msg
    return goal, None


def plan_case(c, supported):
    """Turn one extracted Case into a Plan: either an executable grading, or a NAMED refusal to grade."""
    # ⛔ ONLY A BODILESS test(Name). IS THE PLACEHOLDER (cfo 2026-10-05). lgtunit's test(Name) :- Goal is a test that must SUCCEED, the
    # test/1 dialect of test(Name, true); the extractor already tells the two apart (goal "" for the fact), but this check read every
    # test/1 as the placeholder, so the suite's 7 test/1 cases -- all with bodies, none bodiless -- sat UNGRADED as "declared and not
    # implemented": dynamic_1 x3, multifile_1 x3, operators iso_operators_15.
    if c.kind == "test" and not c.expect and not (c.goal or "").strip():
        return Plan(c, skip_reason="lgtunit test/1 placeholder: the suite declares this test and does not implement it")
    goal, why = action_goal(c, supported)
    if goal is None:
        return Plan(c, skip_reason=why)
    opts, unknown = _split_option(c.options)
    if unknown:
        return Plan(c, skip_reason="test/3 option(s) not understood: %s" % ",".join(unknown))
    # ⛔ THE LEGACY THREE ARE THE SAME THREE EXPECTATIONS SPELLED DIFFERENTLY -- succeeds == true,
    # fails == false, throws(Name,Ball) == the ball. They are normalised into the same expectation
    # vocabulary here rather than given their own grading path, because two paths that mean the same thing
    # are two places for the meaning to drift, and 349 of the 3617 cases (10%) ride on this one.
    if c.kind == "succeeds" or (c.kind == "test" and not c.expect):
        return _finish(c, "succ", goal, [], None, opts, supported)
    if c.kind == "fails":
        return _finish(c, "fail", goal, [], None, opts, supported)
    if True:
        e = (c.expect or "").strip()
        m = re.match(r"([a-z_]+)\s*(\()?", e)
        head = m.group(1) if m else ""
        arg = None
        if m and m.group(2):
            k = ex._close_paren(e[m.end():])
            if k is None:
                return Plan(c, skip_reason="expectation does not parse: %s" % e[:60])
            arg = e[m.end():m.end() + k]
        want, tail, balls, weaker = None, "", [], None
        if head == "true" and arg is None:
            want = "succ"
        elif head == "true":
            want, tail = "succ", ", (%s)" % arg
        elif head in ("false", "fail") and arg is None:
            want = "fail"
        elif head in ("false", "fail"):
            want, tail = "succ", ", \\+ (%s)" % arg
        elif head == "deterministic":
            want, weaker = "succ", "deterministic"
            tail = ", (%s)" % arg if arg else ""
        elif head == "exists":
            want = "succ"
            tail = ", (%s)" % arg if arg else ""
        elif head == "all":
            want, goal = "succ", "\\+ ( (%s), \\+ (%s) )" % (goal, arg)
        elif head == "variant" and arg is not None:
            a = ex.split_args(arg)
            if len(a) != 2:
                return Plan(c, skip_reason="variant/%d -- expected variant/2" % len(a))
            want, tail = "succ", ", lgt_variant(%s, %s)" % (a[0], a[1])
        elif head == "subsumes" and arg is not None:
            a = ex.split_args(arg)
            if len(a) != 2:
                return Plan(c, skip_reason="subsumes/%d -- expected subsumes/2" % len(a))
            want, tail = "succ", ", lgt_subsumes(%s, %s)" % (a[0], a[1])
        elif head == "error" and arg is not None:
            want, balls = "ball", ["error(%s, _)" % arg]
        elif head == "error_ball" and arg is not None:
            t = arg.strip()
            want = "ball"
            balls = [x for x in ex.split_args(t[1:-1]) if x.strip()] if t.startswith("[") and t.endswith("]") else [arg]
        elif head == "errors" and arg is not None:
            t = arg.strip()
            if not (t.startswith("[") and t.endswith("]")):
                return Plan(c, skip_reason="errors(...) argument is not a list: %s" % t[:50])
            want = "ball"
            balls = ["error(%s, _)" % x for x in ex.split_args(t[1:-1]) if x.strip()]
        elif head == "ball" and arg is not None:
            # throws(Name, [B1, B2]) lists the balls the suite accepts (the ISO one first, a common
            # alternative second): each is its own '$lgt_want' clause, never one clause over the list text
            t = arg.strip()
            want = "ball"
            balls = [x for x in ex.split_args(t[1:-1]) if x.strip()] if t.startswith("[") and t.endswith("]") else [arg]
        elif head == "balls" and arg is not None:
            t = arg.strip()
            want = "ball"
            balls = [x for x in ex.split_args(t[1:-1]) if x.strip()] if t.startswith("[") else [t]
        else:
            return Plan(c, skip_reason="expectation form not implemented: %s" % e[:60])
        if head != "all":
            goal = goal + _braces_to_parens(tail)
        return _finish(c, want, goal, balls, weaker, opts, supported)


def _finish(c, want, goal, balls, weaker, opts, supported=frozenset()):
    # ⛔ AN OPTION IS LOGTALK TEXT LIKE A TEST BODY, SO ITS {Goal} ESCAPE IS REWRITTEN THE SAME WAY (cfo 2026-10-05). Passed verbatim,
    # condition({predicate_property('*->'(_,_), built_in)}) called '{}'/1, raised existence_error({}/1), and the catch around '$lgt_cond'
    # read it as a false condition: predicate_property_2 22, 23, 29 and operators 57 sat UNGRADED as "the case's own condition(...) option
    # is false on this system" on an engine where every one of those conditions is true or false on its own merits; the 12 occurs_check
    # setup({set_prolog_flag(...)}) options would have died the same way once their :- if guard opens. probe_guards already did this.
    opts = dict((k, _braces_to_parens(v)) for k, v in opts.items())
    if opts.get("setup"):
        goal = "lgt_h((%s)), %s" % (opts["setup"], goal)
    if opts.get("cleanup"):
        goal = "%s, lgt_h((%s))" % (goal, opts["cleanup"])
    p = Plan(c, want=want, goal=goal, balls=balls, weaker=weaker)
    # A condition takes the goal's own rewrites, ^^helpers and LIB_MESSAGES (cfo 2026-10-11, CEO-1689): lgt_open_4_31's
    # condition(os::operating_system_type(unix)) reached the program verbatim and read "condition false" on every system.
    cond = opts.get("condition")
    if cond:
        cg, cbad = _rewrite_helpers(cond, supported)
        if cbad is None:
            cg, cmsg = _rewrite_messages(cg)
            if cmsg is None:
                cond = cg
    p.condition = cond
    return p


def program_text(plan, db, shim_src, loaded=()):
    c = plan.case
    parts = [shim_src]
    # ⭐ THE SUITE RUNS UNDER ISO'S OWN SWITCH (ceo CEO-1272, CEO-391: conflicts between ISO and the superset go through ISO's prolog flags, set by
    # the program or the suite runner). Placed after the shim, so the shim reads as before, and ahead of the file's database and the case, so both
    # read and run strictly: an argument over 999 is a syntax error (wg17_term_09/10) and 4 / 2 is 2.0 (float_division_2 13/14).
    parts.append(":- set_prolog_flag(iso, true).")
    # ⛔ The tester-loaded plain-Prolog files go in VERBATIM, ahead of the file's own database and without
    # the directive filter below: their :- if/elif/else/endif guards ARE the subject of one group, and
    # dropping a guard while keeping both of its branches defines exactly the predicates the case expects
    # to be undefined -- a silent semantic edit that turns 31 correct failures into 31 wrong successes.
    for cl in loaded:
        parts.append(cl + ".")
    for cl in db:
        if cl.startswith(":-"):
            m = re.match(r":-\s*([a-z_]+)", cl)
            if m and m.group(1) in DROP_DIRECTIVES:
                continue
        parts.append(cl + ".")
    parts.append("'$lgt_say'(V) :- write(user_output, '@V '), write(user_output, V), nl(user_output).")
    parts.append("'$lgt_say2'(V, B) :- write(user_output, '@V '), write(user_output, V), write(user_output, ' | '), "
                 "catch(writeq(user_output, B), _, write(user_output, '<unprintable>')), nl(user_output).")
    # ⛔ ALWAYS at least one '$lgt_want'/1 clause: a call to an undefined predicate raises existence_error,
    # which would be caught by the enclosing catch and reported as a ball the case never threw.
    parts.append("'$lgt_want'('$lgt_no_ball_expected_here').")
    for b in plan.balls:
        parts.append("'$lgt_want'(%s)." % b)
    # ⛔ ONE CLAUSE PER PREFIX GOAL, never a textual splice into the case's own goal: a clause's variables
    # are local to it, and case 03's X spliced beside case 04's X is ONE variable and a different program.
    for k, g in enumerate(plan.prefix or (), 1):
        parts.append("'$lgt_pre%d' :- %s." % (k, g))
    parts.append("'$lgt_cond' :- %s." % (plan.condition if plan.condition else "true"))
    parts.append("'$lgt_case' :- %s." % plan.goal)
    parts.append(
        "'$lgt_run' :- catch( ( catch('$lgt_cond', _, fail) -> "
        "catch( ( '$lgt_case' -> '$lgt_say'(succ) ; '$lgt_say'(fail) ), B, "
        "( B = '$lgt_harness'(_) -> '$lgt_say2'(harness, B) "
        "; '$lgt_want'(B) -> '$lgt_say'(ballmatch) "
        "; '$lgt_say2'(ballother, B) ) ) "
        "; '$lgt_say'(skipped) ), B2, '$lgt_say2'(toplevel, B2) ).")
    # ⭐ THE CASE RUNS AS AN initialization/1 GOAL, NOT A DIRECTIVE, because lgtunit runs its tests after the file is LOADED: a directive runs as it is
    # read, before any initialization goal, so a case whose loaded file asserts in :- initialization(...) -- directives initialization_1, whose
    # included files assertz(a(1)) and assertz(b(2)) -- saw an empty a/1. As the last initialization goal the case runs after every one the file
    # declares, in order. Measured over the whole suite on one binary: exactly those three cases move, 3410 -> 3413 (hq_prolog 2026-09-25).
    parts.append(":- initialization('$lgt_run').")
    return "\n".join(parts) + "\n"


# ⭐ THE DECLARED HEAP AND STACK, per case (Lon 2026-09-23 18:3x; CEO-1167, CEO-1225; wired by the coo on CEO-1229, the SWI runner's
# pattern). test_prolog_logtalk_suite.sh reads ALL.csv's heap_kb and stack_kb ONCE through lib_declared_arena.sh -- the one reader, its
# floors and refusals -- and hands the validated table here with --decl; a case runs in both modes at its own declaration, keyed
# <group>:<case name> exactly as util_prolog_iso_attributes.py writes the entry, and at the shipped default when it declares nothing.
def load_decl(path):
    """{"group:name": (heap_kb, stack_kb)} from the table lib_declared_arena.sh wrote (entry<TAB>heap<TAB>stack, validated there)."""
    out = {}
    for ln in open(path, encoding="utf-8"):
        e, kb, st = ln.rstrip("\n").split("\t")
        out[e] = (kb, st)
    return out


def decl_switches(decl, fc, plan):
    """The case's declared heap and stack as SPITBOL's switches, -d<kb>k and -s<kb>k (ceo CEO-1353, RULES.md clause 8 (g); the harness's
    _size_switches): after --run in m3 and leading the compiled binary's command line in m4. ⛔ NEVER SCRIP_HEAP_KB -- gc_heap.c reads it
    as the collector's initial WINDOW, so the declared maximum used to be handed over as a window and the cap stayed the default -- and
    never SCRIP_STACK, an environment knob a transcript cannot show. [] when the case declares nothing: its command line is unchanged."""
    kb, st = (decl or {}).get("%s:%s" % (fc.group, plan.case.name), ("", ""))
    return (["-d%sk" % kb] if kb else []) + (["-s%sk" % st] if st else [])


def run_one(plan, db, shim_src, scrip, mode, workroot, srcdir, timeout=10, loaded=(), sw=(), key=None):
    """Run one planned case in one mode. Returns (outcome, detail). `sw` is the case's declared heap and stack (decl_switches)."""
    d = tempfile.mkdtemp(prefix="lgtcase.", dir=workroot)
    try:
        # ⛔⭐ tests.lgt IS COPIED, AND THAT IS DELIBERATE (hq_R 2026-09-13, row prolog-logtalk-eleven-
        # unicode-stream-cases-routed-from-the-builtins-family-row). It used to be excluded alongside
        # tester.lgt on the reasonable-sounding rule "the test SOURCE is not a fixture" -- but
        # unicode/builtins cases 04 and 05 open `^^file_path('tests.lgt')` in read mode precisely BECAUSE
        # it is a known UTF-8 file with no BOM, which makes the suite's own source a genuine fixture for
        # exactly those two. Excluding it did not make them fail honestly: it made them throw
        # existence_error(source_sink,'tests.lgt'), a ball indistinguishable from an engine defect in
        # open/4, and an engine lane is where a harness defect sits red forever (cto 2026-09-13).
        # tester.lgt stays out -- grep the whole suite and no case names it (measured, not assumed).
        for f in os.listdir(srcdir):
            s = os.path.join(srcdir, f)
            if os.path.isfile(s) and f != "tester.lgt":
                try:
                    shutil.copy2(s, os.path.join(d, f))
                except OSError:
                    pass
        prog = os.path.join(d, "case.pl")
        open(prog, "w", encoding="utf-8").write(program_text(plan, db, shim_src, loaded))
        try:
            if mode == "m3":
                r = _ltr.run(retry=False, key=key, argv=[scrip, "--run"] + list(sw) + [prog], capture_output=True, text=True, errors="replace", timeout=timeout,
                                   stdin=subprocess.DEVNULL, cwd=d)
            else:
                s_out = os.path.join(d, "case.s")
                b_out = os.path.join(d, "case.bin")
                cp = _ltr.run(retry=False, key=key, argv=[scrip, "--compile", "-o", s_out, prog], capture_output=True, text=True, errors="replace",
                                    timeout=timeout, stdin=subprocess.DEVNULL, cwd=d)
                if cp.returncode != 0:
                    return "nobuild", (cp.stderr or cp.stdout).strip()[:160]
                rt = os.path.join(os.path.dirname(os.path.abspath(scrip)), "out")
                g = _ltr.run(retry=False, argv=["gcc", "-m64", "-no-pie", s_out, "-o", b_out, "-L", rt, "-lscrip_rt",
                                    "-Wl,-rpath," + rt, "-lm"], capture_output=True, text=True, errors="replace", timeout=120, cwd=d)
                if g.returncode != 0:
                    return "nolink", (g.stderr or "").strip()[:160]
                r = _ltr.run(retry=False, key=key, argv=[b_out] + list(sw), capture_output=True, text=True, errors="replace", timeout=timeout,
                                   stdin=subprocess.DEVNULL, cwd=d)
        except subprocess.TimeoutExpired:
            return "timeout", ""
        for line in r.stdout.splitlines():
            if line.startswith("@V "):
                rest = line[3:]
                if " | " in rest:
                    a, b = rest.split(" | ", 1)
                    return a.strip(), b.strip()[:160]
                return rest.strip(), ""
        # ⛔ NO VERDICT LINE IS NOT A ZERO AND IT IS NOT A PASS. It is the compiler refusing the program
        # (an ISO builtin this engine does not have yet), or the program dying. Both are real reds for the
        # case -- but they are reported with the reason attached, because "no output" read as FAIL with no
        # explanation is how a whole missing builtin family hides inside a percentage.
        err = (r.stderr or r.stdout).strip().splitlines()
        return "nooutput", (err[0][:160] if err else "rc=%d, no @V line" % r.returncode)
    finally:
        shutil.rmtree(d, ignore_errors=True)


def _rewrite_hook(clean, name, supported):
    """Rewrite the file's setup/0 or cleanup/0 clause in place as a plain-Prolog goal; True when it is injectable."""
    for i, cl in enumerate(clean):
        m = re.match(r"%s\s*(?::-\s*(.*))?$" % name, cl, re.S)
        if not m:
            continue
        body = (m.group(1) or "true").strip()
        goal, bad = _rewrite_helpers(body, supported)
        if bad is not None:
            return False
        clean[i] = "%s :- %s" % (name, _braces_to_parens(goal))
        return True
    return False


def _sweep(work, results, where, builders, dbs, shim_src, scrip, modes, workroot, jobs, decl=None):
    """THE DIAGNOSTIC THAT FINDS THE NEXT ONE -- never a grading path, and it can never move the board.
    Every case that FAILS in every graded mode is re-run ONCE with its file's earlier cases ahead of it; the
    ones that flip to PASS are the candidates for a lib_logtalk_sequenced.tsv line, printed for a human to
    declare with a reason. ⛔ IT DOES NOT DECLARE THEM ITSELF. An automatic retry-with-prefix that counted as a
    pass would turn a real engine defect into a green cell the first time a neighbour's state happened to
    mask it -- the flattering direction, and the reason the table is data a person signs."""
    todo = []
    for i, (fc, p) in enumerate(work):
        if p.skip_reason is not None or p.sequenced is not None or where.get(i, (None, 0))[1] == 0:
            continue
        if all(verdict(p, results[(i, m)][0])[0] == "FAIL" for m in modes):
            q = builders[fc.path](p.case, where[i][1], True)
            if q.skip_reason is None:
                todo.append((i, fc, q))
    out = []
    for mode in modes:
        def job(t):
            i, fc, q = t
            try:
                return i, run_one(q, dbs[fc.path], shim_src, scrip, mode, workroot, os.path.dirname(fc.path),
                                  loaded=fc.loaded or (), sw=decl_switches(decl, fc, q), key="%s:%s" % (fc.group, q.case.name))
            except Exception as e:                          # noqa: BLE001 -- one case never takes a run down
                return i, ("harness", "%s: %s" % (type(e).__name__, e))
        with ThreadPoolExecutor(max_workers=jobs) as pool:
            got = dict(pool.map(job, todo))
        todo = [(i, fc, q) for i, fc, q in todo
                if verdict(q, got[i][0])[0] == "PASS"]      # a candidate must flip in EVERY graded mode
    for i, fc, _q in todo:
        out.append((fc.group, work[i][1].case.name))
    return out



# ⛔⭐ THE PER-CASE OUTSIDE ASSIGNER (cto ruling 2026-09-13, on hq_C's encodings census; RULES.md FACT RULE
# CEO-542: OUTSIDE-THE-BASELINE IS ABOUT THE ORACLE, NEVER ABOUT US). A program the oracle cannot run is
# outside the baseline; a program it CAN run is ours and any gap in it is ours. This assigns that per CASE.
#
# WHY PER CASE AND NOT PER FILE. UNGRADABLE.tsv already declares 208 tester.lgt files CONTAINER_OR_LIBRARY
# for needing the Logtalk runtime, and it reads as if that dependency were fully accounted for. It is not:
# unicode/encodings/tests.lgt -- the ONLY tests.lgt of all 192 that does this -- holds 40 CASES with the
# identical dependency, inside a graded file, so they sat in the denominator and read as 40 cases of engine
# work when the group's real ceiling was 9 of 49. ⭐ The census answered WHICH FILES ARE DRIVERS and was read
# as WHICH CASES NEED THE RUNTIME. Same dependency, different granularity, and the artifact could not say
# which question it had answered.
#
# ⛔ THE RULING DOES NOT LAND WITHOUT THIS INSTRUMENT, AND THAT IS THE POINT OF WRITING IT FIRST. Moving 40
# cases out of a denominator by prose, with nothing that can recompute the move, would read as a 9-of-9 green
# forever and nothing in the output would distinguish it from the day it was load-bearing.
#
# ⛔ IT REFUSES TO GUESS. A case is OUTSIDE only when a predicate it calls is measured ABSENT FROM THE ORACLE
# and is resolved to a provider we do not have -- a Logtalk system predicate, or a fixture .lgt that only
# logtalk_load could bring in. Anything else STAYS IN and is counted as UNRESOLVED and named, because an
# audit that cannot say how many subjects it failed to resolve is not a measurement. With no oracle present
# NOTHING is assigned and every case stays IN: an assigner that gets more generous when it can measure less
# is the criterion that improves as the work becomes less measurable.
LOGTALK_SYSTEM = (("logtalk_compile", 1), ("logtalk_compile", 2), ("logtalk_load", 1), ("logtalk_load", 2),
                  ("logtalk_load_context", 2), ("logtalk_make", 0), ("logtalk_make", 1),
                  ("create_object", 4), ("create_protocol", 3), ("create_category", 4),
                  ("abolish_object", 1), ("abolish_protocol", 1), ("abolish_category", 1))
CALL_RE = re.compile(r"(?<![A-Za-z0-9_])([a-z][A-Za-z0-9_]*)\s*\(")
DEF_RE = r"(?<![A-Za-z0-9_])%s\s*\("


def oracle_binary():
    for c in ("/usr/bin/swipl", "swipl"):
        if os.path.isabs(c):
            if os.access(c, os.X_OK):
                return c
        elif shutil.which(c):
            return shutil.which(c)
    return None


def oracle_has(swipl, name, arity, cache):
    """Does the ORACLE have this predicate? None when it could not be asked -- never guessed either way."""
    key = (name, arity)
    if key in cache:
        return cache[key]
    g = ("( catch(( current_predicate(%s/%d) ; functor(H,%s,%d), predicate_property(H,built_in) ),_,fail)"
         " -> write(has) ; write(lacks) ), nl, halt" % (name, arity, name, arity))
    try:
        r = _ltr.run([swipl, "-q", "-g", g], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                           timeout=20)
        out = r.stdout.decode("utf-8", "replace").strip()
    except Exception:
        out = ""
    v = True if out == "has" else (False if out == "lacks" else None)
    cache[key] = v
    return v


def called_predicates(text):
    """(name, arity) for every call spelled in a goal. Over-collects rather than under-collects: a name it
    wrongly includes ends up UNRESOLVED and keeps its case IN, which is the safe direction."""
    out = set()
    for m in CALL_RE.finditer(text or ""):
        e = ex._close_paren(text[m.end():])
        if e is None:
            continue
        try:
            n = len(ex.split_args(text[m.end():m.end() + e]))
        except Exception:
            continue
        out.add((m.group(1), n))
    return out


def fixture_text(path):
    """⛔ THE FIXTURES OF THIS GROUP ARE THE ENCODINGS THEMSELVES, AND GUESSING WRONG FAILS SILENTLY. Reading
    a provider as UTF-8 to learn which predicate it defines fails on exactly the UTF-16/UTF-32 files the group
    exists to exercise. ⭐ AND THE OBVIOUS GUARD DOES NOT WORK: a UTF-16BE file with no BOM decoded as UTF-16LE
    yields plausible text with NO NUL characters at all, so a "reject it if it has NULs" test passes it and the
    predicate simply is not found -- the case then reports UNRESOLVED, which reads as the assigner being
    careful rather than as the assigner being wrong. Measured: 4 of the 20 fixture-backed cases sat in that
    hole. So every candidate is decoded and SCORED, and the one that looks most like source wins."""
    try:
        b = io.open(path, "rb").read()
    except Exception:
        return ""
    best, best_score = "", -1.0
    for enc in ("utf-8-sig", "utf-16", "utf-16-be", "utf-16-le", "utf-32", "utf-32-be", "utf-32-le", "utf-8"):
        try:
            t = b.decode(enc)
        except Exception:
            continue
        if not t:
            continue
        good = sum(1 for c in t if c == "\n" or c == "\t" or " " <= c <= "~")
        score = float(good) / len(t)
        if score > best_score:
            best, best_score = t, score
    return best


def assign_outside(work, dbs, supported, root):
    """Set p.outside_reason per case. Returns (assigned, unresolved_names, why_not) -- why_not is the one
    stated reason nothing could be assigned, or None."""
    swipl = oracle_binary()
    if not swipl:
        return 0, [], ("no oracle on this machine, so NOTHING is outside -- every case stays IN and in the "
                       "denominator, because outside-the-baseline is a measurement of the oracle (CEO-542)")
    cache = {}
    fixtures = {}
    assigned = 0
    unresolved = []
    for fc, p in work:
        if p.outside_reason is not None:
            continue
        # ⛔ THE GOAL, NEVER THE RAW CASE. raw carries lgtunit's own scaffolding -- test/2, true/1,
        # condition/1, clean/1 -- none of which the oracle has, all of which would read as unresolved
        # dependencies and bury the real ones. Measured: scanning raw produced 135 unresolved lines naming
        # the harness instead of the subject.
        body = p.case.goal or ""
        own = dbs.get(fc.path) or ""
        if not isinstance(own, str):
            own = "\n".join(x if isinstance(x, str) else str(x) for x in own)
        d = os.path.dirname(fc.path)
        if d not in fixtures:
            fixtures[d] = [f for f in sorted(glob.glob(os.path.join(d, "*.lgt")))
                           if os.path.basename(f) not in ("tests.lgt", "tester.lgt")]
        pending = []
        for (nm, ar) in sorted(called_predicates(body)):
            if re.search(DEF_RE % re.escape(nm), own) or nm in supported:
                continue
            has = oracle_has(swipl, nm, ar, cache)
            if has is None or has:
                continue
            if (nm, ar) in LOGTALK_SYSTEM:
                p.outside_reason = ("%s/%d is a Logtalk SYSTEM predicate and the oracle raises "
                                    "existence_error on it -- no Logtalk runtime ships here" % (nm, ar))
                break
            prov = None
            for f in fixtures[d]:
                try:
                    if re.search(DEF_RE % re.escape(nm), fixture_text(f)):
                        prov = os.path.basename(f)
                        break
                except Exception:
                    continue
            if prov and p.setup and prov in p.setup:
                continue
            if prov:
                p.outside_reason = ("%s/%d is defined only in %s, which nothing but logtalk_load/1-2 can "
                                    "bring in, and the oracle lacks it" % (nm, ar, prov))
                break
            pending.append("%s:%s calls %s/%d, which the oracle lacks and this assigner could not resolve "
                           "to a provider -- STAYS IN" % (fc.group, p.case.name, nm, ar))
        # ⛔ AN UNRESOLVED NAME ON A CASE THAT DID RESOLVE IS NOISE ABOUT A CASE NOBODY NEEDS TO LOOK AT. The
        # scan reads option terms as calls (clean/1 out of logtalk_load(P,[clean(on)])), which is the safe
        # direction, but reporting them beside the genuinely unresolved ones buries the list that matters.
        if p.outside_reason is not None:
            assigned += 1
        else:
            unresolved.extend(pending)
    return assigned, unresolved, None

def _run_text(text, scrip, mode, timeout=20):
    """stdout of one plain-Prolog program in one mode, or None when it did not build or run to completion."""
    d = tempfile.mkdtemp(prefix="lgtprobe.")
    try:
        prog = os.path.join(d, "probe.pl")
        open(prog, "w", encoding="utf-8").write(text)
        try:
            if mode == "m3":
                r = _ltr.run([scrip, prog], capture_output=True, text=True, errors="replace", timeout=timeout,
                                   stdin=subprocess.DEVNULL, cwd=d)
            else:
                s_out, b_out = os.path.join(d, "probe.s"), os.path.join(d, "probe.bin")
                cp = _ltr.run([scrip, "--compile", "-o", s_out, prog], capture_output=True, text=True, errors="replace",
                                    timeout=timeout, stdin=subprocess.DEVNULL, cwd=d)
                if cp.returncode != 0:
                    return None
                rt = os.path.join(os.path.dirname(os.path.abspath(scrip)), "out")
                g = _ltr.run(["gcc", "-m64", "-no-pie", s_out, "-o", b_out, "-L", rt, "-lscrip_rt", "-Wl,-rpath," + rt, "-lm"],
                                   capture_output=True, text=True, errors="replace", timeout=120, cwd=d)
                if g.returncode != 0:
                    return None
                r = _ltr.run([b_out], capture_output=True, text=True, errors="replace", timeout=timeout,
                                   stdin=subprocess.DEVNULL, cwd=d)
        except subprocess.TimeoutExpired:
            return None
        return r.stdout
    finally:
        shutil.rmtree(d, ignore_errors=True)


# ⭐ THE GUARDS NO STATIC RULE DECIDES ARE ASKED OF THE BINARY UNDER TEST (ex.PROBED's header says why). Each runs once per graded mode
# inside the shim, as the case programs do, with Logtalk's {Goal} escape read as plain (Goal); an exception reads as FALSE, which is the
# answer a backend gives a guard it cannot run. A guard the modes answer differently, a guard naming a Logtalk message (:: or ^^), and
# a probe that did not run to its last line stay UNDECIDED -- both branches graded, as before -- and every decision is printed.
def probe_guards(root, scrip, modes, shim_src):
    files, _bad = ex.parse_suite(root)
    texts = sorted({u for fc in files for u in (fc.undecided or ()) if "::" not in u and "^^" not in u})
    if not texts:
        return
    parts = [shim_src]
    for k, t in enumerate(texts):
        parts.append("'$lgt_guard%d' :- %s." % (k, _braces_to_parens(t)))
    for k in range(len(texts)):
        parts.append(":- ( catch('$lgt_guard%d', _, fail) -> write(user_output, '@G %d true') ; write(user_output, '@G %d false') ), "
                     "nl(user_output)." % (k, k, k))
    text = "\n".join(parts) + "\n"
    seen = {}
    modes = [m for m in (modes.split(",") if isinstance(modes, str) else modes) if m]
    for mode in modes:
        out = _run_text(text, scrip, mode)
        got = dict(re.findall(r"^@G (\d+) (true|false)$", out or "", re.M))
        for k in range(len(texts)):
            seen.setdefault(k, []).append(got.get(str(k)))
    for k, t in enumerate(texts):
        vs = set(seen.get(k, [None]))
        if len(vs) == 1 and None not in vs:
            ex.PROBED[t] = (vs.pop() == "true")
            print("GUARD PROBED on this binary (%s agree): %s -> %s" % (",".join(modes), t[:120], "TRUE" if ex.PROBED[t] else "FALSE"))
        else:
            print("GUARD UNDECIDED (the probe answered %s over %s): %s -- both branches stay in the population" % (seen.get(k), ",".join(modes), t[:120]))


def grade(root, scrip, modes, jobs=8, limit=None, only_group=None, seq_table=SEQ_TABLE, sweep=False, decl=None, only=None):
    # ⛔ ABSOLUTE, AND CHECKED HERE. Every case runs with cwd set to its own scratch directory, so a
    # relative binary path ("./scrip", the obvious thing to type) resolves against the scratch dir and is
    # not there. Measured 2026-09-12: it does not raise anything a reader would notice -- every case comes
    # back as a harness refusal and the board prints a complete, plausible, entirely UNGRADED table.
    scrip = os.path.abspath(scrip)
    if not os.access(scrip, os.X_OK):
        return None, [(scrip, "no executable compiler at this path -- a missing binary prints a full, "
                              "plausible, entirely false board rather than nothing")]
    shim_src = open(SHIM, encoding="utf-8").read()
    # ⛔ NO GUARD IS PROBED (Lon 2026-10-05, CEO-1518: "We do want ALL test programs to run."): the four engine guards probe_guards()
    # decided took one branch of each pair out of the population; both branches are graded now, as before CEO-1266.
    files, bad = ex.parse_suite(root)
    if bad:
        return None, bad
    seq_setups = {}
    sequenced, seqbad = load_sequenced(seq_table, seq_setups)
    if seqbad:
        return None, seqbad
    excluded, exbad = load_excluded(root)
    if exbad:
        return None, exbad
    excl_hits = []                # (group:case, class, condition) -- every row the suite honoured, printed on the board
    exerr = []                    # (group:case, why) -- an exclusion the suite contradicts; it REFUSES, never warns
    supported = shim_helpers()
    work = []
    probes = []                   # (index into work, the SAME case planned standalone) -- the policing arm
    where = {}                    # index into work -> (file, the case's position in that file)
    seqerr = []                   # declarations this suite contradicts; they REFUSE, never warn
    seqseen = set()
    # ⛔ THE DATABASE IS SPLIT BEFORE ANY CASE IS PLANNED, per file: the plain-Prolog clauses travel with
    # every case, the Logtalk-only ones are dropped AND NAMED, and a case that would have called one is
    # UNGRADED with that name instead of being graded against a program that does not parse.
    dbs = {}
    drops = {}
    builders = {}                 # path -> the planner for that file, so the sweep never re-derives one
    for fc in files:
        if only_group and fc.group != only_group:
            continue
        clean, dropped = split_db(fc.db, supported)
        clean = clean + lgtunit_aliases(fc.path, supported)
        dbs[fc.path] = clean
        drops[fc.path] = dropped
        # lgtunit runs the object's own setup/0 before its tests and cleanup/0 after them; every case here is
        # its own process, so each case carries the file's hooks around its own goal. A hook body is Logtalk
        # text like a test body ({...} and ^^helpers), so it is rewritten the same way; a hook whose helper the
        # shim lacks is not injected at all (measured 2026-09-12: setup_call_cleanup_3's `setup :- {retractall(v(_))}`
        # ran verbatim, raised existence_error({}/1) and turned 22 passing cases UNGRADED). setup is strict --
        # lgtunit skips the set when it fails -- and cleanup is soft: its outcome never grades a test.
        has_setup = _rewrite_hook(clean, "setup", supported)
        has_cleanup = _rewrite_hook(clean, "cleanup", supported)

        def build(c, idx, want_prefix, fc=fc, dropped=dropped, has_setup=has_setup, has_cleanup=has_cleanup):
            """One plan for one case. want_prefix wires this file's EARLIER cases ahead of it (SEQ_TABLE)."""
            p = plan_case(c, supported)
            setup = seq_setups.get((fc.group, c.name))
            if p.skip_reason is None and want_prefix and setup:
                p.setup = setup
                p.goal = "%s, %s" % (setup, p.goal)
            elif p.skip_reason is None and want_prefix and idx > 0:
                pre = []
                for e in fc.cases[:idx]:
                    g, why = action_goal(e, supported)
                    n = dropped_in(g, dropped) if (g is not None and dropped) else None
                    if g is None or n is not None:
                        p.skip_reason = ("sequenced-prefix-not-expressible: this case is graded with its file's "
                                         "earlier cases run first and %s cannot be expressed here (%s)"
                                         % (e.name, why if g is None else "it calls %s, a clause this file "
                                            "defines in Logtalk message-sending syntax" % n))
                        break
                    pre.append(g)
                if p.skip_reason is None:
                    p.prefix = pre
                    p.goal = "%s, %s" % (", ".join("ignore(catch('$lgt_pre%d', _, true))" % (k + 1)
                                                   for k in range(len(pre))), p.goal)
            if p.skip_reason is None:
                if has_setup:
                    p.goal = "lgt_h(setup), %s" % p.goal
                if has_cleanup:
                    p.goal = "%s, ignore(catch(cleanup, _, true))" % p.goal
            if p.skip_reason is None and dropped:
                n = calls_dropped(p, dropped)
                if n is not None:
                    p.skip_reason = ("logtalk-only-helper-clause: this file defines %s in Logtalk "
                                     "message-sending syntax, which has no plain-Prolog form here" % n)
            return p

        builders[fc.path] = build
        for idx, c in enumerate(fc.cases):
            # A BOUNDED_INTEGERS_ONLY row takes its live case out before it is planned; a WINDOWS_ONLY row names a guarded-out
            # branch and never the live unix branch that carries the same name, so it is judged below, against the dead names.
            xk = "%s:%s" % (fc.group, c.name)
            xr = excluded.get(xk)
            if xr is not None and xr[0] == "BOUNDED_INTEGERS_ONLY":
                if not _bounded_only(c):
                    exerr.append((xk, "is excluded BOUNDED_INTEGERS_ONLY and its options %r carry no condition that needs "
                                      "bounded integers -- the row is stale or names the wrong case" % (c.options or "")))
                    continue
                excl_hits.append((xk, xr[0], xr[1]))
                continue
            if xr is not None and xr[0] == "BOUNDED_MAX_ARITY_ONLY":
                if not _bounded_max_arity_only(c):
                    exerr.append((xk, "is excluded BOUNDED_MAX_ARITY_ONLY and its options %r carry no condition that needs a "
                                      "max_arity that is not unbounded -- the row is stale or names the wrong case" % (c.options or "")))
                    continue
                excl_hits.append((xk, xr[0], xr[1]))
                continue
            if xr is not None and xr[0] == "NO_ORACLE_ANSWER":
                if not _no_oracle_answer(c):
                    exerr.append((xk, "is excluded NO_ORACLE_ANSWER and its goal %r neither calls a Logtalk system predicate nor builds a "
                                      "term of an arity beyond 2^64 -- the row is stale or names the wrong case" % ((c.goal or "")[:80],)))
                    continue
                excl_hits.append((xk, xr[0], xr[1]))
                continue
            if xr is not None and xr[0] == "DOTLESS_FLOAT_READ":
                if not _dotless_float_read(c):
                    exerr.append((xk, "is excluded DOTLESS_FLOAT_READ and its goal %r does not read a dotless float expecting "
                                      "syntax_error -- the row is stale or names the wrong case" % ((c.goal or "")[:80],)))
                    continue
                excl_hits.append((xk, xr[0], xr[1]))
                continue
            reason = sequenced.get((fc.group, c.name))
            p = build(c, idx, reason is not None)
            if reason is not None:
                seqseen.add((fc.group, c.name))
                if idx == 0:
                    seqerr.append((fc.group, c.name, "is declared order-dependent and is the FIRST case in its "
                                   "file -- there is no prefix to run, so the line grades nothing differently "
                                   "and tells a reader something untrue"))
                elif p.skip_reason is None:
                    p.sequenced = reason
                    probes.append((len(work), build(c, idx, False)))
            where[len(work)] = (fc, idx)
            work.append((fc, p))
    # ⛔ A DECLARATION WHOSE GROUP IS HERE AND WHOSE CASE IS NOT is a renamed or deleted case, and it must not
    # rot as a line nobody reads. Only groups actually graded are judged, so --group and a scratch fixture do
    # not turn every other declaration into a refusal.
    graded_groups = {fc.group for fc in files if not (only_group and fc.group != only_group)}
    for (g, nm), _r in sorted(sequenced.items()):
        if g in graded_groups and (g, nm) not in seqseen:
            seqerr.append((g, nm, "is declared order-dependent and its group was graded, but no case of that "
                           "name is in it -- the case was renamed or deleted and the declaration is stale"))
    # ⛔ A DECLARATION THAT NAMES NO GRADED CASE IS REFUSED, the table's twin of the order-dependence check above: a renamed or
    # deleted case would otherwise leave its heap or stack declared for nothing while the receipt counted it as honoured.
    _keys = {"%s:%s" % (fc.group, p.case.name) for fc, p in work}
    # ⭐ A CASE A :- if(...) GUARD DECIDES FALSE IS STILL A VENDORED CASE, SO ITS DECLARATION IS NOT AN ORPHAN -- and it is NAMED here,
    # per guard, on the board. ⛔⭐ AND IT IS EXCLUDED BY NAME OR THE BOARD REFUSES (Lon 2026-10-05, CEO-1518: "We have NO expected
    # failures."): the only guards that may take a case out are the Windows branch, each one a WINDOWS_ONLY row of EXCLUDED_CASES.tsv,
    # and the sibling branch of a guard the ceo RULED (util_logtalk_extract.RULED, CEO-1524), each one an EXCLUSIVE_BRANCH row.
    _dead = {}
    for fc in files:
        if fc.group in graded_groups:
            for nm, why in (fc.dead_names or ()):
                _dead.setdefault(why, []).append("%s:%s" % (fc.group, nm))
    for why, ks in sorted(_dead.items(), key=lambda x: -len(x[1])):
        print("GUARDED OUT (a :- if(...) this system decides FALSE, out of the population and named): %d case(s) under %s -- %s"
              % (len(ks), why, " ".join(ks)))
        for k in ks:
            xr = excluded.get(k)
            if xr is not None and xr[0] == "WINDOWS_ONLY" and "operating_system_type(windows)" in why:
                excl_hits.append((k, xr[0], xr[1]))
            elif xr is not None and xr[0] == "EXCLUSIVE_BRANCH" and ex.ruled_guard(why) is not None:
                excl_hits.append((k, xr[0], xr[1]))
            else:
                exerr.append((k, "a :- if(...) takes this case out (%s) and no WINDOWS_ONLY or EXCLUSIVE_BRANCH row of %s names it -- "
                                 "every case is graded or excluded by name" % (why, EXCLUDED_TABLE)))
    _hit_keys = {k for k, _c, _r in excl_hits}
    for k, (cls, _r) in sorted(excluded.items()):
        if k.split(":", 1)[0] in graded_groups and k not in _hit_keys:
            exerr.append((k, "is excluded %s and the suite has no such case %s -- the row is stale or names the wrong case"
                             % (cls, {"WINDOWS_ONLY": "behind a Windows guard", "EXCLUSIVE_BRANCH": "behind a ruled guard",
                                      "DOTLESS_FLOAT_READ": "reading a dotless float",
                                      "BOUNDED_MAX_ARITY_ONLY": "carrying a bounded-max_arity condition"}.get(cls, "carrying a bounded-integers condition"))))
    if exerr:
        return None, [(k, why) for k, why in exerr]
    _dead_keys = {k for ks in _dead.values() for k in ks} | _hit_keys
    _orphan = sorted(k for k in (decl or {}) if k.split(":", 1)[0] in graded_groups and k not in _keys and k not in _dead_keys)
    if _orphan:
        return None, [(k, "ALL.csv declares a heap or stack for this case and no case of that name is graded in its group -- "
                          "the declaration would apply to nothing") for k in _orphan]
    # ⭐ EVERY CASE'S PROGRESS KEY IS group:case, with #n in occurrence order when the population holds the name more than once -- counted over
    # the WHOLE population before --only narrows it, so a round-robin part writes the key a whole run writes (CEO-1802). The ordinal is per-key
    # occurrence order, not the global index, so adding or removing an unrelated case cannot renumber a survivor.
    _kc = {}
    for fc, p in work:
        _k = "%s:%s" % (fc.group, p.case.name)
        _kc[_k] = _kc.get(_k, 0) + 1
    progkey, _seen = {}, {}
    for i, (fc, p) in enumerate(work):
        _k = "%s:%s" % (fc.group, p.case.name)
        if _kc[_k] > 1:
            _seen[_k] = _seen.get(_k, 0) + 1
            progkey[i] = "%s#%d" % (_k, _seen[_k])
        else:
            progkey[i] = _k
    if only is not None:
        # ⭐ --only (the round robin's seam, CEO-1802/1806): grade the cases whose group:case the list names, every instance of a repeated name
        _keep = [i for i, (fc, p) in enumerate(work) if "%s:%s" % (fc.group, p.case.name) in only]
        _re = {o: n for n, o in enumerate(_keep)}
        work = [work[i] for i in _keep]
        where = {_re[i]: v for i, v in where.items() if i in _re}
        probes = [(_re[i], q) for i, q in probes if i in _re]
        progkey = {_re[i]: k for i, k in progkey.items() if i in _re}
    if limit:
        work = work[:limit]
        probes = [(i, q) for i, q in probes if i < limit]
    outside_n, outside_unresolved, outside_off = assign_outside(work, dbs, supported, root)
    workroot = tempfile.mkdtemp(prefix="lgtsuite.")
    results = {}
    probe_results = {}
    case_secs = {}   # (work index, mode) -> the case's own wall seconds in that mode, for its progress row (CEO-1676 (c))
    retried = {}     # mode -> (cases that timed out, the first limit, the long limit, how many timed out again)
    try:
        for mode in modes:
            # ⛔ THE POLICING ARM RUNS IN THE SAME PASS AS THE BOARD, on the same binary and the same tree. A
            # declaration checked by a separate invocation is a declaration checked against a different run.
            todo = [(("w", i), fc, p) for i, (fc, p) in enumerate(work)
                    if p.skip_reason is None and p.outside_reason is None]
            todo += [(("p", j), work[i][0], q) for j, (i, q) in enumerate(probes) if q.skip_reason is None]
            def job(t, to=float(os.environ.get("LOGTALK_TIMEOUT", "10"))):
                # ⛔ ONE CASE MUST NEVER TAKE THE RUN DOWN. A harness exception here (the unicode family
                # writes UTF-16/32 bytes to stdout, which killed the first full run on a decode error) is
                # the harness failing, not the case -- it is reported as such and the other 3616 still get
                # measured. A runner that dies at case 900 publishes nothing at all.
                k, fc, p = t
                t0 = time.monotonic()
                try:
                    return k, run_one(p, dbs[fc.path], shim_src, scrip, mode, workroot, os.path.dirname(fc.path), timeout=to,
                                      loaded=fc.loaded or (), sw=decl_switches(decl, fc, p), key="%s:%s" % (fc.group, p.case.name)), \
                        time.monotonic() - t0
                except Exception as e:                      # noqa: BLE001 -- deliberately broad, see above
                    return k, ("harness", "%s: %s" % (type(e).__name__, e)), time.monotonic() - t0
            with ThreadPoolExecutor(max_workers=jobs) as pool:
                for k, res, secs in pool.map(job, todo):
                    (results if k[0] == "w" else probe_results)[(k[1], mode)] = res
                    if k[0] == "w":
                        case_secs[(k[1], mode)] = secs
            # ⛔⭐ A TIMEOUT IS NOT A VERDICT UNTIL IT HAS BEEN RETRIED LONGER (Lon 2026-10-15 15:3x CDT, in-chat to the coo,
            # verbatim: "So timeout SHOULD NOT count as valid." and "The strategy should be to accumulate a list of timeouts, and
            # do a retry with longer timeouts."). Measured: the 52f822b69 pass ran 9318 s at load 19-21 on 16 cores and 344 of
            # its 361 m4 reds were 10 s timeouts. Every case that timed out is re-run once after the pass, at LOGTALK_RETRY_TIMEOUT
            # seconds (default lib_timeout_retry.longer: 60 s for the 10 s limit) on LOGTALK_RETRY_JOBS workers (default 2); the
            # retry's outcome is the case's outcome, and only a case that times out again at the long limit is graded a timeout.
            slow = [t for t in todo if (results if t[0][0] == "w" else probe_results)[(t[0][1], mode)][0] == "timeout"]
            if slow:
                long_to = float(os.environ.get("LOGTALK_RETRY_TIMEOUT") or _ltr.longer(float(os.environ.get("LOGTALK_TIMEOUT", "10"))))
                with ThreadPoolExecutor(max_workers=max(1, int(os.environ.get("LOGTALK_RETRY_JOBS", "2")))) as pool:
                    for k, res, secs in pool.map(lambda t: job(t, long_to), slow):
                        (results if k[0] == "w" else probe_results)[(k[1], mode)] = res
                        if k[0] == "w":
                            case_secs[(k[1], mode)] = secs
                still = sum(1 for t in slow if (results if t[0][0] == "w" else probe_results)[(t[0][1], mode)][0] == "timeout")
                retried[mode] = (len(slow), os.environ.get("LOGTALK_TIMEOUT", "10"), long_to, still)
        cands = _sweep(work, results, where, builders, dbs, shim_src, scrip, modes, workroot, jobs, decl=decl) \
            if sweep else []
    finally:
        shutil.rmtree(workroot, ignore_errors=True)
    seqinfo = {"table": sequenced, "errors": seqerr, "probes": probes, "probe_results": probe_results,
               "sweep": cands, "outside_n": outside_n, "outside_unresolved": outside_unresolved,
               "outside_off": outside_off, "excluded": excl_hits, "secs": case_secs, "retried": retried, "progkey": progkey}
    return (work, results, seqinfo), []


def verdict(plan, outcome):
    """PASS / FAIL / UNGRADED for one (plan, outcome), with the reason when it is not graded."""
    if outcome in ("harness", "toplevel"):
        return "UNGRADED", "harness could not set the case up"
    if outcome == "skipped":
        return "UNGRADED", "the case's own condition(...) option is false on this system"
    if plan.want == "succ":
        return ("PASS", "") if outcome == "succ" else ("FAIL", outcome)
    if plan.want == "fail":
        return ("PASS", "") if outcome == "fail" else ("FAIL", outcome)
    return ("PASS", "") if outcome == "ballmatch" else ("FAIL", outcome)


def _fmt_reason(plan, why):
    return plan.skip_reason if plan.skip_reason else why


def main(argv):
    import argparse
    ap = argparse.ArgumentParser(description="grade corpus/packages/prolog/logtalk_iso against ISO/IEC 13211-1")
    ap.add_argument("--suite", required=True)
    ap.add_argument("--scrip", required=True)
    ap.add_argument("--modes", default="m3")
    ap.add_argument("--jobs", type=int, default=12)
    ap.add_argument("--group", default=None, help="grade one directory only (a development aid, never a board)")
    ap.add_argument("--only", default=None, help="a file of group:case names, one per line: grade those cases only (a round-robin part, CEO-1802; "
                                                 "its rows carry the whole population's keys, and the runner writes no suite row from it)")
    ap.add_argument("--name-reds", action="store_true")
    ap.add_argument("--decl", default=None,
                    help="the declared heap/stack table lib_declared_arena.sh wrote from ALL.csv (entry<TAB>heap_kb<TAB>stack_kb)")
    ap.add_argument("--sequenced", default=SEQ_TABLE,
                    help="the order-dependent-case declaration table (default: lib_logtalk_sequenced.tsv)")
    ap.add_argument("--sweep-sequenced", action="store_true",
                    help="DIAGNOSTIC, never a grading path: re-run every red with its file's earlier cases "
                         "ahead of it and name the ones that flip -- the candidates for a declaration")
    args = ap.parse_args(argv[1:])
    modes = [m for m in args.modes.split(",") if m]
    only = None
    if args.only:
        only = {l.strip() for l in open(args.only, encoding="utf-8") if l.strip()}
    out, bad = grade(args.suite, args.scrip, modes, jobs=args.jobs, only_group=args.group,
                     seq_table=args.sequenced, sweep=args.sweep_sequenced, decl=load_decl(args.decl) if args.decl else None, only=only)
    if bad:
        # ⛔ THE DONE-WHEN'S REFUSAL: an input this instrument cannot read -- a tests.lgt that will not parse,
        # or a malformed line in the declaration table -- is NAMED and the run publishes nothing. A partial
        # population printed as if it were whole is the one failure this row exists to prevent; see
        # util_logtalk_extract.py's header for the 31 cases that vanished in silence.
        sys.stderr.write("⛔ REFUSED(2) [logtalk_iso]: %d instrument input(s) could not be read; no board is published\n" % len(bad))
        for p, why in bad:
            sys.stderr.write("    %s: %s\n" % (p, why))
        return 2
    work, results, seqinfo = out
    if only is not None and not work:
        # every name the part lists is excluded by name (EXCLUDED_CASES.tsv): nothing to grade, and that is not a refusal
        rows = os.path.join(tempfile.gettempdir(), "logtalk_progress_rows.tsv")
        open(rows, "w").close()
        print("ONLY: none of the %d named case(s) is in the graded population (each is excluded by name)" % len(only))
        print("PROGRESS_ROWS_TSV %s" % rows)
        return 0
    # ⛔⭐ A DEVELOPMENT AID THAT GRADED NOTHING MUST REFUSE, NOT PRINT ZEROS. Measured 2026-09-12: `--group
    # predicates/sub_atom_5` (the path, where the group is the basename) matched no file and this runner
    # printed a complete board reading population=0, identity 0 == 0 ✓, AND per case 0/0 -- the success
    # shape over an empty measurement, which is the one thing every gate in this tree is forbidden to do.
    if args.group and not work:
        groups = sorted({fc.group for fc in ex.parse_suite(args.suite)[0]})
        sys.stderr.write("⛔ REFUSED(2) [logtalk_iso]: --group %r matched no file -- the group is the "
                         "DIRECTORY BASENAME (sub_atom_5), never its path. Known groups: %s\n"
                         % (args.group, ", ".join(groups)))
        return 2
    # ⛔⭐ THE DECLARATION TABLE IS POLICED BEFORE ANY NUMBER IS PRINTED, and it REFUSES. Every case declared
    # order-dependent was ALSO run standalone on this same binary: if it passes standalone the prefix is
    # unnecessary, the verdict it produced is WEAKER than this suite can support, and the line must go. A
    # table nobody checks is a silencer with a comment on top.
    for g, nm, why in seqinfo["errors"]:
        sys.stderr.write("⛔ REFUSED(2) [logtalk_iso]: %s:%s %s\n" % (g, nm, why))
    if seqinfo["errors"]:
        sys.stderr.write("    Fix %s; no board is published.\n" % os.path.basename(args.sequenced))
        return 2
    unearned = []
    for j, (i, q) in enumerate(seqinfo["probes"]):
        for m in modes:
            o = seqinfo["probe_results"].get((j, m))
            if o is not None and verdict(q, o[0])[0] == "PASS":
                unearned.append("%s:%s PASSES standalone in %s" % (work[i][0].group, q.case.name, m))
    if unearned:
        sys.stderr.write("⛔ REFUSED(2) [logtalk_iso]: %d declared order-dependent case(s) do not need a "
                         "prefix, so grading them with one makes the verdict weaker than this suite supports"
                         " -- delete their line(s) from %s:\n"
                         % (len(unearned), os.path.basename(args.sequenced)))
        for u in unearned:
            sys.stderr.write("    %s\n" % u)
        return 2
    pop = len(work)
    board = {}
    named = []
    reasons = {}          # keyed (mode, reason) -- see the print below
    outside_reasons = {}  # keyed (mode, reason) -- the OUTSIDE bucket, named per case by PREDICATE
    weaker = sum(1 for _fc, p in work if p.weaker)
    for mode in modes:
        b = {"PASS": 0, "FAIL": 0, "OUTSIDE": 0, "UNGRADABLE": 0, "UNGRADED": 0, "DEFERRED": 0}
        for i, (fc, p) in enumerate(work):
            # ⛔ OUTSIDE IS TESTED FIRST AND ON PURPOSE. A case the oracle cannot run is outside whether or
            # not its own condition(...) also happened to be false, and bucketing it UNGRADED instead would
            # file a denominator fact under a work-owed reason.
            if p.outside_reason is not None:
                b["OUTSIDE"] += 1
                outside_reasons[(mode, p.outside_reason)] = outside_reasons.get((mode, p.outside_reason), 0) + 1
                continue
            if p.skip_reason is not None:
                b["UNGRADED"] += 1
                k = (mode, p.skip_reason.split(":")[0])
                reasons[k] = reasons.get(k, 0) + 1
                continue
            o, d = results[(i, mode)]
            v, why = verdict(p, o)
            b[v] += 1
            if v == "UNGRADED":
                reasons[(mode, why)] = reasons.get((mode, why), 0) + 1
            elif v == "FAIL":
                # ⛔ a sequenced red is NAMED as one: it is a verdict on the construct in the state its own
                # file establishes, and must never be read as a standalone verdict by whoever picks it up.
                named.append("%s:%s:%s:%s%s%s" % (fc.group, p.case.name, mode, o, (" " + d) if d else "",
                                                  " [SEQUENCED]" if p.sequenced else ""))
        # ⛔ THE IDENTITY IS ASSERTED, NOT ASSUMED. Four plausible counts with an invisible remainder is
        # the exact defect the package lockdown exists to end, so a total that does not reconcile REFUSES.
        tot = sum(b.values())
        if tot != pop:
            sys.stderr.write("⛔ REFUSED(2) [logtalk_iso]: %s buckets sum to %d but the globbed population is %d "
                             "-- a case is in no bucket and would be invisible in every number\n" % (mode, tot, pop))
            return 2
        board[mode] = b
    for m, (n, first_to, long_to, still) in sorted(seqinfo.get("retried", {}).items()):
        print("  TIMEOUT RETRY %s: %d case(s) timed out at %s s and were re-run at %g s: %d timed out again (graded a timeout), "
              "%d answered and are graded on that answer" % (m, n, first_to, long_to, still, n - still))
    print("LOGTALK_ISO_BOARD population=%d %s" % (pop, " ".join(
        "%s_pass=%d %s_fail=%d %s_ungraded=%d" % (m, board[m]["PASS"], m, board[m]["FAIL"], m, board[m]["UNGRADED"])
        for m in modes)))
    for m in modes:
        b = board[m]
        print("  identity %s: PASS %d + FAIL %d + OUTSIDE %d + UNGRADABLE %d + UNGRADED %d + DEFERRED %d == %d ✓"
              % (m, b["PASS"], b["FAIL"], b["OUTSIDE"], b["UNGRADABLE"], b["UNGRADED"], b["DEFERRED"], pop))
    # ⭐ THE EXCLUDED CASES, BY CLASS AND BY NAME, BESIDE THE IDENTITY THEY ARE OUTSIDE OF: shipped == population + excluded.
    excl = seqinfo.get("excluded") or []
    print("  EXCLUDED %d case(s), out of the population and never pass or fail, each named in %s with its own condition "
          "(shipped %d == population %d + excluded %d):" % (len(excl), EXCLUDED_TABLE, pop + len(excl), pop, len(excl)))
    for cls in sorted({c for _k, c, _r in excl}):
        ks = sorted(k for k, c, _r in excl if c == cls)
        print("    %4d  %s -- %s: %s" % (len(ks), cls, EXCLUDED_CLASSES[cls], " ".join(ks)))
    outside_off = seqinfo.get("outside_off")
    outside_unresolved = seqinfo.get("outside_unresolved") or []
    if outside_off:
        print("  OUTSIDE: none assigned -- %s" % outside_off)
    for m in modes:
        rs = sorted(((r, n) for (mm, r) in outside_reasons for n in [outside_reasons[(mm, r)]] if mm == m),
                    key=lambda t: (-t[1], t[0]))
        if rs:
            print("  OUTSIDE %s, by the PREDICATE that put the case there -- out of the graded denominator, "
                  "never hidden (CEO-542: the oracle cannot run these):" % m)
            for r, n in rs:
                print("    %4d  %s" % (n, r))
    if outside_unresolved:
        print("  ⛔ UNRESOLVED by the outside assigner -- these STAY IN the denominator, and an audit that "
              "cannot say how many subjects it failed to resolve is not a measurement: %d"
              % len(outside_unresolved))
        for u in outside_unresolved[:8]:
            print("      %s" % u)
        if len(outside_unresolved) > 8:
            print("      ... and %d more" % (len(outside_unresolved) - 8))
    print("  criterion: each case's OWN expectation as ISO/IEC 13211-1 states it (the suite cites the section "
          "numbers), matched by UNIFICATION inside the engine -- not an oracle diff, and never a text compare")
    if weaker:
        print("  ⚠ %d case(s) expect `deterministic` and are graded on the WEAKER criterion SUCCEEDS: no "
              "choicepoint check is available in this engine, so tightening it can only move the number DOWN" % weaker)
    # ⛔ PER MODE, NOT SUMMED ACROSS MODES. A first cut pooled them and printed 132 skipped conditions for
    # a suite that has 66 -- a table whose every row is exactly double the truth, on a board whose whole
    # point is that the parts reconcile with the whole. It read as plausible because nothing else on the
    # line moved: the identity still balanced, because the identity is computed per mode and the TABLE was
    # the only thing pooled.
    for m in modes:
        rs = {k[1]: v for k, v in reasons.items() if k[0] == m}
        print("  UNGRADED %s, by reason -- work owed, named, never dropped from the population and never a pass:" % m)
        for k in sorted(rs, key=lambda x: -rs[x]):
            print("    %4d  %s" % (rs[k], k))
    # ⛔⭐ THE SEQUENCED CASES ARE PRINTED ON EVERY RUN, WITH THEIR STANDALONE OUTCOME BESIDE THEM. The
    # weakening is the whole cost of this mechanism, so it is stated where the number is, never buried in a
    # data file: each line says what the case scored with its file's prefix AND what it scores alone.
    seqrows = [(i, q) for i, q in seqinfo["probes"]]
    if seqrows:
        print("  SEQUENCED %d case(s) graded with their file's EARLIER cases run first, in file order (which is "
              "how lgtunit runs a tests.lgt) -- declared in %s, and each one re-run standalone on this same "
              "board to prove the prefix is needed:" % (len(seqrows), os.path.basename(args.sequenced)))
        for j, (i, q) in enumerate(seqrows):
            fc, pl = work[i]
            got = " ".join("%s %s" % (m, verdict(pl, results[(i, m)][0])[0]) for m in modes)
            alone = " ".join("%s %s" % (m, verdict(q, seqinfo["probe_results"][(j, m)][0])[0]) for m in modes)
            print("    %s:%s  sequenced: %s · standalone: %s" % (fc.group, q.case.name, got, alone))
            print("        %s" % pl.sequenced)
    if seqinfo["sweep"]:
        print("  ⚠ SWEEP: %d red case(s) PASS when their file's earlier cases run first -- candidates for a "
              "%s line, to be declared BY HAND with a reason and never automatically:"
              % (len(seqinfo["sweep"]), os.path.basename(args.sequenced)))
        for g, nm in seqinfo["sweep"]:
            print("    %s\t%s" % (g, nm))
    elif args.sweep_sequenced:
        print("  SWEEP: no red case passes when its file's earlier cases run first -- every red on this board "
              "is a verdict on the engine, not on this runner's one-program-per-case isolation")
    if args.name_reds:
        for x in named[:400]:
            print("    RED " + x)
    # ⛔⭐ THE AND PER CASE, AND IT IS NOT min(m3, m4) (CEO-372; coo 2026-09-12 on this very board). m3 and
    # m4 both read 1218 PASS and the SETS ARE NOT THE SAME -- m4 carries one more UNGRADED and one fewer
    # FAIL, so they differ by at least one case. Two equal counts over different sets are not a number a
    # suite row can state, and the only honest answer is computed PER CASE: a case passes this suite when
    # it passes in EVERY mode graded. Printed beside the per-mode counts, never instead of them.
    both = 0
    for i, (fc, p) in enumerate(work):
        if p.skip_reason is not None or p.outside_reason is not None:
            continue
        if all(verdict(p, results[(i, m)][0])[0] == "PASS" for m in modes):
            both += 1
    print("  AND per case (passes in EVERY mode graded, the number a suite row states): %d/%d" % (both, pop))
    if len(modes) > 1 and any(board[m]["PASS"] != both for m in modes):
        print("    ⛔ and it is NOT either per-mode count: %s -- equal counts over different sets"
              % ", ".join("%s=%d" % (m, board[m]["PASS"]) for m in modes))
    # ⛔⭐ ONE ROW PER CASE PER MODE INTO THE PROGRESS DATABASE (CEO-331). This runner grades with its own
    # loop, so nothing records it automatically and the coverage reader sees the suite as MISSING -- a flip
    # the progress table cannot see is not paid. ⛔ THE PROGRAM KEY IS group:name, never the goal text:
    # case names repeat across directories (iso_cut_0_01 style names are unique per file, not globally),
    # and a colliding key silently shrinks the denominator. UNGRADED is a real outcome in this table's own
    # vocabulary and is recorded as itself -- never dropped, and never collapsed into FAIL.
    # ⛔⭐ THE KEY MUST BE MEASURED UNIQUE, NOT ASSERTED UNIQUE (coo COO-84 / CEO-779, 2026-09-16). The banner
    # below this line used to say group:name was the fix for name collisions, and it was READ as a guarantee for
    # weeks while SEVEN pairs collided WITHIN one group -- setof_3:iso_setof_3_11, bagof_3:iso_bagof_3_09,
    # discontiguous_1:discontiguous_1_01/_02/_03, op_3:iso_op_3_10, op_3:iso_op_3_21. The progress DB keys on
    # suite+program+mode and keeps the LAST row, so five passes and two fails vanished and each same-named pair
    # whose verdicts differed read as a FLIP IN THE MEASURE: op_3_10 and op_3_21 read plus, minus, plus inside a
    # single pass. ⭐ A BANNER ASSERTING A KEY IS UNIQUE IS NOT A MEASUREMENT THAT IT IS; this counts first.
    # ⛔ AND IT DISAMBIGUATES ONLY THE COLLISIONS, DELIBERATELY. A uniform sequence on every key would re-identify
    # all 3600 programs at once, so the DB would read mass-VANISHED plus mass-NEW and the flip reader would show a
    # wall of false red -- the exact failure the Icon per-entry baseline gate exists to warn about, which trains
    # its reader to re-pin without looking. 3586 keys stay byte-stable; seven gain a #n. The keys are grade()'s progkey, counted over the
    # whole population, so a part's rows carry the keys a whole run's do.
    rows = os.path.join(tempfile.gettempdir(), "logtalk_progress_rows.tsv")
    with open(rows, "w") as pf:
        for i, (fc, p) in enumerate(work):
            _prog = seqinfo["progkey"][i]
            for m in modes:
                if p.outside_reason is not None:
                    v, note = "OUTSIDE", p.outside_reason[:60]
                elif p.skip_reason is not None:
                    v, note = "UNGRADED", p.skip_reason.split(":")[0][:60]
                else:
                    v, why = verdict(p, results[(i, m)][0])
                    note = ("iso-13211-1-case-expectation" + ("-file-sequenced" if p.sequenced else "")) \
                        if v == "PASS" else (why or v)[:60]
                pf.write("package\tlogtalk\tprolog\t%s\t%s\t%s\t%.3f\t%s\n"
                         % (_prog, m, v, seqinfo.get("secs", {}).get((i, m), 0.0), note))
    print("PROGRESS_ROWS_TSV %s" % rows)
    # ⛔ THE OUTSIDE COUNT IS APPENDED, NEVER SUBTRACTED FROM pop HERE. Every reader of this line takes its
    # fields POSITIONALLY, and a shrinking pop would silently re-base every one of them; a trailing field is
    # invisible to a reader that does not want it and available to the one that does. The GRADED denominator
    # is pop MINUS outside, and it is the reader's job to say so out loud when it uses it.
    print("BOARD_FOR_SHELL %d %d %s outside=%d excluded=%d"
          % (pop, both, " ".join("%d %d" % (board[m]["PASS"], board[m]["FAIL"]) for m in modes),
             board[modes[0]]["OUTSIDE"], len(seqinfo.get("excluded") or [])))
    return 0


if __name__ == "__main__":
    import signal as _sg; _sg.signal(_sg.SIGTERM, lambda *_: sys.exit(143)); _sg.signal(_sg.SIGHUP, lambda *_: sys.exit(129))
    sys.exit(main(sys.argv))
