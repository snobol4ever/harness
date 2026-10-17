#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${INRIA_SUITE:=${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus/packages/prolog/inriasuite}" || exit 2
# test_prolog_inria_suite.sh — THE ISO/IEC 13211-1 PROLOG DENOMINATOR (row prolog-iso-conformance-inria-suite-vendored-and-graded).
# Lon 2026-09-03 20:45: "100% means 100% of the industry standard language." For Prolog the standard is ISO/IEC 13211-1
# and the public suite that grades it is the INRIA suite (Deransart / Ed-Dbali / Cervoni), vendored at
# corpus/packages/prolog/inriasuite (see its README and PROVENANCE.txt). 445 goals across 67 builtin-family files.
#
# ⛔⭐ WHAT THIS GRADES, AND WHAT IT DOES NOT -- stated here and in the board line, because a conformance number that
# overstates itself is worse than no number. It compares the OUTCOME CLASS of each goal: success vs failure vs error,
# and for an error the ERROR TERM'S FUNCTOR (type_error, instantiation_error, ...). It does NOT compare substitution
# bindings, so a goal expected to yield [[X <-- a]] scores as a pass if it merely SUCCEEDS, whatever it bound.
# That is strictly weaker than the suite's own criterion. Tightening it can only ever move the number DOWN.
set -u
GATE_NAME=test_prolog_inria_suite
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SUITE="${INRIA_SUITE:-$ROOT/corpus/packages/prolog/inriasuite}"   # line 2 sets it to this default, so the guard judges the suite graded here
SCRIP="$HERE/../../SCRIP/scrip"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -d "$SUITE" ] || refuse "no vendored suite at $SUITE -- a suite that is absent is not a suite that is failing"
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first; a missing binary prints a full, plausible, entirely false all-FAIL board"
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). The line above proves a binary EXISTS; this one proves it is the binary this
# tree describes. ceo's witness, twice on 2026-09-04: a 10:57 binary graded at 14:03 read RED, then GREEN after
# an incremental make -- a vendor board is exactly where that is least visible, because a plausible all-FAIL
# table is this class's normal output. NO LOGIC HERE: util_require_fresh.sh sources gate_require_fresh from
# lib_gate.sh, the ONE authority (hq_B 4c7253e99) -- never a second copy of the staleness rule.
"$HERE/util_require_fresh.sh" --gate test_prolog_inria_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
# ⛔⭐ SOURCED FOR gate_score_row, THE SHARED WRITER -- never a second implementation. This runner mentioned
# lib_gate.sh in a comment for a day and never sourced it, so it printed a 445-goal conformance board and the
# leaderboard never heard a word of it. That is the FACT RULE's own failure mode in the most expensive place
# it can happen: a vendor number that costs ten minutes to produce and is then thrown away, so the next person
# who wants it runs the suite again instead of reading the board.
. "$HERE/lib_gate.sh"
# ⭐ THE DECLARED HEAP AND STACK (Lon 2026-09-23 18:3x; CEO-1167, CEO-1225; wired by the coo on CEO-1229, the SWI runner's pattern):
# each case runs in BOTH modes at what its row in ALL.csv declares (entry = <file>#<case index>, util_prolog_iso_attributes.py's
# numbering) -- heap_kb, stack_kb, read once through lib_declared_arena.sh, the one reader, into the table the python side reads --
# and at the shipped default when it declares nothing; a refused cell refuses the board.
. "$HERE/lib_declared_arena.sh" || refuse "lib_declared_arena.sh unloadable -- the one reader of a declared heap and stack"
_inria_decl="$(mktemp "${TMPDIR:-/tmp}/inria_decl.XXXXXX")"
declared_memory_begin "$SUITE/ALL.csv" "$_inria_decl" || { rm -f "$_inria_decl"; refuse "a declared-memory cell in $SUITE/ALL.csv is refused (named above) -- fix the cell; this board does not grade around it"; }
# ⭐ THE ROUND ROBIN'S SEAM (ceo CEO-1802/1805/1806): under S4E_CHUNK the grader runs only the selected fam#index cases (and any double_quotes setter
# they carry from), writes their rows, and no suite row is written (rr_end below)
. "$HERE/lib_rr.sh" && rr_load "$SUITE" || exit 2
export INRIA_RR_SEL="$(printf '%s ' ${RR_SEL:-})"
export INRIA_SUITE="$SUITE" INRIA_SCRIP="$SCRIP" INRIA_DECL="$_inria_decl" INRIA_HERE="$HERE"
# ⛔ THE HEREDOC DELIMITER IS QUOTED and every value crosses by ENVIRONMENT, never by interpolation. This repo has
# measured the alternative three times in one day: an unquoted heredoc hands the shell the whole program and every
# backtick in it runs as a command. The trap lives in the medium, not in the language you think you are writing.
_inria_out="$(mktemp "${TMPDIR:-/tmp}/inria_board.XXXXXX")"
python3 - <<'PY' | tee "$_inria_out"
import os, re, subprocess, tempfile, sys
sys.path.insert(0, os.environ["INRIA_HERE"]); import lib_timeout_retry as _ltr   # a graded run's timeout under load is retried once (CEO-1335)
# ⭐ THE ENTRY'S OWN SECONDS PER MODE (CEO-1676 (c)): every run below goes through _ltr.run, so its wall is added to the (index, mode) the
# loop is grading -- both passes (the outcome class and the bindings) -- and the progress row carries the sum.
import time as _time, collections as _coll
isecs = _coll.defaultdict(float); _cur = [None]
_ltr_run = _ltr.run
def _timed_run(*a, **k):
    t0 = _time.monotonic()
    try:
        return _ltr_run(*a, **k)
    finally:
        if _cur[0] is not None: isecs[_cur[0]] += _time.monotonic() - t0
