#!/usr/bin/env python3
"""util_inria_cases.py -- THE INRIA SUITE AS GENERATED UNITS (CIO-22 D, the coo 2026-11-10 on the cio's design; row
prolog-inria-container-in-the-one-layout). The generator CONTRACT.tsv names for corpus/packages/prolog/inriasuite (units=generated,
generator=util_inria_cases): cases(pkg_dir) yields one case per goal of the package's 67 family files, named fam#index exactly as ALL.csv
names it (the index counts every goal of every family in file-name order, util_prolog_iso_attributes.py's numbering), each a program that
prints ONE verdict line and the ref that line reads when the goal behaves as the suite's own Expected column says. NO ORACLE RUN cuts a ref:
the ref is the suite's expectation (ISO/IEC 13211-1's, as the INRIA authors wrote it, with the named errata below).

THE LIFT: expected_class, _mask_0c_lits, parse, OUTCOME_ERRATA, HARNESS_PRELUDE, DQ_SET, parse_bindings, has_fresh_named_var and
KNOWN_SUITE_ERRATA are the deleted runner's own text, verbatim (git -C harness show cc2783502^:scripts/test_prolog_inria_suite.sh); their
comments carry their measurements. What changed is where the verdict is decided: the runner read @OK, @NO and @ER( out of stdout in Python
and ran a second program for the bindings; here ONE program per goal decides both and prints the class itself:
    @I success                    the goal succeeded and (where the suite declares bindings, graded as the runner graded them) bound them
    @I success wrong-bindings     the goal succeeded and bound something else
    @I failure                    the goal failed
    @I error <functor>            the goal raised error(F, _) (F's functor) or a bare ball (its functor); "@I error" alone where the suite
                                  expects system_error (some error, functor unspecified)
and the ref is the expected class in the same words. The verdict is written after a newline, so a goal that writes (call((write(3), call(1))))
prints 3 and then the verdict on a line of its own; the runner found its marker anywhere in stdout, the verdict line is found at a line start. corpus_suite_harness.py grades the line by the compare token verdict-line.
THE DOUBLE_QUOTES CARRY is static: every earlier set_prolog_flag(double_quotes, V) goal of the same family is carried as a leading directive
(the last one wins), the reading a conforming run of the authors' driver gives; the runner carried a setter only when it had succeeded in
that run, which made one goal's program depend on another goal's result.
A goal with an aux file other than t_foo, and halt's impl_defined goals, are cases with a reason (no verdict line a real run alone can
give); EXCLUDED.tsv names them as well. No case carries a cwd: each runs in the grader's own scratch directory, as the runner ran it.
"""
import os
import re
def expected_class(exp):
    e = exp.strip()
    if e == "success": return ("success", None)
    if e == "failure": return ("failure", None)
    # ⛔ "impl_defined" / "system_error" are the SUITE'S OWN sentinel vocabulary, not literal functors to
    # string-match -- inriasuite.pl:136-146 (the authors' own driver) lists system_error as a recognized
    # error_type beside instantiation_error/type_error/...; "impl_defined" appears bare (no functor at all)
    # in halt's two entries. impl_defined means "any conforming behavior passes" (checked at point of use,
    # below); system_error means "must raise SOME error, exact functor unspecified" (wfun=None already
    # skips the functor check in the ok= line below). Measured 2026-09-04, seat05: 3 entries total.
    if e == "impl_defined": return ("impl_defined", None)
    if e == "system_error": return ("error", None)
    if e.startswith("["):  return ("success", None)   # a substitution set implies success (weaker, see header)
    m = re.match(r"([a-z_]+)", e)
    return ("error", m.group(1) if m else None)
