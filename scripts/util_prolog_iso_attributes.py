#!/usr/bin/env python3
"""util_prolog_iso_attributes.py -- THE FEATURE-ATTRIBUTE TABLE OF THE PROLOG ISO SUITES (Lon 2026-09-12 to the
cto, verbatim: "Has a full feature attribute TSV/CSV file been created for all the Prolog test suites. See what we
did for SNOBOL4 rungs suite with 100's of attributes. It help to triage failure sets.").

WHAT IT WRITES. One ALL.csv per ISO package, in the shape every other package table already has
(corpus/packages/snobol4/gimpel/ALL.csv, corpus/packages/icon/ipl/ALL.csv): the seven fixed leading columns
    rank,entry,origin,package,n_lines,stdin,want_rc
then the Prolog attribute columns:
    section   the suite's own section (Logtalk: the directory basename, INRIA: the builtin-family file)
    kind      what the case expects -- succ / fail / error (Logtalk also: ungradable, the runner's own named refusal)
    err       the expected error functor (type_error, instantiation_error, ...) or empty
    err_arg   the first argument of that error (callable, integer, evaluable, ...) or empty
then ~170 0/1 feature flags: every ISO builtin, control construct, evaluable function and directive the case's
goal names, and the syntax it exercises (quoted atoms, double-quoted strings, 0'c literals, escapes, floats,
unbounded integers, curly terms, lists, non-ASCII). A flag is 1 when the goal TEXT (and its helper clauses)
mentions the name in callable position -- `foo(` -- or as a bare atom/operator; it says what the case
TOUCHES, never what it is ABOUT (the section says that).

⛔ THE ENTRY IS THE PROGRESS DATABASE'S OWN PROGRAM NAME, spelled exactly as the two runners record it
(Logtalk `group:case`, INRIA `family#index`), so `--triage` can JOIN the table to the last board without a
second naming scheme. That join is the whole point: a failure set read by attribute instead of by name.

MODES.
    --write            regenerate both ALL.csv files in place (corpus/packages/prolog/{logtalk_iso,inriasuite})
    --check            rc=1 if a regenerated table differs from the file on disk (the staleness gate)
    --triage [SUITE]   read the latest board of each suite from the progress database and print the failure set
                       by section, kind, err and by feature (fail rate per feature, highest first)
    --triage-csv PATH  also write the joined rows (attributes + m3/m4 outcome + note) as one CSV

⛔ INRIA'S READER HERE IS THE RUNNER'S OWN `_mask_0c_lits` AND `parse`, COPIED VERBATIM from the python block
of test_prolog_inria_suite.sh (a shell heredoc cannot be imported; a re-implementation was measured first and
read 435 goals where the runner reads 445 -- ten goals lost to 0'c literals beside quotes, and every index after
the first loss misnamed, so the join to the board failed on 187 rows). `--check` asserts the population equals
the runner's printed denominator (445), so a drift between the two copies is caught the day it happens.
"""
import csv
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(HERE, "..", "..", "SCRIP", ".."))
CORPUS = os.environ.get("S4E_CORPUS") or os.path.join(ROOT, "corpus")
PROGRESS = os.environ.get("S4E_PROGRESS_DB") or "/home/resources/progress/results.tsv"
LOGTALK = os.path.join(CORPUS, "packages", "prolog", "logtalk_iso")
INRIA = os.path.join(CORPUS, "packages", "prolog", "inriasuite")
INRIA_POPULATION = 445

sys.path.insert(0, HERE)

FIXED = ["rank", "entry", "origin", "package", "n_lines", "stdin", "want_rc", "heap_kb", "stack_kb", "compile_args", "run_args",
         "section", "kind", "err", "err_arg"]
# ⛔ DECLARED, NEVER DERIVED: a program's heap, stack and command line (CEO-1261; clause 8 (f), CEO-1281) are carried forward
# from the table on disk by entry -- nothing in a goal's text regenerates them. Before this line --write dropped heap_kb and
# stack_kb, which corpus 4d805e1bc wrote into both tables, and --check read both tables STALE.
DECLARED = {"heap_kb": "131072", "stack_kb": "4096", "compile_args": "", "run_args": ""}

CONTROL = ["call", "call_N", "catch", "throw", "cut", "ite", "softcut", "negation", "disj", "conj", "once", "ignore",
           "forall", "findall", "findall_4", "bagof", "setof", "aggregate_all", "between", "succ", "plus", "halt",
           "setup_call_cleanup", "call_cleanup", "call_nth", "repeat", "true", "fail", "false", "not"]