_ltr.run = _timed_run
suite = os.environ["INRIA_SUITE"]; scrip = os.environ["INRIA_SCRIP"]
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
            # ISO verdict without fabricating fixture content the vendor never shipped us -- CEO-749
            # OUTSIDE-BASELINE, named beside the suite, out of the graded denominator, never hidden.
            outside = "requires unvendored run_forest/bips-ex fixture (aux=%s, prologsuite.tar.gz never fetched)" % aux
        out.append((g, e, outside))
    return out
tests = []
OUTSIDE = {}   # test index -> reason, populated below; excluded from BOTH boards' pass/fail, never hidden
for fn in sorted(os.listdir(suite)):
    p = os.path.join(suite, fn)
    if not os.path.isfile(p) or fn.endswith((".md", ".txt", ".pl")): continue
    for goal, exp, outside in parse(p):
        if outside is not None: OUTSIDE[len(tests)] = outside
        tests.append((fn, goal, exp))
if not tests:
    sys.stderr.write("⛔ REFUSED(2) [test_prolog_inria_suite]: parsed ZERO goals from %s -- refusing to print a board with no denominator\n" % suite)
    raise SystemExit(2)
# ⭐ THE DECLARED HEAP AND STACK, per case (the table the shell side built through lib_declared_arena.sh). ⛔ THE KEY IS A NUMBER,
# SO THE NUMBERING IS CHECKED BEFORE ONE DECLARATION IS APPLIED: ALL.csv's entries are <file>#<index> in util_prolog_iso_attributes.py's
# order, this loop's are <file>#<index in tests>; measured identical on all 445 cases 2026-09-23, and if they ever part a declaration
# would land on a different case -- so the board refuses rather than grade anything at a borrowed arena.
DECL = {}
for _ln in open(os.environ["INRIA_DECL"]):
    _e, _kb, _st = _ln.rstrip("\n").split("\t")
    DECL[_e] = (_kb, _st)
if DECL:
    import csv as _csv
    _ids = ["%s#%d" % (fn, i) for i, (fn, g, e) in enumerate(tests)]
    _csv_ids = [r["entry"] for r in _csv.DictReader(open(os.path.join(suite, "ALL.csv"), newline=""))]
    if _ids != _csv_ids:
        sys.stderr.write("⛔ REFUSED(2) [test_prolog_inria_suite]: ALL.csv declares memory for %d case(s), but its entries are not this runner's "
                         "cases in this runner's order (%d here, %d there) -- a declaration would be applied to a different case\n"
                         % (len(DECL), len(_ids), len(_csv_ids)))
        raise SystemExit(2)
def decl_sw(idx, fam):
    # the case's declared heap and stack as SPITBOL's switches, -d<kb>k -s<kb>k (ceo CEO-1353, clause 8 (g); the harness's _size_switches):
    # after --run in m3, leading the binary's command line in m4. NEVER SCRIP_HEAP_KB (gc_heap.c reads it as the collector's initial WINDOW,
    # so the declared maximum was handed over as a window) and never SCRIP_STACK. [] when the case declares nothing.
    kb, st = DECL.get("%s#%d" % (fam, idx), ("", ""))
    return (["-d%sk" % kb] if kb else []) + (["-s%sk" % st] if st else [])