def _mask_0c_lits(s):
    # ⛔ 0'c (a character-code literal, e.g. 0'a = 97) carries a single unpaired quote that desyncs a
    # naive quote-toggle scanner -- measured live on atom_codes/char_code. But a BLIND regex for "0'." is
    # a false-positive trap of its own: the quoted atom '0' immediately followed by another quoted element,
    # e.g. ...,'0']] (number_chars), contains the literal substring "0'" purely as the tail of '0' and the
    # head of the next token, with no character-literal there at all. So this has to be found IN CONTEXT,
    # walking quote-state properly, and only ever recognised while NOT already inside a quote. Returns
    # (masked_string, restore_dict) -- the mask is a placeholder with no quote/bracket/comma of its own,
    # safe to feed to the depth/comma scanners below; restore before use. Shared by parse() and
    # parse_bindings() -- moved above parse() (2026-09-04, seat05) so the census pass can use it too.
    out = []; ph = {}; i = 0; q = False; n = 0
    while i < len(s):
        ch = s[i]
        if not q and ch == "0" and i + 1 < len(s) and s[i+1] == "'":
            j = i + 4 if (i + 2 < len(s) and s[i+2] == "\\") else i + 3
            j = min(j, len(s))
            tok = s[i:j]
            key = "\x01%d\x01" % n; n += 1
            ph[key] = tok
            out.append(key)
            i = j
            continue
        if ch == "'":
            q = not q
        out.append(ch)
        i += 1
    return "".join(out), ph

def parse(path):
    # ⛔⭐ ENTRIES SPAN LINES, AND ASSUMING THEY DO NOT SILENTLY SHRINKS THE DENOMINATOR. The first cut took only
    # lines that both started "[" and ended "]." and reported total=416 -- a clean, plausible board that had
    # quietly dropped ~50 goals, all of them the LONG ones (sub_atom 25 starts / 13 one-liners, functor-bis 19/12,
    # atom_concat 15/9). Those are exactly the hard cases, so the dropped set was biased toward what we are worst
    # at, which flatters the score twice over. Accumulate until the bracket depth closes.
    # ⛔ STRIP THE TRAILING % COMMENT FIRST -- but only one that is OUTSIDE quotes, since % is legal inside a
    # quoted atom. Measured: 13 of the 67 files carry an explanatory comment after the closing "]." (the `fail`
    # family annotates two of its four goals), and requiring the raw line to END with "]." dropped every one of
    # them. The suite's authors comment the SUBTLE cases, so a comment-blind parser again drops exactly the
    # goals that matter most.
    def decomment(t):
        q = False; out = []
        for ch in t:
            if ch == "'": q = not q
            if ch == "%" and not q: break
            out.append(ch)
        return "".join(out).strip()
    out = []; buf = ""
    for raw in open(path, errors="replace"):
        line = decomment(raw.strip())
        if not buf and not line.startswith("["): continue
        buf = (buf + " " + line).strip() if buf else line
        if buf.count("[") > buf.count("]") or not buf.endswith("]."): continue
        body_raw = buf[1:-2]; buf = ""
        # ⛔ THE SPLIT MUST MASK QUOTES TOO, NOT JUST 0'c -- the "and" family writes conjunction in its
        # canonical functional form ','(A,B): the quoted comma atom ',' sits at depth 0, before any
        # bracket, so an unmasked scanner cut the entry after ONE character (goal="'", exp="'(A,B),..."),
        # taking all 5 of that family's goals to NO-CLASS. Measured 2026-09-04, seat05.
        body, ph = _mask_0c_lits(body_raw)
        # ⛔⭐ TOP-LEVEL-COMMA SPLIT, NOT A SINGLE CUT -- inriasuite.pl's own test/3 (2nd clause) recognizes a
        # THREE-element entry `[G, ProgFile, Expected]` (its own comment: "use run_forest(...) to see the
        # program changes" / "[ProgFile]" loads ProgFile before running G) alongside the ordinary two-element
        # `[G, Expected]`. A single first-comma cut folds ProgFile into the SAME field as Expected for every
        # 3-element entry in this suite (measured: the "t" family's `t_foo` aux and file_manip's `in(my_file)`
        # aux both landed inside `e`, and expected_class()'s regex fallback then read the aux ATOM ITSELF as a
        # fabricated error functor -- "t_foo" and "in" respectively -- silently grading against a functor the
        # suite never declared). Collect ALL depth-0 commas; 1 comma = 2 fields (ordinary), 2 commas = 3
        # fields (G, aux, Expected) -- Expected's own grammar (bare atom / error-term / bracketed list) never
        # contains a bare depth-0 comma, so this split is unambiguous.
        depth = 0; cuts = []; q = False
        for i, ch in enumerate(body):
            if ch == "'": q = not q; continue
            if q: continue
            if ch in "([{": depth += 1
            elif ch in ")]}": depth -= 1
            elif ch == "," and depth == 0: cuts.append(i)
        if not cuts: continue
        if len(cuts) == 1:
            g, aux, e = body[:cuts[0]].strip(), None, body[cuts[0]+1:].strip()
        else:
            g, aux, e = body[:cuts[0]].strip(), body[cuts[0]+1:cuts[1]].strip(), body[cuts[1]+1:].strip()
        for key, tok in ph.items():
            g = g.replace(key, tok); e = e.replace(key, tok)
            if aux: aux = aux.replace(key, tok)
        outside = None
        if aux == "t_foo":
            # ⛔ THE REAL t_foo.pl, INLINED AS assertz/1 CALLS -- not consult/1 (unimplemented, per
            # GOAL-PROLOG-100.md's own named gap), and not a file read at Prolog runtime at all. Verbatim
            # facts from corpus/packages/prolog/inriasuite/t_foo.pl (4 clauses); the vendored aux file is
            # never edited, this is just a textual restatement as the goal this suite entry actually needs.
            g = ("(assertz(t_foo(1,2)),assertz(t_foo(2,3)),assertz(t_foo(3,4)),"
                 "assertz((t_foo(_,_))),%s)" % g)
        elif aux is not None:
            # A 3-element entry whose aux field is NOT a known consultable fixture (file_manip's `in(my_file)`
            # is the only case in this suite -- PROVENANCE.txt vendored only inriasuite.tar.gz, never
            # prologsuite.tar.gz, so the 'run_forest'/'bips-ex' machinery + the real my_file fixture the
            # suite's own file_manip comment names do not exist in this tree). Cannot be given a meaningful
            # ISO verdict without fabricating fixture content the vendor never shipped us -- R-749
            # OUTSIDE-BASELINE, named beside the suite, out of the graded denominator, never hidden.
            outside = "requires unvendored run_forest/bips-ex fixture (aux=%s, prologsuite.tar.gz never fetched)" % aux
        out.append((g, e, outside))
    return out

