#!/usr/bin/env python3
"""util_gen_prolog_prelude_libs.py -- SWI-PROLOG'S PURE-PROLOG LIBRARIES AS PRELUDE SOURCES (CEO-1473; cfo 2026-10-10,
row prolog-swi-library-modules-rbtrees-assoc-ordsets-apply-error-pairs-aggregate-option-strings-516-swi-cases).

THE RULING (CEO-1473, approved inside CEO-1352 (5)): swipl's pure-Prolog libraries are vendored under
src/parsers/prolog/prelude/<lib>.pl with their BSD headers, embedded by a generator at build like the parsers, pulled only
by the prelude's existing name-reference closure (a program naming none pays nothing); no run-time file loading.  A
library whose closure names a C-side builtin SCRIP lacks gets that builtin as a row first or the predicate hand-typed,
never a silent stub.

WHAT THIS SCRIPT DOES.  It reads every src/parsers/prolog/prelude/*.pl (VERBATIM copies of swipl 9.0.4's library files,
the version every SWI ref was cut from) and writes src/parsers/prolog/prolog_prelude_libs.inc, a committed table of
const data that prolog_parse.c includes.  Per library it emits the export list (name/arity, a DCG export name//N as
N+2) and its SOURCE as SCRIP will parse it.  THE INJECTOR (prolog_parse.c pl_libs_append) parses a library only when the
program references one of its exports by name/arity (or by the bare name, a closure) that the BASE prelude does not
define -- the base wins per key, so a reference the base answers selects nothing -- and then, from the name/arity
references it finds in the parsed library, selects the libraries that one needs, to a fixpoint.  The embedded text:

  (1) THE MODULE IS FLATTENED, NOT IGNORED.  SCRIP has no module system, so a library's non-exported predicates would
      share one namespace with the user's program, with the base prelude and with every other library (assoc.pl and
      rbtrees.pl both define helpers by the same names).  Every predicate a library defines and does not export is
      renamed '$<lib>_<name>' AT ITS PREDICATE REFERENCES ONLY -- its heads, the body goals that call it, a meta-argument
      that passes it as a closure, a DCG nonterminal -- and never where the same atom is data (library(error) has a
      helper text/1 and the type name text in has_type(text, X)).  Which occurrences are references is read by SWI's
      own reader, util_gen_prolog_prelude_libs_refs.pl, from the subterm positions of each clause under the library's
      operators and meta-predicate declarations; it requires the vendored file to be byte-identical to swipl's own copy.
      A reference written in operator form REFUSES rc=2 (a renamed operator would not parse), and --show lists every
      helper name left standing as data, for review.  The '$' prefix is what the injector already keys on: a '$' name
      is pulled only through the closure of what the program calls.
  (2) DIRECTIVES.  The module system's own directives (module, use_module, autoload, multifile, public, det,
      set_prolog_flag ...) are dropped, each counted on stdout; conditional compilation (if/elif/else/endif) is
      kept for SCRIP's reader.  :- use_foreign_library(foreign(F)) is dropped: SCRIP loads no foreign library, and the predicates F
      defines are answered by the base prelude, measured against swipl (library(http/json)'s json_skip_ws/3, json_write_string/2 and
      json_write_indent/3).  :- expects_dialect(swi) is dropped: SCRIP reads every vendored library as SWI.
      :- meta_predicate S is kept as :- '$meta_spec'((S)) (ARCH-PROLOG-DATABASE.md 4c): the
      lowerer writes each spec into the predicate record's column, which predicate_property reads at run time, and the
      name keeps it out of the module qualification masks, which read only the program's own :- meta_predicate; the
      library's export specs are also emitted as its METAS table, from which the injector declares the specs of the names
      a program references when that library is not appended (maplist's from apply when the base prelude answers maplist).
      ANY OTHER DIRECTIVE REFUSES rc=2 by name: a directive that changes what a library means
      (dynamic, initialization, a term-expansion trigger) is decided when a library brings one, never dropped silently.
      A library(settings) declaration, :- setting(M:Name, Type, Default, Comment), is dropped (the cto's ruling 4,
      ARCH-PROLOG-DATABASE.md sec 4): the base prelude answers setting/2 for exactly the settings a vendored library
      reads, with swipl 9.0.4's measured defaults (library(listing)'s five), so a setting no base rule answers raises
      existence_error at its first read, never a silent default.  :- thread_local is kept: SCRIP's reader takes it as
      :- dynamic, its meaning in a single-threaded runtime.
  (3) HOOK CLAUSES.  A module-qualified head (sandbox:safe_primitive(...), prolog:message(...)) and a term_expansion or
      goal_expansion clause are dropped and named: they extend another module or the loader, and the expansion clause
      would turn on the program's own expansion machinery.
  (4) COMMENTS AND BLANK LINES ARE STRIPPED from the embedded text (the vendored file keeps them); the text is otherwise
      the library's own, token for token.  Its "..." literals are strings, as SWI reads them: the injector marks every
      library clause dq_forced, so prolog_lower.c lowers it in double_quotes=string whatever the program's flag.
  (6) A DICT-METHOD clause (Dict.method(...) := Value :- Body, read as :=/2) is dropped and named: SCRIP has no dicts.
  (5) OMIT: an export SCRIP already answers natively (a lowering the library's clauses would override, because a file
      definition takes precedence over a special-cased builtin) is listed in OMIT below with its reason and its clauses
      are dropped.  An export the base prelude defines needs no entry: the injector drops it (the base prelude wins).

A library in QUIET_BARE is never selected by a BARE atom of an export's name (the any-arity match a closure such as
maplist(foo, L) needs): dcg/basics exports integer//1, atom//1, number//1, string//1 and kin, and library(error)'s type names
are those atoms, so every program reaching error would select dcg_basics.  Its exports are quiet at arity 0 (the injector's
bare-match test reads that entry); a DCG body or phrase/2,3 names a nonterminal at its full arity, which still selects it.
clpfd is quiet the same way (cfo 2026-10-11, row ...-logtalk-reads-100-percent-...-ceo-1689): its exports are named like common
data atoms -- in, ins, sum, chain, element, label, transpose -- so open(F, read, S, [alias(in)]) or a bare `sum` in a term
selected all of clpfd and cost ~9 s of compile (measured: f(in) 9.36 s, f(sum) 9.05 s, f(element) 8.03 s; three Logtalk
stream_property/2 cases timed out at 10 s on alias(in)).  swipl never autoloads clpfd, and every corpus program naming a clpfd
export as a bare closure (maplist(all_distinct, Rows), maplist(indomain, Vs)) also calls one at its full arity, which selects it.
gnu_builtins (SCRIP's own GNU text) is quiet the same way (cfo 2026-10-14): library(error)'s type atom list_or_partial_list and the atoms
system and shell, data in error, dicts and quintus, named its exports list_or_partial_list/1, system/1 and shell/1,2, so every program
reaching library(error) parsed gnu_builtins and the lists and pairs it reaches (test_gate_pl_prelude_libs_cost.sh ARM 2 read 5 libraries
for rbtrees where it wants 2, red since 43a241a77 added list_or_partial_list/1); no corpus program passes a gnu_builtins export as a
bare closure.

A library whose SWI path is not its file stem is named in LIB_PATH (dcg_basics.pl is SWI's library/dcg/basics.pl, module
dcg_basics): the reader resolves and identity-checks it there.  A library SWI builds from several module files is vendored
ONE FILE PER LIBRARY, each under its module's name (library(clpq): clpq.pl, its sub-files bb_q.pl ... store_q.pl from
clp/clpq/ and clpqr_class.pl ... clpqr_redund.pl from clp/clpqr/), so a sub-file's helpers are renamed <module>:<name> and
a module-qualified call from one sub-file into another (bv_q:pivot(...) in clpqr_project) names exactly that private copy.
A library in IMPORT_ONLY_FRONTS and every library it loads through a RELATIVE use_module (its own sub-files, followed
transitively) is IMPORT-ONLY: the injector selects it by name only when the program imports it or an imported library
loads it, the LOADS list emitted beside its exports (swipl autoloads none of clpq: its exports are also clpr's, and its
sub-files are in no autoload index).  Without it a data term selected a sub-file -- rbtrees' DCG body {L == ''} is the
functor {}/1 that nf_q exports, and naming rbtrees parsed 14 libraries.  A library loaded as library(X) (lists, ugraphs)
keeps the ordinary selection by name.

THE EXPORT INDEX (cqo 2026-10-30, CEO-2056): PL_PRELUDE_LIB_EXPORT_INDEX holds every export of every library once per library as
(name, byte length, arity, library index), sorted by the name's bytes, so the injector's selection binary-searches the program's
references in it (pl_libs_named) instead of walking every library's export table against them -- the walk grew with every library
vendored, ARM 2 of test_gate_pl_prelude_libs_cost.sh paying ~1.4M instructions for 78 libraries of which it parses two.

A library in LOCAL is SCRIP's OWN text (gnu_fd.pl, AGPL): no SWI reader, no identity check, no renames (its helpers are
'$'-named by hand); its exports and operators come from its module directive and its clause heads are keyed by this
tokenizer, so they are written in canonical form.  A library in SHADOWS names the export keys of OTHER libraries that its
own clauses replace when it is selected (gnu_fd's fd_dom/2 over clpfd's); a key in QUIET never selects the library by
itself (fd_dom/2 is also SWI's).  Both tables are emitted beside the exports and the injector reads them.

A helper CALLED BY ITS NAME AS DATA -- clpfd's override(selection, ...) reaches selection/1 through call(What, Value), so the
rename of the predicate alone leaves call/2 asking for a selection/1 that no longer exists -- is listed in RENAME_AS_DATA and
every bare occurrence of that atom (one not followed by an open parenthesis) is renamed with it; a helper whose COMPOUND data
term is later called -- clpfd's distinct_goals builds [neq_num(V, N)|Gs] and runs maplist(call, Gs) -- is listed in
RENAME_TERMS_AS_DATA and its compound occurrences are renamed too; --show's "left as data" line is
the review surface for the rest, each of which is a term never called.

A library in WRAPS stands in front of another library's exports: for each wrapped key the generator APPENDS to the wrapped
library's text a copy of that key's clauses under the head '$<lib>_wrapped_<name>', and adds the key to the wrapper's SHADOWS
and QUIET, so when both are selected the wrapper's own clauses for the key replace the public ones and call the copy, and the
key alone never selects the wrapper.  gnu_fd wraps clpfd's six comparisons and four shared boolean connectives so a GNU
program's ** dist / quot_rem and #<=> ## inside them are translated before clpfd's parser sees them; SWI programs never select
gnu_fd and keep clpfd's public clauses.  A wrapped key with no clause in the wrapped library REFUSES rc=2.

A head this script cannot key (an operator-form head, a variable head) REFUSES rc=2 by name.  An export with no clause in
the library is SWI's C (term_hash/2 in library(terms)): it leaves the export table and --show names it as C-side, so a
program calling it reaches SCRIP's builtin or an existence error, never a stub.

USAGE: util_gen_prolog_prelude_libs.py [--dir DIR] [--out PATH] [--check | --show LIB]
  --dir     the vendored directory (default src/parsers/prolog/prelude; the sync gate's self-test points it at a plant)
  --check   regenerate in memory and compare with the committed table; rc 1 if it differs (the sync gate's arm)
  --show    print LIB's embedded source as SCRIP will parse it, its exports, renames and drops
rc 0 written / in sync; 1 stale (--check); 2 refused (a construct named above, or a missing prelude directory).
"""
import argparse, os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
PRELUDE_DIR = os.path.join(ROOT, "src", "parsers", "prolog", "prelude")
DEFAULT_OUT = os.path.join(ROOT, "src", "parsers", "prolog", "prolog_prelude_libs.inc")
REFS_PL = os.path.join(HERE, "util_gen_prolog_prelude_libs_refs.pl")