# ⛔⭐ OUTCOME_ERRATA (row inria-three-functor-bis-cells-graded-on-iso-through-a-named-outcome-erratum-sibling-of-
# known-suite-errata, hq_R 2026-09-06, ceo-370; hq_T co-signs the runner change). SIBLING of KNOWN_SUITE_ERRATA
# below, and deliberately NOT the same mechanism: that one relaxes the BINDINGS comparison to outcome-class-only
# for a goal whose declared substitutions are mistranscribed. These three are wrong on the OUTCOME CLASS ITSELF --
# success vs failure, failure vs success, failure vs error -- which is the axis that mechanism does not touch, so
# registering them there would silently do nothing and read as done.
# ⛔ THE SUITE SAYS SO IN ITS OWN WORDS AND THE PARSER THROWS THE SENTENCE AWAY. All three carry a % comment on
# the same line contradicting the machine-readable expectation, and decomment() above strips % comments before
# grading -- by design, since 13 files annotate subtle cases. So the suite's own correction is structurally
# invisible to the board, and we were scored against the half its authors marked wrong.
# ⛔ THE BAR, same as KNOWN_SUITE_ERRATA: an ISO clause AND measured oracle behaviour on the SAME witness goal,
# cited per entry, never scrip behavior taken on faith. The vendored file is NEVER edited (its README keeps the
# data verbatim); the fix lives here, in the open, and every entry is PRINTED on every run beside the board.
# Lon's bar is 100% of the INDUSTRY STANDARD (ISO/IEC 13211-1), not of a transcription (ceo-370).
OUTCOME_ERRATA = {
    ("functor-bis", "functor(foo(a),foo,2)"): ("failure", None,
        "ISO 13211-1 sec 8.5.1: functor(foo(a),foo,2) asks whether foo(a) has name foo and arity 2; its arity is 1, "
        "so the goal FAILS. The suite declares success and its OWN comment on the same line reads 'Must fail'. "
        "swipl 9.x FAILS and gprolog 1.6.0 (the oracle since CEO-1598; re-measured on this goal 2026-10-10, CEO-1603, and 1.4.5 answered alike) FAILS -- both independent references agree with each other, with ISO, "
        "and with scrip, against the vendored cell (measured hq_R 2026-09-06)."),
    ("functor-bis", "functor([_|_],'.',2)"): ("success", None,
        "ISO 13211-1 sec 6.3.5: the list constructor IS '.'/2, so a partial list [_|_] has name '.' and arity 2 and "
        "the goal SUCCEEDS. The suite declares failure and its OWN comment reads 'Must succeed'. ⛔ THE ORACLES SPLIT "
        "HERE AND THAT IS THE POINT: gprolog 1.6.0 (the oracle since CEO-1598; re-measured on this goal 2026-10-10, CEO-1603, and 1.4.5 answered alike) SUCCEEDS (ISO-conformant) and swipl 9.x FAILS because modern SWI "
        "uses '[|]' as its list functor, a documented post-ISO divergence. The vendored expectation follows the "
        "NON-ISO reading while its own comment follows ISO, so grading against that cell PENALISES the conformance "
        "this suite exists to measure. Graded on ISO + gprolog per ceo-370 (measured hq_R 2026-09-06)."),
    ("functor-bis", "functor(X, foo, a)"): ("error", "type_error",
        "ISO 13211-1 sec 8.5.1.3: functor/3 raises type_error(integer, a) when the arity argument is not an integer. "
        "The suite declares failure and its OWN comment reads 'type_error(integer,a) expected'. swipl 9.x and "
        "gprolog 1.6.0 (the oracle since CEO-1598; re-measured on this goal 2026-10-10, CEO-1603, and 1.4.5 answered alike) BOTH raise type_error(integer,a), as does scrip (measured hq_R 2026-09-06)."),
    ("atom_codes", "atom_codes(A,[ 0'i, 0's, 1000])"): ("success", None,
        "The suite's own comment reads '1000 not a code', an assumption from the pre-Unicode era this 1999 suite "
        "was authored in (a character code above the then-common 8-bit/Latin-1 range). ISO 13211-1 leaves the "
        "representable character-code range IMPLEMENTATION DEFINED. ⛔ THE ORACLES SPLIT ON THIS EXACT WITNESS: "
        "gprolog 1.6.0, the oracle since CEO-1598 (Latin-1-range engine, measured boundary: codes 0-255 accepted, 256+ raise "
        "representation_error(character_code); re-measured 2026-10-10 at 255, 256 and 1000, CEO-1603, and 1.4.5 answered alike) raises the error the suite expects; swipl 9.0.4 (full-Unicode "
        "engine, codes up to 0x10FFFF) SUCCEEDS, binding A to the 3-character atom 'is\\u03e8' -- code 1000 is a "
        "real, representable Unicode character (GREEK CAPITAL LETTER PAMPHYLIAN DIGAMMA). scrip already commits "
        "to the full-Unicode reading elsewhere (pl_anum_code_ok in by_name_dispatch.c caps representable codes at "
        "0x10FFFF, not 255, for number_codes/number_chars) and SUCCEEDS here too, consistently. Graded on the "
        "modern-Unicode reading, matching swipl and scrip's own existing internal choice (measured hq_prolog "
        "2026-09-23, live oracle runs of both swipl and gprolog on this exact goal)."),
    ("number_codes", "number_codes(A,[ 0'1, 0'2, 1000])"): ("error", "syntax_error",
        "SAME oracle split as the atom_codes entry above, same root cause, same suite-authorship-era assumption "
        "('1000 not a code'). gprolog 1.6.0 (the oracle since CEO-1598; re-measured on this goal 2026-10-10, CEO-1603, and 1.4.5 answered alike) raises representation_error(character_code) (its Latin-1 code-range "
        "limit); swipl 9.0.4 raises syntax_error(illegal_number) instead -- code 1000 IS representable (Unicode), "
        "so swipl converts it to the character U+03E8 and then finds \"12\\u03e8\" is not a syntactically valid "
        "number, which is the correct ISO reading for a Unicode-complete implementation: representation_error is "
        "for a code that cannot be turned into a character at all, and this one can. scrip already raises "
        "syntax_error here, unchanged, matching swipl exactly (measured hq_prolog 2026-09-23, live oracle runs)."),
}
outcome_erratum_hits = []
res = {"m3": [0, 0, 0], "m4": [0, 0, 0]}   # pass, fail, crash
named = []
outcome_ok = {}   # (test index in `tests`, mode) -> bool, additive: lets the bindings comparator below
                   # reuse this loop's own verdict instead of re-deriving it from the truncated `named`
                   # diagnostics. ⛔ Keyed by INDEX, not (fam, goal) text: 2 goal texts recur verbatim
                   # across distinct entries in this suite (measured: ('and',"'") x5, ('set_prolog_flag',
                   # 'X = "fred"') x3) -- a text key would silently collide and leak one entry's verdict
                   # onto another's lookup.