OUTCOME_ERRATA = {
    ("functor-bis", "functor(foo(a),foo,2)"): ("failure", None,
        "ISO 13211-1 sec 8.5.1: functor(foo(a),foo,2) asks whether foo(a) has name foo and arity 2; its arity is 1, "
        "so the goal FAILS. The suite declares success and its OWN comment on the same line reads 'Must fail'. "
        "swipl 9.x FAILS and gprolog 1.6.0 (the oracle since R-1598; re-measured on this goal 2026-10-10, R-1603, and 1.4.5 answered alike) FAILS -- both independent references agree with each other, with ISO, "
        "and with scrip, against the vendored cell (measured hq_R 2026-09-06)."),
    ("functor-bis", "functor([_|_],'.',2)"): ("success", None,
        "ISO 13211-1 sec 6.3.5: the list constructor IS '.'/2, so a partial list [_|_] has name '.' and arity 2 and "
        "the goal SUCCEEDS. The suite declares failure and its OWN comment reads 'Must succeed'. ⛔ THE ORACLES SPLIT "
        "HERE AND THAT IS THE POINT: gprolog 1.6.0 (the oracle since R-1598; re-measured on this goal 2026-10-10, R-1603, and 1.4.5 answered alike) SUCCEEDS (ISO-conformant) and swipl 9.x FAILS because modern SWI "
        "uses '[|]' as its list functor, a documented post-ISO divergence. The vendored expectation follows the "
        "NON-ISO reading while its own comment follows ISO, so grading against that cell PENALISES the conformance "
        "this suite exists to measure. Graded on ISO + gprolog per R-370 (measured hq_R 2026-09-06)."),
    ("functor-bis", "functor(X, foo, a)"): ("error", "type_error",
        "ISO 13211-1 sec 8.5.1.3: functor/3 raises type_error(integer, a) when the arity argument is not an integer. "
        "The suite declares failure and its OWN comment reads 'type_error(integer,a) expected'. swipl 9.x and "
        "gprolog 1.6.0 (the oracle since R-1598; re-measured on this goal 2026-10-10, R-1603, and 1.4.5 answered alike) BOTH raise type_error(integer,a), as does scrip (measured hq_R 2026-09-06)."),
    ("atom_codes", "atom_codes(A,[ 0'i, 0's, 1000])"): ("success", None,
        "The suite's own comment reads '1000 not a code', an assumption from the pre-Unicode era this 1999 suite "
        "was authored in (a character code above the then-common 8-bit/Latin-1 range). ISO 13211-1 leaves the "
        "representable character-code range IMPLEMENTATION DEFINED. ⛔ THE ORACLES SPLIT ON THIS EXACT WITNESS: "
        "gprolog 1.6.0, the oracle since R-1598 (Latin-1-range engine, measured boundary: codes 0-255 accepted, 256+ raise "
        "representation_error(character_code); re-measured 2026-10-10 at 255, 256 and 1000, R-1603, and 1.4.5 answered alike) raises the error the suite expects; swipl 9.0.4 (full-Unicode "
        "engine, codes up to 0x10FFFF) SUCCEEDS, binding A to the 3-character atom 'is\\u03e8' -- code 1000 is a "
        "real, representable Unicode character (GREEK CAPITAL LETTER PAMPHYLIAN DIGAMMA). scrip already commits "
        "to the full-Unicode reading elsewhere (pl_anum_code_ok in by_name_dispatch.c caps representable codes at "
        "0x10FFFF, not 255, for number_codes/number_chars) and SUCCEEDS here too, consistently. Graded on the "
        "modern-Unicode reading, matching swipl and scrip's own existing internal choice (measured hq_prolog "
        "2026-09-23, live oracle runs of both swipl and gprolog on this exact goal)."),
    ("number_codes", "number_codes(A,[ 0'1, 0'2, 1000])"): ("error", "syntax_error",
        "SAME oracle split as the atom_codes entry above, same root cause, same suite-authorship-era assumption "
        "('1000 not a code'). gprolog 1.6.0 (the oracle since R-1598; re-measured on this goal 2026-10-10, R-1603, and 1.4.5 answered alike) raises representation_error(character_code) (its Latin-1 code-range "
        "limit); swipl 9.0.4 raises syntax_error(illegal_number) instead -- code 1000 IS representable (Unicode), "
        "so swipl converts it to the character U+03E8 and then finds \"12\\u03e8\" is not a syntactically valid "
        "number, which is the correct ISO reading for a Unicode-complete implementation: representation_error is "
        "for a code that cannot be turned into a character at all, and this one can. scrip already raises "
        "syntax_error here, unchanged, matching swipl exactly (measured hq_prolog 2026-09-23, live oracle runs)."),
}