DATABASE = ["assert", "asserta", "assertz", "retract", "retractall", "abolish", "clause", "dynamic", "discontiguous",
            "multifile", "current_predicate", "predicate_property", "initialization", "ensure_loaded", "include",
            "consult", "op", "current_op", "set_prolog_flag", "current_prolog_flag", "char_conversion",
            "current_char_conversion"]
TERMS = ["functor", "arg", "univ", "copy_term", "term_variables", "compare", "unify", "not_unify", "eq", "ne",
         "term_lt", "term_le", "term_gt", "term_ge", "unify_with_occurs_check", "subsumes_term", "acyclic_term",
         "ground", "var", "nonvar", "atom", "number", "integer", "float", "atomic", "compound", "callable",
         "is_list", "sort", "msort", "keysort", "length", "predsort", "nb_setval", "nb_getval", "b_setval", "b_getval",
         "tab"]
ATOMS = ["atom_codes", "atom_chars", "atom_length", "atom_concat", "sub_atom", "char_code", "number_codes",
         "number_chars", "atom_number", "atom_to_term", "term_to_atom", "atomic_list_concat", "atomic_concat",
         "upcase_atom", "downcase_atom", "atom_string", "string_concat", "string_chars", "string_codes", "string_to_atom",
         "number_vars", "numbervars", "read_term_from_atom"]
ARITH = ["is", "arith_eq", "arith_ne", "arith_lt", "arith_le", "arith_gt", "arith_ge", "add", "sub", "mul", "fdiv",
         "idiv", "div", "mod", "rem", "abs", "sign", "min", "max", "gcd", "sqrt", "sin", "cos", "tan", "asin", "acos",
         "atan", "atan2", "sinh", "cosh", "tanh", "asinh", "acosh", "atanh", "exp", "log", "log2", "log10", "float_fn",
         "integer_fn", "float_integer_part", "float_fractional_part", "truncate", "round", "ceiling", "floor", "shr",
         "shl", "bitand", "bitor", "xor", "bitnot", "msb", "lsb", "popcount", "power", "intpower", "pi", "e_const",
         "inf", "nan", "epsilon", "max_integer", "min_integer", "random", "cot", "copysign", "nexttoward", "trig_deg"]
IO = ["open", "close", "read", "read_term", "write", "writeq", "write_canonical", "write_term", "print", "nl",
      "put_char", "get_char", "peek_char", "put_code", "get_code", "peek_code", "put_byte", "get_byte", "peek_byte",
      "flush_output", "stream_property", "set_stream_position", "at_end_of_stream", "set_input", "set_output",
      "current_input", "current_output", "current_stream", "format", "format_3", "set_stream", "see", "seen", "tell", "told",
      "user_input", "user_output", "user_error", "stream_alias", "stream_opt", "write_opt"]
SYNTAX = ["quoted_atom", "dq_string", "bq_string", "char_lit", "esc_seq", "float_lit", "neg_num", "bigint",
          "hex_lit", "oct_lit", "bin_lit", "curly", "list", "partial_list", "op_expr", "unicode", "var_goal",
          "anon_var", "nested_call", "layout_comment", "end_dot", "infix_def", "prefix_def", "postfix_def",
          "flag_double_quotes", "flag_unknown", "flag_bounded", "flag_char_conversion", "flag_max_arity",
          "flag_debug", "flag_occurs_check"]
FEATURES = CONTROL + DATABASE + TERMS + ATOMS + ARITH + IO + SYNTAX