# ⛔⭐ HARNESS_PRELUDE -- inriasuite.pl's OWN helper predicates (exists/1, reset_flags/0, make_list/2,
# make_list1/2), copied VERBATIM from the vendored driver (this directory's inriasuite.pl, lines ~779-810),
# not reimplemented. Three suite entries call exists/1 directly (current_input, current_output) or depend on
# the harness having consulted the real driver (current_predicate(run_tests/1) -- "depends on the test
# harness" per that file's own comment). This runner drives each goal standalone rather than consulting
# inriasuite.pl wholesale, so without this prelude those calls hit existence_error(procedure, exists/1) --
# a gap in THIS harness, not in scrip: exists/1's own two-clause definition ALWAYS succeeds once it exists at
# all (clause 1 succeeds whether call(G) succeeds or throws, via catch(_,_,true); clause 2 succeeds when
# call(G) merely fails) -- so once the predicate is present, the ISO question these three entries actually
# probe (is exists/1 well-defined and is a harness predicate named run_tests/1 in scope) is answered
# correctly by scrip's own execution of THIS code, not by anything this runner asserts on scrip's behalf.
# run_tests/1 is a stub (never called by any suite entry -- current_predicate/1 only checks it EXISTS).
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
# ⭐ THE DOUBLE_QUOTES CARRY (hq_prolog 2026-09-24). The vendored driver READS each entry after RUNNING the one before it, so
# set_prolog_flag(double_quotes, V) changes how the next entry's "fred" is read -- set_prolog_flag's last three entries grade
# exactly that. This runner compiles each goal alone, so an entry of that shape that SUCCEEDED in a mode is carried, in that
# mode, as a leading directive into the later entries of the SAME family -- the driver's own read-after-run order, and only
# for the one flag that changes reading. A carried directive is SCRIP's own parse-time reading of it, never the runner's.
DQ_SET = re.compile(r"^\s*set_prolog_flag\(\s*double_quotes\s*,\s*([a-z]+)\s*\)\s*$")
# ⭐ A ROUND-ROBIN PART (INRIA_RR_SEL, the fam#index cases lib_rr.sh selected): only those cases run, together with every earlier double_quotes setter
# of a selected case's family, so the carry below reads the same verdicts a whole run reads
_RR = set(os.environ.get("INRIA_RR_SEL", "").split())
if _RR:
    for _i, (_f, _g, _e) in enumerate(tests):
        if "%s#%d" % (_f, _i) in _RR:
            for _j in range(_i):
                if tests[_j][0] == _f and DQ_SET.match(tests[_j][1]):
                    _RR.add("%s#%d" % (_f, _j))
def rr_skip(i):
    return bool(_RR) and ("%s#%d" % (tests[i][0], i)) not in _RR
def dq_lead(tidx, mode):
    fam, lead = tests[tidx][0], ""
    for j in range(tidx):
        m = DQ_SET.match(tests[j][1])
        if tests[j][0] == fam and m and outcome_ok.get((j, mode), False): lead = ":- set_prolog_flag(double_quotes, %s).\n" % m.group(1)
    return lead