HARNESS_PRELUDE = (
    "exists(P/I) :- make_list(I,List), G =.. [P|List], set_prolog_flag(unknown, fail), "
    "catch(call(G),_,true), reset_flags, !.\n"
    "exists(P/I) :- reset_flags.\n"
    "reset_flags :- set_prolog_flag(unknown, error).\n"
    "make_list(N,L) :- N >= 0, make_list1(N,L).\n"
    "make_list1(0,[]).\n"
    "make_list1(N,[_|L1]) :- N1 is N-1, make_list(N1,L1).\n"
    "run_tests(_).\n"
)

DQ_SET = re.compile(r"^\s*set_prolog_flag\(\s*double_quotes\s*,\s*([a-z]+)\s*\)\s*$")

def parse_bindings(e):
    # e is the raw expected-result text, e.g. "[[A <-- 'hello world']]" or
    # "[[T1 <-- '',T2 <-- 'hello'], [T1 <-- 'h',T2 <-- 'ello']]". Returns a list of solution-sets, each
    # a list of (varname, value_text) pairs -- or None if e is not a bindings declaration at all.
    e = e.strip()
    if not e.startswith("["): return None
    e, ph = _mask_0c_lits(e)
    body = e[1:-1].strip()  # strip the outer list brackets
    sols = []
    depth = 0; q = False; start = -1
    for i, ch in enumerate(body):
        if ch == "'" : q = not q
        if q: continue
        if ch == "[":
            if depth == 0: start = i
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0 and start >= 0:
                sols.append(body[start+1:i])
                start = -1
    pairs_all = []
    for sol in sols:
        pairs = []; depth = 0; q = False; cut = 0
        for i, ch in enumerate(sol + ","):
            if ch == "'": q = not q
            if q: continue
            if ch in "([{": depth += 1
            elif ch in ")]}": depth -= 1
            elif ch == "," and depth == 0:
                clause = sol[cut:i].strip() if i < len(sol) else sol[cut:].strip()
                cut = i + 1
                if not clause: continue
                m = re.split(r"\s*<--\s*", clause, maxsplit=1)
                if len(m) != 2:
                    return None  # malformed -- refuse to grade this entry as bindings rather than guess
                var, val = m[0].strip(), m[1].strip()
                for key, tok in ph.items():
                    var = var.replace(key, tok); val = val.replace(key, tok)
                pairs.append((var, val))
        pairs_all.append(pairs)
    return pairs_all if pairs_all else None