_NAME_CALL = {
    "call": ("call",), "catch": ("catch",), "throw": ("throw",), "once": ("once",), "ignore": ("ignore",),
    "forall": ("forall",), "findall": ("findall",), "bagof": ("bagof",), "setof": ("setof",),
    "aggregate_all": ("aggregate_all",), "between": ("between",), "succ": ("succ",), "plus": ("plus",),
    "halt": ("halt",), "setup_call_cleanup": ("setup_call_cleanup",), "call_cleanup": ("call_cleanup",),
    "call_nth": ("call_nth",), "not": ("not", "negation"),
    "assert": ("assert",), "asserta": ("asserta",), "assertz": ("assertz",), "retract": ("retract",),
    "retractall": ("retractall",), "abolish": ("abolish",), "clause": ("clause",), "dynamic": ("dynamic",),
    "discontiguous": ("discontiguous",), "multifile": ("multifile",), "current_predicate": ("current_predicate",),
    "predicate_property": ("predicate_property",), "initialization": ("initialization",),
    "ensure_loaded": ("ensure_loaded",), "include": ("include",), "consult": ("consult",), "op": ("op",),
    "current_op": ("current_op",), "set_prolog_flag": ("set_prolog_flag",),
    "current_prolog_flag": ("current_prolog_flag",), "char_conversion": ("char_conversion",),
    "current_char_conversion": ("current_char_conversion",),
    "functor": ("functor",), "arg": ("arg",), "copy_term": ("copy_term",), "term_variables": ("term_variables",),
    "compare": ("compare",), "unify_with_occurs_check": ("unify_with_occurs_check",),
    "subsumes_term": ("subsumes_term",), "acyclic_term": ("acyclic_term",), "ground": ("ground",), "var": ("var",),
    "nonvar": ("nonvar",), "atom": ("atom",), "number": ("number",), "integer": ("integer",), "float": ("float",),
    "atomic": ("atomic",), "compound": ("compound",), "callable": ("callable",), "is_list": ("is_list",),
    "sort": ("sort",), "msort": ("msort",), "keysort": ("keysort",), "length": ("length",), "predsort": ("predsort",),
    "nb_setval": ("nb_setval",), "nb_getval": ("nb_getval",), "b_setval": ("b_setval",), "b_getval": ("b_getval",),
    "tab": ("tab",),
    "atom_codes": ("atom_codes",), "atom_chars": ("atom_chars",), "atom_length": ("atom_length",),
    "atom_concat": ("atom_concat",), "sub_atom": ("sub_atom",), "char_code": ("char_code",),
    "number_codes": ("number_codes",), "number_chars": ("number_chars",), "atom_number": ("atom_number",),
    "atom_to_term": ("atom_to_term",), "term_to_atom": ("term_to_atom",), "atomic_list_concat": ("atomic_list_concat",),
    "atomic_concat": ("atomic_concat",), "upcase_atom": ("upcase_atom",), "downcase_atom": ("downcase_atom",),
    "atom_string": ("atom_string",), "string_concat": ("string_concat",), "string_chars": ("string_chars",),
    "string_codes": ("string_codes",), "string_to_atom": ("string_to_atom",), "numbervars": ("numbervars",),
    "read_term_from_atom": ("read_term_from_atom",),
    "abs": ("abs",), "sign": ("sign",), "min": ("min",), "max": ("max",), "gcd": ("gcd",), "sqrt": ("sqrt",),
    "sin": ("sin",), "cos": ("cos",), "tan": ("tan",), "asin": ("asin",), "acos": ("acos",), "atan": ("atan",),
    "atan2": ("atan2",), "sinh": ("sinh",), "cosh": ("cosh",), "tanh": ("tanh",), "asinh": ("asinh",),
    "acosh": ("acosh",), "atanh": ("atanh",), "exp": ("exp",), "log": ("log",), "log2": ("log2",), "log10": ("log10",),
    "float_integer_part": ("float_integer_part",), "float_fractional_part": ("float_fractional_part",),
    "truncate": ("truncate",), "round": ("round",), "ceiling": ("ceiling",), "floor": ("floor",), "msb": ("msb",),
    "lsb": ("lsb",), "popcount": ("popcount",), "random": ("random",), "cot": ("cot",), "copysign": ("copysign",),
    "nexttoward": ("nexttoward",), "mod": ("mod",), "rem": ("rem",), "div": ("div",), "xor": ("xor",),
    "open": ("open",), "close": ("close",), "read": ("read",), "read_term": ("read_term",), "write": ("write",),
    "writeq": ("writeq",), "write_canonical": ("write_canonical",), "write_term": ("write_term",), "print": ("print",),
    "nl": ("nl",), "put_char": ("put_char",), "get_char": ("get_char",), "peek_char": ("peek_char",),
    "put_code": ("put_code",), "get_code": ("get_code",), "peek_code": ("peek_code",), "put_byte": ("put_byte",),
    "get_byte": ("get_byte",), "peek_byte": ("peek_byte",), "flush_output": ("flush_output",),
    "stream_property": ("stream_property",), "set_stream_position": ("set_stream_position",),
    "at_end_of_stream": ("at_end_of_stream",), "set_input": ("set_input",), "set_output": ("set_output",),
    "current_input": ("current_input",), "current_output": ("current_output",), "current_stream": ("current_stream",),
    "format": ("format",), "set_stream": ("set_stream",), "see": ("see",), "seen": ("seen",), "tell": ("tell",),
    "told": ("told",), "repeat": ("repeat",), "true": ("true",), "fail": ("fail",), "false": ("false",),
}
_BARE = {"nl": "nl", "halt": "halt", "true": "true", "fail": "fail", "false": "false", "repeat": "repeat",
         "pi": "pi", "e": "e_const", "inf": "inf", "nan": "nan", "epsilon": "epsilon", "max_integer": "max_integer",
         "min_integer": "min_integer", "user_input": "user_input", "user_output": "user_output",
         "user_error": "user_error", "at_end_of_stream": "at_end_of_stream", "flush_output": "flush_output",
         "told": "told", "seen": "seen", "cot": "cot", "random": "random", "float": "float_fn", "integer": "integer_fn"}