tmp = tempfile.mkdtemp()
prog = os.path.join(tmp, "t.pl")
for _tidx, (fam, goal, exp) in enumerate(tests):
    if _tidx in OUTSIDE or rr_skip(_tidx): continue
    want, wfun = expected_class(exp)
    for mode in ("m3", "m4"):
        _cur[0] = (_tidx, mode)
        with open(prog, "w") as f:
            f.write(HARNESS_PRELUDE + dq_lead(_tidx, mode))
            f.write(":- catch( ( %s -> write('@OK') ; write('@NO') ), E, ( write('@ER('), write(E), write(')') ) ), nl.\n" % goal)
        try:
            if mode == "m3":
                r = _ltr.run(key="%s#%d" % (fam, _tidx), argv=[scrip, "--run"] + decl_sw(_tidx, fam) + [prog], capture_output=True, text=True, timeout=10, stdin=subprocess.DEVNULL, cwd=tmp)
            else:
                s = os.path.join(tmp, "t.s"); b = os.path.join(tmp, "t.bin")
                c = _ltr.run(key="%s#%d" % (fam, _tidx), argv=[scrip, "--compile", "-o", s, prog], capture_output=True, text=True, timeout=10, stdin=subprocess.DEVNULL, cwd=tmp)
                if c.returncode != 0: res[mode][1] += 1; named.append("%s:%s:m4:NOBUILD" % (fam, goal[:28])); continue
                g = _ltr.run(["gcc", "-m64", "-no-pie", s, "-o", b, "-L", os.path.join(os.path.dirname(scrip), "out"),
                                    "-lscrip_rt", "-Wl,-rpath," + os.path.join(os.path.dirname(scrip), "out"), "-lm"],
                                   capture_output=True, text=True, timeout=60, cwd=tmp)
                if g.returncode != 0: res[mode][1] += 1; named.append("%s:%s:m4:NOLINK" % (fam, goal[:28])); continue
                r = _ltr.run(key="%s#%d" % (fam, _tidx), argv=[b] + decl_sw(_tidx, fam), capture_output=True, text=True, timeout=10, stdin=subprocess.DEVNULL, cwd=tmp)
        except subprocess.TimeoutExpired:
            res[mode][2] += 1; named.append("%s:%s:%s:TIMEOUT" % (fam, goal[:28], mode)); continue
        if want == "impl_defined":
            # ran without hanging, and (for m4) built and linked -- ISO leaves the exact behavior of
            # halt/0,1 unspecified beyond terminating, so there is nothing further to grade.
            outcome_ok[(_tidx, mode)] = True; res[mode][0] += 1; continue
        o = r.stdout
        if   "@OK" in o: got, gfun = "success", None
        elif "@NO" in o: got, gfun = "failure", None
        elif "@ER" in o:
            got = "error"
            # ⛔ scrip wraps ISO errors as error(Subtype(...), Context) -- the standard shape (measured
            # directly: catch(undef_pred,E,write(E)) prints error(existence_error(procedure,undef_pred/0),
            # undef_pred/0)). Extracting only the OUTERMOST functor after "@ER(" grabs "error" every time
            # such a wrapped error is thrown, never the subtype a wanted-functor check needs -- silently
            # failing EVERY correctly-ISO-wrapped error this engine already raises, and any future one a
            # src/ cure adds (an instrument that cannot see a cure is worse than no instrument -- THE
            # INSTRUMENT LAWS). Drill into error(...) first; fall back to the bare outer functor for an
            # unwrapped ball (e.g. a plain throw(blabla)). Measured 2026-09-04, seat05.
            mm = re.search(r"@ER\(\s*error\(\s*([a-z_]+)", o)
            if not mm: mm = re.search(r"@ER\(\s*([a-z_]+)", o)
            gfun = mm.group(1) if mm else None
        else:
            res[mode][1] += 1; named.append("%s:%s:%s:NO-CLASS" % (fam, goal[:28], mode)); continue
        if (fam, goal) in OUTCOME_ERRATA:
            want, wfun, _why = OUTCOME_ERRATA[(fam, goal)]
            if (fam, goal, mode) not in outcome_erratum_hits: outcome_erratum_hits.append((fam, goal, mode))
        ok = (got == want) and (want != "error" or wfun is None or gfun == wfun)
        outcome_ok[(_tidx, mode)] = ok
        if ok: res[mode][0] += 1
        else:
            res[mode][1] += 1
            named.append("%s:%s:%s:want=%s/%s got=%s/%s" % (fam, goal[:28], mode, want, wfun, got, gfun))
print("INRIA_SUITE_BOARD total=%d m3_pass=%d m3_fail=%d m3_crash=%d m4_pass=%d m4_fail=%d m4_crash=%d OUTSIDE=%d"
      % (len(tests), res["m3"][0], res["m3"][1], res["m3"][2], res["m4"][0], res["m4"][1], res["m4"][2], len(OUTSIDE)))
print("  criterion: OUTCOME CLASS (success/failure/error + error functor); substitution bindings NOT compared -- strictly weaker than the suite's own")
if OUTSIDE:
    print("  %d entries OUTSIDE THE BASELINE (CEO-749): excluded from pass/fail in BOTH boards, named here every run, never hidden:" % len(OUTSIDE))
    for _i in sorted(OUTSIDE):
        _fam, _goal, _exp = tests[_i]
        print("    %s:%s -- %s" % (_fam, _goal[:40], OUTSIDE[_i]))
print("  %d ISO-graded errata (vendored cell contradicts its own %% comment; graded on the ISO reading, never silently -- see OUTCOME_ERRATA):" % (len(OUTCOME_ERRATA),))
for _k in sorted(OUTCOME_ERRATA):
    _w, _f, _why = OUTCOME_ERRATA[_k]
    print("    %s:%s -> graded %s%s" % (_k[0], _k[1], _w, ("/" + _f) if _f else ""))
if os.environ.get("INRIA_NAME_REDS"):
    for x in named[:60]: print("    " + x)