HOOK_DYN = ("directive multifile of a hook the library calls and defines no clause for, kept as :- dynamic: swipl fails such a call quietly, and an "
            "undeclared predicate would raise existence_error (library(http/json)'s json_write_hook/4)")
META_KEPT = ("directive meta_predicate kept as :- '$meta_spec'(Specs) -- the spec column of each predicate's record (ARCH-PROLOG-DATABASE.md 4c); "
             "the name keeps it out of the module qualification masks, which read the program's own :- meta_predicate")
DROP_DIRECTIVES = {"module", "use_module", "autoload", "multifile", "public", "det", "set_prolog_flag",
                   "$clausable", "noprofile", "license", "discontiguous", "module_transparent", "predicate_options",
                   "reexport", "type", "pred", "quasi_quotation_syntax", "volatile", "encoding", "$hide", "setting", "use_foreign_library",
                   "expects_dialect"}
KEEP_DIRECTIVES = {"if", "elif", "else", "endif", "op", "create_prolog_flag", "dynamic", "thread_local"}
EXPANDED = {"clpfd", "csv", "lazy_lists", "json"}
INCLUDES = {"chr_runtime": {"chr_op": "chr/chr_op"}}
GOAL_DROPS = {"hprolog": {"push_hprolog_library": "it only adds swipl's dialect/hprolog directory to the library search path while the hprolog dialect loads"}}
IMPORT_ONLY_FRONTS = {"clpb": "swipl autoloads no clpb export (sat/1, taut/2, labeling/1, sat_count/2 are named only by a program that imports library(clpb), measured on swipl 9.0.4)",
                      "clpq": "swipl autoloads no clpq export (every one is also clpr's, so the autoload index is ambiguous) and none of its sub-files",
                      "clpr": "the same as clpq: its exports are clpq's names, and a program names one of the two",
                      "chr": "SCRIP's own library(chr): its operators and, through chr_runtime, the CHR runtime a lowered CHR program calls",
                      "hprolog": "swipl's dialect/hprolog, loaded only by chr_runtime; its exports (take/3, drop/3, sublist/2 ...) are in no autoload index"}
LIB_PATH = {"clpb": "clp/clpb", "dcg_basics": "dcg/basics", "json": "http/json", "clpq": "clp/clpq", "chr_runtime": "chr/chr_runtime", "hprolog": "dialect/hprolog", "clpr": "clp/clpr", "bb_r": "clp/clpr/bb_r", "bv_r": "clp/clpr/bv_r", "fourmotz_r": "clp/clpr/fourmotz_r", "ineq_r": "clp/clpr/ineq_r", "itf_r": "clp/clpr/itf_r", "nf_r": "clp/clpr/nf_r", "store_r": "clp/clpr/store_r", "bb_q": "clp/clpq/bb_q", "bv_q": "clp/clpq/bv_q", "fourmotz_q": "clp/clpq/fourmotz_q", "ineq_q": "clp/clpq/ineq_q", "itf_q": "clp/clpq/itf_q", "nf_q": "clp/clpq/nf_q", "store_q": "clp/clpq/store_q", "clpqr_class": "clp/clpqr/class", "clpqr_dump": "clp/clpqr/dump", "clpqr_geler": "clp/clpqr/geler", "clpqr_itf": "clp/clpqr/itf", "clpqr_ordering": "clp/clpqr/ordering", "clpqr_project": "clp/clpqr/project", "clpqr_redund": "clp/clpqr/redund"}
RENAME_TERMS_AS_DATA = {"clpfd": {"neq_num"}, "pure_input": {"attr_unify_hook_ndebug"}}
RENAME_AS_DATA = {"clpfd": {"selection", "order", "choice", "bare_integer", "circuit_successors", "g0_successors", "gcc_successors", "clear_parent", "fd_variable",
                            "conjunction", "disjunction", "sink", "source", "clpfd_equal_", "clpfd_geq_", "clpfd_neq"},
                  "clpb": {"ignore_node", "nodevar_put_empty_hash", "var_unbound", "is_visited", "put_visited", "unvisit", "eq_1", "monotonic_variable", "further_branching",
                           "negative_decisive"},
                  "listing": {"portray_blob"}, "simplex": {"clear_parent"}}