_OPS = [("=..", "univ"), ("\\=@=", None), ("=@=", None), ("\\==", "ne"), ("==", "eq"), ("\\=", "not_unify"),
        ("=:=", "arith_eq"), ("=\\=", "arith_ne"), ("=<", "arith_le"), (">=", "arith_ge"), ("@=<", "term_le"),
        ("@>=", "term_ge"), ("@<", "term_lt"), ("@>", "term_gt"), ("*->", "softcut"), ("->", "ite"), ("\\+", "negation"),
        ("**", "power"), ("^", "intpower"), (">>", "shr"), ("<<", "shl"), ("/\\", "bitand"), ("\\/", "bitor"),
        ("//", "idiv"), ("\\", "bitnot")]
_FLAGS = {"double_quotes": "flag_double_quotes", "unknown": "flag_unknown", "bounded": "flag_bounded",
          "char_conversion": "flag_char_conversion", "max_arity": "flag_max_arity", "debug": "flag_debug",
          "occurs_check": "flag_occurs_check"}
_STREAM_OPTS = ("alias(", "eof_action(", "reposition(", "type(", "encoding(", "position(", "end_of_stream(",
                "file_name(", "mode(", "input", "output", "eof_code", "buffer(")
_WRITE_OPTS = ("quoted(", "ignore_ops(", "numbervars(", "max_depth(", "portray(", "variable_names(",
               "variables(", "singletons(")