_gtot = len(tests) - len(OUTSIDE)   # graded denominator -- OUTSIDE entries excluded per CEO-749, never hidden (printed above)
open(os.path.join(tmp, "board"), "w").write("%d %d %d" % (_gtot, res["m3"][0], res["m4"][0]))
print("BOARD_FOR_SHELL %d %d %d" % (_gtot, res["m3"][0], res["m4"][0]))
# The progress rows are written BELOW the bindings comparator, on its per-entry verdict (CEO-331; see there).

# ⛔⭐ THE BINDINGS COMPARATOR (row prolog-inria-bindings-comparator-turns-the-outcome-class-upper-bound-into-a-true-score,
# seat05, 2026-09-04). THE ABOVE BOARD STAYS EXACTLY AS IT WAS -- not one line of it moved -- because the
# delta between it and this one IS the deliverable: how much of 268/445 was a goal reaching the right
# OUTCOME CLASS while binding the wrong thing. Method: reuse the engine's OWN unification/equality
# (`==/2`) rather than round-tripping through printed text, by splicing the suite's own Prolog syntax for
# each expected binding straight back into a comparison goal -- so quoting/formatting of atoms, numbers,
# lists and compound terms is never our problem, it is `==/2`'s. A goal with MULTIPLE declared solution
# sets (e.g. atom_concat(T1,T2,'hello') listing all 6 splits) is graded PASS if the first real solution
# (the runner already commits via `->`, matching the outcome-class check above) matches ANY one of the
# declared sets -- the suite does not mandate solution order for these, so requiring only the FIRST
# listed alternative would be a stricter and less correct reading than the suite intends.
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
# ⛔⭐ KNOWN_SUITE_ERRATA (row prolog-inria-sub-atom-decomposition-enumeration-mismatch, seat05 2026-09-04/05).
# A hardcoded (fam, exact goal text) allowlist of vendored-suite TRANSCRIPTION errors -- never scrip
# behavior taken on faith. Each entry requires an INDEPENDENT ISO reference (swipl and/or gprolog, both
# vendored per ORACLES.md) cross-checked against the SAME witness goal BEFORE it may be added here; the
# suite's own README says its data is kept verbatim ("nothing here is stripped or reformatted"), so the
# fix lives here, in the open, never as a silent edit to the vendored file. Graded outcome-class-only,
# same fallback and same visible-list treatment as excluded_fresh_named below -- never xfail, never a
# silent pass with no trace.
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
        "2026-09-23, live oracle run: swipl 9.0.4 and gprolog 1.4.5 both agree Y=3; gprolog 1.6.0, the oracle since CEO-1598, binds Y=3 too, re-measured 2026-10-10, CEO-1603).",
}
excluded_suite_erratum = []  # (fam, goal) short label for entries matched above, printed every run
excluded_fresh_named = []   # (fam, goal) this comparator refuses to check finer than outcome class
bres = {"m3": [0, 0], "m4": [0, 0]}   # pass, fail -- bindings board covers ALL 445 (non-bindings entries
                                        # inherit their outcome-class verdict: there is nothing finer to check)