LOCAL = {"gnu_fd", "gnu_builtins", "dicts", "uri", "pcre", "mctx", "swi_builtins", "xsb_ordsets", "xsb_tables", "tabling", "xsb_builtins", "xsb_dialect", "prolog_source", "engines", "plunit", "chr"}
WHY_LISTING_PC = "swipl's library(listing) prints a clause in swipl's layout; the prelude selects listing only in the SWI dialect, so gnu_builtins keeps gprolog's for the GNU dialect (the cto's ruling 4b, ARCH-PROLOG-DATABASE.md sec 4b)"
SHADOWS = {"gnu_fd": {("fd_dom", 2): "GNU's fd_dom/2 answers the list of the domain's values where SWI's answers the domain term (measured on gprolog 1.6.0 and swipl 9.0.4, 2026-10-10)"},
           "xsb_dialect": {("term_size", 2): "XSB's term_size/2 counts functors and leaves (emu/std_pred_xsb_i.h term_sizew: a float 4, anything else without arguments 1) where library(terms) counts SWI's cells; the library is selected only in the XSB dialect (measured on XSB 5.0.0, 2026-10-28)", ("concat_atom", 2): "XSB's concat_atom/2 (syslib/string.P) joins ATOMIC elements, numbers included (concat_atom([x,1],A) gives x1) and FAILS on a compound element; backcomp.pl's routes through atom_concat/3, which XSB, strict, refuses a number (type_error(atom,1)); selected only in the XSB dialect (measured on XSB 5.0.0, 2026-10-29)", ("concat_atom", 3): "XSB's concat_atom/3 joins atomic elements with the separator, as concat_atom/2; selected only in the XSB dialect (measured on XSB 5.0.0, 2026-10-29)", ("import", 1): "XSB's renaming import (:- import P from M as Q.) defines Q as a call of P; this library carries xsb_builtins' no-op import/1 as its last clause, so it replaces that one in the XSB dialect"},
           "listing": {("portray_clause", 1): WHY_LISTING_PC, ("portray_clause", 2): WHY_LISTING_PC, ("portray_clause", 3): WHY_LISTING_PC}}
QUIET = {"gnu_fd": {("fd_dom", 2)}, "tabling": {("undefined", 0)}, "varnumbers": {("numbervars", 1)}}
QUIET_BARE = {"dcg_basics", "clpfd", "gnu_builtins", "backcomp"}
WRAPS = {"gnu_fd": {"clpfd": {("#=", 2), ("#\\=", 2), ("#<", 2), ("#>", 2), ("#=<", 2), ("#>=", 2), ("#/\\", 2), ("#\\/", 2), ("#\\", 1), ("#==>", 2)}}}
EXPAND_PL = os.path.join(HERE, "util_gen_prolog_prelude_libs_expand.pl")
INIT_DROPS = {"clpb": {"warn_if_bounded_arithmetic": "only prints a warning when the integer flag bounded is true"},
              "clpfd": {"warn_if_bounded_arithmetic": "only prints a warning when the integer flag bounded is true"},
              "random": {"check_gmp": "only prints a warning when SWI is built without GMP; SCRIP's integers are unbounded"},
              "simplex": {"warn_if_bounded_arithmetic": "only prints a warning when the integer flag bounded is true"},
              "chr_runtime": {"chr_init": "it only sets chr_id, chr_global, chr_debug and chr_debug_history, which the library's own exception/3 hook sets at their first read",
                              "chr_debug_init": "it only sets chr_leash, which the library's own exception/3 hook sets at its first read"}}
# An initialization directive whose only effect, with no foreign library, is to ASSERT clauses: the directive's text is replaced by those
# clauses, verbatim from the library's own fallback branch, before the file is read and keyed, so they are keyed, renamed and exported
# like any other clause (cfo 2026-10-14, row prolog-swi-library-test-pio-...-ceo-1664): readutil's link_foreign/0 tries
# use_foreign_library(foreign(readutil)) and otherwise assertz's read_line_to_codes/2,3 and read_stream_to_codes/2,3 over the Prolog
# pl_read_* predicates; SCRIP has no foreign readutil, so those four clauses are what the library means here.
INIT_AS_CLAUSES = {"readutil": {"link_foreign": ("with no foreign readutil, link_foreign/0's second clause asserts these four clauses over the Prolog pl_read_* predicates", [
    "read_line_to_codes(Stream, Line) :- pl_read_line_to_codes(Stream, Line).",
    "read_line_to_codes(Stream, Line, Tail) :- pl_read_line_to_codes(Stream, Line, Tail).",
    "read_stream_to_codes(Stream, Content) :- pl_read_stream_to_codes(Stream, Content).",
    "read_stream_to_codes(Stream, Content, Tail) :- pl_read_stream_to_codes(Stream, Content, Tail)."])}}
# A literal EDIT of a library's source, applied before the file is read and keyed exactly as INIT_AS_CLAUSES is (the identity
# check stays on the vendored file); each old text must occur exactly once or the generator REFUSES rc=2 (cfo 2026-10-14, row
# prolog-swi-library-test-record-...-ceo-1664).  library(record) defines its accessors through system:term_expansion/2 on
# (:- record(R)), and SCRIP runs no term_expansion for a vendored library (rule (3) drops the hook), so the directive is CALLED;
# its second clause, which raises context_error(nodirective, ...) for a call SWI never makes, asserts the clauses
# compile_records/2 writes instead -- the clauses the expansion would have put in the file.  The (record):current_record/5 fact it
# writes is asserted without its qualifier: current_record/5 has no clause in the library, so it keeps its name, and that is the
# name the library's own calls read.  library(gensym) builds its symbol with atom_concat(Base, N, Atom), which SWI allows for a
# number N and SCRIP's ISO atom_concat/3 refuses outside the SWI dialect; the edit builds it with atomic_list_concat/2.
WHY_MAIN_META = ("SCRIP's module flattener qualifies a meta-argument (:) only inside a module or a plunit unit, and none in a file without either; from user the argument arrives bare, so a bare one is read as user:X, the term swipl passes from user")
SOURCE_EDITS = {"record": [("the directive :- record(R) asserts the clauses system:term_expansion/2 would have compiled", """record(Record) :-
    throw(error(context_error(nodirective, record(Record)), _)).""", """record(Record) :-
    compile_records(Record, [_|Clauses]),
    forall(member(Clause, Clauses), record_assert(Clause)).
record_assert((record):current_record(Name, M, Def, X, IsX)) :-
    !,
    assertz(current_record(Name, M, Def, X, IsX)).
record_assert(Clause) :-
    assertz(Clause).""")],
    "main": [("SCRIP has no library(thread_util) or library(guitracer) source and loads no library at run time, so exists_source/1 fails for both and "
              "--gspy=PI takes the clause's own third branch, spy(PI)", """debug_option(gspy(Atom)) :-
    atom_pi(Atom, PI),
    (   exists_source(library(thread_util))
    ->  use_module(library(threadutil), [tspy/1]),
	Goal = tspy(PI)
    ;   exists_source(library(guitracer))
    ->  use_module(library(gui_tracer), [gspy/1]),
	Goal = gspy(PI)
    ;   Goal = spy(PI)
    ),
    call(Goal).""", """debug_option(gspy(Atom)) :-
    atom_pi(Atom, PI),
    spy(PI)."""),
             ("%s (argv_options/3)" % WHY_MAIN_META, """argv_options(M:Argv, Positional, Options) :-
    in(M:opt_type(_,_,_)),""", """argv_options(Argv, Positional, Options) :-
    Argv \\= _:_,
    !,
    argv_options(user:Argv, Positional, Options).
argv_options(M:Argv, Positional, Options) :-
    in(M:opt_type(_,_,_)),"""),
             ("%s (argv_options/4)" % WHY_MAIN_META, """argv_options(Argv, Positional, Options, POptions) :-
    option(on_error(halt(Code)), POptions),""", """argv_options(Argv, Positional, Options, POptions) :-
    Argv \\= _:_,
    !,
    argv_options(user:Argv, Positional, Options, POptions).
argv_options(Argv, Positional, Options, POptions) :-
    option(on_error(halt(Code)), POptions),"""),
             ("%s (argv_usage/1)" % WHY_MAIN_META, """argv_usage(M:Level) :-""", """argv_usage(Level) :-
    Level \\= _:_,
    !,
    argv_usage(user:Level).
argv_usage(M:Level) :-"""),
             ("SCRIP has no xpce: the flag xpce_version is never defined, so cli_enable_development_system/0 never takes the branch that loads "
              "library(pce_dispatch) at run time", """    (   current_prolog_flag(xpce_version, _)
    ->  use_module(library(pce_dispatch)),
	memberchk(Goal, [pce_dispatch([])]),
	call(Goal)
    ;   true
    ),
""", "")],
    "listing": [("%s (portray_clause/3)" % WHY_MAIN_META, """portray_clause(Stream, Term, M:Options) :-""", """portray_clause(Stream, Term, Options) :-
    Options \\= _:_,
    !,
    portray_clause(Stream, Term, user:Options).
portray_clause(Stream, Term, M:Options) :-""")],
    "gensym": [("atom_concat/3 is ISO outside the SWI dialect (a number argument is a type_error), so the library's own symbol is built by atomic_list_concat/2, which takes "
                "the number in every dialect", """    New is Old+1,
    atom_concat(Base, New, Atom).""", """    New is Old+1,
    atomic_list_concat([Base, New], Atom).""")],
    "nb_set": [("the :- if condition catch((A = f(A), variant_hash(A,_)), _, fail) reads false, as swipl 9.0.4 reads it (variant_hash/2 raises type_error(acyclic_term) "
                "on a cyclic term, measured 2026-10-22); SCRIP's reader has no read-time catch/3, so the verbatim condition warned on stderr in every program reaching "
                "nb_set (distinct/1,2, order_by/2) and read false anyway", """:- if(catch((A = f(A), variant_hash(A,_)), _, fail)).""", """:- if(fail).""")]}