def _strip_quotes(s):
    """The goal with every quoted atom/string body blanked, so names inside quotes never count as calls."""
    out = []
    i = 0
    n = len(s)
    while i < n:
        ch = s[i]
        if ch == "0" and i + 1 < n and s[i + 1] == "'":
            j = i + 4 if (i + 2 < n and s[i + 2] == "\\") else i + 3
            out.append("0'_")
            i = min(j, n)
            continue
        if ch in "'\"`":
            q = ch
            j = i + 1
            while j < n:
                if s[j] == "\\":
                    j += 2
                    continue
                if s[j] == q:
                    if j + 1 < n and s[j + 1] == q:
                        j += 2
                        continue
                    break
                j += 1
            out.append(q + "_" + q)
            i = j + 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def features_of(text):
    """The 0/1 feature vector of one case's goal text (helpers folded in by the caller)."""
    f = dict((k, 0) for k in FEATURES)
    raw = text or ""
    bare = _strip_quotes(raw)
    for m in re.finditer(r"(?<![A-Za-z0-9_'])([a-z][A-Za-z0-9_]*)\s*\(", bare):
        nm = m.group(1)
        for k in _NAME_CALL.get(nm, ()):
            f[k] = 1
        if nm == "call":
            inner = bare[m.end():]
            depth = 1
            j = 0
            commas = 0
            while j < len(inner) and depth > 0:
                c = inner[j]
                if c in "([{":
                    depth += 1
                elif c in ")]}":
                    depth -= 1
                elif c == "," and depth == 1:
                    commas += 1
                j += 1
            if commas >= 1:
                f["call_N"] = 1
        if nm == "findall":
            inner = bare[m.end():]
            if inner.count(",") >= 3:
                f["findall_4"] = 1
        if nm == "format":
            inner = bare[m.end():m.end() + 200]
            if re.match(r"\s*[a-zA-Z_'\"\[]", inner) and inner.count(",") >= 2:
                f["format_3"] = 1
    for tok in re.findall(r"(?<![A-Za-z0-9_'])([a-z][A-Za-z0-9_]*)(?![A-Za-z0-9_(])", bare):
        if tok in _BARE:
            f[_BARE[tok]] = 1
        if tok == "is":
            f["is"] = 1
        if tok in ("mod", "rem", "div", "xor"):
            f[tok] = 1
    ops = bare
    for op, key in _OPS:
        if op in ops:
            if key:
                f[key] = 1
            ops = ops.replace(op, " ")
    if re.search(r"(?<![=\\@<>:*/+\-])=(?![=<>.:\\])", ops):
        f["unify"] = 1
    if re.search(r"(?<![=\\@<>*/+\-])<(?![=<])", ops):
        f["arith_lt"] = 1
    if re.search(r"(?<![=\\@<>*/+\-])>(?![=>])", ops):
        f["arith_gt"] = 1
    if re.search(r"(?<![*/])\*(?![*/>])", ops):
        f["mul"] = 1
    if re.search(r"(?<![*/])/(?![/\\*])", ops):
        f["fdiv"] = 1
    if re.search(r"[A-Za-z0-9_)\]]\s*\+\s*[A-Za-z0-9_(\[]", ops):
        f["add"] = 1
    if re.search(r"[A-Za-z0-9_)\]]\s*-\s*[A-Za-z0-9_(\[]", ops):
        f["sub"] = 1
    if re.search(r"(?<![A-Za-z0-9_])!(?![A-Za-z0-9_])", bare):
        f["cut"] = 1
    if re.search(r"(?<![|\\]);", bare):
        f["disj"] = 1
    if "," in bare:
        f["conj"] = 1
    if "'" in raw and re.search(r"'(?:[^'\\]|\\.|'')*'", raw):
        f["quoted_atom"] = 1
    if re.search(r'"(?:[^"\\]|\\.)*"', raw):
        f["dq_string"] = 1
    if re.search(r"`(?:[^`\\]|\\.)*`", raw):
        f["bq_string"] = 1
    if re.search(r"(?<![A-Za-z0-9_])0'", raw):
        f["char_lit"] = 1
    if re.search(r"""['"`][^'"`]*\\[^'"`]*['"`]""", raw) or re.search(r"\\[nrtabfv0xe\\'\"`]", raw):
        f["esc_seq"] = 1
    if re.search(r"(?<![A-Za-z0-9_])\d+\.\d+(?:[eE][+-]?\d+)?", bare) or re.search(r"(?<![A-Za-z0-9_.])\d+[eE][+-]?\d+", bare):
        f["float_lit"] = 1
    if re.search(r"(?<![A-Za-z0-9_)\]])\s*-\s*\d", bare):
        f["neg_num"] = 1
    for m in re.finditer(r"(?<![A-Za-z0-9_.'])(\d{16,})", bare):
        if int(m.group(1)) > 9223372036854775807:
            f["bigint"] = 1
    if re.search(r"(?<![A-Za-z0-9_])0x[0-9a-fA-F]+", bare):
        f["hex_lit"] = 1
    if re.search(r"(?<![A-Za-z0-9_])0o[0-7]+", bare):
        f["oct_lit"] = 1
    if re.search(r"(?<![A-Za-z0-9_])0b[01]+", bare):
        f["bin_lit"] = 1
    if "{" in bare:
        f["curly"] = 1
    if "[" in bare:
        f["list"] = 1
    if re.search(r"\|\s*[A-Z_]", bare):
        f["partial_list"] = 1
    if re.search(r"\bop\(", bare) or f["op"]:
        f["op_expr"] = 1
        if re.search(r"\bop\([^,]*,\s*[xy]f[xy]\s*,", bare):
            f["infix_def"] = 1
        if re.search(r"\bop\([^,]*,\s*f[xy]\s*,", bare):
            f["prefix_def"] = 1
        if re.search(r"\bop\([^,]*,\s*[xy]f\s*,", bare):
            f["postfix_def"] = 1
    if any(ord(c) > 127 for c in raw):
        f["unicode"] = 1
    if re.search(r"(?:^|[,;(]|->)\s*[A-Z_][A-Za-z0-9_]*\s*(?:[,;)]|->|$)", bare):
        f["var_goal"] = 1
    if re.search(r"(?<![A-Za-z0-9_])_(?![A-Za-z0-9_])", bare):
        f["anon_var"] = 1
    if re.search(r"\b(call|findall|bagof|setof|catch|forall|once|\\\+)\s*\([^()]*\b(call|findall|bagof|setof|catch|forall|once)\s*\(", bare):
        f["nested_call"] = 1
    if "%" in raw or "/*" in raw:
        f["layout_comment"] = 1
    for flag, key in _FLAGS.items():
        if re.search(r"(?:set_prolog_flag|current_prolog_flag)\s*\(\s*%s\b" % flag, bare):
            f[key] = 1
    if any(o in bare for o in _STREAM_OPTS) and (f["open"] or f["stream_property"] or f["set_stream"]):
        f["stream_opt"] = 1
    if any(o in bare for o in _WRITE_OPTS):
        f["write_opt"] = 1
    if re.search(r"\b(user_input|user_output|user_error)\b", bare) or re.search(r"alias\(", bare):
        f["stream_alias"] = 1
    return f