bnamed = []
bok = {}   # (test index, mode) -> bool: THE per-entry verdict on the published criterion, kept for the progress rows below
for _tidx, (fam, goal, exp) in enumerate(tests):
    if _tidx in OUTSIDE or rr_skip(_tidx): continue
    want, wfun = expected_class(exp)
    sols = parse_bindings(exp) if want == "success" else None
    if sols is not None and (fam, goal) in KNOWN_SUITE_ERRATA:
        excluded_suite_erratum.append("%s:%s" % (fam, goal[:40]))
        sols = None
    elif sols is not None and has_fresh_named_var(goal, sols):
        excluded_fresh_named.append("%s:%s" % (fam, goal[:40]))
        sols = None
    for mode in ("m3", "m4"):
        _cur[0] = (_tidx, mode)
        if sols is None:
            # Nothing finer to check than outcome class -- inherit that verdict directly (never re-derive
            # it from the truncated `named` diagnostics, which can collide on goal[:28]).
            bok[(_tidx, mode)] = outcome_ok.get((_tidx, mode), False)
            bres[mode][0 if bok[(_tidx, mode)] else 1] += 1
            continue
        # ⛔ A BARE `_` ON THE VALUE SIDE MEANS "unconstrained here", NOT "==-identical to a fresh
        # variable this comparison goal just introduced" -- those are never the same variable, so a plain
        # `V == _` is a guaranteed false negative regardless of correctness (measured: 8 solution-sets
        # across bagof/setof/findall use `_` this way, e.g. findall(X+Y,(X=1),S), [[S <-- [1+_]]]). `var/1`
        # is the correct check. ⚠ NOT handled: a *named* fresh variable that recurs only inside one
        # compound value (e.g. functor(X,foo,3), [[X <-- foo(A,B,C)]], "A,B,C are 3 new variables" per the
        # suite's own comment) -- that needs structural-variant comparison (=@=/2), which does not exist in
        # this engine (existence_error(procedure,=@=/2), checked live) and a hand-rolled per-argument
        # decomposition is out of scope here; such cases are EXCLUDED from the bindings board below rather
        # than reported as a false defect -- see excluded_fresh_named.
        disj = " ; ".join(("(" + ",".join(("var(%s)" % v) if t == "_" else "%s == %s" % (v, t) for v, t in sol) + ")") if sol else "true" for sol in sols)
        with open(prog, "w") as f:
            f.write(HARNESS_PRELUDE + dq_lead(_tidx, mode))
            f.write(":- catch( ( %s -> ( (%s) -> write('@BOK') ; write('@BFAIL') ) ; write('@BNO') ), E, ( write('@BER('), write(E), write(')') ) ), nl.\n"
                     % (goal, disj))
        bok[(_tidx, mode)] = False
        try:
            if mode == "m3":
                r = _ltr.run(key="%s#%d" % (fam, _tidx), argv=[scrip, "--run"] + decl_sw(_tidx, fam) + [prog], capture_output=True, text=True, timeout=10, stdin=subprocess.DEVNULL, cwd=tmp)
            else:
                s = os.path.join(tmp, "t.s"); b = os.path.join(tmp, "t.bin")
                c = _ltr.run(key="%s#%d" % (fam, _tidx), argv=[scrip, "--compile", "-o", s, prog], capture_output=True, text=True, timeout=10, stdin=subprocess.DEVNULL, cwd=tmp)
                if c.returncode != 0: bres[mode][1] += 1; bnamed.append("%s:%s:m4:NOBUILD" % (fam, goal[:28])); continue
                g = _ltr.run(["gcc", "-m64", "-no-pie", s, "-o", b, "-L", os.path.join(os.path.dirname(scrip), "out"),
                                    "-lscrip_rt", "-Wl,-rpath," + os.path.join(os.path.dirname(scrip), "out"), "-lm"],
                                   capture_output=True, text=True, timeout=60, cwd=tmp)
                if g.returncode != 0: bres[mode][1] += 1; bnamed.append("%s:%s:m4:NOLINK" % (fam, goal[:28])); continue
                r = _ltr.run(key="%s#%d" % (fam, _tidx), argv=[b] + decl_sw(_tidx, fam), capture_output=True, text=True, timeout=10, stdin=subprocess.DEVNULL, cwd=tmp)
        except subprocess.TimeoutExpired:
            bres[mode][1] += 1; bnamed.append("%s:%s:%s:TIMEOUT" % (fam, goal[:28], mode)); continue
        o = r.stdout
        if "@BOK" in o: bres[mode][0] += 1; bok[(_tidx, mode)] = True
        else:
            bres[mode][1] += 1
            reason = "outcome-already-red" if "@BNO" in o or "@BER" in o else "wrong-bindings"
            bnamed.append("%s:%s:%s:%s(%s)" % (fam, goal[:28], mode, reason, o.strip()[:40]))
print("INRIA_SUITE_BINDINGS_BOARD total=%d m3_pass=%d m3_fail=%d m4_pass=%d m4_fail=%d OUTSIDE=%d"
      % (len(tests), bres["m3"][0], bres["m3"][1], bres["m4"][0], bres["m4"][1], len(OUTSIDE)))
print("  criterion: OUTCOME CLASS AND substitution bindings (== against the suite's own declared [[Var <-- Value]] sets, any ONE declared solution set accepted) -- the suite's own criterion, never weaker")
print("  delta vs OUTCOME-CLASS-ONLY board: m3 %+d  m4 %+d  (goals that reached the right outcome while binding the wrong thing)"
      % (bres["m3"][0] - res["m3"][0], bres["m4"][0] - res["m4"][0]))
if OUTSIDE:
    print("  %d entries OUTSIDE THE BASELINE (CEO-749): see INRIA_SUITE_BOARD above for the named list -- same %d entries, excluded here too" % (len(OUTSIDE), len(OUTSIDE)))
if excluded_suite_erratum:
    print("  %d entries graded outcome-class only (PROVEN vendored-suite transcription errata, each "
          "verified against an independent ISO reference -- see KNOWN_SUITE_ERRATA in this script):"
          % len(excluded_suite_erratum))
    for x in excluded_suite_erratum: print("    E:" + x)
if excluded_fresh_named:
    print("  %d entries graded outcome-class only (declared a NAMED fresh variable inside a compound value -- e.g. \"A, B and C are 3 new variables\" -- which needs =@=/2, not present in this engine):"
          % len(excluded_fresh_named))
    for x in excluded_fresh_named: print("    F:" + x)
if os.environ.get("INRIA_NAME_REDS"):
    for x in bnamed[:80]: print("    B:" + x)