# A module-qualified head extending ANOTHER vendored library's local predicate (rule (3) drops every other one): the qualifier
# and name are replaced by that library's renamed local, so the clause joins the other library's predicate when both are
# selected (cfo 2026-10-14): library(record)'s error:has_type(record(M:Name), X) is what makes must_be(record(...), V) check a
# record-typed field, and library(error)'s has_type/2 is '$error_has_type'/2 in the embedded text.
CROSS_HOOKS = {"record": {("error", "has_type"): "$error_has_type"}}
ATTR_HOOKS = {("attr_unify_hook", 2), ("attribute_goals", 3)}
LIB_FLAGS = {"clpfd": [("clpfd_propagation", "default", "read by the propagation loop and never created by 9.0.4's library: swipl fails on an absent flag where "
                                                           "SCRIP's ISO current_prolog_flag/2 raises domain_error, so the flag is declared at its documented default")]}
HOOK_HEADS = {("term_expansion", 2), ("goal_expansion", 2), ("term_expansion", 4), ("goal_expansion", 4)}
OMIT = {"aggregate": {("foreach", 2): "SWI's foreach/2 resets its template between solutions with '$unbind_template'/1, SWI C; the base prelude "
                                      "hand-types it as SWI 6 did, copying the goal per solution with its other variables kept shared"},
        "quintus": {("current_stream", 3): "SCRIP lowers current_stream/3 natively (lower_prolog.c, the GNU and ISO stream table); the library's clause, a "
                                           "file definition, would override that lowering in every program naming it"},
        "strings": {("string", 4): "quasi-quotation support ({|string(X)||...|}); SCRIP's reader has no quasi-quotations, and the bare name string "
                                    "would select the library in every program that tests string/1"}}
DICT_METHOD_HEADS = {(":=", 2)}

SYMCH = set("#$&*+-./:<=>?@^~\\")
ALNUM = re.compile(r"[A-Za-z0-9_]")


class Refuse(Exception):
    pass


def tokenize(src, path):
    toks = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c.isspace():
            j = i
            while j < n and src[j].isspace():
                j += 1
            toks.append(("ws", src[i:j])); i = j; continue
        if c == "%":
            j = src.find("\n", i)
            j = n if j < 0 else j
            toks.append(("comment", src[i:j])); i = j; continue
        if c == "/" and src.startswith("/*", i):
            j = src.find("*/", i + 2)
            if j < 0:
                raise Refuse("%s: an unclosed /* comment" % path)
            toks.append(("comment", src[i:j + 2])); i = j + 2; continue
        if c.isdigit():
            j = i
            if src.startswith("0'", i):
                j = i + 2
                if j < n and src[j] == "\\":
                    j += 2
                    if src[j - 1] in "xX0123456789":
                        while j < n and src[j] != "\\":
                            j += 1
                        j += 1
                elif src.startswith("''", j):
                    j += 2
                else:
                    j += 1
                toks.append(("num", src[i:j])); i = j; continue
            if re.match(r"0[xob]", src[i:i + 2]):
                j = i + 2
                while j < n and (src[j].isalnum() or src[j] == "_"):
                    j += 1
                toks.append(("num", src[i:j])); i = j; continue
            m = re.compile(r"\d[\d_]*(\.\d+)?([eE][+-]?\d+)?(Inf|NaN)?").match(src, i)
            toks.append(("num", m.group(0))); i = m.end(); continue
        if c.isalpha() or c == "_":
            j = i
            while j < n and ALNUM.match(src[j]):
                j += 1
            toks.append(("var" if (c.isupper() or c == "_") else "atom", src[i:j])); i = j; continue
        if c in "'\"`":
            j = i + 1
            while True:
                if j >= n:
                    raise Refuse("%s: an unclosed %s literal" % (path, c))
                if src[j] == "\\":
                    j += 2; continue
                if src[j] == c:
                    if j + 1 < n and src[j + 1] == c:
                        j += 2; continue
                    break
                j += 1
            kind = {"'": "qatom", '"': "str", "`": "bq"}[c]
            toks.append((kind, src[i:j + 1])); i = j + 1; continue
        if c in "()[]{},|":
            toks.append(("punct", c)); i += 1; continue
        if c in "!;":
            toks.append(("atom", c)); i += 1; continue
        if c in SYMCH:
            j = i
            while j < n and src[j] in SYMCH:
                j += 1
            if src[i:j] == "." and (j >= n or src[j].isspace() or src[j] == "%"):
                toks.append(("end", ".")); i = j; continue
            toks.append(("atom", src[i:j])); i = j; continue
        raise Refuse("%s: an unexpected character %r at offset %d" % (path, c, i))
    return toks


def atom_value(tok):
    kind, text = tok
    if kind == "atom":
        return text
    if kind == "qatom":
        return text[1:-1].replace("''", "'").replace("\\\\", "\\")
    return None


def split_clauses(toks):
    clauses, cur = [], []
    for t in toks:
        cur.append(t)
        if t[0] == "end":
            clauses.append(cur); cur = []
    if any(t[0] not in ("ws", "comment") for t in cur):
        raise Refuse("text after the last clause's end token")
    return clauses


def sig(clause):
    return [t for t in clause if t[0] not in ("ws", "comment")]


def top_level_args(s, k):
    """s[k] is '(' or '[': the token lists of its top-level comma-separated elements and the index after the close."""
    depth, args, cur = 0, [], []
    j = k
    while j < len(s):
        t = s[j]
        if t[0] == "punct" and t[1] in "([{":
            depth += 1
            if depth == 1:
                j += 1; continue
        elif t[0] == "punct" and t[1] in ")]}":
            depth -= 1
            if depth == 0:
                if cur:
                    args.append(cur)
                return args, j + 1
        elif t[0] == "punct" and t[1] in ",|" and depth == 1:
            args.append(cur); cur = []; j += 1; continue
        cur.append(t)
        j += 1
    raise Refuse("an unbalanced bracket")


def parse_exports(s, path):
    """s are the significant tokens of ':- module(Name, [Exports])'.  Returns (module name, [(name, arity)])."""
    args, _ = top_level_args(s, 1)
    if len(args) < 2:
        raise Refuse("%s: a module directive without an export list" % path)
    mod = atom_value(next((t for t in args[0] if t not in (("punct", "("), ("punct", ")"))), args[0][0]))
    lst = args[1]
    if not lst or lst[0] != ("punct", "["):
        raise Refuse("%s: the export list is not a list" % path)
    elems, _ = top_level_args(lst, 0)
    exports, ops = [], []
    for e in elems:
        e = [t for t in e if t != ("punct", "(") and t != ("punct", ")")]
        if e and atom_value(e[0]) == "op":
            e = [t for t in e if t != ("punct", ",")]
            if len(e) == 4 and e[1][0] == "num" and atom_value(e[2]) in ("xfx", "xfy", "yfx", "fy", "fx", "xf", "yf") and atom_value(e[3]) is not None:
                ops.append((int(e[1][1]), atom_value(e[2]), atom_value(e[3])))
                continue
            raise Refuse("%s: exports an operator this generator cannot read (%s)" % (path, " ".join(t[1] for t in e)))
        if len(e) == 3 and atom_value(e[0]) is not None and atom_value(e[1]) in ("/", "//") and e[2][0] == "num":
            exports.append((atom_value(e[0]), int(e[2][1]) + (2 if atom_value(e[1]) == "//" else 0)))
            continue
        if len(e) == 4 and e[0] == ("punct", "{") and e[1] == ("punct", "}") and atom_value(e[2]) in ("/", "//") and e[3][0] == "num":
            exports.append(("{}", int(e[3][1]) + (2 if atom_value(e[2]) == "//" else 0)))
            continue
        raise Refuse("%s: an export this generator cannot read (%s)" % (path, " ".join(t[1] for t in e)))
    return mod, exports, ops