def _err_of(balls):
    """(err functor, first argument) of the first expected ball, or ('', '')."""
    for b in balls:
        m = re.match(r"\s*error\(\s*([a-z_]+)(?:\(\s*([^,()]+)\s*(?:,|\)))?", b)
        if m:
            return m.group(1), (m.group(2) or "").strip()
        m = re.match(r"\s*([a-z_]+)(?:\(\s*([^,()]+)\s*(?:,|\)))?", b)
        if m:
            return m.group(1), (m.group(2) or "").strip()
    return "", ""


def logtalk_rows():
    import util_logtalk_extract as ex
    import util_logtalk_grade as gr
    supported = gr.shim_helpers()
    rows = []
    files, bad = ex.parse_suite(LOGTALK)
    if bad:
        raise SystemExit("REFUSED: the suite parser refuses %d file(s): %s" % (len(bad), bad[0]))
    for fc in files:
        keep, dropped = gr.split_db(fc.db)
        for c in fc.cases:
            plan = gr.plan_case(c, supported)
            if plan.skip_reason:
                kind = "ungradable"
            elif plan.want == "succ":
                kind = "succ"
            elif plan.want == "fail":
                kind = "fail"
            else:
                kind = "error"
            err, err_arg = _err_of(plan.balls) if kind == "error" else ("", "")
            text = plan.goal or c.goal or ""
            helper_text = ""
            for h in (c.helpers or []):
                for cl in keep:
                    if re.match(r"\s*'?%s'?\s*(\(|:-|\.|$)" % re.escape(h.strip("'")), cl):
                        helper_text += " " + cl
            f = features_of(text + " " + helper_text)
            rel = os.path.relpath(fc.path, LOGTALK)
            rows.append(dict(entry="%s:%s" % (c.group, c.name), origin=rel, package="logtalk_iso",
                             n_lines=str((c.raw or "").count("\n") + 1), stdin="0", want_rc="0",
                             section=c.group, kind=kind, err=err, err_arg=err_arg, **f))
    rows.sort(key=lambda r: (r["origin"], r["entry"]))
    return rows


def _mask_0c_lits(s):
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


def _inria_parse(path):
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
        body, ph = _mask_0c_lits(body_raw)
        depth = 0; cut = -1; q = False
        for i, ch in enumerate(body):
            if ch == "'": q = not q; continue
            if q: continue
            if ch in "([{": depth += 1
            elif ch in ")]}": depth -= 1
            elif ch == "," and depth == 0: cut = i; break
        if cut < 0: continue
        g, e = body[:cut].strip(), body[cut+1:].strip()
        for key, tok in ph.items():
            g = g.replace(key, tok); e = e.replace(key, tok)
        out.append((g, e))
    return out


def inria_rows():
    rows = []
    idx = 0
    for fn in sorted(os.listdir(INRIA)):
        p = os.path.join(INRIA, fn)
        if not os.path.isfile(p) or fn.endswith((".md", ".txt", ".pl", ".obp")) or fn in ("README",):
            continue
        for goal, exp in _inria_parse(p):
            e = exp.strip()
            if e == "success" or e.startswith("["):
                kind, err, err_arg = "succ", "", ""
            elif e == "failure":
                kind, err, err_arg = "fail", "", ""
            elif e == "impl_defined":
                kind, err, err_arg = "impl_defined", "", ""
            else:
                kind = "error"
                err, err_arg = _err_of([e])
            f = features_of(goal)
            rows.append(dict(entry="%s#%d" % (fn, idx), origin=fn, package="inriasuite", n_lines="1", stdin="0",
                             want_rc="0", section=fn, kind=kind, err=err, err_arg=err_arg, **f))
            idx += 1
    return rows