# ⛔⭐ CEO-331: ONE ROW PER PROGRAM PER MODE INTO THE PROGRESS DATABASE -- ON THE CRITERION THE SUITE ROW STATES (row
# prolog-inria-append-carries-the-outcome-class-while-the-row-states-the-bindings-criterion, COO-84 item 3). The rows
# were written ABOVE this comparator on the outcome class alone, because it kept counters and no per-entry verdict, so
# the DB read 436 where the row published 432 on one pass. Now the comparator keeps `bok` per (index, mode) and the rows
# are written here from it: an entry with no declared bindings carries its outcome-class verdict (there is nothing finer
# to check), every other entry the bindings verdict. Both board lines stand (the outcome class is the documented upper
# bound). ⛔ THE PROGRAM KEY IS fam#INDEX, NEVER fam:goal: 2 goal texts recur verbatim across distinct entries.
_prog_rows = os.path.join(tmp, "progress_rows.tsv")
with open(_prog_rows, "w") as _pf:
    for _i, (_fam, _goal, _exp) in enumerate(tests):
        if _i in OUTSIDE or rr_skip(_i): continue
        for _m in ("m3", "m4"):
            _pf.write("package\tinria\tprolog\t%s#%d\t%s\t%s\t%.3f\toutcome-class-and-bindings\n"
                      % (_fam, _i, _m, "PASS" if bok.get((_i, _m), False) else "FAIL", isecs.get((_i, _m), 0.0)))
assert sum(1 for _k, _v in bok.items() if _v and _k[1] == "m3") == bres["m3"][0] and sum(1 for _k, _v in bok.items() if _v and _k[1] == "m4") == bres["m4"][0], "the per-entry verdicts disagree with the bindings board's counters"
print("PROGRESS_ROWS_TSV %s" % _prog_rows)
open(os.path.join(tmp, "bindings_board"), "w").write("%d %d %d" % (_gtot, bres["m3"][0], bres["m4"][0]))
print("BINDINGS_BOARD_FOR_SHELL %d %d %d" % (_gtot, bres["m3"][0], bres["m4"][0]))
PY

# ⛔ PIPESTATUS[0], NEVER $? -- the pipeline above ends in `tee`, and $? after a pipeline reports the LAST
# command's status, so a python that died would read as a clean run (CLAUDE.md, measured live on this box).
_prc=${PIPESTATUS[0]}
# ⭐ THE ROW CARRIES BOTH NUMBERS AND SAYS WHICH IS WHICH. The runner computes two boards: OUTCOME CLASS
# (success/failure/error plus the error functor) and the suite's OWN criterion, which also compares the
# declared substitution bindings. The first is strictly weaker -- this file's own header says tightening can
# only ever move the number DOWN, and it does, by 7 goals in each mode. Publishing only the outcome-class
# number would put a 61.8% on the leaderboard for a suite whose own criterion says 60.2%, so both go in the
# cell with the weaker one named as the bound it is. A conformance number that overstates itself is worse
# than no number.
# ⛔⭐ CEO-331: append the per-program rows the python side just wrote. NON-FATAL BY DESIGN, exactly like gate_score_row:
# a bookkeeping failure must never red a conformance board, because a runner that gets red-ed by its own bookkeeping is
# a runner people stop calling. The MISSING line in util_progress_flips.py --coverage is the receipt, not this exit code.
if [ -f "$HERE/lib_progress.sh" ]; then
    . "$HERE/lib_progress.sh"
    _prows="$(grep -m1 '^PROGRESS_ROWS_TSV ' "$_inria_out" | awk '{print $2}')"
    if [ -n "${_prows:-}" ] && [ -s "$_prows" ]; then progress_append_rows_tsv "$_prows" || echo "  (progress append failed -- board stands)"; fi
    rr_selected && { rr_end inria; exit 0; }   # a part or a request writes its cases' rows and no suite row (CEO-1802)
fi
_oc="$(grep -m1 '^INRIA_SUITE_BOARD ' "$_inria_out" || true)"
_bs="$(grep -m1 '^BINDINGS_BOARD_FOR_SHELL ' "$_inria_out" || true)"
if [ -n "$_oc" ]; then
    _txt="$_oc"
    if [ -n "$_bs" ]; then
        set -- $_bs
        _txt="inriasuite (ISO/IEC 13211-1) $3/$2 m3 · $4/$2 m4 by the suite's OWN criterion (outcome class AND declared bindings) — $_oc is the OUTCOME-CLASS-ONLY upper bound, which ignores what a goal bound and can only move down when tightened"
    fi
    # ⛔ DENOMINATOR MOVES 445 -> 442 ON THIS LANDING: 3 file_manip entries newly named OUTSIDE THE
    # BASELINE (CEO-749, this same commit) -- util_score_row.py REFUSES a silent denominator move
    # (CEO-546/749 dishonest-denominator class), so every write from here on stamps the reason. Harmless
    # once the denominator is already 442 in SUITES.tsv; the writer only enforces the check on a MOVE.
    gate_score_row prolog vendor "$_txt" m3,m4 INRIA \
        "2026-09-23:file_manip's 3 entries (aux=in(my_file)) need the unvendored run_forest/bips-ex fixture from prologsuite.tar.gz, never fetched -- named OUTSIDE THE BASELINE per CEO-749 rather than graded against a fabricated verdict, denominator 445 -> 442"
else
    # A missing board line is not a zero -- say so rather than writing a row for a run that produced nothing.
    echo "⚠ SCORE.md NOT UPDATED [$GATE_NAME]: the run printed no INRIA_SUITE_BOARD line, so there is no measurement to record"
fi
rm -f "$_inria_out" "$_inria_decl"
exit "$_prc"