def system_fallbacks(toks):
    """The (name, arity) keys a library defines only inside an :- if(\\+current_predicate(Name/Arity)) branch."""
    out, stack = set(), []
    for cl in split_clauses(toks):
        s = sig(cl)
        if not s:
            continue
        if atom_value(s[0]) == ":-" and len(s) > 1:
            d = directive_name(s)
            if d == "if":
                v = [t[1] if t[0] != "qatom" else atom_value(t) for t in s]
                m = re.fullmatch(r":-if\(\\\+current_predicate\(([a-z][A-Za-z0-9_]*)/(\d+)\)\)\.", "".join(v))
                stack.append((m.group(1), int(m.group(2))) if m else None)
            elif d in ("elif", "else") and stack:
                stack[-1] = None
            elif d == "endif" and stack:
                stack.pop()
            continue
        if stack and stack[-1] is not None:
            out.add(stack[-1])
    return out


def swipl_library_file(lpath):
    """The file swipl resolves library(lpath) to."""
    r = subprocess.run(["swipl", "-q", "-g", "absolute_file_name(library('%s'), F, [file_type(prolog), access(read)]), write(F)" % lpath, "-t", "halt"],
                       capture_output=True, text=True, timeout=60)
    if r.returncode != 0 or not r.stdout:
        raise Refuse("swipl resolves no library(%s)" % lpath)
    return r.stdout.strip()


def use_module_specs(s):
    """s are the significant tokens of ':- use_module(Spec[, Imports])'.  Returns its specs as ("library", Path) or ("relative", Path)."""
    if len(s) < 3 or s[2] != ("punct", "("):
        return []
    args, _ = top_level_args(s, 2)
    if not args:
        return []
    elems = top_level_args(args[0], 0)[0] if args[0][0] == ("punct", "[") else [args[0]]
    out = []
    for e in elems:
        kind = "relative"
        if len(e) > 2 and atom_value(e[0]) == "library" and e[1] == ("punct", "("):
            kind, e = "library", e[2:-1]
        out.append((kind, "".join(atom_value(t) if t[0] in ("atom", "qatom") else t[1] for t in e)))
    return out