def carry_declared(rows, path):
    """Fill each row's DECLARED cells from the table at `path`, by entry; an entry the table does not hold takes SPITBOL's
    -d128m -s4m and no command line, what every other table writer gives a new row."""
    old = {}
    if os.path.exists(path):
        with open(path, newline="", encoding="utf-8") as f:
            old = {r["entry"]: r for r in csv.DictReader(f)}
    for r in rows:
        o = old.get(r["entry"], {})
        for k, d in DECLARED.items():
            r[k] = (o.get(k) or "").strip() or d
    return rows


def table_fixed(path):
    """FIXED as the table at `path` carries it: a table that predates the command-line columns keeps its shape (a rewrite never
    imposes a column the table was not given); a new table gets all of FIXED."""
    if not os.path.exists(path):
        return FIXED
    with open(path, newline="", encoding="utf-8") as f:
        hdr = next(csv.reader(f), [])
    return [k for k in FIXED if k not in ("compile_args", "run_args") or k in hdr]


def render(rows, fixed=FIXED):
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    w.writerow(fixed + FEATURES)
    for i, r in enumerate(rows, 1):
        w.writerow([str(i)] + [r[k] for k in fixed[1:]] + [str(r[k]) for k in FEATURES])
    return buf.getvalue()


TABLES = [("logtalk", LOGTALK, logtalk_rows), ("inria", INRIA, inria_rows)]


def do_write(which):
    for name, root, fn in TABLES:
        if which not in ("all", name):
            continue
        path = os.path.join(root, "ALL.csv")
        rows = carry_declared(fn(), path)
        text = render(rows, table_fixed(path))
        open(path, "w", encoding="utf-8").write(text)
        print("wrote %s: %d rows, %d columns (%d features)" % (path, len(rows), len(FIXED) + len(FEATURES), len(FEATURES)))
    return 0


def do_check(which):
    rc = 0
    for name, root, fn in TABLES:
        if which not in ("all", name):
            continue
        rows = fn()
        if name == "inria" and len(rows) != INRIA_POPULATION:
            print("⛔ CHECK [%s]: this reader finds %d goals, the runner's denominator is %d -- the two readers drifted" % (name, len(rows), INRIA_POPULATION))
            rc = 1
        path = os.path.join(root, "ALL.csv")
        if not os.path.exists(path):
            print("⛔ CHECK [%s]: %s is missing -- run --write" % (name, path))
            rc = 1
            continue
        if open(path, encoding="utf-8").read() != render(carry_declared(rows, path), table_fixed(path)):
            print("⛔ CHECK [%s]: %s is STALE against the suite on disk -- run --write" % (name, path))
            rc = 1
        else:
            print("ok [%s]: %s matches the suite (%d rows)" % (name, path, len(rows)))
    return rc


def latest_board(suite):
    """{program: (m3, m4, note)} for the newest board of `suite` in the progress database, plus its stamp."""
    if not os.path.exists(PROGRESS):
        return None, {}
    latest = None
    for line in open(PROGRESS, encoding="utf-8", errors="replace"):
        c = line.rstrip("\n").split("\t")
        if len(c) < 12 or c[5] != suite or c[6] != "prolog":
            continue
        if latest is None or c[0] > latest:
            latest = c[0]
    out = {}
    if latest is None:
        return None, out
    scrip = ""
    for line in open(PROGRESS, encoding="utf-8", errors="replace"):
        c = line.rstrip("\n").split("\t")
        if len(c) < 12 or c[5] != suite or c[0] != latest:
            continue
        scrip = c[1]
        e = out.setdefault(c[7], ["", "", ""])
        if c[8] == "m3":
            e[0] = c[9]
        elif c[8] == "m4":
            e[1] = c[9]
        if c[11]:
            e[2] = c[11]
    return (latest, scrip), out