def has_fresh_named_var(goal, sols):
    # True when some solution-set's value side names a variable that appears NOWHERE else (not in the
    # goal, not as one of this same solution-set's own bound variables) -- the suite's convention for "a
    # new/unconstrained variable belongs here" (e.g. functor(X,foo,3), [[X <-- foo(A,B,C)]], "A, B and C
    # are 3 new variables" per the file's own comment) -- INCLUDING a bare `_` EMBEDDED inside a compound
    # value (e.g. findall(X+Y,(X=1),S), [[S <-- [1+_]]] -- measured: scrip's actual [1+_G0] is the correct
    # shape, but `S == [1+_]` compares it against a brand-new anonymous variable the comparison goal just
    # introduced, so it always mismatches regardless of correctness). A bare `_` as the WHOLE value is
    # handled better, separately (var/1, above), and is not re-flagged here. Neither case can be reached by
    # decomposing the term without =@=/2, which does not exist in this engine (existence_error, measured).
    # Excess caution here only ever makes the bindings board WEAKER (falls back to the outcome-class
    # verdict for that one entry, never claims a false pass), so a loose regex is an acceptable trade.
    goal_vars = set(re.findall(r"\b[A-Z_][A-Za-z0-9_]*\b", goal))
    for sol in sols:
        sol_vars = set(v for v, _t in sol)
        for _v, t in sol:
            if t == "_": continue
            for vv in re.findall(r"\b[A-Z_][A-Za-z0-9_]*\b", t):
                if vv not in goal_vars and vv not in sol_vars:
                    return True
    return False