def expanded_text(path, lib):
    """The library as SWI compiles it (util_gen_prolog_prelude_libs_expand.pl): term- and goal-expanded, its operators
    restored after the last clause."""
    if not shutil.which("swipl"):
        raise Refuse("swipl is not on PATH -- %s is embedded as SWI expands it" % path)
    r = subprocess.run(["swipl", EXPAND_PL, "--", path, LIB_PATH.get(lib, lib)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if r.returncode != 0 or not r.stdout:
        raise Refuse("SWI's expander refused %s (rc=%d): %s" % (path, r.returncode, r.stderr.strip()[:300]))
    return r.stdout


def quote(name):
    return "'" + name.replace("\\", "\\\\").replace("'", "\\'") + "'"


def strip_comments(text, path):
    out = []
    for t in tokenize(text, path):
        out.append(("\n" if ("\n" in t[1] or t[1].startswith("%")) else " ") if t[0] == "comment" else t[1])
    return "".join(out)


def directive_name(s):
    """s are the significant tokens of a directive: its name, read through the parenthesis portray_clause puts around a
    prefix-operator directive (:- (public a/1, b/2))."""
    if len(s) < 2:
        return None
    return atom_value(s[2]) if s[1] == ("punct", "(") and len(s) > 2 else atom_value(s[1])


def local_heads(toks, path):
    """A LOCAL library's clause classification by this tokenizer alone: offset -> (kind, arity, name)."""
    heads, off = {}, 0
    for cl in split_clauses(toks):
        start = off
        off += sum(len(t[1]) for t in cl)
        first = start
        for t in cl:
            if t[0] not in ("ws", "comment"):
                break
            first += len(t[1])
        s = sig(cl)
        if not s:
            continue
        if atom_value(s[0]) == ":-":
            heads[first] = ("directive", 0, "-"); continue
        if len(s) > 2 and s[1][1] == ":" and atom_value(s[0]) is not None:
            heads[first] = ("qualified", 0, "-"); continue
        nm = atom_value(s[0])
        if nm is None:
            raise Refuse("%s: a LOCAL library head this tokenizer cannot key (%s)" % (path, " ".join(t[1] for t in s[:6])))
        ar = 0
        if len(s) > 1 and s[1] == ("punct", "("):
            args, _ = top_level_args(s, 1)
            ar = len(args)
        heads[first] = ("head", ar, nm)
    return heads


def rename_bare_atom(raw, nm, new, path, with_args=False):
    """Every bare occurrence of the atom nm in raw -- an atom token not followed by '(' -- becomes the quoted atom new; with
    with_args, an occurrence written as a compound's functor (nm immediately followed by '(') is renamed too."""
    toks = tokenize(raw, path)
    out = []
    for i, t in enumerate(toks):
        if t[0] == "atom" and t[1] == nm:
            if with_args and i + 1 < len(toks) and toks[i + 1] == ("punct", "("):
                out.append(quote(new))
                continue
            j = i + 1
            while j < len(toks) and toks[j][0] in ("ws", "comment"):
                j += 1
            if not (j < len(toks) and toks[j] == ("punct", "(")):
                out.append(quote(new))
                continue
        out.append(t[1])
    return "".join(out)


def wrapped_copies(text, lib, keys, path):
    """The clauses of text whose head is one of keys, in operator form (A op B or op A), each copied under the head
    '$<lib>_wrapped_<op>'(A, B) with its body verbatim.  Returns (copies text, {key: count})."""
    out, counts = [], {}
    for cl in split_clauses(tokenize(text, path)):
        s = sig(cl)
        if len(s) >= 4 and s[0][0] == "var" and s[1][0] == "atom" and (s[1][1], 2) in keys and s[2][0] == "var" and (s[3] == ("atom", ":-") or s[3][0] == "end"):
            key, nhead, args = (s[1][1], 2), 3, s[0][1] + ", " + s[2][1]
        elif len(s) >= 3 and s[0][0] == "atom" and (s[0][1], 1) in keys and s[1][0] == "var" and (s[2] == ("atom", ":-") or s[2][0] == "end"):
            key, nhead, args = (s[0][1], 1), 2, s[1][1]
        else:
            continue
        seen, rest = 0, []
        for t in cl:
            if seen < nhead:
                if t[0] not in ("ws", "comment"):
                    seen += 1
                continue
            rest.append(t[1])
        out.append(quote("$%s_wrapped_%s" % (lib, key[0])) + "(" + args + ")" + "".join(rest).rstrip() + "\n")
        counts[key] = counts.get(key, 0) + 1
    return "".join(out), counts


def reader_refs(path, lib, read_path=None):
    """SWI's own reader over the vendored file (util_gen_prolog_prelude_libs_refs.pl): every clause's start offset and
    head key, and every predicate reference's span -- head, body goal, meta-argument, DCG nonterminal -- never data."""
    if not shutil.which("swipl"):
        raise Refuse("swipl is not on PATH -- the predicate references of %s are read by SWI's own reader" % path)
    r = subprocess.run(["swipl", REFS_PL, "--", path, LIB_PATH.get(lib, lib)] + ([read_path] if read_path else []), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if r.returncode != 0:
        raise Refuse("SWI's reader refused %s (rc=%d): %s" % (path, r.returncode, r.stderr.strip()[:300]))
    heads, refs = {}, []
    for line in r.stdout.split("\n"):
        f = line.split(" ", 5) if line.startswith("R ") else line.split(" ", 4)
        if line.startswith("C "):
            heads[int(f[1])] = (f[2], int(f[3]), f[4])
        elif line.startswith("R "):
            refs.append((int(f[1]), int(f[2]), int(f[3]), f[4], f[5]))
    return heads, refs


def process(path):
    lib = os.path.splitext(os.path.basename(path))[0]
    src = open(path, encoding="utf-8").read()
    read_path = None
    if lib in EXPANDED:
        src = expanded_text(path, lib)
        read_path = os.path.join(os.environ.get("TMPDIR", "/tmp"), "pl_prelude_expanded_%s_%d.pl" % (lib, os.getpid()))
        open(read_path, "w", encoding="utf-8").write(src)
    init_drops = {}
    for g, (why, clauses) in INIT_AS_CLAUSES.get(lib, {}).items():
        m = re.search(r":-\s*initialization\(\s*%s\s*(?:,\s*[a-z_]+\s*)?\)\s*\." % re.escape(g), src)
        if not m:
            raise Refuse("%s: INIT_AS_CLAUSES names initialization(%s), which the library does not carry" % (path, g))
        src = src[:m.start()] + "\n".join(clauses) + src[m.end():]
        init_drops["directive initialization(%s) replaced by the %d clauses it asserts: %s" % (g, len(clauses), why)] = 1
        read_path = os.path.join(os.environ.get("TMPDIR", "/tmp"), "pl_prelude_initclauses_%s_%d.pl" % (lib, os.getpid()))
        open(read_path, "w", encoding="utf-8").write(src)
    for inc, ipath in INCLUDES.get(lib, {}).items():
        m = re.search(r":-\s*include\(\s*%s\s*\)\s*\." % re.escape(inc), src)
        if not m:
            raise Refuse("%s: INCLUDES names include(%s), which the library does not carry" % (path, inc))
        ifile = swipl_library_file(ipath)
        itext = open(ifile, encoding="utf-8").read()
        idirs = []
        for cl in split_clauses(tokenize(itext, ifile)):
            si = sig(cl)
            if not si:
                continue
            if atom_value(si[0]) != ":-" or directive_name(si) != "op":
                raise Refuse("%s: the included %s carries a clause that is not :- op(...) -- decide what it means for SCRIP first" % (path, ifile))
            idirs.append("".join(t[1] for t in cl if t[0] != "comment").strip())
        src = src[:m.start()] + "\n".join(idirs) + src[m.end():]
        init_drops["directive include(%s) replaced by its %d op directives (%s)" % (inc, len(idirs), ipath)] = 1
        read_path = os.path.join(os.environ.get("TMPDIR", "/tmp"), "pl_prelude_included_%s_%d.pl" % (lib, os.getpid()))
        open(read_path, "w", encoding="utf-8").write(src)
    for why, old, new in SOURCE_EDITS.get(lib, []):
        if src.count(old) != 1:
            raise Refuse("%s: SOURCE_EDITS text for '%s' occurs %d times, not once" % (path, why, src.count(old)))
        src = src.replace(old, new)
        init_drops["edited: %s" % why] = 1
        read_path = os.path.join(os.environ.get("TMPDIR", "/tmp"), "pl_prelude_edited_%s_%d.pl" % (lib, os.getpid()))
        open(read_path, "w", encoding="utf-8").write(src)
    toks = tokenize(src, path)
    for no, cl in enumerate(split_clauses(toks), 1):
        s = sig(cl)
        if s and atom_value(s[0]) == ":-" and len(s) > 1:
            d = directive_name(s)
            if d not in KEEP_DIRECTIVES and d not in DROP_DIRECTIVES and d not in ("module", "initialization", "meta_predicate") and not (d == "record" and lib in EXPANDED) and d not in GOAL_DROPS.get(lib, {}):
                raise Refuse("%s clause %d: the directive :- %s is neither dropped nor kept by this generator -- decide what it means for SCRIP first" % (path, no, d))
    if lib in LOCAL:
        heads, refs = local_heads(toks, path), []
    else:
        heads, refs = reader_refs(path, lib, read_path)
    if read_path:
        os.unlink(read_path)
    mod, exports, ops, kept, drops, keyed, hooks, libops = None, [], [], [], dict(init_drops), [], [], set()
    cross, dynrep, uses, metaspec, metas = {}, {}, [], {}, []
    defined = {(n, a) for k, a, n in heads.values() if k not in ("directive", "unkeyable", "qualified") and n}
    off = 0
    for no, cl in enumerate(split_clauses(toks), 1):
        start = off
        off += sum(len(t[1]) for t in cl)
        first = start
        for t in cl:
            if t[0] not in ("ws", "comment"):
                break
            first += len(t[1])
        s = sig(cl)
        kind, arity, name = heads.get(first, (None, 0, None))
        if kind is None:
            raise Refuse("%s clause %d: SWI's reader reports no clause at offset %d where this tokenizer starts one" % (path, no, first))
        if kind == "directive":
            d = directive_name(s)
            if d == "module" and mod is None:
                mod, exports, ops = parse_exports(s[1:], path)
                drops["directive module"] = drops.get("directive module", 0) + 1
                continue
            if d == "dynamic" and any(t[1] == ":" for t in s):
                drops["directive dynamic (module-qualified)"] = drops.get("directive dynamic (module-qualified)", 0) + 1
                continue
            if d in GOAL_DROPS.get(lib, {}):
                drops["directive %s: %s" % (d, GOAL_DROPS[lib][d])] = 1
                continue
            if d == "initialization":
                k = 3 if s[1] == ("punct", "(") else 2
                g = next((atom_value(t) for t in s[k:] if t[0] in ("atom", "qatom")), None)
                if g in INIT_DROPS.get(lib, {}):
                    drops["directive initialization(%s): %s" % (g, INIT_DROPS[lib][g])] = drops.get("directive initialization(%s): %s" % (g, INIT_DROPS[lib][g]), 0) + 1
                    continue
            if d == "op":
                k = s.index(("punct", "(")) if ("punct", "(") in s else -1
                if k >= 0:
                    args, _ = top_level_args(s, k)
                    if len(args) == 3:
                        for t in args[2]:
                            if atom_value(t) is not None:
                                libops.add(atom_value(t))
            if d == "meta_predicate":
                pos, name_at, last_at = start, None, None
                for t in cl:
                    if name_at is None and t[0] in ("atom", "qatom") and atom_value(t) == "meta_predicate":
                        name_at = pos
                    if t[0] not in ("ws", "comment"):
                        last_at = pos
                    pos += len(t[1])
                if name_at is None or last_at is None or src[last_at:last_at + 1] != ".":
                    raise Refuse("%s clause %d: a :- meta_predicate directive this generator cannot rewrite in place" % (path, no))
                metaspec[start] = (name_at, last_at)
                j = next(k for k, t in enumerate(s) if t[0] in ("atom", "qatom") and atom_value(t) == "meta_predicate")
                body = [t for t in s[j + 1:] if t[0] != "end"]
                if body and body[0] == ("punct", "(") and top_level_args(body, 0)[1] == len(body):
                    terms = top_level_args(body, 0)[0]
                else:
                    terms = top_level_args([("punct", "(")] + body + [("punct", ")")], 0)[0]
                for tm in terms:
                    if len(tm) > 1 and tm[1] == ("punct", "(") and atom_value(tm[0]) is not None:
                        metas.append((atom_value(tm[0]), len(top_level_args(tm, 1)[0]), "".join(t[1] for t in tm)))
                kept.append((start, off))
                drops[META_KEPT] = drops.get(META_KEPT, 0) + 1
                continue
            if d in KEEP_DIRECTIVES:
                kept.append((start, off)); continue
            if d == "multifile":
                hooks_dyn = []
                for j in range(1, len(s) - 2):
                    t, sl, ar = s[j], s[j + 1], s[j + 2]
                    if t[0] in ("atom", "qatom") and sl[1] == "/" and ar[1].isdigit() and s[j - 1][1] != ":" and atom_value(t) != "multifile":
                        if (atom_value(t), int(ar[1])) not in defined:
                            hooks_dyn.append("%s/%s" % (quote(atom_value(t)), ar[1]))
                if hooks_dyn:
                    dynrep[start] = (first, ":- dynamic %s.\n" % ", ".join(hooks_dyn))
                    kept.append((start, off))
                    drops[HOOK_DYN] = drops.get(HOOK_DYN, 0) + len(hooks_dyn)
                    continue
            if d == "use_module":
                uses.extend(use_module_specs(s))
            if d in DROP_DIRECTIVES:
                drops["directive " + d] = drops.get("directive " + d, 0) + 1
                continue
            if d == "record" and lib in EXPANDED:
                drops["directive record('<compiled>') (library(record)'s marker for xref; the accessors it stands for are expanded clauses above)"] = 1
                continue
            raise Refuse("%s clause %d: the directive :- %s is neither dropped nor kept by this generator -- decide what it means for SCRIP first" % (path, no, d))
        if kind == "unkeyable":
            raise Refuse("%s clause %d: a head this generator cannot key (%s)" % (path, no, " ".join(t[1] for t in s[:6])))
        if kind == "qualified":
            qm, qn = atom_value(s[0]), (atom_value(s[2]) if len(s) > 2 and s[1][1] == ":" else None)
            if qm == "user" and qn:
                hooks.append((start, first, off, "")); drops["user: qualifier stripped"] = drops.get("user: qualifier stripped", 0) + 1
                continue
            if qn and (qm, qn) in CROSS_HOOKS.get(lib, {}):
                new = CROSS_HOOKS[lib][(qm, qn)]
                if src[first:first + len(qm) + 1 + len(qn)] != qm + ":" + qn:
                    raise Refuse("%s clause %d: the cross-library hook %s:%s is not written %s:%s( -- the head cannot be renamed in place" % (path, no, qm, qn, qm, qn))
                kept.append((start, off)); cross[start] = (first, len(qm) + 1 + len(qn), new)
                drops["hook %s:%s joins %s" % (qm, qn, new)] = drops.get("hook %s:%s joins %s" % (qm, qn, new), 0) + 1
                continue
            if qn and (qn, 0) in {(h, 0) for h, _ in ATTR_HOOKS}:
                kept.append((start, off)); drops["hook %s:%s kept qualified" % (qm, qn)] = drops.get("hook %s:%s kept qualified" % (qm, qn), 0) + 1
                continue
            drops["module-qualified head (%s)" % qm] = drops.get("module-qualified head (%s)" % qm, 0) + 1
            continue
        if (name, arity) in ATTR_HOOKS:
            hooks.append((start, first, off, mod)); drops["hook %s/%d qualified with the module" % (name, arity)] = drops.get("hook %s/%d qualified with the module" % (name, arity), 0) + 1
            continue
        if (name, arity) in DICT_METHOD_HEADS:
            drops["dict-method clause (SCRIP has no dicts)"] = drops.get("dict-method clause (SCRIP has no dicts)", 0) + 1
            continue
        if (name, arity) in HOOK_HEADS:
            drops["hook %s/%d" % (name, arity)] = drops.get("hook %s/%d" % (name, arity), 0) + 1
            continue
        if (name, arity) in OMIT.get(lib, {}):
            k = "omitted %s/%d (%s)" % (name, arity, OMIT[lib][(name, arity)])
            drops[k] = drops.get(k, 0) + 1
            continue
        kept.append((start, off)); keyed.append((name, arity))
    if mod is None:
        raise Refuse("%s: no :- module directive -- only a module library is vendored" % path)
    exp = set(exports)
    cside = [e for e in exports if e not in keyed and e not in OMIT.get(lib, {})]
    fallbacks = system_fallbacks(toks)
    for k in sorted(fallbacks & set(keyed)):
        drops["%s/%d defined only under :- if(\\+current_predicate(%s/%d)): a fallback for the system predicate, its references keep the name" % (k[0], k[1], k[0], k[1])] = 1
    local = {k for k in keyed if k not in exp and k[0] not in libops and k not in fallbacks}
    as_op = sorted({k[0] for k in keyed if k not in exp and k[0] in libops})
    renamed, chunks = {}, []
    for cs, ce in sorted(kept + [(cs, ce) for cs, _, ce, _ in hooks]):
        raw = src[cs:ce]
        if cs in metaspec:
            na, dot = metaspec[cs]
            raw = raw[:na - cs] + "'$meta_spec'((" + raw[na - cs + len("meta_predicate"):dot - cs] + "))" + raw[dot - cs:]
        hk = next((h for h in hooks if h[0] == cs), None)
        for f, t, ar, kd, nm in sorted((r for r in refs if cs <= r[0] < ce and (r[4], r[2]) in local), reverse=True):
            if kd == "c" and src[t:t + 1] != "(":
                raise Refuse("%s: the local predicate %s/%d is referenced in operator form at offset %d -- a renamed operator would not parse" % (path, nm, ar, f))
            new = "$%s_%s" % (lib, nm)
            raw = raw[:f - cs] + quote(new) + raw[t - cs:]
            renamed["%s/%d" % (nm, ar)] = new
        for nm in sorted(RENAME_AS_DATA.get(lib, set())):
            if not any(k[0] == nm for k in local):
                raise Refuse("%s: RENAME_AS_DATA names %s, which is not a local predicate of %s" % (path, nm, lib))
            raw = rename_bare_atom(raw, nm, "$%s_%s" % (lib, nm), path)
            renamed["%s (as data)" % nm] = "$%s_%s" % (lib, nm)
        for nm in sorted(RENAME_TERMS_AS_DATA.get(lib, set())):
            if not any(k[0] == nm for k in local):
                raise Refuse("%s: RENAME_TERMS_AS_DATA names %s, which is not a local predicate of %s" % (path, nm, lib))
            raw = rename_bare_atom(raw, nm, "$%s_%s" % (lib, nm), path, with_args=True)
            renamed["%s (as a goal term)" % nm] = "$%s_%s" % (lib, nm)
        if cs in cross:
            hf, hl, hn = cross[cs]
            raw = raw[:hf - cs] + quote(hn) + raw[hf - cs + hl:]
        if hk and hk[3]:
            raw = raw[:hk[1] - cs] + hk[3] + ":" + raw[hk[1] - cs:]
        elif hk:
            raw = raw[:hk[1] - cs] + raw[hk[1] - cs + len("user:"):]
        if cs in dynrep:
            raw = raw[:dynrep[cs][0] - cs] + dynrep[cs][1]
        chunks.append(strip_comments(raw, path))
    text = "".join(":- create_prolog_flag(%s, %s, []).\n" % (f, v) for f, v, _ in LIB_FLAGS.get(lib, [])) + "".join(chunks)
    for f, v, why in LIB_FLAGS.get(lib, []):
        drops["flag %s declared %s: %s" % (f, v, why)] = 1
    lines = [l.rstrip() for l in text.split("\n")]
    text = "\n".join(l for l in lines if l.strip()) + "\n"
    out_toks = tokenize(text, path)
    local_names = {n for n, _ in local} - {n for n, _ in exports}
    as_data = sorted({atom_value(t) for t in out_toks if t[0] in ("atom", "qatom") and atom_value(t) in local_names})
    for k, why in SHADOWS.get(lib, {}).items():
        drops["shadows %s/%d of other libraries: %s" % (k[0], k[1], why)] = 1
    return {"lib": lib, "exports": [e for e in exports if e not in OMIT.get(lib, {}) and e not in cside], "cside": cside, "renames": renamed, "ops": ops, "as_op": as_op,
            "shadows": sorted(SHADOWS.get(lib, {})), "quiet": sorted(QUIET.get(lib, set())),
            "drops": drops, "as_data": as_data, "text": text, "atoms": {atom_value(t) for t in out_toks if t[0] in ("atom", "qatom")}, "uses": uses,
            "metas": sorted({m for m in metas if (m[0], m[1]) in set(exports)})}


def c_string_lines(text):
    out = []
    for line in text.split("\n")[:-1]:
        esc = line.replace("\\", "\\\\").replace('"', '\\"').replace("\t", "\\t")
        out.append('    "%s\\n"' % esc)
    return out


def generate(pdir):
    if not os.path.isdir(pdir):
        raise Refuse("no %s" % pdir)
    libs = [process(os.path.join(pdir, f)) for f in sorted(os.listdir(pdir)) if f.endswith(".pl")]
    if not libs:
        raise Refuse("no vendored library under %s" % pdir)
    by_lib = {L["lib"]: L for L in libs}
    for w, wmap in sorted(WRAPS.items()):
        if w not in by_lib:
            raise Refuse("WRAPS names %s, which is not a vendored library" % w)
        for lib, keys in sorted(wmap.items()):
            if lib not in by_lib:
                raise Refuse("WRAPS: %s wraps %s, which is not a vendored library" % (w, lib))
            copies, counts = wrapped_copies(by_lib[lib]["text"], lib, keys, lib + ".pl")
            missing = sorted("%s/%d" % k for k in keys if k not in counts)
            if missing:
                raise Refuse("WRAPS: %s wraps %s in %s, which has no operator-form clause for them" % (w, " ".join(missing), lib))
            by_lib[lib]["text"] += copies
            by_lib[lib]["drops"]["wrapped by %s: %d clauses of %d keys copied under '$%s_wrapped_<op>'" % (w, sum(counts.values()), len(counts), lib)] = 1
            by_lib[w]["shadows"] = sorted(set(by_lib[w]["shadows"]) | set(keys))
            by_lib[w]["quiet"] = sorted(set(by_lib[w]["quiet"]) | set(keys))
    for L in libs:
        if L["lib"] in QUIET_BARE:
            L["quiet"] = sorted(set(L["quiet"]) | {(n, 0) for n, _ in L["exports"]})
    for L in libs:
        L["names"] = sorted(M["lib"] for M in libs if M is not L and any(n in L["atoms"] for n, _ in M["exports"]))
    by_path = {LIB_PATH.get(L["lib"], L["lib"]): L["lib"] for L in libs}
    for L in libs:
        base = os.path.dirname(LIB_PATH.get(L["lib"], L["lib"]))
        L["loads_rel"] = sorted({by_path[q] for q in (os.path.normpath(os.path.join(base, p)) for k, p in L["uses"] if k == "relative") if q in by_path})
        L["loads_lib"] = sorted({by_path[p] for k, p in L["uses"] if k == "library" and p in by_path})
    import_only, todo = set(), sorted(IMPORT_ONLY_FRONTS)
    for f in todo:
        if f not in by_lib:
            raise Refuse("IMPORT_ONLY_FRONTS names %s, which is not a vendored library" % f)
    while todo:
        f = todo.pop()
        if f not in import_only:
            import_only.add(f)
            todo.extend(by_lib[f]["loads_rel"])
    for L in libs:
        L["import_only"] = L["lib"] in import_only
        L["loads"] = sorted(m for m in set(L["loads_rel"]) | set(L["loads_lib"]) if m in import_only) if L["import_only"] else []
        if L["import_only"]:
            L["drops"]["selected only when the program imports it, or a library it imports loads it (IMPORT_ONLY_FRONTS)"] = 1
    o = ["typedef struct { const char *nm; int ar; } pl_prelude_lib_pi_t;",
         "typedef struct { int pri; const char *type; const char *nm; } pl_prelude_lib_op_t;",
         "typedef struct { const char *nm; int ar; const char *spec; } pl_prelude_lib_meta_t;",
         "typedef struct { const char *lib; const pl_prelude_lib_pi_t *exports; const pl_prelude_lib_op_t *ops; const pl_prelude_lib_pi_t *shadows; const pl_prelude_lib_pi_t *quiet; const char *src; "
         "const pl_prelude_lib_meta_t *metas; const char *const *loads; int import_only; } pl_prelude_lib_t;"]
    for i, L in enumerate(libs):
        o.append("static const pl_prelude_lib_pi_t PL_PRELUDE_LIB_%d_EXPORTS[] = {" % i)
        for n, a in L["exports"]:
            o.append('    { "%s", %d },' % (n.replace("\\", "\\\\").replace('"', '\\"'), a))
        o.append("    { 0, 0 }")
        o.append("};")
        for fld in ("shadows", "quiet"):
            o.append("static const pl_prelude_lib_pi_t PL_PRELUDE_LIB_%d_%s[] = {" % (i, fld.upper()))
            for n, a in L[fld]:
                o.append('    { "%s", %d },' % (n.replace("\\", "\\\\").replace('"', '\\"'), a))
            o.append("    { 0, 0 }")
            o.append("};")
        o.append("static const pl_prelude_lib_op_t PL_PRELUDE_LIB_%d_OPS[] = {" % i)
        for pri, ty, n in L["ops"]:
            o.append('    { %d, "%s", "%s" },' % (pri, ty, n.replace("\\", "\\\\").replace('"', '\\"')))
        o.append("    { 0, 0, 0 }")
        o.append("};")
        o.append("static const char *const PL_PRELUDE_LIB_%d_LOADS[] = { %s0 };" % (i, "".join('"%s", ' % m for m in L["loads"])))
        o.append("static const pl_prelude_lib_meta_t PL_PRELUDE_LIB_%d_METAS[] = {" % i)
        for n, a, sp in L.get("metas", []):
            o.append('    { "%s", %d, "%s" },' % (n.replace("\\", "\\\\").replace('"', '\\"'), a, sp.replace("\\", "\\\\").replace('"', '\\"')))
        o.append("    { 0, 0, 0 }")
        o.append("};")
        o.append("static const char PL_PRELUDE_LIB_%d_SRC[] =" % i)
        o.extend(c_string_lines(L["text"]))
        o[-1] += ";"
    o.append("static const pl_prelude_lib_t PL_PRELUDE_LIBS[] = {")
    for i, L in enumerate(libs):
        o.append('    { "%s", PL_PRELUDE_LIB_%d_EXPORTS, PL_PRELUDE_LIB_%d_OPS, PL_PRELUDE_LIB_%d_SHADOWS, PL_PRELUDE_LIB_%d_QUIET, PL_PRELUDE_LIB_%d_SRC, PL_PRELUDE_LIB_%d_METAS, PL_PRELUDE_LIB_%d_LOADS, %d },'
                 % (L["lib"], i, i, i, i, i, i, i, int(L["import_only"])))
    o.append("    { 0, 0, 0, 0, 0, 0, 0, 0, 0 }")
    o.append("};")
    o.append("typedef struct { const char *nm; int n; int ar; int lib; } pl_prelude_lib_ex_t;")
    o.append("static const pl_prelude_lib_ex_t PL_PRELUDE_LIB_EXPORT_INDEX[] = {")
    for n, a, i in sorted(((n, a, i) for i, L in enumerate(libs) for n, a in L["exports"]), key=lambda r: (r[0].encode("utf-8"), r[1], r[2])):
        o.append('    { "%s", %d, %d, %d },' % (n.replace("\\", "\\\\").replace('"', '\\"'), len(n.encode("utf-8")), a, i))
    o.append("};")
    return libs, "\n".join(o) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", default=PRELUDE_DIR)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--show")
    a = ap.parse_args()
    try:
        libs, txt = generate(a.dir)
    except Refuse as e:
        print("REFUSED(2) util_gen_prolog_prelude_libs: %s" % e, file=sys.stderr)
        return 2
    if a.show:
        L = next((L for L in libs if L["lib"] == a.show), None)
        if not L:
            print("REFUSED(2): no vendored library %s" % a.show, file=sys.stderr)
            return 2
        print("exports: " + " ".join("%s/%d" % e for e in L["exports"]))
        print("operators: " + " ".join("op(%d,%s,%s)" % o for o in L["ops"]))
        print("renamed: " + " ".join("%s->%s" % kv for kv in sorted(L["renames"].items())))
        print("dropped: " + ", ".join("%s x%d" % kv for kv in sorted(L["drops"].items())))
        print("names exports of (informational -- the injector selects a library by the name/arity references it finds when it parses the libraries it selected): " + " ".join(L["names"]))
        print("C-side exports (no clause in the library; SCRIP answers them as builtins or they are existence errors): " + " ".join("%s/%d" % e for e in L["cside"]))
        print("left as data (a helper's name used as a term, never a goal -- review each): " + " ".join(L["as_data"]))
        print("helpers kept under their own names because the library declares them as operators (a renamed operator would not parse): " + " ".join(L["as_op"]))
        sys.stdout.write(L["text"])
        return 0
    if a.check:
        cur = open(a.out).read() if os.path.exists(a.out) else ""
        if cur != txt:
            print("STALE: %s differs from what util_gen_prolog_prelude_libs.py generates from %s -- run it and commit both" % (os.path.relpath(a.out, ROOT), os.path.relpath(a.dir, ROOT)))
            return 1
        print("in sync: %d vendored libraries, %s" % (len(libs), " ".join(L["lib"] for L in libs)))
        return 0
    open(a.out, "w").write(txt)
    for L in libs:
        print("%-20s exports=%-3d renamed=%-3d C-side=%-2d as-data=%-2d dropped: %s" % (L["lib"], len(L["exports"]), len(L["renames"]), len(L["cside"]), len(L["as_data"]), ", ".join("%s x%d" % kv for kv in sorted(L["drops"].items()))))
    print("wrote %s" % os.path.relpath(a.out, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