def do_triage(which, csv_out):
    joined = []
    for name, root, fn in TABLES:
        if which not in ("all", name):
            continue
        rows = fn()
        stamp, board = latest_board(name)
        if stamp is None:
            print("== %s: no board in %s" % (name, PROGRESS))
            continue
        print("== %s: board %s at scrip %s, %d table rows, %d board rows" % (name, stamp[0], stamp[1], len(rows), len(board)))
        unmatched = 0
        for r in rows:
            b = board.get(r["entry"])
            if b is None:
                unmatched += 1
                r["m3"], r["m4"], r["note"] = "", "", ""
            else:
                r["m3"], r["m4"], r["note"] = b
            r["red"] = 1 if (r["m3"] not in ("PASS", "") or r["m4"] not in ("PASS", "")) else 0
            joined.append(r)
        if unmatched:
            print("   ⚠ %d table rows have no board row (the runner records them under another name, or the board is older than the suite)" % unmatched)
        reds = [r for r in rows if r["red"]]
        print("   red (either mode not PASS): %d of %d" % (len(reds), len(rows)))

        def hist(key, rs, top=40):
            h = {}
            for r in rs:
                h[r[key]] = h.get(r[key], 0) + 1
            return sorted(h.items(), key=lambda kv: -kv[1])[:top]
        print("   by kind (red/total):")
        tot = {}
        for r in rows:
            t = tot.setdefault(r["kind"], [0, 0])
            t[1] += 1
            t[0] += r["red"]
        for k, (a, b) in sorted(tot.items(), key=lambda kv: -kv[1][0]):
            print("      %-14s %4d / %4d" % (k, a, b))
        print("   by expected error (red/total, error cases only):")
        tot = {}
        for r in rows:
            if r["kind"] != "error":
                continue
            t = tot.setdefault(r["err"] + ("(" + r["err_arg"] + ")" if r["err_arg"] else ""), [0, 0])
            t[1] += 1
            t[0] += r["red"]
        for k, (a, b) in sorted(tot.items(), key=lambda kv: -kv[1][0])[:30]:
            print("      %-40s %4d / %4d" % (k, a, b))
        print("   by section (red/total, top 40):")
        tot = {}
        for r in rows:
            t = tot.setdefault(r["section"], [0, 0])
            t[1] += 1
            t[0] += r["red"]
        for k, (a, b) in sorted(tot.items(), key=lambda kv: -kv[1][0])[:40]:
            print("      %-32s %4d / %4d" % (k, a, b))
        print("   by outcome pair m3/m4 (red only):")
        for k, n in hist("m3", reds, 10):
            print("      m3=%-10s %4d" % (k, n))
        print("   by feature -- red share of the cases touching it (feature: red/total), features with >= 5 cases, worst first:")
        ft = []
        for k in FEATURES:
            n = sum(1 for r in rows if r[k])
            if n < 5:
                continue
            rd = sum(1 for r in rows if r[k] and r["red"])
            ft.append((rd / float(n), rd, n, k))
        for share, rd, n, k in sorted(ft, reverse=True)[:60]:
            print("      %-26s %4d / %4d  (%3d%%)" % (k, rd, n, int(share * 100)))
    if csv_out and joined:
        with open(csv_out, "w", encoding="utf-8") as fh:
            w = csv.writer(fh, lineterminator="\n")
            w.writerow(FIXED + ["m3", "m4", "red", "note"] + FEATURES)
            for i, r in enumerate(joined, 1):
                w.writerow([str(i)] + [r[k] for k in FIXED[1:]] + [r["m3"], r["m4"], str(r["red"]), r.get("note", "")] + [str(r[k]) for k in FEATURES])
        print("wrote %s (%d joined rows)" % (csv_out, len(joined)))
    return 0


def main(argv):
    which = "all"
    mode = None
    csv_out = None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--write", "--check", "--triage"):
            mode = a[2:]
        elif a == "--triage-csv":
            mode = mode or "triage"
            csv_out = argv[i + 1]
            i += 1
        elif a in ("logtalk", "inria", "all"):
            which = a
        else:
            sys.stderr.write("usage: util_prolog_iso_attributes.py [--write|--check|--triage [--triage-csv PATH]] [logtalk|inria|all]\n")
            return 2
        i += 1
    if mode == "write":
        return do_write(which)
    if mode == "check":
        return do_check(which)
    if mode == "triage":
        return do_triage(which, csv_out)
    sys.stderr.write("usage: util_prolog_iso_attributes.py [--write|--check|--triage [--triage-csv PATH]] [logtalk|inria|all]\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