KNOWN_SUITE_ERRATA = {
    ("sub_atom", "sub_atom('ab', Before, Length, After, Sub_atom)"):
        "suite declares Before ranging 1..3 (never 0) for a 2-char atom; swipl AND gprolog (independent "
        "ISO references) both instead produce scrip's own exact 6-solution set starting Before=0 -- the "
        "VENDORED SUITE TEXT is the erratum, not scrip (verified seat05 2026-09-04, task "
        "prolog-inria-sub-atom-decomposition-enumeration-mismatch).",
    ("functor-bis", "functor(foo(a,b,c),X,Y)"):
        "suite declares [[X <-- foo, Y <-- 2]] for functor(foo(a,b,c),X,Y) -- foo(a,b,c) has arity 3, and the "
        "SAME LINE's own %% comment reads 'Must instantiate Y by 3', contradicting its own machine-readable "
        "cell exactly as the three OUTCOME_ERRATA functor-bis entries above do. swipl AND gprolog (independent "
        "ISO references) both bind Y=3; so does scrip. VENDORED SUITE TEXT is the erratum (measured hq_prolog "
        "2026-09-23, live oracle run: swipl 9.0.4 and gprolog 1.4.5 both agree Y=3; gprolog 1.6.0, the oracle since R-1598, binds Y=3 too, re-measured 2026-10-10, R-1603).",
}


MARK = "@I"


def _err_class_writer(print_functor):
    if not print_functor:
        return "nl, write('@I error')"
    return ("nl, write('@I error '), ( INRIA_E = error(INRIA_F, _), nonvar(INRIA_F) -> true ; INRIA_F = INRIA_E ), "
            "( compound(INRIA_F) -> functor(INRIA_F, INRIA_N, _) ; INRIA_N = INRIA_F ), write(INRIA_N)")


def tests_of(pkg_dir):
    """[(fam, goal, exp, aux_reason)] in the runner's order: every regular file of the package that is not .md, .txt or .pl, sorted by name."""
    out = []
    for fn in sorted(os.listdir(pkg_dir)):
        p = os.path.join(pkg_dir, fn)
        if not os.path.isfile(p) or fn.endswith((".md", ".txt", ".pl", ".csv", ".tsv", ".ref", ".in", ".rc", ".mask")) or fn.startswith("ALL."):
            continue
        for goal, exp, outside in parse(p):
            out.append((fn, goal, exp, outside))
    return out


def cases(pkg_dir):
    tests = tests_of(str(pkg_dir))
    for idx, (fam, goal, exp, outside) in enumerate(tests):
        name = "%s#%d" % (fam, idx)
        if outside is not None:
            yield {"name": name, "reason": outside}
            continue
        want, wfun = expected_class(exp)
        if (fam, goal) in OUTCOME_ERRATA:
            want, wfun, _why = OUTCOME_ERRATA[(fam, goal)]
        if want == "impl_defined":
            yield {"name": name, "reason": "impl_defined: the suite declares any conforming behaviour, so no verdict line a real run alone can give"}
            continue
        sols = parse_bindings(exp) if want == "success" else None
        if sols is not None and ((fam, goal) in KNOWN_SUITE_ERRATA or has_fresh_named_var(goal, sols)):
            sols = None
        check = (" ; ".join(("(" + ",".join(("var(%s)" % v) if t == "_" else "%s == %s" % (v, t) for v, t in sol) + ")") if sol else "true"
                            for sol in sols) if sols else "true")
        lead = ""
        for j in range(idx):
            m = DQ_SET.match(tests[j][1])
            if tests[j][0] == fam and m:
                lead = ":- set_prolog_flag(double_quotes, %s).\n" % m.group(1)
        prog = (HARNESS_PRELUDE + lead +
                ":- catch( ( %s -> ( (%s) -> nl, write('@I success') ; nl, write('@I success wrong-bindings') ) ; nl, write('@I failure') ), INRIA_E, ( %s ) ), nl.\n"
                % (goal, check, _err_class_writer(not (want == "error" and wfun is None))))
        ref = {"success": "@I success", "failure": "@I failure"}.get(want) or ("@I error %s" % wfun if wfun else "@I error")
        yield {"name": name, "program": prog, "ref": ref}
